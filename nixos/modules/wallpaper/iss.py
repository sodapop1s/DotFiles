"""Write the ISS ground position for the wallpaper.

Runs from a systemd user timer. Fetches the ISS TLE from CelesTrak at most every 12 hours (a stale
copy is used if the network is down), propagates it with SGP4 and writes ~/.cache/orbit/iss.json:
    {"lat": deg, "lon": deg, "alt_km": km, "time": iso8601, "tle_age_h": hours}
On battery it only recomputes every 5 minutes.

    orbit-iss                 normal run
    orbit-iss --tle FILE      use this TLE file instead of fetching (testing)
    orbit-iss --print         print the result instead of writing it
"""
import json
import math
import os
import sys
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

from sgp4.api import Satrec, jday

TLE_URL = "https://celestrak.org/NORAD/elements/gp.php?CATNR=25544&FORMAT=tle"
TLE_MAX_AGE = 12 * 3600
BATTERY_INTERVAL = 300
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "orbit"
AC_ONLINE = Path("/sys/class/power_supply/ACAD/online")

WGS84_A = 6378.137
WGS84_E2 = 0.00669437999014


def on_battery():
    try:
        return AC_ONLINE.read_text().strip() == "0"
    except OSError:
        return False


def load_tle(path):
    """Return (line1, line2, age_seconds)."""
    if path:
        lines = Path(path).read_text().splitlines()
        return lines[-2], lines[-1], 0
    cached = CACHE / "iss.tle"
    age = time.time() - cached.stat().st_mtime if cached.exists() else None
    if age is None or age > TLE_MAX_AGE:
        try:
            req = urllib.request.Request(TLE_URL, headers={"User-Agent": "orbit-wallpaper/1.0"})
            with urllib.request.urlopen(req, timeout=15) as r:
                text = r.read().decode()
            if len(text.splitlines()) >= 3:
                CACHE.mkdir(parents=True, exist_ok=True)
                cached.write_text(text)
                age = 0
        except OSError as e:
            print(f"TLE fetch failed, using the cached copy: {e}", file=sys.stderr)
    if not cached.exists():
        sys.exit("no TLE available yet")
    lines = cached.read_text().splitlines()
    return lines[-2], lines[-1], time.time() - cached.stat().st_mtime


def gmst_rad(jd):
    d = jd - 2451545.0
    t = d / 36525.0
    deg = 280.46061837 + 360.98564736629 * d + 0.000387933 * t * t - t ** 3 / 38710000.0
    return math.radians(deg % 360.0)


def subpoint(sat, now):
    jd, fr = jday(now.year, now.month, now.day, now.hour, now.minute, now.second + now.microsecond / 1e6)
    err, (x, y, z), _ = sat.sgp4(jd, fr)
    if err:
        sys.exit(f"SGP4 error {err}")
    lon = math.atan2(y, x) - gmst_rad(jd + fr)
    lon = (lon + math.pi) % (2 * math.pi) - math.pi
    p = math.hypot(x, y)
    lat = math.atan2(z, p * (1 - WGS84_E2))
    for _ in range(5):
        n = WGS84_A / math.sqrt(1 - WGS84_E2 * math.sin(lat) ** 2)
        alt = p / math.cos(lat) - n
        lat = math.atan2(z, p * (1 - WGS84_E2 * n / (n + alt)))
    return math.degrees(lat), math.degrees(lon), alt


def main():
    args = sys.argv[1:]
    tle_path = args[args.index("--tle") + 1] if "--tle" in args else None
    out = CACHE / "iss.json"
    if "--print" not in args and on_battery() and out.exists() and time.time() - out.stat().st_mtime < BATTERY_INTERVAL:
        return
    l1, l2, age = load_tle(tle_path)
    now = datetime.now(timezone.utc)
    lat, lon, alt = subpoint(Satrec.twoline2rv(l1, l2), now)
    result = {"lat": round(lat, 3), "lon": round(lon, 3), "alt_km": round(alt, 1),
              "time": now.isoformat(timespec="seconds"), "tle_age_h": round(age / 3600, 1)}
    if "--print" in args:
        print(json.dumps(result))
        return
    CACHE.mkdir(parents=True, exist_ok=True)
    tmp = out.with_suffix(".tmp")
    tmp.write_text(json.dumps(result))
    tmp.replace(out)  # atomic, so the wallpaper never reads half a file


main()
