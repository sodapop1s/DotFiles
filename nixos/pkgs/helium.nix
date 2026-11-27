# Helium (privacy-focused Chromium fork) from the upstream AppImage, wrapped in an FHS env.
# Not in nixpkgs. Bump version + hash together:
#   nix-prefetch-url https://github.com/imputnet/helium-linux/releases/download/<ver>/helium-<ver>-x86_64.AppImage
{ appimageTools, fetchurl }:

let
  pname = "helium";
  version = "0.20.3.1";
  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-x86_64.AppImage";
    sha256 = "0dx09kz71w9a1lyyddbccrwc925f709cn9g3jbma257y92357bqz";
  };
  contents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;
  extraInstallCommands = ''
    for d in ${contents}/usr/share/icons ${contents}/usr/share/applications; do :; done
    install -Dm444 ${contents}/*.desktop -t $out/share/applications 2>/dev/null || true
    substituteInPlace $out/share/applications/*.desktop --replace-quiet 'Exec=AppRun' 'Exec=helium' || true
    cp -r ${contents}/usr/share/icons $out/share/ 2>/dev/null || true
  '';
  meta.mainProgram = "helium";
}
