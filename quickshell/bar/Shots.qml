import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Capture tools: screenshot (region / window / screen), colour picker with history, recent shots.
// Screenshots are taken by niri itself; they land in ~/Pictures/Screenshots (see niri config).
Item {
    id: root
    required property var bar
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.peach

    property var    recent: []
    property var    colors: []          // newest first, "#rrggbb"
    property string status: ""
    property bool   statusErr: false
    property int    tick: 0

    function say(msg, err) { status = msg; statusErr = !!err; statusTimer.restart() }
    Timer { id: statusTimer; interval: 4000; onTriggered: root.status = "" }

    Job { id: recentJob; script: Quickshell.shellPath("shots.sh") }
    Job { id: copyJob;   script: Quickshell.shellPath("shots.sh") }
    function activate() {
        tick++
        recentJob.go(["recent", "12"], r => { if (Array.isArray(r)) recent = r })
    }

    // ── colour history (kept in a small file) ─────────────
    FileView {
        id: colorFile
        path: Quickshell.env("HOME") + "/.local/state/qs-bar-colors.json"
        onLoaded: { try { var c = JSON.parse(colorFile.text()); if (Array.isArray(c)) root.colors = c } catch(e) {} }
    }
    function addColor(hex) {
        var c = colors.filter(x => x !== hex)
        c.unshift(hex)
        colors = c.slice(0, 16)
        colorFile.setText(JSON.stringify(colors))
    }

    // ── Capturing: close the hub first so it isn't in the shot ──
    property var pendingCmd: []
    Process { id: runProc; onExited: running = false }
    Timer { id: launchTimer; interval: 450; onTriggered: { runProc.command = root.pendingCmd; runProc.running = true } }
    function capture(kind) {
        var action = kind === "region" ? "screenshot" : (kind === "screen" ? "screenshot-screen" : "screenshot-window")
        pendingCmd = ["niri", "msg", "action", action]
        root.bar.hubOpen = false
        launchTimer.restart()
    }

    // colour picker: niri lets you click a pixel, then prints the colour
    Process {
        id: pickProc
        command: ["niri", "msg", "pick-color"]
        stdout: StdioCollector {
            onStreamFinished: {
                var hex = root.parseColor(text)
                if (hex) {
                    root.addColor(hex)
                    root.copyText(hex)
                    notifyProc.command = ["notify-send", "-a", "Color picker", "-u", "low", "Copied " + hex, "Saved in the Capture panel history"]
                    notifyProc.running = true
                }
            }
        }
    }
    Process { id: notifyProc; onExited: running = false }
    Timer { id: pickTimer; interval: 350; onTriggered: pickProc.running = true }
    function pickColor() { root.bar.hubOpen = false; pickTimer.restart() }

    function parseColor(t) {
        var m = /#([0-9a-fA-F]{6})\b/.exec(t)
        if (m) return "#" + m[1].toLowerCase()
        var n = t.match(/[0-9]*\.?[0-9]+/g)       // e.g. rgb(0.2, 0.4, 0.6)
        if (n && n.length >= 3) {
            var v = n.slice(0, 3).map(Number)
            var scale = v.every(x => x <= 1.0001) && /\./.test(t) ? 255 : 1
            return "#" + v.map(x => Math.max(0, Math.min(255, Math.round(x * scale))).toString(16).padStart(2, "0")).join("")
        }
        return ""
    }
    Process { id: copyTextProc; onExited: running = false }
    function copyText(s) {
        copyTextProc.command = ["bash", "-c", "printf %s \"$1\" | wl-copy", "_", s]
        copyTextProc.running = true
    }
    function copyImage(item) {
        copyJob.go(["copy", item.path], r => { if (r && r.error) say(r.error, true); else say("image copied", false) })
    }
    Process { id: openProc; onExited: running = false }
    function openPath(p) { openProc.command = ["xdg-open", p]; openProc.running = true; root.bar.hubOpen = false }

    function ago(sec, _t) {
        var s = Math.max(0, Math.round(Date.now() / 1000 - sec))
        if (s < 45) return "now"
        if (s < 3600) return Math.max(1, Math.round(s / 60)) + "m ago"
        if (s < 86400) return Math.round(s / 3600) + "h ago"
        return Math.round(s / 86400) + "d ago"
    }

    // ── UI ────────────────────────────────────────────────
    AppHeader {
        id: head
        bar: root.bar; icon: "󰄀"; title: "Capture"; accent: root.accent
        anchors { top: parent.top; left: parent.left; right: parent.right }
        onBack: root.bar.hubView = "main"
        Text {
            visible: root.status.length > 0
            text: root.status; color: root.statusErr ? Theme.red : Theme.green
            font { family: root.font; pixelSize: 11 }
        }
        Text {
            text: "open folder"; color: Theme.dim; font { family: root.font; pixelSize: 11 }
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                        onClicked: root.openPath(Quickshell.env("HOME") + "/Pictures/Screenshots") }
        }
    }
    Rectangle { id: sep; anchors { top: head.bottom; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 } height: 1; color: Theme.sep }

    // action buttons
    RowLayout {
        id: actions
        anchors { top: sep.bottom; topMargin: 12; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 }
        spacing: 8
        Repeater {
            model: [
                { id: "region", icon: "󰆞", label: "Region" },
                { id: "window", icon: "󰖲", label: "Window" },
                { id: "screen", icon: "󰍹", label: "Screen" },
                { id: "color",  icon: "󰃣", label: "Pick color" }
            ]
            delegate: Rectangle {
                id: btn
                required property var modelData
                Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.preferredHeight: 76; radius: 14
                color: ba.containsMouse ? Qt.alpha(Theme.peach, 0.18) : Theme.card
                border { color: ba.containsMouse ? Qt.alpha(Theme.peach, 0.5) : Theme.cardBorder; width: 1 }
                Behavior on color { ColorAnimation { duration: 120 } }
                ColumnLayout {
                    anchors.centerIn: parent; spacing: 6
                    Text { Layout.alignment: Qt.AlignHCenter; text: btn.modelData.icon; color: root.accent; font { family: root.font; pixelSize: 24 } }
                    Text { Layout.alignment: Qt.AlignHCenter; text: btn.modelData.label; color: Theme.text; font { family: root.font; pixelSize: 10 } }
                }
                MouseArea {
                    id: ba; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { if (btn.modelData.id === "color") root.pickColor(); else root.capture(btn.modelData.id) }
                }
            }
        }
    }

    // colour history
    Text {
        id: colorsTitle
        visible: root.colors.length > 0
        anchors { top: actions.bottom; topMargin: 14; left: parent.left; leftMargin: 18 }
        text: "COLORS"; color: Theme.dim; font { family: root.font; pixelSize: 10; bold: true; letterSpacing: 1 }
    }
    Flow {
        id: colorFlow
        visible: root.colors.length > 0
        anchors { top: colorsTitle.bottom; topMargin: 6; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 }
        spacing: 6
        Repeater {
            model: root.colors
            delegate: Rectangle {
                id: sw
                required property string modelData
                width: 56; height: 28; radius: 8; color: modelData
                border { color: swa.containsMouse ? "white" : Theme.cardBorder; width: swa.containsMouse ? 2 : 1 }
                MouseArea { id: swa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.copyText(sw.modelData); root.say("copied " + sw.modelData, false) } }
                Text { visible: swa.containsMouse; anchors.centerIn: parent; text: sw.modelData.slice(1)
                       color: (parseInt(sw.modelData.slice(1, 3), 16) * 0.3 + parseInt(sw.modelData.slice(3, 5), 16) * 0.6 + parseInt(sw.modelData.slice(5, 7), 16) * 0.1) > 140 ? Theme.crust : "#ffffff"
                       font { family: root.font; pixelSize: 9 } }
            }
        }
    }

    // recent screenshots
    Text {
        id: recentTitle
        anchors { top: root.colors.length > 0 ? colorFlow.bottom : actions.bottom; topMargin: 14; left: parent.left; leftMargin: 18 }
        text: "RECENT"; color: Theme.dim; font { family: root.font; pixelSize: 10; bold: true; letterSpacing: 1 }
    }
    GridView {
        id: grid
        anchors { top: recentTitle.bottom; topMargin: 6; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 12 }
        clip: true; boundsBehavior: Flickable.StopAtBounds
        cellWidth: Math.floor(width / 3); cellHeight: Math.round(cellWidth * 0.62) + 6
        model: root.recent

        delegate: Item {
            id: cell
            required property var modelData
            width: grid.cellWidth; height: grid.cellHeight
            Rectangle {
                anchors { fill: parent; margins: 3 }
                radius: 10; clip: true
                color: Qt.alpha(Theme.mauve, 0.08)
                border { color: hh.hovered ? Qt.alpha(Theme.peach, 0.6) : Theme.cardBorder; width: 1 }
                Image {
                    anchors { fill: parent; margins: 1 }
                    asynchronous: true; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(360, 230)
                    source: "file://" + cell.modelData.path
                }
                Rectangle {
                    visible: hh.hovered
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 24; color: Qt.alpha(Theme.crust, 0.78)
                    Text { anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                           text: root.ago(cell.modelData.at, root.tick); color: Theme.text; font { family: root.font; pixelSize: 10 } }
                    Text {
                        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        text: "󰆏"; color: root.accent; font { family: root.font; pixelSize: 14 }
                        MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: root.copyImage(cell.modelData) }
                    }
                }
                HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; z: -1; onClicked: root.openPath(cell.modelData.path) }
            }
        }
        Text { visible: grid.count === 0; anchors.centerIn: parent; text: "No screenshots yet"; color: Theme.dim; font { family: root.font; pixelSize: 12 } }
    }
}
