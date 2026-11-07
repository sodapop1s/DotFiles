# Earth wallpaper support: the compiled shader, the ISS position script and its timer.
# Installed under /run/current-system/sw/share/orbit/ (read by quickshell/orbit/Wallpaper.qml).
{ pkgs, lib, ... }:

let
  shader = pkgs.runCommand "orbit-earth-shader" { nativeBuildInputs = [ pkgs.qt6.qtshadertools ]; } ''
    mkdir -p $out/share/orbit
    qsb --qt6 -o $out/share/orbit/earth.frag.qsb ${./earth.frag}
  '';

  issScript = pkgs.writers.writePython3Bin "orbit-iss"
    { libraries = [ pkgs.python3Packages.sgp4 ]; flakeIgnore = [ "E501" ]; }
    (builtins.readFile ./iss.py);
in
{
  environment.systemPackages = [ shader issScript ];
  # pathsToLink is an allow-list: without this the files never reach /run/current-system/sw
  environment.pathsToLink = [ "/share/orbit" ];

  # ISS position once a minute. AccuracySec lets systemd batch the wake-up with others; the script
  # itself slows to every 5 minutes on battery and refetches the TLE at most every 12 hours.
  systemd.user.services.orbit-iss = {
    description = "Compute the ISS position for the wallpaper";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${issScript}/bin/orbit-iss";
      Nice = 15;
    };
  };
  systemd.user.timers.orbit-iss = {
    description = "ISS position for the wallpaper, every minute";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnStartupSec = "20s";
      OnUnitActiveSec = "1min";
      AccuracySec = "10s";
    };
  };
}
