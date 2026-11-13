import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// Brightness and the radio / VPN switches. State comes from sysstat.py (while the panel is open); each switch runs
// one command and then reads the real state back, so what you see is what the system reports.
//   qs -c orbit ipc call quick brightness <percent>     (also usable from a keybind)
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 12

    signal manage(string tab)
    readonly property var q: (Sys.stats && Sys.stats.quick) || ({})
    property real holdUntil: 0          // keep the slider where it was dragged until the system catches up
    property int shown: 0
    property string error: ""

    readonly property int brightnessNow: q.brightness === undefined || q.brightness === null ? -1 : q.brightness
    onBrightnessNowChanged: if (Date.now() >= holdUntil && brightnessNow >= 0) shown = brightnessNow
    Component.onCompleted: if (brightnessNow >= 0) shown = brightnessNow

    // brightness: set at most every 100 ms while dragging; never below 1% (0 turns the backlight off)
    property int pending: -1
    function setBrightness(pct) {
        shown = Math.max(1, Math.min(100, Math.round(pct)))
        holdUntil = Date.now() + 1500
        pending = shown
        if (!briProc.running) flush.restart()
    }
    Timer { id: flush; interval: 100; onTriggered: root.sendBrightness() }
    function sendBrightness() {
        if (root.pending < 0 || briProc.running) return
        briProc.command = ["brightnessctl", "-q", "set", root.pending + "%"]
        root.pending = -1
        briProc.running = true
    }
    Process { id: briProc; onExited: { if (root.pending >= 0) root.sendBrightness(); else Sys.refreshStats() } }

    // switches: run the command, show its complaint if it fails, then re-read the state
    Process {
        id: sw
        stderr: StdioCollector { onStreamFinished: { var l = text.trim().split("\n").pop(); root.error = l } }
        onExited: code => { if (code === 0) root.error = ""; settle.restart() }
    }
    Timer { id: settle; interval: 700; onTriggered: Sys.refreshStats() }
    function run(cmd) { if (sw.running) return; root.error = ""; sw.command = cmd; sw.running = true }

    IpcHandler {
        target: "quick"
        function brightness(pct: int): void { root.setBrightness(pct) }
    }

    // brightness
    ColumnLayout {
        visible: root.brightnessNow >= 0
        Layout.fillWidth: true
        spacing: 2
        RowLayout {
            Layout.fillWidth: true
            Text { text: "Brightness"; color: Theme.muted; Layout.fillWidth: true; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
            Text { text: root.shown + "%"; color: Theme.text; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
        }
        Slider { Layout.fillWidth: true; value: root.shown / 100; onMoved: v => root.setBrightness(v * 100) }
    }

    Toggle {
        visible: root.q.wifi !== undefined && root.q.wifi !== null
        label: "Wi-Fi"
        sub: (root.q.wifi ? (Sys.stats.wifi ? "Connected to " + Sys.stats.wifi.ssid : "Not connected") : "Off") + "  ·  Manage"
        labelActive: true
        onLabelClicked: root.manage("wifi")
        on: root.q.wifi === true
        onFlipped: root.run(["nmcli", "radio", "wifi", root.q.wifi ? "off" : "on"])
    }
    Toggle {
        visible: root.q.bluetooth !== undefined && root.q.bluetooth !== null
        label: "Bluetooth"
        sub: (root.q.bluetooth ? ((root.q.bluetoothDevices || []).length ? (root.q.bluetoothDevices || []).join(", ") : "No device connected") : "Off") + "  ·  Manage"
        labelActive: true
        onLabelClicked: root.manage("bluetooth")
        on: root.q.bluetooth === true
        onFlipped: root.run(["bluetoothctl", "power", root.q.bluetooth ? "off" : "on"])
    }
    Toggle {
        visible: root.q.tailscale !== undefined && root.q.tailscale !== null
        label: "Tailscale"
        sub: "Private network to your other machines"
        on: root.q.tailscale === true
        onFlipped: root.run(["tailscale", root.q.tailscale ? "down" : "up"])
    }
    Toggle {
        visible: root.q.idle !== undefined && root.q.idle !== null
        label: "Auto-lock and sleep"
        sub: "Lock after 5 min, screen off at 6, sleep at 20 on battery"
        on: root.q.idle === true
        onFlipped: root.run(["systemctl", "--user", root.q.idle ? "stop" : "start", "swayidle"])
    }
    Repeater {
        model: root.q.vpns || []
        delegate: Toggle {
            required property var modelData
            label: modelData.name
            sub: "VPN"
            on: modelData.on
            onFlipped: root.run(["nmcli", "connection", modelData.on ? "down" : "up", "id", modelData.name])
        }
    }

    Text {
        visible: root.error.length > 0
        Layout.fillWidth: true
        text: root.error
        wrapMode: Text.WordWrap
        color: Theme.warn
        font { family: Theme.fontUi; pixelSize: 12 }
    }
}
