# idevicerestore from upstream master. The nixpkgs snapshot (Oct 2025) fails to
# restore newer iPhones ("Unable to fetch Yonkers ticket"); master has the fix.
# Drop this once nixpkgs catches up.

{ fetchFromGitHub, idevicerestore, libirecovery }:

let
  libirecovery-git = libirecovery.overrideAttrs (_: {
    version = "git-2026-10-05";
    src = fetchFromGitHub {
      owner = "libimobiledevice";
      repo  = "libirecovery";
      rev   = "93c117c29b1f6669bc4ceca8b84e1df06449fe33";
      hash  = "sha256-tNKNceZHMAWwhngt3n4XXbY1w6CeWhYbvWHBuODEvV4=";
    };
    postPatch = "";
  });
in
(idevicerestore.override { libirecovery = libirecovery-git; }).overrideAttrs (_: {
  version = "git-2026-10-05";
  src = fetchFromGitHub {
    owner = "libimobiledevice";
    repo  = "idevicerestore";
    rev   = "4b3e847e1d9a1210049a9e3f1d1caa38650c6617";
    hash  = "sha256-F6/yl83AvZaUnnrrzNl8l9FRRJGgh6U53ADw/8XKw6I=";
  };
  patches   = [];
  postPatch = "";
})
