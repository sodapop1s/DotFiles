#!/usr/bin/env bash
# Lecture-notes folders for the School > Notes > Lectures page (bash, jq). Read-only apart from the small list of folders.
#   lectures.sh detect              -> [{path, files}]  folders that look like Notability / lecture backups
#   lectures.sh roots               -> [path]
#   lectures.sh addroot <path>      -> start watching a folder (must be inside your home)
#   lectures.sh droproot <path>
#   lectures.sh list                -> [{path, name, rel, root, mtime, size, ext}]  newest lecture files first
#   lectures.sh open <path>         -> open a file from one of the folders
# Notability can back itself up (Settings -> Auto-Backup) to a cloud folder as PDF; when that folder is synced to this
# computer, add it here. Folders are remembered in ~/.config/qs-bar/lectures.json.
set -u
CONF="$HOME/.config/qs-bar/lectures.json"
fail() { jq -cn --arg e "$1" '{error:$e}'; exit 1; }
roots() { [ -f "$CONF" ] && jq -r '.roots[]?' "$CONF" 2>/dev/null; }
EXT='-iname *.pdf -o -iname *.m4a -o -iname *.mp3 -o -iname *.wav -o -iname *.txt -o -iname *.md -o -iname *.rtf -o -iname *.png -o -iname *.jpg -o -iname *.jpeg'
under_home() { local p; p=$(realpath -m -- "$1" 2>/dev/null) || return 1; case $p in "$HOME"/*) return 0 ;; esac; return 1; }

case ${1:-} in
  roots) roots | jq -R -s -c 'split("\n") | map(select(length>0))' ;;

  detect)
    find "$HOME" -maxdepth 4 -type d \( -iname 'notability*' -o -iname 'lectures' -o -iname 'lecture notes' -o -iname 'lecture*notes' \) -not -path '*/.*' -not -path '*/node_modules/*' 2>/dev/null | head -n 12 | while IFS= read -r d; do
      n=$(find "$d" -maxdepth 4 -type f \( -iname '*.pdf' -o -iname '*.m4a' -o -iname '*.note' \) 2>/dev/null | head -n 400 | wc -l)
      printf '%s\t%s\n' "$d" "$n"
    done | jq -R -s -c 'split("\n") | map(select(length>0) | split("\t") | {path:.[0], files:(.[1]|tonumber)})' ;;

  addroot)
    p=${2:-}; [ -d "$p" ] && under_home "$p" || fail "pick an existing folder inside your home folder"
    p=$(realpath "$p")
    mkdir -p "$(dirname "$CONF")"
    cur='{"roots":[]}'; [ -f "$CONF" ] && cur=$(cat "$CONF")
    jq --arg p "$p" '.roots = ((.roots // []) + [$p] | unique)' <<<"$cur" > "$CONF.tmp" && mv "$CONF.tmp" "$CONF"
    jq -cn '{ok:true}' ;;

  droproot)
    [ -f "$CONF" ] || fail "nothing saved"
    jq --arg p "${2:-}" '.roots = ((.roots // []) | map(select(. != $p)))' "$CONF" > "$CONF.tmp" && mv "$CONF.tmp" "$CONF"
    jq -cn '{ok:true}' ;;

  list)
    roots | while IFS= read -r r; do
      [ -d "$r" ] || continue
      # shellcheck disable=SC2086
      find "$r" -maxdepth 5 -type f \( $EXT \) -not -path '*/.*' -printf '%T@\t%s\t%p\n' 2>/dev/null | while IFS=$'\t' read -r t s p; do printf '%s\t%s\t%s\t%s\n' "$t" "$s" "$r" "$p"; done
    done | sort -rn | head -n 150 \
      | jq -R -s -c 'split("\n") | map(select(length>0) | split("\t") | {mtime:(.[0]|tonumber|floor), size:(.[1]|tonumber), root:.[2], path:.[3]}
                     | . + {name:(.path|split("/")|last), rel:(.path[(.root|length+1):]), ext:((.path|split(".")|last)|ascii_downcase)})' ;;

  open)
    f=${2:-}; [ -f "$f" ] || fail "that file is gone"
    case ${f,,} in *.pdf|*.m4a|*.mp3|*.wav|*.txt|*.md|*.rtf|*.png|*.jpg|*.jpeg) ;; *) fail "that kind of file is not opened from here" ;; esac
    ok=0; while IFS= read -r r; do case $(realpath -- "$f") in "$(realpath -- "$r")"/*) ok=1 ;; esac; done < <(roots)
    [ $ok = 1 ] || fail "that file is not in one of your lecture folders"
    setsid -f xdg-open "$f" >/dev/null 2>&1 < /dev/null
    jq -cn '{ok:true}' ;;

  *) fail "usage: lectures.sh detect|roots|addroot <path>|droproot <path>|list|open <path>" ;;
esac
