#!/usr/bin/env python3
"""The keys menu: reads niri's binds and prints the important ones as JSON, grouped.

Each menu row names an action; its keys come from whatever is bound to that action in the niri config, so
changing a bind changes the menu. Rows whose action is not bound are left out.

    hotkeys.py [config.kdl]        default: ~/.config/niri/config.kdl
    -> {"groups": [{"title": ..., "rows": [{"label": ..., "chords": [["Super", "Q"], ...]}]}]}
"""
import json
import os
import re
import sys

NAMES = {"Mod": "Super", "Super": "Super", "Ctrl": "Ctrl", "Alt": "Alt", "Shift": "Shift",
         "Slash": "/", "Comma": ",", "Period": ".", "Minus": "−", "Equal": "+", "Space": "Space",
         "BracketLeft": "[", "BracketRight": "]", "Page_Up": "PgUp", "Page_Down": "PgDn", "Escape": "Esc",
         "Print": "PrtSc", "Left": "←", "Right": "→", "Up": "↑", "Down": "↓", "Home": "Home", "End": "End",
         "Delete": "Del", "Return": "Enter", "Tab": "Tab"}
MODS = ("Mod", "Super", "Ctrl", "Alt", "Shift")

# (group, [(label, action regex) | (label, "family", [action regexes]) | (label, "digits", action prefix)])
MENU = [
    ("Apps", [
        ("Terminal", r'^spawn "ghostty"$'),
        ("Files", r'"yazi"'),
        ("Launcher", r'"toggle" "launcher"'),
        ("Clipboard history", r'"toggle" "clipboard"'),
        ("System monitor", r'"btop"'),
    ]),
    ("Panels", [
        ("System panel", r'"toggle" "left"'),
        ("Day panel", r'"toggle" "right"'),
        ("Study", r'"toggle" "study"'),
        ("Wi-Fi networks", r'"network" "open" "wifi"'),
        ("Bluetooth devices", r'"network" "open" "bluetooth"'),
        ("Notifications", r'"panel" "open" "right"'),
        ("Do not disturb", r'"call" "dnd"'),
        ("Dismiss notification", r'"notif" "dismiss"$'),
        ("Dismiss all notifications", r'dismissAll'),
    ]),
    ("Windows", [
        ("Close window", r'^close-window$'),
        ("Fullscreen", r'^fullscreen-window$'),
        ("Maximize column", r'^maximize-column$'),
        ("Floating on or off", r'^toggle-window-floating$'),
        ("Next column width", r'^switch-preset-column-width$'),
        ("Narrower column", r'^set-column-width "-10%"$'),
        ("Wider column", r'^set-column-width "\+10%"$'),
        ("Tabbed column", r'^toggle-column-tabbed-display$'),
        ("Overview", r'^toggle-overview$'),
    ]),
    ("Move around", [
        ("Focus", "family", [r'^focus-column-left$', r'^focus-window-down$', r'^focus-window-up$', r'^focus-column-right$']),
        ("Move window", "family", [r'^move-column-left$', r'^move-window-down$', r'^move-window-up$', r'^move-column-right$']),
        ("Go to workspace", "digits", "focus-workspace"),
        ("Send window to workspace", "digits", "move-column-to-workspace"),
        ("Workspace down, up", "family", [r'^focus-workspace-down$', r'^focus-workspace-up$']),
    ]),
    ("Screenshots", [
        ("Select an area", r'^screenshot$'),
        ("Whole screen", r'^screenshot-screen$'),
        ("One window", r'^screenshot-window$'),
    ]),
    ("Session", [
        ("Lock", r'"orbit-lock"'),
        ("Power menu", r'"wlogout"'),
        ("Screen off", r'^power-off-monitors$'),
        ("Move the pill", r'"pill" "cycle"'),
        ("Switch to the old desktop", r'rice-switch'),
        ("This menu", r'"toggle" "keys"'),
        ("Quit niri", r'^quit$'),
    ]),
]


def parse_binds(path):
    """[(chord tokens, action text)] for the binds block, comments ignored."""
    out, inside = [], False
    for raw in open(path, encoding="utf-8"):
        line = raw.split("//")[0].rstrip() if '"//' not in raw else raw.rstrip()
        if re.match(r"^binds\s*\{", line):
            inside = True
            continue
        if inside and re.match(r"^\}", line):
            break
        if not inside:
            continue
        m = re.match(r"^\s*([A-Za-z0-9_+]+)\s+([^{]*)\{\s*(.*?)\s*;?\s*\}", line)
        if m:
            out.append((m.group(1).split("+"), m.group(3).strip()))
    return out


def show(tokens):
    return [NAMES.get(t, t) for t in tokens]


def chords_for(binds, rx):
    return [t for t, action in binds if re.search(rx, action)]


def family(binds, rxs):
    """one compact chord for a direction family: Super + H J K L, plus the arrow version"""
    letters, arrows, prefix = [], [], None
    for rx in rxs:
        ks = chords_for(binds, rx)
        let = next((k for k in ks if len(k[-1]) == 1), None)
        arr = next((k for k in ks if k[-1] in ("Left", "Right", "Up", "Down")), None)
        if let is None and arr is None:
            return []
        if let:
            prefix = prefix or let[:-1]
            letters.append(let[-1])
        if arr:
            arrows.append(NAMES[arr[-1]])
    out = []
    if letters and len(letters) == len(rxs):
        out.append(show(prefix) + [" ".join(letters)])
    if arrows and len(arrows) == len(rxs):
        pre = prefix if prefix is not None else []
        out.append(show(pre) + [" ".join(arrows)])
    return out


def digits(binds, action):
    nums, prefix = [], None
    for tokens, a in binds:
        m = re.match(r"^" + re.escape(action) + r" (\d)$", a)
        if m:
            nums.append(int(m.group(1)))
            prefix = tokens[:-1]
    return [show(prefix) + ["%d–%d" % (min(nums), max(nums))]] if len(nums) > 1 else []


def build(path):
    binds = parse_binds(path)
    groups = []
    for title, specs in MENU:
        rows = []
        for spec in specs:
            label = spec[0]
            if len(spec) == 2:
                chords = [show(t) for t in chords_for(binds, spec[1])]
            elif spec[1] == "family":
                chords = family(binds, spec[2])
            else:
                chords = digits(binds, spec[2])
            if chords:
                rows.append({"label": label, "chords": chords[:3]})
        if rows:
            groups.append({"title": title, "rows": rows})
    return {"groups": groups}


if __name__ == "__main__":
    cfg = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/.config/niri/config.kdl")
    print(json.dumps(build(cfg), ensure_ascii=False))
