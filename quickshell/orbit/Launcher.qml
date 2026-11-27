import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// App launcher: type to search installed apps, Enter to start. With nothing typed it shows what
// you launched recently. Apps start through niri, so they are not children of the shell.
ColumnLayout {
    id: root
    width: parent.width
    spacing: 10

    property bool active: false
    signal done()
    // set by the shell: returns true when focus mode forbids this app
    property var blocked: null

    property string query: ""
    property int sel: 0
    property var recents: ({})            // { "App Name": { count, last } }

    readonly property var apps: DesktopEntries.applications.values.filter(a => !a.noDisplay)

    readonly property var results: {
        var q = query.trim().toLowerCase()
        if (q.length === 0) {
            return Object.keys(recents).sort((a, b) => recents[b].last - recents[a].last)
                .map(n => apps.find(a => a.name === n)).filter(a => a).slice(0, 7)
        }
        var tier = a => {
            var n = a.name.toLowerCase()
            if (n.startsWith(q)) return 0
            if (n.includes(" " + q)) return 1
            if (n.includes(q)) return 2
            if ((a.genericName || "").toLowerCase().includes(q) || (a.keywords || []).some(k => k.toLowerCase().includes(q))) return 3
            return 9
        }
        return apps.filter(a => tier(a) < 9).sort((a, b) => {
            var ta = tier(a), tb = tier(b)
            if (ta !== tb) return ta - tb
            var ca = recents[a.name] ? recents[a.name].count : 0, cb = recents[b.name] ? recents[b.name].count : 0
            if (ca !== cb) return cb - ca
            return a.name.localeCompare(b.name)
        }).slice(0, 8)
    }
    onResultsChanged: sel = 0

    onActiveChanged: if (active) { field.text = ""; sel = 0; Qt.callLater(field.focusInput) }

    // qs -c orbit ipc call launcher search <text>   (opens the launcher with that query; handy for scripts and testing)
    IpcHandler {
        target: "launcher"
        function search(q: string): void { field.text = q; root.query = q }
    }

    FileView {
        id: recentStore
        path: Quickshell.env("HOME") + "/.local/state/qs-orbit-recent.json"
        onLoaded: { try { root.recents = JSON.parse(recentStore.text()) } catch (e) {} }
    }
    Process { id: spawner }

    function launch(app) {
        if (!app) return
        if (blocked && blocked(app)) return
        var r = Object.assign({}, recents)
        var cur = r[app.name] || { count: 0, last: 0 }
        r[app.name] = { count: cur.count + 1, last: Date.now() }
        recents = r
        recentStore.setText(JSON.stringify(r))
        var cmd = app.execString.replace(/%[fFuUdDnNickvm]/g, "").trim()
        if (app.runInTerminal) cmd = "ghostty -e " + cmd
        spawner.command = ["niri", "msg", "action", "spawn-sh", "--", cmd]
        spawner.running = true
        done()
    }

    SearchField {
        id: field
        Layout.fillWidth: true
        placeholder: "Search apps"
        onTextChanged: root.query = text
        onDown: root.sel = Math.min(root.results.length - 1, root.sel + 1)
        onUp: root.sel = Math.max(0, root.sel - 1)
        onAccepted: root.launch(root.results[root.sel])
    }

    Repeater {
        model: root.results
        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            radius: 10
            color: index === root.sel ? Theme.raised : "transparent"

            Rectangle {   // selection marker (accent: selection only)
                visible: row.index === root.sel
                x: 0; anchors.verticalCenter: parent.verticalCenter
                width: 3; height: 22; radius: 2; color: Theme.accent
            }
            RowLayout {
                anchors { fill: parent; leftMargin: 14; rightMargin: 12 }
                spacing: 12
                Image {
                    Layout.preferredWidth: 28; Layout.preferredHeight: 28
                    sourceSize: Qt.size(56, 56)
                    source: row.modelData.icon ? (row.modelData.icon.startsWith("/") ? "file://" + row.modelData.icon : Quickshell.iconPath(row.modelData.icon, true)) : ""
                    asynchronous: true
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 0
                    Text { text: row.modelData.name; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: Theme.fontUi; pixelSize: Theme.sizeUi + 1 } }
                    Text { visible: text.length > 0; text: row.modelData.comment || row.modelData.genericName || ""; color: Theme.muted; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: Theme.fontUi; pixelSize: 11 } }
                }
            }
            MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: root.sel = row.index; onClicked: root.launch(row.modelData) }
        }
    }

    Text {
        visible: root.results.length === 0
        Layout.fillWidth: true; Layout.topMargin: 4; Layout.bottomMargin: 6
        text: root.query.trim().length === 0 ? "Type to search. Recently used apps appear here." : "No matching apps."
        color: Theme.muted
        font { family: Theme.fontUi; pixelSize: 12 }
    }
}
