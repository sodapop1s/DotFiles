# omdrop-owl -- AirDrop radio backend for non-Broadcom Wi-Fi (OWL / AWDL in userspace)
#
# Upstream only packages for Arch (PKGBUILD) and Debian. This mirrors the
# PKGBUILD: build OWL (jedbillyb fork) at the pinned commit, apply the repo's
# patches, then lay out the helpers the way /usr/lib/omdrop expects, which
# here is $out/lib/omdrop. The helper finds its siblings via `dirname $0`, so
# the layout is all that matters; only the polkit policy needs the real path.
#
# Pins (rev/hashes) come from upstream's `pins` file. Bump them together.

{ lib
, stdenv
, fetchFromGitHub
, cmake
, pkg-config
, libev
, libpcap
, libnl
, python3
, glib
, bash
, iproute2
, iw
, gnugrep
, gawk
, gnused
, coreutils
, procps
, util-linux
, networkmanager
, keyutils
, findutils
}:

let
  # OWL: the airdrop-mt7921 fork (-S channel strategies, iOS 26 fixes).
  owl = fetchFromGitHub {
    owner = "jedbillyb";
    repo = "owl";
    rev = "832d70f815c3d4a06a02117bf0fc5e868daa1ff0";
    fetchSubmodules = true; # googletest + radiotap-library
    hash = "sha256-wke+tR6E4mfmzlGw1tgXiYOkSxeIRvaOmOYNWXIUVR8=";
  };

  # Radio-independent tools, used unmodified (GPL-2.0-only, separate programs).
  omdropAwdl = fetchFromGitHub {
    owner = "brentkearney";
    repo = "omdrop-awdl";
    rev = "534f91a525337951ca19c311e53d333bd6d55100";
    hash = "sha256-GqxaM/5Qnj458AQPdHp1Jyfa6HK7tdybO6xDBbKUWc4=";
  };

  pythonEnv = python3.withPackages (ps: with ps; [
    libarchive-c
    pillow
    zeroconf
    ifaddr
    dbus-python
    pygobject3
  ]);

  # The helper runs as root via pkexec, which drops the environment, so it
  # gets its PATH from the script itself.
  runtimePath = lib.makeBinPath [
    pythonEnv bash coreutils gnugrep gawk gnused findutils procps util-linux
    iproute2 iw networkmanager keyutils
  ];

  fromOmdropAwdl = [
    "send-to-peer" "airdrop-send.py" "awdl-af-parse.py" "awdl_identity.py"
    "awdl_debug.py" "ble-airdrop-adv.py" "awdl-airdrop-adv.py" "awdl-mdns-respond.py"
  ];
in
stdenv.mkDerivation {
  pname = "omdrop-owl";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "t4t5";
    repo = "omdrop-owl";
    rev = "ee6a57d971c207c933a424c0d705044a02985b0a";
    hash = "sha256-YnBx/k6ao+y7m+p3PxFGCudrbG3/K3g3Ak1NwBdAQbs=";
  };

  nativeBuildInputs = [ cmake pkg-config ];
  buildInputs = [ libev libpcap libnl ];

  # We drive cmake against OWL's tree ourselves (it is a second source), so
  # skip the setup hook's configure/build against ./ .
  dontUseCmakeConfigure = true;
  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    cp -r --no-preserve=mode ${owl} owl
    for p in patches/owl-*.patch; do
      echo "applying $(basename "$p")"
      patch -d owl -p1 < "$p"
    done

    # Policy minimum is for the bundled googletest (CMake 4 refuses < 3.5).
    # Only the owl target is built: googletest fails under current GCC.
    cmake -S owl -B build -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -Wno-dev
    cmake --build build --target owl -j$NIX_BUILD_CORES

    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    # Same sanity check as the PKGBUILD: did the patches add -S/-R/-m/-F/-E?
    help=$(build/daemon/owl -S intersect -R 12 -m 02:00:00:00:00:01 -F -E -h 2>&1 || true)
    case "$help" in
      *"invalid option"*|*"-R takes"*|*"-m takes"*) echo "patches did not apply"; exit 1 ;;
    esac
  '';

  installPhase = ''
    runHook preInstall

    lib=$out/lib/omdrop
    install -Dm755 userspace/omdrop-discoverable $lib/omdrop-discoverable
    install -Dm644 userspace/owl-profiles        $lib/owl-profiles
    install -Dm755 build/daemon/owl              $lib/owl
    for f in ${lib.concatStringsSep " " fromOmdropAwdl}; do
      install -Dm755 ${omdropAwdl}/userspace/$f $lib/$f
    done

    # Policy bound to the store path of the helper (what pkexec will exec).
    install -Dm644 packaging/omdrop-owl.policy \
      $out/share/polkit-1/actions/io.github.t4t5.omdrop-owl.policy
    substituteInPlace $out/share/polkit-1/actions/io.github.t4t5.omdrop-owl.policy \
      --replace-fail /usr/lib/omdrop/omdrop-discoverable $lib/omdrop-discoverable

    install -Dm644 packaging/99-omdrop-owl-unmanaged.conf \
      $out/etc/NetworkManager/conf.d/99-omdrop-owl-unmanaged.conf

    install -Dm644 README.md $out/share/doc/omdrop-owl/README.md
    install -Dm644 owl/COPYING $out/share/licenses/omdrop-owl/OWL-GPL-3.0
    install -Dm644 ${omdropAwdl}/LICENSE $out/share/licenses/omdrop-owl/omdrop-awdl-LICENSE

    runHook postInstall
  '';

  # Wire interpreters and PATH. pkexec strips the environment, so everything
  # has to be baked in.
  postFixup = ''
    lib=$out/lib/omdrop

    # Python tools: use the env with dbus/gi/zeroconf/etc.
    for f in $lib/*.py $lib/send-to-peer; do
      sed -i '1s|^#!.*python3.*|#!${pythonEnv}/bin/python3|' "$f"
    done

    # Shell helper: absolute bash, plus PATH and the GI typelibs for the BLE
    # advertiser's `from gi.repository import GLib`.
    sed -i '1s|^#!.*|#!${bash}/bin/bash|' $lib/omdrop-discoverable
    sed -i '/^set -uo pipefail$/a export PATH=${runtimePath}:"$PATH"\nexport GI_TYPELIB_PATH=${glib.out}/lib/girepository-1.0${"$"}{GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}' \
      $lib/omdrop-discoverable
    grep -q 'export PATH=' $lib/omdrop-discoverable   # fail loudly if the anchor moved
  '';

  meta = {
    description = "AirDrop radio backend (OWL/AWDL in userspace) for non-Broadcom Wi-Fi";
    homepage = "https://github.com/t4t5/omdrop-owl";
    # OWL + patches GPL-3.0+, radiotap ISC, omdrop-awdl tools GPL-2.0-only
    license = with lib.licenses; [ gpl3Plus gpl2Only isc ];
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "omdrop-discoverable";
  };
}
