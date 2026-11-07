import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Kerbal Space Program through CKAN: pick the game install, see/remove/upgrade installed mods,
// search and install more, and launch the game. All work is done by ckan.sh (the `ckan` command).
Item {
    id: root
    required property var bar
    property bool embedded: false
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.red

    property var    st: null                    // ckan.sh status
    property bool   loaded: false
    property string tab: "installed"            // installed | browse
    property var    installed: []               // [{flag,id,version}]
    property var    results: []                 // search / featured results
    property bool   showingFeatured: true
    property string query: ""
    property var    details: ({})               // id -> ckan.sh show result
    property string expanded: ""
    property string busyWhat: ""                // text of a running install/remove/upgrade
    property string armedRemove: ""
    property bool   menuOpen: false
    property string status: ""
    property bool   statusErr: false
    property int    tick: 0

    function say(msg, err) { status = msg; statusErr = !!err; statusTimer.restart() }
    Timer { id: statusTimer; interval: 6000; onTriggered: root.status = "" }

    Job { id: statusJob;   script: Quickshell.shellPath("ckan.sh") }
    Job { id: updateJob;   script: Quickshell.shellPath("ckan.sh") }
    Job { id: listJob;     script: Quickshell.shellPath("ckan.sh") }
    Job { id: searchJob;   script: Quickshell.shellPath("ckan.sh") }
    Job { id: actJob;      script: Quickshell.shellPath("ckan.sh") }
    Job { id: showJob;     script: Quickshell.shellPath("ckan.sh") }
    Job { id: addJob;      script: Quickshell.shellPath("ckan.sh") }
    Job { id: launchJob;   script: Quickshell.shellPath("ckan.sh") }
    Process { id: openProc; onExited: running = false }
    function open(u) { if (/^https?:\/\//.test(u)) { openProc.command = ["xdg-open", u]; openProc.running = true } }

    readonly property var  instances: (st && st.instances) ? st.instances : []
    readonly property var  steamInfo: (st && st.steam) ? st.steam : ({ found: false, path: "", added: false })
    readonly property bool hasInstance: instances.length > 0
    readonly property var  current: hasInstance ? (instances.find(i => i.default) || instances[0]) : null
    readonly property bool hasCatalog: !!(st && st.catalog && st.catalog.at > 0)
    readonly property var installedIds: installed.map(m => m.id)

    function showBrowse() { tab = "browse"; if (results.length === 0) loadFeatured() }
    function activate() {
        tick++; menuOpen = false; armedRemove = ""
        statusJob.go(["status"], r => {
            if (!r) { st = { ckan: false, error: "no answer" }; loaded = true; return }
            if (r.error) { st = { ckan: false, error: r.error }; loaded = true; return }
            st = r; loaded = true
            if (hasInstance) { loadInstalled(); if (hasCatalog && results.length === 0) loadFeatured() }
        })
    }
    function loadInstalled() {
        listJob.go(["installed"], r => {
            if (!Array.isArray(r)) return
            installed = r
            // remembered so the Games tab can show an "updates" badge before this tab is ever opened
            root.bar.school.setPref("kspUpgrades", r.filter(m => !!m.upgrade).length)
            root.bar.school.setPref("kspChecked", Date.now())
        })
    }
    readonly property int upgradeCount: installed.filter(m => !!m.upgrade).length
    // called when the Games panel opens: look for upgrades in the background, at most every 6 hours
    function quickRefresh() {
        if (root.bar.school.pref("kspChecked", 0) > Date.now() - 6 * 3600000) return
        statusJob.go(["status"], r => { if (r && !r.error && r.instances && r.instances.length) loadInstalled() })
    }
    function loadFeatured() {
        showingFeatured = true
        searchJob.go(["featured"], r => { if (Array.isArray(r)) results = r })
    }
    function runSearch() {
        var q = query.trim()
        if (q.length < 2) { loadFeatured(); return }
        showingFeatured = false
        if (!searchJob.go(["search", q], r => {
            if (Array.isArray(r)) results = r
            else if (r && r.error) say(r.error, true)
        })) searchTimer.restart()
    }
    Timer { id: searchTimer; interval: 450; onTriggered: root.runSearch() }

    function updateCatalog() {
        if (updateJob.running) return
        say("downloading the mod catalog…", false)
        updateJob.go(["update"], r => {
            if (r && r.ok) { say("catalog updated (" + r.count + " mods)", false); activate() }
            else say(r && r.error ? r.error : "catalog update failed", true)
        })
    }
    function addFolder(name, path) {
        addJob.go(["add", name, path], r => {
            if (r && r.ok) { say("added " + name, false); activate() }
            else say(r && r.error ? r.error : "could not add that folder", true)
        })
    }
    function useInstance(name) { menuOpen = false; addJob.go(["default", name], r => { installed = []; activate() }) }

    function run(args, doing, done) {
        if (busyWhat) return
        busyWhat = doing
        say(doing + "…", false)
        actJob.go(args, r => {
            busyWhat = ""
            if (r && r.ok) { say(done, false); loadInstalled() }
            else say(r && r.error ? r.error : "that didn't work", true)
        })
    }
    function install(m) { run(["install", m.id], "installing " + m.name, "installed " + m.name) }
    function removeMod(m) {
        if (armedRemove !== m.id) { armedRemove = m.id; armTimer.restart(); return }
        armedRemove = ""
        run(["remove", m.id], "removing " + m.id, "removed " + m.id)
    }
    Timer { id: armTimer; interval: 4000; onTriggered: root.armedRemove = "" }
    function upgradeAll() { run(["upgrade"], "upgrading mods", "mods are up to date") }
    function play() {
        say("starting Kerbal Space Program…", false)
        launchJob.go(["launch"], r => { if (r && r.error) say(r.error, true) })
    }
    function toggleDetails(id) {
        expanded = expanded === id ? "" : id
        if (expanded && !details[id]) showJob.go(["show", id], r => { if (r && !r.error) { var d = Object.assign({}, details); d[id] = r; details = d } })
    }
    function agoText(sec, _t) {
        if (!sec) return "never"
        var h = Math.round((Date.now() / 1000 - sec) / 3600)
        return h < 1 ? "just now" : h < 48 ? h + "h ago" : Math.round(h / 24) + "d ago"
    }

    // ══ UI ═══════════════════════════════════════════════
    AppHeader {
        id: head
        compact: root.embedded
        bar: root.bar; icon: "󰑣"; title: "KSP"; accent: root.accent
        anchors { top: parent.top; left: parent.left; right: parent.right }
        onBack: root.bar.hubView = "main"
        Text {
            visible: root.status.length > 0
            text: root.status; color: root.statusErr ? Theme.red : Theme.green
            elide: Text.ElideRight; width: Math.min(implicitWidth, 300)
            font { family: root.font; pixelSize: 10 }
        }
        Text {
            visible: root.working
            text: "󰑐"; color: root.accent; font { family: root.font; pixelSize: 13 }
            RotationAnimator on rotation { running: root.working; from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
        }
        Text {
            visible: root.hasInstance && root.hasCatalog
            text: root.updateJobBusy ? "updating…" : "catalog " + root.agoText(root.st && root.st.catalog ? root.st.catalog.at : 0, root.tick) + "  󰑐"
            color: Theme.dim; font { family: root.font; pixelSize: 10 }
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.updateCatalog() }
        }
    }
    readonly property bool updateJobBusy: updateJob.running
    readonly property bool working: updateJob.running || actJob.running || searchJob.running || listJob.running

    // ───────── states without a usable setup ─────────
    ColumnLayout {
        id: setup
        visible: root.loaded && (!(root.st && root.st.ckan) || !root.hasInstance)
        anchors { top: head.bottom; topMargin: 8; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 }
        spacing: 10

        // CKAN itself missing
        Rectangle {
            visible: root.loaded && !(root.st && root.st.ckan)
            Layout.fillWidth: true; implicitHeight: m1.implicitHeight + 28; radius: 14; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
            ColumnLayout {
                id: m1
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
                spacing: 6
                Text { text: "CKAN isn't installed"; color: Theme.text; font { family: root.font; pixelSize: 13; bold: true } }
                Text { text: "CKAN is the mod manager for Kerbal Space Program. It's listed in your NixOS config (nixos/common.nix); rebuild to get it:"
                       color: Theme.dim; wrapMode: Text.Wrap; Layout.fillWidth: true; font { family: root.font; pixelSize: 10 } }
                Text { text: "sudo nixos-rebuild switch --flake ~/DotFiles/nixos#soda-fw"; color: root.accent; font { family: root.font; pixelSize: 10 } }
            }
        }

        // Steam copy found but not registered
        Rectangle {
            visible: root.loaded && !!(root.st && root.st.ckan) && root.steamInfo.found && !root.steamInfo.added
            Layout.fillWidth: true; implicitHeight: m2.implicitHeight + 28; radius: 14; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
            ColumnLayout {
                id: m2
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
                spacing: 8
                Text { text: "Kerbal Space Program found in Steam"; color: Theme.text; font { family: root.font; pixelSize: 13; bold: true } }
                Text { text: root.steamInfo.path; color: Theme.dim; elide: Text.ElideMiddle; Layout.fillWidth: true; font { family: root.font; pixelSize: 10 } }
                Rectangle {
                    Layout.preferredHeight: 36; Layout.fillWidth: true; radius: 11; color: Theme.green
                    Text { anchors.centerIn: parent; text: "Add it to CKAN"; color: Theme.crust; font { family: root.font; pixelSize: 12; bold: true } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.addFolder("KSP (Steam)", root.steamInfo.path) }
                }
            }
        }

        // nothing found
        Rectangle {
            visible: root.loaded && !!(root.st && root.st.ckan) && !root.steamInfo.found
            Layout.fillWidth: true; implicitHeight: m3.implicitHeight + 28; radius: 14; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
            ColumnLayout {
                id: m3
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
                spacing: 8
                Text { text: "Kerbal Space Program isn't installed yet"; color: Theme.text; font { family: root.font; pixelSize: 13; bold: true } }
                Text { text: "Install it from Steam and it shows up here automatically. If you already have a copy somewhere else, add its folder below."
                       color: Theme.dim; wrapMode: Text.Wrap; Layout.fillWidth: true; font { family: root.font; pixelSize: 10 } }
                Rectangle {
                    Layout.preferredHeight: 34; Layout.fillWidth: true; radius: 11; color: Qt.alpha(Theme.sky, 0.18); border { color: Theme.sky; width: 1 }
                    Text { anchors.centerIn: parent; text: "󰓓  Install KSP in Steam"; color: Theme.sky; font { family: root.font; pixelSize: 12; bold: true } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.open("https://store.steampowered.com/app/220200"); root.bar.hubOpen = false } }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 32; radius: 9; color: Qt.alpha(Theme.mauve, 0.07)
                        border { color: pathInput.activeFocus ? root.accent : Theme.sep; width: 1 }
                        TextInput {
                            id: pathInput
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            verticalAlignment: TextInput.AlignVCenter; color: Theme.text; clip: true; font { family: root.font; pixelSize: 11 }
                            Keys.onReturnPressed: { if (text.trim()) root.addFolder("KSP", text.trim()) }
                            Text { visible: pathInput.text.length === 0; anchors.verticalCenter: parent.verticalCenter; text: "/path/to/Kerbal Space Program"; color: Theme.dim; font { family: root.font; pixelSize: 11 } }
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 60; Layout.preferredHeight: 32; radius: 9; color: root.accent
                        Text { anchors.centerIn: parent; text: "Add"; color: Theme.crust; font { family: root.font; pixelSize: 11; bold: true } }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (pathInput.text.trim()) root.addFolder("KSP", pathInput.text.trim()) } }
                    }
                }
            }
        }
    }

    // ───────── normal view ─────────
    Item {
        id: main
        visible: root.loaded && !!(root.st && root.st.ckan) && root.hasInstance
        anchors { top: head.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: parent.bottom }

        // instance card + play
        Rectangle {
            id: instCard
            anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 }
            height: 64; radius: 14
            color: ia.containsMouse ? Qt.alpha(Theme.red, 0.10) : Theme.card
            border { color: root.menuOpen ? root.accent : Theme.cardBorder; width: 1 }
            MouseArea { id: ia; anchors.fill: parent; hoverEnabled: true; cursorShape: root.st && root.instances.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: { if (root.instances.length > 1) root.menuOpen = !root.menuOpen } }
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 12
                Rectangle {
                    Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 12; color: Qt.alpha(Theme.red, 0.16)
                    Text { anchors.centerIn: parent; text: "󰑣"; color: root.accent; font { family: root.font; pixelSize: 22 } }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 1
                    Text { text: root.current ? root.current.name : ""; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true
                           textFormat: Text.PlainText; font { family: root.font; pixelSize: 13; bold: true } }
                    Text { text: root.current ? "Kerbal Space Program " + root.current.version + "  ·  " + root.installed.length + " mod" + (root.installed.length === 1 ? "" : "s") : ""
                           color: Theme.dim; font { family: root.font; pixelSize: 10 } }
                }
                Text { visible: root.st && root.instances.length > 1; text: root.menuOpen ? "󰅃" : "󰅀"; color: Theme.dim; font { family: root.font; pixelSize: 16 } }
                Rectangle {
                    Layout.preferredWidth: 78; Layout.preferredHeight: 36; radius: 11
                    color: pa.containsMouse ? Qt.lighter(Theme.green, 1.1) : Theme.green
                    Text { anchors.centerIn: parent; text: "󰐊  Play"; color: Theme.crust; font { family: root.font; pixelSize: 12; bold: true } }
                    MouseArea { id: pa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.play() }
                }
            }
        }

        // catalog missing
        Rectangle {
            visible: !root.hasCatalog
            anchors { top: instCard.bottom; topMargin: 10; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 }
            implicitHeight: cm.implicitHeight + 28; radius: 14; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
            ColumnLayout {
                id: cm
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
                spacing: 8
                Text { text: "Download the mod catalog"; color: Theme.text; font { family: root.font; pixelSize: 13; bold: true } }
                Text { text: "CKAN needs its list of mods first (about 35 MB, from CKAN's servers)."; color: Theme.dim; wrapMode: Text.Wrap; Layout.fillWidth: true; font { family: root.font; pixelSize: 10 } }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 36; radius: 11; color: root.accent; opacity: root.updateJobBusy ? 0.5 : 1
                    Text { anchors.centerIn: parent; text: root.updateJobBusy ? "Downloading…" : "Download catalog"; color: Theme.crust; font { family: root.font; pixelSize: 12; bold: true } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.updateCatalog() }
                }
            }
        }

        // tabs
        Row {
            id: tabs
            visible: root.hasCatalog
            anchors { top: instCard.bottom; topMargin: 10; left: parent.left; leftMargin: 14 }
            spacing: 6
            Repeater {
                model: [["installed", "Installed"], ["browse", "Get mods"]]
                delegate: Rectangle {
                    id: tb
                    required property var modelData
                    width: 120; height: 28; radius: 9
                    color: root.tab === modelData[0] ? Qt.alpha(Theme.red, 0.16) : "transparent"
                    border { color: root.tab === modelData[0] ? Qt.alpha(Theme.red, 0.4) : Theme.cardBorder; width: 1 }
                    Text { anchors.centerIn: parent; text: tb.modelData[1]; color: root.tab === tb.modelData[0] ? root.accent : Theme.dim; font { family: root.font; pixelSize: 11 } }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { root.tab = tb.modelData[0]; root.expanded = ""; if (root.tab === "browse" && root.results.length === 0) root.loadFeatured() }
                    }
                }
            }
        }
        Row {
            visible: root.hasCatalog && root.tab === "installed" && root.installed.length > 0
            anchors { verticalCenter: tabs.verticalCenter; right: parent.right; rightMargin: 16 }
            spacing: 6
            Rectangle {
                width: upTxt.implicitWidth + 20; height: 26; radius: 8; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                Text { id: upTxt; anchors.centerIn: parent; text: "󰚰 upgrade all"; color: Theme.text; font { family: root.font; pixelSize: 10 } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.upgradeAll() }
            }
        }

        // search box (Get mods)
        Rectangle {
            id: box
            visible: root.hasCatalog && root.tab === "browse"
            anchors { top: tabs.bottom; topMargin: 8; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 }
            height: visible ? 34 : 0; radius: 10
            color: Qt.alpha(Theme.mauve, 0.07)
            border { color: input.activeFocus ? root.accent : Theme.sep; width: 1 }
            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                spacing: 8
                Text { text: "󰍉"; color: input.activeFocus ? root.accent : Theme.dim; font { family: root.font; pixelSize: 14 } }
                TextInput {
                    id: input
                    Layout.fillWidth: true; color: Theme.text; clip: true; font { family: root.font; pixelSize: 12 }
                    onTextChanged: { root.query = text; searchTimer.restart() }
                    Keys.onEscapePressed: { if (text.length > 0) text = ""; else root.bar.hubOpen = false }
                    Text { visible: input.text.length === 0; anchors.verticalCenter: parent.verticalCenter
                           text: "search mods for KSP " + (root.current ? root.current.version : "") + "  (empty = popular picks)"; color: Theme.dim; font { family: root.font; pixelSize: 11 } }
                }
                Text { visible: input.text.length > 0; text: "✕"; color: Theme.dim; font { family: root.font; pixelSize: 11 }
                       MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: input.text = "" } }
            }
        }

        // lists
        ListView {
            id: list
            visible: root.hasCatalog
            anchors {
                top: root.tab === "browse" ? box.bottom : tabs.bottom; topMargin: 8
                left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 12
            }
            clip: true; spacing: 4; boundsBehavior: Flickable.StopAtBounds
            model: root.tab === "installed" ? root.installed : root.results

            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property bool inst: root.tab === "installed"
                readonly property string mid: modelData.id
                readonly property bool have: root.installedIds.indexOf(mid) >= 0
                readonly property bool open: root.expanded === mid
                readonly property var det: root.details[mid]
                width: list.width
                height: Math.max(54, rcol.implicitHeight + 16)
                radius: 10
                color: rh.hovered ? Qt.alpha(Theme.red, 0.07) : Theme.card
                border { color: Theme.cardBorder; width: 1 }
                HoverHandler { id: rh; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: root.toggleDetails(row.mid) }

                RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12; topMargin: 8; bottomMargin: 8 }
                    spacing: 10
                    ColumnLayout {
                        id: rcol
                        Layout.fillWidth: true; spacing: 2
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Text { text: row.modelData.name || row.mid; color: Theme.text; elide: Text.ElideRight; Layout.maximumWidth: 250
                                   textFormat: Text.PlainText; font { family: root.font; pixelSize: 12; bold: true } }
                            Text { text: row.modelData.version; color: Theme.dim; elide: Text.ElideRight; Layout.fillWidth: true
                                   textFormat: Text.PlainText; font { family: root.font; pixelSize: 10 } }
                            Rectangle { visible: !!row.modelData.auto; width: depT.implicitWidth + 12; height: 16; radius: 8; color: Qt.alpha(Theme.sky, 0.16)
                                Text { id: depT; anchors.centerIn: parent; text: "dependency"; color: Theme.sky; font { family: root.font; pixelSize: 8 } } }
                            Rectangle { visible: !!row.modelData.upgrade; width: upT.implicitWidth + 12; height: 16; radius: 8; color: Qt.alpha(Theme.yellow, 0.2)
                                Text { id: upT; anchors.centerIn: parent; text: "update"; color: Theme.yellow; font { family: root.font; pixelSize: 8 } } }
                        }
                        Text { visible: !!row.modelData.author; text: "by " + row.modelData.author; color: Theme.dim; elide: Text.ElideRight; Layout.fillWidth: true
                               textFormat: Text.PlainText; font { family: root.font; pixelSize: 9 } }
                        Text { visible: !!row.modelData.abstract && !row.open; text: row.modelData.abstract || ""; color: Theme.subtext; wrapMode: Text.Wrap
                               maximumLineCount: 2; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 10 } }
                        // details
                        ColumnLayout {
                            visible: row.open
                            Layout.fillWidth: true; spacing: 3
                            Text { text: row.det ? row.det.summary : "loading…"; color: Theme.subtext; wrapMode: Text.Wrap; Layout.fillWidth: true
                                   textFormat: Text.PlainText; font { family: root.font; pixelSize: 10 } }
                            Text { visible: row.det && row.det.depends.length > 0; text: row.det ? "Needs: " + row.det.depends.join(", ") : ""; color: Theme.dim
                                   wrapMode: Text.Wrap; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 10 } }
                            Text { visible: row.det && row.det.license; text: row.det ? row.det.license + (row.det.tags ? "  ·  " + row.det.tags : "") : ""; color: Theme.dim
                                   wrapMode: Text.Wrap; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 9 } }
                            Text { visible: row.det && (row.det.home || row.det.repository); text: "󰖟 open page"; color: root.accent; font { family: root.font; pixelSize: 10 }
                                   MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                                               onClicked: root.open(row.det.repository || row.det.home) } }
                        }
                    }
                    // action
                    Rectangle {
                        Layout.preferredWidth: row.inst ? 84 : 84; Layout.preferredHeight: 30; Layout.alignment: Qt.AlignTop; radius: 9
                        readonly property bool armed: row.inst && root.armedRemove === row.mid
                        color: row.inst ? (armed ? Qt.alpha(Theme.red, 0.25) : "transparent") : (row.have ? "transparent" : root.accent)
                        border { color: row.inst ? (armed ? root.accent : Theme.cardBorder) : (row.have ? Theme.cardBorder : root.accent); width: 1 }
                        Text {
                            anchors.centerIn: parent
                            text: row.inst ? (parent.armed ? "Confirm" : "Remove") : (row.have ? "󰄬 Installed" : (root.busyWhat ? "…" : "Install"))
                            color: row.inst ? (parent.armed ? root.accent : Theme.dim) : (row.have ? Theme.dim : Theme.crust)
                            font { family: root.font; pixelSize: 11; bold: !row.inst && !row.have }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            enabled: root.busyWhat === "" && (row.inst || !row.have)
                            onClicked: { if (row.inst) root.removeMod({ id: row.mid }); else root.install({ id: row.mid, name: row.modelData.name || row.mid }) }
                        }
                    }
                }
            }

            Text {
                visible: list.count === 0
                anchors.centerIn: parent; horizontalAlignment: Text.AlignHCenter
                text: root.tab === "installed" ? (listJob.running ? "reading installed mods…\n(CKAN takes a few seconds)" : "No mods installed yet.\nOpen “Get mods” to add some.") : (searchJob.running ? "searching…\n(CKAN takes a few seconds)" : "No results")
                color: Theme.dim; font { family: root.font; pixelSize: 11 }
            }
        }
    }

    // instance picker (when several KSP installs are registered)
    MouseArea { anchors.fill: parent; visible: root.menuOpen; z: 20; onClicked: root.menuOpen = false }
    Rectangle {
        visible: root.menuOpen
        z: 21
        anchors { top: parent.top; topMargin: head.height + 4 + 64 + 6; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 }
        height: root.instances.length * 40 + 12
        radius: 12; color: Qt.alpha(Theme.base, 0.99); border { color: root.accent; width: 1 }
        Column {
            anchors { fill: parent; margins: 6 }
            spacing: 0
            Repeater {
                model: root.instances
                delegate: Rectangle {
                    id: ir
                    required property var modelData
                    width: parent.width; height: 40; radius: 8
                    color: ih.hovered ? Qt.alpha(Theme.red, 0.12) : "transparent"
                    HoverHandler { id: ih; cursorShape: Qt.PointingHandCursor }
                    MouseArea { anchors.fill: parent; onClicked: root.useInstance(ir.modelData.name) }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        Text { text: ir.modelData.name; color: Theme.text; font { family: root.font; pixelSize: 12 } }
                        Text { text: ir.modelData.version; color: Theme.dim; font { family: root.font; pixelSize: 10 } }
                        Item { Layout.fillWidth: true }
                        Text { visible: ir.modelData.default; text: "󰄬"; color: root.accent; font { family: root.font; pixelSize: 13 } }
                    }
                }
            }
        }
    }

    Text {
        visible: !root.loaded
        anchors.centerIn: parent
        text: "checking CKAN…"; color: Theme.dim; font { family: root.font; pixelSize: 11 }
    }
}
