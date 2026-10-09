import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "schoolutil.js" as U

// School > Week: one page that sums up the week ahead and the week behind. It nudges you on Sunday evening, and can save
// itself as a note in your Obsidian vault (Weekly Reviews/).
Flickable {
    id: root
    required property var bar
    readonly property var sc: bar.school
    readonly property var fs: bar.studyFocus
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.mauve
    contentHeight: col.implicitHeight + 24
    clip: true; boundsBehavior: Flickable.StopAtBounds

    property var    money: null
    property var    backups: []
    property int    newLectures: 0
    property string status: ""
    property bool   statusErr: false
    Job { id: moneyJob;  script: Quickshell.shellPath("budget.sh") }
    Job { id: backupJob; script: Quickshell.shellPath("backup.sh") }
    Job { id: lecJob;    script: Quickshell.shellPath("lectures.sh") }
    function say(msg, err) { status = msg; statusErr = !!err; statusTimer.restart() }
    Timer { id: statusTimer; interval: 5000; onTriggered: root.status = "" }
    function activate() {
        sc.refresh()
        moneyJob.go(["summary"], r => { if (r && !r.error) money = r })
        backupJob.go(["status"], r => { if (Array.isArray(r)) backups = r })
        lecJob.go(["list"], l => { if (Array.isArray(l)) newLectures = l.filter(f => f.mtime * 1000 > Date.now() - 7 * 86400000).length })
    }

    readonly property real weekStart: U.dayStart(sc.nowMs) - ((new Date(sc.nowMs)).getDay() + 6) % 7 * 86400000     // Monday
    readonly property var nextWeek: sc.upcoming.filter(a => a.due * 1000 < sc.nowMs + 7 * 86400000)
    readonly property var soonExams: sc.exams.filter(e => e.whenMs < sc.nowMs + 14 * 86400000)
    readonly property var warnings: backups.filter(b => b.level !== "ok")

    function markdown() {
        var L = []
        var d = new Date(root.weekStart)
        L.push("# Week of " + U.isoDate(d), "")
        L.push("## Coming up")
        if (nextWeek.length === 0) L.push("- Nothing due in the next 7 days")
        nextWeek.forEach(a => L.push("- [ ] " + a.name + " — " + a.course + ", " + U.dueLabel(a.due * 1000, sc.nowMs)))
        if (sc.overdue.length) { L.push("", "## Missing or overdue"); sc.overdue.forEach(a => L.push("- " + a.name + " — " + a.course)) }
        if (soonExams.length) {
            L.push("", "## Exams")
            soonExams.forEach(e => { var t = sc.topicsOf(e.id); L.push("- " + e.name + " — " + U.dueLabel(e.whenMs, sc.nowMs) + (t.length ? " (" + t.filter(x => x.done).length + "/" + t.length + " topics ready)" : "")) })
        }
        L.push("", "## Focus", "- " + U.minutesText(fs.weekMinutes) + " focused this week")
        fs.byCourse.slice(0, 5).forEach(c => L.push("  - " + (c.course || "General") + ": " + U.minutesText(c.min)))
        if (money) L.push("", "## Money", "- Spent " + U.money(money.spent) + " this month" + (money.limit ? " of " + U.money(money.limit) : ""))
        if (warnings.length) { L.push("", "## Backups"); warnings.forEach(b => L.push("- " + b.name + ": " + b.message)) }
        L.push("", "## Reflection", "- What went well:", "- What to fix:", "")
        return L.join("\n")
    }
    Process {
        id: saveProc
        stdinEnabled: true
        property string text: ""
        onStarted: { write(text); stdinEnabled = false }
        stdout: StdioCollector {
            onStreamFinished: {
                var r = null; try { r = JSON.parse(text) } catch (e) {}
                saveProc.stdinEnabled = true
                if (r && r.ok) root.say("saved to Obsidian: " + r.rel, false); else root.say(r && r.error ? r.error : "could not save", true)
            }
        }
    }
    function saveNote() {
        saveProc.text = markdown()
        saveProc.command = ["bash", Quickshell.shellPath("notes.sh"), "newnote", "Weekly Reviews/Week of " + U.isoDate(new Date(root.weekStart)) + ".md"]
        saveProc.running = true
    }

    component Card: Rectangle {
        default property alias content: inner.data
        Layout.fillWidth: true; implicitHeight: inner.implicitHeight + 22; radius: 12; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
        ColumnLayout { id: inner; anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
spacing: 5 }
    }
    component Head: Text { color: Theme.text; font { family: root.font; pixelSize: 12; bold: true } }
    component Line: Text { Layout.fillWidth: true; elide: Text.ElideRight; textFormat: Text.PlainText; color: Theme.subtext; font { family: root.font; pixelSize: 11 } }

    ColumnLayout {
        id: col
        x: 14; width: root.width - 28; y: 8
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            Text { text: "󰃰  Week of " + U.isoDate(new Date(root.weekStart)); color: root.accent; font { family: root.font; pixelSize: 12; bold: true } }
            Item { Layout.fillWidth: true }
            Text { visible: root.status.length > 0; text: root.status; color: root.statusErr ? Theme.red : Theme.green; elide: Text.ElideMiddle; Layout.maximumWidth: 230; font { family: root.font; pixelSize: 10 } }
            Rectangle {
                Layout.preferredHeight: 26; Layout.preferredWidth: sv.implicitWidth + 20; radius: 13; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                Text { id: sv; anchors.centerIn: parent; text: "save to Obsidian"; color: Theme.text; font { family: root.font; pixelSize: 10 } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.saveNote() }
            }
        }

        Card {
            RowLayout { Layout.fillWidth: true
                Head { text: "󰃭  Coming up" }
                Item { Layout.fillWidth: true }
                Text { visible: root.sc.overdue.length > 0; text: root.sc.overdue.length + " overdue"; color: Theme.red; font { family: root.font; pixelSize: 10 } }
                Text { visible: root.sc.inbox > 0; text: "󰇮 " + root.sc.inbox; color: Theme.yellow; font { family: root.font; pixelSize: 10 } } }
            Repeater {
                model: root.nextWeek.slice(0, 6)
                delegate: RowLayout { required property var modelData; Layout.fillWidth: true; spacing: 8
                    Line { text: modelData.name; color: Theme.text }
                    Text { text: modelData.course.split(" ")[0]; color: Theme.dim; font { family: root.font; pixelSize: 9 } }
                    Text { text: U.dueLabel(modelData.due * 1000, root.sc.nowMs).replace(/ \d+(:\d+)? [AP]M$/, ""); color: Theme.subtext; Layout.preferredWidth: 56; horizontalAlignment: Text.AlignRight; font { family: root.font; pixelSize: 10 } } }
            }
            Line { visible: root.nextWeek.length === 0; text: root.sc.configured ? "Nothing due in the next 7 days." : "Connect Canvas on the Due tab to see this." }
            Line { visible: root.nextWeek.length > 6; text: "+ " + (root.nextWeek.length - 6) + " more" ; color: Theme.dim }
        }
        Card {
            visible: root.soonExams.length > 0
            Head { text: "󰈙  Exams in the next two weeks" }
            Repeater {
                model: root.soonExams
                delegate: RowLayout { required property var modelData; Layout.fillWidth: true; spacing: 8
                    readonly property real ready: root.sc.examReadiness(modelData)
                    Line { text: modelData.name; color: Theme.text }
                    Text { text: ready >= 0 ? Math.round(ready * 100) + "% ready" : "no topics yet"; color: ready >= 0.7 ? Theme.green : ready >= 0 ? Theme.yellow : Theme.dim; font { family: root.font; pixelSize: 10 } }
                    Text { text: U.dueLabel(modelData.whenMs, root.sc.nowMs).replace(/ \d+(:\d+)? [AP]M$/, ""); color: Theme.subtext; Layout.preferredWidth: 56; horizontalAlignment: Text.AlignRight; font { family: root.font; pixelSize: 10 } } }
            }
        }
        Card {
            RowLayout { Layout.fillWidth: true
                Head { text: "󰔟  Focus" }
                Item { Layout.fillWidth: true }
                Text { text: U.minutesText(root.fs.weekMinutes) + " this week"; color: Theme.green; font { family: root.font; pixelSize: 11; bold: true } } }
            Repeater {
                model: root.fs.byCourse.slice(0, 4)
                delegate: RowLayout { required property var modelData; Layout.fillWidth: true
                    Line { text: modelData.course || "General" }
                    Text { text: U.minutesText(modelData.min); color: Theme.dim; font { family: root.font; pixelSize: 10 } } }
            }
            Line { visible: root.fs.byCourse.length === 0; text: "No focus sessions yet this week. Start one on the Focus tab." }
        }
        Card {
            RowLayout { Layout.fillWidth: true
                Head { text: "󰠓  Money" }
                Item { Layout.fillWidth: true }
                Text { visible: root.money !== null; text: root.money ? U.money(root.money.spent) + (root.money.limit ? " of " + U.money(root.money.limit) : " spent") : ""; color: root.money && root.money.left !== null && root.money.left < 0 ? Theme.red : Theme.text; font { family: root.font; pixelSize: 11; bold: true } } }
            Line { visible: root.money && root.money.count === 0; text: "Nothing logged this month." }
            Line { visible: root.money && root.money.perDay !== null && root.money.left > 0; text: root.money ? "about " + U.money(root.money.perDay) + " a day for the next " + root.money.daysLeft + " days" : "" }
        }
        Card {
            Head { text: "󰂺  Lectures and backups" }
            Line { text: root.newLectures + " new lecture file" + (root.newLectures === 1 ? "" : "s") + " this week" }
            Repeater {
                model: root.backups
                delegate: RowLayout { required property var modelData; Layout.fillWidth: true; spacing: 8
                    Text { text: modelData.level === "ok" ? "✓" : "!"; color: modelData.level === "ok" ? Theme.green : modelData.level === "warn" ? Theme.yellow : Theme.red; font { family: root.font; pixelSize: 12; bold: true } }
                    Line { text: modelData.name + ": " + modelData.message; color: modelData.level === "ok" ? Theme.subtext : Theme.text } }
            }
        }
    }
}
