import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: pb
    property string icon: ""
    property string text: ""
    property string badge: ""
    property bool   lit: false
    property color  accent: Theme.mauve
    signal clicked
    implicitHeight: 38
    radius: 12
    color: pbArea.containsMouse ? Qt.rgba(pb.accent.r, pb.accent.g, pb.accent.b, 0.16) : Theme.card
    border { color: pbArea.containsMouse || pb.lit ? Qt.rgba(pb.accent.r, pb.accent.g, pb.accent.b, 0.45) : Theme.cardBorder; width: 1 }
    Behavior on color { ColorAnimation { duration: 120 } }
    RowLayout {
        anchors.centerIn: parent
        spacing: 8
        Text { text: pb.icon; color: pb.accent; font { family: "JetBrainsMono Nerd Font"; pixelSize: 15 } }
        Text { text: pb.text; color: Theme.text; font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 } }
        Rectangle {
            visible: pb.badge.length > 0
            Layout.preferredWidth: Math.max(18, badgeText.implicitWidth + 10); Layout.preferredHeight: 16; radius: 8
            color: pb.accent
            Text { id: badgeText; anchors.centerIn: parent; text: pb.badge; color: Theme.crust
                   font { family: "JetBrainsMono Nerd Font"; pixelSize: 9; bold: true } }
        }
        Rectangle { visible: pb.lit; Layout.preferredWidth: 6; Layout.preferredHeight: 6; radius: 3; color: pb.accent }
    }
    MouseArea { id: pbArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pb.clicked() }
}
