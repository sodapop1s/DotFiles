#!/usr/bin/env bash
# Steam helper (reads Steam's own library files; no network, no login).
#   steam.sh games     -> JSON [{id, name, lastPlayed, size, update, cover, header}] installed games, newest played first
#   steam.sh status    -> {steam: bool, running: [appid...]}
#   steam.sh launch <appid>
set -u
ROOT="$HOME/.local/share/Steam"
[ -d "$ROOT" ] || ROOT="$HOME/.steam/steam"

libraries() { # every library folder's steamapps dir
  echo "$ROOT/steamapps"
  [ -f "$ROOT/steamapps/libraryfolders.vdf" ] && sed -n 's/^\s*"path"\s*"\(.*\)"\s*$/\1\/steamapps/p' "$ROOT/steamapps/libraryfolders.vdf"
}
kv() { sed -n "s/^[[:space:]]*\"$1\"[[:space:]]*\"\(.*\)\"[[:space:]]*\$/\1/p" "$2" | head -n 1; }

case ${1:-} in
  games)
    libraries | sort -u | while read -r lib; do
      for f in "$lib"/appmanifest_*.acf; do
        [ -f "$f" ] || continue
        id=$(kv appid "$f"); name=$(kv name "$f")
        case $name in Proton*|"Steam Linux Runtime"*|"Steamworks Common"*|"SteamVR"*) continue ;; esac
        cache="$ROOT/appcache/librarycache/$id"
        cover=$(find "$cache" -maxdepth 2 -name 'library_600x900.jpg' 2>/dev/null | head -n 1)
        header=$(find "$cache" -maxdepth 2 -name 'header.jpg' 2>/dev/null | head -n 1)
        jq -cn --arg id "$id" --arg name "$name" --arg lp "$(kv LastPlayed "$f")" --arg size "$(kv SizeOnDisk "$f")" \
               --arg flags "$(kv StateFlags "$f")" --arg cover "$cover" --arg header "$header" \
          '{id:$id, name:$name, lastPlayed:($lp|tonumber? // 0), size:($size|tonumber? // 0),
            update: ((($flags|tonumber? // 4) % 4) >= 2), installed: ((($flags|tonumber? // 4) % 8) >= 4),
            cover:$cover, header:$header}'
      done
    done | jq -s -c 'sort_by(-.lastPlayed)' ;;
  status)
    running=$(pgrep -af 'reaper SteamLaunch AppId=' 2>/dev/null | sed -n 's/.*AppId=\([0-9]*\).*/\1/p' | sort -u | jq -R -s -c 'split("\n")|map(select(length>0))')
    jq -cn --argjson r "${running:-[]}" --argjson s "$(pgrep -x steam >/dev/null && echo true || echo false)" '{steam:$s, running:$r}' ;;
  launch)
    id=${2:?appid}; case $id in *[!0-9]*) echo '{"error":"bad appid"}'; exit 1 ;; esac
    setsid -f steam "steam://rungameid/$id" >/dev/null 2>&1 < /dev/null
    echo '{"ok":true}' ;;
  *) echo '{"error":"usage: steam.sh games|status|launch <appid>"}'; exit 1 ;;
esac
