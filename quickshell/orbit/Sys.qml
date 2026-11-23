pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared system state for the pill and panels. Everything is event-driven or slow-polled:
// niri and NetworkManager push events, the battery is one tiny sysfs read every 30 s, and the
// heavier stats script runs only while the system panel is open (statsWanted).
Singleton {
    id: root

    // ── battery ──
    // The BIOS stops charging at 80%, so 80% counts as full: the pill scales to it (the panel shows the real figure).
    readonly property int batCap: 80
    property int batPct: 0
    property string batStatus: "Unknown"
    readonly property int batLevel: Math.min(100, Math.round(batPct * 100 / batCap))
    readonly property bool charging: batStatus === "Charging"
    readonly property bool onBattery: batStatus === "Discharging"
    FileView { id: capFile;  path: "/sys/class/power_supply/BAT1/capacity"; onLoaded: root.batPct = parseInt(text()) || 0 }
    FileView { id: statFile; path: "/sys/class/power_supply/BAT1/status";   onLoaded: root.batStatus = text().trim() }
    Timer { interval: 30000; running: true; repeat: true; onTriggered: { capFile.reload(); statFile.reload() } }

    // ── niri workspaces ──
    property var workspaces: []
    readonly property var workspaceList: {
        var f = workspaces.find(w => w.is_focused)
        var out = f ? f.output : ""
        return workspaces.filter(w => w.output === out).sort((a, b) => a.idx - b.idx)
    }
    function focusWorkspace(idx) { focusProc.command = ["niri", "msg", "action", "focus-workspace", String(idx)]; focusProc.running = true }
    Process { id: focusProc }
    Process {
        id: wsQuery
        command: ["niri", "msg", "-j", "workspaces"]
        stdout: StdioCollector { onStreamFinished: { try { root.workspaces = JSON.parse(text) } catch (e) {} } }
    }
    Process {
        id: wsEvents
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser { onRead: data => { if (data.indexOf("Workspace") >= 0) wsDebounce.restart() } }
        onExited: wsRetry.start()
    }
    Timer { id: wsDebounce; interval: 100; onTriggered: wsQuery.running = true }
    Timer { id: wsRetry; interval: 5000; onTriggered: wsEvents.running = true }

    // ── network: "connected" | "limited" | "none" ──
    property string netState: "connected"
    Process {
        id: netQuery
        command: ["nmcli", "-t", "-f", "CONNECTIVITY,STATE", "general"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.trim().split(":")
                var conn = p[0], state = p[1] || ""
                root.netState = state.indexOf("connected") !== 0 ? "none"
                              : (conn === "full" || conn === "unknown") ? "connected" : "limited"
            }
        }
    }
    Process {
        id: netEvents
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser { onRead: data => netDebounce.restart() }
        onExited: netRetry.start()
    }
    Timer { id: netDebounce; interval: 500; onTriggered: netQuery.running = true }
    Timer { id: netRetry; interval: 5000; onTriggered: netEvents.running = true }

    // ── detailed stats for the system panel ──
    property bool statsWanted: false
    property var stats: ({})
    Process {
        id: statsProc
        command: ["python3", Quickshell.shellPath("sysstat.py")]
        stdout: StdioCollector { onStreamFinished: { try { root.stats = JSON.parse(text) } catch (e) {} } }
    }
    function refreshStats() { if (!statsProc.running) statsProc.running = true }
    Timer {
        interval: 3000; repeat: true; running: root.statsWanted; triggeredOnStart: true
        onTriggered: if (!statsProc.running) statsProc.running = true
    }

    // ── where the pill sits: top or bottom, and whether it reserves its own strip (windows then start below it) ──
    property string pillPosition: "top"
    property bool pillReserve: false
    FileView {
        id: pillStore
        path: Quickshell.env("HOME") + "/.local/state/qs-orbit-pill.json"
        onLoaded: {
            try {
                var d = JSON.parse(pillStore.text())
                if (d.position === "top" || d.position === "bottom") root.pillPosition = d.position
                root.pillReserve = d.reserve === true
            } catch (e) {}
        }
    }
    function setPill(pos, reserve) {
        pillPosition = pos; pillReserve = reserve
        pillStore.setText(JSON.stringify({ position: pos, reserve: reserve }))
    }
    function cyclePill() {   // top, top reserved, bottom, bottom reserved
        var states = [["top", false], ["top", true], ["bottom", false], ["bottom", true]]
        var i = states.findIndex(s => s[0] === pillPosition && s[1] === pillReserve)
        var n = states[(i + 1) % states.length]
        setPill(n[0], n[1])
    }
    IpcHandler {
        target: "pill"
        function position(p: string): void { if (p === "top" || p === "bottom") root.setPill(p, root.pillReserve) }
        function reserve(v: string): void { root.setPill(root.pillPosition, v === "toggle" ? !root.pillReserve : v === "on") }
        function cycle(): void { root.cyclePill() }
    }

    Component.onCompleted: { wsQuery.running = true; netQuery.running = true }
}
