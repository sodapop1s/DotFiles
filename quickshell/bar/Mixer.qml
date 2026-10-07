import QtQuick
import QtQuick.Layouts
import Quickshell

// Audio mixer: output device, per-app volumes and the microphone (see mixer.sh).
Item {
    id: root
    required property var bar
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.teal

    property var    mix: ({ sinks: [], sources: [], apps: [] })
    property string status: ""
    property bool   statusErr: false
    property real   holdUntil: 0        // don't overwrite sliders with stale readings right after a change

    function say(msg, err) { status = msg; statusErr = !!err; statusTimer.restart() }
    Timer { id: statusTimer; interval: 4000; onTriggered: root.status = "" }

    Job { id: listJob; script: Quickshell.shellPath("mixer.sh") }
    Job { id: ctlJob;  script: Quickshell.shellPath("mixer.sh") }

    function refresh() {
        if (Date.now() < holdUntil) return
        listJob.go(["list"], r => {
            if (r && r.error) say(r.error, true)
            else if (r && Date.now() >= root.holdUntil) mix = r
        })
    }
    function activate() { holdUntil = 0; refresh() }
    Timer { interval: 2000; repeat: true; running: root.visible; onTriggered: root.refresh() }

    // optimistic local edit, then tell PipeWire (latest volume per node wins)
    property var pendingVol: ({})
    function patch(id, changes) {
        function upd(arr) { return arr.map(n => n.id === id ? Object.assign({}, n, changes) : n) }
        mix = { sinks: upd(mix.sinks), sources: upd(mix.sources), apps: upd(mix.apps) }
    }
    function setVolume(id, v, commit) {
        v = Math.max(0, Math.min(100, Math.round(v * 100)))
        patch(id, { volume: v })
        holdUntil = Date.now() + 1500
        pendingVol[id] = v
        if (commit) flush()
    }
    function flush() {
        var ids = Object.keys(pendingVol)
        if (ids.length === 0 || ctlJob.running) return
        var id = ids[0], v = pendingVol[id]
        delete pendingVol[id]
        ctlJob.go(["volume", id, String(v)], r => { if (r && r.error) say(r.error, true); flush() })
    }
    Timer { interval: 120; repeat: true; running: root.visible; onTriggered: root.flush() }

    function toggleMute(n) {
        patch(n.id, { muted: !n.muted }); holdUntil = Date.now() + 1500
        ctlJob.go(["mute", String(n.id)], r => { if (r && r.error) say(r.error, true) })
    }
    function makeDefault(n) {
        if (n.default) return
        ctlJob.go(["default", String(n.id)], r => {
            if (r && r.error) say(r.error, true); else say("default: " + n.name, false)
            holdUntil = 0; refresh()
        })
    }
    function appName(a) {
        var m = /\[(.+)\]/.exec(a.name) || /\[(.+)\]/.exec(a.app)
        return m ? m[1] : (a.app || a.name)
    }

    // ── Flat row model for the list ───────────────────────
    readonly property var rows: {
        var out = []
        var ds = mix.sinks.find(n => n.default)
        out.push({ kind: "header", title: "Output" })
        mix.sinks.forEach(n => out.push({ kind: "device", node: n, glyph: "󰓃" }))
        if (ds) out.push({ kind: "volume", node: ds, glyph: "󰕾" })
        if (mix.apps.length) out.push({ kind: "header", title: "Applications" })
        mix.apps.forEach(a => out.push({ kind: "app", node: a }))
        var dm = mix.sources.find(n => n.default)
        out.push({ kind: "header", title: "Input" })
        mix.sources.forEach(n => out.push({ kind: "device", node: n, glyph: "󰍬" }))
        if (dm) out.push({ kind: "volume", node: dm, glyph: "󰍬" })
        return out
    }

    // ── UI ────────────────────────────────────────────────
    AppHeader {
        id: head
        bar: root.bar; icon: "󰋋"; title: "Audio"; accent: root.accent
        anchors { top: parent.top; left: parent.left; right: parent.right }
        onBack: root.bar.hubView = "main"
        Text {
            visible: root.status.length > 0
            text: root.status; color: root.statusErr ? Theme.red : Theme.green
            font { family: root.font; pixelSize: 11 }
        }
        Text {
            text: "open mixer"; color: Theme.dim; font { family: root.font; pixelSize: 11 }
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                        onClicked: { root.bar.hubOpen = false; root.bar.openPavucontrol() } }
        }
    }
    Rectangle { id: sep; anchors { top: head.bottom; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 } height: 1; color: Theme.sep }

    ListView {
        id: list
        anchors { top: sep.bottom; topMargin: 8; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 12 }
        clip: true; spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        model: root.rows

        delegate: Item {
            id: row
            required property var modelData
            readonly property string kind: modelData.kind
            readonly property var node: modelData.node
            width: list.width
            height: kind === "header" ? 28 : (kind === "app" ? 50 : (kind === "volume" ? 38 : 40))

            // header
            Text {
                visible: row.kind === "header"
                anchors { left: parent.left; leftMargin: 4; bottom: parent.bottom; bottomMargin: 4 }
                text: (row.modelData.title || "").toUpperCase(); color: Theme.dim
                font { family: root.font; pixelSize: 10; bold: true; letterSpacing: 1 }
            }

            // device row (click = make default)
            Rectangle {
                visible: row.kind === "device"
                anchors.fill: parent; radius: 10
                color: dh.hovered ? Qt.alpha(Theme.teal, 0.10) : Theme.card
                border { color: row.node && row.node.default ? Qt.alpha(Theme.teal, 0.5) : Theme.cardBorder; width: 1 }
                HoverHandler { id: dh; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: root.makeDefault(row.node) }
                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 10
                    Text { text: row.modelData.glyph || ""; color: (row.node && row.node.default) ? root.accent : Theme.dim
                           font { family: root.font; pixelSize: 16 } }
                    Text { text: row.node ? row.node.name : ""; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true
                           font { family: root.font; pixelSize: 11 } textFormat: Text.PlainText }
                    Text { visible: !!(row.node && row.node.default); text: "default"; color: root.accent; font { family: root.font; pixelSize: 9 } }
                }
            }

            // main volume row
            RowLayout {
                visible: row.kind === "volume"
                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                spacing: 12
                Text {
                    text: row.node && row.node.muted ? (row.modelData.glyph === "󰍬" ? "󰍭" : "󰝟") : (row.modelData.glyph || "")
                    color: row.node && row.node.muted ? Theme.dim : root.accent
                    font { family: root.font; pixelSize: 17 }
                    Layout.preferredWidth: 22
                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleMute(row.node) }
                }
                HSlider {
                    id: mainSl
                    Layout.fillWidth: true
                    value: row.node ? row.node.volume / 100 : 0
                    accent: root.accent; dimmed: row.node ? row.node.muted : false
                    onMoved: v => root.setVolume(row.node.id, v, false)
                    onCommitted: v => root.setVolume(row.node.id, v, true)
                }
                Text { text: (row.node ? row.node.volume : 0) + "%"; color: Theme.subtext; Layout.preferredWidth: 34
                       horizontalAlignment: Text.AlignRight; font { family: root.font; pixelSize: 11 } }
            }

            // application row
            Rectangle {
                visible: row.kind === "app"
                anchors.fill: parent; radius: 10
                color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 10
                    Item {
                        Layout.preferredWidth: 26; Layout.preferredHeight: 26
                        Image {
                            id: appIcon
                            anchors.fill: parent; fillMode: Image.PreserveAspectFit; asynchronous: true; sourceSize: Qt.size(52, 52)
                            source: row.node && row.node.icon ? Quickshell.iconPath(row.node.icon, true) : ""
                            visible: status === Image.Ready
                        }
                        Text { visible: appIcon.status !== Image.Ready; anchors.centerIn: parent; text: "󰎆"; color: root.accent
                               font { family: root.font; pixelSize: 17 } }
                    }
                    ColumnLayout {
                        Layout.preferredWidth: 110; spacing: 0
                        Text { text: row.node ? root.appName(row.node) : ""; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true
                               font { family: root.font; pixelSize: 11; bold: true } textFormat: Text.PlainText }
                        Text { text: row.node ? row.node.media : ""; color: Theme.dim; elide: Text.ElideRight; Layout.fillWidth: true
                               font { family: root.font; pixelSize: 9 } textFormat: Text.PlainText }
                    }
                    HSlider {
                        Layout.fillWidth: true
                        value: row.node ? row.node.volume / 100 : 0
                        accent: root.accent; dimmed: row.node ? row.node.muted : false
                        onMoved: v => root.setVolume(row.node.id, v, false)
                        onCommitted: v => root.setVolume(row.node.id, v, true)
                    }
                    Text { text: (row.node ? row.node.volume : 0) + "%"; color: Theme.subtext; Layout.preferredWidth: 32
                           horizontalAlignment: Text.AlignRight; font { family: root.font; pixelSize: 10 } }
                    Text {
                        text: row.node && row.node.muted ? "󰝟" : "󰕾"; color: row.node && row.node.muted ? Theme.dim : root.accent
                        font { family: root.font; pixelSize: 15 }
                        MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleMute(row.node) }
                    }
                }
            }
        }
    }
}
