#!/usr/bin/env bash
# CKAN (Kerbal Space Program mod manager) helper for the bar. Needs the `ckan` command, jq, and bash.
#
#   ckan.sh status                    -> {ckan, version, instances:[{name,game,version,default,path}], default, steam:{found,path,added}, catalog:{count,at}}
#   ckan.sh add <name> <path>         -> register a KSP folder with CKAN (becomes the default if it is the first)
#   ckan.sh default <name>            -> choose which instance the other commands use
#   ckan.sh update                    -> download the mod catalog -> {ok, count}
#   ckan.sh search <text>             -> [{id, version, name, author, abstract}] compatible mods matching the text
#   ckan.sh featured                  -> the same shape, a hand-picked list of popular mods
#   ckan.sh installed                 -> [{id, version, auto}]
#   ckan.sh show <id>                 -> {id, name, summary, version, authors, license, tags, depends, links:{...}}
#   ckan.sh install <id>...           -> install mods (CKAN resolves dependencies)
#   ckan.sh remove <id>...
#   ckan.sh upgrade [<id>...]         -> upgrade given mods, or everything installed
#   ckan.sh launch                    -> start the game (through Steam when it is the Steam copy)
#
# QS_CKAN_BIN overrides the ckan binary (used for testing).
set -u
# testing only: run CKAN with a different home folder (its config, catalog and instance list live there)
[ -n "${QS_CKAN_HOME:-}" ] && export HOME=$QS_CKAN_HOME
CKAN_BIN=${QS_CKAN_BIN:-$(command -v ckan 2>/dev/null || true)}
fail() { jq -cn --arg e "$1" '{error:$e}'; exit 1; }
[ -n "$CKAN_BIN" ] && [ -x "$CKAN_BIN" ] || fail "ckan-missing"

# run ckan quietly: mono prints thread noise on exit that we never want
ck() { "$CKAN_BIN" "$@" 2>/dev/null; }
CONFIG="$HOME/.local/share/CKAN/config.json"

STEAM_ROOT="$HOME/.local/share/Steam"; [ -d "$STEAM_ROOT" ] || STEAM_ROOT="$HOME/.steam/steam"
steam_ksp_dir() { # first Steam library that has KSP (appid 220200) installed
  local lib
  { echo "$STEAM_ROOT"; sed -n 's/^[[:space:]]*"path"[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$STEAM_ROOT/steamapps/libraryfolders.vdf" 2>/dev/null; } | sort -u | while read -r lib; do
    [ -f "$lib/steamapps/appmanifest_220200.acf" ] || continue
    local dir; dir=$(sed -n 's/^[[:space:]]*"installdir"[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$lib/steamapps/appmanifest_220200.acf" | head -n 1)
    [ -d "$lib/steamapps/common/$dir" ] && { echo "$lib/steamapps/common/$dir"; return; }
  done
}

instances_json() { # from `ckan instance list` (columns are separated by two or more spaces)
  ck instance list | awk 'NR>2 && NF>0' | awk -F'  +' '{p=$5; for(i=6;i<=NF;i++) p=p "  " $i; print $1 "\t" $2 "\t" $3 "\t" $4 "\t" p}' \
    | jq -R -s -c 'split("\n") | map(select(length>0) | split("\t") | {name:.[0], game:.[1], version:.[2], default:(.[3]=="Yes"), path:.[4]})'
}

# lines like "* Id (version) - Name by Author - abstract"  ->  JSON
parse_search() {
  jq -R -s -c 'split("\n") | map(select(startswith("* ")) | capture("^\\* (?<id>\\S+) \\((?<version>[^)]*)\\) - (?<rest>.*)$")
      | . + ((.rest | capture("^(?<name>.*?) by (?<author>.*?) - (?<abstract>.*)$")) // {name:.rest, author:"", abstract:""}) | del(.rest))'
}

# id -> name/author/abstract for the whole catalog; rebuilt when the catalog is newer than it (one `ckan search` run)
INDEX="$HOME/.cache/qs-bar-ckan-index.json"
index() {
  # rebuilt when missing, tiny (a failed earlier build), or older than the catalog; a failed build is never kept
  local cat; cat=$(ls -t "$HOME"/.local/share/CKAN/repos/*-KSP-default.json 2>/dev/null | head -n 1)
  local size=0; [ -s "$INDEX" ] && size=$(stat -c %s "$INDEX")
  if [ "$size" -lt 1000 ] || { [ -n "$cat" ] && [ "$cat" -nt "$INDEX" ]; }; then
    mkdir -p "$(dirname "$INDEX")"
    if ck search --detail --headless "e" | parse_search | jq -c 'map({key:.id, value:.}) | from_entries' > "$INDEX.tmp" 2>/dev/null \
       && [ "$(jq 'length' "$INDEX.tmp" 2>/dev/null || echo 0)" -gt 100 ]; then
      mv "$INDEX.tmp" "$INDEX"
    else
      rm -f "$INDEX.tmp"; echo '{}'; return
    fi
  fi
  cat "$INDEX"
}

case ${1:-} in
  status)
    ver=$("$CKAN_BIN" version 2>/dev/null | head -n 1)
    inst=$(instances_json); [ -n "$inst" ] || inst='[]'
    sp=$(steam_ksp_dir)
    added=false
    [ -n "$sp" ] && jq -e --arg p "$sp" 'any(.[]; .path == $p)' <<<"$inst" >/dev/null 2>&1 && added=true
    # when the mod catalog was last downloaded (CKAN keeps one big file per repository)
    cat_at=$(stat -c %Y "$HOME"/.local/share/CKAN/repos/*-KSP-default.json 2>/dev/null | sort -n | tail -n 1)
    cat_at=${cat_at:-0}
    jq -cn --arg v "$ver" --argjson i "$inst" --arg sp "$sp" --argjson added "$added" --argjson at "$cat_at" '
      {ckan:true, version:$v, instances:$i, default:([$i[]|select(.default)][0].name // ""),
       steam:{found:($sp != ""), path:$sp, added:$added}, catalog:{at:$at}}' ;;

  add)
    name=${2:-}; path=${3:-}
    [ -n "$name" ] && [ -d "$path" ] || fail "give a name and an existing folder"
    out=$(ck instance add "$name" "$path") || true
    n=$(instances_json | jq 'length')
    [ "$n" -le 1 ] && ck instance default "$name" >/dev/null
    instances_json | jq -e --arg n "$name" 'any(.[]; .name==$n)' >/dev/null && jq -cn '{ok:true}' || fail "CKAN did not accept that folder: $(printf '%s' "$out" | tail -n 1)" ;;

  default) [ -n "${2:-}" ] || fail "no name"; ck instance default "$2" >/dev/null; jq -cn '{ok:true}' ;;

  update)
    out=$(ck update) || true
    cnt=$(printf '%s' "$out" | sed -n 's/.*Updated information on \([0-9]*\) modules.*/\1/p' | tail -n 1)
    [ -n "$cnt" ] && jq -cn --argjson c "$cnt" '{ok:true,count:$c}' || fail "could not download the mod catalog" ;;

  search)
    q=${2:-}; [ ${#q} -ge 2 ] || fail "type at least two letters"
    ck search --detail --headless "$q" | parse_search ;;

  featured)
    ids='ModuleManager MechJeb2 KerbalEngineerRedux KerbalAlarmClock Scatterer Waterfall DistantObject CommunityTechTree BetterBurnTime ClickThroughBlocker TweakScale PreciseNode KerbalKonstructs Kopernicus ScienceAlert RCSBuildAid DockingPortAlignmentIndicator Toolbar AstronomersVisualPack EnvironmentalVisualEnhancements SmokeScreen RealPlume KerbinSideRemastered StockVisualEnhancements'
    index | jq -c --arg ids "$ids" '. as $i | ($ids | split(" ")) | map($i[.]) | map(select(.))' ;;

  installed)
    index >/dev/null
    ck list --porcelain --headless | awk 'NF>=2' | jq -R -s -c --slurpfile idx "$INDEX" '
      ($idx[0] // {}) as $i
      | split("\n") | map(select(length>0) | split(" ") | {flag:.[0], id:.[1], version:(.[2] // "")}
        | . + {auto:(.flag == "+"), upgrade:(.flag == "^"), name:($i[.id].name // .id), author:($i[.id].author // ""), abstract:($i[.id].abstract // "")})' ;;

  show)
    id=${2:-}; case $id in ''|*[!0-9A-Za-z_.-]*) fail "bad mod id" ;; esac
    out=$(ck show --without-files --headless "$id") || fail "no such mod"
    [ -n "$out" ] || fail "no such mod"
    jq -R -s -c --arg id "$id" '
      split("\n") as $l
      | def field($k): ([$l[] | select(test("^[[:space:]]+"+$k+":"))][0] // "" | sub("^[[:space:]]+"+$k+":[[:space:]]*"; ""));
      { id:$id, name:($l[0] | split(": ")[0]), summary:($l[0] | sub("^[^:]*: ?"; "")),
        version:field("Version"), authors:field("Authors"), status:field("Status"), license:field("License"), tags:field("Tags"),
        depends:([$l | to_entries[] | select(.value == "Depends:") | .key] as $k | if ($k|length)>0 then [$l[($k[0]+1):][] | select(startswith("  - ")) | sub("^  - ";"")] else [] end),
        home:field("Home page"), repository:field("Repository"), manual:field("Manual") }' <<<"$out" ;;

  install)
    shift; [ $# -gt 0 ] || fail "no mods given"
    for m in "$@"; do case $m in ''|*[!0-9A-Za-z_.-]*) fail "bad mod id: $m" ;; esac; done
    out=$("$CKAN_BIN" install --headless --no-recommends "$@" 2>&1); rc=$?
    if [ $rc -eq 0 ] && ! printf '%s' "$out" | grep -qiE 'error|not (compatible|found)|could not|failed'; then jq -cn --arg o "$(printf '%s' "$out" | grep -v abort_threads | tail -n 4)" '{ok:true, log:$o}'
    else fail "$(printf '%s' "$out" | grep -v abort_threads | grep -iE 'error|not|could|fail|conflict|depend' | head -n 2 | tr '\n' ' ')"; fi ;;

  remove)
    shift; [ $# -gt 0 ] || fail "no mods given"
    for m in "$@"; do case $m in ''|*[!0-9A-Za-z_.-]*) fail "bad mod id: $m" ;; esac; done
    out=$("$CKAN_BIN" remove --headless "$@" 2>&1); rc=$?
    [ $rc -eq 0 ] && jq -cn '{ok:true}' || fail "$(printf '%s' "$out" | grep -v abort_threads | tail -n 2 | tr '\n' ' ')" ;;

  upgrade)
    shift
    if [ $# -eq 0 ]; then args=(--all); else args=("$@"); fi
    out=$("$CKAN_BIN" upgrade --headless "${args[@]}" 2>&1); rc=$?
    [ $rc -eq 0 ] && jq -cn '{ok:true}' || fail "$(printf '%s' "$out" | grep -v abort_threads | tail -n 2 | tr '\n' ' ')" ;;

  launch)
    path=$(instances_json | jq -r '[.[]|select(.default)][0].path // empty')
    [ -n "$path" ] || fail "no KSP instance selected"
    sp=$(steam_ksp_dir)
    if [ -n "$sp" ] && [ "$sp" = "$path" ]; then setsid -f steam "steam://rungameid/220200" >/dev/null 2>&1 < /dev/null
    elif [ -x "$path/KSP.x86_64" ]; then (cd "$path" && setsid -f ./KSP.x86_64 >/dev/null 2>&1 < /dev/null)
    else fail "could not find the game to start"; fi
    jq -cn '{ok:true}' ;;

  *) fail "usage: ckan.sh status|add|default|update|search|featured|installed|show|install|remove|upgrade|launch" ;;
esac
