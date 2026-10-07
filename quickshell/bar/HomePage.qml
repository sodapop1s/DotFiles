import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

ColumnLayout {
    id: home
    required property var bar
    property alias searchInput: searchInput
    spacing: 0

    // Enter in the search box: ask Claude if the box holds a "?question" (true when that used the key)
    function tryAsk() {
        if (!ask.visible) return false
        var clear = ask.clearsAfterSubmit, cmd = ask.isCommand || ask.isNew
        if (!ask.submit()) return false
        if (clear) searchInput.text = "?"; else if (cmd) searchInput.text = ""
        return true
    }

    // ── Search bar + lock / power ─────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: 8

    Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 40
        radius: 12
        color: Qt.alpha(Theme.mauve, 0.07)
        border { color: searchInput.activeFocus ? Qt.alpha(Theme.mauve, 0.40) : Theme.sep; width: 1 }

        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            spacing: 8

            Text {
                text: "󰍉"
                color: searchInput.activeFocus ? Theme.mauve : Theme.dim
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
            }

            TextInput {
                id: searchInput
                Layout.fillWidth: true
                color: Theme.text
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
                onTextChanged: bar.searchQuery = text
                Keys.onEscapePressed: {
                    if (text.length > 0) { text = "" }
                    else { bar.hubOpen = false }
                }
                Keys.onReturnPressed: {
                    if (home.tryAsk()) return
                    if (calc.visible && calc.ok && (bar.searchResults.length === 0 || text.trim()[0] === "=")) calc.copy()
                    else if (bar.searchResults.length > 0)
                        bar.launchApp(bar.searchResults[Math.min(bar.selIndex, bar.searchResults.length - 1)])
                }
                Keys.onDownPressed: bar.selIndex = Math.min(bar.searchResults.length - 1, bar.selIndex + 1)
                Keys.onUpPressed:   bar.selIndex = Math.max(0, bar.selIndex - 1)
                Keys.onTabPressed:  bar.selIndex = (bar.selIndex + 1) % Math.max(1, bar.searchResults.length)
            }

            Text {
                visible: searchInput.text.length > 0
                text: "✕"; color: Theme.dim
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: searchInput.text = "" }
            }

            Text {
                visible: searchInput.text.length === 0
                text: "search apps"; color: Theme.dim
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
            }
        }
    }

    BarIconButton {
        icon: "󰌾"; tip: "Lock"
        onClicked: { bar.hubOpen = false; bar.lockProc.running = true }
    }
    BarIconButton {
        icon: "󰐥"; tip: "Power"; tint: Theme.red
        onClicked: bar.hubView = "power"
    }
    }

    // ── Calculator (LaTeX maths, graphs) ──────────
    AskCard { id: ask; query: home.bar.searchQuery; bar: home.bar }
    CalcCard { id: calc; query: bar.searchQuery; visible: !ask.visible && wanted && (query.replace(/^=\s*/, "").length > 0) }

    // ── Search results (when typing) ──────────────
    Item { visible: bar.searchQuery.length >= 1; Layout.preferredHeight: 8 }
    Repeater {
        model: bar.searchResults
        delegate: Rectangle {
            id: resRow
            required property var modelData
            required property int index
            readonly property bool sel: index === bar.selIndex
            Layout.fillWidth: true; implicitHeight: 38; radius: 6
            color: sel ? Qt.alpha(Theme.mauve, 0.14) : "transparent"

            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                spacing: 10
                Item {
                    Layout.preferredWidth: 22; Layout.preferredHeight: 22
                    Image {
                        id: resIcon
                        anchors.fill: parent
                        sourceSize: Qt.size(44, 44)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        source: bar.iconSrc(resRow.modelData.icon)
                        visible: status === Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: resIcon.status !== Image.Ready
                        text: "󰀻"
                        color: resRow.sel ? Theme.mauve : Theme.dim
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 15 }
                    }
                }
                Text {
                    text: resRow.modelData.name; color: resRow.sel ? Theme.text : Theme.dim
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                    elide: Text.ElideRight; Layout.fillWidth: true
                }
                Text {
                    visible: resRow.sel
                    text: "↵"; color: Theme.dim
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                }
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: bar.selIndex = resRow.index
                onClicked: bar.launchApp(resRow.modelData)
            }
        }
    }

    Text {
        visible: bar.searchQuery.length >= 1 && bar.searchResults.length === 0 && !calc.visible && !ask.visible
        Layout.fillWidth: true; Layout.topMargin: 14
        text: bar.appLoadProc.running ? "loading apps…" : "No apps found"
        color: Theme.dim; horizontalAlignment: Text.AlignHCenter
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
    }

    // ── Recently launched (empty search) ──────────
    RowLayout {
        visible: bar.searchQuery.length < 1 && bar.recentApps.length > 0
        Layout.fillWidth: true; Layout.preferredHeight: 34; Layout.topMargin: 8
        spacing: 6
        Repeater {
            model: bar.recentApps
            delegate: Rectangle {
                id: chip
                required property var modelData
                Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.preferredHeight: 34; radius: 12
                color: chipArea.containsMouse ? Qt.alpha(Theme.mauve, 0.14) : Theme.card
                border { color: Theme.cardBorder; width: 1 }
                RowLayout {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    spacing: 6
                    Image {
                        id: chipIcon
                        Layout.preferredWidth: 16; Layout.preferredHeight: 16
                        sourceSize: Qt.size(32, 32)
                        asynchronous: true
                        source: bar.iconSrc(chip.modelData.icon)
                        visible: status === Image.Ready
                    }
                    Text {
                        visible: chipIcon.status !== Image.Ready
                        text: "󰀻"; color: Theme.dim
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                    }
                    Text {
                        text: chip.modelData.name; color: Theme.text
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                }
                MouseArea { id: chipArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bar.launchApp(chip.modelData) }
            }
        }
    }

    // ── Quick tiles ───────────────────────────────
    // ── Due soon (Canvas) ─────────────────────────
    Rectangle {
        visible: bar.searchQuery.length < 1 && bar.school.configured && (bar.school.upcoming.length > 0 || bar.school.overdue.length > 0)
        Layout.fillWidth: true; Layout.topMargin: 10
        implicitHeight: dueCol.implicitHeight + 20
        radius: 12; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { bar.hubView = "school"; schoolView.setTab("due") } }
        ColumnLayout {
            id: dueCol
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
            spacing: 5
            RowLayout {
                Layout.fillWidth: true
                Text { text: "󰃭  Due soon"; color: Theme.blue; font { family: "JetBrainsMono Nerd Font"; pixelSize: 11; bold: true } }
                Item { Layout.fillWidth: true }
                Text { visible: bar.school.overdue.length > 0; text: bar.school.overdue.length + " overdue"; color: Theme.red; font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 } }
            }
            Repeater {
                model: bar.school.upcoming.slice(0, 3)
                delegate: RowLayout {
                    required property var modelData
                    readonly property real hrs: (modelData.due * 1000 - bar.school.nowMs) / 3600000
                    Layout.fillWidth: true; spacing: 8
                    Text { text: modelData.name; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 } }
                    Text { text: modelData.course.split(" ")[0]; color: Theme.dim; font { family: "JetBrainsMono Nerd Font"; pixelSize: 9 } }
                    Text { text: Math.round(hrs) < 48 ? Math.max(1, Math.round(hrs)) + "h" : Math.round(hrs / 24) + "d"; color: hrs < 24 ? Theme.red : hrs < 72 ? Theme.yellow : Theme.dim; Layout.preferredWidth: 26; horizontalAlignment: Text.AlignRight; font { family: "JetBrainsMono Nerd Font"; pixelSize: 11; bold: true } }
                }
            }
        }
    }

    // ── Connections ───────────────────────────────
    Rectangle {
        visible: bar.searchQuery.length < 1
        Layout.fillWidth: true; Layout.topMargin: 10
        implicitHeight: connCol.implicitHeight
        radius: 12; color: Theme.card; border { color: Theme.cardBorder; width: 1 }

        ColumnLayout {
            id: connCol
            anchors { left: parent.left; right: parent.right }
            spacing: 0

            ToggleRow {
                Layout.fillWidth: true
                icon: !bar.wifiOn ? "󰖪" : bar.netSignal < 0 ? "󰤭" : bar.netSignal <= 40 ? "󰤟" : bar.netSignal <= 70 ? "󰤢" : "󰤨"
                title: "Wi‑Fi"
                subtitle: !bar.wifiOn ? "Off" : (bar.wifiSsid.length > 0 ? bar.wifiSsid : "Not connected")
                on: bar.wifiOn; accent: Theme.sky; hasPanel: true
                onToggled: bar.wifiToggleProc.toggle()
                onOpened: bar.hubView = "wifi"
            }
            Rectangle { Layout.fillWidth: true; Layout.leftMargin: 14; Layout.rightMargin: 14; implicitHeight: 1; color: Theme.cardBorder }
            ToggleRow {
                Layout.fillWidth: true
                property var adapter: Bluetooth.defaultAdapter
                property var linked: bar.btDevices.filter(d => d.connected)
                icon: !(adapter?.enabled ?? false) ? "󰂲" : linked.length > 0 ? "󰂱" : "󰂯"
                title: "Bluetooth"
                subtitle: !(adapter?.enabled ?? false) ? "Off" : (linked.length > 0 ? (linked[0].name || "Connected") : "On")
                on: adapter?.enabled ?? false; accent: Theme.blue; hasPanel: true
                onToggled: { if (adapter) adapter.enabled = !adapter.enabled }
                onOpened: bar.hubView = "bt"
            }
            Rectangle { Layout.fillWidth: true; Layout.leftMargin: 14; Layout.rightMargin: 14; implicitHeight: 1; color: Theme.cardBorder }
            ToggleRow {
                Layout.fillWidth: true
                icon: bar.dndOn ? "󰂛" : "󰂚"
                title: "Do Not Disturb"
                subtitle: bar.dndOn ? "Only urgent notifications" : "Off"
                on: bar.dndOn; accent: Theme.peach; hasPanel: false
                onToggled: bar.dndOn = !bar.dndOn
            }
        }
    }

    // ── Quick settings: night light, keep awake, power profile, power off on lid close ──
    Job { id: quickJob; script: Quickshell.shellPath("quick.sh") }
    property var  qs: ({ profile: "", profiles: [], night: false, nightOk: false, awake: false, lid: false })
    property string qsNote: ""
    function qsRefresh() { quickJob.go(["status"], r => { if (r && r.night !== undefined) home.qs = r }) }
    function qsDo(args) {
        quickJob.go(args, r => { if (r && r.error) { home.qsNote = r.error; noteTimer.restart() } home.qsRefresh() })
    }
    Timer { id: noteTimer; interval: 5000; onTriggered: home.qsNote = "" }
    Component.onCompleted: qsRefresh()
    Connections { target: bar; function onHubOpenChanged() { if (bar.hubOpen) home.qsRefresh() } }
    readonly property var profileOrder: ["power-saver", "balanced", "performance"]
    readonly property var profileInfo: ({ "power-saver": { icon: "󰌪", label: "Saver" }, "balanced": { icon: "󰾅", label: "Balanced" }, "performance": { icon: "󰓅", label: "Perform" } })

    ColumnLayout {
        visible: bar.searchQuery.length < 1
        Layout.fillWidth: true; Layout.topMargin: 10
        spacing: 6
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            QuickPill {
                Layout.fillWidth: true; Layout.preferredWidth: 1
                icon: home.qs.profile ? home.profileInfo[home.qs.profile].icon : "󰾅"
                label: home.qs.profile ? home.profileInfo[home.qs.profile].label : "Profile"
                sub: "power"
                on: home.qs.profile === "performance"; accent: Theme.peach
                onClicked: {
                    if (!home.qs.profile) { home.qsNote = "Needs power-profiles-daemon (rebuild NixOS)"; noteTimer.restart(); return }
                    var avail = home.profileOrder.filter(p => home.qs.profiles.indexOf(p) >= 0)
                    home.qsDo(["profile", avail[(avail.indexOf(home.qs.profile) + 1) % avail.length]])
                }
            }
            QuickPill {
                Layout.fillWidth: true; Layout.preferredWidth: 1
                icon: "󰖔"; label: "Night"; sub: "warm screen"
                on: home.qs.night; accent: Theme.yellow
                onClicked: {
                    if (!home.qs.nightOk) { home.qsNote = "Needs wlsunset (rebuild NixOS)"; noteTimer.restart(); return }
                    home.qsDo(["night", home.qs.night ? "off" : "on"])
                }
            }
            QuickPill {
                Layout.fillWidth: true; Layout.preferredWidth: 1
                icon: "󰅶"; label: "Awake"; sub: "no sleep"
                on: home.qs.awake; accent: Theme.green
                onClicked: home.qsDo(["awake", home.qs.awake ? "off" : "on"])
            }
            QuickPill {
                Layout.fillWidth: true; Layout.preferredWidth: 1
                icon: "󰐥"; label: "Lid off"; sub: home.qs.lid ? "shuts down!" : "closing: nothing"
                on: home.qs.lid; accent: Theme.red
                onClicked: home.qsDo(["lid", home.qs.lid ? "off" : "on"])
            }
        }
        Text {
            visible: home.qsNote.length > 0 || home.qs.lid
            Layout.fillWidth: true; Layout.leftMargin: 4; wrapMode: Text.WordWrap
            text: home.qsNote.length > 0 ? home.qsNote : "Closing the lid will shut the computer down (until you turn this off or reboot)."
            color: home.qsNote.length > 0 ? Theme.yellow : Theme.red; font { family: "JetBrainsMono Nerd Font"; pixelSize: 9 }
        }
    }

    // ── Apps ──────────────────────────────────────
    Rectangle {
        visible: bar.searchQuery.length < 1
        Layout.fillWidth: true; Layout.topMargin: 10
        implicitHeight: dockGrid.implicitHeight + 20
        radius: 12; color: Theme.card; border { color: Theme.cardBorder; width: 1 }

        GridLayout {
            id: dockGrid
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 10; rightMargin: 10 }
            columns: 5; rowSpacing: 10; columnSpacing: 4
            Repeater {
                model: bar.applets
                delegate: DockItem {
                    required property var modelData
                    Layout.fillWidth: true; Layout.preferredWidth: 1
                    icon: modelData.icon; label: modelData.label; accent: modelData.accent
                    badge: modelData.id === "notifs" && (bar.store?.unread ?? 0) > 0 ? String(bar.store.unread) : ""
                    lit: (modelData.id === "spotify" && bar.spActive && bar.mediaStatus === "Playing")
                    onClicked: bar.hubView = modelData.id
                }
            }
        }
    }

    // ── Sound and brightness ──────────────────────
    Rectangle {
        visible: bar.searchQuery.length < 1
        Layout.fillWidth: true; Layout.topMargin: 10
        implicitHeight: slCol.implicitHeight + 16
        radius: 12; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
        ColumnLayout {
            id: slCol
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
            spacing: 2
            HubSlider {
                Layout.fillWidth: true
                icon: bar.volMuted ? "󰝟" : bar.volPct > 66 ? "󰕾" : bar.volPct > 33 ? "󰖀" : "󰕿"
                iconDim: bar.volMuted
                value: bar.volPct / 100; displayText: bar.volPct + "%"; accentColor: Theme.teal
                onIconClicked: { if (!bar.volSetProc.running) bar.volSetProc.mute() }
                onSlid: pct => { bar.volPct = Math.round(pct * 100); if (!bar.volSetProc.running) bar.volSetProc.setTo(Math.round(pct * 100)) }
            }
            HubSlider {
                Layout.fillWidth: true
                icon: bar.brightPct > 66 ? "󰃠" : bar.brightPct > 33 ? "󰃟" : "󰃞"
                value: bar.brightPct / 100; displayText: bar.brightPct + "%"; accentColor: Theme.yellow
                onSlid: pct => { bar.brightPct = Math.round(pct * 100); if (!bar.brightSetProc.running) bar.brightSetProc.setTo(Math.round(pct * 100)) }
            }
        }
    }

    // ── Now playing ───────────────────────────────
    Rectangle {
        visible: bar.searchQuery.length < 1 && bar.mediaStatus !== "Stopped" && bar.mediaTitle.length > 0
        Layout.fillWidth: true; Layout.topMargin: 10
        implicitHeight: 62
        radius: 12; color: Theme.card; border { color: Theme.cardBorder; width: 1 }

        MouseArea {
            anchors.fill: parent
            cursorShape: bar.spActive ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: { if (bar.spActive) bar.hubView = "spotify" }
        }
        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            spacing: 12
            Rectangle {
                Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 10
                color: Qt.alpha(Theme.green, bar.mediaStatus === "Playing" ? 0.18 : 0.08)
                Text { anchors.centerIn: parent; text: bar.spActive ? "󰓇" : "󰎆"
                       color: bar.mediaStatus === "Playing" ? Theme.green : Theme.dim
                       font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 } }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                Text { text: bar.mediaTitle; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true
                       font { family: "JetBrainsMono Nerd Font"; pixelSize: 12; bold: true } textFormat: Text.PlainText }
                Text { visible: bar.mediaArtist.length > 0; text: bar.mediaArtist; color: Theme.dim; elide: Text.ElideRight; Layout.fillWidth: true
                       font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 } textFormat: Text.PlainText }
            }
            Text { text: "󰒮"; color: Theme.text; font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
                   MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: bar.mediaPrev() } }
            Rectangle {
                Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 17; color: Theme.green
                Text { anchors.centerIn: parent; text: bar.mediaStatus === "Playing" ? "󰏤" : "󰐊"; color: Theme.crust
                       font { family: "JetBrainsMono Nerd Font"; pixelSize: 17 } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: bar.mediaPlayPause() }
            }
            Text { text: "󰒭"; color: Theme.text; font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
                   MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: bar.mediaNext() } }
        }
    }

    // ── System ────────────────────────────────────
    Rectangle {
        visible: bar.searchQuery.length < 1
        Layout.fillWidth: true; Layout.topMargin: 10
        implicitHeight: 74
        radius: 12; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
        RowLayout {
            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
            spacing: 0
            StatCell { Layout.fillWidth: true; Layout.preferredWidth: 1
                icon: "󰻠"; label: "CPU"; value: bar.cpuUsage + "%"; frac: bar.cpuUsage / 100
                accent: bar.cpuUsage > 80 ? Theme.red : Theme.teal }
            StatCell { Layout.fillWidth: true; Layout.preferredWidth: 1
                icon: "󰍛"; label: "Memory"; value: bar.memPercent + "%"; frac: bar.memPercent / 100
                accent: bar.memPercent > 80 ? Theme.red : Theme.sky }
            StatCell { Layout.fillWidth: true; Layout.preferredWidth: 1
                icon: "󰔏"; label: "Temp"; value: bar.cpuTemp + "°C"; frac: Math.min(1, bar.cpuTemp / 100)
                accent: bar.cpuTemp > 80 ? Theme.red : bar.cpuTemp > 70 ? Theme.yellow : Theme.peach }
            StatCell { Layout.fillWidth: true; Layout.preferredWidth: 1
                property bool chg: bar.batStatus === "Charging" || bar.batStatus === "Full"
                icon: chg ? "󰂄" : bar.batPct > 90 ? "󰁹" : bar.batPct > 70 ? "󰂂" : bar.batPct > 50 ? "󰂀" : bar.batPct > 30 ? "󰁾" : bar.batPct > 15 ? "󰁻" : "󰂎"
                label: chg ? "Charging" : "Battery"; value: bar.batPct + "%"; frac: bar.batPct / 100
                accent: chg ? Theme.green : bar.batPct <= 15 ? Theme.red : bar.batPct <= 30 ? Theme.yellow : Theme.text }
        }
    }
}
