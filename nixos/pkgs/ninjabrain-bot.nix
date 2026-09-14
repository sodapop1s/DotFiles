# Ninjabrain Bot -- stronghold calculator for MCSR
#
# Upstream only ships a bare JAR, so this is just a wrapper around it.
#
# The NixOS-specific catch: the bundled JNativeHook library (what powers the
# global hotkeys) is a .so that gets unpacked to /tmp at runtime and dynamically
# links against a pile of X11 libs. Nothing puts those on the loader path here,
# so without the LD_LIBRARY_PATH prefix below the hotkeys just quietly stop
# working while the rest of the app looks fine. Confirmed with readelf -d on
# libJNativeHook.so: libX11, libXtst, libXt, libXinerama, libxcb, libxkbcommon.

{ lib
, stdenvNoCC
, fetchurl
, makeWrapper
, jdk21
, xorg
, libxkbcommon
}:

let
  # Everything libJNativeHook.so wants at load time.
  runtimeLibs = lib.makeLibraryPath [
    xorg.libX11       # also provides libX11-xcb.so.1
    xorg.libXtst      # XTest, needed to grab keys globally
    xorg.libXt
    xorg.libXinerama
    xorg.libxcb
    libxkbcommon      # also provides libxkbcommon-x11.so.0
  ];
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "ninjabrain-bot";
  version = "1.5.2";

  src = fetchurl {
    url = "https://github.com/Ninjabrain1/Ninjabrain-Bot/releases/download/${finalAttrs.version}/Ninjabrain-Bot-${finalAttrs.version}.jar";
    hash = "sha256-mAmfYyGpDUrOwTQA6G0F96+NYOVjnC84Qn6WjccUUP8=";
  };

  # It's a JAR, there is nothing to unpack or build.
  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/ninjabrain-bot
    cp $src $out/share/ninjabrain-bot/ninjabrain-bot.jar

    makeWrapper ${jdk21}/bin/java $out/bin/ninjabrain-bot \
      --add-flags "-jar $out/share/ninjabrain-bot/ninjabrain-bot.jar" \
      --prefix LD_LIBRARY_PATH : "${runtimeLibs}" \
      --set _JAVA_AWT_WM_NONREPARENTING 1

    # Desktop entry so it shows up in the DMS launcher instead of being
    # terminal-only.
    mkdir -p $out/share/applications
    cat > $out/share/applications/ninjabrain-bot.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Ninjabrain Bot
Comment=Stronghold calculator for Minecraft speedrunning
Exec=$out/bin/ninjabrain-bot
Terminal=false
Categories=Game;Utility;
EOF

    runHook postInstall
  '';

  meta = {
    description = "Accurate stronghold calculator for Minecraft speedrunning";
    homepage = "https://github.com/Ninjabrain1/Ninjabrain-Bot";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "ninjabrain-bot";
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
  };
})
