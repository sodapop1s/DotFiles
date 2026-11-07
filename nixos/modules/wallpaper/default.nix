# Earth wallpaper support: the compiled shader, the ISS position script and its timer.
# Installed under /run/current-system/sw/share/orbit/ (read by quickshell/orbit/Wallpaper.qml).
{ pkgs, lib, ... }:

let
  shader = pkgs.runCommand "orbit-earth-shader" { nativeBuildInputs = [ pkgs.qt6.qtshadertools ]; } ''
    mkdir -p $out/share/orbit
    qsb --qt6 -o $out/share/orbit/earth.frag.qsb ${./earth.frag}
  '';

  # NASA Earth Observatory imagery (credit: NASA Earth Observatory). Pinned by hash; downscaled so the
  # GPU holds two 4096x2048 maps (about 64 MB) instead of a 13500x6750 one.
  nasa = "https://assets.science.nasa.gov/content/dam/science/esd/eo/images";
  blueMarble = pkgs.fetchurl {
    # Blue Marble Next Generation, August 2004, with topography and bathymetry (5400x2700)
    url = "${nasa}/bmng/bmng-topography-bathymetry/august/world.topo.bathy.200408.3x5400x2700.jpg";
    hash = "sha256-9217lEReiXWnVchJ3aqT7Qe34BEY+wt+a8VUamjBjVw=";
  };
  blackMarble = pkgs.fetchurl {
    # Black Marble 2016, 3 km (13500x6750)
    url = "${nasa}/imagerecords/144000/144898/BlackMarble_2016_3km.jpg";
    hash = "sha256-IwqsRIrmjDWL5DPdUYiIzMs6hcz2b3tEMmRBwyStZyU=";
  };
  textures = pkgs.runCommand "orbit-earth-textures" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    mkdir -p $out/share/orbit
    magick ${blueMarble}  -filter Lanczos -resize 4096x2048! -quality 90 $out/share/orbit/earth-day.jpg
    magick ${blackMarble} -filter Lanczos -resize 4096x2048! -quality 90 $out/share/orbit/earth-night.jpg
  '';

  issScript = pkgs.writers.writePython3Bin "orbit-iss"
    { libraries = [ pkgs.python3Packages.sgp4 ]; flakeIgnore = [ "E501" ]; }
    (builtins.readFile ./iss.py);
in
{
  environment.systemPackages = [ shader textures issScript ];
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
