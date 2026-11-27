import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

RowLayout {
    id: sl
    property string icon: "󰕿"
    property bool   iconDim: false
    property real   value: 0
    property string displayText: ""
    property color  accentColor: Theme.teal
    signal slid(real pct)
    signal iconClicked

    implicitHeight: 38
    spacing: 12

    Item {
        Layout.preferredWidth: 24; Layout.preferredHeight: 24
        Text {
            anchors.centerIn: parent
            text: sl.icon
            color: sl.iconDim ? Theme.dim : sl.accentColor
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 17 }
        }
        MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: sl.iconClicked() }
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 24

        Rectangle {
            id: slTrack
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            height: slArea.containsMouse || slArea.pressed ? 8 : 6; radius: height / 2
            color: Qt.alpha(Theme.mauve, 0.12)
            Behavior on height { NumberAnimation { duration: 100 } }

            Rectangle {
                width: Math.max(parent.height, slTrack.width * sl.value)
                height: parent.height; radius: parent.radius
                color: sl.accentColor
            }
        }

        Rectangle {
            visible: slArea.containsMouse || slArea.pressed
            x: Math.max(0, Math.min(slTrack.width - width, slTrack.width * sl.value - width / 2))
            anchors.verticalCenter: slTrack.verticalCenter
            width: 14; height: 14; radius: 7
            color: "white"
        }

        MouseArea {
            id: slArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function emit(mx) { sl.slid(Math.max(0, Math.min(1, mx / slTrack.width))) }
            onPressed:         mouse => emit(mouse.x)
            onPositionChanged: mouse => { if (pressed) emit(mouse.x) }
        }
    }

    Text {
        text: sl.displayText
        color: Theme.subtext
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
        Layout.preferredWidth: 34
        horizontalAlignment: Text.AlignRight
    }
}
