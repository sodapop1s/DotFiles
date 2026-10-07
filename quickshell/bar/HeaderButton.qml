import QtQuick

// Small pill button for the right-hand side of an applet header (rescan, clear, random, …).
Rectangle {
    id: hb
    property string text: ""
    property color  accent: Theme.mauve
    property bool   active: false
    signal clicked

    implicitHeight: 24
    implicitWidth: label.implicitWidth + 20
    height: implicitHeight; width: implicitWidth
    radius: 12
    color: active ? Qt.alpha(accent, 0.22) : (area.containsMouse ? Qt.alpha(accent, 0.16) : Qt.alpha(Theme.mauve, 0.08))
    border { color: active || area.containsMouse ? Qt.alpha(accent, 0.45) : Theme.cardBorder; width: 1 }
    Behavior on color { ColorAnimation { duration: 100 } }
    Text {
        id: label
        anchors.centerIn: parent
        text: hb.text; color: hb.active || area.containsMouse ? hb.accent : Theme.subtext
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 10; bold: hb.active }
    }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: hb.clicked() }
}
