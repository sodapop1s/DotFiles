#!/usr/bin/env bash
# Mod manager helper for Prism Launcher instances (bash, jq, curl, unzip).
#
#   mods.sh summary <instance>                 -> {enabled, disabled, mc, loaders, dir}
#   mods.sh list <instance>                    -> {mods:[...], projects:[...], mc, loaders, dir}
#   mods.sh toggle <instance> <file>           -> enable/disable a mod (renames .jar <-> .jar.disabled)
#   mods.sh search <instance> <query> [offset] -> Modrinth search, filtered to the instance's version/loader
#   mods.sh plan <instance> <project-id>       -> what installing would download (incl. required dependencies)
#   mods.sh install <instance> <project-id>    -> download + verify + install it (and required dependencies)
#   mods.sh updates <instance> [fresh]         -> {checked, items:[{file, project, name, current, latest, filename, size}]}  mods with a newer version (cached for an hour)
#   mods.sh update <instance> <file>           -> replace one mod with its newest version (the old file is kept in ~/.local/state/qs-bar-mod-backups)
#   mods.sh updateall <instance>               -> update everything that has an update
#   mods.sh save <instance> <name>             -> remember this instance's mod list as ~/.config/qs-bar/mod-lists/<name>.json
#   mods.sh lists                              -> [{name, count, mc, loaders}]
#   mods.sh apply <instance> <name>            -> install every mod of a saved list that this instance does not have yet
#   mods.sh droplist <name>                    -> forget a saved list
#
# Disabling follows Prism's own convention: "mod.jar" <-> "mod.jar.disabled".
# Downloads only come from cdn.modrinth.com and are checked against Modrinth's SHA-512.
set -u
ROOT=${QS_PRISM_ROOT:-}
if [ -z "$ROOT" ]; then
  for d in "$HOME/.local/share/PrismLauncher" "$HOME/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher"; do
    [ -d "$d/instances" ] && ROOT=$d && break
  done
fi
API=https://api.modrinth.com/v2
UA="qs-bar-mods/1.0 (personal Quickshell bar)"
CACHE="$HOME/.cache/qs-bar-modinfo"
RECORD="$HOME/.local/state/qs-bar-mods.json"
MAX_BYTES=$((600 * 1024 * 1024))
LISTS="$HOME/.config/qs-bar/mod-lists"
BACKUPS="$HOME/.local/state/qs-bar-mod-backups"

fail() { jq -cn --arg e "$1" '{error:$e}'; exit 1; }
[ -n "$ROOT" ] || fail "Prism Launcher instances folder not found"
mkdir -p "$CACHE"

valid_instance() { case ${1:-} in ''|.|..|*/*) return 1 ;; esac; [ -d "$ROOT/instances/$1" ]; }
valid_file()     { case ${1:-} in ''|*/*|.*) return 1 ;; esac; case $1 in *.jar|*.jar.disabled) return 0 ;; esac; return 1; }
mods_dir() { for m in "$ROOT/instances/$1/minecraft/mods" "$ROOT/instances/$1/.minecraft/mods"; do [ -d "$m" ] && { echo "$m"; return; }; done; echo "$ROOT/instances/$1/minecraft/mods"; }

# game version and loaders (as Modrinth category names) from the instance's mmc-pack.json
mc_version() { jq -r '[.components[]|select(.uid=="net.minecraft")|.version][0] // ""' "$ROOT/instances/$1/mmc-pack.json" 2>/dev/null; }
loaders_json() {
  jq -c '[.components[].uid] | map(
      if . == "org.quiltmc.quilt-loader" then ["quilt","fabric"]
      elif . == "net.fabricmc.fabric-loader" then ["fabric"]
      elif . == "net.neoforged" then ["neoforge"]
      elif . == "net.minecraftforge" then ["forge"]
      else empty end) | add // []' "$ROOT/instances/$1/mmc-pack.json" 2>/dev/null || echo '[]'
}

# ── reading a jar ─────────────────────────────────────────
# prints {id,name,version,desc,iconpath,depends:[],provides:[]} for a jar
read_meta() {
  local jar=$1 fm qm
  fm=$(unzip -p "$jar" fabric.mod.json 2>/dev/null)
  if [ -n "$fm" ] && jq -e . >/dev/null 2>&1 <<<"$fm"; then
    jq -c '{id:(.id // ""), name:(.name // .id // ""), version:((.version // "")|tostring),
            desc:((.description // "")|tostring|.[0:200]),
            iconpath:(if (.icon|type)=="string" then .icon
                      elif (.icon|type)=="object" then (.icon|to_entries|sort_by(.key|tonumber? // 0)|last|.value) else "" end),
            depends:((.depends // {})|keys), provides:((.provides // [])|map(if type=="string" then . else (.id // empty) end))}' <<<"$fm"
    return
  fi
  qm=$(unzip -p "$jar" quilt.mod.json 2>/dev/null)
  if [ -n "$qm" ] && jq -e . >/dev/null 2>&1 <<<"$qm"; then
    jq -c '.quilt_loader as $q | {id:($q.id // ""), name:($q.metadata.name // $q.id // ""), version:(($q.version // "")|tostring),
            desc:(($q.metadata.description // "")|tostring|.[0:200]), iconpath:(($q.metadata.icon // "")|if type=="string" then . else "" end),
            depends:[($q.depends // [])[] | if type=="string" then . else (.id // empty) end],
            provides:[($q.provides // [])[] | if type=="string" then . else (.id // empty) end]}' <<<"$qm"
    return
  fi
  local toml id name ver
  toml=$(unzip -p "$jar" META-INF/mods.toml 2>/dev/null; unzip -p "$jar" META-INF/neoforge.mods.toml 2>/dev/null)
  if [ -n "$toml" ]; then
    id=$(sed -n 's/^[[:space:]]*modId[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' <<<"$toml" | head -n 1)
    name=$(sed -n 's/^[[:space:]]*displayName[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' <<<"$toml" | head -n 1)
    ver=$(sed -n 's/^[[:space:]]*version[[:space:]]*=[[:space:]]*"\([^"$]*\)".*/\1/p' <<<"$toml" | head -n 1)
    jq -cn --arg id "$id" --arg name "${name:-$id}" --arg v "$ver" '{id:$id,name:$name,version:$v,desc:"",iconpath:"",depends:[],provides:[]}'
    return
  fi
  echo '{"id":"","name":"","version":"","desc":"","iconpath":"","depends":[],"provides":[]}'
}

# cached per jar (name+size+mtime); extracts the icon next to it
meta_for() { # path -> JSON with icon (file path or "")
  local f=$1 name size mt key mf
  name=$(basename "$f"); size=$(stat -c %s "$f"); mt=$(stat -c %Y "$f")
  key=$(printf '%s' "$name|$size|$mt" | sha1sum | cut -c1-20)
  mf="$CACHE/$key.json"
  if [ ! -s "$mf" ]; then
    local m ip icon=""
    m=$(read_meta "$f")
    ip=$(jq -r '.iconpath // ""' <<<"$m")
    if [ -n "$ip" ] && unzip -p "$f" "$ip" > "$CACHE/$key.png.tmp" 2>/dev/null && [ -s "$CACHE/$key.png.tmp" ]; then
      mv "$CACHE/$key.png.tmp" "$CACHE/$key.png"; icon="$CACHE/$key.png"
    else rm -f "$CACHE/$key.png.tmp"; fi
    jq -c --arg icon "$icon" '. + {icon:$icon}' <<<"$m" > "$mf.tmp" && mv "$mf.tmp" "$mf"
  fi
  cat "$mf"
}

# Modrinth project ids the instance already has: from Prism's .index and from our own record
known_projects() { # instance -> JSON array
  local md; md=$(mods_dir "$1")
  { [ -d "$md/.index" ] && sed -n "s/^mod-id = '\(.*\)'.*/\1/p" "$md"/.index/*.pw.toml 2>/dev/null
    [ -f "$RECORD" ] && jq -r --arg i "$1" '(.[$i] // {}) | keys[]' "$RECORD" 2>/dev/null
  } | sort -u | jq -R -s -c 'split("\n")|map(select(length>0))'
}

# ── Modrinth ──────────────────────────────────────────────
mr() { curl -s --max-time 20 -H "User-Agent: $UA" "$@"; }

# accepts a Modrinth project id or its slug ("sodium") and prints the project id
project_id() {
  case ${1:-} in ''|*[!0-9A-Za-z_-]*) return 1 ;; esac
  mr "$API/project/$1" | jq -r '.id // empty'
}

# pick the best version of a project for this instance -> JSON version object ("" if none)
best_version() { # project mc loaders
  local resp
  resp=$(mr -G "$API/project/$1/version" --data-urlencode "game_versions=[\"$2\"]" --data-urlencode "loaders=$3") || return 1
  jq -c 'if type=="array" and length>0 then ([.[]|select(.version_type=="release")][0] // .[0]) else empty end' <<<"$resp"
}

plan_items() { # instance project -> JSON array of items (main first, then required deps)
  local inst=$1 mc loaders known items='[]' queue seen='[]' depth=0
  mc=$(mc_version "$inst"); loaders=$(loaders_json "$inst"); known=$(known_projects "$inst")
  queue=$(jq -cn --arg p "$2" '[{p:$p, req:false}]')
  while [ "$(jq 'length' <<<"$queue")" -gt 0 ] && [ $depth -lt 4 ]; do
    local next='[]'
    while IFS= read -r row; do
      local pid req v proj title slug
      pid=$(jq -r .p <<<"$row"); req=$(jq -r .req <<<"$row")
      jq -e --arg p "$pid" 'index($p)' <<<"$seen" >/dev/null 2>&1 && continue
      seen=$(jq -c --arg p "$pid" '. + [$p]' <<<"$seen")
      if [ "$req" = true ] && jq -e --arg p "$pid" 'index($p)' <<<"$known" >/dev/null 2>&1; then continue; fi   # dependency already installed
      v=$(best_version "$pid" "$mc" "$loaders")
      proj=$(mr "$API/project/$pid")
      title=$(jq -r '.title // ""' <<<"$proj"); slug=$(jq -r '.slug // ""' <<<"$proj")
      if [ -z "$v" ]; then
        items=$(jq -c --arg p "$pid" --arg t "${title:-$pid}" --argjson r "$req" '. + [{project:$p,title:$t,required:$r,missing:true}]' <<<"$items")
        continue
      fi
      items=$(jq -c --arg p "$pid" --arg t "$title" --arg s "$slug" --argjson r "$req" --argjson v "$v" '
        ($v.files | (map(select(.primary))[0] // .[0])) as $f
        | . + [{project:$p, title:$t, slug:$s, required:$r, version:$v.version_number, filename:$f.filename, url:$f.url, size:$f.size,
                sha512:($f.hashes.sha512 // ""), missing:false}]' <<<"$items")
      next=$(jq -c --argjson v "$v" '. + [$v.dependencies[]? | select(.dependency_type=="required" and .project_id != null) | {p:.project_id, req:true}]' <<<"$next")
    done < <(jq -c '.[]' <<<"$queue")
    queue=$next; depth=$((depth + 1))
  done
  # dependencies that are already present as a jar with the same name are not downloaded twice
  echo "$items"
}

mrpost() { curl -s --max-time 30 -H "User-Agent: $UA" -H "Content-Type: application/json" -X POST -d "$2" "$API/$1"; }

# sha1 of every jar in the instance: JSON object {"file name": "sha1"}
jar_hashes() {
  local md f; md=$(mods_dir "$1")
  for f in "$md"/*.jar "$md"/*.jar.disabled; do
    [ -f "$f" ] && printf '%s\t%s\n' "$(basename "$f")" "$(sha1sum "$f" | cut -d' ' -f1)"
  done | jq -R -s -c 'split("\n")|map(select(length>0)|split("\t")|{key:.[0],value:.[1]})|from_entries'
}

# Modrinth's idea of each installed file: what version it is and what the newest compatible one is
compute_updates() { # instance -> JSON {checked, items}
  local inst=$1 hashes body cur new mc loaders titles
  hashes=$(jar_hashes "$inst")
  [ "$(jq 'length' <<<"$hashes")" -gt 0 ] || { jq -cn '{checked:0, items:[]}'; return; }
  mc=$(mc_version "$inst"); loaders=$(loaders_json "$inst")
  body=$(jq -cn --argjson h "$hashes" '{hashes:($h|to_entries|map(.value)), algorithm:"sha1"}')
  cur=$(mrpost version_files "$body")
  new=$(mrpost version_files/update "$(jq -cn --argjson b "$body" --arg mc "$mc" --argjson l "$loaders" '$b + {loaders:$l, game_versions:[$mc]}')")
  jq -e 'type=="object"' >/dev/null 2>&1 <<<"$cur" || { jq -cn '{error:"Modrinth did not answer"}'; return; }
  jq -e 'type=="object"' >/dev/null 2>&1 <<<"$new" || new='{}'
  titles=$(mr -G "$API/projects" --data-urlencode "ids=$(jq -c '[.[]|.project_id]|unique' <<<"$cur")" | jq -c 'if type=="array" then map({key:.id,value:.title})|from_entries else {} end')
  jq -cn --argjson h "$hashes" --argjson cur "$cur" --argjson new "$new" --argjson t "$titles" '
    {checked: ($h|length),
     items: [ $h | to_entries[] | . as $e | ($cur[$e.value]) as $c | ($new[$e.value]) as $n
              | select($c != null and $n != null)
              | select(([$n.files[]?.hashes.sha1] | index($e.value)) == null)
              | ($n.files | (map(select(.primary))[0] // .[0])) as $f
              | {file:$e.key, project:$c.project_id, name:($t[$c.project_id] // $e.key), current:$c.version_number, latest:$n.version_number,
                 filename:$f.filename, url:$f.url, size:$f.size, sha512:($f.hashes.sha512 // "")} ] }'
}

updates_cached() { # instance [fresh]
  local f="$CACHE/updates-$1.json" sig now
  sig=$(jar_hashes "$1" | sha1sum | cut -c1-16); now=$(date +%s)
  if [ "${2:-}" != fresh ] && [ -s "$f" ] && [ "$(jq -r '.sig' "$f")" = "$sig" ] && [ $(( now - $(jq -r '.at' "$f") )) -lt 3600 ]; then jq -c '.data' "$f"; return; fi
  local d; d=$(compute_updates "$1")
  jq -e '.error' >/dev/null 2>&1 <<<"$d" || jq -cn --arg s "$sig" --argjson at "$now" --argjson d "$d" '{sig:$s, at:$at, data:$d}' > "$f"
  echo "$d"
}

# replace one mod with the newest version; $1 instance, $2 item (JSON from compute_updates). prints nothing, returns non-zero with a message in $ERR
do_update() {
  local inst=$1 it=$2 md url fn size sha old oldpath dis=""
  md=$(mods_dir "$inst"); url=$(jq -r .url <<<"$it"); fn=$(jq -r .filename <<<"$it"); size=$(jq -r '.size // 0' <<<"$it"); sha=$(jq -r .sha512 <<<"$it"); old=$(jq -r .file <<<"$it")
  case $url in https://cdn.modrinth.com/*) ;; *) ERR="refusing to download from an unexpected host"; return 1 ;; esac
  valid_file "$fn" || { ERR="unexpected file name from Modrinth"; return 1; }
  [ "$size" -le "$MAX_BYTES" ] || { ERR="$fn is larger than the safety limit"; return 1; }
  oldpath="$md/$old"; [ -f "$oldpath" ] || { ERR="$old is gone"; return 1; }
  case $old in *.disabled) dis=.disabled ;; esac
  curl -fsSL --max-time 900 -H "User-Agent: $UA" -o "$md/$fn.part" "$url" || { rm -f "$md/$fn.part"; ERR="download of $fn failed"; return 1; }
  if [ -n "$sha" ] && [ "$(sha512sum "$md/$fn.part" | cut -d' ' -f1)" != "$sha" ]; then rm -f "$md/$fn.part"; ERR="$fn failed its checksum - not installed"; return 1; fi
  mkdir -p "$BACKUPS/$inst"; mv -f "$oldpath" "$BACKUPS/$inst/$old"
  mv -f "$md/$fn.part" "$md/$fn$dis"
  mkdir -p "$(dirname "$RECORD")"; [ -f "$RECORD" ] || echo '{}' > "$RECORD"
  jq --arg i "$inst" --arg p "$(jq -r .project <<<"$it")" --arg f "$fn" '.[$i][$p] = $f' "$RECORD" > "$RECORD.tmp" && mv "$RECORD.tmp" "$RECORD"
  rm -f "$CACHE/updates-$inst.json"
}

safe_name() { printf '%s' "$1" | tr -d '\000-\037/\\' | sed 's/^[[:space:].]*//;s/[[:space:]]*$//' | cut -c1-48; }

case ${1:-} in
  summary)
    valid_instance "${2:-}" || fail "no such instance"
    md=$(mods_dir "$2")
    en=$(ls "$md"/*.jar 2>/dev/null | wc -l); dis=$(ls "$md"/*.jar.disabled 2>/dev/null | wc -l)
    jq -cn --argjson e "$en" --argjson d "$dis" --arg mc "$(mc_version "$2")" --argjson l "$(loaders_json "$2")" --arg dir "$md" \
       '{enabled:$e, disabled:$d, mc:$mc, loaders:$l, dir:$dir}' ;;

  list)
    valid_instance "${2:-}" || fail "no such instance"
    md=$(mods_dir "$2")
    tmp=$(mktemp)
    for f in "$md"/*.jar "$md"/*.jar.disabled; do
      [ -f "$f" ] || continue
      name=$(basename "$f"); en=true; case $name in *.disabled) en=false ;; esac
      meta_for "$f" | jq -c --arg file "$name" --argjson en "$en" --argjson size "$(stat -c %s "$f")" \
        '. + {file:$file, enabled:$en, size:$size, name:(if .name=="" then ($file|sub("\\.jar(\\.disabled)?$";"")) else .name end)}' >> "$tmp"
    done
    mods=$(jq -s -c 'sort_by(.name|ascii_downcase)' "$tmp"); rm -f "$tmp"
    jq -cn --argjson m "$mods" --argjson p "$(known_projects "$2")" --arg mc "$(mc_version "$2")" --argjson l "$(loaders_json "$2")" --arg dir "$md" \
       '{mods:$m, projects:$p, mc:$mc, loaders:$l, dir:$dir}' ;;

  toggle)
    valid_instance "${2:-}" || fail "no such instance"; valid_file "${3:-}" || fail "bad file name"
    f="$(mods_dir "$2")/$3"; [ -f "$f" ] || fail "mod file not found"
    case $3 in
      *.jar.disabled) mv -n "$f" "${f%.disabled}" ;;
      *.jar)          mv -n "$f" "$f.disabled" ;;
    esac || fail "rename failed"
    jq -cn '{ok:true}' ;;

  search)
    valid_instance "${2:-}" || fail "no such instance"
    q=${3:-}; offset=${4:-0}; case $offset in ''|*[!0-9]*) offset=0 ;; esac
    mc=$(mc_version "$2"); lj=$(loaders_json "$2")
    [ "$lj" != "[]" ] || fail "this instance has no mod loader"
    facets=$(jq -cn --arg mc "$mc" --argjson l "$lj" '[["project_type:mod"],["versions:"+$mc],($l|map("categories:"+.))]')
    idx=downloads; [ -n "$q" ] && idx=relevance
    mr -G "$API/search" --data-urlencode "query=$q" --data-urlencode "facets=$facets" --data-urlencode "limit=20" \
       --data-urlencode "offset=$offset" --data-urlencode "index=$idx" \
      | jq -c 'if .hits then {total:.total_hits, hits:[.hits[]|{id:.project_id, slug, title, desc:.description, author, downloads, icon:(.icon_url // "")}]} else {error:"Modrinth did not answer"} end' ;;

  plan)
    valid_instance "${2:-}" || fail "no such instance"; [ -n "${3:-}" ] || fail "no project"
    pid=$(project_id "$3"); [ -n "$pid" ] || fail "that mod was not found on Modrinth"
    items=$(plan_items "$2" "$pid")
    jq -cn --argjson i "$items" '{items:$i, bytes:($i|map(select(.missing|not)|.size // 0)|add // 0)}' ;;

  install)
    valid_instance "${2:-}" || fail "no such instance"; [ -n "${3:-}" ] || fail "no project"
    md=$(mods_dir "$2"); mkdir -p "$md"
    pid=$(project_id "$3"); [ -n "$pid" ] || fail "that mod was not found on Modrinth"
    items=$(plan_items "$2" "$pid")
    [ "$(jq 'length' <<<"$items")" -gt 0 ] || fail "nothing to install"
    jq -e '.[0].missing == false' <<<"$items" >/dev/null || fail "no compatible version for this Minecraft version and loader"
    done_list='[]'; skipped='[]'
    while IFS= read -r it; do
      [ "$(jq -r .missing <<<"$it")" = true ] && { skipped=$(jq -c --argjson i "$it" '. + [$i.title + " (no compatible version)"]' <<<"$skipped"); continue; }
      url=$(jq -r .url <<<"$it"); fn=$(jq -r .filename <<<"$it"); size=$(jq -r '.size // 0' <<<"$it"); sha=$(jq -r .sha512 <<<"$it"); pid=$(jq -r .project <<<"$it")
      case $url in https://cdn.modrinth.com/*) ;; *) fail "refusing to download from an unexpected host" ;; esac
      valid_file "$fn" || fail "unexpected file name from Modrinth"
      [ "$size" -le "$MAX_BYTES" ] || fail "$fn is larger than the safety limit"
      if [ -e "$md/$fn" ] || [ -e "$md/$fn.disabled" ]; then skipped=$(jq -c --arg f "$fn" '. + [$f + " (already there)"]' <<<"$skipped"); continue; fi
      curl -fsSL --max-time 900 -H "User-Agent: $UA" -o "$md/$fn.part" "$url" || { rm -f "$md/$fn.part"; fail "download of $fn failed"; }
      if [ -n "$sha" ] && [ "$(sha512sum "$md/$fn.part" | cut -d' ' -f1)" != "$sha" ]; then rm -f "$md/$fn.part"; fail "$fn failed its checksum - not installed"; fi
      mv "$md/$fn.part" "$md/$fn"
      # remember which Modrinth project this file came from
      mkdir -p "$(dirname "$RECORD")"; [ -f "$RECORD" ] || echo '{}' > "$RECORD"
      jq --arg i "$2" --arg p "$pid" --arg f "$fn" '.[$i][$p] = $f' "$RECORD" > "$RECORD.tmp" && mv "$RECORD.tmp" "$RECORD"
      done_list=$(jq -c --arg f "$fn" '. + [$f]' <<<"$done_list")
    done < <(jq -c '.[]' <<<"$items")
    jq -cn --argjson d "$done_list" --argjson s "$skipped" '{ok:true, installed:$d, skipped:$s}' ;;

  updates)
    valid_instance "${2:-}" || fail "no such instance"
    updates_cached "$2" "${3:-}" ;;

  update)
    valid_instance "${2:-}" || fail "no such instance"; valid_file "${3:-}" || fail "bad file name"
    it=$(updates_cached "$2" | jq -c --arg f "$3" '.items[]? | select(.file==$f)')
    [ -n "$it" ] || fail "that mod is already up to date"
    ERR=""; do_update "$2" "$it" || fail "$ERR"
    jq -cn --arg n "$(jq -r .name <<<"$it")" --arg v "$(jq -r .latest <<<"$it")" '{ok:true, name:$n, version:$v}' ;;

  updateall)
    valid_instance "${2:-}" || fail "no such instance"
    d=$(updates_cached "$2" fresh); jq -e '.error' >/dev/null 2>&1 <<<"$d" && fail "Modrinth did not answer"
    ok='[]'; bad='[]'
    while IFS= read -r it; do
      ERR=""
      if do_update "$2" "$it"; then ok=$(jq -c --arg n "$(jq -r .name <<<"$it")" '. + [$n]' <<<"$ok")
      else bad=$(jq -c --arg n "$(jq -r .name <<<"$it") ($ERR)" '. + [$n]' <<<"$bad"); fi
    done < <(jq -c '.items[]' <<<"$d")
    jq -cn --argjson o "$ok" --argjson b "$bad" '{ok:true, updated:$o, failed:$b}' ;;

  save)
    valid_instance "${2:-}" || fail "no such instance"
    name=$(safe_name "${3:-}"); [ -n "$name" ] || fail "give the list a name"
    hashes=$(jar_hashes "$2"); [ "$(jq 'length' <<<"$hashes")" -gt 0 ] || fail "this instance has no mods"
    cur=$(mrpost version_files "$(jq -cn --argjson h "$hashes" '{hashes:($h|to_entries|map(.value)), algorithm:"sha1"}')")
    jq -e 'type=="object"' >/dev/null 2>&1 <<<"$cur" || fail "Modrinth did not answer"
    titles=$(mr -G "$API/projects" --data-urlencode "ids=$(jq -c '[.[]|.project_id]|unique' <<<"$cur")" | jq -c 'if type=="array" then map({key:.id,value:.title})|from_entries else {} end')
    mkdir -p "$LISTS"
    jq -cn --arg name "$name" --arg mc "$(mc_version "$2")" --argjson l "$(loaders_json "$2")" --argjson h "$hashes" --argjson cur "$cur" --argjson t "$titles" '
      {name:$name, mc:$mc, loaders:$l, saved:(now|floor),
       mods:[$h|to_entries[] | ($cur[.value]) as $c | select($c != null) | {project:$c.project_id, title:($t[$c.project_id] // .key), version:$c.version_number}],
       unknown:[$h|to_entries[] | select($cur[.value] == null) | .key]}' > "$LISTS/$name.json"
    jq -c '{ok:true, name, count:(.mods|length), unknown:(.unknown|length)}' "$LISTS/$name.json" ;;

  lists)
    mkdir -p "$LISTS"
    for f in "$LISTS"/*.json; do [ -f "$f" ] && jq -c '{name, count:(.mods|length), mc, loaders, unknown:(.unknown|length)}' "$f"; done | jq -s -c '.' ;;

  droplist)
    name=$(safe_name "${2:-}"); [ -n "$name" ] && [ -f "$LISTS/$name.json" ] || fail "no such list"
    rm -f "$LISTS/$name.json"; jq -cn '{ok:true}' ;;

  apply)
    valid_instance "${2:-}" || fail "no such instance"
    name=$(safe_name "${3:-}"); [ -n "$name" ] && [ -f "$LISTS/$name.json" ] || fail "no such list"
    [ "$(loaders_json "$2")" != "[]" ] || fail "this instance has no mod loader"
    installed=0; skipped=0; bad='[]'
    while IFS= read -r row; do
      pid=$(jq -r .project <<<"$row"); title=$(jq -r .title <<<"$row")
      if jq -e --arg p "$pid" 'index($p)' >/dev/null 2>&1 <<<"$(known_projects "$2")"; then skipped=$((skipped + 1)); continue; fi
      out=$(bash "$0" install "$2" "$pid" 2>/dev/null)
      if jq -e '.ok == true' >/dev/null 2>&1 <<<"$out"; then installed=$((installed + 1))
      else bad=$(jq -c --arg t "$title" '. + [$t]' <<<"$bad"); fi
    done < <(jq -c '.mods[]' "$LISTS/$name.json")
    jq -cn --argjson i $installed --argjson s $skipped --argjson b "$bad" '{ok:true, installed:$i, skipped:$s, failed:$b}' ;;

  *) fail "usage: mods.sh summary|list|toggle|search|plan|install|updates|update|updateall|save|lists|apply|droplist" ;;
esac
