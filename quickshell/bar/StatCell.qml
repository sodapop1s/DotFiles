import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    property string icon: ""
    property string label: ""
    property string value: ""
    property real   frac: 0
    property color  accent: Theme.text

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 3
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6
            Text { text: parent.parent.parent.icon; color: parent.parent.parent.accent
                   font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 } }
            Text { text: parent.parent.parent.value; color: Theme.text
                   font { family: "JetBrainsMono Nerd Font"; pixelSize: 14; bold: true } }
        }
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 64; Layout.preferredHeight: 3; radius: 1.5
            color: Qt.alpha(Theme.mauve, 0.12)
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, parent.parent.parent.frac)); height: parent.height; radius: parent.radius
                color: parent.parent.parent.accent
            }
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: parent.parent.label; color: Theme.dim
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 9 }
        }
    }
}
