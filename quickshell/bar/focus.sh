#!/usr/bin/env bash
# Helpers for the School tab's focus mode (bash, jq).
#   focus.sh verify              -> reads your login password from stdin; {ok:true} or {error}  (checked by the system, nothing is stored)
#   focus.sh kill <name>...      -> stop running programs by exact process name  -> {killed:[...]}
#   focus.sh apps                -> the list of programs focus mode keeps closed (edit ~/.config/qs-bar/focus.json)
set -u
CONF="$HOME/.config/qs-bar/focus.json"
fail() { jq -cn --arg e "$1" '{error:$e}'; exit 1; }
DEFAULT_APPS='["steam","steamwebhelper","discord","Discord","lutris","prismlauncher","org.prismlauncher.PrismLauncher","spotify"]'

case ${1:-} in
  verify)
    IFS= read -r pw || true
    [ -n "$pw" ] || fail "type your password"
    helper=/run/wrappers/bin/unix_chkpwd; [ -x "$helper" ] || helper=$(command -v unix_chkpwd || true)
    [ -n "$helper" ] || fail "cannot check passwords on this system"
    if printf '%s\0' "$pw" | "$helper" "$(id -un)" nullok >/dev/null 2>&1; then jq -cn '{ok:true}'
    else sleep 1; fail "wrong password"; fi ;;
  apps)
    if [ -f "$CONF" ] && jq -e '.apps | type=="array"' "$CONF" >/dev/null 2>&1; then jq -c '.apps' "$CONF"
    else
      mkdir -p "$(dirname "$CONF")"
      jq -n --argjson a "$DEFAULT_APPS" '{apps:$a, note:"programs that focus mode keeps closed (exact process names)"}' > "$CONF"
      echo "$DEFAULT_APPS"
    fi ;;
  kill)
    shift; killed='[]'
    for n in "$@"; do
      case $n in ''|*[!A-Za-z0-9._-]*) continue ;; esac
      if pkill -x "$n" 2>/dev/null; then killed=$(jq -c --arg n "$n" '. + [$n]' <<<"$killed"); fi
    done
    jq -cn --argjson k "$killed" '{killed:$k}' ;;
  *) fail "usage: focus.sh verify|apps|kill <name>..." ;;
esac
