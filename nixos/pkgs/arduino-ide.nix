# arduino-ide with two fixes over the nixpkgs package:
#  - libxkbfile in the FHS env (the keyboard-layout native module fails to load without it)
#  - stdout/stderr sent to /dev/null: when launched from a launcher the pipe is closed,
#    and every console.log then raises a "write EPIPE" popup in the main process
{ appimageTools, arduino-ide, libsecret, xorg, symlinkJoin, writeShellScript }:

let
  base = arduino-ide.override {
    appimageTools = appimageTools // {
      wrapType2 = args: appimageTools.wrapType2 (args // {
        extraPkgs = pkgs: [ libsecret xorg.libxkbfile ];
      });
    };
  };
  quiet = writeShellScript "arduino-ide" ''
    exec ${base}/bin/arduino-ide "$@" >/dev/null 2>&1
  '';
in
symlinkJoin {
  name = "arduino-ide-${base.version}";
  paths = [ base ];
  postBuild = ''
    rm $out/bin/arduino-ide
    ln -s ${quiet} $out/bin/arduino-ide
  '';
  meta = base.meta;
}
