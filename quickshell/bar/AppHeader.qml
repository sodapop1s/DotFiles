import QtQuick
import QtQuick.Layouts

// Standard top row of an applet panel: back chip, accent icon tile + title, and a slot on the right.
Item {
    id: hdr
    required property var bar
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property color  accent: Theme.mauve
    default property alias trailing: trail.data
    property bool   compact: false      // embedded in another panel: just the right-hand controls
    signal back

    implicitHeight: compact ? 30 : 48
    height: compact ? 30 : 48

    // a faint wash of the applet's colour so every panel feels tied to its icon
    Rectangle {
        visible: !hdr.compact
        anchors { fill: parent; leftMargin: 8; rightMargin: 8; topMargin: 4; bottomMargin: 2 }
        radius: 12
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.alpha(hdr.accent, 0.14) }
            GradientStop { position: 0.7; color: Qt.alpha(hdr.accent, 0.03) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
        spacing: 10
        Rectangle {
            visible: !hdr.compact
            Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13
            color: backArea.containsMouse ? Qt.alpha(hdr.accent, 0.22) : Qt.alpha(Theme.mauve, 0.10)
            Behavior on color { ColorAnimation { duration: 100 } }
            Text { anchors.centerIn: parent; text: "󰁍"; color: backArea.containsMouse ? hdr.accent : Theme.subtext
                   font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 } }
            MouseArea { id: backArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: hdr.back() }
        }
        Rectangle {
            visible: !hdr.compact
            Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 9
            color: Qt.alpha(hdr.accent, 0.18)
            border { color: Qt.alpha(hdr.accent, 0.35); width: 1 }
            Text { anchors.centerIn: parent; text: hdr.icon; color: hdr.accent; font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 } }
        }
        ColumnLayout {
            visible: !hdr.compact
            spacing: -1
            Text { text: hdr.title; color: Theme.bright; font { family: "JetBrainsMono Nerd Font"; pixelSize: 14; bold: true } }
            Text { visible: hdr.subtitle.length > 0; text: hdr.subtitle; color: Theme.dim; font { family: "JetBrainsMono Nerd Font"; pixelSize: 9 } }
        }
        Item { Layout.fillWidth: true }
        Row { id: trail; spacing: 8; Layout.alignment: Qt.AlignVCenter }
    }
}
