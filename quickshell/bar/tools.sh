#!/usr/bin/env bash
# Small helpers for the School > Tools page (bash, jq).
#   tools.sh matlab-folders     -> [{path, name, files, mtime}]  folders under your MATLAB roots that contain .m files, newest first
#   tools.sh matlab <path>      -> start MATLAB with that folder as the working folder
#   tools.sh matlab             -> start MATLAB
# MATLAB roots: ~/MATLAB, ~/Documents/MATLAB, and anything listed in ~/.config/qs-bar/matlab-folders.json (a JSON array of paths).
set -u
fail() { jq -cn --arg e "$1" '{error:$e}'; exit 1; }
roots() {
  echo "$HOME/MATLAB"; echo "$HOME/Documents/MATLAB"
  [ -f "$HOME/.config/qs-bar/matlab-folders.json" ] && jq -r '.[]?' "$HOME/.config/qs-bar/matlab-folders.json" 2>/dev/null
}
case ${1:-} in
  matlab-folders)
    roots | while IFS= read -r r; do
      [ -d "$r" ] || continue
      { echo "$r"; find "$r" -mindepth 1 -maxdepth 2 -type d -not -path '*/.*' 2>/dev/null; } | while IFS= read -r d; do
        n=$(find "$d" -maxdepth 1 -type f -name '*.m' 2>/dev/null | wc -l)
        [ "$n" -gt 0 ] || continue
        printf '%s\t%s\t%s\n' "$d" "$n" "$(stat -c %Y "$d")"
      done
    done | sort -u | jq -R -s -c 'split("\n") | map(select(length>0) | split("\t") | {path:.[0], name:(.[0]|split("/")|last), files:(.[1]|tonumber), mtime:(.[2]|tonumber)}) | sort_by(-.mtime) | .[0:12]' ;;
  matlab)
    command -v matlab >/dev/null 2>&1 || fail "MATLAB is not installed"
    p=${2:-}
    if [ -n "$p" ]; then
      [ -d "$p" ] || fail "that folder is gone"
      case $p in "$HOME"/*) ;; *) fail "folder must be inside your home" ;; esac
      setsid -f matlab -sd "$p" >/dev/null 2>&1 < /dev/null
    else setsid -f matlab >/dev/null 2>&1 < /dev/null; fi
    jq -cn '{ok:true}' ;;
  *) fail "usage: tools.sh matlab-folders|matlab [path]" ;;
esac
