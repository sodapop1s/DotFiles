import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Windows: every open window grouped by workspace. Click one to jump to it, ✕ to close it. (niri)
Item {
    id: root
    required property var bar
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.sky
    property var windows: []
    property var workspaces: []
    property string status: ""
    property bool   statusErr: false

    Job { id: listJob; script: Quickshell.shellPath("windows.sh") }
    Job { id: actJob;  script: Quickshell.shellPath("windows.sh") }
    function say(msg, err) { status = msg; statusErr = !!err; statusTimer.restart() }
    Timer { id: statusTimer; interval: 3000; onTriggered: root.status = "" }
    function activate() { refresh() }
    function refresh() { listJob.go(["list"], r => { if (r && r.windows) { windows = r.windows; workspaces = r.workspaces } }) }
    Timer { interval: 1500; repeat: true; running: root.visible; onTriggered: root.refresh() }
    function focusWin(w) { actJob.go(["focus", String(w.id)], r => { if (r && r.ok) root.bar.hubOpen = false; else say(r && r.error ? r.error : "could not focus", true) }) }
    function closeWin(w) { actJob.go(["close", String(w.id)], r => { if (r && r.error) say(r.error, true); refresh() }) }

    // flat list: a header for each workspace, then its windows
    readonly property var rows: {
        var out = []
        workspaces.forEach(ws => {
            var inWs = windows.filter(w => w.workspace === ws.id)
            if (inWs.length === 0) return
            out.push({ t: "head", text: "WORKSPACE " + ws.idx + (ws.name ? "  ·  " + ws.name : ""), focused: ws.focused })
            inWs.forEach(w => out.push({ t: "win", w: w }))
        })
        return out
    }

    AppHeader {
        id: head
        bar: root.bar; icon: "󰖯"; title: "Windows"; accent: root.accent
        anchors { top: parent.top; left: parent.left; right: parent.right }
        onBack: root.bar.hubView = "main"
        Text { visible: root.status.length > 0; text: root.status; color: root.statusErr ? Theme.red : Theme.green; font { family: root.font; pixelSize: 11 } }
        Text { text: root.windows.length + " open"; color: Theme.dim; font { family: root.font; pixelSize: 10 } }
    }
    Rectangle { id: sep; anchors { top: head.bottom; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 } height: 1; color: Theme.sep }

    ListView {
        id: list
        anchors { top: sep.bottom; topMargin: 8; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 10 }
        clip: true; spacing: 4; boundsBehavior: Flickable.StopAtBounds
        model: root.rows
        delegate: Loader {
            id: ld
            required property var modelData
            width: list.width
            sourceComponent: modelData.t === "head" ? headC : winC
            Component {
                id: headC
                Text { width: list.width; topPadding: 6; text: ld.modelData.text; color: ld.modelData.focused ? root.accent : Theme.dim; font { family: root.font; pixelSize: 9; bold: true; letterSpacing: 1 } }
            }
            Component {
                id: winC
                Rectangle {
                    id: wr
                    readonly property var w: ld.modelData.w
                    width: list.width; height: 44; radius: 10
                    color: wh.hovered ? Qt.alpha(root.accent, 0.10) : Theme.card
                    border { color: wr.w.focused ? Qt.alpha(root.accent, 0.6) : (wr.w.urgent ? Theme.red : Theme.cardBorder); width: 1 }
                    HoverHandler { id: wh; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; onClicked: root.focusWin(wr.w) }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
spacing: 10
                        Item {
                            Layout.preferredWidth: 24; Layout.preferredHeight: 24
                            Image { id: ic; anchors.fill: parent; sourceSize: Qt.size(48, 48); fillMode: Image.PreserveAspectFit; asynchronous: true
                                    source: root.bar.iconSrc(wr.w.app) ; visible: status === Image.Ready }
                            Text { visible: ic.status !== Image.Ready; anchors.centerIn: parent; text: "󰖯"; color: Theme.dim; font { family: root.font; pixelSize: 16 } }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            Text { text: wr.w.title || wr.w.app; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 11; bold: wr.w.focused } }
                            Text { text: wr.w.app + (wr.w.floating ? "  ·  floating" : ""); color: Theme.dim; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 9 } }
                        }
                        Text { visible: wr.w.focused; text: "●"; color: root.accent; font { family: root.font; pixelSize: 10 } }
                        Text { text: "✕"; color: Theme.dim; font { family: root.font; pixelSize: 12 }
                               MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.closeWin(wr.w) } }
                    }
                }
            }
        }
        Text { visible: root.rows.length === 0; anchors.centerIn: parent; text: "no windows"; color: Theme.dim; font { family: root.font; pixelSize: 12 } }
    }
}
