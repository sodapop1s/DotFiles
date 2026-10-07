{ pkgs }:

pkgs.buildFHSEnv {
  name = "matlab";
  targetPkgs = p: with p; [
    stdenv.cc.cc.lib
    zlib
    glib
    fontconfig
    freetype
    libGL
    xorg.libX11
    xorg.libXext
    xorg.libXrender
    xorg.libXi
    xorg.libXcursor
    xorg.libXrandr
    xorg.libXfixes
    xorg.libxcb
    xorg.xcbutil
    xorg.xcbutilimage
    xorg.xcbutilkeysyms
    xorg.xcbutilrenderutil
    xorg.xcbutilwm
    xorg.libSM
    xorg.libICE
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXtst
    xorg.xcbutilcursor
    xorg.libXt
    alsa-lib
    dbus
    expat
    nss
    nspr
    atk
    gtk3
    pango
    cairo
    gdk-pixbuf
    pam
    cups
    libcap_ng
    audit
    gperftools
    libgbm
    libdrm
    wayland
    systemd
    util-linux
  ];
  runScript = "/opt/matlab/R2026b/bin/matlab";
}
