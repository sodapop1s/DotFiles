# Lock screen and idle handling.
#   orbit-lock   themed swaylock (config generated from the design tokens); never starts a second locker
#   swayidle     lock after 5 min idle, screen off after 6, suspend after 20 only on battery (never on AC,
#                so VMs keep running while plugged in). Always locks before any sleep, and on `loginctl lock-session`.
# Apps that ask the compositor to stay awake (video players, browsers playing video) hold idle off by themselves.
#
# Idle handling is OFF by default: swayidle is installed and defined, but not started at login.
#   orbit-idle on | off | status     start or stop it for this session (also a switch in the System panel)
#   orbit.idle.autostart = true;     in a host's configuration.nix to have it start with every login again
# Note: with swayidle stopped, a manual suspend or `loginctl lock-session` no longer locks first; Super+Alt+L still does.
{ config, lib, pkgs, ... }:

let
  cfg = config.orbit.idle;
  lockConfig = "/run/current-system/sw/share/rice-theme/swaylock/config";

  lock = pkgs.writeShellScriptBin "orbit-lock" ''
    # anchored match: the command line must start with a path ending in /swaylock
    ${pkgs.procps}/bin/pgrep -f '^\S*/swaylock( |$)' >/dev/null && exit 0
    exec ${pkgs.swaylock}/bin/swaylock -f -C ${lockConfig}
  '';

  suspendOnBattery = pkgs.writeShellScript "orbit-suspend-on-battery" ''
    # ACAD/online is 0 on battery, 1 on AC
    [ "$(cat /sys/class/power_supply/ACAD/online 2>/dev/null)" = "0" ] && exec systemctl suspend
    exit 0
  '';

  idleCtl = pkgs.writeShellScriptBin "orbit-idle" ''
    case "''${1:-status}" in
      on)     systemctl --user start swayidle && echo "auto-lock and sleep: on" ;;
      off)    systemctl --user stop swayidle  && echo "auto-lock and sleep: off" ;;
      status) if systemctl --user is-active --quiet swayidle; then echo on; else echo off; fi ;;
      *)      echo "usage: orbit-idle on|off|status" >&2; exit 2 ;;
    esac
  '';

  niri = "/run/current-system/sw/bin/niri";
in
{
  options.orbit.idle.autostart = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Start swayidle (lock, screen off, suspend when idle) with every graphical login.";
  };

  config = {
  environment.systemPackages = [ lock idleCtl pkgs.swayidle ];

  systemd.user.services.swayidle = {
    description = "Lock, blank and suspend when idle";
    wantedBy = lib.optional cfg.autostart "graphical-session.target";
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = 2;
      ExecStart = builtins.concatStringsSep " " [
        "${pkgs.swayidle}/bin/swayidle -w"
        "timeout 300 '${lock}/bin/orbit-lock'"
        "timeout 360 '${niri} msg action power-off-monitors' resume '${niri} msg action power-on-monitors'"
        "timeout 1200 '${suspendOnBattery}'"
        "before-sleep '${lock}/bin/orbit-lock'"
        "lock '${lock}/bin/orbit-lock'"
      ];
    };
  };
  };
}
