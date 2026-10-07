import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Bluetooth

PanelWindow {
    id: bar

    anchors { top: true; left: true; right: true }
    implicitHeight: centerIsland.height + 12
    color: "transparent"
    exclusiveZone: 44
    WlrLayershell.keyboardFocus: hubOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Process { id: lockProc; command: ["swaylock"]; onExited: running = false }
    Process { id: powerProc; onExited: running = false }

    // School tab: Canvas/calendar data, study timer, focus mode
    SchoolData  { id: schoolData; bar: bar }
    FocusState  { id: focusState; bar: bar; school: schoolData }
    property alias school: schoolData
    property alias studyFocus: focusState

    // Processes the hub pages (HomePage, WifiView, PowerView) drive
    property alias appLoadProc: appLoadProc
    property alias brightSetProc: brightSetProc
    property alias volSetProc: volSetProc
    property alias wifiToggleProc: wifiToggleProc
    property alias wifiConnectProc: wifiConnectProc
    property alias wifiScanProc: wifiScanProc
    property alias powerProc: powerProc
    property alias lockProc: lockProc

    // ── Hub ───────────────────────────────────────────────
    property bool hubOpen: false

    // notification store (history, unread count, clear) — provided by shell.qml
    property var store: null
    property int nowTick: 0
    property string timerText: ""        // running timer from the Calendar applet, shown by the clock

    // applets shown in the hub's Apps dock; id doubles as the hubView name
    readonly property var applets: [
        { id: "notifs",     label: "Alerts",     icon: "󰂜", accent: Theme.mauve },
        { id: "spotify",    label: "Spotify",    icon: "󰓇", accent: Theme.green },
        { id: "calendar",   label: "Calendar",   icon: "󰃭", accent: Theme.blue },
        { id: "wallpapers", label: "Wallpaper",  icon: "󰸉", accent: Theme.pink },
        { id: "clipboard",  label: "Clipboard",  icon: "󰅌", accent: Theme.yellow },
        { id: "mixer",      label: "Audio",      icon: "󰋋", accent: Theme.teal },
        { id: "shots",      label: "Capture",    icon: "󰄀", accent: Theme.peach },
        { id: "windows",    label: "Windows",    icon: "󰖯", accent: Theme.sky },
        { id: "theme",      label: "Theme",      icon: "󰏘", accent: Theme.mauve }
    ]
    readonly property var appletHeights: ({ calendar: 590, wallpapers: 520, clipboard: 540, mixer: 540, shots: 540, games: 650, school: 700, theme: 560, windows: 560 })
    function activateApplet(v) {
        var a = ({ calendar: calView, wallpapers: wallView, clipboard: clipView, mixer: mixView,
                   shots: shotView, games: gamesView, school: schoolView, windows: winView })[v]
        if (a && a.activate) a.activate()
    }

    // ── Spotify: shared state (browsing/controlling lives in Spotify.qml) ──
    readonly property string spScript: Quickshell.shellPath("spotify.sh")
    // preferences, persisted: { notify: bool, recents: { <playlist/album uri>: <timestamp> } }
    property var spPrefs: ({ notify: false, recents: {} })
    FileView {
        id: spPrefsFile
        path: Quickshell.env("HOME") + "/.local/state/qs-bar-spotify-prefs.json"
        onLoaded: { try { bar.spPrefs = Object.assign({ notify: false, recents: {} }, JSON.parse(spPrefsFile.text())) } catch(e) {} }
    }
    function saveSpPrefs() { spPrefsFile.setText(JSON.stringify(spPrefs)) }

    // "Artist – Title" popup when the song changes (off by default; DND silences it)
    property string _lastTrackKey: ""
    Process { id: spNotifyProc; onExited: running = false }
    function checkTrackNotify() {
        var key = (mediaTrackId || (mediaTitle + "|" + mediaArtist))
        if (spPrefs.notify && mediaStatus === "Playing" && _lastTrackKey !== "" && key !== _lastTrackKey
            && mediaTitle.length > 0 && !spNotifyProc.running) {
            spNotifyProc.command = ["notify-send", "-a", "Spotify", "-u", "low", mediaTitle, mediaArtist]
            spNotifyProc.running = true
        }
        _lastTrackKey = key
    }

    Timer { interval: 30000; repeat: true; running: bar.hubOpen; onTriggered: bar.nowTick++ }
    function ago(t, _tick) {
        var s = Math.max(0, Math.round((Date.now() - t) / 1000))
        if (s < 45)    return "now"
        if (s < 3600)  return Math.max(1, Math.round(s / 60)) + "m"
        if (s < 86400) return Math.round(s / 3600) + "h"
        return Math.round(s / 86400) + "d"
    }

    IpcHandler {
        target: "dnd"
        function toggle(): void { bar.dndOn = !bar.dndOn }
        function on(): void  { bar.dndOn = true }
        function off(): void { bar.dndOn = false }
    }

    IpcHandler {
        target: "hub"
        function toggle(): void { bar.hubOpen = !bar.hubOpen }
        function open(view: string): void {
            if (view === "minecraft" || view === "steam" || view === "lutris" || view === "ksp") { bar.hubView = "games"; bar.hubOpen = true; gamesView.setTab(view); return }
            if (view === "school" || view === "due" || view === "exams" || view === "grades" || view === "focus" || view === "notes" || view === "aero" || view === "money" || view === "tools" || view === "week" || view === "review" || view === "lectures") {
                bar.hubView = "school"; bar.hubOpen = true; schoolView.setTab(view === "school" ? "due" : view === "review" ? "week" : view === "lectures" ? "notes" : view); if (view === "lectures") schoolView.notes.pane = "lectures"; return
            }
            if (view === "capture") { bar.hubView = "school"; bar.hubOpen = true; schoolView.captureNote(); return }
            bar.hubView = view; bar.hubOpen = true
        }
        // press Enter in the search box (for testing and scripts): qs -c bar ipc call hub submit
        function submit(): void { hubContent.tryAsk() }
        function launch(name: string): void { bar.launchApp(bar.appList.find(x => x.name.toLowerCase() === name.toLowerCase())) }
        // run a method of an applet, e.g. `hub applet minecraft toggleMenu` (handy for testing)
        function applet(view: string, action: string): void {
            var launcher = (view === "minecraft" || view === "steam" || view === "lutris" || view === "ksp")
            if (view === "school") { bar.hubView = "school"; bar.hubOpen = true; schoolView.activate(); if (schoolView[action]) schoolView[action](); return }
            bar.hubView = launcher ? "games" : view; bar.hubOpen = true
            if (launcher) gamesView.setTab(view)
            var m = ({ calendar: calView, wallpapers: wallView, clipboard: clipView, mixer: mixView, shots: shotView, games: gamesView, minecraft: gamesView.mc, steam: gamesView.steam, lutris: gamesView.lutris, ksp: gamesView.ksp })[view]
            if (m && m[action]) m[action]()
        }
        function spotify(tab: string, query: string): void {
            bar.hubView = "spotify"; bar.hubOpen = true
            if (tab.startsWith("page:")) {      // e.g. page:playlist:<id> (for testing)
                var p = tab.split(":")
                spView.openPage({ kind: p[1], id: p[2], uri: "spotify:" + p[1] + ":" + p[2], name: query || "Page" })
                return
            }
            spView.setTab(tab)
            if (query.length > 0) spView.setQuery(query)
        }
        function search(q: string): void { bar.hubView = "main"; bar.hubOpen = true; hubContent.searchInput.text = q }
    }

    // ── Niri workspaces + focused window ─────────────────
    property var    workspaces:   []
    property string focusedTitle: ""

    Process {
        id: niriWsProc
        command: ["niri", "msg", "-j", "workspaces"]
        property string buf: ""
        stdout: SplitParser { onRead: data => { niriWsProc.buf += data } }
        onExited: (code) => {
            if (code === 0 && buf.length > 0) { try { bar.workspaces = JSON.parse(buf) } catch(e) {} }
            buf = ""; running = false
        }
    }

    Process {
        id: niriWinProc
        command: ["niri", "msg", "-j", "focused-window"]
        property string buf: ""
        stdout: SplitParser { onRead: data => { niriWinProc.buf += data } }
        onExited: (code) => {
            if (code === 0) {
                try {
                    var w = JSON.parse(buf)
                    bar.focusedTitle = (w && (w.title || w.app_id)) ? (w.title || w.app_id) : ""
                } catch(e) { bar.focusedTitle = "" }
            }
            buf = ""; running = false
        }
    }

    Timer {
        interval: 500; repeat: true; running: true
        onTriggered: {
            if (!niriWsProc.running) niriWsProc.running = true
            if (!niriWinProc.running) niriWinProc.running = true
        }
    }

    Process {
        id: wsActionProc
        function focus(idx) { command = ["niri", "msg", "action", "focus-workspace", "--index", idx.toString()]; running = true }
        onExited: running = false
    }

    // ── Stats ─────────────────────────────────────────────
    property int    cpuUsage:   0
    property int    memPercent: 0
    property int    cpuTemp:    0
    property int    batPct:     0
    property string batStatus:  "Unknown"
    // The BIOS stops charging at this percent, so 80% is a "full" battery: icons and bars scale to it
    readonly property int    batCap:      80
    readonly property int    batLevel:    Math.min(100, Math.round(batPct * 100 / batCap))
    readonly property bool   batCharging: batStatus === "Charging"
    readonly property bool   batHeld:     batPct >= batCap - 2 && (batStatus === "Full" || batStatus === "Not charging")   // plugged in, sitting at the cap
    function batIcon(): string {
        if (batCharging) return "󰂄"
        if (batHeld) return "󰚥"
        var l = batLevel
        return l > 90 ? "󰁹" : l > 70 ? "󰂂" : l > 50 ? "󰂀" : l > 30 ? "󰁾" : l > 15 ? "󰁻" : "󰂎"
    }
    property var    _cpuPrev:   null

    // ── Low-battery warnings (20% / 10% / 5%, once per discharge) ──
    property int batWarned: 100
    Process { id: batNotifyProc; onExited: running = false }
    function warnBattery(level, pct) {
        if (batNotifyProc.running) return
        batNotifyProc.command = ["notify-send", "-a", "Battery", "-u", level <= 10 ? "critical" : "normal",
            level <= 5 ? "Battery critically low" : "Battery low",
            pct + "% remaining — plug in soon"]
        batNotifyProc.running = true
    }
    function checkBattery() {
        if (batPct > 25 || batStatus === "Charging" || batStatus === "Full") { batWarned = 100; return }
        if (batStatus !== "Discharging") return
        var levels = [5, 10, 20]
        for (var i = 0; i < levels.length; i++) {
            if (batPct <= levels[i]) {
                if (levels[i] < batWarned) { batWarned = levels[i]; warnBattery(levels[i], batPct) }
                return
            }
        }
    }
    // dev aid: render only the hub card (never the rest of the screen) to a PNG
    IpcHandler {
        target: "snap"
        function hub(path: string): void { centerIsland.grabToImage(function(r) { r.saveToFile(path) }) }
    }

    IpcHandler {
        target: "power"
        function warn(level: int): void { bar.warnBattery(level, level) }
    }

    Process {
        id: statsProc
        command: ["bash", "-c",
            "awk 'NR==1{print \"cpu\",$2,$3,$4,$5,$6,$7,$8}' /proc/stat; " +
            "awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{print \"mem\",t,a}' /proc/meminfo; " +
            "printf 'temp %s\\n' $(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0); " +
            "printf 'bat %s %s\\n' $(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null || echo -1) $(cat /sys/class/power_supply/BAT1/status 2>/dev/null || echo Unknown)"
        ]
        property string buf: ""
        stdout: SplitParser { onRead: data => { statsProc.buf += data + "\n" } }
        onExited: (code) => {
            if (code === 0) {
                buf.split("\n").forEach(line => {
                    var p = line.trim().split(/\s+/)
                    if (p[0] === "cpu" && p.length >= 8) {
                        var u = parseInt(p[1]), ni = parseInt(p[2]), s = parseInt(p[3]),
                            id = parseInt(p[4]), io = parseInt(p[5]), ir = parseInt(p[6]), si = parseInt(p[7])
                        var total = u + ni + s + id + io + ir + si
                        if (bar._cpuPrev) {
                            var dT = total - bar._cpuPrev.total
                            var dI = id - bar._cpuPrev.idle
                            bar.cpuUsage = dT > 0 ? Math.round((1 - dI/dT) * 100) : 0
                        }
                        bar._cpuPrev = { total: total, idle: id }
                    } else if (p[0] === "mem" && p.length >= 3) {
                        var tot = parseInt(p[1]), avail = parseInt(p[2])
                        bar.memPercent = tot > 0 ? Math.round((1 - avail/tot) * 100) : 0
                    } else if (p[0] === "temp" && p.length >= 2) {
                        bar.cpuTemp = Math.round(parseInt(p[1]) / 1000)
                    } else if (p[0] === "bat" && p.length >= 3) {
                        var pct = parseInt(p[1])
                        if (pct >= 0) bar.batPct = pct
                        bar.batStatus = p[2]
                        bar.checkBattery()
                    }
                })
            }
            buf = ""; running = false
        }
    }

    Timer { interval: 2000; repeat: true; running: true; triggeredOnStart: true; onTriggered: { if (!statsProc.running) statsProc.running = true } }

    // ── Network ───────────────────────────────────────────
    property int netSignal: -1
    property string wifiSsid: ""

    Process {
        id: netProc
        command: ["bash", "-c", "nmcli --escape no -t -f active,ssid,signal dev wifi 2>/dev/null | grep '^yes' | head -1"]
        property bool got: false
        stdout: SplitParser { onRead: data => {
            var p = data.trim().split(":")
            if (p.length >= 3) { bar.netSignal = parseInt(p[p.length - 1]); bar.wifiSsid = p.slice(1, p.length - 1).join(":"); netProc.got = true }
        } }
        onStarted: got = false
        onExited: { if (!got) { bar.netSignal = -1; bar.wifiSsid = "" } running = false }
    }

    Timer { interval: 10000; repeat: true; running: true; triggeredOnStart: true; onTriggered: { if (!netProc.running) netProc.running = true } }

    // ── Weather ───────────────────────────────────────────
    property string weatherStr: "…"

    Process {
        id: weatherProc
        command: ["bash", "-c", "curl -sf --max-time 5 'https://wttr.in/?format=%c+%f' || echo '? --°F'"]
        stdout: SplitParser { onRead: data => { var t = data.trim(); if (t.length > 0) bar.weatherStr = t } }
        onExited: running = false
    }

    Timer { interval: 3600000; repeat: true; running: true; triggeredOnStart: true; onTriggered: { if (!weatherProc.running) weatherProc.running = true } }

    // ── Volume (wpctl) ────────────────────────────────────
    property int  volPct:   0
    property bool volMuted: false

    Process {
        id: volProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                var m = data.trim().match(/Volume:\s*([\d.]+)(\s+\[MUTED\])?/)
                if (m) { bar.volPct = Math.round(parseFloat(m[1]) * 100); bar.volMuted = m[2] !== undefined }
            }
        }
        onExited: running = false
    }

    Timer { interval: 2000; repeat: true; running: true; triggeredOnStart: true; onTriggered: { if (!volProc.running) volProc.running = true } }

    Process {
        id: volSetProc
        onExited: { running = false; if (!volProc.running) volProc.running = true }
        function raise()    { command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%+"]; running = true }
        function lower()    { command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"]; running = true }
        function mute()     { command = ["wpctl", "set-mute",   "@DEFAULT_AUDIO_SINK@", "toggle"]; running = true }
        function setTo(pct) { command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (Math.min(150, pct) / 100).toFixed(2)]; running = true }
    }

    // ── Brightness (brightnessctl) ────────────────────────
    property int brightPct: 39

    Process {
        id: brightProc
        command: ["bash", "-c", "brightnessctl -m | cut -d, -f4 | tr -d '%'"]
        stdout: SplitParser { onRead: data => { var v = parseInt(data.trim()); if (!isNaN(v)) bar.brightPct = v } }
        onExited: running = false
    }

    Timer { interval: 5000; repeat: true; running: true; triggeredOnStart: true; onTriggered: { if (!brightProc.running) brightProc.running = true } }

    Process {
        id: brightSetProc
        onExited: { running = false; if (!brightProc.running) brightProc.running = true }
        function setTo(pct) { command = ["brightnessctl", "set", Math.max(1, pct) + "%"]; running = true }
    }

    // ── WiFi toggle ───────────────────────────────────────
    property bool wifiOn: true

    Process {
        id: wifiReadProc
        command: ["nmcli", "radio", "wifi"]
        stdout: SplitParser { onRead: data => { bar.wifiOn = data.trim() === "enabled" } }
        onExited: running = false
    }

    Process {
        id: wifiToggleProc
        onExited: { running = false; if (!wifiReadProc.running) wifiReadProc.running = true }
        function toggle() { command = ["nmcli", "radio", "wifi", bar.wifiOn ? "off" : "on"]; running = true }
    }

    Timer { interval: 8000; repeat: true; running: true; triggeredOnStart: true; onTriggered: { if (!wifiReadProc.running) wifiReadProc.running = true } }

    // ── Media (playerctl) ────────────────────────────────
    // Several MPRIS players can exist at once (browser tab + spotify_player). Control the one
    // that is actually playing; otherwise prefer spotify_player, then whatever is first.
    readonly property string mediaPick:
        "p=$(for x in $(playerctl -l 2>/dev/null); do [ \"$(playerctl -p $x status 2>/dev/null)\" = Playing ] && { echo $x; break; }; done); " +
        "[ -n \"$p\" ] || p=$(playerctl -l 2>/dev/null | grep -m1 '^spotify_player$' || playerctl -l 2>/dev/null | head -n 1); " +
        "[ -n \"$p\" ] || exit 1; "

    Process {
        id: mediaProc
        command: ["bash", "-c", bar.mediaPick +
            "out=$(playerctl -p \"$p\" metadata --format '{{status}}\t{{title}}\t{{artist}}\t{{position}}\t{{mpris:length}}' | " +
            "awk -F'\\t' -v OFS='\\t' '{$4=int($4/1000);$5=int($5/1000);print}'); " +
            "if [ \"$p\" = spotify_player ] && [ -z \"$(printf %s \"$out\" | cut -f2)\" ]; then out=$(bash '" + bar.spScript + "' nowline); fi; printf '%s\\n' \"$out\""]
        property string buf: ""
        stdout: SplitParser { onRead: data => { mediaProc.buf += data } }
        onExited: (code) => {
            if (code === 0 && buf.trim().length > 0) {
                var parts = buf.trim().split("\t")
                bar.mediaStatus = parts[0] || "Stopped"
                bar.mediaTitle  = parts[1] || ""
                bar.mediaArtist = parts[2] || ""
                if (parts.length >= 9) {
                    bar.spActive = true
                    if (Date.now() > bar.ctlHoldUntil) {
                        bar.mediaShuffle = parts[5] === "true"
                        bar.mediaRepeat  = parts[6] || "off"
                        bar.mediaVolume  = parseInt(parts[7]) || 0
                    }
                    bar.mediaTrackId = parts[8] || ""
                    bar.mediaDevice  = parts[9] || ""
                } else {
                    bar.spActive = false; bar.mediaTrackId = ""; bar.mediaDevice = ""
                }
                bar.checkTrackNotify()
                if (Date.now() > bar.seekHoldUntil) {
                    bar.mediaPosMs   = parseInt(parts[3]) || 0
                    bar.mediaLenMs   = parseInt(parts[4]) || 0
                    bar.mediaPosAt   = Date.now()
                }
            } else {
                bar.mediaStatus = "Stopped"
                bar.mediaTitle  = ""
                bar.mediaArtist = ""
                bar.mediaPosMs = 0; bar.mediaLenMs = 0
                bar.spActive = false; bar.mediaTrackId = ""
            }
            buf = ""; running = false
        }
    }

    Timer { interval: 2000; repeat: true; running: true; triggeredOnStart: true; onTriggered: { if (!mediaProc.running) mediaProc.running = true } }

    Process { id: mediaPlayProc; command: ["bash", "-c", bar.mediaPick + "if [ \"$p\" = spotify_player ]; then bash '" + bar.spScript + "' control playpause; else playerctl -p \"$p\" play-pause; fi"]; onExited: { running = false; if (!mediaProc.running) mediaProc.running = true } }
    Process { id: mediaPrevProc; command: ["bash", "-c", bar.mediaPick + "if [ \"$p\" = spotify_player ]; then bash '" + bar.spScript + "' control prev; else playerctl -p \"$p\" previous; fi"]; onExited: { running = false; if (!mediaProc.running) mediaProc.running = true } }
    Process { id: mediaNextProc; command: ["bash", "-c", bar.mediaPick + "if [ \"$p\" = spotify_player ]; then bash '" + bar.spScript + "' control next; else playerctl -p \"$p\" next; fi"]; onExited: { running = false; if (!mediaProc.running) mediaProc.running = true } }

    // ── DND (local state) ─────────────────────────────────
    property bool dndOn: false

    // ── Media (playerctl) ─────────────────────────────────
    property string mediaStatus: "Stopped"
    property string mediaTitle:  ""
    property string mediaArtist: ""
    property real   mediaPosMs:  0      // position at the last poll
    property real   mediaLenMs:  0
    property real   mediaPosAt:  0      // Date.now() of that poll
    property real   seekHoldUntil: 0    // ignore polls briefly after a seek so the bar doesn't jump back
    property int    mediaTick:   0
    // extra state that only the Spotify API source provides
    property bool   spActive:      false    // the player in use is spotify_player (data comes from the Web API)
    property bool   mediaShuffle:  false
    property string mediaRepeat:   "off"
    property int    mediaVolume:   0
    property string mediaTrackId:  ""
    property string mediaDevice:   ""
    property real   ctlHoldUntil:  0        // ignore polls briefly after changing shuffle/repeat/volume
    function pollMedia()      { if (!mediaProc.running) mediaProc.running = true }
    function mediaPlayPause() { if (!mediaPlayProc.running) mediaPlayProc.running = true }
    function mediaPrev()      { if (!mediaPrevProc.running) mediaPrevProc.running = true }
    function mediaNext()      { if (!mediaNextProc.running) mediaNextProc.running = true }
    function seekTo(ms)       { mediaSeekProc.seekTo(ms) }
    function openPavucontrol() { launchPavuctl.running = true }
    // live position: interpolate between polls while playing
    function mediaNowMs(_tick) {
        var p = mediaPosMs + (mediaStatus === "Playing" ? Date.now() - mediaPosAt : 0)
        return Math.max(0, mediaLenMs > 0 ? Math.min(mediaLenMs, p) : p)
    }
    function fmtTime(ms) {
        var s = Math.floor(ms / 1000), m = Math.floor(s / 60)
        return m + ":" + (s % 60).toString().padStart(2, "0")
    }
    Timer { interval: 500; repeat: true; running: bar.hubOpen && bar.hubView === "spotify"; onTriggered: bar.mediaTick++ }

    Process {
        id: mediaSeekProc
        onExited: { running = false; if (!mediaProc.running) mediaProc.running = true }
        function seekTo(ms) {
            ms = Math.max(0, Math.round(ms))
            bar.mediaPosMs = ms; bar.mediaPosAt = Date.now(); bar.seekHoldUntil = Date.now() + 3000
            if (running) return
            command = ["bash", "-c", bar.mediaPick +
                "if [ \"$p\" = spotify_player ]; then bash '" + bar.spScript + "' control seek " + ms + "; " +
                "else playerctl -p \"$p\" position " + (ms / 1000).toFixed(2) + "; fi"]
            running = true
        }
    }

    // ── Hub view state ────────────────────────────────────
    property string hubView: "main"   // "main" | "wifi" | "bt"
    property var    wifiNetworks: []
    property var    btDevices: {
        var ad = Bluetooth.defaultAdapter
        var devs = ad?.devices?.values ?? []
        var scanning = ad?.discovering ?? false
        var rank = d => d.connected ? 0 : (d.paired || d.bonded || d.trusted) ? 1 : 2
        return devs.filter(d => d.connected || d.paired || d.bonded || d.trusted || (scanning && d.name && d.name !== d.address))
                   .sort((a, b) => rank(a) - rank(b) || (a.name || a.address).localeCompare(b.name || b.address))
    }
    property int currentHubHeight: {
        if (!hubOpen) return 32
        if (hubView === "wifi") return Math.max(280, 124 + Math.min(wifiNetworks.length, 7) * 52)
        if (hubView === "notifs") return 440
        if (hubView === "power")  return 310
        if (appletHeights[hubView] !== undefined) return appletHeights[hubView]
        if (hubView === "spotify") return 580
        if (hubView === "bt")   return Math.max(280, 124 + Math.min(btDevices.length, 7) * 52)
        // main view: 60 (island padding) + 48 (search bar + gap) + content
        return Math.max(180, hubContent.implicitHeight + 88 + 14)
    }

    Process {
        id: wifiScanProc
        command: ["nmcli", "--escape", "no", "-t", "-f", "active,ssid,signal,security", "dev", "wifi", "list"]
        property string buf: ""
        stdout: SplitParser { onRead: data => { wifiScanProc.buf += data + "\n" } }
        onExited: (code) => {
            if (code === 0) {
                var nets = [], seen = {}
                buf.split("\n").forEach(line => {
                    var t = line.trim(); if (!t) return
                    var parts = t.split(":")
                    if (parts.length < 4) return
                    var active = parts[0], security = parts[parts.length - 1]
                    var signal = parseInt(parts[parts.length - 2])
                    var ssid = parts.slice(1, parts.length - 2).join(":")
                    if ((active === "yes" || active === "no") && !isNaN(signal) && ssid && !seen[ssid]) {
                        seen[ssid] = true
                        nets.push({ active: active === "yes", ssid, signal, security })
                    }
                })
                nets.sort((a, b) => (b.active - a.active) || (b.signal - a.signal))
                bar.wifiNetworks = nets
            }
            buf = ""; running = false
        }
    }

    Process {
        id: wifiConnectProc
        onExited: { running = false; if (!wifiScanProc.running) wifiScanProc.running = true }
        function connectTo(ssid)   { command = ["nmcli", "dev", "wifi", "connect", ssid]; running = true }
        function disconnectWifi()  {
            command = ["bash", "-c",
                "iface=$(nmcli -t -f device,type dev | awk -F: '$2==\"wifi\"{print $1;exit}'); nmcli dev disconnect \"$iface\""]
            running = true
        }
    }

    // ── App search ────────────────────────────────────────
    property var    appList:     []
    property string searchQuery: ""
    property int selIndex: 0
    onSearchQueryChanged: selIndex = 0

    // launch history: { "App Name": { count, last } }, persisted
    property var recents: ({})
    FileView {
        id: recentStore
        path: Quickshell.env("HOME") + "/.local/state/qs-bar-recent.json"
        onLoaded: { try { bar.recents = JSON.parse(recentStore.text()) } catch(e) {} }
    }
    function launchApp(app) {
        if (!app) return
        if (studyFocus.isBlocked(app)) { schoolData.notify("Focus mode is on", app.name + " is blocked until focus mode ends."); return }
        var r = Object.assign({}, bar.recents)
        var cur = r[app.name] || { count: 0, last: 0 }
        r[app.name] = { count: cur.count + 1, last: Date.now() }
        bar.recents = r
        recentStore.setText(JSON.stringify(r))
        appLaunchProc.launch(app.exec)
        bar.hubOpen = false
    }
    function iconSrc(icon) {
        if (!icon) return ""
        if (icon.startsWith("/")) return "file://" + icon
        return Quickshell.iconPath(icon, true)
    }

    property var recentApps: {
        var names = Object.keys(recents).sort((a, b) => recents[b].last - recents[a].last)
        var out = []
        for (var i = 0; i < names.length && out.length < 4; i++) {
            var app = appList.find(a => a.name === names[i])
            if (app) out.push(app)
        }
        return out
    }

    property var searchResults: {
        if (searchQuery.length < 1 || searchQuery.trim().startsWith("=") || searchQuery.trim().startsWith("?")) return []
        var q = searchQuery.toLowerCase()
        var tier = a => {
            var n = a.name.toLowerCase()
            if (n.startsWith(q)) return 0
            if (n.includes(" " + q)) return 1
            if (n.includes(q)) return 2
            if ((a.exec || "").toLowerCase().includes(q)) return 3
            return 9
        }
        var r = appList.filter(a => tier(a) < 9)
        r.sort((a, b) => {
            var ta = tier(a), tb = tier(b)
            if (ta !== tb) return ta - tb
            var ca = recents[a.name]?.count ?? 0, cb = recents[b.name]?.count ?? 0
            if (ca !== cb) return cb - ca
            return a.name.localeCompare(b.name)
        })
        return r.slice(0, 6)
    }

    readonly property string _appScript: [
        "for base in $(printf %s \"$HOME/.local/share:$HOME/.nix-profile/share:/etc/profiles/per-user/$USER/share:/run/current-system/sw/share:/nix/var/nix/profiles/default/share:$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/var/lib/snapd/desktop:/usr/local/share:/usr/share:$XDG_DATA_DIRS\" | tr : \" \"); do",
        "  dir=\"$base/applications\"",
        "  [ -d \"$dir\" ] || continue",
        "  for f in \"$dir\"/*.desktop; do",
        "    [ -f \"$f\" ] || continue",
        "    grep -qi \"^NoDisplay=true\" \"$f\" && continue",
        "    grep -q \"^Type=Application\" \"$f\" || continue",
        "    n=$(grep -m1 \"^Name=\" \"$f\" | cut -d= -f2-)",
        "    e=$(grep -m1 \"^Exec=\" \"$f\" | cut -d= -f2- | sed \"s/ *%[fFuUdDnNickvm]//g;s/^[[:space:]]*//;s/[[:space:]]*$//\")",
        "    ic=$(grep -m1 \"^Icon=\" \"$f\" | cut -d= -f2-)",
        "    [ -n \"$n\" ] && [ -n \"$e\" ] && printf \"%s\\t%s\\t%s\\n\" \"$n\" \"$e\" \"$ic\"",
        "  done",
        "done | sort -t\"$(printf \"\\t\")\" -k1,1 | awk -F\"\\t\" \"!seen[\\$1]++\" | jq -Rn \"[inputs | split(\\\"\\\\t\\\") | {name: .[0], exec: .[1], icon: .[2]}]\""
    ].join("\n")

    Process {
        id: appLoadProc
        command: ["bash", "-c", bar._appScript]
        property string buf: ""
        stdout: SplitParser { onRead: data => { appLoadProc.buf += data } }
        onExited: (code) => {
            if (code === 0) { try { bar.appList = JSON.parse(buf) } catch(e) {} }
            buf = ""; running = false
        }
    }

    Process {
        id: appLaunchProc
        onExited: running = false
        function launch(exec) { command = ["bash", "-c", exec + " &"]; running = true }
    }

    Component.onCompleted: appLoadProc.running = true

    // ── App launchers ─────────────────────────────────────
    Process { id: launchRofi;    command: ["rofi", "-show", "drun"];  onExited: running = false }
    Process { id: launchBlueman; command: ["blueman-manager"];        onExited: running = false }
    Process { id: launchNmEditor;command: ["nm-connection-editor"];   onExited: running = false }
    Process { id: launchPavuctl; command: ["pavucontrol"];            onExited: running = false }

    // ── Left island ───────────────────────────────────────
    Rectangle {
        anchors { left: parent.left; leftMargin: 8; top: parent.top; topMargin: 6 }
        height: 32
        width: leftRow.implicitWidth + 18
        radius: 10
        color: Theme.islandBg
        border { color: Theme.islandBorder; width: 1 }

        RowLayout {
            id: leftRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: "  "
                color: Theme.mauve
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: launchRofi.running = true }
            }

            Rectangle { width: 1; height: 20; color: Theme.sep }

            Repeater {
                model: bar.workspaces
                delegate: Rectangle {
                    required property var modelData
                    width: 26; height: 26; radius: 7
                    color: modelData.is_focused ? Theme.mauve : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: modelData.idx.toString()
                        color: modelData.is_focused ? Theme.crust : Theme.dim
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 12; bold: modelData.is_focused }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: wsActionProc.focus(modelData.idx) }
                }
            }

            Rectangle { width: 1; height: 20; color: Theme.sep; visible: bar.focusedTitle.length > 0 }

            Text {
                visible: bar.focusedTitle.length > 0
                text: bar.focusedTitle
                color: Theme.text
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 13; italic: true }
                elide: Text.ElideRight
                Layout.maximumWidth: 260
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { bar.hubView = "windows"; bar.hubOpen = true; winView.activate() } }
            }

            Rectangle { width: 1; height: 20; color: Theme.sep; visible: bar.mediaTitle.length > 0 && bar.mediaStatus !== "Stopped" && bar.spActive }

            Text {
                visible: bar.mediaTitle.length > 0 && bar.mediaStatus !== "Stopped" && bar.spActive
                text: "󰓇 " + (bar.mediaArtist.length > 0 ? bar.mediaArtist + " – " : "") + bar.mediaTitle
                color: bar.mediaStatus === "Playing" ? Theme.green : Theme.dim
                elide: Text.ElideRight
                Layout.maximumWidth: 240
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                textFormat: Text.PlainText
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) { bar.hubView = "spotify"; bar.hubOpen = true }
                        else bar.mediaPlayPause()
                    }
                }
            }
        }
    }

    // ── Right island ──────────────────────────────────────
    Rectangle {
        anchors { right: parent.right; rightMargin: 8; top: parent.top; topMargin: 6 }
        height: 32
        width: rightRow.implicitWidth + 18
        radius: 10
        color: Theme.islandBg
        border { color: Theme.islandBorder; width: 1 }

        RowLayout {
            id: rightRow
            anchors.centerIn: parent
            spacing: 8

            Text {
                visible: (bar.store?.unread ?? 0) > 0
                text: "󰂚 " + (bar.store?.unread ?? 0)
                color: Theme.mauve
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { bar.hubView = "notifs"; bar.hubOpen = true } }
            }
            Rectangle { visible: (bar.store?.unread ?? 0) > 0; width: 1; height: 16; color: Theme.sep }

            Text {
                visible: bar.dndOn
                text: "󰂛"
                color: Theme.peach
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 15 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: bar.dndOn = false }
            }
            Rectangle { visible: bar.dndOn; width: 1; height: 16; color: Theme.sep }

            Text { text: " " + bar.cpuUsage + "%"; color: bar.cpuUsage > 80 ? Theme.red : Theme.teal; font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 } }
            Rectangle { width: 1; height: 16; color: Theme.sep }
            Text { text: " " + bar.memPercent + "%"; color: bar.memPercent > 80 ? Theme.red : Theme.teal; font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 } }
            Rectangle { width: 1; height: 16; color: Theme.sep }
            Text { text: " " + bar.cpuTemp + "°C"; color: bar.cpuTemp > 80 ? Theme.red : (bar.cpuTemp > 70 ? Theme.yellow : Theme.peach); font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 } }
            Rectangle { width: 1; height: 16; color: Theme.sep }

            Text {
                property var  adapter:   Bluetooth.defaultAdapter
                property var  connected: adapter?.devices?.values?.filter(d => d.connected) ?? []
                property bool powered:   adapter?.enabled ?? false
                text: connected.length > 0 ? "󰂯 " + (connected[0].name?.substring(0, 12) ?? "") : (powered ? "󰂯" : "󰂲")
                color: connected.length > 0 ? Theme.sky : (powered ? Theme.text : Theme.dim)
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: launchBlueman.running = true }
            }

            Rectangle { width: 1; height: 16; color: Theme.sep }

            Text {
                property string wifiIcon: bar.netSignal < 0 ? "󰤭" : bar.netSignal <= 20 ? "󰤯" : bar.netSignal <= 40 ? "󰤟" : bar.netSignal <= 60 ? "󰤢" : bar.netSignal <= 80 ? "󰤥" : "󰤨"
                text: wifiIcon
                color: bar.netSignal >= 0 ? Theme.sky : Theme.dim
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: launchNmEditor.running = true }
            }

            Rectangle { width: 1; height: 16; color: Theme.sep }

            Text {
                text: bar.volMuted ? "󰝟 " + bar.volPct + "%" : (bar.volPct > 66 ? "󰕾 " : bar.volPct > 33 ? "󰖀 " : "󰕿 ") + bar.volPct + "%"
                color: bar.volMuted ? Theme.dim : Theme.teal
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: launchPavuctl.running = true
                    onWheel: event => { if (!volSetProc.running) { if (event.angleDelta.y > 0) volSetProc.raise(); else volSetProc.lower() } }
                }
            }

            Rectangle { width: 1; height: 16; color: Theme.sep }

            Text {
                property bool charging: bar.batCharging || bar.batHeld
                text: bar.batIcon() + " " + bar.batPct + "%"
                color: charging ? Theme.green : bar.batLevel <= 19 ? Theme.red : bar.batLevel <= 38 ? Theme.yellow : Theme.text
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                visible: bar.batPct >= 0
            }
        }
    }

    // ── Center island — expands downward into hub ─────────
    Rectangle {
        id: centerIsland
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 6 }
        height: 32
        width: bar.hubOpen ? 520 : centerRow.implicitWidth + 22
        radius: 10
        clip: true
        color: bar.hubOpen ? Qt.alpha(Theme.panel, 0.985) : Theme.islandBg
        Behavior on color { ColorAnimation { duration: 160 } }
        border { color: bar.hubOpen ? Qt.alpha(Theme.mauve, 0.35) : Theme.islandBorder; width: 1 }

        Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on width  { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Connections {
            target: bar
            function onHubOpenChanged() {
                if (!bar.hubOpen) {
                    centerIsland.height = 32
                    bar.hubView = "main"
                    hubContent.searchInput.text = ""
                } else {
                    centerIsland.height = bar.currentHubHeight
                    hubContent.searchInput.forceActiveFocus()
                    if (bar.hubView === "notifs") bar.store?.markRead()
                    if (bar.hubView === "spotify") spView.activate()
                    bar.activateApplet(bar.hubView)
                    if (!appLoadProc.running) appLoadProc.running = true
                }
            }
            function onCurrentHubHeightChanged() {
                if (bar.hubOpen) centerIsland.height = bar.currentHubHeight
            }
            function onHubViewChanged() {
                if (bar.hubOpen && bar.hubView === "notifs") { bar.nowTick++; bar.store?.markRead() }
                if (bar.hubOpen && bar.hubView === "spotify") spView.activate()
                if (bar.hubOpen) bar.activateApplet(bar.hubView)
                if (bar.hubOpen && bar.hubView === "wifi" && !wifiScanProc.running)
                    wifiScanProc.running = true
            }
        }

        // ── Header row (always visible) ───────────────────
        Item {
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 32

            RowLayout {
                id: centerRow
                anchors.centerIn: parent
                spacing: 10

                Text {
                    visible: bar.timerText.length > 0
                    text: bar.timerText
                    color: Theme.mauve
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                }
                Rectangle { visible: bar.timerText.length > 0; width: 1; height: 20; color: Theme.sep }

                Text {
                    visible: bar.studyFocus.barText.length > 0
                    text: bar.studyFocus.barText
                    color: bar.studyFocus.phase === "focus" ? Theme.green : Theme.sky
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                }
                Rectangle { visible: bar.studyFocus.barText.length > 0; width: 1; height: 20; color: Theme.sep }
                Text {
                    visible: bar.school.chipText.length > 0
                    text: "󰃭 " + bar.school.chipText
                    color: Theme.yellow
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                }
                Rectangle { visible: bar.school.chipText.length > 0; width: 1; height: 20; color: Theme.sep }

                Text {
                    text: bar.weatherStr
                    color: Theme.peach
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                }

                Rectangle { width: 1; height: 20; color: Theme.sep }

                Text {
                    id: clockLabel
                    color: Theme.pink
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 13; weight: Font.Medium }
                    Timer {
                        interval: 1000; repeat: true; running: true; triggeredOnStart: true
                        onTriggered: {
                            var d = new Date()
                            var h = d.getHours(), m = d.getMinutes()
                            var ampm = h >= 12 ? "PM" : "AM"
                            h = h % 12 || 12
                            var days   = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
                            var months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
                            clockLabel.text = h + ":" + m.toString().padStart(2,"0") + " " + ampm
                                + "  ·  " + days[d.getDay()] + " " + months[d.getMonth()] + " " + d.getDate()
                        }
                    }
                }

                Text {
                    text: bar.hubOpen ? "󰅃" : "󰅀"
                    color: Theme.dim
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.hubOpen = !bar.hubOpen
            }
        }

        // ── Divider ───────────────────────────────────────
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 38 }
            height: 1
            color: Theme.sep
            opacity: bar.hubOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }

        // ── Hub tabs: Home | Games (only on those two pages) ─
        Rectangle {
            id: hubTabs
            visible: bar.hubOpen && (bar.hubView === "main" || bar.hubView === "games" || bar.hubView === "school")
            anchors { top: parent.top; topMargin: 46; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 }
            height: 34; radius: 12
            color: Qt.alpha(Theme.mauve, 0.06)
            border { color: Theme.cardBorder; width: 1 }
            RowLayout {
                anchors { fill: parent; margins: 3 }
                spacing: 3
                Repeater {
                    model: [ { id: "main", label: "Home", icon: "󰋜", color: Theme.mauve }, { id: "school", label: "School", icon: "󰑴", color: Theme.blue } ]
                        .concat(bar.studyFocus.modeOn ? [] : [ { id: "games", label: "Games", icon: "󰊖", color: Theme.green } ])
                    delegate: Rectangle {
                        id: ht
                        required property var modelData
                        readonly property bool sel: bar.hubView === modelData.id
                        Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.fillHeight: true; radius: 9
                        color: sel ? Qt.rgba(Qt.color(modelData.color).r, Qt.color(modelData.color).g, Qt.color(modelData.color).b, 0.20)
                                   : (hta.containsMouse ? Qt.alpha(Theme.mauve, 0.08) : "transparent")
                        Behavior on color { ColorAnimation { duration: 120 } }
                        RowLayout {
                            anchors.centerIn: parent; spacing: 8
                            Text { text: ht.modelData.icon; color: ht.sel ? ht.modelData.color : Theme.dim; font { family: "JetBrainsMono Nerd Font"; pixelSize: 15 } }
                            Text { text: ht.modelData.label; color: ht.sel ? Theme.text : Theme.dim; font { family: "JetBrainsMono Nerd Font"; pixelSize: 12; bold: ht.sel } }
                        }
                        MouseArea { id: hta; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { bar.hubView = ht.modelData.id; if (ht.modelData.id === "school") schoolView.activate() } }
                    }
                }
            }
        }

        // ── Main view ─────────────────────────────────────
        HomePage {
            bar: bar
            id: hubContent
            visible: bar.hubView === "main"
            anchors { top: parent.top; topMargin: 88; left: parent.left; right: parent.right }
            anchors { leftMargin: 14; rightMargin: 14 }
        }

        // ── WiFi view ─────────────────────────────────────
        WifiView {
            bar: bar
            visible: bar.hubView === "wifi"
            anchors { top: parent.top; topMargin: 46; left: parent.left; right: parent.right; bottom: parent.bottom }
        }

        // ── Power view ────────────────────────────────────
        PowerView {
            bar: bar
            id: powerView
            visible: bar.hubView === "power"
            anchors { top: parent.top; topMargin: 46; left: parent.left; right: parent.right; bottom: parent.bottom }
        }

        // ── Applets ───────────────────────────────────────
        Calendar {
            id: calView
            bar: bar
            visible: bar.hubView === "calendar"
            anchors { top: parent.top; topMargin: 46; left: parent.left; right: parent.right; bottom: parent.bottom }
        }
        Wallpapers {
            id: wallView
            bar: bar
            visible: bar.hubView === "wallpapers"
            anchors { top: parent.top; topMargin: 46; left: parent.left; right: parent.right; bottom: parent.bottom }
        }
        Clipboard {
            id: clipView
            bar: bar
            visible: bar.hubView === "clipboard"
            anchors { top: parent.top; topMargin: 46; left: parent.left; right: parent.right; bottom: parent.bottom }
        }
        Mixer {
            id: mixView
            bar: bar
            visible: bar.hubView === "mixer"
            anchors { top: parent.top; topMargin: 46; left: parent.left; right: parent.right; bottom: parent.bottom }
        }
        Shots {
            id: shotView
            bar: bar
            visible: bar.hubView === "shots"
            anchors { top: parent.top; topMargin: 46; left: parent.left; right: parent.right; bottom: parent.bottom }
        }
        Games {
            id: gamesView
            bar: bar
            visible: bar.hubView === "games"
            anchors { top: parent.top; topMargin: 84; left: parent.left; right: parent.right; bottom: parent.bottom }
        }

        Windows {
            id: winView
            bar: bar
            visible: bar.hubView === "windows"
            anchors { top: parent.top; topMargin: 46; left: parent.left; right: parent.right; bottom: parent.bottom }
        }
        School {
            id: schoolView
            bar: bar
            visible: bar.hubView === "school"
            anchors { top: parent.top; topMargin: 84; left: parent.left; right: parent.right; bottom: parent.bottom }
        }
        ThemeView {
            bar: bar
            visible: bar.hubView === "theme"
            anchors { top: parent.top; topMargin: 46; left: parent.left; right: parent.right; bottom: parent.bottom }
        }

        // ── Spotify view ──────────────────────────────────
        Spotify {
            id: spView
            bar: bar
            visible: bar.hubView === "spotify"
            anchors { top: parent.top; topMargin: 46; left: parent.left; right: parent.right; bottom: parent.bottom }
        }

        // ── Notification history view ─────────────────────
        NotifView {
            bar: bar
            visible: bar.hubView === "notifs"
            anchors { top: parent.top; topMargin: 46; left: parent.left; right: parent.right; bottom: parent.bottom }
        }

        // ── Bluetooth view ────────────────────────────────
        BluetoothView {
            bar: bar
            visible: bar.hubView === "bt"
            anchors { top: parent.top; topMargin: 46; left: parent.left; right: parent.right; bottom: parent.bottom }
        }
    }


}
