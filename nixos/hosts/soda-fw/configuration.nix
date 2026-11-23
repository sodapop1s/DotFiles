{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../common.nix
    ../../modules/omdrop.nix
    ../../modules/theme
    ../../modules/wallpaper
    ../../modules/clipboard.nix
    ../../modules/idle.nix
    ../../modules/filemanager.nix
    ../../modules/spotify.nix
    ../../modules/desktop-switch.nix
  ];

  networking.hostName = "soda-fw";

  # ESP is only 96MB, shared with Windows — keep the count low
  boot.loader.systemd-boot.configurationLimit = 3;

  # Silent hard resets since at least 2026-10-05 (no MCE/oops/GPU logs), on BIOS 03.05,
  # which has known random-shutdown reports. fwupd to update the BIOS from LVFS.
  # (linuxPackages_latest would name the reset reason at boot, but its kernel+initrd
  # don't fit the 22MB left on the ESP.)
  services.fwupd.enable = true;

  # Bluetooth
  hardware.bluetooth.enable      = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable        = true;  # Bluetooth GUI

  # Restrict BT to A2DP only (no headset mic / HFP profile)
  services.pipewire.wireplumber.extraConfig."51-bluez-a2dp-only" = {
    "monitor.bluez.properties" = {
      "bluez5.roles" = [ "a2dp_sink" "a2dp_source" ];
    };
  };

  # AirDrop to/from iPhones. The Wi-Fi card is an MT7922 (mt7921e), which omdrop-owl
  # lists as untested, hence allowUntested. Needs the AP on channel 6, 44 or 149.
  services.omdrop.enable        = true;
  services.omdrop.allowUntested = true;

  # Compressed RAM swap — the iGPU shares system RAM, so modded KSP OOMs without it
  zramSwap.enable = true;

  # Mesa VAAPI/VDPAU for the 780M iGPU — Moonlight decodes HEVC/AV1 through it
  hardware.graphics.enable = true;

  environment.systemPackages = with pkgs; [
    # Plain btop — no ROCm dependency on the laptop
    btop
    # Game-streaming client for Sunshine on soda-desk (client only, no firewall ports)
    moonlight-qt
  ];
}
