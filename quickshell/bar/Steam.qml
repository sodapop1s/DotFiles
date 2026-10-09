import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Steam: installed games (read from Steam's own library files) with launch buttons. See steam.sh.
Item {
    id: root
    required property var bar
    property bool embedded: false          // true when shown as a tab inside the Games panel
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.sky

    property var    games: []
    property bool   steamUp: false
    property var    running: []
    property string status: ""
    property bool   statusErr: false
    property int    tick: 0

    function say(msg, err) { status = msg; statusErr = !!err; statusTimer.restart() }
    Timer { id: statusTimer; interval: 4000; onTriggered: root.status = "" }

    Job { id: gamesJob;  script: Quickshell.shellPath("steam.sh") }
    Job { id: statusJob; script: Quickshell.shellPath("steam.sh") }
    Job { id: launchJob; script: Quickshell.shellPath("steam.sh") }

    function activate() {
        tick++
        gamesJob.go(["games"], r => { if (Array.isArray(r)) games = r })
        refreshStatus()
    }
    function refreshStatus() {
        statusJob.go(["status"], r => { if (r && r.running !== undefined) { steamUp = r.steam; running = r.running } })
    }
    Timer { interval: 3000; repeat: true; running: root.visible; onTriggered: root.refreshStatus() }

    function launch(g) {
        say("launching " + g.name + "…", false)
        launchJob.go(["launch", g.id], r => { if (r && r.error) say(r.error, true) })
        statusDelay.restart()
    }
    Timer { id: statusDelay; interval: 4000; onTriggered: root.refreshStatus() }
    Process { id: steamProc; onExited: running = false }
    function openSteam() {
        steamProc.command = ["setsid", "-f", "steam"]
        steamProc.running = true
        say("starting Steam…", false)
        statusDelay.restart()
    }

    function ago(sec, _t) {
        if (!sec) return "never played"
        var d = Math.floor((Date.now() / 1000 - sec) / 86400)
        if (d <= 0) return "played today"
        if (d === 1) return "played yesterday"
        if (d < 60) return "played " + d + " days ago"
        if (d < 700) return "played " + Math.round(d / 30) + " months ago"
        return "played " + Math.round(d / 365) + " years ago"
    }
    function sizeText(b) {
        if (!b) return ""
        if (b >= 1e9) return (b / 1e9).toFixed(1) + " GB"
        return Math.round(b / 1e6) + " MB"
    }

    AppHeader {
        id: head
        compact: root.embedded
        bar: root.bar; icon: "󰓓"; title: "Steam"; accent: root.accent
        anchors { top: parent.top; left: parent.left; right: parent.right }
        onBack: root.bar.hubView = "main"
        Text {
            visible: root.status.length > 0
            text: root.status; color: root.statusErr ? Theme.red : Theme.green
            font { family: root.font; pixelSize: 11 }
        }
        Row {
            spacing: 6
            Rectangle { width: 7; height: 7; radius: 3.5; color: root.steamUp ? Theme.green : Theme.dim; anchors.verticalCenter: parent.verticalCenter }
            Text { text: root.steamUp ? "Steam running" : "Steam not running"; color: Theme.dim; font { family: root.font; pixelSize: 10 } }
        }
        Text {
            visible: !root.steamUp
            text: "start Steam"; color: root.accent; font { family: root.font; pixelSize: 11 }
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.openSteam() }
        }
    }
    Rectangle { id: sep; anchors { top: head.bottom; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 } height: 1; color: Theme.sep }

    GridView {
        id: grid
        anchors { top: sep.bottom; topMargin: 10; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 12 }
        clip: true; boundsBehavior: Flickable.StopAtBounds
        cellWidth: Math.floor(width / 2)
        cellHeight: Math.round((cellWidth - 8) * 215 / 460) + 74
        model: root.games

        delegate: Item {
            id: cell
            required property var modelData
            readonly property bool isRunning: root.running.indexOf(modelData.id) >= 0
            width: grid.cellWidth; height: grid.cellHeight

            Rectangle {
                anchors { fill: parent; margins: 4 }
                radius: 12; clip: true
                color: Theme.card
                border { color: hh.hovered ? Qt.alpha(Theme.sky, 0.6) : (cell.isRunning ? Theme.green : Theme.cardBorder); width: 1 }

                Image {
                    id: art
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: Math.round(width * 215 / 460)
                    asynchronous: true; fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(460, 215)
                    source: cell.modelData.header ? "file://" + cell.modelData.header
                                                  : "https://cdn.cloudflare.steamstatic.com/steam/apps/" + cell.modelData.id + "/header.jpg"
                    Rectangle { anchors.fill: parent; z: -1; color: Qt.alpha(Theme.sky, 0.10) }
                    Text { visible: art.status !== Image.Ready; anchors.centerIn: parent; text: "󰓓"; color: root.accent; font { family: root.font; pixelSize: 30 } }

                    // play overlay
                    Rectangle {
                        anchors.fill: parent; color: Qt.alpha(Theme.crust, 0.55); visible: hh.hovered
                        Rectangle {
                            anchors.centerIn: parent; width: 46; height: 46; radius: 23; color: Theme.green
                            Text { anchors.centerIn: parent; text: cell.isRunning ? "󰍉" : "󰐊"; color: Theme.crust; font { family: root.font; pixelSize: 24 } }
                        }
                    }
                    Rectangle {
                        visible: cell.isRunning
                        anchors { left: parent.left; top: parent.top; margins: 8 }
                        height: 18; width: runTxt.implicitWidth + 14; radius: 9; color: Theme.green
                        Text { id: runTxt; anchors.centerIn: parent; text: "Running"; color: Theme.crust; font { family: root.font; pixelSize: 9; bold: true } }
                    }
                }
                ColumnLayout {
                    anchors { left: parent.left; right: parent.right; top: art.bottom; bottom: parent.bottom; leftMargin: 12; rightMargin: 12; topMargin: 8; bottomMargin: 8 }
                    spacing: 2
                    Text { text: cell.modelData.name; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true
                           font { family: root.font; pixelSize: 12; bold: true } textFormat: Text.PlainText }
                    Text { text: root.ago(cell.modelData.lastPlayed, root.tick) + (root.sizeText(cell.modelData.size) ? "  ·  " + root.sizeText(cell.modelData.size) : "")
                           color: Theme.dim; elide: Text.ElideRight; Layout.fillWidth: true; font { family: root.font; pixelSize: 10 } }
                    Text { visible: cell.modelData.update; text: "󰚰 update pending"; color: Theme.yellow; font { family: root.font; pixelSize: 10 } }
                    Item { Layout.fillHeight: true }
                }
                HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: root.launch(cell.modelData) }
            }
        }

        Text {
            visible: grid.count === 0
            anchors.centerIn: parent; horizontalAlignment: Text.AlignHCenter
            text: "No installed games found in Steam's library."; color: Theme.dim; font { family: root.font; pixelSize: 12 }
        }
    }
}
