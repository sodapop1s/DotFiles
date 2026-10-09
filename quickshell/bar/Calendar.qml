import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Calendar (read-only Proton Calendar feed via "Share via link") plus timer / stopwatch / alarms.
// Events come from calendar.sh (ical.py); the feed link is stored in ~/.config/qs-bar/calendar-url.
Item {
    id: root
    required property var bar
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.blue
    readonly property int weekStart: 0              // 0 = Sunday first, 1 = Monday first
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property var dayNames: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    property string tab: "calendar"                 // calendar | timers
    property date   month: new Date(new Date().getFullYear(), new Date().getMonth(), 1)
    property date   selected: new Date()
    property var    events: []                      // occurrences in the visible grid
    property var    info: ({ hasUrl: false, cachedAt: 0, count: 0, name: "" })
    property bool   infoLoaded: false
    property bool   syncing: false
    property string status: ""
    property bool   statusErr: false
    property int    tick: 0

    function say(msg, err) { status = msg; statusErr = !!err; statusTimer.restart() }
    Timer { id: statusTimer; interval: 5000; onTriggered: root.status = "" }

    function pad(n) { return (n < 10 ? "0" : "") + n }
    function ymd(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) }
    function sameDay(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate() }
    function addDays(d, n) { var x = new Date(d.getFullYear(), d.getMonth(), d.getDate() + n); return x }

    // ── grid geometry ─────────────────────────────────────
    readonly property date gridStart: {
        var first = new Date(month.getFullYear(), month.getMonth(), 1)
        var offset = (first.getDay() - weekStart + 7) % 7
        return addDays(first, -offset)
    }
    readonly property var cells: {
        var out = []
        for (var i = 0; i < 42; i++) out.push(addDays(gridStart, i))
        return out
    }

    // ── data ──────────────────────────────────────────────
    Job { id: statusJob; script: Quickshell.shellPath("calendar.sh") }
    Job { id: syncJob;   script: Quickshell.shellPath("calendar.sh") }
    Job { id: eventsJob; script: Quickshell.shellPath("calendar.sh") }

    function loadEvents() {
        var from = ymd(gridStart), to = ymd(addDays(gridStart, 42))
        eventsJob.go(["events", from, to], r => {
            if (Array.isArray(r)) events = r
            else { events = []; if (r && r.error && r.error !== "not-synced") say(r.error, true) }
        })
    }
    function sync(force) {
        if (syncing) return
        syncing = true
        syncJob.go(["sync"], r => {
            syncing = false
            if (r && r.ok) { info = Object.assign({}, info, { cachedAt: Math.floor(Date.now() / 1000), count: r.count, name: r.name }); loadEvents(); if (force) say("calendar updated", false) }
            else if (r && r.error && r.error !== "no-url") say(r.error, true)
        })
    }
    function showTimers() { tab = "timers"; startTimer(5) }
    function showCalendar() { tab = "calendar" }
    function activate() {
        tick++
        statusJob.go(["status"], r => {
            if (r && r.error) { say(r.error, true); return }
            if (r) {
                info = r; infoLoaded = true
                if (!r.hasUrl) events = []
                if (r.hasUrl) {
                    loadEvents()
                    if (Date.now() / 1000 - r.cachedAt > 1800) sync(false)     // refresh when older than 30 minutes
                }
            }
        })
    }
    onMonthChanged: { if (info.hasUrl) loadEvents() }

    // events per day: "YYYY-MM-DD" -> [event...]
    readonly property var byDay: {
        var map = {}
        events.forEach(e => {
            var s = new Date(e.start), en = new Date(e.end)
            var d = new Date(s.getFullYear(), s.getMonth(), s.getDate())
            var last = e.allDay ? addDays(new Date(en.getFullYear(), en.getMonth(), en.getDate()), -1)
                                : (en.getHours() === 0 && en.getMinutes() === 0 && en > s ? addDays(new Date(en.getFullYear(), en.getMonth(), en.getDate()), -1)
                                                                                         : new Date(en.getFullYear(), en.getMonth(), en.getDate()))
            var n = 0
            while (d <= last && n++ < 60) { var k = ymd(d); (map[k] = map[k] || []).push(e); d = addDays(d, 1) }
        })
        return map
    }
    readonly property var agenda: {
        var list = (byDay[ymd(selected)] || []).slice()
        list.sort((a, b) => (b.allDay - a.allDay) || (a.start < b.start ? -1 : 1))
        return list
    }
    function timeText(e) {
        if (e.allDay) return "all day"
        var s = new Date(e.start), en = new Date(e.end)
        function t(d) { return pad(d.getHours()) + ":" + pad(d.getMinutes()) }
        return t(s) + (en > s ? " – " + t(en) : "")
    }
    function syncedText(_t) {
        if (!info.cachedAt) return "not synced"
        var m = Math.round((Date.now() / 1000 - info.cachedAt) / 60)
        return m < 2 ? "synced just now" : m < 90 ? "synced " + m + "m ago" : "synced " + Math.round(m / 60) + "h ago"
    }

    // ── linking a calendar ────────────────────────────────
    Process {
        id: linkProc
        stdout: StdioCollector {
            onStreamFinished: {
                var r = null
                try { r = JSON.parse(text) } catch(e) {}
                if (r && r.ok) { root.info = Object.assign({}, root.info, { hasUrl: true }); linkInput.text = ""; root.say("linked — downloading…", false); root.sync(true) }
                else root.say(r && r.error ? r.error : "could not save the link", true)
            }
        }
    }
    function linkUrl(u) {
        linkProc.environment = ({ QS_CAL_URL: u })
        linkProc.command = ["bash", "-c", "printf %s \"$QS_CAL_URL\" | bash '" + Quickshell.shellPath("calendar.sh") + "' seturl"]
        linkProc.running = true
    }
    Process { id: openProc; onExited: running = false }
    function open(u) { openProc.command = ["xdg-open", u]; openProc.running = true }

    // ══════════ Timers: timer, stopwatch, alarms ═════════
    // timer
    property real   timerEnd: 0                      // epoch ms when running
    property real   timerLeft: 0                     // ms left when paused / idle
    property real   timerTotal: 0
    readonly property bool timerRunning: timerEnd > 0
    // stopwatch
    property real   swStart: 0                       // epoch ms of the current run, 0 when stopped
    property real   swAccum: 0                       // ms from earlier runs
    property var    laps: []
    readonly property bool swRunning: swStart > 0
    // alarms: { time: "HH:MM", label, on }
    property var    alarms: []
    property string lastAlarmKey: ""
    property real   now: Date.now()

    Timer { interval: 250; repeat: true; running: root.timerRunning || root.swRunning || root.visible; onTriggered: { root.now = Date.now(); root.checkTimer() } }
    Timer { interval: 15000; repeat: true; running: true; onTriggered: root.checkAlarms() }

    function remaining() { return timerRunning ? Math.max(0, timerEnd - now) : timerLeft }
    function fmtClock(ms, tenths) {
        var s = Math.max(0, Math.floor(ms / 1000)), h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60
        var base = (h > 0 ? h + ":" + pad(m) : m) + ":" + pad(sec)
        return tenths ? base + "." + Math.floor((ms % 1000) / 100) : base
    }
    function startTimer(minutes) {
        timerTotal = minutes * 60000; timerLeft = timerTotal; timerEnd = Date.now() + timerTotal; syncBarTimer()
    }
    function toggleTimer() {
        if (timerRunning) { timerLeft = Math.max(0, timerEnd - Date.now()); timerEnd = 0 }
        else if (timerLeft > 0) { timerEnd = Date.now() + timerLeft }
        syncBarTimer()
    }
    function resetTimer() { timerEnd = 0; timerLeft = 0; timerTotal = 0; syncBarTimer() }
    function checkTimer() {
        if (timerRunning && Date.now() >= timerEnd) {
            timerEnd = 0; timerLeft = 0; syncBarTimer()
            notify("Timer finished", timerTotal >= 60000 ? Math.round(timerTotal / 60000) + " minute timer is done" : "Time is up", true)
        }
        syncBarTimer()
    }
    // the bar's clock shows a running timer
    function syncBarTimer() { root.bar.timerText = timerRunning ? "󱎫 " + fmtClock(Math.max(0, timerEnd - Date.now())) : (timerLeft > 0 ? "󱎫 " + fmtClock(timerLeft) + " ⏸" : "") }

    function swElapsed() { return swAccum + (swRunning ? now - swStart : 0) }
    function toggleSw() {
        if (swRunning) { swAccum += Date.now() - swStart; swStart = 0 } else { swStart = Date.now() }
    }
    function lapSw() { if (swRunning || swAccum > 0) { var l = laps.slice(); l.unshift(swElapsed()); laps = l } }
    function resetSw() { swStart = 0; swAccum = 0; laps = [] }

    FileView {
        id: alarmFile
        path: Quickshell.env("HOME") + "/.local/state/qs-bar-alarms.json"
        onLoaded: { try { var a = JSON.parse(alarmFile.text()); if (Array.isArray(a)) root.alarms = a } catch(e) {} }
    }
    function saveAlarms() { alarmFile.setText(JSON.stringify(alarms)) }
    function addAlarm(t, label) {
        if (!/^([01]?\d|2[0-3]):[0-5]\d$/.test(t)) { say("time should look like 07:30", true); return false }
        var parts = t.split(":")
        alarms = alarms.concat([{ time: pad(+parts[0]) + ":" + parts[1], label: label, on: true }])
        saveAlarms(); return true
    }
    function checkAlarms() {
        var d = new Date(), hm = pad(d.getHours()) + ":" + pad(d.getMinutes()), key = ymd(d) + " " + hm
        if (key === lastAlarmKey) return
        var hit = alarms.filter(a => a.on && a.time === hm)
        if (hit.length) { lastAlarmKey = key; notify("Alarm  " + hm, hit.map(a => a.label || "Alarm").join(", "), true) }
    }
    Process { id: notifyProc; onExited: running = false }
    function notify(title, body, urgent) {
        notifyProc.command = ["notify-send", "-a", "Clock", "-u", urgent ? "critical" : "normal", title, body]
        notifyProc.running = true
    }

    // ══════════ UI ═══════════════════════════════════════
    AppHeader {
        id: head
        bar: root.bar; icon: "󰃭"; title: "Calendar"; accent: root.accent
        anchors { top: parent.top; left: parent.left; right: parent.right }
        onBack: root.bar.hubView = "main"
        Text {
            visible: root.status.length > 0
            text: root.status; color: root.statusErr ? Theme.red : Theme.green
            elide: Text.ElideRight; width: Math.min(implicitWidth, 230)
            font { family: root.font; pixelSize: 11 }
        }
        Text {
            visible: root.info.hasUrl && root.status.length === 0 && root.tab === "calendar"
            text: root.syncing ? "syncing…" : root.syncedText(root.tick)
            color: Theme.dim; font { family: root.font; pixelSize: 10 }
        }
        HeaderButton {
            visible: root.info.hasUrl && root.tab === "calendar"
            text: "󰑐  sync"; accent: root.accent; active: root.syncing
            onClicked: root.sync(true)
        }
    }
    Item { id: sep; anchors.top: head.bottom; height: 0 }

    // tab switch
    Row {
        id: tabs
        anchors { top: sep.bottom; topMargin: 10; horizontalCenter: parent.horizontalCenter }
        spacing: 6
        Repeater {
            model: [["calendar", "󰃭  Calendar"], ["timers", "󱎫  Timers"]]
            delegate: Rectangle {
                id: tb
                required property var modelData
                width: 150; height: 28; radius: 9
                color: root.tab === modelData[0] ? Qt.alpha(Theme.blue, 0.16) : "transparent"
                border { color: root.tab === modelData[0] ? Qt.alpha(Theme.blue, 0.4) : Theme.cardBorder; width: 1 }
                Text { anchors.centerIn: parent; text: tb.modelData[1]; color: root.tab === tb.modelData[0] ? root.accent : Theme.dim; font { family: root.font; pixelSize: 11 } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.tab = tb.modelData[0] }
            }
        }
    }

    // ───────────── calendar tab ─────────────
    Item {
        id: calTab
        visible: root.tab === "calendar"
        anchors { top: tabs.bottom; topMargin: 10; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 12 }

        // month navigation
        RowLayout {
            id: monthNav
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 30; spacing: 8
            Text { text: root.monthNames[root.month.getMonth()] + " " + root.month.getFullYear(); color: Theme.text; Layout.fillWidth: true
                   font { family: root.font; pixelSize: 15; bold: true } }
            Rectangle {
                Layout.preferredWidth: 54; Layout.preferredHeight: 24; radius: 8; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                Text { anchors.centerIn: parent; text: "Today"; color: Theme.text; font { family: root.font; pixelSize: 10 } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { var n = new Date(); root.month = new Date(n.getFullYear(), n.getMonth(), 1); root.selected = n } }
            }
            Text { text: "󰅁"; color: Theme.dim; font { family: root.font; pixelSize: 18 }
                   MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor
                               onClicked: root.month = new Date(root.month.getFullYear(), root.month.getMonth() - 1, 1) } }
            Text { text: "󰅂"; color: Theme.dim; font { family: root.font; pixelSize: 18 }
                   MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor
                               onClicked: root.month = new Date(root.month.getFullYear(), root.month.getMonth() + 1, 1) } }
        }

        // weekday header
        Row {
            id: weekHead
            anchors { top: monthNav.bottom; topMargin: 6; left: parent.left; right: parent.right }
            Repeater {
                model: 7
                delegate: Text {
                    required property int index
                    width: weekHead.width / 7; horizontalAlignment: Text.AlignHCenter
                    text: root.dayNames[(index + root.weekStart) % 7]; color: Theme.dim
                    font { family: root.font; pixelSize: 10 }
                }
            }
        }

        // day grid
        Grid {
            id: dayGrid
            anchors { top: weekHead.bottom; topMargin: 4; left: parent.left; right: parent.right }
            columns: 7
            readonly property real cw: width / 7
            Repeater {
                model: root.cells
                delegate: Item {
                    id: dc
                    required property var modelData
                    readonly property bool inMonth: modelData.getMonth() === root.month.getMonth()
                    readonly property bool isToday: root.sameDay(modelData, new Date())
                    readonly property bool isSel: root.sameDay(modelData, root.selected)
                    readonly property var evs: root.byDay[root.ymd(modelData)] || []
                    width: dayGrid.cw; height: 40
                    Rectangle {
                        anchors { fill: parent; margins: 2 }
                        radius: 10
                        color: dc.isSel ? Qt.alpha(Theme.blue, 0.20) : (dh.hovered ? Qt.alpha(Theme.mauve, 0.10) : "transparent")
                        border { color: dc.isSel ? root.accent : "transparent"; width: 1 }
                        Rectangle {
                            visible: dc.isToday
                            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 3 }
                            width: 22; height: 22; radius: 11; color: root.accent
                        }
                        Text {
                            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 5 }
                            text: dc.modelData.getDate()
                            color: dc.isToday ? Theme.crust : (dc.inMonth ? Theme.text : Theme.dim)
                            font { family: root.font; pixelSize: 12; bold: dc.isToday }
                            opacity: dc.inMonth || dc.isToday ? 1 : 0.5
                        }
                        Row {
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 4 }
                            spacing: 3
                            Repeater {
                                model: Math.min(3, dc.evs.length)
                                delegate: Rectangle { width: 5; height: 5; radius: 2.5; color: root.accent; opacity: dc.inMonth ? 1 : 0.5 }
                            }
                        }
                        HoverHandler { id: dh; cursorShape: Qt.PointingHandCursor }
                        MouseArea { anchors.fill: parent; onClicked: { root.selected = dc.modelData; if (!dc.inMonth) root.month = new Date(dc.modelData.getFullYear(), dc.modelData.getMonth(), 1) } }
                    }
                }
            }
        }

        // agenda for the selected day
        Text {
            id: agendaTitle
            visible: root.info.hasUrl
            anchors { top: dayGrid.bottom; topMargin: 8; left: parent.left }
            text: root.dayNames[root.selected.getDay()] + ", " + root.monthNames[root.selected.getMonth()].slice(0, 3) + " " + root.selected.getDate()
            color: Theme.subtext; font { family: root.font; pixelSize: 11; bold: true }
        }
        ListView {
            id: agendaList
            visible: root.info.hasUrl
            anchors { top: agendaTitle.bottom; topMargin: 6; left: parent.left; right: parent.right; bottom: parent.bottom }
            clip: true; spacing: 4; boundsBehavior: Flickable.StopAtBounds
            model: root.agenda
            delegate: Rectangle {
                id: ag
                required property var modelData
                width: agendaList.width; height: Math.max(44, agCol.implicitHeight + 14); radius: 10
                color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                Rectangle { width: 3; radius: 1.5; color: root.accent; anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 8 } }
                ColumnLayout {
                    id: agCol
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 20; rightMargin: 12 }
                    spacing: 1
                    Text { text: ag.modelData.title; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true
                           textFormat: Text.PlainText; font { family: root.font; pixelSize: 12; bold: true } }
                    Text { text: root.timeText(ag.modelData) + (ag.modelData.location ? "  ·  " + ag.modelData.location : ""); color: Theme.dim
                           elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 10 } }
                }
            }
            Text {
                visible: agendaList.count === 0
                anchors.centerIn: parent
                text: root.infoLoaded && root.info.cachedAt === 0 ? "Waiting for the first sync…" : "Nothing planned"
                color: Theme.dim; font { family: root.font; pixelSize: 11 }
            }
        }

        // not linked yet
        Rectangle {
            visible: root.infoLoaded && !root.info.hasUrl
            anchors { top: dayGrid.bottom; topMargin: 10; left: parent.left; right: parent.right; bottom: parent.bottom }
            radius: 12; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
            ColumnLayout {
                anchors { fill: parent; margins: 14 }
                spacing: 8
                Text { text: "Show your Proton Calendar here"; color: Theme.text; font { family: root.font; pixelSize: 12; bold: true } }
                Text {
                    text: "In Proton Calendar: Settings → your calendar → Share via link → create a link, and paste it below. It is read-only and kept in a private file (~/.config/qs-bar/calendar-url)."
                    color: Theme.dim; wrapMode: Text.Wrap; Layout.fillWidth: true; font { family: root.font; pixelSize: 10 }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 32; radius: 9
                        color: Qt.alpha(Theme.mauve, 0.07)
                        border { color: linkInput.activeFocus ? root.accent : Theme.sep; width: 1 }
                        TextInput {
                            id: linkInput
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            verticalAlignment: TextInput.AlignVCenter
                            color: Theme.text; clip: true; echoMode: TextInput.Password
                            font { family: root.font; pixelSize: 11 }
                            Keys.onReturnPressed: { if (text.trim().length) root.linkUrl(text.trim()) }
                            Text { visible: linkInput.text.length === 0; anchors.verticalCenter: parent.verticalCenter
                                   text: "paste the calendar link"; color: Theme.dim; font { family: root.font; pixelSize: 11 } }
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 64; Layout.preferredHeight: 32; radius: 9; color: root.accent
                        Text { anchors.centerIn: parent; text: "Link"; color: Theme.crust; font { family: root.font; pixelSize: 11; bold: true } }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (linkInput.text.trim().length) root.linkUrl(linkInput.text.trim()) } }
                    }
                }
                Text {
                    text: "󰖟 open Proton Calendar"; color: root.accent; font { family: root.font; pixelSize: 10 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.bar.hubOpen = false; root.open("https://calendar.proton.me") } }
                }
                Item { Layout.fillHeight: true }
            }
        }
    }

    // ───────────── timers tab ─────────────
    Flickable {
        id: timersTab
        visible: root.tab === "timers"
        anchors { top: tabs.bottom; topMargin: 10; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 12 }
        clip: true; contentHeight: tcol.implicitHeight; boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: tcol
            width: timersTab.width; spacing: 10

            // timer
            Rectangle {
                Layout.fillWidth: true; implicitHeight: timerCol.implicitHeight + 24; radius: 14
                color: Theme.card; border { color: root.timerRunning ? root.accent : Theme.cardBorder; width: 1 }
                ColumnLayout {
                    id: timerCol
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
                    spacing: 10
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "󱎫  Timer"; color: Theme.text; font { family: root.font; pixelSize: 12; bold: true } }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.fmtClock(root.remaining() + (root.timerRunning ? 999 : 0), false)
                            color: root.timerRunning ? root.accent : Theme.text
                            font { family: root.font; pixelSize: 28; bold: true }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        Repeater {
                            model: [1, 5, 10, 15, 25, 45]
                            delegate: Rectangle {
                                required property int modelData
                                Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.preferredHeight: 30; radius: 9
                                color: pa.containsMouse ? Qt.alpha(Theme.blue, 0.18) : Qt.alpha(Theme.mauve, 0.07)
                                border { color: Theme.cardBorder; width: 1 }
                                Text { anchors.centerIn: parent; text: modelData + "m"; color: Theme.text; font { family: root.font; pixelSize: 11 } }
                                MouseArea { id: pa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.startTimer(modelData) }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Rectangle {
                            Layout.preferredWidth: 90; Layout.preferredHeight: 30; radius: 9
                            color: Qt.alpha(Theme.mauve, 0.07); border { color: customMin.activeFocus ? root.accent : Theme.sep; width: 1 }
                            TextInput {
                                id: customMin
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.text; clip: true; inputMethodHints: Qt.ImhDigitsOnly
                                font { family: root.font; pixelSize: 11 }
                                Keys.onReturnPressed: { var v = parseFloat(text); if (v > 0) { root.startTimer(v); text = "" } }
                                Text { visible: customMin.text.length === 0; anchors.verticalCenter: parent.verticalCenter; text: "minutes"; color: Theme.dim; font { family: root.font; pixelSize: 11 } }
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            visible: root.timerLeft > 0 || root.timerRunning
                            Layout.preferredWidth: 90; Layout.preferredHeight: 30; radius: 9
                            color: Qt.alpha(Theme.blue, 0.2); border { color: root.accent; width: 1 }
                            Text { anchors.centerIn: parent; text: root.timerRunning ? "󰏤 Pause" : "󰐊 Resume"; color: root.accent; font { family: root.font; pixelSize: 11; bold: true } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleTimer() }
                        }
                        Rectangle {
                            visible: root.timerLeft > 0 || root.timerRunning
                            Layout.preferredWidth: 70; Layout.preferredHeight: 30; radius: 9
                            color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                            Text { anchors.centerIn: parent; text: "Reset"; color: Theme.text; font { family: root.font; pixelSize: 11 } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.resetTimer() }
                        }
                    }
                }
            }

            // stopwatch
            Rectangle {
                Layout.fillWidth: true; implicitHeight: swCol.implicitHeight + 24; radius: 14
                color: Theme.card; border { color: root.swRunning ? Theme.green : Theme.cardBorder; width: 1 }
                ColumnLayout {
                    id: swCol
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text { text: "󱦟  Stopwatch"; color: Theme.text; font { family: root.font; pixelSize: 12; bold: true } }
                        Item { Layout.fillWidth: true }
                        Text { text: root.fmtClock(root.swElapsed(), true); color: root.swRunning ? Theme.green : Theme.text; font { family: root.font; pixelSize: 24; bold: true } }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 30; radius: 9
                            color: root.swRunning ? Qt.alpha(Theme.red, 0.2) : Qt.alpha(Theme.green, 0.2)
                            border { color: root.swRunning ? Theme.red : Theme.green; width: 1 }
                            Text { anchors.centerIn: parent; text: root.swRunning ? "󰓛 Stop" : "󰐊 Start"; color: root.swRunning ? Theme.red : Theme.green; font { family: root.font; pixelSize: 11; bold: true } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggleSw() }
                        }
                        Rectangle {
                            Layout.preferredWidth: 80; Layout.preferredHeight: 30; radius: 9; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                            Text { anchors.centerIn: parent; text: "Lap"; color: Theme.text; font { family: root.font; pixelSize: 11 } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.lapSw() }
                        }
                        Rectangle {
                            Layout.preferredWidth: 80; Layout.preferredHeight: 30; radius: 9; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                            Text { anchors.centerIn: parent; text: "Reset"; color: Theme.text; font { family: root.font; pixelSize: 11 } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.resetSw() }
                        }
                    }
                    Repeater {
                        model: root.laps.slice(0, 4)
                        delegate: RowLayout {
                            required property int index
                            required property real modelData
                            Layout.fillWidth: true
                            Text { text: "Lap " + (root.laps.length - index); color: Theme.dim; font { family: root.font; pixelSize: 10 } }
                            Item { Layout.fillWidth: true }
                            Text { text: root.fmtClock(modelData, true); color: Theme.text; font { family: root.font; pixelSize: 11 } }
                        }
                    }
                }
            }

            // alarms
            Rectangle {
                Layout.fillWidth: true; implicitHeight: alCol.implicitHeight + 24; radius: 14
                color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                ColumnLayout {
                    id: alCol
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
                    spacing: 8
                    Text { text: "󰀠  Alarms"; color: Theme.text; font { family: root.font; pixelSize: 12; bold: true } }
                    Repeater {
                        model: root.alarms
                        delegate: RowLayout {
                            id: ar
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true; spacing: 10
                            Text { text: ar.modelData.time; color: ar.modelData.on ? Theme.text : Theme.dim; font { family: root.font; pixelSize: 16; bold: true } }
                            Text { text: ar.modelData.label || "Alarm"; color: Theme.dim; Layout.fillWidth: true; elide: Text.ElideRight; font { family: root.font; pixelSize: 11 } }
                            Rectangle {
                                Layout.preferredWidth: 34; Layout.preferredHeight: 18; radius: 9
                                color: ar.modelData.on ? root.accent : Qt.alpha(Theme.mauve, 0.16)
                                Rectangle { y: 2; x: ar.modelData.on ? parent.width - width - 2 : 2; width: 14; height: 14; radius: 7; color: ar.modelData.on ? Theme.crust : Theme.subtext }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: { root.alarms = root.alarms.map((a, i) => i === ar.index ? { time: a.time, label: a.label, on: !a.on } : a); root.saveAlarms() } }
                            }
                            Text { text: "󰆴"; color: Theme.dim; font { family: root.font; pixelSize: 14 }
                                   MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                                               onClicked: { root.alarms = root.alarms.filter((a, i) => i !== ar.index); root.saveAlarms() } } }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Rectangle {
                            Layout.preferredWidth: 70; Layout.preferredHeight: 30; radius: 9
                            color: Qt.alpha(Theme.mauve, 0.07); border { color: alTime.activeFocus ? root.accent : Theme.sep; width: 1 }
                            TextInput {
                                id: alTime
                                anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
                                verticalAlignment: TextInput.AlignVCenter; color: Theme.text; clip: true; maximumLength: 5
                                font { family: root.font; pixelSize: 11 }
                                KeyNavigation.tab: alLabel
                                Text { visible: alTime.text.length === 0; anchors.verticalCenter: parent.verticalCenter; text: "07:30"; color: Theme.dim; font { family: root.font; pixelSize: 11 } }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 30; radius: 9
                            color: Qt.alpha(Theme.mauve, 0.07); border { color: alLabel.activeFocus ? root.accent : Theme.sep; width: 1 }
                            TextInput {
                                id: alLabel
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                verticalAlignment: TextInput.AlignVCenter; color: Theme.text; clip: true
                                font { family: root.font; pixelSize: 11 }
                                Keys.onReturnPressed: { if (root.addAlarm(alTime.text.trim(), text.trim())) { alTime.text = ""; text = "" } }
                                Text { visible: alLabel.text.length === 0; anchors.verticalCenter: parent.verticalCenter; text: "label (optional)"; color: Theme.dim; font { family: root.font; pixelSize: 11 } }
                            }
                        }
                        Rectangle {
                            Layout.preferredWidth: 60; Layout.preferredHeight: 30; radius: 9; color: root.accent
                            Text { anchors.centerIn: parent; text: "Add"; color: Theme.crust; font { family: root.font; pixelSize: 11; bold: true } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: { if (root.addAlarm(alTime.text.trim(), alLabel.text.trim())) { alTime.text = ""; alLabel.text = "" } } }
                        }
                    }
                }
            }
        }
    }
}
