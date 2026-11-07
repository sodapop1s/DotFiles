import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// The two on-demand panels and the dimming behind them. One is open at a time.
//   qs -c orbit ipc call panel toggle left|right      (also: open <side>, close)
Item {
    id: root
    property string active: ""        // "", "left" or "right"

    // classes and deadlines for the right panel (calendar + Canvas helpers)
    SchoolData { id: sd; bar: Sys }

    // the calendar helper only reads its cache; sync it on start and every 30 minutes, then reload the classes
    Process {
        id: calSync
        command: ["bash", Quickshell.shellPath("calendar.sh"), "sync"]
        onExited: sd.refreshEvents()
    }
    Timer { interval: 1800000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!calSync.running) calSync.running = true }

    Binding { target: Sys; property: "statsWanted"; value: root.active === "left" }

    IpcHandler {
        target: "panel"
        function toggle(side: string): void { root.active = root.active === side ? "" : side }
        function open(side: string): void { root.active = side }
        function close(): void { root.active = "" }
    }

    // wallpaper dim; clicking it closes whatever is open
    PanelWindow {
        visible: root.active !== "" || scrimSpring.moving
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusiveZone: -1
        WlrLayershell.layer: WlrLayershell.Top
        WlrLayershell.namespace: "orbit-scrim"
        Spring { id: scrimSpring; target: root.active !== "" ? 1 : 0 }
        Rectangle { anchors.fill: parent; color: Theme.bg; opacity: 0.55 * Math.max(0, Math.min(1, scrimSpring.value)) }
        MouseArea { anchors.fill: parent; onClicked: root.active = "" }
    }

    EdgePanel {
        side: "left"; title: "System"
        open: root.active === "left"
        onCloseRequested: root.active = ""
        SystemPanel {}
    }
    EdgePanel {
        side: "right"; title: "Day"
        open: root.active === "right"
        onCloseRequested: root.active = ""
        DayPanel { school: sd }
    }
}
