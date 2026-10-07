import QtQuick
import QtQuick.Layouts
import Quickshell

// Wallpaper picker: thumbnails of ~/Pictures/Wallpaper (see wallpaper.sh), click to apply with swww.
Item {
    id: root
    required property var bar
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.pink

    property var    images: []
    property string current: ""
    property string status: ""
    property bool   statusErr: false

    function say(msg, err) { status = msg; statusErr = !!err; statusTimer.restart() }
    Timer { id: statusTimer; interval: 4000; onTriggered: root.status = "" }

    Job { id: job; script: Quickshell.shellPath("wallpaper.sh") }
    Job { id: curJob; script: Quickshell.shellPath("wallpaper.sh") }

    function activate() {
        job.go(["list"], r => { if (Array.isArray(r)) images = r; else root.say("could not list wallpapers", true) })
        curJob.go(["current"], r => { if (r && r.path) current = r.path })
    }
    function apply(img) {
        current = img.path
        say("applying " + img.name + "…", false)
        applyJob.go(["set", img.path], r => {
            if (r && r.error) say(r.error, true); else say("wallpaper: " + img.name, false)
        })
    }
    function random() {
        applyJob.go(["random"], r => {
            if (r && r.error) say(r.error, true)
            else if (r && r.path) { current = r.path; say("random wallpaper", false) }
        })
    }
    Job { id: applyJob; script: Quickshell.shellPath("wallpaper.sh") }

    AppHeader {
        id: head
        bar: root.bar; icon: "󰸉"; title: "Wallpaper"; accent: root.accent
        anchors { top: parent.top; left: parent.left; right: parent.right }
        onBack: root.bar.hubView = "main"

        Text {
            visible: root.status.length > 0
            text: root.status; color: root.statusErr ? Theme.red : Theme.green
            font { family: root.font; pixelSize: 11 }
        }
        Text {
            text: "󰒝 random"; color: Theme.dim; font { family: root.font; pixelSize: 11 }
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.random() }
        }
    }
    Rectangle { id: sep; anchors { top: head.bottom; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 } height: 1; color: Theme.sep }

    GridView {
        id: grid
        anchors { top: sep.bottom; topMargin: 10; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 12 }
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        cellWidth: Math.floor(width / 3)
        cellHeight: Math.round(cellWidth * 0.66) + 6
        model: root.images

        delegate: Item {
            id: cell
            required property var modelData
            readonly property bool isCurrent: modelData.path === root.current
            width: grid.cellWidth; height: grid.cellHeight

            Rectangle {
                anchors { fill: parent; margins: 3 }
                radius: 10; clip: true
                color: Qt.alpha(Theme.mauve, 0.08)
                border { color: cell.isCurrent ? root.accent : (hh.hovered ? Qt.alpha(Theme.pink, 0.5) : Theme.cardBorder); width: cell.isCurrent ? 2 : 1 }

                Image {
                    anchors { fill: parent; margins: 2 }
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(360, 240)
                    source: "file://" + cell.modelData.path
                }
                // name + current marker
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 22; color: Qt.alpha(Theme.crust, 0.72)
                    visible: hh.hovered || cell.isCurrent
                    Text {
                        anchors { left: parent.left; leftMargin: 8; right: parent.right; rightMargin: 24; verticalCenter: parent.verticalCenter }
                        text: cell.modelData.name; color: Theme.text; elide: Text.ElideRight
                        font { family: root.font; pixelSize: 10 }
                    }
                    Text {
                        visible: cell.isCurrent
                        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        text: "󰄬"; color: root.accent; font { family: root.font; pixelSize: 13 }
                    }
                }
                HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: root.apply(cell.modelData) }
            }
        }

        Text {
            visible: grid.count === 0
            anchors.centerIn: parent
            text: "No images in ~/Pictures/Wallpaper"; color: Theme.dim
            font { family: root.font; pixelSize: 12 }
        }
    }
}
