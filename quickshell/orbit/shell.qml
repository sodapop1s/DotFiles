import QtQuick
import Quickshell
import Quickshell.Io

// orbit: a minimal pill plus on-demand panels. The old hub files stay in this directory until
// step 5 decides which features get ported; only the ones named here are loaded.
ShellRoot {
    id: shell
    property bool dndOn: false

    IpcHandler {
        target: "dnd"
        function toggle(): void { shell.dndOn = !shell.dndOn }
        function on(): void  { shell.dndOn = true }
        function off(): void { shell.dndOn = false }
    }

    Pill {}
    Panels {}
    Notifications { id: notifs; dnd: shell.dndOn }
}
