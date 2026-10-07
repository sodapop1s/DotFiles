import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    required property var bar
    id: powerView

    function run(cmd) { bar.hubOpen = false; bar.powerProc.command = cmd; bar.powerProc.running = true }
    onVisibleChanged: { if (!visible) disarm.restart() }
    Timer { id: disarm; interval: 1; onTriggered: { for (var i = 0; i < powerGrid.children.length; i++) powerGrid.children[i].armed = false } }

    RowLayout {
        id: powerNav
        anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 }
        height: 40; spacing: 8
        Text {
            text: "󰁍"; color: Theme.dim; font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: bar.hubView = "main" }
        }
        Text { text: "󰐥 Power"; color: Theme.red; font { family: "JetBrainsMono Nerd Font"; pixelSize: 14; bold: true } }
        Item { Layout.fillWidth: true }
        Text { text: "click twice to confirm"; color: Theme.dim; font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 } }
    }

    GridLayout {
        id: powerGrid
        anchors { top: powerNav.bottom; topMargin: 6; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 }
        columns: 2; rowSpacing: 10; columnSpacing: 10

        PowerTile { Layout.fillWidth: true; Layout.preferredWidth: 1
            icon: "󰍃"; label: "Log out"; confirm: true; tint: Theme.peach
            onRun: powerView.run(["niri", "msg", "action", "quit", "--skip-confirmation"]) }
        PowerTile { Layout.fillWidth: true; Layout.preferredWidth: 1
            icon: "󰤄"; label: "Sleep"; confirm: false; tint: Theme.sky
            onRun: powerView.run(["systemctl", "suspend"]) }
        PowerTile { Layout.fillWidth: true; Layout.preferredWidth: 1
            icon: "󰜉"; label: "Restart"; confirm: true; tint: Theme.yellow
            onRun: powerView.run(["systemctl", "reboot"]) }
        PowerTile { Layout.fillWidth: true; Layout.preferredWidth: 1
            icon: "󰐥"; label: "Shut down"; confirm: true; tint: Theme.red
            onRun: powerView.run(["systemctl", "poweroff"]) }
    }
}
