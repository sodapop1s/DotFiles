#!/usr/bin/env bash
# Spotify Web API helper for the Quickshell bar (needs only bash, curl, jq).
# Login is done once with spotify-login.py; its token lives in ~/.local/state/qs-bar-spotify.json
#
#   playlists                    your playlists
#   albums                       your saved albums
#   search <query>               {tracks, albums, artists, playlists}
#   tracks playlist|album <id>   tracks of a playlist / album
#   tracks liked                 your liked songs
#   queue                        {current, queue:[...]}
#   devices                      Connect devices
#   nowline                      Status Pos Len ... (tab-separated, see below), empty when idle
#   play <context-uri> [track-uri]   start a playlist/album/artist (optionally at a track) on the player
#   play-uris <index> <uri>...   play a list of tracks, starting at <index>
#   control playpause|next|prev|seek <ms>|shuffle on|off|repeat off|context|track|volume <0-100>
#   control transfer <device-id>|queue <uri>|like <track-id>|unlike <track-id>|liked <track-id>
#   raw METHOD PATH [json]       debugging
set -u
STATE="$HOME/.local/state/qs-bar-spotify.json"
CONF="$HOME/.config/spotify-player/app.toml"
DEVICE_NAME="spotify-player"

fail() { jq -cn --arg e "$1" '{error: $e}'; exit 1; }

[ -f "$STATE" ] || fail "not logged in: run spotify-login.py"
CLIENT_ID=$(sed -n 's/^client_id *= *"\([^"]*\)".*/\1/p' "$CONF" 2>/dev/null | head -n 1)
[ -n "$CLIENT_ID" ] || fail "no client_id in spotify-player app.toml"

access_token() {
  local exp now tok resp
  exp=$(jq -r '.expires_at // 0 | floor' "$STATE"); now=$(date +%s)
  if [ "$exp" -gt $((now + 60)) ]; then jq -r .access_token "$STATE"; return; fi
  resp=$(curl -s --max-time 10 -X POST https://accounts.spotify.com/api/token \
    -d grant_type=refresh_token -d client_id="$CLIENT_ID" \
    --data-urlencode refresh_token="$(jq -r .refresh_token "$STATE")") || fail "network error"
  tok=$(jq -r '.access_token // empty' <<<"$resp")
  [ -n "$tok" ] || fail "login expired - run spotify-login.py ($(jq -r '.error_description // .error // "unknown"' <<<"$resp"))"
  jq --argjson r "$resp" --argjson now "$now" \
     '.access_token=$r.access_token | .expires_at=($now + ($r.expires_in // 3600)) | (if $r.refresh_token then .refresh_token=$r.refresh_token else . end)' \
     "$STATE" > "$STATE.tmp" && chmod 600 "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
  echo "$tok"
}

# api METHOD PATH [JSON-BODY]  -> prints body, fails with Spotify's message on HTTP errors
api() {
  local method=$1 path=$2 body=${3:-} tok out code url
  tok=$(access_token) || exit 1
  case $path in http*) url=$path ;; *) url="https://api.spotify.com/v1$path" ;; esac
  if [ -n "$body" ]; then
    out=$(curl -s --max-time 10 -w '\n%{http_code}' -X "$method" -H "Authorization: Bearer $tok" -H 'Content-Type: application/json' -d "$body" "$url") || fail "network error"
  else
    out=$(curl -s --max-time 10 -w '\n%{http_code}' -X "$method" -H "Authorization: Bearer $tok" "$url") || fail "network error"
  fi
  code=${out##*$'\n'}; out=${out%$'\n'*}
  case $code in 2*) printf '%s' "$out" ;; *) fail "$code: $(jq -r '.error.message // .error // "request failed"' <<<"$out" 2>/dev/null)" ;; esac
}

enc() { jq -rn --arg s "$1" '$s|@uri'; }

# ---- jq normalizers: every list item has uri, id, name, plus sub (subtitle) and image
IMG='((.images // []) | (.[1] // .[0] // {}) | .url // "")'
J_TRACK='{kind:"track", uri, id, name, sub:((.artists // [])|map(.name)|join(", ")), image:((.album.images // [])|(.[1] // .[0] // {})|.url // ""), dur:(.duration_ms // 0)}'
J_ALBUM='{kind:"album", uri, id, name, sub:((.artists // [])|map(.name)|join(", ")), image:'"$IMG"'}'
J_ARTIST='{kind:"artist", uri, id, name, sub:"artist", image:'"$IMG"'}'
J_PLAYLIST='{kind:"playlist", uri, id, name:(.name // "(untitled)"), sub:((.owner.display_name // "") + (((.tracks // .items // {}) | .total?) as $t | if $t != null then "  ·  \($t) tracks" else "" end)), image:'"$IMG"'}'

paged() { # paged PATH JQ-FILTER MAX-ITEMS -> JSON array (pages are streamed through a temp file)
  local url=$1 filt=$2 max=${3:-200} tmp page n=0 got
  tmp=$(mktemp) || fail "no temp file"
  while [ -n "$url" ] && [ "$url" != null ] && [ "$n" -lt "$max" ]; do
    page=$(api GET "$url") || { rm -f "$tmp"; exit 1; }
    got=$(jq -c "[ .items[]? | $filt | select(.uri) ]" <<<"$page") || { rm -f "$tmp"; fail "unexpected response"; }
    printf '%s\n' "$got" >> "$tmp"
    n=$((n + $(jq 'length' <<<"$got")))
    url=$(jq -r '.next // empty' <<<"$page")
  done
  jq -cs 'add // []' "$tmp"; rm -f "$tmp"
}

case ${1:-} in
  playlists) paged "/me/playlists?limit=50" "select(.) | $J_PLAYLIST" 200 ;;
  albums)    paged "/me/albums?limit=50" ".album | $J_ALBUM" 200 ;;
  search)
    q=${2:-}; [ -n "$q" ] || fail "usage: spotify.sh search <query>"
    api GET "/search?q=$(enc "$q")&type=track,album,artist,playlist&limit=8" | jq -c "{
      tracks:    [.tracks.items[]?    | select(.) | $J_TRACK],
      albums:    [.albums.items[]?    | select(.) | $J_ALBUM],
      artists:   [.artists.items[]?   | select(.) | $J_ARTIST],
      playlists: [.playlists.items[]? | select(.) | $J_PLAYLIST] }" ;;
  tracks)
    case ${2:-} in
      playlist) paged "/playlists/${3:?id}/items?limit=100" ".item | select(.type == \"track\") | $J_TRACK" 300 ;;
      album)    img=$(api GET "/albums/${3:?id}" | jq -r "$IMG") || exit 1
                paged "/albums/$3/tracks?limit=50" "$J_TRACK | .image = \"$img\"" 300 ;;
      liked)    paged "/me/tracks?limit=50" ".track | $J_TRACK" 200 ;;
      *) fail "usage: spotify.sh tracks playlist|album <id> | liked" ;;
    esac ;;
  queue)
    api GET /me/player/queue | jq -c "{current: (.currently_playing | if . then $J_TRACK else null end), queue: [.queue[]? | select(.type == \"track\") | $J_TRACK]}" ;;
  devices) api GET /me/player/devices | jq -c '.devices' ;;
  nowline)
    # Status Title Artist PosMs LenMs Shuffle Repeat Volume TrackId Device  (tab-separated)
    out=$(api GET "/me/player?additional_types=episode") || exit 1
    [ -n "$out" ] || exit 0
    jq -r 'if .item then [(if .is_playing then "Playing" else "Paused" end), (.item.name // ""),
           ((.item.artists // [.item.show] // []) | map(.name // "") | join(", ")),
           (.progress_ms // 0), (.item.duration_ms // 0), (.shuffle_state // false), (.repeat_state // "off"),
           (.device.volume_percent // 0), (.item.id // ""), (.device.name // "")] | @tsv else empty end' <<<"$out" ;;
  play)
    ctx=${2:-}; [ -n "$ctx" ] || fail "usage: spotify.sh play <context-uri> [track-uri]"
    dev=$(api GET /me/player/devices | jq -r --arg n "$DEVICE_NAME" '(if type=="array" then . else (.devices // []) end) | map(select(.name==$n))[0].id // empty')
    [ -n "$dev" ] || fail "player device not found - is spotify_player running?"
    case $ctx in
      *:track:*) body=$(jq -cn --arg u "$ctx" '{uris:[$u]}') ;;
      *) if [ -n "${3:-}" ]; then body=$(jq -cn --arg c "$ctx" --arg t "$3" '{context_uri:$c, offset:{uri:$t}}')
         else body=$(jq -cn --arg c "$ctx" '{context_uri:$c}'); fi ;;
    esac
    api PUT "/me/player/play?device_id=$dev" "$body" >/dev/null || exit 1
    echo '{"ok":true}' ;;
  play-uris)
    idx=${2:-0}; shift 2 2>/dev/null || fail "usage: spotify.sh play-uris <index> <uri>..."
    dev=$(api GET /me/player/devices | jq -r --arg n "$DEVICE_NAME" '(if type=="array" then . else (.devices // []) end) | map(select(.name==$n))[0].id // empty')
    [ -n "$dev" ] || fail "player device not found - is spotify_player running?"
    body=$(jq -cn --argjson i "$idx" '{uris: $ARGS.positional, offset:{position:$i}}' --args "$@")
    api PUT "/me/player/play?device_id=$dev" "$body" >/dev/null || exit 1
    echo '{"ok":true}' ;;
  control)
    case ${2:-} in
      playpause)
        playing=$(api GET /me/player | jq -r '.is_playing // false' 2>/dev/null)
        if [ "$playing" = true ]; then api PUT /me/player/pause '{}' >/dev/null || exit 1
        else api PUT /me/player/play '{}' >/dev/null || exit 1; fi ;;
      next)    api POST /me/player/next '{}' >/dev/null || exit 1 ;;
      prev)    api POST /me/player/previous '{}' >/dev/null || exit 1 ;;
      seek)    case ${3:-} in ''|*[!0-9]*) fail "usage: control seek <ms>" ;; esac
               api PUT "/me/player/seek?position_ms=$3" '{}' >/dev/null || exit 1 ;;
      shuffle) case ${3:-} in on) st=true ;; off) st=false ;; *) fail "usage: control shuffle on|off" ;; esac
               api PUT "/me/player/shuffle?state=$st" '{}' >/dev/null || exit 1 ;;
      repeat)  case ${3:-} in off|context|track) ;; *) fail "usage: control repeat off|context|track" ;; esac
               api PUT "/me/player/repeat?state=$3" '{}' >/dev/null || exit 1 ;;
      volume)  case ${3:-} in ''|*[!0-9]*) fail "usage: control volume <0-100>" ;; esac
               api PUT "/me/player/volume?volume_percent=$3" '{}' >/dev/null || exit 1 ;;
      transfer) api PUT /me/player "$(jq -cn --arg d "${3:?device id}" '{device_ids:[$d], play:true}')" >/dev/null || exit 1 ;;
      queue)   api POST "/me/player/queue?uri=$(enc "${3:?uri}")" '{}' >/dev/null || exit 1 ;;
      like)    api PUT "/me/library?uris=$(enc "spotify:track:${3:?id}")" '{}' >/dev/null || exit 1 ;;
      unlike)  api DELETE "/me/library?uris=$(enc "spotify:track:${3:?id}")" '{}' >/dev/null || exit 1 ;;
      liked)   api GET "/me/library/contains?uris=$(enc "spotify:track:${3:?id}")" | jq -c '.[0]' ; exit 0 ;;
      *) fail "unknown control" ;;
    esac
    echo '{"ok":true}' ;;
  raw) api "${2:?method}" "${3:?path}" "${4:-}" ;;
  *) fail "usage: spotify.sh playlists|albums|search|tracks|queue|devices|nowline|play|play-uris|control" ;;
esac
