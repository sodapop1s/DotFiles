#!/usr/bin/env bash
# Obsidian vault helper (bash, jq, rg). Only touches Inbox.md (appending) - everything else is read-only.
#   notes.sh vault                 -> {path, name, exists}
#   notes.sh recent [n]            -> [{rel, title, mtime}]  most recently edited notes
#   notes.sh search <text>         -> [{rel, title, snippet}]  matching titles and contents
#   notes.sh capture <text>        -> add a line to Inbox.md in the vault  ("todo ..." becomes a checkbox)
#   notes.sh open <rel>            -> open the note in Obsidian
#   notes.sh newnote <rel>         -> create a NEW note (text on stdin) under "Weekly Reviews/"; never overwrites
# QS_VAULT overrides the vault folder (used for testing).
set -u
fail() { jq -cn --arg e "$1" '{error:$e}'; exit 1; }
VAULT=${QS_VAULT:-}
if [ -z "$VAULT" ] && [ -f "$HOME/.config/obsidian/obsidian.json" ]; then
  VAULT=$(jq -r '(.vaults // {}) | [to_entries[] | select(.value.open == true)][0].value.path // ([to_entries[]][0].value.path // "")' "$HOME/.config/obsidian/obsidian.json" 2>/dev/null)
fi
[ -n "$VAULT" ] && [ -d "$VAULT" ] || { [ "${1:-}" = vault ] && { jq -cn '{path:"", name:"", exists:false}'; exit 0; }; fail "no Obsidian vault found (open Obsidian once and pick a vault)"; }
NAME=$(basename "$VAULT")

valid_rel() { case ${1:-} in ''|/*|*..*|.*|*/.*) return 1 ;; esac; case $1 in *.md) [ -f "$VAULT/$1" ] ;; *) return 1 ;; esac; }

case ${1:-} in
  vault) jq -cn --arg p "$VAULT" --arg n "$NAME" '{path:$p, name:$n, exists:true}' ;;

  recent)
    n=${2:-8}; case $n in ''|*[!0-9]*) n=8 ;; esac
    find "$VAULT" -type f -name '*.md' -not -path '*/.*' -printf '%T@\t%P\n' 2>/dev/null | sort -rn | head -n "$n" \
      | jq -R -s -c 'split("\n") | map(select(length>0) | split("\t") | {rel:.[1], title:(.[1] | split("/") | last | sub("\\.md$";"")), mtime:(.[0]|tonumber|floor)})' ;;

  search)
    q=${2:-}; [ ${#q} -ge 2 ] || { echo '[]'; exit 0; }
    {
      find "$VAULT" -type f -iname "*$q*.md" -not -path '*/.*' -printf '%P\n' 2>/dev/null | head -n 15 | while IFS= read -r f; do printf '%s\t%s\n' "$f" ""; done
      rg -i -F --max-count 1 --no-heading --with-filename --no-line-number -g '*.md' -g '!.*' -- "$q" "$VAULT" 2>/dev/null | head -n 30 \
        | while IFS= read -r line; do f=${line%%:*}; s=${line#*:}; printf '%s\t%s\n' "${f#"$VAULT"/}" "$s"; done
    } | jq -R -s -c 'split("\n") | map(select(length>0) | split("\t") | {rel:.[0], title:(.[0] | split("/") | last | sub("\\.md$";"")), snippet:((.[1] // "") | .[0:140])})
                     | group_by(.rel) | map(.[-1] + {snippet:(map(.snippet)|map(select(length>0))|.[0] // "")}) | .[0:20]' ;;

  capture)
    text=${2:-}
    text=$(printf '%s' "$text" | tr '\n\r\t' '   ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | cut -c1-500)
    [ -n "$text" ] || fail "write something first"
    f="$VAULT/Inbox.md"
    [ -f "$f" ] || printf '# Inbox\n\nQuick captures from the bar.\n\n' > "$f"
    stamp=$(date '+%Y-%m-%d %H:%M')
    case $text in
      [Tt][Oo][Dd][Oo]\ *) printf -- '- [ ] %s  _(%s)_\n' "${text#* }" "$stamp" >> "$f" ;;
      *)                   printf -- '- %s — %s\n' "$stamp" "$text" >> "$f" ;;
    esac
    jq -cn '{ok:true, file:"Inbox.md"}' ;;

  newnote)
    rel=${2:-}
    case $rel in "Weekly Reviews/"*.md) ;; *) fail "only notes in the Weekly Reviews folder can be created from here" ;; esac
    case $rel in *..*|*/.*|/*) fail "bad note name" ;; esac
    base=${rel%.md}; n=2; target="$VAULT/$rel"
    while [ -e "$target" ]; do target="$VAULT/$base ($n).md"; n=$((n + 1)); done
    mkdir -p "$(dirname "$target")" || fail "could not create the folder"
    head -c 200000 > "$target"
    jq -cn --arg r "${target#"$VAULT"/}" '{ok:true, rel:$r}' ;;

  open)
    valid_rel "${2:-}" || fail "no such note"
    rel=${2%.md}
    url="obsidian://open?vault=$(jq -rn --arg v "$NAME" '$v|@uri')&file=$(jq -rn --arg f "$rel" '$f|@uri')"
    setsid -f xdg-open "$url" >/dev/null 2>&1 < /dev/null
    jq -cn '{ok:true}' ;;

  *) fail "usage: notes.sh vault|recent [n]|search <text>|capture <text>|open <rel>|newnote <rel>" ;;
esac
