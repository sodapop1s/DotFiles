import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications

PanelWindow {
    id: notifWin

    anchors { top: true; right: true }
    implicitWidth: 380
    implicitHeight: 42 + island.height
    color: "transparent"
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property color cIslandBg:     Qt.rgba(49/255,  50/255,  68/255,  0.92)
    readonly property color cIslandBorder: Qt.rgba(203/255, 166/255, 247/255, 0.15)
    readonly property color cText:    "#b4befe"
    readonly property color cMauve:   "#cba6f7"
    readonly property color cRed:     "#f38ba8"
    readonly property color cDim:     "#6c7086"
    readonly property color cSubtext: "#a6adc8"

    // QObject array — Repeater model; content reads modelData directly
    property var notifs: []
    // Timing: {notif: QObject, expiresAt: int}  (expiresAt=0 → no auto-dismiss)
    property var notifItems: []

    function removeNotif(notif) {
        if (!notif) return
        var nid = notif.id
        var fn = notifWin.notifs.filter(n => n && n.id !== nid)
        if (fn.length === notifWin.notifs.length) return
        notifWin.notifs = fn
        notifWin.notifItems = notifWin.notifItems.filter(x => x.notif && x.notif.id !== nid)
        notif.dismiss()
    }

    // Always-running poll; snapshot expired items before calling removeNotif
    // so array mutation mid-loop is not an issue
    Timer {
        interval: 250
        repeat: true
        running: true
        onTriggered: {
            var now = new Date().getTime()
            var expired = notifWin.notifItems.filter(x => x.expiresAt > 0 && now >= x.expiresAt)
            expired.forEach(x => { if (x.notif) notifWin.removeNotif(x.notif) })
        }
    }

    NotificationServer {
        id: server
        keepOnReload: true
        onNotification: notif => {
            var ms = notif.urgency === NotificationUrgency.Critical ? 0
                   : notif.expireTimeout > 0                        ? notif.expireTimeout
                   :                                                   5000
            notifWin.notifs     = notifWin.notifs.concat([notif])
            notifWin.notifItems = notifWin.notifItems.concat([{
                notif:     notif,
                expiresAt: ms > 0 ? new Date().getTime() + ms : 0
            }])
        }
    }

    IpcHandler {
        target: "notif"
        function dismiss(): void {
            if (notifWin.notifs.length > 0) notifWin.removeNotif(notifWin.notifs[0])
        }
        function dismissAll(): void {
            notifWin.notifs.slice().forEach(n => notifWin.removeNotif(n))
        }
    }

    Rectangle {
        id: island
        // topMargin 37: 1px overlap with bar right island (ends at y=38) so
        // the flat top connects seamlessly with no visible gap
        anchors { top: parent.top; right: parent.right; topMargin: 37; rightMargin: 8 }
        width: 364
        color: notifWin.cIslandBg
        border { color: notifWin.cIslandBorder; width: 1 }
        clip: true

        // Flat top, rounded bottom — looks like bar island extending downward
        radius: 10
        topLeftRadius: 0
        topRightRadius: 0

        height: notifWin.notifs.length > 0 ? content.height + 28 : 0
        Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        Column {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors { leftMargin: 14; rightMargin: 14; topMargin: 14 }
            spacing: 12

            Repeater {
                model: notifWin.notifs

                delegate: Item {
                    id: delRoot
                    width: content.width
                    height: innerCol.implicitHeight

                    property double totalTimeout: {
                        if (!modelData) return 0
                        if (modelData.urgency === NotificationUrgency.Critical) return 0
                        if (modelData.expireTimeout > 0) return modelData.expireTimeout
                        return 5000
                    }

                    ColumnLayout {
                        id: innerCol
                        anchors { left: parent.left; right: parent.right }
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                width: 3; radius: 1
                                Layout.fillHeight: true
                                color: !modelData                                           ? notifWin.cDim
                                     : modelData.urgency === NotificationUrgency.Critical   ? notifWin.cRed
                                     : modelData.urgency === NotificationUrgency.Low        ? notifWin.cDim
                                     :                                                         notifWin.cMauve
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: (modelData?.appName?.length ?? 0) > 0 ? modelData.appName : "Notification"
                                    color: notifWin.cDim
                                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                }
                                Text {
                                    visible: (modelData?.summary?.length ?? 0) > 0
                                    text: modelData?.summary ?? ""
                                    color: notifWin.cText
                                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 13; bold: true }
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                }
                                Text {
                                    visible: (modelData?.body?.length ?? 0) > 0
                                    text: modelData?.body ?? ""
                                    color: notifWin.cSubtext
                                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 2; radius: 1
                            color: notifWin.cIslandBorder
                            visible: delRoot.totalTimeout > 0

                            Rectangle {
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                width: parent.width
                                color: (modelData?.urgency === NotificationUrgency.Critical) ? notifWin.cRed : notifWin.cMauve
                                radius: 1; opacity: 0.6

                                NumberAnimation on width {
                                    running: delRoot.totalTimeout > 0
                                    from: parent.parent.width; to: 0
                                    duration: delRoot.totalTimeout
                                }
                            }
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (notifWin.notifs.length > 0)
                    notifWin.removeNotif(notifWin.notifs[0])
            }
        }
    }
}
