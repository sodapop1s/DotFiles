import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// AirDrop through the omdrop CLI. Nothing listens until you turn it on; it stays on for a limited time.
// Status is polled only while the panel is open.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 8

    property bool active: false
    property var st: ({ receiving: false, visible: null, remaining: null, mode: "off" })
    property var blockers: []
    property var peers: []
    property bool scanned: false
    property string windowArg: "10m"
    property string status: ""

    readonly property bool on: st.receiving === true
    readonly property bool ready: blockers.length === 0
    function mmss(s) { return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0") }
    readonly property string summary: {
        if (!ready && !on) return "Not ready"
        if (!on) return "Off"
        if (st.visible === false) return "On, not visible"
        if (st.mode === "once") return "Visible until one file arrives"
        if (st.remaining !== null && st.remaining !== undefined) return "Visible, " + mmss(st.remaining) + " left"
        return "Visible"
    }
    function say(msg) { status = msg; statusTimer.restart() }
    Timer { id: statusTimer; interval: 6000; onTriggered: root.status = "" }

    function refresh() { if (!statusProc.running) statusProc.running = true }
    Timer { interval: 3000; repeat: true; running: root.active; triggeredOnStart: true; onTriggered: root.refresh() }
    onActiveChanged: if (active) doctorProc.running = true; else peersProc.running = false

    Process {
        id: statusProc
        command: ["omdrop", "status", "--json"]
        stdout: StdioCollector { onStreamFinished: { try { root.st = JSON.parse(text) } catch (e) {} } }
    }
    Process {
        id: doctorProc
        command: ["omdrop", "doctor", "--json"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.blockers = JSON.parse(text).missing || [] } catch (e) { root.blockers = [{ id: "cli", say: "the omdrop command is not installed" }] } }
        }
    }
    Process {
        id: toggleProc
        property string err: ""
        stderr: StdioCollector { onStreamFinished: toggleProc.err = text.trim().split("\n").pop().replace(/^omdrop: /, "") }
        onExited: code => {
            if (code !== 0) root.say(err || "Could not change AirDrop")
            else if (!root.on) { root.peers = []; root.scanned = false }
            root.refresh(); doctorProc.running = true
        }
    }
    function toggle() {
        if (toggleProc.running) return
        toggleProc.err = ""
        toggleProc.command = on ? ["omdrop", "off"] : ["omdrop", "on", windowArg]
        peersProc.running = false
        toggleProc.running = true
    }
    Process {
        id: peersProc
        command: ["omdrop", "peers", "--json", "-n"]
        stdout: StdioCollector { onStreamFinished: { try { root.peers = JSON.parse(text) } catch (e) {} root.scanned = true } }
    }
    function scan() { if (!on) return; scanned = false; peersProc.running = true }
    Process {
        id: sendProc
        stderr: StdioCollector { onStreamFinished: { var t = text.trim(); if (t) root.say(t.split("\n").pop().replace(/^omdrop: /, "")) } }
    }
    function send(p) {
        if (sendProc.running) return
        sendProc.command = ["omdrop", "send", "--pick", "--to", p.mac]
        sendProc.running = true
    }

    component Chip: Rectangle {
        id: chip
        property string text
        property bool selected: false
        signal clicked()
        implicitWidth: label.implicitWidth + 20; implicitHeight: 28
        radius: 8
        color: selected || area.containsMouse ? Theme.raised : "transparent"
        border { width: 1; color: selected ? Theme.accent : Theme.hairline }
        Text { id: label; anchors.centerIn: parent; text: chip.text; color: Theme.text; font { family: Theme.fontUi; pixelSize: 12 } }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: chip.clicked() }
    }

    RowLayout {
        Layout.fillWidth: true
        Text { text: root.summary; color: Theme.text; Layout.fillWidth: true; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
        Chip { text: toggleProc.running ? "…" : (root.on ? "Turn off" : "Turn on"); enabled: root.ready || root.on; onClicked: root.toggle() }
    }
    RowLayout {
        visible: !root.on
        spacing: 6
        Repeater {
            model: [ { v: "10m", l: "10 min" }, { v: "30m", l: "30 min" }, { v: "1h", l: "1 hour" }, { v: "once", l: "One file" } ]
            delegate: Chip { required property var modelData; text: modelData.l; selected: root.windowArg === modelData.v; onClicked: root.windowArg = modelData.v }
        }
    }
    Text {
        visible: !root.ready && !root.on
        Layout.fillWidth: true
        text: root.blockers.map(b => b.say).join(". ")
        wrapMode: Text.WordWrap
        color: Theme.warn; font { family: Theme.fontUi; pixelSize: 12 }
    }
    RowLayout {
        visible: root.on
        Chip { text: peersProc.running ? "Searching…" : "Find devices"; onClicked: root.scan() }
    }
    Repeater {
        model: root.on ? root.peers : []
        delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true
            Text { text: modelData.name || modelData.mac; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
            Chip { text: "Send files"; onClicked: root.send(modelData) }
        }
    }
    Text {
        visible: root.on && root.scanned && root.peers.length === 0
        text: "No devices found."
        color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 }
    }
    Text {
        visible: root.status.length > 0
        Layout.fillWidth: true
        text: root.status; wrapMode: Text.WordWrap
        color: Theme.warn; font { family: Theme.fontUi; pixelSize: 12 }
    }
}
