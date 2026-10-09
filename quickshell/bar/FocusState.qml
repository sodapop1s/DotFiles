import QtQuick
import Quickshell
import Quickshell.Io
import "schoolutil.js" as U

// Study timer (pomodoro), focus mode, and the break/posture nudges. State for the School tab's Focus page.
//  - Focus mode silences notifications and keeps your distraction apps closed until its timer ends; ending it early
//    needs your login password. (It is a speed bump against your own impulses, not a security lock.)
//  - The pomodoro timer shows its countdown on the bar's clock island.
Item {
    id: root
    required property var bar
    required property var school
    readonly property string scripts: Quickshell.shellPath("focus.sh")

    // ══ pomodoro ═════════════════════════════════════════
    property string phase: "idle"               // idle | focus | break | long
    property bool   running: false
    property real   endMs: 0
    property real   leftMs: 0                   // when paused
    property int    cycle: 0                    // focus sessions finished since the last long break
    property real   accumMs: 0                  // focus time not yet written to the log
    readonly property var cfg: school.pref("pomodoro", { focus: 25, brk: 5, long: 15, every: 4, autoDnd: true })
    function setCfg(k, v) { var c = Object.assign({}, cfg); c[k] = v; school.setPref("pomodoro", c) }
    function phaseMs(p) { return (p === "focus" ? cfg.focus : p === "break" ? cfg.brk : cfg.long) * 60000 }
    property real now: Date.now()
    readonly property real remaining: running ? Math.max(0, endMs - now) : (phase === "idle" ? phaseMs("focus") : leftMs)
    function clock(ms) { var s = Math.ceil(ms / 1000); return U.pad(Math.floor(s / 60)) + ":" + U.pad(s % 60) }
    // text for the bar: shown while a session exists
    readonly property string barText: phase === "idle" ? "" : (phase === "focus" ? "󰔟 " : "󰾨 ") + clock(remaining) + (running ? "" : " ⏸")

    function start() {
        if (phase === "idle") { phase = "focus"; leftMs = phaseMs("focus") }
        endMs = Date.now() + leftMs; running = true; applyDnd()
    }
    function pause() { if (!running) return; leftMs = Math.max(0, endMs - Date.now()); running = false; applyDnd() }
    function toggle() { if (running) pause(); else start() }
    function reset() { flushLog(); phase = "idle"; running = false; cycle = 0; leftMs = 0; applyDnd() }
    function skip() {
        if (phase === "idle") return
        finishPhase(false)
    }
    function finishPhase(natural) {
        flushLog()
        var was = phase
        if (was === "focus") {
            cycle++
            if (natural) school.notify("Focus session done", "Nice work — take a " + (cycle % cfg.every === 0 ? cfg.long : cfg.brk) + " minute break.")
            phase = (cycle % cfg.every === 0) ? "long" : "break"
            if (phase === "long") cycle = 0
        } else {
            if (natural) school.notify("Break over", "Ready for the next focus session?")
            phase = "focus"
        }
        leftMs = phaseMs(phase)
        // breaks start by themselves; the next focus session waits for you
        if (phase === "focus") { running = false } else { endMs = Date.now() + leftMs; running = true }
        applyDnd()
    }
    Timer {
        interval: 1000; repeat: true; running: root.running || root.modeOn
        onTriggered: {
            root.now = Date.now()
            if (root.running) {
                if (root.phase === "focus") root.accumMs += 1000
                if (root.now >= root.endMs) root.finishPhase(true)
            }
            if (root.modeOn && root.modeUntil > 0 && root.now >= root.modeUntil) { root.endMode(); school.notify("Focus mode finished", "Notifications and apps are back.") }
        }
    }
    // what you are studying right now (a course code, or "" for general): focus time is logged against it
    readonly property string course: school.pref("studyCourse", "")
    function setCourse(c) { school.setPref("studyCourse", c) }
    // the assignment you are working on: its time is added up so the Due list can learn how long things take you
    readonly property string task: school.pref("studyTask", "")
    readonly property var taskItem: task === "" ? null : (school.due.find(a => String(a.id) === task) || null)
    function setTask(id) { flushLog(); school.setPref("studyTask", id) }
    function startTask(a) {
        flushLog()
        school.setPref("studyTask", String(a.id)); school.setPref("studyCourse", a.course)
        if (!running) start()
    }
    function flushLog() {
        var min = Math.round(accumMs / 60000)
        accumMs = 0
        if (min <= 0) return
        var log = Object.assign({}, school.pref("focusLog", {}))
        var k = U.isoDate(new Date())
        var day = Object.assign({}, dayObj(log[k]))
        day[course] = (day[course] || 0) + min
        log[k] = day
        if (task !== "") {
            var tl = Object.assign({}, school.pref("taskLog", {}))
            tl[task] = (tl[task] || 0) + min
            school.setPref("taskLog", tl)
        }
        // keep about three months
        var keys = Object.keys(log).sort(); while (keys.length > 100) delete log[keys.shift()]
        school.setPref("focusLog", log)
    }
    // older logs stored one number per day; newer ones { course: minutes }
    function dayObj(v) { return v === undefined ? {} : (typeof v === "number" ? { "": v } : v) }
    function dayTotal(v) { var o = dayObj(v), sum = 0; Object.keys(o).forEach(function (c) { sum += o[c] }); return sum }
    readonly property var log: school.pref("focusLog", {})
    readonly property int todayMinutes: dayTotal(log[U.isoDate(new Date(now))]) + Math.round(accumMs / 60000)
    readonly property int weekMinutes: {
        var sum = 0
        for (var i = 0; i < 7; i++) sum += dayTotal(log[U.isoDate(new Date(now - i * 86400000))])
        return sum + Math.round(accumMs / 60000)
    }
    // minutes per day for the last 7 days, oldest first (for the little chart)
    readonly property var week: {
        var out = []
        for (var i = 6; i >= 0; i--) { var d = new Date(now - i * 86400000); out.push({ day: ["S", "M", "T", "W", "T", "F", "S"][d.getDay()], min: dayTotal(log[U.isoDate(d)]) + (i === 0 ? Math.round(accumMs / 60000) : 0) }) }
        return out
    }
    // this week split by course: [{ course, min }] biggest first
    readonly property var byCourse: {
        var sums = {}
        for (var i = 0; i < 7; i++) {
            var o = dayObj(log[U.isoDate(new Date(now - i * 86400000))])
            Object.keys(o).forEach(function (c) { sums[c] = (sums[c] || 0) + o[c] })
        }
        var live = Math.round(accumMs / 60000); if (live > 0) sums[course] = (sums[course] || 0) + live
        return Object.keys(sums).map(function (c) { return { course: c, min: sums[c] } }).filter(function (x) { return x.min > 0 }).sort(function (a, b) { return b.min - a.min })
    }

    // ══ focus mode ═══════════════════════════════════════
    property bool modeOn: false
    property real modeUntil: 0
    property var  blocked: []
    property string endError: ""
    property bool   checking: false
    property string pendingPw: ""
    Job { id: appsJob; script: root.scripts }
    Job { id: killJob; script: root.scripts }

    function startMode(minutes) {
        minutes = Math.max(5, Math.min(240, minutes))        // never open-ended: the worst case is that it times out
        modeUntil = Date.now() + minutes * 60000
        modeOn = true; endError = ""
        school.setPref("modeUntil", modeUntil)
        appsJob.go(["apps"], r => { if (Array.isArray(r)) blocked = r; killNow() })
        applyDnd()
    }
    function endMode() {
        modeOn = false; modeUntil = 0
        school.setPref("modeUntil", 0)
        applyDnd()
    }
    function killNow() { if (modeOn && blocked.length) killJob.go(["kill"].concat(blocked), r => {}) }
    Timer { interval: 5000; repeat: true; running: root.modeOn; onTriggered: root.killNow() }
    // is this launcher entry one of the blocked programs?
    function isBlocked(app) {
        if (!modeOn || !app) return false
        var hay = ((app.name || "") + " " + (app.exec || "")).toLowerCase()
        return blocked.some(b => b.length > 2 && hay.indexOf(b.toLowerCase()) >= 0)
    }
    // ending early: the password is checked by the system (focus.sh verify), and is never kept
    Process {
        id: verifyProc
        stdinEnabled: true
        onStarted: { write(root.pendingPw + "\n"); root.pendingPw = "" }
        stdout: StdioCollector {
            onStreamFinished: {
                root.checking = false
                var r = null; try { r = JSON.parse(text) } catch (e) {}
                if (r && r.ok) { root.endError = ""; root.endMode() }
                else root.endError = r && r.error ? r.error : "could not check the password"
            }
        }
    }
    function endWithPassword(pw) {
        if (checking || !pw) return
        checking = true; endError = ""; pendingPw = pw
        verifyProc.command = ["bash", scripts, "verify"]
        verifyProc.running = true
    }
    Connections {
        target: school
        function onPrefsLoadedChanged() {
            if (!school.prefsLoaded) return
            var until = school.pref("modeUntil", 0)
            if (until > Date.now()) { modeUntil = until; modeOn = true; appsJob.go(["apps"], r => { if (Array.isArray(r)) blocked = r; killNow() }); applyDnd() }
        }
    }

    // Do Not Disturb follows focus mode and the focus phase of the timer, then goes back to what it was
    property bool weSetDnd: false
    property bool dndBefore: false
    function applyDnd() {
        var want = modeOn || (cfg.autoDnd && phase === "focus" && running)
        if (want && !weSetDnd) { dndBefore = bar.dndOn; bar.dndOn = true; weSetDnd = true }
        else if (!want && weSetDnd) { bar.dndOn = dndBefore; weSetDnd = false }
    }

    // ══ nudges ═══════════════════════════════════════════
    readonly property var nudges: ({
        eye:     { label: "Eyes", sub: "every 20 min · look 20 ft away for 20 s", every: 20, title: "Rest your eyes", body: "Look at something 20 feet away for 20 seconds." },
        water:   { label: "Water", sub: "every hour", every: 60, title: "Drink some water", body: "A glass of water now beats a headache later." },
        stretch: { label: "Stretch", sub: "every 90 min", every: 90, title: "Stand up and stretch", body: "Walk around for a minute and roll your shoulders." }
    })
    readonly property var nudgeOn: school.pref("nudges", { eye: true, water: false, stretch: false })
    function setNudge(k, v) { var n = Object.assign({}, nudgeOn); n[k] = v; school.setPref("nudges", n) }
    property var lastNudge: ({ eye: Date.now(), water: Date.now(), stretch: Date.now() })
    Timer {
        interval: 60000; repeat: true; running: true
        onTriggered: {
            var t = Date.now(), l = Object.assign({}, root.lastNudge)
            Object.keys(root.nudges).forEach(function (k) {
                if (!root.nudgeOn[k]) { l[k] = t; return }
                if (t - l[k] >= root.nudges[k].every * 60000) { l[k] = t; root.school.notify(root.nudges[k].title, root.nudges[k].body) }
            })
            root.lastNudge = l
        }
    }
}
