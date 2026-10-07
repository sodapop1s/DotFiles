import QtQuick
import QtQuick.Layouts

// Standard top row of an applet panel: back arrow, icon + title, and a slot on the right.
Item {
    id: hdr
    required property var bar
    property string icon: ""
    property string title: ""
    property color  accent: Theme.mauve
    default property alias trailing: trail.data
    property bool   compact: false      // embedded in another panel: just the right-hand controls
    signal back

    implicitHeight: compact ? 30 : 40
    height: compact ? 30 : 40

    RowLayout {
        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
        spacing: 8
        Text {
            visible: !hdr.compact
            text: "󰁍"; color: Theme.dim
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: hdr.back() }
        }
        Text {
            visible: !hdr.compact
            text: hdr.icon + "  " + hdr.title; color: hdr.accent
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 14; bold: true }
        }
        Item { Layout.fillWidth: true }
        Row { id: trail; spacing: 12; Layout.alignment: Qt.AlignVCenter }
    }
}
