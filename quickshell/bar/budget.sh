#!/usr/bin/env bash
command -v python3 >/dev/null 2>&1 || { echo '{"error":"python3 is not installed"}'; exit 1; }
exec python3 "$(dirname "$(readlink -f "$0")")/budget.py" "$@"
