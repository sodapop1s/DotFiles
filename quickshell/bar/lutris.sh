#!/usr/bin/env bash
# Lutris helper (reads Lutris's own game database; needs bash, jq, and sqlite3 or python3).
#   lutris.sh games        -> JSON [{id, name, slug, runner, platform, lastPlayed, playtime, art}] installed games, newest played first
#   lutris.sh status       -> {lutris: bool, running: [name...]}
#   lutris.sh launch <id>
#   lutris.sh open         -> start the Lutris window (to add or install games)
# QS_LUTRIS_DATA overrides the data folder (used for testing).
set -u
DATA=${QS_LUTRIS_DATA:-$HOME/.local/share/lutris}
DB="$DATA/pga.db"
SQL="select id,name,slug,runner,platform,coalesce(lastplayed,0) as lastplayed,coalesce(playtime,0) as playtime from games where installed=1"

rows() { # the query as a JSON array
  if command -v sqlite3 >/dev/null 2>&1; then sqlite3 -readonly -json "$DB" "$SQL" 2>/dev/null
  else python3 - "$DB" "$SQL" <<'PY' 2>/dev/null
import sqlite3, sys, json
c = sqlite3.connect("file:%s?mode=ro" % sys.argv[1], uri=True); c.row_factory = sqlite3.Row
print(json.dumps([dict(r) for r in c.execute(sys.argv[2])]))
PY
  fi
}

case ${1:-} in
  games)
    [ -f "$DB" ] || { echo '[]'; exit 0; }
    r=$(rows); [ -n "$r" ] || r='[]'
    # artwork: the cover if Lutris has one, else the banner, else nothing (the card shows an icon)
    jq -c --arg d "$DATA" '
      map({id:(.id|tostring), name, slug, runner:(.runner // ""), platform:(.platform // ""),
           lastPlayed:(.lastplayed // 0), playtime:(.playtime // 0),
           cover:($d + "/coverart/" + .slug + ".jpg"), banner:($d + "/banners/" + .slug + ".jpg")})
      | sort_by(-.lastPlayed)' <<<"$r" \
    | jq -c '.[]' | while read -r g; do
        c=$(jq -r .cover <<<"$g"); b=$(jq -r .banner <<<"$g")
        art=""; [ -f "$c" ] && art=$c || { [ -f "$b" ] && art=$b; }
        jq -c --arg a "$art" '. + {art:$a} | del(.cover, .banner)' <<<"$g"
      done | jq -s -c '.' ;;
  status)
    names=$(pgrep -af '^lutris-wrapper: ' 2>/dev/null | sed -n 's/.*lutris-wrapper: *//p' | sort -u | jq -R -s -c 'split("\n")|map(select(length>0))')
    jq -cn --argjson r "${names:-[]}" --argjson s "$(pgrep -f '(^|/)\.?lutris(-wrapped)?( |$)' >/dev/null && echo true || echo false)" '{lutris:$s, running:$r}' ;;
  launch)
    id=${2:?id}; case $id in *[!0-9]*) echo '{"error":"bad game id"}'; exit 1 ;; esac
    setsid -f lutris "lutris:rungameid/$id" >/dev/null 2>&1 < /dev/null
    echo '{"ok":true}' ;;
  open)
    setsid -f lutris >/dev/null 2>&1 < /dev/null
    echo '{"ok":true}' ;;
  *) echo '{"error":"usage: lutris.sh games|status|launch <id>|open"}'; exit 1 ;;
esac
