#!/usr/bin/env bash
# Prism Launcher helper.
#   prism.sh list           -> JSON [{id, name, display, group, mc, loader, java, icon, lastLaunch, playtime, running}]
#   prism.sh launch <id>
#   prism.sh kill <id>
# Display names come from ~/.config/qs-bar/minecraft-names.json:
#   { "instances": { "<instance folder>": "Display name" }, "versions": { "26.2": "Chaos Cubed" } }
set -u
for d in "$HOME/.local/share/PrismLauncher" "$HOME/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher"; do
  [ -d "$d/instances" ] && ROOT="$d" && break
done
[ -n "${ROOT:-}" ] || { echo '{"error":"Prism Launcher instances folder not found"}'; exit 1; }
NAMES="$HOME/.config/qs-bar/minecraft-names.json"
[ -f "$NAMES" ] || NAMES=/dev/null

cfg() { sed -n "s/^$1=\(.*\)\$/\1/p" "$2" | head -n 1; }

case ${1:-} in
  list)
    for dir in "$ROOT"/instances/*/; do
      id=$(basename "$dir"); c="$dir/instance.cfg"
      [ -f "$c" ] || continue
      name=$(cfg name "$c"); icon=$(cfg iconKey "$c"); jp=$(cfg JavaPath "$c")
      last=$(cfg lastLaunchTime "$c"); played=$(cfg totalTimePlayed "$c")
      mc=""; loader=""
      if [ -f "$dir/mmc-pack.json" ]; then
        mc=$(jq -r '[.components[]|select(.uid=="net.minecraft")|.version][0] // ""' "$dir/mmc-pack.json")
        loader=$(jq -r '[.components[]|select(.uid|test("^net\\.(minecraftforge|neoforged|fabricmc\\.fabric-loader)$|quilt"))|(.uid|sub("^.*\\.";"")) + " " + (.version // "")][0] // ""' "$dir/mmc-pack.json")
      fi
      java=$(printf '%s' "$jp" | sed -n 's/.*openjdk-\([0-9]*\).*/\1/p')
      iconpath=""
      for ext in png svg jpg; do [ -f "$ROOT/icons/$icon.$ext" ] && { iconpath="$ROOT/icons/$icon.$ext"; break; }; done
      running=false; pgrep -f -- "/instances/$id/" >/dev/null 2>&1 && running=true
      jq -cn --arg id "$id" --arg name "$name" --arg icon "$icon" --arg mc "$mc" --arg loader "$loader" --arg java "$java" --arg iconpath "$iconpath" \
             --arg last "${last:-0}" --arg played "${played:-0}" --argjson running "$running" --slurpfile names "$NAMES" '
        ($names[0] // {}) as $n
        | ($name | test("gtnh|gt[ _]new[ _]horizons|daily|nightly"; "i")) as $gtnh
        | (if $n.instances[$id] then $n.instances[$id]
           elif ($name | test("Daily [0-9]+")) then "GTNH Nightly " + ($name | capture("Daily (?<d>[0-9]+)").d)
           elif $gtnh then $name
           elif ($n.versions[$mc] and $name == $mc) then "Minecraft \($mc) “\($n.versions[$mc])”"
           elif ($mc != "" and $name == $mc) then "Minecraft \($mc)"
           else $name end) as $display
        | {id:$id, name:$name, display:$display, group:(if ($gtnh or ($icon|test("gtnh";"i"))) then "GTNH" else "Minecraft" end),
           mc:$mc, loader:$loader, java:$java, icon:$iconpath, lastLaunch:($last|tonumber? // 0), playtime:($played|tonumber? // 0), running:$running}'
    done | jq -s -c 'sort_by(.group, -.lastLaunch)' ;;
  launch)
    id=${2:?instance id}; [ -d "$ROOT/instances/$id" ] || { echo '{"error":"no such instance"}'; exit 1; }
    setsid -f prismlauncher -l "$id" >/dev/null 2>&1 < /dev/null
    echo '{"ok":true}' ;;
  kill)
    id=${2:?instance id}; [ -d "$ROOT/instances/$id" ] || { echo '{"error":"no such instance"}'; exit 1; }
    pkill -f -- "/instances/$id/" && echo '{"ok":true}' || echo '{"error":"not running"}' ;;
  *) echo '{"error":"usage: prism.sh list|launch <id>|kill <id>"}'; exit 1 ;;
esac
