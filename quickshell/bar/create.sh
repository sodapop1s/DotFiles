#!/usr/bin/env bash
# Create a Prism Launcher instance (bash, jq, curl).
#
#   create.sh versions                      -> [{version, releaseTime}] release versions, newest first
#   create.sh loaders <mc>                  -> {fabric, quilt, neoforge, forge, java, javaPath}  (null = not available)
#   create.sh presets                       -> starter mod lists (edit ~/.config/qs-bar/mod-presets.json)
#   create.sh create <name> <mc> <loader>   -> make the instance (loader: fabric|quilt|neoforge|forge|vanilla)
#
# Versions and loader versions come from Prism's own metadata service, so the instance matches what
# Prism would create itself. Mods are added afterwards with mods.sh.
set -u
ROOT=${QS_PRISM_ROOT:-}
if [ -z "$ROOT" ]; then
  for d in "$HOME/.local/share/PrismLauncher" "$HOME/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher"; do
    [ -d "$d/instances" ] && ROOT=$d && break
  done
fi
META=https://meta.prismlauncher.org/v1
CACHE_DIR="$HOME/.cache"
PRESETS="$HOME/.config/qs-bar/mod-presets.json"

fail() { jq -cn --arg e "$1" '{error:$e}'; exit 1; }
[ -n "$ROOT" ] || fail "Prism Launcher folder not found"
meta() { # cached for an hour
  local f="$CACHE_DIR/qs-bar-meta-$(printf '%s' "$1" | tr '/.' '__').json"
  if [ ! -s "$f" ] || [ $(( $(date +%s) - $(stat -c %Y "$f") )) -gt 3600 ]; then
    curl -sf --max-time 20 "$META/$1" -o "$f.tmp" && jq -e . "$f.tmp" >/dev/null 2>&1 && mv "$f.tmp" "$f" || { rm -f "$f.tmp"; [ -s "$f" ] || return 1; }
  fi
  cat "$f"
}

# newest version of a loader component that is not a beta/rc/pre-release; prefers Prism's "recommended"
pick() { # index.json-on-stdin [equals-mc] -> version or empty
  jq -r --arg mc "${1:-}" '
    [.versions[] | select($mc == "" or (.requires // [] | any(.uid == "net.minecraft" and .equals == $mc)))] as $all
    | ([$all[] | select(.recommended == true)][0].version
       // [$all[] | select(.version | test("beta|alpha|rc|pre|snapshot"; "i") | not)][0].version
       // $all[0].version // empty)'
}

java_for() { # major -> path of a JDK with that major, taken from existing instances (empty if none)
  local major=$1 f p
  for f in "$ROOT"/instances/*/instance.cfg; do
    [ -f "$f" ] || continue
    p=$(sed -n 's/^JavaPath=\(.*\)$/\1/p' "$f" | head -n 1)
    case $p in *"openjdk-$major."*|*"jdk-$major"*|*"temurin-$major"*) [ -x "$p" ] && { echo "$p"; return; } ;; esac
  done
  for p in /nix/store/*-openjdk-"$major".*/bin/java /usr/lib/jvm/*"$major"*/bin/java; do [ -x "$p" ] && { echo "$p"; return; }; done
}

case ${1:-} in
  versions)
    f="$CACHE_DIR/qs-bar-mcversions.json"
    if [ ! -s "$f" ] || [ $(( $(date +%s) - $(stat -c %Y "$f") )) -gt 21600 ]; then
      meta net.minecraft/index.json | jq -c '[.versions[] | select(.type=="release") | {version, releaseTime}] | sort_by(.releaseTime) | reverse | .[0:40]' > "$f.tmp" \
        && mv "$f.tmp" "$f" || { rm -f "$f.tmp"; [ -s "$f" ] || fail "could not reach Prism's version service"; }
    fi
    cat "$f" ;;

  loaders)
    mc=${2:?mc version}
    inter=$(meta net.fabricmc.intermediary/index.json | jq -r --arg mc "$mc" '[.versions[]|select(.version==$mc)]|length') || inter=0
    fab=""; qui=""
    if [ "${inter:-0}" -gt 0 ]; then
      fab=$(meta net.fabricmc.fabric-loader/index.json | pick)
      qui=$(meta org.quiltmc.quilt-loader/index.json | pick)
    fi
    neo=$(meta net.neoforged/index.json | pick "$mc"); frg=$(meta net.minecraftforge/index.json | pick "$mc")
    major=$(meta "net.minecraft/$mc.json" | jq -r '(.compatibleJavaMajors // []) | max // empty')
    jp=""; [ -n "$major" ] && jp=$(java_for "$major")
    jq -cn --arg f "$fab" --arg q "$qui" --arg n "$neo" --arg g "$frg" --arg m "$major" --arg jp "$jp" '
      {fabric:($f|select(.!="")), quilt:($q|select(.!="")), neoforge:($n|select(.!="")), forge:($g|select(.!="")),
       java:($m|select(.!="")|tonumber), javaPath:($jp|select(.!=""))}' ;;

  presets)
    if [ ! -s "$PRESETS" ]; then
      mkdir -p "$(dirname "$PRESETS")"
      cat > "$PRESETS" <<'JSON'
{
  "fabric": [
    { "slug": "fabric-api",      "label": "Fabric API",      "note": "Required by most Fabric mods",      "default": true },
    { "slug": "sodium",          "label": "Sodium",          "note": "Much faster rendering",             "default": true },
    { "slug": "lithium",         "label": "Lithium",         "note": "Game logic optimisation",           "default": true },
    { "slug": "modmenu",         "label": "Mod Menu",        "note": "Lists your mods in-game",           "default": true },
    { "slug": "ferrite-core",    "label": "FerriteCore",     "note": "Lower memory use",                  "default": true },
    { "slug": "entityculling",   "label": "Entity Culling",  "note": "Skips entities you cannot see",     "default": true },
    { "slug": "immediatelyfast", "label": "ImmediatelyFast", "note": "Faster HUD and menus",              "default": true },
    { "slug": "iris",            "label": "Iris Shaders",    "note": "Shader pack support",               "default": false },
    { "slug": "dynamic-fps",     "label": "Dynamic FPS",     "note": "Saves power when unfocused",        "default": false },
    { "slug": "appleskin",       "label": "AppleSkin",       "note": "Food and saturation info",          "default": false },
    { "slug": "no-chat-reports", "label": "No Chat Reports", "note": "Turns off chat signing",            "default": false }
  ],
  "neoforge": [
    { "slug": "sodium",          "label": "Sodium",          "note": "Much faster rendering",             "default": true },
    { "slug": "ferrite-core",    "label": "FerriteCore",     "note": "Lower memory use",                  "default": true },
    { "slug": "entityculling",   "label": "Entity Culling",  "note": "Skips entities you cannot see",     "default": true },
    { "slug": "immediatelyfast", "label": "ImmediatelyFast", "note": "Faster HUD and menus",              "default": true },
    { "slug": "iris",            "label": "Iris Shaders",    "note": "Shader pack support",               "default": false }
  ],
  "forge": [
    { "slug": "ferrite-core",    "label": "FerriteCore",     "note": "Lower memory use",                  "default": true },
    { "slug": "entityculling",   "label": "Entity Culling",  "note": "Skips entities you cannot see",     "default": true }
  ]
}
JSON
    fi
    jq -c . "$PRESETS" 2>/dev/null || fail "mod-presets.json is not valid JSON" ;;

  create)
    name=${2:-}; mc=${3:-}; loader=${4:-}
    name=$(printf '%s' "$name" | tr -d '\000-\037' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -n "$name" ] && [ ${#name} -le 64 ] || fail "give the instance a name (up to 64 characters)"
    case $mc in ''|*[!0-9A-Za-z._-]*) fail "bad Minecraft version" ;; esac
    case $loader in fabric|quilt|neoforge|forge|vanilla) ;; *) fail "unknown loader" ;; esac
    mcmeta=$(meta "net.minecraft/$mc.json") || fail "Prism has no data for Minecraft $mc"

    # folder name: letters, digits, space . _ - ; made unique
    base=$(printf '%s' "$name" | tr -c 'A-Za-z0-9 ._-' '_' | sed 's/^[._ ]*//')
    [ -n "$base" ] || base="instance"
    id=$base; n=2
    while [ -e "$ROOT/instances/$id" ]; do id="$base ($n)"; n=$((n + 1)); done

    case $loader in
      fabric)   lv=$(meta net.fabricmc.fabric-loader/index.json | pick); luid=net.fabricmc.fabric-loader ;;
      quilt)    lv=$(meta org.quiltmc.quilt-loader/index.json | pick);   luid=org.quiltmc.quilt-loader ;;
      neoforge) lv=$(meta net.neoforged/index.json | pick "$mc");        luid=net.neoforged ;;
      forge)    lv=$(meta net.minecraftforge/index.json | pick "$mc");   luid=net.minecraftforge ;;
      vanilla)  lv=""; luid="" ;;
    esac
    [ "$loader" = vanilla ] || [ -n "$lv" ] || fail "no $loader build exists for Minecraft $mc"
    case $loader in fabric|quilt)
      meta net.fabricmc.intermediary/index.json | jq -e --arg mc "$mc" 'any(.versions[]; .version==$mc)' >/dev/null || fail "$loader does not support Minecraft $mc yet" ;;
    esac

    lw=$(jq -r '[.requires[]?|select(.uid=="org.lwjgl3")|.suggests][0] // empty' <<<"$mcmeta")
    pack=$(jq -cn --arg mc "$mc" --arg lw "$lw" --arg luid "$luid" --arg lv "$lv" --arg loader "$loader" '
      [ (if $lw != "" then {uid:"org.lwjgl3", version:$lw, dependencyOnly:true} else empty end),
        {uid:"net.minecraft", version:$mc, important:true},
        (if $loader == "fabric" or $loader == "quilt" then {uid:"net.fabricmc.intermediary", version:$mc, dependencyOnly:true} else empty end),
        (if $luid != "" then {uid:$luid, version:$lv} else empty end) ] | {components:., formatVersion:1}')

    major=$(jq -r '(.compatibleJavaMajors // []) | max // empty' <<<"$mcmeta")
    jp=""; [ -n "$major" ] && jp=$(java_for "$major")

    dir="$ROOT/instances/$id"
    mkdir -p "$dir/minecraft" || fail "could not create the instance folder"
    [ "$loader" = vanilla ] || mkdir -p "$dir/minecraft/mods"
    printf '%s\n' "$pack" | jq . > "$dir/mmc-pack.json"
    {
      echo "[General]"
      echo "ConfigVersion=1.3"
      echo "InstanceType=OneSix"
      echo "iconKey=default"
      echo "name=$name"
      if [ -n "$jp" ]; then echo "OverrideJavaLocation=true"; echo "JavaPath=$jp"; fi
    } > "$dir/instance.cfg"
    jq -cn --arg id "$id" --arg name "$name" --arg mc "$mc" --arg loader "$loader" --arg lv "$lv" --arg jp "$jp" --arg major "$major" \
      '{id:$id, name:$name, mc:$mc, loader:$loader, loaderVersion:$lv, javaMajor:($major|select(.!="")|tonumber), javaPath:$jp}' ;;

  *) fail "usage: create.sh versions|loaders <mc>|presets|create <name> <mc> <loader>" ;;
esac
