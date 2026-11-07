import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Bluetooth: paired and nearby devices. Pick one to connect, disconnect, pair or forget it.
ColumnLayout {
    id: root
    spacing: 10

    property bool active: false
    property var info: ({ powered: true, devices: [] })
    property string selected: ""
    property string status: ""
    property bool statusBad: false
    property bool scanning: false

    readonly property var kinds: ({ "audio-headset": "Headphones", "audio-headphones": "Headphones", "audio-card": "Audio",
        "input-keyboard": "Keyboard", "input-mouse": "Mouse", "input-gaming": "Controller", "input-tablet": "Tablet",
        "phone": "Phone", "computer": "Computer", "video-display": "Display", "printer": "Printer" })
    function say(msg, bad) { status = msg; statusBad = !!bad }
    function valid(mac) { return /^[0-9A-F:]{17}$/.test(mac) }

    function reload() { if (!listProc.running) listProc.running = true }
    onActiveChanged: if (active) { selected = ""; say(""); reload() }
    Timer { interval: 3000; repeat: true; running: root.active; onTriggered: root.reload() }
    Process {
        id: listProc
        command: ["python3", Quickshell.shellPath("connections.py"), "bluetooth"]
        stdout: StdioCollector { onStreamFinished: { try { root.info = JSON.parse(text) } catch (e) {} } }
    }

    // discovery runs for a short, fixed time
    Process { id: scan; command: ["bluetoothctl", "--timeout", "10", "scan", "on"]; onExited: root.scanning = false }
    function startScan() { if (scan.running || !info.powered) return; scanning = true; scan.running = true }

    Process {
        id: act
        property string out: ""
        stdout: StdioCollector { onStreamFinished: act.out += text }
        stderr: StdioCollector { onStreamFinished: act.out += text }
        onExited: code => {
            var failed = code !== 0 || /Failed to|not available|org\.bluez\.Error/i.test(act.out)
            if (failed) {
                var l = act.out.trim().split("\n").filter(x => /Failed|Error|not/i.test(x)).pop() || ""
                root.say(/AuthenticationFailed|Authentication/i.test(l) ? "Pairing was refused. Put the device in pairing mode and try again."
                         : l.replace(/^\[.*?\]#?\s*/, "") || "That did not work.", true)
            } else { root.say(""); root.selected = "" }
            act.out = ""; settle.restart()
        }
    }
    Timer { id: settle; interval: 800; onTriggered: root.reload() }
    function run(cmd, msg) { if (act.running || !valid(root.selected)) return; say(msg, false); act.out = ""; act.command = cmd; act.running = true }
    Process { id: power; onExited: settle.restart() }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Toggle {
            label: "Bluetooth"
            on: root.info.powered
            onFlipped: { power.command = ["bluetoothctl", "power", root.info.powered ? "off" : "on"]; power.running = true }
        }
        Chip { text: root.scanning ? "Scanning…" : "Scan for devices"; enabled: root.info.powered && !root.scanning; onClicked: root.startScan() }
    }

    Text {
        visible: root.status.length > 0
        Layout.fillWidth: true; wrapMode: Text.WordWrap
        text: root.status; color: root.statusBad ? Theme.crit : Theme.muted
        font { family: Theme.fontUi; pixelSize: 12 }
    }
    Text { visible: !root.info.powered; text: "Bluetooth is off."; color: Theme.muted; Layout.topMargin: 6; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }

    ListView {
        id: list
        visible: root.info.powered
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(440, contentHeight)
        clip: true; spacing: 6
        boundsBehavior: Flickable.StopAtBounds
        model: root.info.devices

        delegate: Rectangle {
            id: row
            required property var modelData
            readonly property bool open: root.selected === modelData.mac
            width: list.width
            height: rowCol.implicitHeight + 20
            radius: 10
            color: open ? Theme.raised : "transparent"
            border { width: 1; color: open ? Theme.accent : Theme.hairline }

            MouseArea { anchors { left: parent.left; right: parent.right; top: parent.top } height: 52; onClicked: root.selected = row.open ? "" : row.modelData.mac }

            ColumnLayout {
                id: rowCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; topMargin: 10 }
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true; spacing: 12
                    Rectangle {
                        Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4
                        color: row.modelData.connected ? Theme.good : "transparent"
                        border { width: row.modelData.connected ? 0 : 1; color: Theme.hairline }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        Text { text: row.modelData.name; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
                        Text {
                            text: (root.kinds[row.modelData.kind] || "Device") + "  ·  " + (row.modelData.connected ? "Connected" : row.modelData.paired ? "Paired" : "Available")
                            color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 }
                        }
                    }
                    Text { visible: row.modelData.battery !== null; text: row.modelData.battery + "%"; color: row.modelData.battery <= 15 ? Theme.warn : Theme.muted; font { family: Theme.fontUi; pixelSize: 12 } }
                }

                RowLayout {
                    visible: row.open
                    spacing: 8
                    Chip { visible: row.modelData.connected; text: "Disconnect"; onClicked: root.run(["bluetoothctl", "disconnect", row.modelData.mac], "Disconnecting…") }
                    Chip { visible: row.modelData.paired && !row.modelData.connected; filled: true; text: "Connect"; onClicked: root.run(["bluetoothctl", "connect", row.modelData.mac], "Connecting to " + row.modelData.name + "…") }
                    Chip {
                        visible: !row.modelData.paired; filled: true; text: "Pair and connect"
                        onClicked: root.run(["sh", "-c", "bluetoothctl pair \"$1\" && bluetoothctl trust \"$1\" && bluetoothctl connect \"$1\"", "sh", row.modelData.mac], "Pairing with " + row.modelData.name + "…")
                    }
                    Chip { visible: row.modelData.paired; danger: true; text: "Forget"; onClicked: root.run(["bluetoothctl", "remove", row.modelData.mac], "Forgetting " + row.modelData.name + "…") }
                }
            }
        }

        Text {
            visible: list.count === 0 && root.info.powered
            anchors.centerIn: parent
            text: root.scanning ? "Looking for devices…" : "No devices yet. Choose Scan for devices."
            color: Theme.muted; font { family: Theme.fontUi; pixelSize: Theme.sizeUi }
        }
    }
}
