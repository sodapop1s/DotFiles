#!/usr/bin/env bash
# Wallpaper helper (swww).
#   wallpaper.sh list            -> JSON [{path, name}] of images in the wallpaper folders
#   wallpaper.sh current         -> JSON {path}
#   wallpaper.sh set <path>      -> apply with a transition and remember it
#   wallpaper.sh random          -> apply a random one
#   wallpaper.sh restore         -> re-apply the remembered one (used at login)
# Folders: ~/Pictures/Wallpaper, plus any listed (one per line) in ~/.config/qs-bar/wallpaper-dirs
set -u
STATE="$HOME/.local/state/qs-bar-wallpaper"
DIRS_FILE="$HOME/.config/qs-bar/wallpaper-dirs"

dirs() { echo "$HOME/Pictures/Wallpaper"; [ -f "$DIRS_FILE" ] && grep -v '^\s*$' "$DIRS_FILE" | sed "s|^~|$HOME|"; }
images() {
  dirs | while read -r d; do [ -d "$d" ] && find "$d" -maxdepth 2 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' \) -not -path '*/__MACOSX/*' -not -name '._*'; done | sort -V
}
apply() { # apply <path> <transition?>
  [ -f "$1" ] || { jq -cn '{error:"file not found"}'; exit 1; }
  if [ "${2:-yes}" = yes ]; then
    swww img "$1" --transition-type any --transition-duration 1.2 --transition-fps 60 >/dev/null 2>&1 || { jq -cn '{error:"swww failed - is swww-daemon running?"}'; exit 1; }
  else
    swww img "$1" --transition-type none >/dev/null 2>&1 || exit 1
  fi
  mkdir -p "$(dirname "$STATE")"; printf '%s\n' "$1" > "$STATE"
}

case ${1:-} in
  list)    images | jq -R -s -c 'split("\n") | map(select(length>0)) | map({path: ., name: (split("/")|last|sub("\\.[^.]*$";""))})' ;;
  current)
    p=$(cat "$STATE" 2>/dev/null)
    [ -n "$p" ] || p=$(swww query 2>/dev/null | sed -n 's/.*image: //p' | head -n 1)
    jq -cn --arg p "$p" '{path:$p}' ;;
  set)     apply "${2:?path}" yes; echo '{"ok":true}' ;;
  random)  p=$(images | shuf -n 1); [ -n "$p" ] || { jq -cn '{error:"no wallpapers found"}'; exit 1; }; apply "$p" yes; jq -cn --arg p "$p" '{ok:true,path:$p}' ;;
  restore) p=$(cat "$STATE" 2>/dev/null); [ -n "$p" ] && [ -f "$p" ] && apply "$p" no ;;
  *) jq -cn '{error:"usage: wallpaper.sh list|current|set <path>|random|restore"}'; exit 1 ;;
esac
