import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// The two on-demand panels and the dimming behind them. One is open at a time.
//   qs -c orbit ipc call panel toggle left|right|launcher|clipboard|study|keys      (also: open <name>, close)
Item {
    id: root
    required property var store      // the Notifications window (history)
    required property var host       // the shell root (owns dndOn, school, studyFocus)
    required property var school     // classes and deadlines (SchoolData)
    property string active: ""        // "", "left", "right", "launcher", "clipboard", "study" or "keys"
    readonly property bool sideOpen: active === "left" || active === "right"

    // the calendar helper only reads its cache; sync it on start and every 30 minutes, then reload the classes
    Process {
        id: calSync
        command: ["bash", Quickshell.shellPath("calendar.sh"), "sync"]
        onExited: root.school.refreshEvents()
    }
    Timer { interval: 1800000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!calSync.running) calSync.running = true }

    Binding { target: Sys; property: "statsWanted"; value: root.active === "left" }

    IpcHandler {
        target: "panel"
        function toggle(name: string): void { root.active = root.active === name ? "" : name }
        function open(name: string): void { root.active = name }
        function close(): void { root.active = "" }
    }

    // wallpaper dim; clicking it closes whatever is open
    PanelWindow {
        visible: root.sideOpen || scrimSpring.moving
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusiveZone: -1
        WlrLayershell.layer: WlrLayershell.Top
        WlrLayershell.namespace: "orbit-scrim"
        Spring { id: scrimSpring; target: root.sideOpen ? 1 : 0 }
        Rectangle { anchors.fill: parent; color: Theme.bg; opacity: 0.55 * Math.max(0, Math.min(1, scrimSpring.value)) }
        MouseArea { anchors.fill: parent; onClicked: root.active = "" }
    }

    EdgePanel {
        side: "left"; title: "System"
        open: root.active === "left"
        onCloseRequested: root.active = ""
        SystemPanel { open: root.active === "left" }
    }
    EdgePanel {
        side: "right"; title: "Day"
        open: root.active === "right"
        onCloseRequested: root.active = ""
        DayPanel { school: root.school; store: root.store; host: root.host; open: root.active === "right" }
    }

    Overlay {
        open: root.active === "launcher"
        onCloseRequested: root.active = ""
        Launcher { active: root.active === "launcher"; onDone: root.active = ""; blocked: root.host.appBlocked }
    }
    Overlay {
        open: root.active === "clipboard"
        cardWidth: 720
        onCloseRequested: root.active = ""
        ClipboardPicker { active: root.active === "clipboard"; onDone: root.active = "" }
    }
    Overlay {
        open: root.active === "keys"
        cardWidth: 1120
        maxCardHeight: 760
        onCloseRequested: root.active = ""
        Hotkeys { active: root.active === "keys" }
    }
    Overlay {
        open: root.active === "study"
        cardWidth: 780
        maxCardHeight: 720
        onCloseRequested: root.active = ""
        Study { host: root.host; active: root.active === "study"; onDone: root.active = "" }
    }
}
