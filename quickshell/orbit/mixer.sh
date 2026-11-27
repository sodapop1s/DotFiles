#!/usr/bin/env bash
# Audio mixer helper (PipeWire via pw-dump + wpctl).
#   mixer.sh list                   -> {sinks, sources, apps} with volume (0-100), muted, default
#   mixer.sh volume <id> <0-100>    -> set volume
#   mixer.sh mute <id>              -> toggle mute
#   mixer.sh default <id>           -> make a sink/source the default
set -u
fail() { jq -cn --arg e "$1" '{error:$e}'; exit 1; }
command -v pw-dump >/dev/null && command -v wpctl >/dev/null || fail "needs pw-dump and wpctl (PipeWire)"

defid() { wpctl inspect "$1" 2>/dev/null | head -n 1 | sed -n 's/^id \([0-9]*\),.*/\1/p'; }

case ${1:-} in
  list)
    nodes=$(pw-dump 2>/dev/null | jq -c '[.[] | select(.type == "PipeWire:Interface:Node") | {id, p: .info.props}
      | select(.p["media.class"] != null)
      | select(.p["media.class"] | test("^(Audio/Sink|Audio/Source|Stream/Output/Audio)$"))
      | {id, class: .p["media.class"],
         name: (.p["node.description"] // .p["node.nick"] // .p["node.name"] // ""),
         app: (.p["application.name"] // .p["node.name"] // ""),
         media: (.p["media.name"] // ""),
         icon: (.p["application.icon-name"] // .p["application.process.binary"] // "")}]') || fail "pw-dump failed"
    vols=""
    for id in $(jq -r '.[].id' <<<"$nodes"); do
      out=$(wpctl get-volume "$id" 2>/dev/null) || continue
      vols+=$(awk -v id="$id" '{printf "%s %d %s\n", id, int($2*100+0.5), ($0 ~ /MUTED/ ? "true" : "false")}' <<<"$out")$'\n'
    done
    volmap=$(printf '%s' "$vols" | jq -Rn '[inputs | split(" ") | select(length==3) | {key:.[0], value:{volume:(.[1]|tonumber), muted:(.[2]=="true")}}] | from_entries')
    jq -cn --argjson n "$nodes" --argjson v "$volmap" --arg ds "$(defid @DEFAULT_AUDIO_SINK@)" --arg dsrc "$(defid @DEFAULT_AUDIO_SOURCE@)" '
      def withvol: . as $x | $x + ($v[($x.id|tostring)] // {volume:0, muted:false});
      { sinks:   [$n[] | select(.class=="Audio/Sink")   | withvol | . + {default: ((.id|tostring) == $ds)}],
        sources: [$n[] | select(.class=="Audio/Source") | withvol | . + {default: ((.id|tostring) == $dsrc)}],
        apps:    [$n[] | select(.class=="Stream/Output/Audio") | withvol | select(.name != "" or .app != "")] }' ;;
  volume)
    case ${3:-} in ''|*[!0-9]*) fail "usage: mixer.sh volume <id> <0-100>" ;; esac
    wpctl set-volume "${2:?id}" "$3%" >/dev/null 2>&1 || fail "set-volume failed"; echo '{"ok":true}' ;;
  mute)    wpctl set-mute "${2:?id}" toggle >/dev/null 2>&1 || fail "set-mute failed"; echo '{"ok":true}' ;;
  default) wpctl set-default "${2:?id}" >/dev/null 2>&1 || fail "set-default failed"; echo '{"ok":true}' ;;
  *) fail "usage: mixer.sh list|volume <id> <pct>|mute <id>|default <id>" ;;
esac
