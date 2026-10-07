import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Clipboard history (text). A background `wl-paste --watch` records everything copied while the
// bar runs. The history itself is kept in memory only, because copied text can contain passwords.
// The one exception is what you pin: pinned items are your snippets, so they are saved to
// ~/.local/state/qs-bar-clipboard.json (readable by you only) and come back after a restart.
Item {
    id: root
    required property var bar
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.yellow
    readonly property int maxItems: 60
    readonly property int maxChars: 20000

    // each item: { t: text, at: ms, pinned: bool }
    property var    items: []
    property string query: ""
    property string status: ""
    property bool   statusErr: false
    property int    tick: 0

    function say(msg, err) { status = msg; statusErr = !!err; statusTimer.restart() }
    Timer { id: statusTimer; interval: 3000; onTriggered: root.status = "" }
    Timer { interval: 30000; repeat: true; running: root.visible; onTriggered: root.tick++ }
    function activate() { tick++; input.forceActiveFocus() }

    // ── Watcher ───────────────────────────────────────────
    Process {
        id: watcher
        command: ["wl-paste", "--type", "text", "--watch", "jq", "-Rsc", "."]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var t = ""
                try { t = JSON.parse(data) } catch(e) { return }
                root.record(t)
            }
        }
        onExited: restartTimer.start()
    }
    Timer { id: restartTimer; interval: 3000; onTriggered: watcher.running = true }

    // ── Pinned snippets, saved on disk ────────────────────
    FileView {
        id: pinStore
        path: Quickshell.env("HOME") + "/.local/state/qs-bar-clipboard.json"
        onLoaded: {
            try {
                var saved = JSON.parse(pinStore.text()).filter(x => x && typeof x.t === "string")
                var have = root.items.map(x => x.t)
                root.items = root.items.concat(saved.filter(x => have.indexOf(x.t) < 0).map(x => ({ t: x.t, at: x.at || 0, pinned: true })))
            } catch(e) {}
        }
    }
    Timer { id: chmodTimer; interval: 400; onTriggered: chmodProc.running = true }
    Process { id: chmodProc; command: ["chmod", "600", Quickshell.env("HOME") + "/.local/state/qs-bar-clipboard.json"] }
    function savePins() {
        pinStore.setText(JSON.stringify(items.filter(x => x.pinned).map(x => ({ t: x.t, at: x.at }))))
        chmodTimer.restart()
    }

    function record(t) {
        if (typeof t !== "string" || t.trim().length === 0 || t.length > maxChars) return
        var list = items.slice()
        var i = list.findIndex(x => x.t === t)
        var pinned = false
        if (i >= 0) { pinned = list[i].pinned; list.splice(i, 1) }
        list.unshift({ t: t, at: Date.now(), pinned: pinned })
        // keep pinned items, trim the oldest unpinned ones
        var unpinned = 0
        list = list.filter(x => x.pinned || (++unpinned <= maxItems))
        items = list
        if (pinned) savePins()      // the text was pinned already: refresh its time
    }

    // ── Actions ───────────────────────────────────────────
    Process { id: copyProc; onExited: running = false }
    function copy(it) {
        if (copyProc.running) return
        copyProc.command = ["bash", "-c", "printf %s \"$1\" | wl-copy", "_", it.t]
        copyProc.running = true
        say("copied", false)
        closeTimer.restart()
    }
    Timer { id: closeTimer; interval: 250; onTriggered: root.bar.hubOpen = false }
    function togglePin(it) {
        items = items.map(x => x === it ? { t: x.t, at: x.at, pinned: !x.pinned } : x)
        savePins()
    }
    function remove(it) { var was = it.pinned; items = items.filter(x => x !== it); if (was) savePins() }
    function clearUnpinned() { items = items.filter(x => x.pinned); say("cleared", false) }

    function ago(ms, _t) {
        var s = Math.max(0, Math.round((Date.now() - ms) / 1000))
        if (s < 45) return "now"
        if (s < 3600) return Math.max(1, Math.round(s / 60)) + "m"
        if (s < 86400) return Math.round(s / 3600) + "h"
        return Math.round(s / 86400) + "d"
    }
    function kindOf(t) {
        var s = t.trim()
        if (/^https?:\/\/\S+$/.test(s)) return "link"
        if (/^#?[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(s)) return "color"
        if (/^(\/|~\/)[^\n]{1,300}$/.test(s)) return "path"
        if (s.indexOf("\n") >= 0) return "multi"
        return "text"
    }
    readonly property var shown: {
        var q = query.trim().toLowerCase()
        var list = q ? items.filter(x => x.t.toLowerCase().indexOf(q) >= 0) : items
        // pinned first, otherwise newest first (already ordered)
        return list.filter(x => x.pinned).concat(list.filter(x => !x.pinned))
    }

    // ── UI ────────────────────────────────────────────────
    AppHeader {
        id: head
        bar: root.bar; icon: "󰅌"; title: "Clipboard"; accent: root.accent
        anchors { top: parent.top; left: parent.left; right: parent.right }
        onBack: root.bar.hubView = "main"
        Text {
            visible: root.status.length > 0
            text: root.status; color: root.statusErr ? Theme.red : Theme.green
            font { family: root.font; pixelSize: 11 }
        }
        Text {
            text: root.items.length + " items"; color: Theme.dim; font { family: root.font; pixelSize: 10 }
        }
        Text {
            text: "clear"; color: Theme.dim; font { family: root.font; pixelSize: 11 }
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.clearUnpinned() }
        }
    }
    Rectangle { id: sep; anchors { top: head.bottom; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 } height: 1; color: Theme.sep }

    Rectangle {
        id: box
        anchors { top: sep.bottom; topMargin: 10; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 }
        height: 34; radius: 10
        color: Qt.alpha(Theme.mauve, 0.07)
        border { color: input.activeFocus ? Qt.alpha(Theme.yellow, 0.45) : Theme.sep; width: 1 }
        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            spacing: 8
            Text { text: "󰍉"; color: input.activeFocus ? root.accent : Theme.dim; font { family: root.font; pixelSize: 14 } }
            TextInput {
                id: input
                Layout.fillWidth: true
                color: Theme.text; clip: true
                font { family: root.font; pixelSize: 12 }
                onTextChanged: root.query = text
                Keys.onEscapePressed: { if (text.length > 0) text = ""; else root.bar.hubOpen = false }
                Keys.onReturnPressed: { if (root.shown.length > 0) root.copy(root.shown[0]) }
                Text { visible: input.text.length === 0; anchors.verticalCenter: parent.verticalCenter
                       text: "search clipboard history"; color: Theme.dim; font { family: root.font; pixelSize: 11 } }
            }
            Text {
                visible: input.text.length > 0; text: "✕"; color: Theme.dim; font { family: root.font; pixelSize: 11 }
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: input.text = "" }
            }
        }
    }

    ListView {
        id: list
        anchors { top: box.bottom; topMargin: 10; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 12 }
        clip: true; spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        model: root.shown

        delegate: Rectangle {
            id: row
            required property var modelData
            readonly property string kind: root.kindOf(modelData.t)
            width: list.width
            height: Math.max(46, rowCol.implicitHeight + 16)
            radius: 10
            color: hh.hovered ? Qt.alpha(Theme.yellow, 0.10) : Theme.card
            border { color: modelData.pinned ? Qt.alpha(Theme.yellow, 0.5) : Theme.cardBorder; width: 1 }

            HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
            MouseArea { anchors.fill: parent; onClicked: root.copy(row.modelData) }

            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 10; topMargin: 8; bottomMargin: 8 }
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 30; Layout.preferredHeight: 30; Layout.alignment: Qt.AlignTop; radius: 8
                    color: row.kind === "color" ? ("#" + row.modelData.t.trim().replace("#", "").slice(0, 6)) : Qt.alpha(Theme.yellow, 0.12)
                    border { color: Theme.cardBorder; width: row.kind === "color" ? 1 : 0 }
                    Text {
                        visible: row.kind !== "color"
                        anchors.centerIn: parent
                        text: row.kind === "link" ? "󰖟" : row.kind === "path" ? "󰉋" : row.kind === "multi" ? "󰈙" : "󰦨"
                        color: root.accent; font { family: root.font; pixelSize: 15 }
                    }
                }
                ColumnLayout {
                    id: rowCol
                    Layout.fillWidth: true; spacing: 2
                    Text {
                        text: row.modelData.t.length > 400 ? row.modelData.t.slice(0, 400) + "…" : row.modelData.t
                        color: Theme.text; Layout.fillWidth: true
                        wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
                        textFormat: Text.PlainText
                        font { family: root.font; pixelSize: 11 }
                    }
                    Text {
                        text: root.ago(row.modelData.at, root.tick) + (row.modelData.t.length > 80 ? "  ·  " + row.modelData.t.length + " chars" : "")
                        color: Theme.dim; font { family: root.font; pixelSize: 9 }
                    }
                }
                ColumnLayout {
                    Layout.alignment: Qt.AlignTop; spacing: 6
                    Text {
                        visible: hh.hovered || row.modelData.pinned
                        text: "󰐃"; color: row.modelData.pinned ? root.accent : Theme.dim; font { family: root.font; pixelSize: 14 }
                        MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.togglePin(row.modelData) }
                    }
                    Text {
                        visible: hh.hovered
                        text: "󰆴"; color: Theme.dim; font { family: root.font; pixelSize: 14 }
                        MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.remove(row.modelData) }
                    }
                }
            }
        }

        Text {
            visible: list.count === 0
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            text: root.items.length === 0 ? "Nothing copied yet.\nHistory starts when the bar starts and is kept in memory only." : "No matches"
            color: Theme.dim; font { family: root.font; pixelSize: 11 }
        }
    }
}
