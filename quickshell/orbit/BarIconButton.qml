import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: ib
    property string icon: ""
    property string tip: ""
    property color  tint: Theme.text
    signal clicked
    Layout.preferredWidth: 40; Layout.preferredHeight: 40
    radius: 12
    color: ibArea.containsMouse ? Qt.rgba(ib.tint.r, ib.tint.g, ib.tint.b, 0.18) : Theme.card
    border { color: ibArea.containsMouse ? Qt.rgba(ib.tint.r, ib.tint.g, ib.tint.b, 0.45) : Theme.cardBorder; width: 1 }
    Behavior on color { ColorAnimation { duration: 120 } }
    Text {
        anchors.centerIn: parent
        text: ib.icon
        color: ibArea.containsMouse ? ib.tint : Theme.subtext
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
    }
    MouseArea { id: ibArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ib.clicked() }
}
