# Clipboard history for the orbit picker (quickshell/orbit/ClipboardPicker.qml).
#   wl-clip-persist  keeps the regular clipboard alive after the copying app closes (primary selection untouched)
#   cliphist         stores text copies; the picker lists them and copies one back
# cliphist has no per-entry age, so the stand-in for "expire after a couple of days" is a daily wipe;
# the history also never holds more than 200 entries. Copies flagged sensitive by password managers
# (CLIPBOARD_STATE=sensitive from wl-paste) are not stored.
{ pkgs, ... }:

let
  graphical = {
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = { Restart = "on-failure"; RestartSec = 2; };
  };
in
{
  environment.systemPackages = with pkgs; [ cliphist wl-clip-persist ];

  systemd.user.services.wl-clip-persist = graphical // {
    description = "Keep the clipboard after the source app exits";
    serviceConfig = graphical.serviceConfig // {
      ExecStart = "${pkgs.wl-clip-persist}/bin/wl-clip-persist --clipboard regular";
    };
  };

  systemd.user.services.cliphist-watch = graphical // {
    description = "Record text copies in cliphist";
    serviceConfig = graphical.serviceConfig // {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --type text --watch ${pkgs.cliphist}/bin/cliphist -max-items 200 store";
    };
  };

  systemd.user.services.cliphist-wipe = {
    description = "Clear the clipboard history";
    serviceConfig = { Type = "oneshot"; ExecStart = "${pkgs.cliphist}/bin/cliphist wipe"; };
  };
  systemd.user.timers.cliphist-wipe = {
    description = "Clear the clipboard history daily";
    wantedBy = [ "timers.target" ];
    timerConfig = { OnCalendar = "*-*-* 04:00:00"; Persistent = true; };
  };
}
