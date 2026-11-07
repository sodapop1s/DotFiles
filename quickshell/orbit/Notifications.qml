import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications

PanelWindow {
    id: notifWin

    anchors { top: true; right: true }
    margins { top: 14; right: 14 }
    implicitWidth: 380
    implicitHeight: Math.max(1, stack.implicitHeight + 8)
    color: "transparent"
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // only the cards take input; the rest of the window is click-through
    mask: Region { item: stack }

    property var notifs: []
    // Do Not Disturb: set from the bar; critical notifications still get through
    property bool dnd: false

    // ── History (persisted) ───────────────────────────────
    // plain objects, not Notification handles: those die with the popup
    property var history: []
    property int unread: 0
    readonly property int maxHistory: 100

    FileView {
        id: store
        path: Quickshell.env("HOME") + "/.local/state/qs-orbit-notifs.json"
        onLoaded: {
            try {
                var d = JSON.parse(store.text())
                notifWin.history = d.history || []
                notifWin.unread  = d.unread  || 0
            } catch(e) {}
        }
    }

    function saveHistory() {
        store.setText(JSON.stringify({ history: notifWin.history, unread: notifWin.unread }))
    }
    function pushHistory(n, suppressed) {
        var item = {
            appName:    n.appName || "",
            appIcon:    n.appIcon || "",
            summary:    n.summary || "",
            body:       n.body || "",
            urgency:    n.urgency,
            time:       Date.now(),
            suppressed: suppressed
        }
        notifWin.history = [item].concat(notifWin.history).slice(0, notifWin.maxHistory)
        notifWin.unread += 1
        saveHistory()
    }
    function markRead()       { if (notifWin.unread !== 0) { notifWin.unread = 0; saveHistory() } }
    function clearHistory()   { notifWin.history = []; notifWin.unread = 0; saveHistory() }
    function removeHistory(i) { var h = notifWin.history.slice(); h.splice(i, 1); notifWin.history = h; saveHistory() }
    readonly property int maxVisible: 5

    function removeNotif(notif) {
        if (!notif) return
        var nid = notif.id
        var fn = notifWin.notifs.filter(n => n && n.id !== nid)
        if (fn.length === notifWin.notifs.length) return
        notifWin.notifs = fn
        try { notif.dismiss() } catch(e) {}
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        onNotification: notif => {
            notif.tracked = true
            // the School tab's own reminders ("Study") still show under Do Not Disturb
            var muted = notifWin.dnd && notif.urgency !== NotificationUrgency.Critical && notif.appName !== "Study"
            notifWin.pushHistory(notif, muted)
            if (muted) {
                try { notif.dismiss() } catch(e) {}
                return
            }
            // a sender can close its notification itself; that leaves a dead entry here, so drop those first
            var list = notifWin.notifs.filter(n => n).concat([notif])
            // drop the oldest if the stack gets too tall
            while (list.length > notifWin.maxVisible) {
                var old = list.shift()
                try { old.dismiss() } catch(e) {}
            }
            notifWin.notifs = list
        }
    }

    IpcHandler {
        target: "notif"
        function dismiss(): void {
            if (notifWin.notifs.length > 0) notifWin.removeNotif(notifWin.notifs[notifWin.notifs.length - 1])
        }
        function clearHistory(): void { notifWin.clearHistory() }
        // qs -c orbit ipc call notif forget <app>   drops that sender's entries from the history
        function forget(app: string): void {
            notifWin.history = notifWin.history.filter(h => h.appName !== app)
            notifWin.unread = Math.min(notifWin.unread, notifWin.history.length)
            notifWin.saveHistory()
        }
        function dismissAll(): void {
            notifWin.notifs.slice().forEach(n => notifWin.removeNotif(n))
        }
    }

    ColumnLayout {
        id: stack
        anchors { top: parent.top; right: parent.right; topMargin: 0 }
        width: 360
        spacing: 8

        Repeater {
            // newest on top. The model is just the ids: handing Qt a list that holds notification objects crashed Quickshell
            // (SIGSEGV) when a sender closed its own notification and another one arrived.
            model: notifWin.notifs.filter(n => n).reverse().map(n => n.id)

            delegate: Rectangle {
                id: card
                required property var modelData
                readonly property var  n: notifWin.notifs.find(x => x && x.id === modelData) ?? null
                readonly property bool critical: n?.urgency === NotificationUrgency.Critical
                readonly property bool low:      n?.urgency === NotificationUrgency.Low
                // colour is for state only: red when critical, muted when low, neutral otherwise
                readonly property color tone: critical ? Theme.crit : (low ? Theme.muted : Theme.text)

                // 0 → never auto-dismiss
                readonly property int totalMs: critical ? 0 : (n && n.expireTimeout > 0 ? n.expireTimeout : (low ? 4000 : 6000))
                property real leftMs: totalMs
                readonly property bool hovered: hoverArea.containsMouse || closeArea.containsMouse

                Layout.fillWidth: true
                implicitHeight: body.implicitHeight + 28
                radius: Theme.radius
                color: Theme.panel
                border { width: 1; color: critical ? Theme.crit : Theme.hairline }
                clip: true

                // slides in on the shared spring
                Spring { id: enter; target: 0 }
                Component.onCompleted: enter.target = 1
                opacity: Math.max(0, Math.min(1, enter.value * 1.6))
                transform: Translate { x: (1 - enter.value) * 48 }

                // auto-dismiss countdown; pauses while hovered
                Timer {
                    interval: 50; repeat: true
                    running: card.totalMs > 0 && !card.hovered
                    onTriggered: {
                        card.leftMs -= 50
                        if (card.leftMs <= 0) notifWin.removeNotif(card.n)
                    }
                }

                // click anywhere to dismiss (actions/close sit on top)
                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: notifWin.removeNotif(card.n)
                }

                ColumnLayout {
                    id: body
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        // the app's icon or image; a letter when it has none
                        Rectangle {
                            Layout.alignment: Qt.AlignTop
                            width: 40; height: 40; radius: 10
                            color: Theme.raised
                            border { width: 1; color: Theme.hairline }

                            Image {
                                id: img
                                anchors.centerIn: parent
                                width: 28; height: 28
                                sourceSize: Qt.size(56, 56)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                visible: status === Image.Ready
                                source: {
                                    var im = card.n?.image ?? ""
                                    if (im.length > 0) return im
                                    var ic = card.n?.appIcon ?? ""
                                    if (ic.length === 0) return ""
                                    if (ic.startsWith("/")) return "file://" + ic
                                    if (ic.startsWith("file:") || ic.startsWith("image:") || ic.startsWith("http")) return ic
                                    return Quickshell.iconPath(ic, true)
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: img.status !== Image.Ready
                                text: ((card.n?.appName?.length ?? 0) > 0 ? card.n.appName : "N").charAt(0).toUpperCase()
                                color: card.tone
                                font { family: Theme.fontUi; pixelSize: 18; weight: Font.DemiBold }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Text {
                                    text: (card.n?.appName?.length ?? 0) > 0 ? card.n.appName : "Notification"
                                    color: card.critical ? Theme.crit : Theme.muted
                                    font { family: Theme.fontUi; pixelSize: 11; capitalization: Font.AllUppercase; letterSpacing: 1 }
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                }
                                Text {
                                    text: "×"
                                    color: closeArea.containsMouse ? Theme.text : Theme.muted
                                    font { family: Theme.fontUi; pixelSize: 16 }
                                    MouseArea {
                                        id: closeArea
                                        anchors.fill: parent; anchors.margins: -6
                                        hoverEnabled: true
                                        onClicked: notifWin.removeNotif(card.n)
                                    }
                                }
                            }

                            Text {
                                visible: (card.n?.summary?.length ?? 0) > 0
                                text: card.n?.summary ?? ""
                                color: Theme.text
                                font { family: Theme.fontUi; pixelSize: Theme.sizeUi + 1; weight: Font.DemiBold }
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                                textFormat: Text.PlainText
                            }
                            Text {
                                visible: (card.n?.body?.length ?? 0) > 0
                                text: card.n?.body ?? ""
                                color: Theme.muted
                                font { family: Theme.fontUi; pixelSize: 12 }
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap; maximumLineCount: 4; elide: Text.ElideRight
                                textFormat: Text.StyledText
                            }
                        }
                    }

                    // action buttons
                    Flow {
                        visible: (card.n?.actions?.length ?? 0) > 0
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: card.n?.actions ?? []
                            delegate: Chip {
                                required property var modelData
                                implicitHeight: 28
                                text: modelData.text
                                onClicked: { modelData.invoke(); notifWin.removeNotif(card.n) }
                            }
                        }
                    }
                }

                // thin countdown bar along the bottom
                Rectangle {
                    visible: card.totalMs > 0
                    anchors { left: parent.left; bottom: parent.bottom }
                    height: 2
                    width: parent.width * Math.max(0, card.leftMs / card.totalMs)
                    color: Theme.muted
                    opacity: card.hovered ? 0.3 : 0.7
                }
            }
        }
    }
}
