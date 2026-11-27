#!/usr/bin/env bash
# Run by niri when the lid closes (see the switch-events block in ~/.config/niri/config.kdl).
# Shuts the computer down only while the "Power off on lid close" switch in the hub is on.
# QS_POWEROFF_CMD replaces the shutdown command (so the script can be tested without turning anything off).
[ -e "${XDG_RUNTIME_DIR:-/tmp}/qs-lid-poweroff" ] && ${QS_POWEROFF_CMD:-systemctl poweroff}
exit 0
