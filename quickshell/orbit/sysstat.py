#!/usr/bin/env python3
"""One JSON snapshot for the system panel: CPU, memory, temperatures, battery, Wi-Fi, services, quick settings.

Run only while the panel is open. Services come from ~/.config/orbit/services.json:
  [{"name": "Jellyfin", "host": "homelab", "port": 8096}, ...]
"""
import json, os, re, socket, subprocess, time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

BAT = Path("/sys/class/power_supply/BAT1")


def read(p, default=""):
    try:
        return Path(p).read_text().strip()
    except OSError:
        return default


def cpu_times():
    f = [int(x) for x in read("/proc/stat").splitlines()[0].split()[1:]]
    return f[3] + f[4], sum(f)  # idle+iowait, total


def cpu_percent():
    i0, t0 = cpu_times()
    time.sleep(0.25)
    i1, t1 = cpu_times()
    return round(100 * (1 - (i1 - i0) / max(1, t1 - t0)))


def mem_percent():
    m = {l.split(":")[0]: int(l.split()[1]) for l in read("/proc/meminfo").splitlines()}
    return round(100 * (1 - m["MemAvailable"] / m["MemTotal"]))


def temps():
    names = {"k10temp": "cpu", "amdgpu": "gpu", "nvme": "storage"}
    out = {}
    for h in Path("/sys/class/hwmon").glob("hwmon*"):
        key = names.get(read(h / "name"))
        v = read(h / "temp1_input")
        if key and v and key not in out:
            out[key] = round(int(v) / 1000)
    return out


def battery():
    if not BAT.exists():
        return None
    now, full, power = (int(read(BAT / n, "0")) for n in ("energy_now", "energy_full", "power_now"))
    status = read(BAT / "status")
    minutes = None
    if power > 0:
        left = now if status == "Discharging" else full - now if status == "Charging" else 0
        minutes = round(60 * left / power) if left else None
    design = int(read(BAT / "energy_full_design", "0"))
    health = round(100 * full / design) if design else None
    return {"pct": int(read(BAT / "capacity", "0")), "status": status, "watts": round(power / 1e6, 1),
            "minutes": minutes, "health": health}


def wifi():
    try:
        r = subprocess.run(["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL", "dev", "wifi", "list", "--rescan", "no"],
                           capture_output=True, text=True, timeout=2).stdout
    except (OSError, subprocess.TimeoutExpired):
        return None
    for line in r.splitlines():
        a, ssid, sig = re.split(r"(?<!\\):", line)[:3]
        if a == "yes":
            return {"ssid": ssid.replace("\\:", ":"), "signal": int(sig or 0)}
    return None


def run(*cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=2).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def brightness():
    for d in sorted(Path("/sys/class/backlight").glob("*")):
        cur, top = int(read(d / "brightness", "0")), int(read(d / "max_brightness", "0"))
        if top:
            return round(100 * cur / top)
    return None


def quick():
    """state of the quick-settings toggles; a key is None when that thing is not available here"""
    wifi = run("nmcli", "radio", "wifi").strip()
    bt = re.search(r"Powered:\s*(yes|no)", run("bluetoothctl", "show"))
    ts = None
    try:
        ts = json.loads(run("tailscale", "status", "--json") or "null")
    except ValueError:
        pass
    vpns = []
    for line in run("nmcli", "-t", "-f", "NAME,TYPE,STATE", "connection", "show").splitlines():
        parts = re.split(r"(?<!\\):", line)
        if len(parts) >= 3 and parts[1] in ("wireguard", "vpn"):
            vpns.append({"name": parts[0].replace("\\:", ":"), "on": parts[2] == "activated"})
    return {"brightness": brightness(),
            "wifi": (wifi == "enabled") if wifi else None,
            "bluetooth": (bt.group(1) == "yes") if bt else None,
            "tailscale": (ts.get("BackendState") == "Running") if ts and ts.get("BackendState") else None,
            "vpns": vpns}


def probe(s):
    try:
        with socket.create_connection((s["host"], int(s["port"])), timeout=0.8):
            return {"name": s["name"], "up": True}
    except OSError:
        return {"name": s["name"], "up": False}


def services():
    try:
        cfg = json.loads(read(Path.home() / ".config/orbit/services.json", "[]"))
    except ValueError:
        return []
    with ThreadPoolExecutor(max_workers=8) as ex:
        return list(ex.map(probe, cfg))


print(json.dumps({"cpu": cpu_percent(), "mem": mem_percent(), "temps": temps(), "battery": battery(),
                  "wifi": wifi(), "services": services(), "quick": quick()}))
