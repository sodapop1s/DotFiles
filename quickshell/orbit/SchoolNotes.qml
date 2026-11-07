import QtQuick
import QtQuick.Layouts
import Quickshell
import "schoolutil.js" as U

// School > Notes: quick capture into your Obsidian vault's Inbox.md, search, and recent notes.
Item {
    id: root
    required property var bar
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.mauve
    property string vaultName: ""
    property bool   vaultOk: true
    property var    recent: []
    property var    found: []
    property string status: ""
    property bool   statusErr: false
    property string searched: ""
    property string pane: "notes"                 // notes (Obsidian) | lectures (synced lecture folders)

    Job { id: vaultJob; script: Quickshell.shellPath("notes.sh") }
    Job { id: recentJob; script: Quickshell.shellPath("notes.sh") }
    Job { id: searchJob; script: Quickshell.shellPath("notes.sh") }
    Job { id: capJob; script: Quickshell.shellPath("notes.sh") }
    Job { id: openJob; script: Quickshell.shellPath("notes.sh") }

    function say(msg, err) { status = msg; statusErr = !!err; statusTimer.restart() }
    Timer { id: statusTimer; interval: 3500; onTriggered: root.status = "" }
    function activate() {
        lectures.activate()
        vaultJob.go(["vault"], r => { if (r) { vaultOk = r.exists; vaultName = r.name } })
        recentJob.go(["recent", "10"], r => { if (Array.isArray(r)) recent = r })
    }
    function focusCapture() { pane = "notes"; capIn.forceActiveFocus() }
    function capture() {
        var t = capIn.text.trim()
        if (!t) return
        capJob.go(["capture", t], r => {
            if (r && r.ok) { say("added to Inbox.md", false); capIn.text = ""; activate() }
            else say(r && r.error ? r.error : "could not save", true)
        })
    }
    Timer { id: searchTimer; interval: 350; onTriggered: root.runSearch() }
    function runSearch() {
        var q = searchIn.text.trim()
        if (q.length < 2) { found = []; searched = ""; return }
        if (!searchJob.go(["search", q], r => { if (Array.isArray(r)) { found = r; searched = q } })) searchTimer.restart()
    }
    function openNote(rel) { openJob.go(["open", rel], r => { if (r && r.ok) root.bar.hubOpen = false; else say(r && r.error ? r.error : "could not open", true) }) }

    Row {
        id: panes
        anchors { top: parent.top; topMargin: 8; left: parent.left; leftMargin: 14 }
        spacing: 6
        Repeater {
            model: [["notes", "󰎞  Obsidian"], ["lectures", "󰂺  Lectures"]]
            delegate: Rectangle {
                required property var modelData
                readonly property bool sel: root.pane === modelData[0]
                height: 26; width: pl.implicitWidth + 20; radius: 13; color: sel ? Qt.alpha(root.accent, 0.22) : Theme.card; border { color: sel ? root.accent : Theme.cardBorder; width: 1 }
                Text { id: pl; anchors.centerIn: parent; text: modelData[1]; color: sel ? Theme.text : Theme.subtext; font { family: root.font; pixelSize: 10 } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.pane = modelData[0] }
            }
        }
    }
    SchoolLectures {
        id: lectures
        bar: root.bar
        visible: root.pane === "lectures"
        anchors { top: panes.bottom; topMargin: 8; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 10 }
    }

    ColumnLayout {
        visible: root.pane === "notes"
        anchors { top: panes.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; topMargin: 2; bottomMargin: 10 }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Text { text: "󰎞  " + (root.vaultName || "Obsidian"); color: root.accent; font { family: root.font; pixelSize: 12; bold: true } }
            Item { Layout.fillWidth: true }
            Text { visible: root.status.length > 0; text: root.status; color: root.statusErr ? Theme.red : Theme.green; font { family: root.font; pixelSize: 10 } }
        }
        Text { visible: !root.vaultOk; Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.yellow; font { family: root.font; pixelSize: 11 }
               text: "No Obsidian vault found. Open Obsidian once and choose a vault, then come back." }

        // quick capture
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 44; radius: 12
            color: Qt.alpha(root.accent, 0.08); border { color: capIn.activeFocus ? Qt.alpha(root.accent, 0.6) : Qt.alpha(root.accent, 0.3); width: 1 }
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
spacing: 8
                Text { text: "󰐕"; color: root.accent; font { family: root.font; pixelSize: 16 } }
                TextInput {
                    id: capIn
                    Layout.fillWidth: true; color: Theme.text; clip: true; font { family: root.font; pixelSize: 12 }
                    onAccepted: root.capture()
                    Keys.onEscapePressed: root.bar.hubOpen = false
                    Text { visible: capIn.text.length === 0; anchors.verticalCenter: parent.verticalCenter; color: Theme.dim; font { family: root.font; pixelSize: 11 }
                           text: "quick capture → Inbox.md   (start with “todo ” for a checkbox)" }
                }
                Text { text: "↵"; color: Theme.dim; font { family: root.font; pixelSize: 12 } }
            }
        }

        // search
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 34; radius: 10; color: Qt.alpha(Theme.mauve, 0.07); border { color: searchIn.activeFocus ? Qt.alpha(root.accent, 0.5) : Theme.sep; width: 1 }
            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
spacing: 8
                Text { text: "󰍉"; color: Theme.dim; font { family: root.font; pixelSize: 14 } }
                TextInput {
                    id: searchIn
                    Layout.fillWidth: true; color: Theme.text; clip: true; font { family: root.font; pixelSize: 12 }
                    onTextChanged: searchTimer.restart()
                    Text { visible: searchIn.text.length === 0; anchors.verticalCenter: parent.verticalCenter; color: Theme.dim; font { family: root.font; pixelSize: 11 }
text: "search your notes" }
                }
            }
        }

        Text { text: root.searched.length ? "RESULTS" : "RECENT"; color: Theme.dim; font { family: root.font; pixelSize: 9; bold: true; letterSpacing: 1 } }
        ListView {
            id: list
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: 4; boundsBehavior: Flickable.StopAtBounds
            model: root.searched.length ? root.found : root.recent
            delegate: Rectangle {
                id: nr
                required property var modelData
                width: list.width; height: nr.modelData.snippet ? 50 : 40; radius: 10
                color: nh.hovered ? Qt.alpha(root.accent, 0.10) : Theme.card; border { color: Theme.cardBorder; width: 1 }
                HoverHandler { id: nh; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: root.openNote(nr.modelData.rel) }
                ColumnLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
spacing: 0
                    Item { Layout.fillHeight: true }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: nr.modelData.title; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 12; bold: true } }
                        Text { visible: nr.modelData.mtime !== undefined; text: nr.modelData.mtime ? U.rel(nr.modelData.mtime * 1000, Date.now()).replace("in ", "") : ""; color: Theme.dim; font { family: root.font; pixelSize: 9 } }
                    }
                    Text { text: nr.modelData.snippet ? nr.modelData.snippet : ""; visible: !!nr.modelData.snippet; color: Theme.dim; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 10 } }
                    Text { visible: !nr.modelData.snippet && nr.modelData.rel.indexOf("/") >= 0; text: nr.modelData.rel.replace(/\/[^\/]*$/, ""); color: Theme.dim; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 9 } }
                    Item { Layout.fillHeight: true }
                }
            }
            Text { visible: list.count === 0; anchors.centerIn: parent; color: Theme.dim; font { family: root.font; pixelSize: 11 }
text: root.searched.length ? "no notes match" : "nothing yet" }
        }
    }
}
