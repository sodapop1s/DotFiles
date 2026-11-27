#!/usr/bin/env bash
# Window list for the hub's Windows applet (niri, jq).
#   windows.sh list            -> {windows:[{id, title, app, workspace, focused, floating, urgent}], workspaces:[{id, idx, name, focused}]}
#   windows.sh focus <id>      -> bring that window to the front
#   windows.sh close <id>      -> ask that window to close (the app may still ask to save)
set -u
fail() { jq -cn --arg e "$1" '{error:$e}'; exit 1; }
command -v niri >/dev/null 2>&1 || fail "niri is not running"
case ${1:-} in
  list)
    w=$(niri msg -j windows 2>/dev/null) || fail "could not ask niri"
    s=$(niri msg -j workspaces 2>/dev/null) || fail "could not ask niri"
    jq -cn --argjson w "$w" --argjson s "$s" '
      {windows: ($w | map({id, title:(.title // ""), app:(.app_id // ""), workspace:.workspace_id, focused:.is_focused, floating:.is_floating, urgent:.is_urgent})
                    | sort_by(.workspace, .id)),
       workspaces: ($s | map({id, idx, name, focused:.is_focused}) | sort_by(.idx))}' ;;
  focus) case ${2:-} in ''|*[!0-9]*) fail "bad window id" ;; esac; niri msg action focus-window --id "$2" >/dev/null 2>&1 && jq -cn '{ok:true}' || fail "that window is gone" ;;
  close) case ${2:-} in ''|*[!0-9]*) fail "bad window id" ;; esac; niri msg action close-window --id "$2" >/dev/null 2>&1 && jq -cn '{ok:true}' || fail "that window is gone" ;;
  *) fail "usage: windows.sh list|focus <id>|close <id>" ;;
esac
