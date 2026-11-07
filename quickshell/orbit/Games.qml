import QtQuick
import QtQuick.Layouts
import Quickshell

// Game launchers in one place: a "Recent" home page, plus Minecraft (Prism instances), Steam, Lutris and KSP (CKAN).
// Minecraft.qml and Steam.qml are embedded as tabs; this file only adds the tab bar and the Recent page.
Item {
    id: root
    required property var bar
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.green
    property alias mc: mcTab
    property alias steam: steamTab
    property alias ksp: kspTab
    property alias lutris: lutrisTab

    property string tab: "recent"              // recent | minecraft | steam | lutris | ksp
    property int    tick: 0
    property string status: ""
    property bool   statusErr: false

    function say(msg, err) { status = msg; statusErr = !!err; statusTimer.restart() }
    Timer { id: statusTimer; interval: 4000; onTriggered: root.status = "" }

    function setTab(t) {
        tab = t
        if (t === "minecraft") mcTab.activate()
        else if (t === "steam") steamTab.activate()
        else if (t === "lutris") lutrisTab.activate()
        else if (t === "ksp") kspTab.activate()
        else activate()
    }
    function activate() {
        tick++
        mcTab.refresh()
        steamTab.activate()
        lutrisTab.refresh()
        kspTab.quickRefresh()
        if (tab === "minecraft") mcTab.activate()
    }
    Timer { interval: 5000; repeat: true; running: root.visible && root.tab === "recent"; onTriggered: { root.tick++; mcTab.refresh(); steamTab.refreshStatus(); lutrisTab.refresh() } }

    // ── Recent page data ──────────────────────────────────
    Job { id: mcLaunch;    script: Quickshell.shellPath("prism.sh") }
    Job { id: steamLaunch; script: Quickshell.shellPath("steam.sh") }
    Job { id: lutrisLaunch; script: Quickshell.shellPath("lutris.sh") }

    readonly property var recents: {
        var out = []
        mcTab.instances.forEach(i => out.push({
            kind: "minecraft", id: i.id, name: i.display, at: i.lastLaunch, running: i.running, icon: i.icon,
            sub: "Minecraft " + i.mc + (i.loader ? "  ·  " + mcTab.loaderText(i.loader) : "")
        }))
        steamTab.games.forEach(g => out.push({
            kind: "steam", id: g.id, name: g.name, at: g.lastPlayed * 1000, running: steamTab.running.indexOf(g.id) >= 0,
            header: g.header, sub: "Steam" + (steamTab.sizeText(g.size) ? "  ·  " + steamTab.sizeText(g.size) : "")
        }))
        lutrisTab.games.forEach(g => out.push({
            kind: "lutris", id: g.id, name: g.name, at: g.lastPlayed * 1000, running: lutrisTab.isRunning(g),
            header: g.art, sub: "Lutris" + (g.runner ? "  ·  " + g.runner : "")
        }))
        out.sort((a, b) => b.at - a.at)
        return out.slice(0, 12)
    }
    function ago(ms, _t) {
        if (!ms) return "never played"
        var d = Math.floor((Date.now() - ms) / 86400000)
        if (d <= 0) { var h = Math.floor((Date.now() - ms) / 3600000); return h <= 0 ? "just now" : h + "h ago" }
        if (d === 1) return "yesterday"
        if (d < 60) return d + " days ago"
        return Math.round(d / 30) + " months ago"
    }
    function play(it) {
        say("launching " + it.name + "…", false)
        if (it.kind === "minecraft") mcLaunch.go(["launch", it.id], r => { if (r && r.error) say(r.error, true) })
        else if (it.kind === "lutris") lutrisLaunch.go(["launch", it.id], r => { if (r && r.error) say(r.error, true) })
        else steamLaunch.go(["launch", it.id], r => { if (r && r.error) say(r.error, true) })
    }
    function openItem(it) {
        if (it.kind === "minecraft") {
            var inst = mcTab.instances.find(i => i.id === it.id)
            if (inst) mcTab.select(inst)
            setTab("minecraft")
        } else setTab(it.kind === "lutris" ? "lutris" : "steam")
    }

    // ══ UI ═══════════════════════════════════════════════
    // launcher tabs
    Row {
        id: tabs
        anchors { top: parent.top; topMargin: 2; left: parent.left; leftMargin: 14 }
        width: parent.width - 28
        spacing: 5
        Repeater {
            model: [
                { id: "recent",    label: "Recent",    icon: "󰋚" },
                { id: "minecraft", label: "Minecraft", icon: "󰍳" },
                { id: "steam",     label: "Steam",     icon: "󰓓" },
                { id: "lutris",    label: "Lutris",    icon: "󰊗" },
                { id: "ksp",       label: "KSP",       icon: "󰑣" }
            ]
            delegate: Rectangle {
                id: tb
                required property var modelData
                readonly property bool sel: root.tab === modelData.id
                width: Math.floor((tabs.width - 4 * tabs.spacing) / 5); height: 30; radius: 10
                color: sel ? Qt.alpha(Theme.green, 0.16) : (ta.containsMouse ? Qt.alpha(Theme.mauve, 0.08) : "transparent")
                border { color: sel ? Qt.alpha(Theme.green, 0.4) : Theme.cardBorder; width: 1 }
                RowLayout {
                    anchors.centerIn: parent; spacing: 5
                    Text { text: tb.modelData.icon; color: tb.sel ? root.accent : Theme.dim; font { family: root.font; pixelSize: 14 } }
                    Text { text: tb.modelData.label; color: tb.sel ? root.accent : Theme.text; font { family: root.font; pixelSize: 10; bold: tb.sel } }
                    Rectangle {   // mods with a newer version waiting (KSP, via CKAN)
                        visible: tb.modelData.id === "ksp" && root.bar.school.pref("kspUpgrades", 0) > 0
                        width: Math.max(14, kspBadge.implicitWidth + 8); height: 14; radius: 7; color: Theme.yellow
                        Text { id: kspBadge; anchors.centerIn: parent; text: root.bar.school.pref("kspUpgrades", 0); color: Theme.crust; font { family: root.font; pixelSize: 8; bold: true } }
                    }
                    Rectangle {   // a dot when something in that launcher is running
                        visible: (tb.modelData.id === "minecraft" && mcTab.instances.some(i => i.running))
                                 || (tb.modelData.id === "steam" && steamTab.running.length > 0)
                                 || (tb.modelData.id === "lutris" && lutrisTab.running.length > 0)
                        width: 6; height: 6; radius: 3; color: Theme.green
                    }
                }
                MouseArea { id: ta; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setTab(tb.modelData.id) }
            }
        }
    }
    Text {
        visible: root.status.length > 0
        anchors { verticalCenter: tabs.verticalCenter; right: parent.right; rightMargin: 16 }
        text: root.status; color: root.statusErr ? Theme.red : Theme.green
        elide: Text.ElideRight; width: Math.min(implicitWidth, 150)
        font { family: root.font; pixelSize: 10 }
    }
    Rectangle { id: sep; anchors { top: tabs.bottom; topMargin: 8; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 } height: 1; color: Theme.sep }

    // ───────── Recent ─────────
    Item {
        id: recentPage
        visible: root.tab === "recent"
        anchors { top: sep.bottom; topMargin: 10; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 12 }

        // the two launchers at a glance
        RowLayout {
            id: cards
            anchors { top: parent.top; left: parent.left; right: parent.right }
            spacing: 8
            Repeater {
                model: [
                    { id: "minecraft", title: "Minecraft", icon: "󰍳", color: Theme.green },
                    { id: "steam",     title: "Steam",     icon: "󰓓", color: Theme.sky },
                    { id: "lutris",    title: "Lutris",    icon: "󰊗", color: Theme.peach }
                ]
                delegate: Rectangle {
                    id: lc
                    required property var modelData
                    readonly property string sub: modelData.id === "minecraft"
                        ? mcTab.instances.length + " instance" + (mcTab.instances.length === 1 ? "" : "s") + (mcTab.instances.some(i => i.running) ? "  ·  running" : "")
                        : modelData.id === "lutris"
                        ? lutrisTab.games.length + " game" + (lutrisTab.games.length === 1 ? "" : "s") + (lutrisTab.running.length ? "  ·  running" : "")
                        : steamTab.games.length + " game" + (steamTab.games.length === 1 ? "" : "s") + (steamTab.steamUp ? "  ·  Steam open" : "  ·  Steam closed")
                    Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.preferredHeight: 64; radius: 14
                    color: lh.hovered ? Qt.rgba(Qt.color(modelData.color).r, Qt.color(modelData.color).g, Qt.color(modelData.color).b, 0.14) : Theme.card
                    border { color: lh.hovered ? modelData.color : Theme.cardBorder; width: 1 }
                    HoverHandler { id: lh; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; onClicked: root.setTab(lc.modelData.id) }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        spacing: 10
                        Rectangle {
                            Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 11
                            color: Qt.rgba(Qt.color(lc.modelData.color).r, Qt.color(lc.modelData.color).g, Qt.color(lc.modelData.color).b, 0.18)
                            Text { anchors.centerIn: parent; text: lc.modelData.icon; color: lc.modelData.color; font { family: root.font; pixelSize: 20 } }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 1
                            Text { text: lc.modelData.title; color: Theme.text; font { family: root.font; pixelSize: 12; bold: true } }
                            Text { text: lc.sub; color: Theme.dim; elide: Text.ElideRight; Layout.fillWidth: true; font { family: root.font; pixelSize: 9 } }
                        }
                    }
                }
            }
        }

        Text {
            id: recentTitle
            anchors { top: cards.bottom; topMargin: 14; left: parent.left; leftMargin: 4 }
            text: "RECENTLY PLAYED"; color: Theme.dim; font { family: root.font; pixelSize: 10; bold: true; letterSpacing: 1 }
        }

        ListView {
            id: list
            anchors { top: recentTitle.bottom; topMargin: 6; left: parent.left; right: parent.right; bottom: parent.bottom }
            clip: true; spacing: 4; boundsBehavior: Flickable.StopAtBounds
            model: root.recents

            delegate: Rectangle {
                id: row
                required property var modelData
                width: list.width; height: 56; radius: 12
                color: rh.hovered ? Qt.alpha(Theme.green, 0.08) : Theme.card
                border { color: row.modelData.running ? Theme.green : Theme.cardBorder; width: 1 }
                HoverHandler { id: rh; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: root.openItem(row.modelData) }

                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    spacing: 10
                    Rectangle {
                        Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 10; clip: true
                        color: row.modelData.kind === "minecraft" ? Qt.alpha(Theme.green, 0.14) : (row.modelData.kind === "lutris" ? Qt.alpha(Theme.peach, 0.14) : Qt.alpha(Theme.sky, 0.14))
                        Image {
                            id: art
                            anchors { fill: parent; margins: row.modelData.kind === "minecraft" ? 3 : 0 }
                            asynchronous: true; sourceSize: Qt.size(96, 96)
                            fillMode: row.modelData.kind === "minecraft" ? Image.PreserveAspectFit : Image.PreserveAspectCrop
                            source: row.modelData.kind === "minecraft" ? (row.modelData.icon ? "file://" + row.modelData.icon : "")
                                                                      : (row.modelData.header ? "file://" + row.modelData.header : "")
                            visible: status === Image.Ready
                        }
                        Text {
                            visible: art.status !== Image.Ready; anchors.centerIn: parent
                            text: row.modelData.kind === "minecraft" ? "󰍳" : (row.modelData.kind === "lutris" ? "󰊗" : "󰓓")
                            color: row.modelData.kind === "minecraft" ? root.accent : (row.modelData.kind === "lutris" ? Theme.peach : Theme.sky); font { family: root.font; pixelSize: 18 }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        Text { text: row.modelData.name; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true
                               textFormat: Text.PlainText; font { family: root.font; pixelSize: 12; bold: true } }
                        Text { text: row.modelData.sub + "  ·  " + root.ago(row.modelData.at, root.tick); color: Theme.dim; elide: Text.ElideRight; Layout.fillWidth: true
                               textFormat: Text.PlainText; font { family: root.font; pixelSize: 10 } }
                    }
                    Text { visible: row.modelData.running; text: "● running"; color: Theme.green; font { family: root.font; pixelSize: 10 } }
                    Rectangle {
                        Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 17
                        color: pa.containsMouse ? Qt.lighter(Theme.green, 1.1) : Theme.green
                        opacity: row.modelData.running ? 0.4 : 1
                        Text { anchors.centerIn: parent; text: "󰐊"; color: Theme.crust; font { family: root.font; pixelSize: 18 } }
                        MouseArea { id: pa; anchors.fill: parent; hoverEnabled: true; enabled: !row.modelData.running; cursorShape: Qt.PointingHandCursor
                                    onClicked: root.play(row.modelData) }
                    }
                }
            }

            Text {
                visible: list.count === 0
                anchors.centerIn: parent
                text: "No games found yet."; color: Theme.dim; font { family: root.font; pixelSize: 12 }
            }
        }
    }

    // ───────── launchers ─────────
    Minecraft {
        id: mcTab
        embedded: true
        visible: root.tab === "minecraft"
        bar: root.bar
        anchors { top: sep.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: parent.bottom }
    }
    Ckan {
        id: kspTab
        embedded: true
        visible: root.tab === "ksp"
        bar: root.bar
        anchors { top: sep.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: parent.bottom }
    }
    Lutris {
        id: lutrisTab
        embedded: true
        visible: root.tab === "lutris"
        bar: root.bar
        anchors { top: sep.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: parent.bottom }
    }
    Steam {
        id: steamTab
        embedded: true
        visible: root.tab === "steam"
        bar: root.bar
        anchors { top: sep.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: parent.bottom }
    }
}
