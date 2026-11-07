import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: pt
    property string icon: ""
    property string label: ""
    property bool   confirm: true
    property color  tint: Theme.red
    property bool   armed: false
    signal run
    Layout.preferredHeight: 84
    radius: 14
    color: armed ? Qt.alpha(Theme.red, 0.22)
                 : (ptArea.containsMouse ? Qt.rgba(pt.tint.r, pt.tint.g, pt.tint.b, 0.16) : Theme.card)
    border { color: armed ? Theme.red : (ptArea.containsMouse ? Qt.rgba(pt.tint.r, pt.tint.g, pt.tint.b, 0.45) : Theme.cardBorder); width: 1 }
    Behavior on color { ColorAnimation { duration: 120 } }
    Timer { id: ptDisarm; interval: 4000; onTriggered: pt.armed = false }
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 6
        Text { Layout.alignment: Qt.AlignHCenter; text: pt.armed ? "󰀦" : pt.icon
               color: pt.armed ? Theme.red : pt.tint; font { family: "JetBrainsMono Nerd Font"; pixelSize: 26 } }
        Text { Layout.alignment: Qt.AlignHCenter; text: pt.armed ? "Click again to confirm" : pt.label
               color: pt.armed ? Theme.red : Theme.text; font { family: "JetBrainsMono Nerd Font"; pixelSize: 11; bold: true } }
    }
    MouseArea {
        id: ptArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (pt.confirm && !pt.armed) { pt.armed = true; ptDisarm.restart() }
            else { pt.armed = false; pt.run() }
        }
    }
}
