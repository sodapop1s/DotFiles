# omdrop -- AirDrop CLI + receiver (brentkearney/omdrop-plugin), ported to NixOS
#
# Upstream is an Omarchy bar plugin that expects Arch (pacman, ufw), a
# self-installed user unit and /usr/lib/omdrop. We keep the `omdrop` CLI and
# the receiver (airdrop-serve.py) and patch the distro assumptions out:
#   - radio helpers point at the omdrop-owl store path (polkit is bound to it)
#   - the receiver's systemd user unit comes from NixOS (modules/omdrop.nix),
#     so `omdrop setup` must not write one
#   - PATH and python are baked in, since pkexec and user units strip the env
#   - omarchy-* helpers the CLI calls are provided as small shims
# The Omarchy panel (Panel.qml) is unused: the quickshell hub drives the CLI.

{ lib
, stdenv
, fetchFromGitHub
, python3
, bash
, coreutils
, gnugrep
, gawk
, gnused
, findutils
, util-linux
, iproute2
, systemd
, openssl
, keyutils
, libnotify
, xdg-utils
, wl-clipboard
, glib
, writeShellScriptBin
, omdrop-owl
}:

let
  pythonEnv = python3.withPackages (ps: with ps; [ libarchive-c pygobject3 ]);

  # What the CLI expects from Omarchy, mapped onto plain freedesktop tools.
  omarchyShims = [
    (writeShellScriptBin "omarchy-notification-send" ''
      t=5000 img= ; pos=() ; cmd=()
      while [ $# -gt 0 ]; do
        case "$1" in
          -t) t=$2; shift 2 ;;
          --image) img=$2; shift 2 ;;
          --exec) shift; cmd=("$@"); break ;;
          *) pos+=("$1"); shift ;;
        esac
      done
      if [ ''${#cmd[@]} -gt 0 ]; then
        ( r=$(${libnotify}/bin/notify-send -a Omdrop -t "$t" -A default=Open -w ''${img:+-i "$img"} "''${pos[@]}")
          [ "$r" = default ] && "''${cmd[@]}" ) >/dev/null 2>&1 &
      else
        ${libnotify}/bin/notify-send -a Omdrop -t "$t" ''${img:+-i "$img"} "''${pos[@]}"
      fi
    '')
    (writeShellScriptBin "omarchy-launch-browser" ''exec ${xdg-utils}/bin/xdg-open "$@"'')
    # pacman's vercmp: prints -1, 0 or 1
    (writeShellScriptBin "vercmp" ''
      [ "$1" = "$2" ] && { echo 0; exit 0; }
      first=$(printf '%s\n%s\n' "$1" "$2" | ${coreutils}/bin/sort -V | head -1)
      [ "$first" = "$1" ] && echo -1 || echo 1
    '')
    (writeShellScriptBin "omarchy-default-terminal" ''echo "''${TERMINAL:-kitty}"'')
  ];

  runtimePath = lib.makeBinPath ([
    pythonEnv bash coreutils gnugrep gawk gnused findutils util-linux iproute2
    systemd openssl libnotify xdg-utils wl-clipboard
  ] ++ omarchyShims) + ":/run/wrappers/bin";
in
stdenv.mkDerivation {
  pname = "omdrop";
  version = "0.15.1";

  src = fetchFromGitHub {
    owner = "brentkearney";
    repo = "omdrop-plugin";
    rev = "32653660960c0870769108c29924a65341dd0711";
    hash = "sha256-U2mTqU8uhd9/ZPj8kjVFV/3NSlNOkpPWWtzG7muIBV0=";
  };

  dontBuild = true;

  postPatch = ''
    # radio helpers: the nix store path, which is what the polkit action names
    substituteInPlace bin/omdrop \
      --replace-fail /usr/lib/omdrop/omdrop-discoverable ${omdrop-owl}/lib/omdrop/omdrop-discoverable \
      --replace-fail /usr/lib/omdrop/send-to-peer ${omdrop-owl}/lib/omdrop/send-to-peer \
      --replace-fail /usr/lib/libkeyutils.so.1 ${keyutils.lib}/lib/libkeyutils.so.1

    substituteInPlace bin/identity.py \
      --replace-fail "CDLL('libkeyutils.so.1'" "CDLL('${keyutils.lib}/lib/libkeyutils.so.1'"

    # NixOS owns the receiver unit; never write ~/.config/systemd/user/*.service
    substituteInPlace bin/omdrop \
      --replace-fail 'unit_install() {' 'unit_install() {
  return 1  # managed by NixOS (services/omdrop module)'

    # ...and never symlink ~/.local/bin/omdrop: it is on PATH from the system
    substituteInPlace bin/omdrop \
      --replace-fail '[[ -z "$current" || "$current" == */plugins/*/bin/omdrop ]]; then' \
                     '[[ -z "$current" || "$current" == */plugins/*/bin/omdrop ]] && false; then' \
      --replace-fail 'elif [[ "$current" != "$plugin/bin/omdrop" ]]; then' \
                     'elif false; then'

    # PATH for pkexec / user-unit contexts
    substituteInPlace bin/omdrop \
      --replace-fail 'set -uo pipefail' 'set -uo pipefail
export PATH=${runtimePath}:"$PATH"
export GI_TYPELIB_PATH=${glib.out}/lib/girepository-1.0''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}'

    sed -i '1s|^#!.*bash.*|#!${bash}/bin/bash|' bin/omdrop
    for f in bin/*.py; do
      if head -1 "$f" | grep -q '^#!.*python'; then
        sed -i '1s|^#!.*|#!${pythonEnv}/bin/python3|' "$f"
      fi
    done
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r bin share skills docs manifest.json LICENSE README.md $out/
    chmod +x $out/bin/omdrop
    runHook postInstall
  '';

  passthru = { inherit pythonEnv runtimePath; };

  meta = {
    description = "AirDrop CLI and receiver (Omdrop), ported from Omarchy to NixOS";
    homepage = "https://github.com/brentkearney/omdrop-plugin";
    license = lib.licenses.mit;
    mainProgram = "omdrop";
    platforms = lib.platforms.linux;
  };
}
