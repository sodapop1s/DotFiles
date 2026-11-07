import QtQuick
import Quickshell
import Quickshell.Wayland

// A centred card that pops in on the shared spring, with its own dim behind it and keyboard focus
// while open. Used by the launcher, clipboard picker and study window. Escape or a click outside closes.
PanelWindow {
    id: win

    property bool open: false
    property real cardWidth: 640
    property real maxCardHeight: 640
    signal closeRequested()
    default property alias content: body.data

    anchors { top: true; bottom: true; left: true; right: true }
    visible: open || spring.moving
    color: "transparent"
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "orbit-overlay"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Spring { id: spring; target: win.open ? 1 : 0 }
    Shortcut { sequence: "Escape"; enabled: win.open; onActivated: win.closeRequested() }

    Rectangle { anchors.fill: parent; color: Theme.bg; opacity: 0.55 * Math.max(0, Math.min(1, spring.value)) }
    MouseArea { anchors.fill: parent; onClicked: win.closeRequested() }

    Rectangle {
        id: card
        width: win.cardWidth
        height: Math.min(win.maxCardHeight, body.childrenRect.height + 32)
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.18 + (1 - spring.value) * 28
        opacity: Math.max(0, Math.min(1, spring.value * 1.6))
        scale: 0.96 + 0.04 * spring.value
        radius: Theme.radius
        color: Theme.panel
        border { width: 1; color: Theme.hairline }

        MouseArea { anchors.fill: parent }            // clicks on the card must not close it
        Item { id: body; x: 16; y: 16; width: parent.width - 32; height: parent.height - 32 }
    }
}
