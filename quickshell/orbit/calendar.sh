#!/usr/bin/env bash
# Wrapper so the bar can call the calendar helper; python3 must be installed (NixOS: add it to systemPackages).
command -v python3 >/dev/null 2>&1 || { echo '{"error":"python3 is not installed - add it to your NixOS config"}'; exit 1; }
exec python3 "$(dirname "$(readlink -f "$0")")/ical.py" "$@"
