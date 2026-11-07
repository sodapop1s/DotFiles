import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Clipboard history picker. History is recorded by `wl-paste --watch cliphist store` (started by niri);
// this only lists it, copies a chosen entry back and deletes entries. Enter copies, Shift+Delete removes.
ColumnLayout {
    id: root
    width: parent.width
    spacing: 10

    property bool active: false
    signal done()

    property string query: ""
    property int sel: 0
    property var entries: []              // [{ id, text }], newest first
    property string status: ""

    readonly property var shown: {
        var q = query.trim().toLowerCase()
        return (q.length ? entries.filter(e => e.text.toLowerCase().includes(q)) : entries).slice(0, 9)
    }
    onShownChanged: sel = Math.min(sel, Math.max(0, shown.length - 1))
    onQueryChanged: sel = 0

    function reload() { if (!listProc.running) listProc.running = true }
    onActiveChanged: if (active) { field.text = ""; sel = 0; status = ""; reload(); Qt.callLater(field.focusInput) }

    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = text.split("\n").filter(l => l.length).map(l => {
                    var i = l.indexOf("\t")
                    return { id: l.slice(0, i), text: l.slice(i + 1) }
                })
            }
        }
        onExited: (code) => { if (code !== 0) root.status = "cliphist is not available" }
    }
    Process { id: copier; onExited: root.done() }
    Process { id: deleter; onExited: root.reload() }

    function copy(e) {
        if (!e) return
        copier.command = ["sh", "-c", "cliphist decode " + e.id + " | wl-copy"]
        copier.running = true
    }
    function remove(e) {
        if (!e) return
        deleter.command = ["sh", "-c", "printf '%s\\t%s\\n' " + e.id + " x | cliphist delete"]
        deleter.running = true
    }

    SearchField {
        id: field
        Layout.fillWidth: true
        placeholder: "Search clipboard history"
        onTextChanged: root.query = text
        onDown: root.sel = Math.min(root.shown.length - 1, root.sel + 1)
        onUp: root.sel = Math.max(0, root.sel - 1)
        onAccepted: root.copy(root.shown[root.sel])
        onDeleteRequested: root.remove(root.shown[root.sel])
    }

    Repeater {
        model: root.shown
        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            radius: 8
            color: index === root.sel ? Theme.raised : "transparent"
            Rectangle {
                visible: row.index === root.sel
                x: 0; anchors.verticalCenter: parent.verticalCenter
                width: 3; height: 18; radius: 2; color: Theme.accent
            }
            Text {
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 12 }
                text: row.modelData.text
                color: Theme.text
                elide: Text.ElideRight
                textFormat: Text.PlainText
                font { family: Theme.fontMono; pixelSize: 12 }
            }
            MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: root.sel = row.index; onClicked: root.copy(row.modelData) }
        }
    }

    Text {
        visible: root.shown.length === 0
        Layout.fillWidth: true; Layout.bottomMargin: 6
        text: root.status.length ? root.status : (root.query.length ? "Nothing matches." : "Nothing copied yet.")
        color: Theme.muted
        font { family: Theme.fontUi; pixelSize: 12 }
    }
    Text {
        visible: root.shown.length > 0
        Layout.fillWidth: true
        text: "Enter copies  ·  Shift+Delete removes"
        color: Theme.muted
        font { family: Theme.fontUi; pixelSize: 11 }
    }
}
