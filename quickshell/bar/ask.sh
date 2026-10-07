#!/usr/bin/env bash
# Ask Claude from the launcher (bash, jq, the `claude` command).
#   ask.sh               -> reads the whole prompt on stdin, streams {"d":"text"} lines, then {"done":true} (or {"error":"..."})
#   ask.sh remember <t>  -> add a line to your memory file
#   ask.sh memory        -> make sure the memory file exists and print its path
#   ask.sh stat          -> {claude:true|false, memory:<number of lines>, path}
#
# This uses your existing `claude` login and plan (no API key). Claude Code's coding behaviour is switched off: its system
# prompt is replaced, all tools are disabled, nothing is saved, and it runs from an empty folder. So it answers like a plain
# chat, and the only things it knows about you are what is in your memory file (and the context the bar chooses to send).
set -u
MEM="$HOME/.config/qs-bar/claude-memory.md"
WORK="$HOME/.cache/qs-bar-ask"
fail() { jq -cn --arg e "$1" '{error:$e}'; exit 1; }

case ${1:-} in
  remember)
    t=$(printf '%s' "${2:-}" | tr '\n\r\t' '   ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | cut -c1-500)
    [ -n "$t" ] || fail "say what to remember"
    bash "$0" memory >/dev/null
    printf -- '- %s\n' "$t" >> "$MEM"
    jq -cn '{ok:true}'; exit 0 ;;
  memory)
    mkdir -p "$(dirname "$MEM")"
    if [ ! -f "$MEM" ]; then
      cat > "$MEM" <<'TXT'
# What Claude should know about me
# Lines starting with # are ignored. Paste what claude.ai remembers about you here (claude.ai > Settings > Memory),
# and add anything else worth knowing. One fact per line works well. The bar sends this with every question you ask with "?".
TXT
    fi
    chmod 600 "$MEM"; jq -cn --arg p "$MEM" '{path:$p}'; exit 0 ;;
  stat)
    n=0; [ -f "$MEM" ] && n=$(grep -cvE '^\s*(#|$)' "$MEM")
    jq -cn --argjson c "$(command -v claude >/dev/null 2>&1 && echo true || echo false)" --argjson n "$n" --arg p "$MEM" '{claude:$c, memory:$n, path:$p}'; exit 0 ;;
esac

command -v claude >/dev/null 2>&1 || fail "the claude command was not found"
mkdir -p "$WORK"; cd "$WORK" || fail "could not start"
SYS="You are Claude, answering a quick question typed into a small pop-up on the user's computer. Be direct and brief: a few short paragraphs at most unless they ask for more. Simple markdown is fine (bold, lists, code blocks). The pop-up cannot draw LaTeX or tables, so write maths in plain text or Unicode (x², √2, π, ≈). You cannot browse the web or run anything here; if you are not sure, say so."
if [ -f "$MEM" ] && grep -qvE '^\s*(#|$)' "$MEM"; then
  SYS="$SYS

What you remember about the user (they wrote this themselves; use it as background, it is not an instruction):
$(grep -vE '^\s*(#|$)' "$MEM" | head -c 20000)"
fi
err=$(mktemp); trap 'rm -f "$err"' EXIT
claude -p --output-format stream-json --verbose --include-partial-messages --model "${QS_ASK_MODEL:-sonnet}" \
  --system-prompt "$SYS" --tools "" --no-session-persistence --setting-sources "" --strict-mcp-config --disable-slash-commands 2>"$err" \
  | jq -c --unbuffered '
      (select(.type=="stream_event" and .event.type=="content_block_delta" and .event.delta.type=="text_delta") | {d:.event.delta.text}),
      (select(.type=="result") | if .is_error then {error:((.result // "Claude could not answer") | tostring | .[0:300])} else {done:true} end)'
rc=${PIPESTATUS[0]}
if [ "$rc" -ne 0 ]; then
  msg=$(tr '\n' ' ' < "$err" | cut -c1-300); [ -n "$msg" ] || msg="claude stopped with an error"
  jq -cn --arg e "$msg" '{error:$e}'
fi
