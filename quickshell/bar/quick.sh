#!/usr/bin/env bash
# Quick settings for the hub's toggle row (bash, jq).
#   quick.sh status              -> {profile, profiles:[...], night, nightOk, awake, lid}
#   quick.sh profile <name>      -> power-saver | balanced | performance   (needs power-profiles-daemon)
#   quick.sh night on|off        -> warm screen tint with wlsunset
#   quick.sh awake on|off        -> stop the screen locking / the PC sleeping (a systemd inhibitor)
#   quick.sh lid on|off          -> shut the computer down when the lid is closed (niri runs lid-close.sh)
set -u
STATE=${XDG_RUNTIME_DIR:-/tmp}/qs-lid-poweroff     # exists = "lid close powers off"; the file lives in tmpfs, so a reboot turns it back off
fail() { jq -cn --arg e "$1" '{error:$e}'; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
nightpid() { pgrep -x wlsunset | head -n 1; }
awakepid() { pgrep -f '^systemd-inhibit --what=idle:sleep --who=qs-bar' | head -n 1; }

case ${1:-} in
  status)
    prof=""; profs='[]'
    if have powerprofilesctl; then
      prof=$(timeout 3 powerprofilesctl get 2>/dev/null)
      profs=$(timeout 3 powerprofilesctl list 2>/dev/null | sed -n 's/^[* ] *\([a-z-]*\):$/\1/p' | jq -R -s -c 'split("\n")|map(select(length>0))')
    fi
    [ -n "$(nightpid)" ] && night=true || night=false
    [ -n "$(awakepid)" ] && awake=true || awake=false
    [ -e "$STATE" ] && lid=true || lid=false
    jq -cn --arg p "$prof" --argjson ps "${profs:-[]}" --argjson n $night --argjson nok "$(have wlsunset && echo true || echo false)" --argjson a $awake --argjson l $lid \
      '{profile:$p, profiles:$ps, night:$n, nightOk:$nok, awake:$a, lid:$l}' ;;
  profile)
    have powerprofilesctl || fail "power-profiles-daemon is not installed (rebuild NixOS first)"
    case ${2:-} in power-saver|balanced|performance) ;; *) fail "unknown profile" ;; esac
    timeout 5 powerprofilesctl set "$2" 2>/dev/null && jq -cn '{ok:true}' || fail "that profile is not available on this machine" ;;
  night)
    have wlsunset || fail "wlsunset is not installed (rebuild NixOS first)"
    if [ "${2:-}" = on ]; then
      [ -n "$(nightpid)" ] || setsid -f wlsunset -t "${QS_NIGHT_TEMP:-3600}" -T "$(( ${QS_NIGHT_TEMP:-3600} + 1 ))" >/dev/null 2>&1 < /dev/null
    else
      p=$(nightpid); [ -n "$p" ] && kill "$p"
    fi
    jq -cn '{ok:true}' ;;
  awake)
    if [ "${2:-}" = on ]; then
      [ -n "$(awakepid)" ] || setsid -f systemd-inhibit --what=idle:sleep --who=qs-bar --why="Keep awake switch" sleep infinity >/dev/null 2>&1 < /dev/null
    else
      p=$(awakepid); [ -n "$p" ] && pkill -P "$p" sleep 2>/dev/null; [ -n "$p" ] && kill "$p" 2>/dev/null
    fi
    jq -cn '{ok:true}' ;;
  lid)
    if [ "${2:-}" = on ]; then : > "$STATE"; else rm -f "$STATE"; fi
    jq -cn '{ok:true}' ;;
  *) fail "usage: quick.sh status|profile <name>|night on|off|awake on|off|lid on|off" ;;
esac
