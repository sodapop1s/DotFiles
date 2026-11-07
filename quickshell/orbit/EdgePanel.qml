import QtQuick
import Quickshell
import Quickshell.Wayland

// A panel that slides in from the left or right screen edge on the shared spring.
// Its window is unmapped while closed. Put the contents inside it; Escape asks to close.
PanelWindow {
    id: win

    required property string side          // "left" | "right"
    property bool open: false
    property string title: ""
    signal closeRequested()
    default property alias content: body.data

    readonly property real panelWidth: 380
    readonly property real travel: panelWidth + 24

    anchors { top: true; bottom: true; left: side === "left"; right: side === "right" }
    margins { top: 12; bottom: 12; left: 12; right: 12 }
    implicitWidth: panelWidth
    visible: open || spring.moving
    color: "transparent"
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.namespace: "orbit-panel-" + side
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Spring { id: spring; target: win.open ? 1 : 0 }

    Shortcut { sequence: "Escape"; enabled: win.open; onActivated: win.closeRequested() }

    Rectangle {
        id: card
        width: parent.width; height: parent.height
        x: (side === "left" ? -1 : 1) * (1 - spring.value) * win.travel
        radius: Theme.radius
        color: Theme.panel
        border { width: 1; color: Theme.hairline }

        Text {
            id: heading
            x: 20; y: 18
            text: win.title
            color: Theme.text
            font { family: Theme.fontUi; pixelSize: 18; weight: Font.DemiBold }
        }
        Item { id: body; anchors { top: heading.bottom; topMargin: 14; left: parent.left; right: parent.right; bottom: parent.bottom; margins: 20 } }
    }
}
