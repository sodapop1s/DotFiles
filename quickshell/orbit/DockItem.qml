import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: di
    property string icon: ""
    property string label: ""
    property string badge: ""
    property bool   lit: false
    property color  accent: Theme.mauve
    signal clicked
    implicitHeight: 62

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 5
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 42; Layout.preferredHeight: 42; radius: 13
            color: diArea.containsMouse ? Qt.rgba(di.accent.r, di.accent.g, di.accent.b, 0.26)
                                        : Qt.rgba(di.accent.r, di.accent.g, di.accent.b, di.lit ? 0.20 : 0.11)
            border { color: Qt.rgba(di.accent.r, di.accent.g, di.accent.b, di.lit || diArea.containsMouse ? 0.55 : 0.0); width: 1 }
            Behavior on color { ColorAnimation { duration: 120 } }
            Text { anchors.centerIn: parent; text: di.icon; color: di.accent; font { family: "JetBrainsMono Nerd Font"; pixelSize: 20 } }
            Rectangle {
                visible: di.badge.length > 0
                anchors { right: parent.right; top: parent.top; rightMargin: -5; topMargin: -5 }
                width: Math.max(16, bdg.implicitWidth + 8); height: 16; radius: 8; color: di.accent
                Text { id: bdg; anchors.centerIn: parent; text: di.badge; color: Theme.crust; font { family: "JetBrainsMono Nerd Font"; pixelSize: 9; bold: true } }
            }
        }
        Text { Layout.alignment: Qt.AlignHCenter; text: di.label; color: diArea.containsMouse ? Theme.text : Theme.subtext
               font { family: "JetBrainsMono Nerd Font"; pixelSize: 9 } }
    }
    MouseArea { id: diArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: di.clicked() }
}
