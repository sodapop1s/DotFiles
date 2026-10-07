import QtQuick
import Quickshell
import Quickshell.Io
import "schoolutil.js" as U

// Everything the School tab knows: Canvas (courses, assignments, announcements), today's classes from the calendar,
// the battery/bedtime assistant, and the little preferences file. It lives for as long as the bar does, so the
// Home page and the clock can show "due soon" without the School tab ever being opened.
Item {
    id: root
    required property var bar

    // ── preferences (~/.local/state/qs-bar-school.json) ───
    property var  prefs: ({})
    property bool prefsLoaded: false
    function pref(k, def) { return prefs[k] === undefined ? def : prefs[k] }
    function setPref(k, v) {
        var p = Object.assign({}, prefs); p[k] = v; prefs = p
        prefStore.setText(JSON.stringify(p))
    }
    FileView {
        id: prefStore
        path: Quickshell.env("HOME") + "/.local/state/qs-bar-school.json"
        onLoaded: { try { root.prefs = JSON.parse(prefStore.text()) } catch (e) {} root.prefsLoaded = true }
        onLoadFailed: root.prefsLoaded = true
    }

    // ── notifications from the School tab (shown even under Do Not Disturb: app name "Study") ──
    property var notifyQueue: []
    function notify(title, body) { notifyQueue = notifyQueue.concat([[title, body || ""]]); if (!notifyTimer.running) notifyTimer.start() }
    Process { id: notifyProc; onExited: { running = false; if (root.notifyQueue.length) notifyTimer.start() } }
    Timer {
        id: notifyTimer; interval: 400
        onTriggered: {
            if (notifyProc.running || root.notifyQueue.length === 0) return
            var n = root.notifyQueue[0]; root.notifyQueue = root.notifyQueue.slice(1)
            notifyProc.command = ["notify-send", "-a", "Study", "-i", "appointment-soon", n[0], n[1]]
            notifyProc.running = true
        }
    }

    property real nowMs: Date.now()
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.nowMs = Date.now() }

    // ══ Canvas ═══════════════════════════════════════════
    property bool   configured: false
    property string domain: ""
    property var    courses: []
    property var    due: []
    property var    announce: []
    property int    inbox: 0
    property bool   syncing: false
    property real   lastSync: 0
    property string canvasError: ""
    property bool   checked: false              // we have asked canvas.sh at least once

    Job { id: stJob;   script: Quickshell.shellPath("canvas.sh") }
    Job { id: crsJob;  script: Quickshell.shellPath("canvas.sh") }
    Job { id: dueJob;  script: Quickshell.shellPath("canvas.sh") }
    Job { id: annJob;  script: Quickshell.shellPath("canvas.sh") }
    Job { id: inbJob;  script: Quickshell.shellPath("canvas.sh") }

    function refresh() {
        if (syncing) return
        stJob.go(["status"], st => {
            checked = true
            if (!st) return
            configured = st.configured; domain = st.domain
            if (!configured) return
            syncing = true; canvasError = ""
            crsJob.go(["courses"], cr => {
                if (Array.isArray(cr)) courses = cr
                else if (cr && cr.error) canvasError = cr.error
                dueJob.go(["due", "30"], d => {
                    if (Array.isArray(d)) { due = d; lastSync = Date.now(); nowMs = Date.now(); finalize(d.filter(a => a.submitted)) }
                    else if (d && d.error) canvasError = d.error
                    annJob.go(["announcements"], a => {
                        if (Array.isArray(a)) announce = a
                        inbJob.go(["inbox"], i => { if (i && i.unread !== undefined) inbox = i.unread; syncing = false })
                    })
                })
            })
        })
    }
    Timer { interval: 900000; running: root.configured; repeat: true; onTriggered: root.refresh() }
    Timer { interval: 2500; running: true; onTriggered: { root.refresh(); root.refreshEvents() } }

    // connect: the token goes to canvas.sh on stdin, never on a command line
    property string setupError: ""
    property bool   connecting: false
    property string pendingToken: ""
    Process {
        id: setupProc
        stdinEnabled: true
        onStarted: { write(root.pendingToken + "\n"); root.pendingToken = "" }
        stdout: StdioCollector {
            onStreamFinished: {
                root.connecting = false
                var r = null; try { r = JSON.parse(text) } catch (e) {}
                if (r && r.ok) { root.setupError = ""; root.refresh() }
                else root.setupError = r && r.error ? r.error : "could not reach Canvas"
            }
        }
    }
    function connect(domainText, token) {
        if (connecting) return
        setupError = ""; connecting = true; pendingToken = token
        setupProc.command = ["bash", Quickshell.shellPath("canvas.sh"), "setup", domainText.trim()]
        setupProc.running = true
    }
    Job { id: outJob; script: Quickshell.shellPath("canvas.sh") }
    function disconnect() { outJob.go(["logout"], r => { configured = false; courses = []; due = []; announce = []; inbox = 0 }) }

    // assignments you have ticked off yourself (for things Canvas cannot see, like paper hand-ins)
    readonly property var doneIds: pref("done", [])
    function isDone(a) { return doneIds.indexOf(String(a.id)) >= 0 }
    function toggleDone(a) {
        var d = doneIds.slice(), k = String(a.id), i = d.indexOf(k)
        if (i >= 0) d.splice(i, 1); else { d.push(k); finalize([a]) }
        setPref("done", d.slice(-300))
    }
    // ══ progress and time estimates ═══════════════════
    // Progress is yours to set (not started → started → well along → nearly done). Time estimates come from how long
    // that kind of assignment really took you before, measured with the study timer.
    readonly property var progress: pref("progress", {})
    function progressOf(a) { return progress[String(a.id)] || 0 }
    function cycleProgress(a) {
        var p = Object.assign({}, progress), k = String(a.id), n = ((p[k] || 0) + 1) % 4
        if (n === 0) delete p[k]; else p[k] = n
        setPref("progress", p)
    }
    readonly property var taskLog: pref("taskLog", {})            // assignment id -> minutes worked, from the study timer
    readonly property var history: pref("history", {})            // kind of work -> minutes it took (last 12)
    readonly property var recorded: pref("recorded", [])
    readonly property var typicalMin: ({ homework: 90, quiz: 30, exam: 120, paper: 180, project: 240, lab: 120, discussion: 30, presentation: 120, reading: 45, milestone: 150, other: 60 })
    function typeOf(a) {
        var n = (a.name || "").toLowerCase()
        if (/quiz/.test(n)) return "quiz"
        if (/exam|midterm|final\b/.test(n)) return "exam"
        if (/milestone/.test(n)) return "milestone"
        if (/lab\b|laboratory/.test(n)) return "lab"
        if (/paper|essay|report|reflection|draft/.test(n)) return "paper"
        if (/project|checklist|plan\b/.test(n)) return "project"
        if (/present/.test(n)) return "presentation"
        if (/discussion|forum|post/.test(n)) return "discussion"
        if (/read|chapter notes/.test(n)) return "reading"
        if (/homework|hw\b|problem set|assignment|worksheet/.test(n)) return "homework"
        return "other"
    }
    function median(arr) { var s = arr.slice().sort(function (x, y) { return x - y }), m = Math.floor(s.length / 2); return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2 }
    // minutes this kind of assignment usually takes you
    function estimateMin(a) {
        var t = typeOf(a), h = history[t] || []
        var base = h.length >= 2 ? median(h) : (h.length === 1 ? h[0] : typicalMin[t])
        return Math.max(10, Math.round(base / 5) * 5)
    }
    function learned(a) { return (history[typeOf(a)] || []).length >= 2 }
    // what is left: the estimate minus the time you have logged, and less as you mark progress
    function remainingMin(a) {
        var est = estimateMin(a), spent = taskLog[String(a.id)] || 0
        return Math.max(5, Math.round(Math.min(est - spent, est * (1 - 0.25 * progressOf(a)))))
    }
    function workMinutes(days) {
        var limit = nowMs + days * 86400000, sum = 0
        open.forEach(function (a) { if (a.due * 1000 <= limit && (a.due * 1000 >= nowMs || a.missing)) sum += remainingMin(a) })
        return sum
    }
    readonly property real dailyHours: pref("dailyHours", 4)
    // when something is finished, remember how long it really took (only if you timed it)
    function finalize(list) {
        var rec = recorded.slice(), h = Object.assign({}, history), changed = false
        list.forEach(function (a) {
            var k = String(a.id), m = taskLog[k] || 0
            if (rec.indexOf(k) >= 0 || m < 5) return
            var t = typeOf(a), arr = (h[t] || []).concat([m]); h[t] = arr.slice(-12)
            rec.push(k); changed = true
        })
        if (changed) { setPref("history", h); setPref("recorded", rec.slice(-400)) }
    }

    readonly property var open: due.filter(a => !a.submitted && !isDone(a))
    readonly property var upcoming: open.filter(a => a.due * 1000 >= nowMs).sort((a, b) => a.due - b.due)
    readonly property var overdue: open.filter(a => a.due * 1000 < nowMs && (a.missing || a.due * 1000 > nowMs - 14 * 86400000))
    // short text for the clock island: the next thing due within two days
    readonly property string chipText: {
        var a = upcoming[0]
        if (!a || a.due * 1000 - nowMs > 2 * 86400000) return ""
        var nm = a.name.length > 14 ? a.name.slice(0, 13) + "…" : a.name
        return nm + " · " + U.rel(a.due * 1000, nowMs).replace("in ", "")
    }

    // ══ exams: the ones you add yourself, plus anything in Canvas that looks like an exam ══
    readonly property var manualExams: pref("exams", [])
    readonly property var examTopics: pref("examTopics", {})
    readonly property var exams: {
        var out = manualExams.map(e => ({ id: e.id, name: e.name, course: e.course || "", whenMs: e.when, manual: true, url: "" }))
        due.forEach(a => {
            if (U.isExamName(a.name) && !isDone(a) && a.due * 1000 > nowMs - 3600000)
                out.push({ id: "c" + a.id, name: a.name, course: a.course, whenMs: a.due * 1000, manual: false, url: a.url })
        })
        return out.filter(e => e.whenMs > nowMs - 3600000).sort((x, y) => x.whenMs - y.whenMs)
    }
    function topicsOf(id) { return examTopics[id] || [] }
    function setTopics(id, arr) { var m = Object.assign({}, examTopics); m[id] = arr; setPref("examTopics", m) }
    function addExam(name, course, whenMs) {
        var list = manualExams.slice()
        list.push({ id: "m" + Date.now(), name: name, course: course, when: whenMs })
        setPref("exams", list)
    }
    function removeExam(id) {
        setPref("exams", manualExams.filter(e => e.id !== id))
        var m = Object.assign({}, examTopics); delete m[id]; setPref("examTopics", m)
    }
    readonly property var nextExam: exams.length ? exams[0] : null
    function examReadiness(e) { var t = topicsOf(e.id); return t.length ? t.filter(x => x.done).length / t.length : -1 }

    // ══ classes (from the calendar the Calendar applet syncs) ══
    property var  events: []
    property bool calendarOn: false
    Job { id: calJob; script: Quickshell.shellPath("calendar.sh") }
    function refreshEvents() {
        var t = new Date()
        var end = new Date(t.getFullYear(), t.getMonth(), t.getDate() + 4)
        calJob.go(["events", U.isoDate(t), U.isoDate(end)], r => {
            if (Array.isArray(r)) {
                events = r.filter(e => !e.allDay).map(e => Object.assign({}, e, { startMs: Date.parse(e.start), endMs: Date.parse(e.end) })).sort((a, b) => a.startMs - b.startMs)
                calendarOn = true
            } else calendarOn = false
        })
    }
    Timer { interval: 600000; running: true; repeat: true; onTriggered: root.refreshEvents() }
    readonly property var todayEvents: events.filter(e => U.dayStart(e.startMs) === U.dayStart(nowMs) && e.endMs > nowMs)
    readonly property var nextEvent: events.find(e => e.endMs > nowMs) || null

    // ══ battery and bedtime assistant ═══════════════════
    property var    batHist: []                // [{t, pct}] samples while on battery
    property string notifiedFor: ""
    property string bedNotified: ""
    readonly property bool onBattery: bar.batStatus === "Discharging"
    function drainRate() {                     // % per hour, from the last hour of samples (a typical 12 if we do not know yet)
        var h = batHist.filter(s => s.t > Date.now() - 3600000)
        if (h.length < 2) return 12
        var a = h[0], b = h[h.length - 1], hours = (b.t - a.t) / 3600000
        if (hours < 0.15) return 12
        return Math.max(5, Math.min(35, (a.pct - b.pct) / hours))
    }
    function assistantTick() {
        var now = Date.now()
        if (onBattery) { batHist = batHist.concat([{ t: now, pct: bar.batPct }]).filter(s => s.t > now - 5400000) }
        else batHist = []
        nowMs = now
        if (pref("batteryAssist", true) && onBattery) {
            var ev = events.find(e => e.startMs > now && e.startMs - now < 3 * 3600000 && e.endMs - e.startMs >= 45 * 60000)
            if (ev) {
                var hoursToEnd = (ev.endMs - now) / 3600000
                var need = Math.min(95, Math.round(drainRate() * hoursToEnd + 15))
                var key = ev.uid + ev.start
                if (bar.batPct < need && notifiedFor !== key) {
                    notifiedFor = key
                    notify("Charge before " + ev.title, "At " + bar.batPct + "% now; " + ev.title + " runs " + U.clock(ev.startMs) + "–" + U.clock(ev.endMs) + " and will want about " + need + "%.")
                }
            }
        }
        // Sunday evening: the weekly review is ready
        var dt = new Date(now)
        if (dt.getDay() === 0 && dt.getHours() >= 18 && pref("reviewNotified", "") !== U.isoDate(dt)) {
            setPref("reviewNotified", U.isoDate(dt))
            notify("Your weekly review is ready", "Open School → Week to see next week at a glance.")
        }
        // bedtime reminder
        var bt = bedtime
        if (bt && pref("bedtimeAssist", true) && now >= bt.ms - 20 * 60000 && now < bt.ms + 30 * 60000 && bedNotified !== bt.key) {
            bedNotified = bt.key
            notify("Time to wind down", "Bed by " + U.clock(bt.ms) + " to get " + pref("sleepHours", 8) + "h before " + bt.title + " at " + U.clock(bt.startMs) + ".")
        }
    }
    Timer { interval: 300000; running: true; repeat: true; onTriggered: root.assistantTick() }
    Timer { interval: 20000; running: true; onTriggered: root.assistantTick() }
    Connections { target: bar; function onBatStatusChanged() { root.assistantTick() } }

    // tomorrow's first timed event decides bedtime: it starts, minus time to get ready, minus sleep
    readonly property var bedtime: {
        var t = new Date(nowMs), tomorrow = new Date(t.getFullYear(), t.getMonth(), t.getDate() + 1).getTime()
        var first = events.find(e => e.startMs >= tomorrow && e.startMs < tomorrow + 86400000)
        // after midnight "tomorrow's first event" is really today's, so look at what is still ahead
        var todayFirst = events.find(e => e.startMs > nowMs && U.dayStart(e.startMs) === U.dayStart(nowMs) && new Date(nowMs).getHours() < 5)
        var ev = todayFirst || first
        if (!ev) return null
        var ms = ev.startMs - (pref("prepMinutes", 75) + pref("sleepHours", 8) * 60) * 60000
        return { ms: ms, startMs: ev.startMs, title: ev.title, key: ev.uid + ev.start }
    }
}
