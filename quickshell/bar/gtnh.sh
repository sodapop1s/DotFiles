#!/usr/bin/env bash
# GTNH version lookup (cached for an hour).
#   gtnh.sh latest  -> {stable, pre, nightly, nightlyAt, nightlies:[tags newest first], fetchedAt}
# stable/pre come from the official version-history page; nightlies from the modpack's GitHub releases.
set -u
CACHE="$HOME/.cache/qs-bar-gtnh.json"
TTL=3600
now=$(date +%s)
if [ "${2:-}" != "fresh" ] && [ -f "$CACHE" ] && [ $((now - $(jq -r '.fetchedAt // 0' "$CACHE" 2>/dev/null || echo 0))) -lt $TTL ]; then
  cat "$CACHE"; exit 0
fi
[ "${1:-}" = latest ] || { echo '{"error":"usage: gtnh.sh latest [fresh]"}'; exit 1; }

page=$(curl -s --max-time 15 https://www.gtnewhorizons.com/version-history/) || page=""
# headings on the page are lines that are exactly a version; the page lists newest first
versions=$(printf '%s' "$page" | sed 's/<[^>]*>/\n/g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
  | grep -E -x '2\.[0-9]+\.[0-9]+(-(beta|RC|rc)-[0-9]+)?' | awk '!seen[$0]++')
stable=$(printf '%s\n' "$versions" | grep -E -x '2\.[0-9]+\.[0-9]+' | head -n 1)
first_ship=$(printf '%s\n' "$versions" | head -n 1)
rel=$(curl -s --max-time 15 'https://api.github.com/repos/GTNewHorizons/GT-New-Horizons-Modpack/releases?per_page=100') || rel="[]"
if ! printf '%s' "$rel" | jq -e 'type=="array"' >/dev/null 2>&1; then
  [ -f "$CACHE" ] && { cat "$CACHE"; exit 0; }
  echo '{"error":"could not reach GitHub (rate limited or offline)"}'; exit 1
fi
nightlies=$(printf '%s' "$rel" | jq -c '[.[] | select(.tag_name|test("nightly")) | .tag_name]')
nightly=$(printf '%s' "$nightlies" | jq -r '.[0] // ""')
nightlyAt=$(printf '%s' "$rel" | jq -r '[.[] | select(.tag_name|test("nightly"))][0].published_at // ""')
pre=$(printf '%s\n' "$versions" | grep -E -- '-(beta|RC|rc)-' | head -n 1)
# only worth showing if it is newer than the newest stable
[ -n "$pre" ] && [ -n "$stable" ] && [ "$(printf '%s\n%s\n' "${pre%%-*}" "$stable" | sort -V | tail -n 1)" = "$stable" ] && [ "${pre%%-*}" != "$stable" ] && pre=""
out=$(jq -cn --arg s "$stable" --arg p "$pre" --arg n "$nightly" --arg na "$nightlyAt" --argjson ns "$nightlies" --argjson t "$now" --arg f "$first_ship" \
  '{stable:$s, pre:$p, newest:$f, nightly:$n, nightlyAt:$na, nightlies:$ns, fetchedAt:$t}')
mkdir -p "$(dirname "$CACHE")"; printf '%s\n' "$out" > "$CACHE"; printf '%s\n' "$out"
