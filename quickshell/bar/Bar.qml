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

    // ── Catppuccin Mocha ──────────────────────────────────
    readonly property color cIslandBg:     Qt.rgba(49/255,  50/255,  68/255,  0.92)
    readonly property color cIslandBorder: Qt.rgba(203/255, 166/255, 247/255, 0.15)
    readonly property color cSep:          Qt.rgba(203/255, 166/255, 247/255, 0.25)
    readonly property color cText:   "#b4befe"
    readonly property color cMauve:  "#cba6f7"
    readonly property color cPink:   "#f5c2e7"
    readonly property color cPeach:  "#fab387"
    readonly property color cTeal:   "#94e2d5"
    readonly property color cSky:    "#89dceb"
    readonly property color cGreen:  "#a6e3a1"
    readonly property color cYellow: "#f9e2af"
    readonly property color cRed:    "#f38ba8"
    readonly property color cDim:    "#6c7086"
    readonly property color cCrust:  "#11111b"

    // ── Hub ───────────────────────────────────────────────
    property bool hubOpen: false

    IpcHandler {
        target: "hub"
        function toggle(): void { bar.hubOpen = !bar.hubOpen }
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
    property var    _cpuPrev:   null

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
                    }
                })
            }
            buf = ""; running = false
        }
    }

    Timer { interval: 2000; repeat: true; running: true; triggeredOnStart: true; onTriggered: { if (!statsProc.running) statsProc.running = true } }

    // ── Network ───────────────────────────────────────────
    property int netSignal: -1

    Process {
        id: netProc
        command: ["bash", "-c", "nmcli -t -f active,signal dev wifi 2>/dev/null | grep '^yes' | head -1 | cut -d: -f2"]
        stdout: SplitParser { onRead: data => { var s = data.trim(); bar.netSignal = s.length > 0 ? parseInt(s) : -1 } }
        onExited: running = false
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
    Process {
        id: mediaProc
        command: ["playerctl", "metadata", "--format", "{{status}}\t{{title}}\t{{artist}}"]
        property string buf: ""
        stdout: SplitParser { onRead: data => { mediaProc.buf += data } }
        onExited: (code) => {
            if (code === 0 && buf.trim().length > 0) {
                var parts = buf.trim().split("\t")
                bar.mediaStatus = parts[0] || "Stopped"
                bar.mediaTitle  = parts[1] || ""
                bar.mediaArtist = parts[2] || ""
            } else {
                bar.mediaStatus = "Stopped"
                bar.mediaTitle  = ""
                bar.mediaArtist = ""
            }
            buf = ""; running = false
        }
    }

    Timer { interval: 2000; repeat: true; running: true; triggeredOnStart: true; onTriggered: { if (!mediaProc.running) mediaProc.running = true } }

    Process { id: mediaPlayProc; command: ["playerctl", "play-pause"]; onExited: { running = false; if (!mediaProc.running) mediaProc.running = true } }
    Process { id: mediaPrevProc; command: ["playerctl", "previous"];   onExited: { running = false; if (!mediaProc.running) mediaProc.running = true } }
    Process { id: mediaNextProc; command: ["playerctl", "next"];       onExited: { running = false; if (!mediaProc.running) mediaProc.running = true } }

    // ── DND (local state) ─────────────────────────────────
    property bool dndOn: false

    // ── Media (playerctl) ─────────────────────────────────
    property string mediaStatus: "Stopped"
    property string mediaTitle:  ""
    property string mediaArtist: ""

    // ── Hub view state ────────────────────────────────────
    property string hubView: "main"   // "main" | "wifi" | "bt"
    property var    wifiNetworks: []
    property var    btDevices: {
        var devs = Bluetooth.defaultAdapter?.devices?.values ?? []
        return devs.filter(d => d.paired || d.connected || d.trusted)
    }
    property int currentHubHeight: {
        if (!hubOpen) return 32
        if (hubView === "wifi") return Math.max(200, 101 + Math.min(wifiNetworks.length, 7) * 42)
        if (hubView === "bt")   return Math.max(200, 101 + Math.min(btDevices.length,   7) * 42)
        // main view: 60 (island padding) + 48 (search bar + gap) + content
        if (searchQuery.length >= 2) return Math.max(180, 108 + Math.min(searchResults.length, 6) * 42)
        var base = 314
    if (mediaTitle.length > 0 && mediaStatus !== "Stopped") base += 44
    return base
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

    Process {
        id: btActionProc
        onExited: running = false
        function connectDevice(addr)    { command = ["bluetoothctl", "connect",    addr]; running = true }
        function disconnectDevice(addr) { command = ["bluetoothctl", "disconnect", addr]; running = true }
    }

    // ── App search ────────────────────────────────────────
    property var    appList:     []
    property string searchQuery: ""
    property var searchResults: {
        if (searchQuery.length < 2) return []
        var q = searchQuery.toLowerCase()
        var r = appList.filter(a => a.name.toLowerCase().includes(q))
        r.sort((a, b) => {
            var ai = a.name.toLowerCase().indexOf(q), bi = b.name.toLowerCase().indexOf(q)
            return ai !== bi ? ai - bi : a.name.localeCompare(b.name)
        })
        return r.slice(0, 6)
    }

    readonly property string _pyAppScript: [
        "import os,re,json,glob",
        "dirs=['/run/current-system/sw/share/applications',os.path.expanduser('~/.local/share/applications')]",
        "apps,seen=[],set()",
        "for d in dirs:",
        " if not os.path.isdir(d):continue",
        " for p in glob.glob(d+'/*.desktop'):",
        "  try:",
        "   c=open(p).read()",
        "   if re.search(r'^NoDisplay=true',c,re.M|re.I):continue",
        "   if not re.search(r'^Type=Application',c,re.M):continue",
        "   n=re.search(r'^Name=(.+)',c,re.M);e=re.search(r'^Exec=(.+)',c,re.M)",
        "   if not n or not e or n.group(1) in seen:continue",
        "   seen.add(n.group(1))",
        "   apps.append({'name':n.group(1),'exec':re.sub(r' *%[fFuUdDnNickvm]','',e.group(1)).strip()})",
        "  except:pass",
        "apps.sort(key=lambda x:x['name'].lower())",
        "print(json.dumps(apps))"
    ].join("\n")

    Process {
        id: appLoadProc
        command: ["python3", "-c", bar._pyAppScript]
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
        color: bar.cIslandBg
        border { color: bar.cIslandBorder; width: 1 }

        RowLayout {
            id: leftRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: "  "
                color: bar.cMauve
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: launchRofi.running = true }
            }

            Rectangle { width: 1; height: 20; color: bar.cSep }

            Repeater {
                model: bar.workspaces
                delegate: Rectangle {
                    required property var modelData
                    width: 26; height: 26; radius: 7
                    color: modelData.is_focused ? bar.cMauve : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: modelData.idx.toString()
                        color: modelData.is_focused ? bar.cCrust : bar.cDim
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 12; bold: modelData.is_focused }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: wsActionProc.focus(modelData.idx) }
                }
            }

            Rectangle { width: 1; height: 20; color: bar.cSep; visible: bar.focusedTitle.length > 0 }

            Text {
                visible: bar.focusedTitle.length > 0
                text: bar.focusedTitle
                color: bar.cText
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 13; italic: true }
                elide: Text.ElideRight
                Layout.maximumWidth: 260
            }
        }
    }

    // ── Right island ──────────────────────────────────────
    Rectangle {
        anchors { right: parent.right; rightMargin: 8; top: parent.top; topMargin: 6 }
        height: 32
        width: rightRow.implicitWidth + 18
        radius: 10
        color: bar.cIslandBg
        border { color: bar.cIslandBorder; width: 1 }

        RowLayout {
            id: rightRow
            anchors.centerIn: parent
            spacing: 8

            Text { text: " " + bar.cpuUsage + "%"; color: bar.cpuUsage > 80 ? bar.cRed : bar.cTeal; font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 } }
            Rectangle { width: 1; height: 16; color: bar.cSep }
            Text { text: " " + bar.memPercent + "%"; color: bar.memPercent > 80 ? bar.cRed : bar.cTeal; font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 } }
            Rectangle { width: 1; height: 16; color: bar.cSep }
            Text { text: " " + bar.cpuTemp + "°C"; color: bar.cpuTemp > 80 ? bar.cRed : (bar.cpuTemp > 70 ? bar.cYellow : bar.cPeach); font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 } }
            Rectangle { width: 1; height: 16; color: bar.cSep }

            Text {
                property var  adapter:   Bluetooth.defaultAdapter
                property var  connected: adapter?.devices?.values?.filter(d => d.connected) ?? []
                property bool powered:   adapter?.powered ?? false
                text: connected.length > 0 ? "󰂯 " + (connected[0].name?.substring(0, 12) ?? "") : (powered ? "󰂯" : "󰂲")
                color: connected.length > 0 ? bar.cSky : (powered ? bar.cText : bar.cDim)
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: launchBlueman.running = true }
            }

            Rectangle { width: 1; height: 16; color: bar.cSep }

            Text {
                property string wifiIcon: bar.netSignal < 0 ? "󰤭" : bar.netSignal <= 20 ? "󰤯" : bar.netSignal <= 40 ? "󰤟" : bar.netSignal <= 60 ? "󰤢" : bar.netSignal <= 80 ? "󰤥" : "󰤨"
                text: wifiIcon
                color: bar.netSignal >= 0 ? bar.cSky : bar.cDim
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: launchNmEditor.running = true }
            }

            Rectangle { width: 1; height: 16; color: bar.cSep }

            Text {
                text: bar.volMuted ? "󰝟 " + bar.volPct + "%" : (bar.volPct > 66 ? "󰕾 " : bar.volPct > 33 ? "󰖀 " : "󰕿 ") + bar.volPct + "%"
                color: bar.volMuted ? bar.cDim : bar.cTeal
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: launchPavuctl.running = true
                    onWheel: event => { if (!volSetProc.running) { if (event.angleDelta.y > 0) volSetProc.raise(); else volSetProc.lower() } }
                }
            }

            Rectangle { width: 1; height: 16; color: bar.cSep }

            Text {
                property bool charging: bar.batStatus === "Charging" || bar.batStatus === "Full"
                text: (charging ? "󰂄" : bar.batPct > 90 ? "󰁹" : bar.batPct > 70 ? "󰂂" : bar.batPct > 50 ? "󰂀" : bar.batPct > 30 ? "󰁾" : bar.batPct > 15 ? "󰁻" : "󰂎") + " " + bar.batPct + "%"
                color: charging ? bar.cGreen : bar.batPct <= 15 ? bar.cRed : bar.batPct <= 30 ? bar.cYellow : bar.cText
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
        width: centerRow.implicitWidth + 22
        radius: 10
        clip: true
        color: bar.cIslandBg
        border { color: bar.hubOpen ? Qt.rgba(203/255, 166/255, 247/255, 0.35) : bar.cIslandBorder; width: 1 }

        Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on width  { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Connections {
            target: bar
            function onHubOpenChanged() {
                if (!bar.hubOpen) {
                    centerIsland.height = 32
                    centerIsland.width  = centerRow.implicitWidth + 22
                    bar.hubView = "main"
                    searchInput.text = ""
                } else {
                    centerIsland.height = bar.currentHubHeight
                    centerIsland.width  = 520
                    searchInput.forceActiveFocus()
                }
            }
            function onCurrentHubHeightChanged() {
                if (bar.hubOpen) centerIsland.height = bar.currentHubHeight
            }
            function onHubViewChanged() {
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
                    text: bar.weatherStr
                    color: bar.cPeach
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                }

                Rectangle { width: 1; height: 20; color: bar.cSep }

                Text {
                    id: clockLabel
                    color: bar.cPink
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
                    color: bar.cDim
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
            color: bar.cSep
            opacity: bar.hubOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }

        // ── Main view ─────────────────────────────────────
        ColumnLayout {
            id: hubContent
            visible: bar.hubView === "main"
            anchors { top: parent.top; topMargin: 46; left: parent.left; right: parent.right }
            anchors { leftMargin: 14; rightMargin: 14 }
            spacing: 0

            // ── Search bar ────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 36; Layout.bottomMargin: 8
                radius: 8
                color: Qt.rgba(203/255, 166/255, 247/255, 0.07)
                border { color: searchInput.activeFocus ? Qt.rgba(203/255, 166/255, 247/255, 0.40) : bar.cSep; width: 1 }

                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    spacing: 8

                    Text {
                        text: ""
                        color: searchInput.activeFocus ? bar.cMauve : bar.cDim
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        color: bar.cText
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                        onTextChanged: bar.searchQuery = text
                        Keys.onEscapePressed: {
                            if (text.length > 0) { text = "" }
                            else { bar.hubOpen = false }
                        }
                        Keys.onReturnPressed: {
                            if (bar.searchResults.length > 0) {
                                appLaunchProc.launch(bar.searchResults[0].exec)
                                text = ""; bar.hubOpen = false
                            }
                        }
                    }

                    Text {
                        visible: searchInput.text.length > 0
                        text: "✕"; color: bar.cDim
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: searchInput.text = "" }
                    }

                    Text {
                        visible: searchInput.text.length === 0
                        text: "search apps…"; color: bar.cDim
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                    }
                }
            }

            // ── Search results (when typing) ──────────────
            Repeater {
                model: bar.searchResults
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true; implicitHeight: 38; radius: 6
                    color: index === 0 ? Qt.rgba(203/255, 166/255, 247/255, 0.10) : "transparent"

                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        spacing: 10
                        Text {
                            text: ""
                            color: index === 0 ? bar.cMauve : bar.cDim
                            font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                        }
                        Text {
                            text: modelData.name; color: index === 0 ? bar.cText : bar.cDim
                            font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                        Text {
                            visible: index === 0
                            text: "↵"; color: bar.cDim
                            font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { appLaunchProc.launch(modelData.exec); searchInput.text = ""; bar.hubOpen = false }
                    }
                }
            }

            // ── Normal content (hidden while searching) ───
            HubSlider {
                visible: bar.searchQuery.length < 2
                Layout.fillWidth: true; Layout.preferredHeight: 34
                icon: bar.volMuted ? "󰝟" : bar.volPct > 66 ? "󰕾" : bar.volPct > 33 ? "󰖀" : "󰕿"
                value: bar.volPct / 100; displayText: bar.volPct + "%"; accentColor: bar.cTeal
                onSlid: pct => { bar.volPct = Math.round(pct * 100); if (!volSetProc.running) volSetProc.setTo(Math.round(pct * 100)) }
            }

            HubSlider {
                visible: bar.searchQuery.length < 2
                Layout.fillWidth: true; Layout.preferredHeight: 34
                icon: "󰃠"; value: bar.brightPct / 100; displayText: bar.brightPct + "%"; accentColor: bar.cYellow
                onSlid: pct => { bar.brightPct = Math.round(pct * 100); if (!brightSetProc.running) brightSetProc.setTo(Math.round(pct * 100)) }
            }

            // ── Media controls ────────────────────────────
            Rectangle {
                visible: bar.searchQuery.length < 2 && bar.mediaStatus !== "Stopped" && bar.mediaTitle.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                Layout.topMargin: 6
                radius: 8
                color: Qt.rgba(203/255, 166/255, 247/255, 0.06)
                border { color: bar.cSep; width: 1 }

                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    spacing: 6

                    Text {
                        text: "󰒮"
                        color: bar.cDim
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (!mediaPrevProc.running) mediaPrevProc.running = true } }
                    }
                    Text {
                        text: bar.mediaStatus === "Playing" ? "󰏤" : "󰐊"
                        color: bar.cMauve
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (!mediaPlayProc.running) mediaPlayProc.running = true } }
                    }
                    Text {
                        text: "󰒭"
                        color: bar.cDim
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (!mediaNextProc.running) mediaNextProc.running = true } }
                    }

                    Rectangle { width: 1; height: 20; color: bar.cSep }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            text: bar.mediaTitle
                            color: bar.cText
                            font { family: "JetBrainsMono Nerd Font"; pixelSize: 11; bold: true }
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                        Text {
                            visible: bar.mediaArtist.length > 0
                            text: bar.mediaArtist
                            color: bar.cDim
                            font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                    }
                }
            }

            Rectangle {
                visible: bar.searchQuery.length < 2
                Layout.fillWidth: true; Layout.topMargin: 10; Layout.bottomMargin: 10; implicitHeight: 1; color: bar.cSep
            }

            RowLayout {
                visible: bar.searchQuery.length < 2
                Layout.fillWidth: true; Layout.preferredHeight: 48; spacing: 0
                HubStat { Layout.fillWidth: true; label: "CPU";  value: bar.cpuUsage + "%";   accent: bar.cpuUsage  > 80 ? bar.cRed : bar.cTeal }
                HubStat { Layout.fillWidth: true; label: "RAM";  value: bar.memPercent + "%"; accent: bar.memPercent > 80 ? bar.cRed : bar.cTeal }
                HubStat { Layout.fillWidth: true; label: "Temp"; value: bar.cpuTemp + "°C";   accent: bar.cpuTemp > 80 ? bar.cRed : bar.cpuTemp > 70 ? bar.cYellow : bar.cPeach }
                HubStat { Layout.fillWidth: true; label: "Bat";  value: bar.batPct + "%";     accent: (bar.batStatus === "Charging" || bar.batStatus === "Full") ? bar.cGreen : bar.batPct <= 20 ? bar.cRed : bar.cText }
            }

            Rectangle {
                visible: bar.searchQuery.length < 2
                Layout.fillWidth: true; Layout.topMargin: 10; Layout.bottomMargin: 10; implicitHeight: 1; color: bar.cSep
            }

            RowLayout {
                visible: bar.searchQuery.length < 2
                Layout.fillWidth: true; Layout.preferredHeight: 36; spacing: 8
                Text { text: bar.weatherStr; color: bar.cPeach; font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 } }
                Item { Layout.fillWidth: true }
                HubToggle {
                    label: "WiFi"; icon: bar.wifiOn ? "󰖩" : "󰖪"; active: bar.wifiOn
                    onToggled: { bar.hubView = "wifi" }
                }
                HubToggle {
                    property var adapter: Bluetooth.defaultAdapter
                    label: "BT"; icon: (adapter?.powered ?? false) ? "󰂯" : "󰂲"
                    active: bar.btDevices.some(d => d.connected)
                    onToggled: { bar.hubView = "bt" }
                }
                HubToggle { label: "DND"; icon: bar.dndOn ? "󰂛" : "󰂚"; active: bar.dndOn; onToggled: bar.dndOn = !bar.dndOn }
            }
        }

        // ── WiFi view ─────────────────────────────────────
        Item {
            visible: bar.hubView === "wifi"
            anchors { top: parent.top; topMargin: 46; left: parent.left; right: parent.right; bottom: parent.bottom }

            ColumnLayout {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                anchors { leftMargin: 12; rightMargin: 12 }
                spacing: 0

                // nav row
                RowLayout {
                    Layout.fillWidth: true; Layout.preferredHeight: 40; spacing: 8
                    Text {
                        text: "󰁍"
                        color: bar.cDim; font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: bar.hubView = "main" }
                    }
                    Text { text: "WiFi"; color: bar.cSky; font { family: "JetBrainsMono Nerd Font"; pixelSize: 14; bold: true } }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: wifiScanProc.running ? "scanning…" : "rescan"
                        color: bar.cDim; font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (!wifiScanProc.running) wifiScanProc.running = true } }
                    }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: bar.cSep; Layout.bottomMargin: 2 }

                Repeater {
                    model: bar.wifiNetworks
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; implicitHeight: 40; radius: 6
                        color: modelData.active ? Qt.rgba(137/255, 220/255, 235/255, 0.12) : "transparent"

                        RowLayout {
                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                            spacing: 8
                            Text {
                                text: modelData.signal > 75 ? "󰤨" : modelData.signal > 50 ? "󰤥" : modelData.signal > 25 ? "󰤢" : "󰤟"
                                color: modelData.active ? bar.cSky : bar.cDim
                                font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                            }
                            Text {
                                text: modelData.ssid; color: modelData.active ? bar.cText : bar.cDim
                                font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                                elide: Text.ElideRight; Layout.fillWidth: true
                            }
                            Text {
                                text: modelData.security || "Open"; color: bar.cDim
                                font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
                            }
                            Text {
                                visible: modelData.active; text: "●"; color: bar.cGreen
                                font { family: "JetBrainsMono Nerd Font"; pixelSize: 8 }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.active) wifiConnectProc.disconnectWifi()
                                else wifiConnectProc.connectTo(modelData.ssid)
                            }
                        }
                    }
                }

                Text {
                    visible: bar.wifiNetworks.length === 0 && !wifiScanProc.running
                    Layout.fillWidth: true; Layout.topMargin: 16
                    text: "No networks found"; color: bar.cDim
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // ── Bluetooth view ────────────────────────────────
        Item {
            visible: bar.hubView === "bt"
            anchors { top: parent.top; topMargin: 46; left: parent.left; right: parent.right; bottom: parent.bottom }

            ColumnLayout {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                anchors { leftMargin: 12; rightMargin: 12 }
                spacing: 0

                // nav row
                RowLayout {
                    Layout.fillWidth: true; Layout.preferredHeight: 40; spacing: 8
                    Text {
                        text: "󰁍"
                        color: bar.cDim; font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: bar.hubView = "main" }
                    }
                    Text { text: "Bluetooth"; color: bar.cSky; font { family: "JetBrainsMono Nerd Font"; pixelSize: 14; bold: true } }
                    Item { Layout.fillWidth: true }
                    Text {
                        property bool scanning: Bluetooth.defaultAdapter?.discovering ?? false
                        text: scanning ? "scanning…" : "scan"
                        color: bar.cDim; font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: bar.cSep; Layout.bottomMargin: 2 }

                Repeater {
                    model: bar.btDevices
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; implicitHeight: 40; radius: 6
                        color: modelData.connected ? Qt.rgba(148/255, 226/255, 213/255, 0.12) : "transparent"

                        RowLayout {
                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                            spacing: 8
                            Text {
                                text: modelData.connected ? "󰂯" : "󰂲"
                                color: modelData.connected ? bar.cTeal : bar.cDim
                                font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                            }
                            Text {
                                text: modelData.name || modelData.address
                                color: modelData.connected ? bar.cText : bar.cDim
                                font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                                elide: Text.ElideRight; Layout.fillWidth: true
                            }
                            Text {
                                text: modelData.connected ? "connected" : (modelData.paired ? "paired" : "trusted")
                                color: modelData.connected ? bar.cGreen : bar.cDim
                                font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.connected) btActionProc.disconnectDevice(modelData.address)
                                else btActionProc.connectDevice(modelData.address)
                            }
                        }
                    }
                }

                Text {
                    visible: bar.btDevices.length === 0
                    Layout.fillWidth: true; Layout.topMargin: 16
                    text: "No paired devices"; color: bar.cDim
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    // ── Inline components ─────────────────────────────────

    component HubSlider: RowLayout {
        id: sl
        property string icon: "󰕿"
        property real   value: 0
        property string displayText: ""
        property color  accentColor: "#94e2d5"
        signal slid(real pct)

        implicitHeight: 34
        spacing: 10

        Text {
            text: sl.icon
            color: sl.accentColor
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 15 }
            Layout.preferredWidth: 18
        }

        Item {
            Layout.fillWidth: true
            height: 20

            Rectangle {
                id: slTrack
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                height: 4; radius: 2
                color: Qt.rgba(203/255, 166/255, 247/255, 0.10)

                Rectangle {
                    width: Math.max(slHandle.width / 2, slTrack.width * sl.value)
                    height: parent.height; radius: parent.radius
                    color: sl.accentColor; opacity: 0.75
                }
            }

            Rectangle {
                id: slHandle
                x: (slTrack.width - width) * sl.value
                anchors.verticalCenter: slTrack.verticalCenter
                width: 14; height: 14; radius: 7
                color: sl.accentColor
            }

            MouseArea {
                anchors.fill: parent
                function emit(mx) { sl.slid(Math.max(0, Math.min(1, mx / slTrack.width))) }
                onPressed:         mouse => emit(mouse.x)
                onPositionChanged: mouse => { if (pressed) emit(mouse.x) }
            }
        }

        Text {
            text: sl.displayText
            color: bar.cDim
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
            Layout.preferredWidth: 32
            horizontalAlignment: Text.AlignRight
        }
    }

    component HubStat: Item {
        property string label:  ""
        property string value:  ""
        property color  accent: "#b4befe"

        implicitHeight: 48

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 2

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.value
                color: parent.parent.accent
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 15; bold: true }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.label
                color: bar.cDim
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
            }
        }
    }

    component HubToggle: Rectangle {
        id: tog
        property string label:  ""
        property string icon:   ""
        property bool   active: false
        signal toggled

        width: 64; height: 32; implicitHeight: 32; radius: 8
        color: active ? Qt.rgba(203/255, 166/255, 247/255, 0.20) : Qt.rgba(49/255, 50/255, 68/255, 0.80)
        border { color: active ? Qt.rgba(203/255, 166/255, 247/255, 0.40) : Qt.rgba(203/255, 166/255, 247/255, 0.10); width: 1 }

        RowLayout {
            anchors.centerIn: parent
            spacing: 5

            Text { text: tog.icon; color: tog.active ? bar.cMauve : bar.cDim; font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 } }
            Text { text: tog.label; color: tog.active ? bar.cText : bar.cDim; font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 } }
        }

        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tog.toggled() }
    }
}
