import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Minecraft / GTNH: pick a Prism Launcher instance from a drop-down, launch it, and (for GTNH)
// see whether a newer pack is out. Helpers: prism.sh (instances) and gtnh.sh (versions).
Item {
    id: root
    required property var bar
    property bool embedded: false          // true when shown as a tab inside the Games panel
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.green
    readonly property string home: Quickshell.env("HOME")

    property var    instances: []
    property string selectedId: ""
    property bool   menuOpen: false
    property var    gtnh: null           // result of gtnh.sh latest
    property bool   killArmed: false
    property bool   modsOpen: false
    property bool   createOpen: false
    property string pendingSelect: ""      // instance to select once the list has refreshed (after creating one)
    property var    modsSummary: null    // {enabled, disabled, mc, loaders} for the selected non-GTNH instance
    property string status: ""
    property bool   statusErr: false
    property int    tick: 0

    function say(msg, err) { status = msg; statusErr = !!err; statusTimer.restart() }
    Timer { id: statusTimer; interval: 5000; onTriggered: root.status = "" }

    readonly property var selected: instances.find(i => i.id === selectedId) || (instances.length ? instances[0] : null)

    // ── remembered selection ──────────────────────────────
    FileView {
        id: prefs
        path: root.home + "/.local/state/qs-bar-minecraft.json"
        onLoaded: { try { var p = JSON.parse(prefs.text()); if (p.selected) root.selectedId = p.selected } catch(e) {} }
    }
    function select(inst) {
        selectedId = inst.id; menuOpen = false; killArmed = false
        prefs.setText(JSON.stringify({ selected: inst.id }))
        modsSummary = null
        loadVersions(); loadSummary()
    }

    // ── data ──────────────────────────────────────────────
    Job { id: listJob;   script: Quickshell.shellPath("prism.sh") }
    Job { id: actJob;    script: Quickshell.shellPath("prism.sh") }
    Job { id: verJob;    script: Quickshell.shellPath("gtnh.sh") }
    Job { id: sumJob;    script: Quickshell.shellPath("mods.sh") }
    Job { id: updCountJob; script: Quickshell.shellPath("mods.sh") }
    property int updateCount: 0                    // mods with a newer version in the selected instance

    readonly property bool modded: !!(selected && selected.group !== "GTNH" && selected.loader)
    function loadSummary() {
        if (!modded) { modsSummary = null; return }
        sumJob.go(["summary", selected.id], r => { if (r && !r.error) modsSummary = r })
        var id = selected.id
        updateCount = 0
        updCountJob.go(["updates", id, ""], r => { if (r && r.items && selected && selected.id === id) updateCount = r.items.length })
    }
    function modsBrowse() { modsView.testBrowse("mod menu") }
    function modsPlan() { modsView.testPlan() }
    function demoCreate() { createView.demoDone(); createOpen = true }
    function showCreate() { createView.open(); createOpen = true }
    function showMods() {                     // opens the mod manager of the first non-GTNH instance (used for testing)
        var i = instances.find(x => x.group !== "GTNH" && x.loader)
        if (i) { selectedId = i.id; loadSummary(); modsView.open(); modsOpen = true }
    }

    function refresh() { listJob.go(["list"], r => { if (Array.isArray(r)) {
            instances = r
            if (pendingSelect) { var n = r.find(x => x.id === pendingSelect); if (n) select(n); pendingSelect = "" }
            loadVersions(); if (!modsSummary) loadSummary()
        } else if (r && r.error) say(r.error, true) }) }
    function loadVersions() {
        if (selected && selected.group === "GTNH" && !gtnh) verJob.go(["latest"], r => { if (r) gtnh = r })
    }
    function activate() { tick++; killArmed = false; menuOpen = false; modsOpen = false; createOpen = false; refresh(); loadVersions(); loadSummary() }
    function toggleMenu() { menuOpen = !menuOpen }
    Timer { interval: 4000; repeat: true; running: root.visible; onTriggered: { root.tick++; root.refresh() } }

    function play() {
        if (!selected) return
        say("launching " + selected.display + "…", false)
        actJob.go(["launch", selected.id], r => { if (r && r.error) say(r.error, true) })
        pollSoon.restart()
    }
    Timer { id: pollSoon; interval: 5000; onTriggered: root.refresh() }
    function kill() {
        if (!selected) return
        if (!killArmed) { killArmed = true; armTimer.restart(); return }
        killArmed = false
        actJob.go(["kill", selected.id], r => { if (r && r.error) say(r.error, true); else say("stopped " + selected.display, false); refresh() })
    }
    Timer { id: armTimer; interval: 4000; onTriggered: root.killArmed = false }

    Process { id: openProc; onExited: running = false }
    function open(path) { openProc.command = ["xdg-open", path]; openProc.running = true }
    function instDir() { return home + "/.local/share/PrismLauncher/instances/" + selected.id }

    // ── formatting ────────────────────────────────────────
    function ago(ms, _t) {
        if (!ms) return "never"
        var d = Math.floor((Date.now() - ms) / 86400000)
        if (d <= 0) { var h = Math.floor((Date.now() - ms) / 3600000); return h <= 0 ? "just now" : h + "h ago" }
        if (d === 1) return "yesterday"
        if (d < 60) return d + " days ago"
        return Math.round(d / 30) + " months ago"
    }
    function playtimeText(sec) {
        if (!sec) return "no playtime"
        var h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60)
        return h > 0 ? h + "h " + m + "m" : m + "m"
    }
    function loaderText(l) {
        if (!l) return ""
        var p = l.split(" ")
        var nm = p[0].replace("minecraftforge", "Forge").replace("quilt-loader", "Quilt").replace("fabric-loader", "Fabric").replace("neoforged", "NeoForge")
        return nm + (p[1] ? " " + p[1] : "")
    }
    function subtitle(i) {
        if (!i) return ""
        return ["Minecraft " + i.mc, loaderText(i.loader), i.java ? "Java " + i.java : ""].filter(x => x).join("  ·  ")
    }

    // ── GTNH version logic ────────────────────────────────
    // installed version of the selected instance, from its name: {kind:"nightly", date} or {kind:"release", ver}
    function installedInfo(i) {
        if (!i) return null
        var text = i.name + " " + i.id
        var d = /(\d{4}-\d{2}-\d{2})/.exec(text)
        if (d && /nightly|daily/i.test(text)) return { kind: "nightly", date: d[1] }
        var m = /(\d+\.\d+\.\d+)(?:[-_ ]?(beta|b|rc)[-_ ]?(\d+))?/i.exec(text)
        if (!m) return null
        var tag = m[2] ? (m[2].toLowerCase() === "rc" ? "RC" : "beta") : ""
        return { kind: "release", ver: m[1] + (tag ? "-" + tag + "-" + m[3] : "") }
    }
    // sortable key: major, minor, patch, stage (beta=0, RC=1, stable=2), number
    function vkey(v) {
        var m = /^(\d+)\.(\d+)\.(\d+)(?:-(beta|RC|rc)-(\d+))?$/.exec(v)
        if (!m) return [0, 0, 0, 0, 0]
        var stage = m[4] ? (m[4].toLowerCase() === "rc" ? 1 : 0) : 2
        return [+m[1], +m[2], +m[3], stage, m[5] ? +m[5] : 0]
    }
    function vcmp(a, b) {
        var x = vkey(a), y = vkey(b)
        for (var i = 0; i < 5; i++) if (x[i] !== y[i]) return x[i] - y[i]
        return 0
    }
    // { text, level: "ok"|"new"|"info", latest: string }
    readonly property var gtnhStatus: {
        var i = selected, inst = installedInfo(i)
        if (!i || i.group !== "GTNH" || !gtnh || gtnh.error) return null
        if (!inst) return { text: "version unknown", level: "info", installed: "?" }
        if (inst.kind === "nightly") {
            var behind = (gtnh.nightlies || []).filter(t => {
                var dm = /(\d{4}-\d{2}-\d{2})/.exec(t); return dm && dm[1] > inst.date
            }).length
            return { installed: "Nightly " + inst.date, level: behind > 0 ? "new" : "ok",
                     text: behind > 0 ? behind + " newer nightl" + (behind === 1 ? "y" : "ies") + " out" : "up to date" }
        }
        var newest = gtnh.pre && vcmp(gtnh.pre, gtnh.stable) > 0 ? gtnh.pre : gtnh.stable
        var older = vcmp(inst.ver, newest) < 0
        return { installed: inst.ver, level: older ? "new" : "ok", text: older ? "newer: " + newest : "up to date" }
    }

    // ══ UI ═══════════════════════════════════════════════
    AppHeader {
        id: head
        compact: root.embedded
        bar: root.bar; icon: "󰍳"; title: "Minecraft"; accent: root.accent
        anchors { top: parent.top; left: parent.left; right: parent.right }
        onBack: root.bar.hubView = "main"
        Text {
            visible: root.status.length > 0
            text: root.status; color: root.statusErr ? Theme.red : Theme.green
            elide: Text.ElideRight; width: Math.min(implicitWidth, 260)
            font { family: root.font; pixelSize: 11 }
        }
        Text {
            text: "󰐕 New"; color: root.accent; font { family: root.font; pixelSize: 11; bold: true }
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: { createView.open(); root.createOpen = true } }
        }
        Text {
            text: "󰑐"; color: Theme.dim; font { family: root.font; pixelSize: 14 }
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: { root.refresh(); root.gtnh = null; root.verJob_reload() } }
        }
    }
    function verJob_reload() { if (selected && selected.group === "GTNH") verJob.go(["latest", "fresh"], r => { if (r) gtnh = r }) }
    Rectangle { id: sep; anchors { top: head.bottom; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 } height: 1; color: Theme.sep }

    // instance selector (the drop-down button)
    Rectangle {
        id: selector
        anchors { top: sep.bottom; topMargin: 12; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 }
        height: 64; radius: 14
        color: selArea.containsMouse ? Qt.alpha(Theme.green, 0.12) : Theme.card
        border { color: root.menuOpen ? root.accent : Theme.cardBorder; width: 1 }
        Behavior on color { ColorAnimation { duration: 120 } }
        MouseArea { id: selArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.menuOpen = !root.menuOpen }
        RowLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 14 }
            spacing: 12
            InstIcon { inst: root.selected; size: 40 }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 1
                Text { text: root.selected ? root.selected.display : "No instances found"; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true
                       textFormat: Text.PlainText; font { family: root.font; pixelSize: 13; bold: true } }
                Text { text: root.subtitle(root.selected); color: Theme.dim; elide: Text.ElideRight; Layout.fillWidth: true
                       font { family: root.font; pixelSize: 10 } }
            }
            Rectangle { visible: !!(root.selected && root.selected.running); width: runLbl.implicitWidth + 14; height: 18; radius: 9; color: Theme.green
                Text { id: runLbl; anchors.centerIn: parent; text: "Running"; color: Theme.crust; font { family: root.font; pixelSize: 9; bold: true } } }
            Text { text: root.menuOpen ? "󰅃" : "󰅀"; color: Theme.dim; font { family: root.font; pixelSize: 16 } }
        }
    }

    component InstIcon: Rectangle {
        id: ic
        property var inst: null
        property int size: 36
        Layout.preferredWidth: size; Layout.preferredHeight: size
        width: size; height: size; radius: size * 0.28; clip: true
        color: Qt.alpha(Theme.green, 0.14)
        Image {
            id: img
            anchors { fill: parent; margins: 3 }
            asynchronous: true; fillMode: Image.PreserveAspectFit; sourceSize: Qt.size(96, 96)
            source: ic.inst && ic.inst.icon ? "file://" + ic.inst.icon : ""
            visible: status === Image.Ready
        }
        Text { visible: img.status !== Image.Ready; anchors.centerIn: parent; text: "󰍳"; color: root.accent; font { family: root.font; pixelSize: ic.size * 0.5 } }
    }

    // ── detail area ───────────────────────────────────────
    Item {
        id: detail
        anchors { top: selector.bottom; topMargin: 12; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 12 }
        visible: root.selected !== null

        Flickable {
            anchors.fill: parent; clip: true; contentHeight: col.implicitHeight; boundsBehavior: Flickable.StopAtBounds
            ColumnLayout {
                id: col
                width: parent.width; spacing: 10

                // play / stop
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 50; radius: 14
                        color: playArea.containsMouse ? Qt.lighter(Theme.green, 1.1) : Theme.green
                        opacity: root.selected && root.selected.running ? 0.45 : 1
                        RowLayout { anchors.centerIn: parent; spacing: 10
                            Text { text: "󰐊"; color: Theme.crust; font { family: root.font; pixelSize: 22 } }
                            Text { text: root.selected && root.selected.running ? "Already running" : "Play"; color: Theme.crust; font { family: root.font; pixelSize: 14; bold: true } } }
                        MouseArea { id: playArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    enabled: !(root.selected && root.selected.running); onClicked: root.play() }
                    }
                    Rectangle {
                        visible: !!(root.selected && root.selected.running)
                        Layout.preferredWidth: 110; Layout.preferredHeight: 50; radius: 14
                        color: root.killArmed ? Qt.alpha(Theme.red, 0.28) : Theme.card
                        border { color: root.killArmed ? Theme.red : Theme.cardBorder; width: 1 }
                        Text { anchors.centerIn: parent; text: root.killArmed ? "Click to confirm" : "󰓛  Stop"
                               color: root.killArmed ? Theme.red : Theme.text; font { family: root.font; pixelSize: 11; bold: true } }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.kill() }
                    }
                }

                // stats
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 64; radius: 12
                    color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        spacing: 0
                        Repeater {
                            model: [
                                { k: "Last played", v: root.selected ? root.ago(root.selected.lastLaunch, root.tick) : "" },
                                { k: "Play time",   v: root.selected ? root.playtimeText(root.selected.playtime) : "" },
                                { k: "Java",        v: root.selected && root.selected.java ? root.selected.java : "—" }
                            ]
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true; Layout.preferredWidth: 1; spacing: 2
                                Text { Layout.alignment: Qt.AlignHCenter; text: modelData.v; color: Theme.text; font { family: root.font; pixelSize: 13; bold: true } }
                                Text { Layout.alignment: Qt.AlignHCenter; text: modelData.k; color: Theme.dim; font { family: root.font; pixelSize: 9 } }
                            }
                        }
                    }
                }

                // mods (non-GTNH instances)
                Rectangle {
                    visible: root.modded
                    Layout.fillWidth: true; implicitHeight: 62; radius: 12
                    color: modsArea.containsMouse ? Qt.alpha(Theme.green, 0.12) : Theme.card
                    border { color: Theme.cardBorder; width: 1 }
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea { id: modsArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { modsView.open(); root.modsOpen = true } }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                        spacing: 12
                        Rectangle {
                            Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 11; color: Qt.alpha(Theme.green, 0.16)
                            Text { anchors.centerIn: parent; text: "󰏖"; color: root.accent; font { family: root.font; pixelSize: 19 } }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 1
                            Text { text: "Mods"; color: Theme.text; font { family: root.font; pixelSize: 13; bold: true } }
                            Text {
                                text: root.modsSummary ? root.modsSummary.enabled + " enabled  ·  " + root.modsSummary.disabled + " disabled" + (root.updateCount > 0 ? "  ·  " + root.updateCount + " updates" : "") : "reading…"
                                color: root.updateCount > 0 ? Theme.yellow : Theme.dim; font { family: root.font; pixelSize: 10 }
                            }
                        }
                        Text { text: "Manage  󰅂"; color: root.accent; font { family: root.font; pixelSize: 11 } }
                    }
                }

                // GTNH versions
                Rectangle {
                    visible: !!(root.selected && root.selected.group === "GTNH")
                    Layout.fillWidth: true; implicitHeight: gtCol.implicitHeight + 24; radius: 12
                    color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                    ColumnLayout {
                        id: gtCol
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "GTNH versions"; color: Theme.text; font { family: root.font; pixelSize: 12; bold: true } }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                visible: root.gtnhStatus !== null
                                width: chipT.implicitWidth + 16; height: 20; radius: 10
                                color: root.gtnhStatus && root.gtnhStatus.level === "new" ? Qt.alpha(Theme.yellow, 0.2) : Qt.alpha(Theme.green, 0.18)
                                Text { id: chipT; anchors.centerIn: parent; text: root.gtnhStatus ? root.gtnhStatus.text : ""
                                       color: root.gtnhStatus && root.gtnhStatus.level === "new" ? Theme.yellow : Theme.green
                                       font { family: root.font; pixelSize: 10; bold: true } }
                            }
                        }
                        Text {
                            visible: !root.gtnh
                            text: verJob.running ? "checking for new versions…" : "version info unavailable"
                            color: Theme.dim; font { family: root.font; pixelSize: 10 }
                        }
                        Text { visible: !!(root.gtnh && root.gtnh.error); text: root.gtnh ? (root.gtnh.error || "") : ""; color: Theme.red; font { family: root.font; pixelSize: 10 } }
                        GridLayout {
                            visible: !!(root.gtnh && !root.gtnh.error)
                            Layout.fillWidth: true; columns: 2; columnSpacing: 12; rowSpacing: 4
                            Text { text: "Installed"; color: Theme.dim; font { family: root.font; pixelSize: 11 } }
                            Text { text: root.gtnhStatus ? root.gtnhStatus.installed : "—"; color: Theme.text; font { family: root.font; pixelSize: 11; bold: true } }
                            Text { text: "Latest stable"; color: Theme.dim; font { family: root.font; pixelSize: 11 } }
                            Text { text: root.gtnh ? (root.gtnh.stable || "—") : ""; color: Theme.text; font { family: root.font; pixelSize: 11 } }
                            Text { visible: !!(root.gtnh && root.gtnh.pre); text: "Latest pre-release"; color: Theme.dim; font { family: root.font; pixelSize: 11 } }
                            Text { visible: !!(root.gtnh && root.gtnh.pre); text: root.gtnh ? root.gtnh.pre : ""; color: Theme.text; font { family: root.font; pixelSize: 11 } }
                            Text { text: "Latest nightly"; color: Theme.dim; font { family: root.font; pixelSize: 11 } }
                            Text { text: root.gtnh ? (root.gtnh.nightly || "—").replace(/^.*nightly-/, "") : ""; color: Theme.text; font { family: root.font; pixelSize: 11 } }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            LinkButton { label: "󰖟 Downloads"; onClicked: root.open("https://www.gtnewhorizons.com/downloads/") }
                            LinkButton { label: "󰋚 Version history"; onClicked: root.open("https://www.gtnewhorizons.com/version-history/") }
                        }
                    }
                }

                // folders / logs
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    LinkButton { label: "󰉋 Instance folder"; onClicked: root.open(root.instDir()) }
                    LinkButton { label: "󰈙 Latest log"; onClicked: root.open(root.instDir() + "/minecraft/logs/latest.log") }
                    LinkButton { label: "󰍳 Prism"; onClicked: { root.bar.hubOpen = false; root.openPrism() } }
                }
            }
        }
    }
    Process { id: prismProc; onExited: running = false }
    function openPrism() { prismProc.command = ["setsid", "-f", "prismlauncher"]; prismProc.running = true }

    component LinkButton: Rectangle {
        id: lb
        property string label: ""
        signal clicked
        Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.preferredHeight: 34; radius: 10
        color: la.containsMouse ? Qt.alpha(Theme.green, 0.14) : Qt.alpha(Theme.mauve, 0.07)
        border { color: la.containsMouse ? Qt.alpha(Theme.green, 0.4) : Theme.cardBorder; width: 1 }
        Text { anchors.centerIn: parent; text: lb.label; color: Theme.text; font { family: root.font; pixelSize: 11 } }
        MouseArea { id: la; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: lb.clicked() }
    }

    // ── the drop-down list (on top of everything) ─────────
    MouseArea { anchors.fill: parent; visible: root.menuOpen; z: 20; onClicked: root.menuOpen = false }
    Rectangle {
        id: menu
        visible: root.menuOpen
        z: 21
        anchors { top: selector.bottom; topMargin: 6; left: selector.left; right: selector.right }
        height: Math.min(menuList.contentHeight + 12, root.height - selector.y - selector.height - 24)
        radius: 14
        color: Qt.alpha(Theme.panel, 0.99)
        border { color: root.accent; width: 1 }
        ListView {
            id: menuList
            anchors { fill: parent; margins: 6 }
            clip: true; spacing: 2; boundsBehavior: Flickable.StopAtBounds
            model: {
                var out = [], last = ""
                root.instances.forEach(i => {
                    if (i.group !== last) { out.push({ header: i.group }); last = i.group }
                    out.push({ inst: i })
                })
                return out
            }
            delegate: Item {
                id: mrow
                required property var modelData
                readonly property bool isHeader: modelData.header !== undefined
                width: menuList.width
                height: isHeader ? 26 : 46
                Text { visible: mrow.isHeader; anchors { left: parent.left; leftMargin: 8; bottom: parent.bottom; bottomMargin: 3 }
                       text: (mrow.modelData.header || "").toUpperCase(); color: Theme.dim
                       font { family: root.font; pixelSize: 10; bold: true; letterSpacing: 1 } }
                Rectangle {
                    visible: !mrow.isHeader
                    anchors.fill: parent; radius: 10
                    color: mh.hovered ? Qt.alpha(Theme.green, 0.14) : (mrow.modelData.inst && mrow.modelData.inst.id === root.selectedId ? Qt.alpha(Theme.green, 0.08) : "transparent")
                    HoverHandler { id: mh; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; onClicked: root.select(mrow.modelData.inst) }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 10 }
                        spacing: 10
                        InstIcon { inst: mrow.modelData.inst || null; size: 30 }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 0
                            Text { text: mrow.modelData.inst ? mrow.modelData.inst.display : ""; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true
                                   textFormat: Text.PlainText; font { family: root.font; pixelSize: 12 } }
                            Text { text: mrow.modelData.inst ? root.ago(mrow.modelData.inst.lastLaunch, root.tick) : ""; color: Theme.dim; font { family: root.font; pixelSize: 9 } }
                        }
                        Text { visible: !!(mrow.modelData.inst && mrow.modelData.inst.running); text: "● running"; color: Theme.green; font { family: root.font; pixelSize: 9 } }
                        Text { visible: !!(mrow.modelData.inst && mrow.modelData.inst.id === root.selectedId); text: "󰄬"; color: root.accent; font { family: root.font; pixelSize: 14 } }
                    }
                }
            }
        }
    }

    Mods {
        id: modsView
        anchors.fill: parent
        visible: root.modsOpen
        z: 40
        bar: root.bar
        instance: root.selected
        onBack: { root.modsOpen = false; root.loadSummary(); root.refresh() }
    }

    Create {
        id: createView
        anchors.fill: parent
        visible: root.createOpen
        z: 45
        bar: root.bar
        onBack: root.createOpen = false
        onCreated: id => { root.createOpen = false; root.pendingSelect = id; root.refresh() }
    }

    Text {
        visible: root.instances.length === 0
        anchors.centerIn: parent
        text: "No Prism Launcher instances found."; color: Theme.dim; font { family: root.font; pixelSize: 12 }
    }
}
