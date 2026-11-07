import QtQuick

// A thin horizontal slider, 0..1. Emits moved(v) while dragging; the owner stores the value.
Item {
    id: root
    property real value: 0
    property color tone: Theme.text
    signal moved(real v)

    implicitHeight: 20
    implicitWidth: 120
    readonly property real frac: Math.max(0, Math.min(1, value))

    Rectangle {
        id: track
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 4; radius: 2; color: Theme.hairline
        Rectangle { width: parent.width * root.frac; height: parent.height; radius: 2; color: root.tone }
    }
    Rectangle {
        visible: area.containsMouse || area.pressed
        x: track.width * root.frac - width / 2; anchors.verticalCenter: parent.verticalCenter
        width: 12; height: 12; radius: 6; color: Theme.text
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true          // dragging a slider must not scroll the panel
        function set(mx) { root.moved(Math.max(0, Math.min(1, mx / width))) }
        onPressed: m => set(m.x)
        onPositionChanged: m => { if (pressed) set(m.x) }
    }
}
