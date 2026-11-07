#!/usr/bin/env bash
# Pulls your Notability Auto-Backup folder from Google Drive into ~/Notability (one-way, read-only on Drive, never deletes locally).
#   notability-sync.sh setup     sign in to Google once (opens your browser; the token stays in ~/.config/rclone)
#   notability-sync.sh sync      copy new and changed files down
#   notability-sync.sh status    -> {configured, last, files}
# Needs rclone. It is found on PATH, else in the Nix store, else fetched with `nix shell`.
set -u
REMOTE=notability
FOLDER_ID="1emgR-Zi0Wzip_2Xq75n3hwyOMGGR30kS"
DEST="$HOME/Notability"
STAMP="$HOME/.local/state/qs-orbit-notability-sync"
fail() { jq -cn --arg e "$1" '{error:$e}'; exit 1; }

rc() {
  if command -v rclone >/dev/null 2>&1; then rclone "$@"; return; fi
  local bin; bin=$(ls -d /nix/store/*-rclone-[0-9]*/bin/rclone 2>/dev/null | head -n 1)
  if [ -n "$bin" ]; then "$bin" "$@"; else nix shell nixpkgs#rclone -c rclone "$@"; fi
}
configured() { rc listremotes 2>/dev/null | grep -qx "$REMOTE:"; }

case ${1:-} in
  setup)
    configured && { jq -cn '{ok:true, note:"already set up"}'; exit 0; }
    rc config create "$REMOTE" drive scope=drive.readonly root_folder_id="$FOLDER_ID" >/dev/null 2>&1 || fail "sign-in did not finish"
    jq -cn '{ok:true}' ;;

  sync)
    configured || fail "not signed in to Google yet"
    mkdir -p "$DEST" "$(dirname "$STAMP")"
    # copy, not sync: a file deleted on Drive stays here. Skip Notability's own Welcome folder.
    out=$(rc copy "$REMOTE:" "$DEST" --exclude "Welcome/**" --drive-export-formats pdf --transfers 4 --stats-one-line -v 2>&1) || fail "$(printf %s "$out" | tail -n 1)"
    date +%s > "$STAMP"
    jq -cn --argjson n "$(printf %s "$out" | grep -c ': Copied')" '{ok:true, copied:$n}' ;;

  status)
    c=false; configured && c=true
    last=0; [ -f "$STAMP" ] && last=$(cat "$STAMP")
    n=$(find "$DEST" -type f 2>/dev/null | wc -l)
    jq -cn --argjson c "$c" --argjson l "$last" --argjson n "$n" '{configured:$c, last:$l, files:$n}' ;;

  *) fail "usage: notability-sync.sh setup|sync|status" ;;
esac
