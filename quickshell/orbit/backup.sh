#!/usr/bin/env bash
# Is the stuff that matters backed up? (bash, jq, git; read-only)
#   backup.sh status   -> [{name, path, git, dirty, unpushed, hasRemote, lastCommit, newest, level, message}]
# level: "ok" | "warn" | "bad". The folders come from ~/.config/qs-bar/backup.json ([{"name":"...","path":"..."}]); when that
# file does not exist, your dotfiles repo and your Obsidian vault are checked.
set -u
CONF="$HOME/.config/qs-bar/backup.json"
HERE=$(dirname "$(readlink -f "$0")")
now=$(date +%s)

list() {
  if [ -f "$CONF" ] && jq -e 'type=="array"' "$CONF" >/dev/null 2>&1; then jq -c '.[]' "$CONF"; return; fi
  [ -d "$HOME/DotFiles" ] && jq -cn --arg p "$HOME/DotFiles" '{name:"Dotfiles", path:$p}'
  v=$(bash "$HERE/notes.sh" vault 2>/dev/null | jq -r 'select(.exists) | .path')
  [ -n "${v:-}" ] && jq -cn --arg p "$v" '{name:"Obsidian vault", path:$p}'
}

case ${1:-} in
  status)
    list | while IFS= read -r row; do
      name=$(jq -r .name <<<"$row"); path=$(jq -r .path <<<"$row")
      path=${path/#\~/$HOME}
      [ -d "$path" ] || { jq -cn --arg n "$name" --arg p "$path" '{name:$n, path:$p, git:false, level:"bad", message:"folder not found"}'; continue; }
      if git -C "$path" rev-parse --git-dir >/dev/null 2>&1; then
        dirty=$(git -C "$path" status --porcelain 2>/dev/null | wc -l)
        last=$(git -C "$path" log -1 --format=%ct 2>/dev/null || echo 0); last=${last:-0}
        remote=$(git -C "$path" remote | head -n 1)
        up=$(git -C "$path" rev-parse --abbrev-ref '@{u}' 2>/dev/null || true)
        unpushed=0; [ -n "$up" ] && unpushed=$(git -C "$path" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
        # oldest uncommitted change tells how long work has been sitting unsaved
        oldest=$now
        if [ "$dirty" -gt 0 ]; then
          oldest=$(git -C "$path" status --porcelain 2>/dev/null | cut -c4- | head -n 200 | while IFS= read -r f; do stat -c %Y "$path/$f" 2>/dev/null; done | sort -n | head -n 1); oldest=${oldest:-$now}
        fi
        age_dirty=$(( (now - oldest) / 86400 )); age_commit=$(( (now - last) / 86400 ))
        level=ok; msg="saved ${age_commit}d ago"
        [ "$dirty" -eq 0 ] && msg="everything is committed"
        if [ -z "$remote" ]; then level=warn; msg="committed, but there is no remote — it only exists on this computer"; fi
        if [ "$unpushed" -gt 0 ]; then level=warn; msg="$unpushed commit(s) not pushed yet"; fi
        if [ "$dirty" -gt 0 ] && [ "$age_dirty" -ge 3 ]; then level=warn; msg="$dirty changed file(s), the oldest ${age_dirty} days uncommitted"; fi
        if [ "$dirty" -gt 0 ] && [ "$age_dirty" -ge 10 ]; then level=bad; fi
        if [ "$dirty" -gt 0 ] && [ "$age_dirty" -lt 3 ]; then msg="$dirty file(s) changed since the last commit"; fi
        jq -cn --arg n "$name" --arg p "$path" --argjson d "$dirty" --argjson u "$unpushed" --argjson hr "$([ -n "$remote" ] && echo true || echo false)" --argjson lc "$last" --arg lv "$level" --arg m "$msg" \
          '{name:$n, path:$p, git:true, dirty:$d, unpushed:$u, hasRemote:$hr, lastCommit:$lc, level:$lv, message:$m}'
      else
        newest=$(find "$path" -type f -not -path '*/.*' -printf '%T@\n' 2>/dev/null | sort -rn | head -n 1 | cut -d. -f1); newest=${newest:-0}
        sync=""
        for m in .stfolder .dropbox .dropbox.cache .git .sync .obsidian-sync; do [ -e "$path/$m" ] && sync=$m; done
        [ -e "$path/.obsidian/plugins/obsidian-git" ] && sync=obsidian-git
        if [ -n "$sync" ] && [ "$sync" != ".obsidian-sync" ]; then level=ok; msg="looks synced ($sync)"
        else level=warn; msg="no version control or sync found here — a second copy is worth having"; fi
        jq -cn --arg n "$name" --arg p "$path" --argjson nw "$newest" --arg lv "$level" --arg m "$msg" '{name:$n, path:$p, git:false, newest:$nw, level:$lv, message:$m}'
      fi
    done | jq -s -c '.' ;;
  *) jq -cn '{error:"usage: backup.sh status"}'; exit 1 ;;
esac
