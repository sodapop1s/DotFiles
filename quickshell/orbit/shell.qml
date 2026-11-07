import Quickshell

ShellRoot {
    Bar { id: bar; store: notifs }
    Notifications { id: notifs; dnd: bar.dndOn }
}
