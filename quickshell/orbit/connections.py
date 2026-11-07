#!/usr/bin/env python3
"""State for the Connections window: Wi-Fi networks and Bluetooth devices, as JSON.

    connections.py wifi [--rescan]    {"enabled", "device", "networks": [{ssid, signal, security, inUse, saved, enterprise}]}
    connections.py bluetooth          {"powered", "devices": [{mac, name, kind, paired, connected, trusted, battery}]}

Read-only: changes (connect, pair, forget, ...) are made by the window with nmcli and bluetoothctl.
"""
import json
import re
import subprocess
import sys


def run(*cmd, timeout=6):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def split(line):
    return [p.replace("\\:", ":") for p in re.split(r"(?<!\\):", line)]


def wifi(rescan):
    enabled = run("nmcli", "radio", "wifi").strip() == "enabled"
    device = ""
    for line in run("nmcli", "-t", "-f", "DEVICE,TYPE", "device").splitlines():
        d, t = split(line)[:2]
        if t == "wifi":
            device = d
            break
    saved = {split(l)[0] for l in run("nmcli", "-t", "-f", "NAME,TYPE", "connection", "show").splitlines()
             if split(l)[1:2] == ["802-11-wireless"]}
    nets = {}
    flag = "yes" if rescan else "no"
    for line in run("nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", flag,
                    timeout=20 if rescan else 6).splitlines():
        use, ssid, signal, sec = (split(line) + ["", "", "", ""])[:4]
        if not ssid:
            continue                       # hidden network
        n = {"ssid": ssid, "signal": int(signal or 0), "security": sec, "inUse": use == "*",
             "saved": ssid in saved, "enterprise": "802.1X" in sec}
        cur = nets.get(ssid)
        if cur is None or n["inUse"] or (not cur["inUse"] and n["signal"] > cur["signal"]):
            nets[ssid] = n
    order = sorted(nets.values(), key=lambda n: (not n["inUse"], not n["saved"], -n["signal"]))
    return {"enabled": enabled, "device": device, "networks": order}


def field(info, key):
    m = re.search(r"^\s*" + key + r":\s*(.*)$", info, re.M)
    return m.group(1).strip() if m else ""


def bluetooth():
    powered = "yes" in field(run("bluetoothctl", "show"), "Powered")
    devices = []
    for line in run("bluetoothctl", "devices").splitlines():
        m = re.match(r"^Device\s+([0-9A-F:]{17})\s+(.*)$", line.strip())
        if not m:
            continue
        mac, name = m.groups()
        info = run("bluetoothctl", "info", mac, timeout=3)
        paired = field(info, "Paired") == "yes"
        # nearby devices that do not announce a name show up as their address; they cannot be told apart, so skip them
        if not paired and re.fullmatch(r"([0-9A-Fa-f]{2}-){5}[0-9A-Fa-f]{2}", field(info, "Name") or name):
            continue
        bat = re.search(r"Battery Percentage:.*\((\d+)\)", info)
        devices.append({"mac": mac, "name": field(info, "Name") or name, "kind": field(info, "Icon"),
                        "paired": paired, "connected": field(info, "Connected") == "yes",
                        "trusted": field(info, "Trusted") == "yes", "battery": int(bat.group(1)) if bat else None})
    devices.sort(key=lambda d: (not d["connected"], not d["paired"], d["name"].lower()))
    return {"powered": powered, "devices": devices}


if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else ""
    if what == "wifi":
        print(json.dumps(wifi("--rescan" in sys.argv), ensure_ascii=False))
    elif what == "bluetooth":
        print(json.dumps(bluetooth(), ensure_ascii=False))
    else:
        sys.exit("usage: connections.py wifi [--rescan] | bluetooth")
