#!/usr/bin/env bash
# Canvas LMS helper for the School tab (bash, curl, jq). Read-only: it never submits or changes anything.
#
#   canvas.sh status                    -> {configured, domain}
#   canvas.sh setup <domain>            -> reads the access token from stdin, checks it, saves both  -> {ok, name}
#   canvas.sh logout                    -> forgets the token
#   canvas.sh courses                   -> [{id, name, code, term, score, grade}]
#   canvas.sh due [days]                -> [{id, courseId, course, name, due, points, submitted, graded, score, missing, late, url}]  (next N days, plus missing work)
#   canvas.sh groups <courseId>         -> {weighted, score, grade, groups:[{name, weight, items:[{name, points, score, graded}]}]}
#   canvas.sh announcements             -> [{title, course, posted, url}]  (last 14 days)
#   canvas.sh inbox                     -> {unread}
#
# The domain and token live in ~/.config/qs-bar/ (the token file is readable by you only). The token is only ever sent to
# the domain you gave. QS_CANVAS_BASE / QS_CANVAS_TOKEN override both (used for testing against a fake server).
set -u
DIR="$HOME/.config/qs-bar"
CONF="$DIR/canvas.json"
TOKFILE="$DIR/canvas-token"
fail() { jq -cn --arg e "$1" '{error:$e}'; exit 1; }

BASE=${QS_CANVAS_BASE:-}
[ -n "$BASE" ] || { [ -f "$CONF" ] && BASE=$(jq -r '.domain // empty' "$CONF" 2>/dev/null); }
TOKEN=${QS_CANVAS_TOKEN:-}
[ -n "$TOKEN" ] || { [ -f "$TOKFILE" ] && TOKEN=$(tr -d '[:space:]' < "$TOKFILE"); }
BASE=${BASE%/}

# one page of a Canvas API call; prints the body, and the next page's URL (if any) to $NEXTFILE
NEXTFILE=$(mktemp); trap 'rm -f "$NEXTFILE"' EXIT
get_page() { # url
  local hdr; hdr=$(mktemp)
  curl -s --max-time 30 -D "$hdr" -H "Authorization: Bearer $TOKEN" "$1"
  tr -d '\r' < "$hdr" | sed -n 's/^[Ll]ink:.*<\([^>]*\)>; *rel="next".*/\1/p' > "$NEXTFILE"
  rm -f "$hdr"
}
# every page of a list endpoint, as one JSON array. $1 = path starting with /api/v1/..., with its query string
get_all() {
  local url="$BASE$1" out='[]' body n=0
  while [ -n "$url" ] && [ $n -lt 20 ]; do
    case $url in "$BASE"/*) ;; *) break ;; esac            # never follow a link to another host
    body=$(get_page "$url")
    jq -e 'type=="array"' >/dev/null 2>&1 <<<"$body" || { [ $n -eq 0 ] && { printf '%s' "$body"; return 1; }; break; }
    out=$(jq -c -s '.[0] + .[1]' <(printf '%s' "$out") <(printf '%s' "$body"))
    url=$(head -n 1 "$NEXTFILE"); n=$((n + 1))
  done
  printf '%s' "$out"
}
need_login() { [ -n "$BASE" ] && [ -n "$TOKEN" ] || fail "not-configured"; }
api_error() { jq -r 'if type=="object" then (.errors[0].message // .message // empty) else empty end' 2>/dev/null <<<"$1"; }

case ${1:-} in
  status)
    jq -cn --arg d "$BASE" --argjson c "$([ -n "$BASE" ] && [ -n "$TOKEN" ] && echo true || echo false)" '{configured:$c, domain:$d}' ;;

  setup)
    d=${2:-}; case $d in https://*|http://localhost*|http://127.0.0.1*) ;; *) d="https://${d#http://}" ;; esac
    d=${d%/}
    case $d in http://*[!A-Za-z0-9.:/_-]*|https://*[!A-Za-z0-9.:/_-]*|https://|https:///*) fail "that does not look like a web address" ;; esac
    IFS= read -r tok || true; tok=$(printf '%s' "$tok" | tr -d '[:space:]')
    [ -n "$tok" ] || fail "paste your access token"
    me=$(curl -s --max-time 20 -H "Authorization: Bearer $tok" "$d/api/v1/users/self")
    name=$(jq -r '.name // empty' <<<"$me" 2>/dev/null)
    [ -n "$name" ] || fail "Canvas did not accept that: $(api_error "$me")"
    mkdir -p "$DIR"; chmod 700 "$DIR"
    ( umask 077; printf '%s\n' "$tok" > "$TOKFILE" )
    jq -cn --arg d "$d" '{domain:$d}' > "$CONF"
    jq -cn --arg n "$name" '{ok:true, name:$n}' ;;

  logout) rm -f "$TOKFILE"; jq -cn '{ok:true}' ;;

  courses)
    need_login
    r=$(get_all "/api/v1/courses?enrollment_state=active&include%5B%5D=total_scores&include%5B%5D=term&per_page=100") || fail "$(api_error "$r")"
    # Canvas codes look like "AE-150-001_2027_10.FS": show "AE 150", and drop the code from the front of the name
    jq -c 'map(select(.name != null and (.workflow_state // "available") != "completed")
      | (.course_code // .name) as $raw
      | ($raw | (capture("^(?<d>[A-Za-z]{2,5})[-_ ]?(?<n>[0-9]{2,4})") | (.d | ascii_upcase) + " " + .n) // $raw) as $short
      | {id, name:((.name | ltrimstr($raw) | sub("^[ :_-]+"; "")) | if . == "" then $short else . end), code:$short, term:(.term.name // ""),
         score:(([.enrollments[]? | select(.type=="student") | .computed_current_score][0])),
         grade:(([.enrollments[]? | select(.type=="student") | .computed_current_grade][0]))})' <<<"$r" ;;

  due)
    need_login
    days=${2:-21}; case $days in ''|*[!0-9]*) days=21 ;; esac
    courses=$(bash "$0" courses); jq -e 'type=="array"' >/dev/null 2>&1 <<<"$courses" || { printf '%s\n' "$courses"; exit 1; }
    all='[]'
    while IFS= read -r c; do
      cid=$(jq -r .id <<<"$c"); cname=$(jq -r .code <<<"$c")
      a=$(get_all "/api/v1/courses/$cid/assignments?include%5B%5D=submission&order_by=due_at&per_page=100") || continue
      all=$(jq -c -s --arg cn "$cname" --argjson cid "$cid" --arg base "$BASE" '.[0] + (.[1] | map(select(.due_at != null and (.published // true)) | {
          id, courseId:$cid, course:$cn, name, due:(.due_at | fromdateiso8601), points:(.points_possible // 0),
          submitted:((.submission.workflow_state // "unsubmitted") | . != "unsubmitted"),
          graded:((.submission.workflow_state // "") == "graded"), score:(.submission.score),
          missing:(.submission.missing // false), late:(.submission.late // false),
          url:(.html_url // ($base + "/courses/" + ($cid|tostring) + "/assignments/" + (.id|tostring)))}))' <(printf '%s' "$all") <(printf '%s' "$a"))
    done < <(jq -c '.[]' <<<"$courses")
    now=$(date +%s)
    jq -c --argjson now "$now" --argjson days "$days" '
      map(select((.due >= $now - 86400 * 2 and .due <= $now + 86400 * $days) or (.missing and .due >= $now - 86400 * 45)))
      | map(select((.submitted | not) or .due >= $now))
      | sort_by(.due)' <<<"$all" ;;

  groups)
    need_login
    cid=${2:-}; case $cid in ''|*[!0-9]*) fail "bad course" ;; esac
    course=$(curl -s --max-time 30 -H "Authorization: Bearer $TOKEN" "$BASE/api/v1/courses/$cid?include%5B%5D=total_scores")
    g=$(get_all "/api/v1/courses/$cid/assignment_groups?include%5B%5D=assignments&include%5B%5D=submission&per_page=100") || fail "$(api_error "$g")"
    jq -cn --argjson c "$course" --argjson g "$g" '
      {weighted:($c.apply_assignment_group_weights // false),
       score:([$c.enrollments[]? | select(.type=="student") | .computed_current_score][0]),
       grade:([$c.enrollments[]? | select(.type=="student") | .computed_current_grade][0]),
       groups:[$g[] | {name, weight:(.group_weight // 0),
         items:[.assignments[]? | select(.published // true) | select((.omit_from_final_grade // false) | not) | {name, points:(.points_possible // 0),
                score:(.submission.score), graded:((.submission.workflow_state // "") == "graded" and (.submission.score != null)),
                excused:(.submission.excused // false)}]}]}' ;;

  announcements)
    need_login
    courses=$(bash "$0" courses); jq -e 'type=="array"' >/dev/null 2>&1 <<<"$courses" || { printf '%s\n' "$courses"; exit 1; }
    ctx=$(jq -r 'map("context_codes%5B%5D=course_" + (.id|tostring)) | join("&")' <<<"$courses")
    [ -n "$ctx" ] || { echo '[]'; exit 0; }
    start=$(date -u -d '14 days ago' +%Y-%m-%d)
    a=$(get_all "/api/v1/announcements?$ctx&start_date=$start&per_page=50") || fail "$(api_error "$a")"
    jq -c --argjson cs "$courses" 'map(. as $a | {title, posted:((.posted_at // "1970-01-01T00:00:00Z") | fromdateiso8601),
        course:([$cs[] | select(("course_" + (.id|tostring)) == $a.context_code)][0].code // ""), url:(.html_url // "")}) | sort_by(-.posted)' <<<"$a" ;;

  inbox)
    need_login
    r=$(curl -s --max-time 20 -H "Authorization: Bearer $TOKEN" "$BASE/api/v1/conversations/unread_count")
    jq -c '{unread:((.unread_count // 0) | tonumber)}' <<<"$r" 2>/dev/null || fail "$(api_error "$r")" ;;

  *) fail "usage: canvas.sh status|setup <domain>|logout|courses|due [days]|groups <course>|announcements|inbox" ;;
esac
