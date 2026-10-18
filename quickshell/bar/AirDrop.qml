import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// AirDrop with iPhones / iPads / Macs, driven by the `omdrop` CLI (nixos/pkgs/omdrop.nix).
// On = visible to nearby Apple devices and receiving, for the chosen window. Click a nearby
// device to pick files and send. The radio needs root through pkexec; polkit allows it for the
// active session, so there is no password prompt.
Item {
    id: root
    required property var bar
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.sky

    property var    st: ({ receiving: false, visible: null, remaining: null, name: "", mode: "off", reason: null })
    property var    blockers: []                 // doctor: what stands in the way
    property var    peers: []                    // [{ mac, rssi, name }]
    property bool   scanned: false
    property string windowArg: "10m"
    property string status: ""
    property bool   statusErr: false

    readonly property bool on: st.receiving === true
    readonly property bool busy: toggleProc.running
    readonly property bool ready: blockers.length === 0

    function say(msg, err) { status = msg; statusErr = !!err; statusTimer.restart() }
    Timer { id: statusTimer; interval: 6000; onTriggered: root.status = "" }

    function activate() { refresh(); doctorProc.running = true }
    function refresh() { if (!statusProc.running) statusProc.running = true }
    Timer { interval: 3000; repeat: true; running: root.visible && root.bar.hubOpen; onTriggered: root.refresh() }
    onVisibleChanged: if (!visible) { peersProc.running = false }

    Process {
        id: statusProc
        command: ["omdrop", "status", "--json"]
        stdout: StdioCollector { onStreamFinished: { try { root.st = JSON.parse(text) } catch(e) {} } }
    }
    Process {
        id: doctorProc
        command: ["omdrop", "doctor", "--json"]
        stdout: StdioCollector {
            onStreamFinished: { try { root.blockers = JSON.parse(text).missing || [] } catch(e) { root.blockers = [{ id: "cli", say: "the omdrop command isn't installed" }] } }
        }
    }

    // ── on / off ──────────────────────────────────────────
    Process {
        id: toggleProc
        property string err: ""
        stderr: StdioCollector { onStreamFinished: toggleProc.err = text.trim().split("\n").pop().replace(/^omdrop: /, "") }
        onExited: code => {
            if (code !== 0) root.say(err || "couldn't change AirDrop", true)
            else if (!root.on) { root.peers = []; root.scanned = false }
            root.refresh(); doctorProc.running = true
        }
    }
    function toggle() {
        if (busy) return
        toggleProc.err = ""
        toggleProc.command = root.on ? ["omdrop", "off"] : ["omdrop", "on", root.windowArg]
        peersProc.running = false
        toggleProc.running = true
    }

    // ── nearby devices ────────────────────────────────────
    Process {
        id: peersProc
        command: ["omdrop", "peers", "--json", "-n"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.peers = JSON.parse(text) } catch(e) {}
                root.scanned = true
            }
        }
        stderr: StdioCollector { onStreamFinished: { var t = text.trim(); if (t) root.say(t.split("\n").pop().replace(/^omdrop: /, ""), true) } }
    }
    function scan() { if (!on) return; scanned = false; peersProc.running = true }

    // ── send ──────────────────────────────────────────────
    Process {
        id: sendProc
        property string who: ""
        stderr: StdioCollector { onStreamFinished: { var t = text.trim(); if (t && sendProc.lastCode !== 0) root.say(t.split("\n").pop().replace(/^omdrop: /, ""), true) } }
        property int lastCode: 0
        onExited: code => { lastCode = code; if (code === 0) root.say("sent to " + who, false); else if (code === 1) {} }
    }
    function send(p) {
        if (sendProc.running) return
        sendProc.who = p.name || p.mac
        sendProc.command = ["omdrop", "send", "--pick", "--to", p.mac]
        root.say("choose files…", false)
        sendProc.running = true
    }

    function mmss(s) { return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0") }
    readonly property string subtitle: {
        if (!ready && !on) return "not ready"
        if (!on) return "off"
        if (st.visible === false) return "receiving, not visible"
        if (st.mode === "once") return "visible until one file arrives"
        if (st.remaining !== null && st.remaining !== undefined) return "visible · " + mmss(st.remaining) + " left"
        return "visible"
    }

    // ── UI ────────────────────────────────────────────────
    AppHeader {
        id: head
        bar: root.bar; icon: "󰒊"; title: "AirDrop"; accent: root.accent
        subtitle: root.subtitle
        anchors { top: parent.top; left: parent.left; right: parent.right }
        onBack: root.bar.hubView = "main"
        Text {
            visible: root.status.length > 0
            text: root.status; color: root.statusErr ? Theme.red : Theme.green
            elide: Text.ElideRight; Layout.maximumWidth: 200
            font { family: root.font; pixelSize: 11 }
        }
        HeaderButton {
            text: root.busy ? "…" : (root.on ? "on" : "off")
            accent: root.on ? Theme.green : Theme.dim; active: root.on
            onClicked: root.toggle()
        }
    }

    // window length (only matters when turning on)
    RowLayout {
        id: windows
        visible: !root.on
        anchors { top: head.bottom; topMargin: 10; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 }
        spacing: 8
        Repeater {
            model: [ { v: "10m", l: "10 min" }, { v: "30m", l: "30 min" }, { v: "1h", l: "1 hour" }, { v: "once", l: "one file" } ]
            delegate: Rectangle {
                id: chip
                required property var modelData
                readonly property bool sel: root.windowArg === modelData.v
                Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.preferredHeight: 34; radius: 12
                color: sel ? Qt.alpha(root.accent, 0.2) : (ca.containsMouse ? Qt.alpha(root.accent, 0.1) : Theme.card)
                border { color: sel ? Qt.alpha(root.accent, 0.5) : Theme.cardBorder; width: 1 }
                Text { anchors.centerIn: parent; text: chip.modelData.l; color: chip.sel ? Theme.bright : Theme.subtext
                       font { family: root.font; pixelSize: 11; bold: chip.sel } }
                MouseArea { id: ca; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.windowArg = chip.modelData.v }
            }
        }
    }

    // why it can't run
    EmptyState {
        visible: !root.on && !root.ready
        anchors { centerIn: parent; verticalCenterOffset: 20 }
        width: parent.width - 48
        icon: "󰀦"; accent: Theme.yellow
        title: "Not ready"
        hint: root.blockers.map(b => b.say).join("\n")
    }
    EmptyState {
        visible: !root.on && root.ready
        anchors { centerIn: parent; verticalCenterOffset: 20 }
        icon: "󰒊"; accent: root.accent
        title: "Off"
        hint: "Turn on to become visible to nearby iPhones and Macs. Received files land in " + (root.st.dir || "~/Downloads") + "."
    }

    // nearby devices
    Item {
        visible: root.on
        anchors { top: head.bottom; topMargin: 8; left: parent.left; right: parent.right; bottom: parent.bottom }

        RowLayout {
            id: nearbyHead
            anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 18; rightMargin: 14 }
            Text { text: "NEARBY"; color: Theme.dim; Layout.fillWidth: true
                   font { family: root.font; pixelSize: 10; bold: true; letterSpacing: 1 } }
            HeaderButton {
                text: peersProc.running ? "󰑐  asking…" : "󰑐  scan"; accent: root.accent; active: peersProc.running
                onClicked: root.scan()
            }
        }
        ListView {
            id: list
            anchors { top: nearbyHead.bottom; topMargin: 6; left: parent.left; right: parent.right; bottom: tip.top; leftMargin: 14; rightMargin: 14; bottomMargin: 6 }
            clip: true; spacing: 6; boundsBehavior: Flickable.StopAtBounds
            model: root.peers
            delegate: Rectangle {
                id: row
                required property var modelData
                width: list.width; height: 46; radius: 12
                color: hh.hovered ? Qt.alpha(root.accent, 0.12) : Theme.card
                border { color: hh.hovered ? Qt.alpha(root.accent, 0.5) : Theme.cardBorder; width: 1 }
                HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: root.send(row.modelData) }
                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 12 }
                    spacing: 10
                    Rectangle {
                        Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 9
                        color: Qt.alpha(root.accent, 0.18)
                        Text { anchors.centerIn: parent; text: "󰄜"; color: root.accent; font { family: root.font; pixelSize: 16 } }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 0
                        Text { text: row.modelData.name || "Unnamed device"; color: row.modelData.name ? Theme.text : Theme.subtext
                               elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText
                               font { family: root.font; pixelSize: 12; bold: !!row.modelData.name } }
                        Text { text: row.modelData.mac + (row.modelData.rssi !== null && row.modelData.rssi !== undefined ? "  ·  " + row.modelData.rssi + " dBm" : "")
                               color: Theme.dim; font { family: root.font; pixelSize: 10 } }
                    }
                    Text { text: "󰒊  send"; color: hh.hovered ? root.accent : Theme.dim; font { family: root.font; pixelSize: 11 } }
                }
            }
        }
        EmptyState {
            visible: root.peers.length === 0
            anchors { centerIn: list }
            width: list.width
            icon: peersProc.running ? "󰑐" : "󰍉"; accent: root.accent
            title: peersProc.running ? "Asking nearby devices…" : (root.scanned ? "Nobody found" : "Press scan")
            hint: peersProc.running ? "takes 15–20 s" : "On the iPhone, open the share sheet (or AirDrop → Everyone for 10 minutes), then scan."
        }
        Text {
            id: tip
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 18; rightMargin: 14; bottomMargin: 10 }
            text: "Visible as “" + (root.st.name || "this computer") + "”. Click a device to choose files."
            color: Theme.dim; elide: Text.ElideRight; font { family: root.font; pixelSize: 10 }
        }
    }
}
