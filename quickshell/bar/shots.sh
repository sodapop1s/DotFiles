#!/usr/bin/env bash
# Capture helper.
#   shots.sh recent [n]       -> JSON [{path, name, at}] newest screenshots in ~/Pictures/Screenshots
#   shots.sh copy <path>      -> put an image on the clipboard
DIR="$HOME/Pictures/Screenshots"
case ${1:-} in
  recent)
    n=${2:-12}
    [ -d "$DIR" ] || { echo '[]'; exit 0; }
    find "$DIR" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.webp' \) -printf '%T@\t%p\n' 2>/dev/null \
      | sort -rn | head -n "$n" \
      | jq -R -s -c 'split("\n") | map(select(length>0) | split("\t") | {at: (.[0]|tonumber|floor), path: .[1], name: (.[1]|split("/")|last)})' ;;
  copy)
    f=${2:?path}
    [ -f "$f" ] || { jq -cn '{error:"file not found"}'; exit 1; }
    wl-copy --type image/png < "$f" && echo '{"ok":true}' || { jq -cn '{error:"wl-copy failed"}'; exit 1; } ;;
  *) jq -cn '{error:"usage: shots.sh recent [n] | copy <path>"}'; exit 1 ;;
esac
