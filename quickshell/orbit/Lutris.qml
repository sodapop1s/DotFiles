import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Lutris: installed games (read from Lutris's own database) with launch buttons. See lutris.sh.
Item {
    id: root
    required property var bar
    property bool embedded: false          // true when shown as a tab inside the Games panel
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.peach

    property var    games: []
    property bool   loaded: false
    property bool   lutrisUp: false
    property var    running: []            // names of games Lutris is running
    property string status: ""
    property bool   statusErr: false
    property int    tick: 0

    function say(msg, err) { status = msg; statusErr = !!err; statusTimer.restart() }
    Timer { id: statusTimer; interval: 4000; onTriggered: root.status = "" }

    Job { id: gamesJob;  script: Quickshell.shellPath("lutris.sh") }
    Job { id: statusJob; script: Quickshell.shellPath("lutris.sh") }
    Job { id: launchJob; script: Quickshell.shellPath("lutris.sh") }

    function activate() {
        tick++
        gamesJob.go(["games"], r => { if (Array.isArray(r)) { games = r; loaded = true } })
        refreshStatus()
    }
    function refresh() { gamesJob.go(["games"], r => { if (Array.isArray(r)) { games = r; loaded = true } }); refreshStatus() }
    function refreshStatus() {
        statusJob.go(["status"], r => { if (r && r.running !== undefined) { lutrisUp = r.lutris; running = r.running } })
    }
    Timer { interval: 3000; repeat: true; running: root.visible; onTriggered: root.refreshStatus() }
    Timer { interval: 15000; repeat: true; running: root.visible; onTriggered: root.refresh() }   // picks up games added in Lutris

    function isRunning(g) { return running.indexOf(g.name) >= 0 }
    function launch(g) {
        say("launching " + g.name + "…", false)
        launchJob.go(["launch", g.id], r => { if (r && r.error) say(r.error, true) })
        statusDelay.restart()
    }
    Timer { id: statusDelay; interval: 4000; onTriggered: root.refreshStatus() }
    function openLutris() {
        launchJob.go(["open"], r => { if (r && r.error) say(r.error, true) })
        say("opening Lutris…", false)
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
    function hoursText(h) {
        if (!h) return ""
        return h < 1 ? Math.round(h * 60) + " min" : (h < 10 ? h.toFixed(1) : Math.round(h)) + " h"
    }

    AppHeader {
        id: head
        compact: root.embedded
        bar: root.bar; icon: "󰊗"; title: "Lutris"; accent: root.accent
        anchors { top: parent.top; left: parent.left; right: parent.right }
        onBack: root.bar.hubView = "main"
        Text {
            visible: root.status.length > 0
            text: root.status; color: root.statusErr ? Theme.red : Theme.green
            font { family: root.font; pixelSize: 11 }
        }
        Row {
            spacing: 6
            Rectangle { width: 7; height: 7; radius: 3.5; color: root.lutrisUp ? Theme.green : Theme.dim; anchors.verticalCenter: parent.verticalCenter }
            Text { text: root.lutrisUp ? "Lutris open" : "Lutris closed"; color: Theme.dim; font { family: root.font; pixelSize: 10 } }
        }
        Text {
            text: "open Lutris"; color: root.accent; font { family: root.font; pixelSize: 11 }
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.openLutris() }
        }
    }
    Rectangle { id: sep; anchors { top: head.bottom; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 } height: 1; color: Theme.sep }

    GridView {
        id: grid
        anchors { top: sep.bottom; topMargin: 10; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 12 }
        clip: true; boundsBehavior: Flickable.StopAtBounds
        cellWidth: Math.floor(width / 2)
        cellHeight: Math.round((cellWidth - 8) * 0.56) + 74
        model: root.games

        delegate: Item {
            id: cell
            required property var modelData
            readonly property bool isRunning: root.isRunning(modelData)
            width: grid.cellWidth; height: grid.cellHeight

            Rectangle {
                anchors { fill: parent; margins: 4 }
                radius: 12; clip: true
                color: Theme.card
                border { color: hh.hovered ? Qt.alpha(Theme.peach, 0.6) : (cell.isRunning ? Theme.green : Theme.cardBorder); width: 1 }

                Image {
                    id: art
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: Math.round(width * 0.56)
                    asynchronous: true; fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(460, 260)
                    source: cell.modelData.art ? "file://" + cell.modelData.art : ""
                    Rectangle { anchors.fill: parent; z: -1; color: Qt.alpha(Theme.peach, 0.10) }
                    Text { visible: art.status !== Image.Ready; anchors.centerIn: parent; text: "󰊗"; color: root.accent; font { family: root.font; pixelSize: 30 } }

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
                    Text { text: root.ago(cell.modelData.lastPlayed, root.tick) + (root.hoursText(cell.modelData.playtime) ? "  ·  " + root.hoursText(cell.modelData.playtime) : "")
                           color: Theme.dim; elide: Text.ElideRight; Layout.fillWidth: true; font { family: root.font; pixelSize: 10 } }
                    Text { text: cell.modelData.runner; visible: text.length > 0; color: Theme.dim; elide: Text.ElideRight; Layout.fillWidth: true
                           font { family: root.font; pixelSize: 9 } textFormat: Text.PlainText }
                    Item { Layout.fillHeight: true }
                }
                HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: root.launch(cell.modelData) }
            }
        }
    }

    // nothing installed yet: say how to start
    ColumnLayout {
        visible: root.loaded && root.games.length === 0
        anchors { centerIn: parent; verticalCenterOffset: 20 }
        width: parent.width - 80; spacing: 12
        Rectangle {
            Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 64; Layout.preferredHeight: 64; radius: 20
            color: Qt.alpha(Theme.peach, 0.16)
            Text { anchors.centerIn: parent; text: "󰊗"; color: root.accent; font { family: root.font; pixelSize: 32 } }
        }
        Text { Layout.alignment: Qt.AlignHCenter; text: "No games in Lutris yet"; color: Theme.text; font { family: root.font; pixelSize: 14; bold: true } }
        Text {
            Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
            text: "Install or add a game in Lutris (GOG, Epic, Battle.net, itch, a Windows .exe, an emulator…) and it will show up here with a play button."
            color: Theme.dim; font { family: root.font; pixelSize: 11 }
        }
        Rectangle {
            Layout.alignment: Qt.AlignHCenter; Layout.preferredHeight: 34; Layout.preferredWidth: openTxt.implicitWidth + 36; radius: 17
            color: oa.containsMouse ? Qt.lighter(root.accent, 1.1) : root.accent
            Text { id: openTxt; anchors.centerIn: parent; text: "Open Lutris"; color: Theme.crust; font { family: root.font; pixelSize: 12; bold: true } }
            MouseArea { id: oa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openLutris() }
        }
    }
}
