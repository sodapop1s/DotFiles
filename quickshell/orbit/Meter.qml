import QtQuick

// A thin progress bar, 0..1. Colour is neutral unless the owner passes a state tone.
Rectangle {
    id: m
    property real value: 0
    property color tone: Theme.muted
    implicitHeight: 4
    radius: 2
    color: Theme.hairline
    Rectangle { width: parent.width * Math.max(0, Math.min(1, m.value)); height: parent.height; radius: 2; color: m.tone }
}
