import QtQuick
import Quickshell
import Quickshell.Io

// orbit: a minimal pill plus on-demand panels. The old hub files stay in this directory until
// they are ported or removed; only the ones named here are loaded.
ShellRoot {
    id: shell
    property bool dndOn: false

    // What the old bar used to provide to the School pages (they take the shell as their `bar`).
    readonly property bool hubOpen: panels.active === "study"
    property alias school: schoolData
    property alias studyFocus: focusState

    SchoolData { id: schoolData; bar: Sys }
    FocusState { id: focusState; bar: shell; school: schoolData }

    // launcher hook: true when focus mode forbids the app (and says so)
    function appBlocked(app) {
        var blocked = focusState.isBlocked({ name: app.name, exec: app.execString })
        if (blocked) schoolData.notify("Focus mode is on", app.name + " is blocked until focus mode ends.")
        return blocked
    }

    IpcHandler {
        target: "dnd"
        function toggle(): void { shell.dndOn = !shell.dndOn }
        function on(): void  { shell.dndOn = true }
        function off(): void { shell.dndOn = false }
    }

    Wallpaper {}
    Pill {}
    Panels { id: panels; store: notifs; host: shell; school: schoolData }
    Notifications { id: notifs; dnd: shell.dndOn }
}
