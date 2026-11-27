import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "schoolutil.js" as U

// Ask Claude from the launcher.
//   ?how long does a Hohmann transfer to Mars take      the answer streams in here, follow-ups continue the chat
//   ??the same question                                 opens it in the Claude app instead (with your claude.ai memories)
//   ?remember I prefer metric units                     adds a line to ~/.config/qs-bar/claude-memory.md
//   ?memory   ?new   ?context                           edit the memory file, start over, toggle school context
// Answers come from the `claude` command with your plan (ask.sh). It sees only your memory file and, if you switch it on, a short
// summary of your courses and what is due. Nothing else on this computer.
Rectangle {
    id: card
    required property string query
    required property var bar
    readonly property var sc: bar.school
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.mauve

    readonly property string raw: query.trim()
    readonly property bool inApp: raw.indexOf("??") === 0
    readonly property bool asking: raw.indexOf("?") === 0 && !inApp
    readonly property string text: (inApp ? raw.slice(2) : raw.slice(1)).trim()
    readonly property string command: text.split(/\s+/)[0].toLowerCase()
    readonly property bool isRemember: asking && command === "remember"
    readonly property bool isMemory: asking && text.toLowerCase() === "memory"
    readonly property bool isNew: asking && text.toLowerCase() === "new"
    readonly property bool isContext: asking && text.toLowerCase() === "context"
    readonly property bool isCommand: isRemember || isMemory || isNew || isContext

    property var    turns: []                  // [{ role: "user"|"assistant", text }]
    property string partial: ""
    property bool   busy: false
    property string error: ""
    property string note: ""
    property int    memoryLines: 0
    property bool   claudeOk: true
    readonly property bool useContext: sc.pref("askContext", false)

    visible: inApp || asking || (turns.length > 0 && raw === "")
    Layout.fillWidth: true; Layout.topMargin: 8
    implicitHeight: col.implicitHeight + 22
    radius: 12; color: Qt.alpha(accent, 0.07); border { color: Qt.alpha(accent, 0.35); width: 1 }

    Job { id: statJob; script: Quickshell.shellPath("ask.sh") }
    Job { id: actJob;  script: Quickshell.shellPath("ask.sh") }
    Process { id: openProc; onExited: running = false }
    Process { id: copyProc }
    Job { id: noteJob; script: Quickshell.shellPath("notes.sh") }
    function refreshStat() { statJob.go(["stat"], r => { if (r) { memoryLines = r.memory; claudeOk = r.claude } }) }
    onVisibleChanged: if (visible) refreshStat()
    Component.onCompleted: refreshStat()
    function say(t) { note = t; noteTimer.restart() }
    Timer { id: noteTimer; interval: 3500; onTriggered: card.note = "" }

    // what the bar tells Claude about school, only if you switch it on
    function schoolContext() {
        var L = ["Today is " + new Date().toDateString() + ", " + U.clock(Date.now()) + "."]
        if (sc.courses.length) L.push("Courses this term: " + sc.courses.map(c => c.name + " (" + c.code + (c.score !== null && c.score !== undefined ? ", " + c.score.toFixed(0) + "%" : "") + ")").join("; ") + ".")
        var up = sc.upcoming.slice(0, 8)
        if (up.length) L.push("Due soon: " + up.map(a => a.name + " [" + a.course + ", " + U.dueLabel(a.due * 1000, sc.nowMs) + "]").join("; ") + ".")
        if (sc.overdue.length) L.push("Overdue or missing: " + sc.overdue.slice(0, 5).map(a => a.name + " [" + a.course + "]").join("; ") + ".")
        if (sc.exams.length) L.push("Exams: " + sc.exams.slice(0, 4).map(e => e.name + " " + U.dueLabel(e.whenMs, sc.nowMs)).join("; ") + ".")
        if (sc.todayEvents.length) L.push("Today's calendar: " + sc.todayEvents.slice(0, 5).map(e => e.title + " " + U.clock(e.startMs)).join("; ") + ".")
        return L.join("\n")
    }
    function buildPrompt(question) {
        var parts = []
        if (useContext) parts.push("[Context from the user's school app]\n" + schoolContext() + "\n[End of context]\n")
        if (turns.length) parts.push("Earlier in this chat:\n" + turns.slice(-8).map(t => (t.role === "user" ? "User: " : "Claude: ") + t.text).join("\n") + "\n")
        parts.push("User: " + question)
        return parts.join("\n")
    }

    property string pendingPrompt: ""
    property bool   restart: false
    Process {
        id: proc
        stdinEnabled: true
        command: ["bash", Quickshell.shellPath("ask.sh")]
        onStarted: { write(card.pendingPrompt); card.pendingPrompt = ""; stdinEnabled = false }
        stdout: SplitParser {
            onRead: data => {
                var m = null; try { m = JSON.parse(data) } catch (e) { return }
                if (m.d !== undefined) { card.partial += m.d; flick.toEnd() }
                else if (m.error) { card.error = m.error; card.finish(false) }
                else if (m.done) card.finish(true)
            }
        }
        onExited: {
            stdinEnabled = true
            if (card.restart) { card.restart = false; running = true; return }       // the next question was typed while the last one was still shutting down
            if (card.busy) card.finish(card.partial.length > 0)
        }
    }
    function finish(ok) {
        if (!busy) return
        busy = false
        if (ok && partial.length) turns = turns.concat([{ role: "assistant", text: partial }])
        partial = ""
    }
    function ask(question) {
        if (busy) return
        error = ""
        pendingPrompt = buildPrompt(question)
        turns = turns.concat([{ role: "user", text: question }])
        partial = ""; busy = true
        if (proc.running) { restart = true; proc.running = false } else proc.running = true
        flick.toEnd()
    }

    // Enter was pressed in the search box; returns true when the card used it
    function submit() {
        if (inApp) {
            if (!text) return true
            openProc.command = ["xdg-open", "claude://claude.ai/new?q=" + encodeURIComponent(text)]
            openProc.running = true
            bar.hubOpen = false
            return true
        }
        if (!asking) return false
        if (isNew) { turns = []; partial = ""; error = ""; return true }
        if (isContext) { sc.setPref("askContext", !useContext); say(useContext ? "school context is off" : "school context is on"); return true }
        if (isMemory) { actJob.go(["memory"], r => { if (r && r.path) { openProc.command = ["xdg-open", r.path]; openProc.running = true; bar.hubOpen = false } }); return true }
        if (isRemember) {
            var t = text.slice(8).trim()
            if (t) actJob.go(["remember", t], r => { if (r && r.ok) { say("remembered"); refreshStat() } })
            return true
        }
        if (!text) return true
        ask(text)
        return true
    }
    // after sending, the search box goes back to a bare "?" so you can type a follow-up
    readonly property bool clearsAfterSubmit: asking && !isCommand && text.length > 0
    function copyAnswer() {
        var last = turns.filter(t => t.role === "assistant").slice(-1)[0]
        if (!last) return
        copyProc.command = ["wl-copy", last.text]; copyProc.running = true; say("copied")
    }
    function toObsidian() {
        var last = turns.filter(t => t.role === "assistant").slice(-1)[0], q = turns.filter(t => t.role === "user").slice(-1)[0]
        if (!last) return
        noteJob.go(["capture", (q ? q.text + " — " : "") + last.text], r => { say(r && r.ok ? "added to Inbox.md" : "could not save") })
    }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; topMargin: 11 }
        spacing: 6

        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Text { text: "󰧑"; color: card.accent; font { family: card.font; pixelSize: 14 } }
            Text { text: card.inApp ? "Open in the Claude app" : "Ask Claude"; color: card.accent; font { family: card.font; pixelSize: 11; bold: true } }
            Item { Layout.fillWidth: true }
            Text { visible: card.note.length > 0; text: card.note; color: Theme.green; font { family: card.font; pixelSize: 10 } }
            Rectangle {
                visible: !card.inApp
                Layout.preferredHeight: 20; Layout.preferredWidth: cx.implicitWidth + 14; radius: 10
                color: card.useContext ? Qt.alpha(Theme.green, 0.2) : Theme.card; border { color: card.useContext ? Theme.green : Theme.cardBorder; width: 1 }
                Text { id: cx; anchors.centerIn: parent; text: card.useContext ? "school context on" : "school context off"; color: card.useContext ? Theme.green : Theme.dim; font { family: card.font; pixelSize: 9 } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: card.sc.setPref("askContext", !card.useContext) }
            }
            Text { visible: !card.inApp; text: card.memoryLines > 0 ? "memory: " + card.memoryLines : "no memory yet"; color: Theme.dim; font { family: card.font; pixelSize: 9 } }
        }

        // the "??" shortcut
        Text {
            visible: card.inApp
            Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.text; textFormat: Text.PlainText; font { family: card.font; pixelSize: 12 }
            text: card.text ? "↵ opens a new chat in the Claude app with:\n“" + card.text + "”\n(it keeps your claude.ai memories; press Enter there to send)" : "Type your question after ??, then press Enter."
        }
        // commands
        Text {
            visible: card.asking && card.isCommand
            Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.text; textFormat: Text.PlainText; font { family: card.font; pixelSize: 12 }
            text: card.isRemember ? "↵ remember: " + card.text.slice(8)
                  : card.isMemory ? "↵ open your memory file (paste what claude.ai remembers about you there)"
                  : card.isNew ? "↵ start a new conversation"
                  : "↵ turn the school context " + (card.useContext ? "off" : "on") + " (your courses, what's due, exams and today's classes are sent with each question)"
        }
        Text {
            visible: !card.claudeOk
            Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.red; font { family: card.font; pixelSize: 11 }
            text: "The claude command was not found, so questions cannot be answered here."
        }

        // transcript
        Flickable {
            id: flick
            visible: card.turns.length > 0 || card.busy
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(330, tcol.implicitHeight + 4)
            contentHeight: tcol.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
            function toEnd() { Qt.callLater(function () { if (contentHeight > height) contentY = contentHeight - height }) }
            ColumnLayout {
                id: tcol
                width: flick.width; spacing: 8
                Repeater {
                    model: card.turns
                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true; spacing: 2
                        Text { text: modelData.role === "user" ? "you" : "claude"; color: modelData.role === "user" ? Theme.dim : card.accent; font { family: card.font; pixelSize: 9; bold: true } }
                        Text {
                            Layout.fillWidth: true; wrapMode: Text.WordWrap
                            textFormat: modelData.role === "user" ? Text.PlainText : Text.MarkdownText
                            text: modelData.text
                            color: modelData.role === "user" ? Theme.subtext : Theme.text
                            linkColor: Theme.sky
                            onLinkActivated: link => { if (/^https?:\/\//.test(link)) { openProc.command = ["xdg-open", link]; openProc.running = true; card.bar.hubOpen = false } }
                            font { family: card.font; pixelSize: 12 }
                        }
                    }
                }
                ColumnLayout {
                    visible: card.busy
                    Layout.fillWidth: true; spacing: 2
                    Text { text: "claude"; color: card.accent; font { family: card.font; pixelSize: 9; bold: true } }
                    Text {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap; textFormat: Text.MarkdownText
                        text: card.partial.length ? card.partial + " ▍" : "thinking…"
                        color: card.partial.length ? Theme.text : Theme.dim; font { family: card.font; pixelSize: 12 }
                    }
                }
            }
        }
        Text { visible: card.error.length > 0; Layout.fillWidth: true; wrapMode: Text.WordWrap; text: card.error; color: Theme.red; font { family: card.font; pixelSize: 11 } }

        RowLayout {
            visible: card.turns.length > 0 && !card.busy && !card.inApp
            Layout.fillWidth: true; spacing: 12
            Text { text: "copy"; color: card.accent; font { family: card.font; pixelSize: 10 }
                   MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: card.copyAnswer() } }
            Text { text: "to Obsidian"; color: card.accent; font { family: card.font; pixelSize: 10 }
                   MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: card.toObsidian() } }
            Item { Layout.fillWidth: true }
            Text { text: "?new to start over"; color: Theme.dim; font { family: card.font; pixelSize: 9 } }
        }
        Text {
            visible: card.asking && !card.isCommand && card.text.length === 0 && card.turns.length === 0
            Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.dim; font { family: card.font; pixelSize: 10 }
            text: "Type a question and press Enter.   ??question opens it in the Claude app.   ?remember …  ?memory  ?context"
        }
        Text {
            visible: card.asking && card.text.length > 0 && !card.isCommand && !card.busy
            Layout.fillWidth: true; color: Theme.dim; font { family: card.font; pixelSize: 10 }
            text: "↵ ask   ·   ?? to open in the Claude app instead"
        }
    }
}
