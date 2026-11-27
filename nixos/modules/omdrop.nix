# AirDrop for non-Broadcom Wi-Fi: omdrop-owl (radio, AWDL in userspace via OWL)
# + omdrop (CLI and receiver). See pkgs/omdrop-owl.nix and pkgs/omdrop.nix.
#
#   services.omdrop.enable = true;
#
# Nothing is visible or listening until `omdrop on` (or the hub's AirDrop
# applet) opens a bounded window. This module only installs the pieces and
# the system plumbing they need.

{ config, lib, pkgs, ... }:

let
  cfg = config.services.omdrop;
in
{
  options.services.omdrop = {
    enable = lib.mkEnableOption "AirDrop (omdrop + omdrop-owl)";

    radioPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../pkgs/omdrop-owl.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ../pkgs/omdrop-owl.nix { }";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../pkgs/omdrop.nix { omdrop-owl = cfg.radioPackage; };
      defaultText = lib.literalExpression "pkgs.callPackage ../pkgs/omdrop.nix { ... }";
    };

    allowUntested = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Create /etc/omdrop/allow-untested so Wi-Fi drivers not marked
        "tested" in owl-profiles (mt7921e, rtw89, ath11k/12k) may run.
      '';
    };

    extraProfiles = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = "mt7921e untested shared station yes yes MT7922 on Framework";
      description = ''
        Extra lines for /etc/omdrop/owl-profiles, read before the packaged
        table. Format: driver status mode mon_mac reconnect mt76_pm notes.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package cfg.radioPackage ];

    # pkexec action for omdrop-discoverable (bound to the store path)
    security.polkit.enable = true;
    environment.pathsToLink = [ "/share/polkit-1/actions" ];

    # awdl0 / mon0 / awdlibss0 are OWL's; NetworkManager must leave them alone
    networking.networkmanager.unmanaged = [
      "interface-name:awdl0" "interface-name:mon0" "interface-name:awdlibss0"
    ];

    # BLE wake advert for iPhones goes through BlueZ
    hardware.bluetooth.enable = lib.mkDefault true;

    # Receiver port, on the AWDL interface only
    networking.firewall.interfaces.awdl0.allowedTCPPorts = [ 8771 ];

    environment.etc = lib.mkMerge [
      (lib.mkIf cfg.allowUntested { "omdrop/allow-untested".text = "1\n"; })
      (lib.mkIf (cfg.extraProfiles != "") { "omdrop/owl-profiles".text = cfg.extraProfiles + "\n"; })
    ];

    # The receiver, as upstream's share/airdrop-receiver.service but with
    # store paths. Not wanted by anything: `omdrop on` starts it for a window
    # and `omdrop off` stops it.
    systemd.user.services.airdrop-receiver = {
      description = "AirDrop receiver over AWDL (awdl0)";
      unitConfig.AssertPathExists = "/sys/class/net/awdl0";
      path = with pkgs; [ iproute2 gnugrep coreutils ];
      serviceConfig = {
        Type = "simple";
        WorkingDirectory = "${cfg.package}";
        ExecStartPre = [
          # wait for a previous instance's port 8771 to clear, then for awdl0's link-local
          ''${pkgs.runtimeShell} -c 'for i in $(seq 1 40); do ss -Hltn 2>/dev/null | grep -q ":8771 " || exit 0; sleep 0.25; done; echo "port 8771 still busy after 10s" >&2; exit 1' ''
          ''${pkgs.runtimeShell} -c 'for i in $(seq 1 60); do ip -6 addr show dev awdl0 scope link 2>/dev/null | grep -q inet6 && exit 0; sleep 0.5; done; echo "awdl0 has no link-local after 30s" >&2; exit 1' ''
        ];
        ExecStart = "${cfg.package.pythonEnv}/bin/python3 ${cfg.package}/bin/airdrop-serve.py --iface awdl0 --port 8771";
        Restart = "on-failure";
        RestartSec = "2s";
        # upstream's hardening, unchanged
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        ReadWritePaths = [ "-%h/Downloads" "-%h/.omdrop" "-%t/omdrop/debug" ];
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [ "AF_INET6" "AF_INET" "AF_UNIX" "AF_NETLINK" ];
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        SystemCallArchitectures = "native";
        LimitCORE = 0;
      };
    };
  };
}
