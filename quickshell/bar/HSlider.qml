import QtQuick

// Horizontal slider, value 0..1. `moved` fires continuously while dragging, `committed` on release.
Item {
    id: s
    property real  value: 0
    property color accent: Theme.teal
    property bool  dimmed: false
    readonly property bool pressed: area.pressed
    signal moved(real v)
    signal committed(real v)

    implicitWidth: 120
    implicitHeight: 24

    Rectangle {
        id: track
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: area.containsMouse || area.pressed ? 8 : 6; radius: height / 2
        color: Qt.alpha(Theme.mauve, 0.12)
        Behavior on height { NumberAnimation { duration: 100 } }
        Rectangle {
            width: Math.max(parent.height, track.width * Math.max(0, Math.min(1, s.value)))
            height: parent.height; radius: parent.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: s.dimmed ? Theme.dim : Qt.darker(s.accent, 1.35) }
                GradientStop { position: 1.0; color: s.dimmed ? Theme.dim : s.accent }
            }
        }
    }
    Rectangle {
        visible: area.containsMouse || area.pressed
        x: Math.max(0, Math.min(track.width - width, track.width * s.value - width / 2))
        anchors.verticalCenter: track.verticalCenter
        width: 14; height: 14; radius: 7; color: Theme.bright
        border { color: s.dimmed ? Theme.dim : s.accent; width: 3 }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        function at(x) { return Math.max(0, Math.min(1, x / width)) }
        onPressed: mouse => s.moved(at(mouse.x))
        onPositionChanged: mouse => { if (pressed) s.moved(at(mouse.x)) }
        onReleased: mouse => s.committed(at(mouse.x))
    }
}
