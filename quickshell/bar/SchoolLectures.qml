import QtQuick
import QtQuick.Layouts
import Quickshell
import "schoolutil.js" as U

// Lecture notes from a synced folder (for example Notability's Auto-Backup, which saves each note as a PDF). New files are
// matched to your Canvas courses by their folder or file name, and open in your PDF viewer or audio player.
Item {
    id: root
    required property var bar
    readonly property var sc: bar.school
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.peach
    property var    roots: []
    property var    files: []
    property var    found: []                      // folders that look like lecture backups, offered when none is set up
    property bool   loaded: false
    property string courseFilter: ""               // "" = all
    property string status: ""
    property bool   statusErr: false

    Job { id: rootsJob; script: Quickshell.shellPath("lectures.sh") }
    Job { id: listJob;  script: Quickshell.shellPath("lectures.sh") }
    Job { id: detJob;   script: Quickshell.shellPath("lectures.sh") }
    Job { id: actJob;   script: Quickshell.shellPath("lectures.sh") }
    function say(msg, err) { status = msg; statusErr = !!err; statusTimer.restart() }
    Timer { id: statusTimer; interval: 4000; onTriggered: root.status = "" }
    function activate() {
        rootsJob.go(["roots"], r => {
            if (!Array.isArray(r)) return
            roots = r; loaded = true
            if (r.length) listJob.go(["list"], l => { if (Array.isArray(l)) files = l })
            else detJob.go(["detect"], d => { if (Array.isArray(d)) found = d })
        })
    }
    function add(path) { actJob.go(["addroot", path], r => { if (r && r.error) say(r.error, true); else activate() }) }
    function drop(path) { actJob.go(["droproot", path], r => activate()) }
    function open(f) { actJob.go(["open", f.path], r => { if (r && r.ok) root.bar.hubOpen = false; else say(r && r.error ? r.error : "could not open", true) }) }

    function norm(s) { return (s || "").toLowerCase().replace(/[^a-z0-9]/g, "") }
    function courseOf(f) {
        var hay = norm(f.rel)
        var c = sc.courses.find(c => norm(c.code).length >= 4 && hay.indexOf(norm(c.code)) >= 0) || sc.courses.find(c => norm(c.name).length >= 5 && hay.indexOf(norm(c.name)) >= 0)
        return c ? c.code : ""
    }
    readonly property var tagged: files.map(f => Object.assign({}, f, { course: courseOf(f) }))
    readonly property var courseList: { var seen = {}, out = []; tagged.forEach(f => { if (f.course && !seen[f.course]) { seen[f.course] = 1; out.push(f.course) } }); return out }
    readonly property var shown: courseFilter === "" ? tagged : tagged.filter(f => f.course === courseFilter)
    readonly property int newThisWeek: tagged.filter(f => f.mtime * 1000 > Date.now() - 7 * 86400000).length
    function icon(ext) { return ext === "pdf" ? "󰈦" : (ext === "m4a" || ext === "mp3" || ext === "wav") ? "󰎆" : (ext === "png" || ext === "jpg" || ext === "jpeg") ? "󰋩" : "󰈙" }

    // ── first time: choose a folder ──
    Flickable {
        visible: root.loaded && root.roots.length === 0
        anchors.fill: parent
        contentHeight: setupCol.implicitHeight + 20; clip: true; boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: setupCol
            x: 0; width: parent.width; spacing: 8
            Text { text: "󰂺  Lecture notes"; color: root.accent; font { family: root.font; pixelSize: 12; bold: true } }
            Rectangle {
                Layout.fillWidth: true; implicitHeight: how.implicitHeight + 20; radius: 12; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                Text {
                    id: how
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                    wrapMode: Text.WordWrap; color: Theme.subtext; font { family: root.font; pixelSize: 10 }
                    text: "Notability keeps your notes on your Apple devices, so this computer can only see them if they are backed up somewhere it can reach.\n\n1. In Notability: Settings → Auto-Backup, choose Dropbox, Google Drive, OneDrive or WebDAV, and set the format to PDF.\n2. Sync that cloud folder to this computer (the provider's app, or rclone) so it shows up as a normal folder.\n3. Put the folder here. New lectures then appear, sorted by course.\n\nPDFs and audio files work. Notability's own .note files can only be opened in Notability, and a lecture's audio recording is not inside its PDF."
                }
            }
            Text { visible: root.found.length > 0; text: "FOUND ON THIS COMPUTER"; color: Theme.dim; font { family: root.font; pixelSize: 9; bold: true; letterSpacing: 1 } }
            Repeater {
                model: root.found
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true; implicitHeight: 44; radius: 10; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
spacing: 8
                        ColumnLayout { Layout.fillWidth: true; spacing: 0
                            Text { text: modelData.path.replace(/^\/home\/[^\/]+/, "~"); color: Theme.text; elide: Text.ElideMiddle; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 11 } }
                            Text { text: modelData.files + " lecture files"; color: Theme.dim; font { family: root.font; pixelSize: 9 } } }
                        Rectangle { Layout.preferredWidth: 70; Layout.preferredHeight: 26; radius: 9; color: root.accent
                                    Text { anchors.centerIn: parent; text: "Use it"; color: Theme.crust; font { family: root.font; pixelSize: 11; bold: true } }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.add(modelData.path) } }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 32; radius: 8; color: Qt.alpha(Theme.mauve, 0.07); border { color: pathIn.activeFocus ? Qt.alpha(root.accent, 0.5) : Theme.sep; width: 1 }
                TextInput { id: pathIn; anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
verticalAlignment: TextInput.AlignVCenter; color: Theme.text; clip: true; font { family: root.font; pixelSize: 11 }
                            onAccepted: { root.add(text.replace(/^~/, "/home/" + Quickshell.env("USER"))); text = "" }
                            Text { visible: pathIn.text.length === 0; anchors.verticalCenter: parent.verticalCenter; text: "or type a folder, like ~/Dropbox/Apps/Notability, and press enter"; color: Theme.dim; font { family: root.font; pixelSize: 10 } } }
            }
            Text { visible: root.status.length > 0; text: root.status; color: root.statusErr ? Theme.red : Theme.green; font { family: root.font; pixelSize: 10 } }
        }
    }

    // ── lectures ──
    ColumnLayout {
        visible: root.roots.length > 0
        anchors.fill: parent; spacing: 8
        Flow {
            Layout.fillWidth: true; spacing: 5
            visible: root.courseList.length > 0
            Repeater {
                model: [""].concat(root.courseList)
                delegate: Rectangle {
                    required property string modelData
                    readonly property bool sel: root.courseFilter === modelData
                    height: 24; width: cl.implicitWidth + 16; radius: 12; color: sel ? Qt.alpha(root.accent, 0.22) : Theme.card; border { color: sel ? root.accent : Theme.cardBorder; width: 1 }
                    Text { id: cl; anchors.centerIn: parent; text: modelData === "" ? "All (" + root.tagged.length + ")" : modelData; color: sel ? Theme.text : Theme.subtext; font { family: root.font; pixelSize: 10 } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.courseFilter = modelData }
                }
            }
        }
        ListView {
            id: list
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: 4; boundsBehavior: Flickable.StopAtBounds
            model: root.shown
            delegate: Rectangle {
                id: lr
                required property var modelData
                width: list.width; height: 46; radius: 10
                color: lh.hovered ? Qt.alpha(root.accent, 0.10) : Theme.card; border { color: Theme.cardBorder; width: 1 }
                HoverHandler { id: lh; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: root.open(lr.modelData) }
                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
spacing: 10
                    Text { text: root.icon(lr.modelData.ext); color: root.accent; font { family: root.font; pixelSize: 17 } }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 0
                        Text { text: lr.modelData.name.replace(/\.[^.]+$/, ""); color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 11; bold: true } }
                        Text { text: (lr.modelData.course ? lr.modelData.course + "  ·  " : "") + lr.modelData.rel.replace(/\/[^\/]*$/, "").replace(/^[^\/]*$/, "") ; color: Theme.dim; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 9 } }
                    }
                    Text { text: U.rel(lr.modelData.mtime * 1000, root.sc.nowMs).replace("in ", ""); color: Theme.dim; font { family: root.font; pixelSize: 9 } }
                }
            }
            Text { visible: list.count === 0; anchors.centerIn: parent; text: "no lecture files yet"; color: Theme.dim; font { family: root.font; pixelSize: 11 } }
        }
        RowLayout {
            Layout.fillWidth: true; spacing: 10
            Text { text: root.newThisWeek + " new this week"; color: Theme.subtext; font { family: root.font; pixelSize: 9 } }
            Text { Layout.fillWidth: true; text: root.roots.map(r => r.replace(/^\/home\/[^\/]+/, "~")).join("  ·  "); color: Theme.dim; elide: Text.ElideMiddle; font { family: root.font; pixelSize: 9 } }
            Text { text: "forget folder"; color: Theme.dim; font { family: root.font; pixelSize: 9 }
                   MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.drop(root.roots[0]) } }
            Text { text: "refresh"; color: root.accent; font { family: root.font; pixelSize: 9 }
                   MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.activate() } }
        }
    }
}
