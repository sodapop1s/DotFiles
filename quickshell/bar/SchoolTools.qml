import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// School > Tools: MATLAB project folders, plus shortcuts to Obsidian, Canvas and each course.
Flickable {
    id: root
    required property var bar
    readonly property var sc: bar.school
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.peach
    contentHeight: col.implicitHeight + 24
    clip: true; boundsBehavior: Flickable.StopAtBounds

    property var    folders: []
    property bool   hasMatlab: true
    property string status: ""
    property bool   statusErr: false
    property var backups: []
    Job { id: backupJob; script: Quickshell.shellPath("backup.sh") }
    Job { id: foldersJob; script: Quickshell.shellPath("tools.sh") }
    Job { id: runJob; script: Quickshell.shellPath("tools.sh") }
    Process { id: openProc; onExited: running = false }
    function say(msg, err) { status = msg; statusErr = !!err; statusTimer.restart() }
    Timer { id: statusTimer; interval: 4000; onTriggered: root.status = "" }
    function activate() {
        foldersJob.go(["matlab-folders"], r => { if (Array.isArray(r)) folders = r })
        backupJob.go(["status"], r => { if (Array.isArray(r)) backups = r })
    }
    function matlab(path) {
        say("starting MATLAB… (it takes a while)", false)
        runJob.go(path ? ["matlab", path] : ["matlab"], r => { if (r && r.error) say(r.error, true); else root.bar.hubOpen = false })
    }
    function open(cmd) { openProc.command = cmd; openProc.running = true; root.bar.hubOpen = false }

    component LinkButton: Rectangle {
        id: lb
        property string icon: ""
        property string text: ""
        property string sub: ""
        property color tint: root.accent
        signal clicked
        implicitHeight: 54; radius: 12
        color: la.containsMouse ? Qt.alpha(tint, 0.14) : Theme.card; border { color: la.containsMouse ? Qt.alpha(tint, 0.5) : Theme.cardBorder; width: 1 }
        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
spacing: 10
            Rectangle { Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 10; color: Qt.alpha(lb.tint, 0.16)
                        Text { anchors.centerIn: parent; text: lb.icon; color: lb.tint; font { family: root.font; pixelSize: 18 } } }
            ColumnLayout { Layout.fillWidth: true; spacing: 0
                Text { text: lb.text; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 12; bold: true } }
                Text { visible: lb.sub.length > 0; text: lb.sub; color: Theme.dim; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 9 } } }
        }
        MouseArea { id: la; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: lb.clicked() }
    }

    ColumnLayout {
        id: col
        x: 14; width: root.width - 28; y: 8
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            Text { text: "󰦬  Tools"; color: root.accent; font { family: root.font; pixelSize: 12; bold: true } }
            Item { Layout.fillWidth: true }
            Text { visible: root.status.length > 0; text: root.status; color: root.statusErr ? Theme.red : Theme.green; font { family: root.font; pixelSize: 10 } }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 8
            LinkButton { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰐱"; text: "MATLAB"; sub: "start it"; onClicked: root.matlab("") }
            LinkButton { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰎞"; text: "Obsidian"; sub: "open your vault"; tint: Theme.mauve; onClicked: root.open(["setsid", "-f", "obsidian"]) }
            LinkButton { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰑴"; text: "Canvas"; sub: root.sc.configured ? root.sc.domain.replace(/^https?:\/\//, "") : "not connected"; tint: Theme.blue
                         onClicked: { if (root.sc.configured) root.open(["xdg-open", root.sc.domain]); else root.say("connect Canvas on the Due tab first", true) } }
        }

        // backups
        Text { text: "BACKUPS"; color: Theme.dim; font { family: root.font; pixelSize: 9; bold: true; letterSpacing: 1 } }
        Repeater {
            model: root.backups
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true; implicitHeight: bk.implicitHeight + 18; radius: 10
                color: Theme.card; border { color: modelData.level === "ok" ? Theme.cardBorder : Qt.alpha(modelData.level === "bad" ? Theme.red : Theme.yellow, 0.5); width: 1 }
                RowLayout {
                    id: bk
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 12 }
spacing: 10
                    Text { text: modelData.level === "ok" ? "󰄬" : "󰀦"; color: modelData.level === "ok" ? Theme.green : modelData.level === "bad" ? Theme.red : Theme.yellow; font { family: root.font; pixelSize: 16 } }
                    ColumnLayout { Layout.fillWidth: true; spacing: 0
                        Text { text: modelData.name; color: Theme.text; font { family: root.font; pixelSize: 11; bold: true } }
                        Text { text: modelData.message; color: Theme.subtext; wrapMode: Text.WordWrap; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 10 } } }
                }
            }
        }

        // MATLAB folders
        Text { text: "MATLAB PROJECTS"; color: Theme.dim; font { family: root.font; pixelSize: 9; bold: true; letterSpacing: 1 } }
        Repeater {
            model: root.folders
            delegate: LinkButton {
                required property var modelData
                Layout.fillWidth: true
                icon: "󰉋"; text: modelData.name; sub: modelData.path.replace(/^\/home\/[^\/]+/, "~") + "  ·  " + modelData.files + " .m files"
                onClicked: root.matlab(modelData.path)
            }
        }
        Text {
            visible: root.folders.length === 0
            Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.dim; font { family: root.font; pixelSize: 10 }
            text: "No MATLAB folders found yet. Folders with .m files inside ~/MATLAB or ~/Documents/MATLAB show up here and open MATLAB right there. To use other places, list them in ~/.config/qs-bar/matlab-folders.json, like  [\"/home/you/classes/aero3301\"]."
        }

        // courses
        Text { visible: root.sc.configured && root.sc.courses.length > 0; text: "COURSE PAGES"; color: Theme.dim; font { family: root.font; pixelSize: 9; bold: true; letterSpacing: 1 } }
        Repeater {
            model: root.sc.configured ? root.sc.courses : []
            delegate: LinkButton {
                required property var modelData
                Layout.fillWidth: true
                icon: "󰑴"; tint: Theme.blue; text: modelData.name; sub: modelData.code
                onClicked: root.open(["xdg-open", root.sc.domain + "/courses/" + modelData.id])
            }
        }
    }
}
