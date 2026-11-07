import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Mod manager for one Prism instance: see/enable/disable installed mods and install more from
// Modrinth. All the work is done by mods.sh. Covers the Minecraft applet while open.
Item {
    id: root
    required property var bar
    property var instance: null
    signal back

    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.green

    property string tab: "installed"           // installed | browse
    property var    mods: []
    property var    projects: []
    property string mc: ""
    property var    loaders: []
    property string dir: ""
    property bool   loaded: false
    property string filter: ""
    property string status: ""
    property bool   statusErr: false
    property string armedFile: ""              // a mod waiting for a second click (disabling something others need)

    // browse
    property var    hits: []
    property int    total: 0
    property string searched: ""               // query the current hits belong to
    property var    plan: null                 // { project, title, items, bytes } waiting for confirmation
    property string installing: ""

    // updates and saved lists
    property var    updates: []                // [{file, name, current, latest, ...}] mods with a newer version
    property bool   checkedUpdates: false
    property string updating: ""               // file being updated, or "all"
    property bool   listsOpen: false
    property var    saved: []                  // [{name, count, mc, loaders}]
    property string listBusy: ""

    function say(msg, err) { status = msg; statusErr = !!err; statusTimer.restart() }
    Timer { id: statusTimer; interval: 6000; onTriggered: root.status = "" }
    function instId() { return instance ? instance.id : "" }
    function loaderText() { return loaders.length ? loaders[0].charAt(0).toUpperCase() + loaders[0].slice(1) : "no loader" }

    Job { id: listJob;    script: Quickshell.shellPath("mods.sh") }
    Job { id: toggleJob;  script: Quickshell.shellPath("mods.sh") }
    Job { id: searchJob;  script: Quickshell.shellPath("mods.sh") }
    Job { id: planJob;    script: Quickshell.shellPath("mods.sh") }
    Job { id: installJob; script: Quickshell.shellPath("mods.sh") }
    Job { id: updJob;     script: Quickshell.shellPath("mods.sh") }
    Job { id: listsJob;   script: Quickshell.shellPath("mods.sh") }
    Job { id: listActJob; script: Quickshell.shellPath("mods.sh") }
    Process { id: openProc; onExited: running = false }

    function open() {
        tab = "installed"; filter = ""; armedFile = ""; plan = null; hits = []; total = 0; searched = ""; loaded = false
        updates = []; checkedUpdates = false; listsOpen = false
        input.text = ""
        reload()
    }
    function testBrowse(q) { tab = "browse"; input.text = q }       // used for testing from the command line
    function testPlan() { if (hits.length) askInstall(hits[0]) }
    function reload() {
        if (!instId()) return
        listJob.go(["list", instId()], r => {
            if (r && r.error) { say(r.error, true); return }
            if (r) { mods = r.mods; projects = r.projects; mc = r.mc; loaders = r.loaders; dir = r.dir; loaded = true }
        })
        checkUpdates(false)
    }
    function checkUpdates(fresh) {
        if (!instId()) return
        var id = instId()
        updJob.go(["updates", id, fresh ? "fresh" : ""], r => {
            if (id !== instId()) return
            if (r && r.items) { updates = r.items; checkedUpdates = true }
        })
    }
    function updateFor(m) { return updates.find(u => u.file === m.file) || null }
    function updateOne(m) {
        var u = updateFor(m)
        if (!u || updating !== "") return
        updating = m.file
        say("updating " + u.name + "…", false)
        listActJob.go(["update", instId(), m.file], r => {
            updating = ""
            if (r && r.ok) say("updated " + r.name + " to " + r.version + (instance && instance.running ? " (applies next launch)" : ""), false)
            else say(r && r.error ? r.error : "update failed", true)
            reload(); checkUpdates(true)
        })
    }
    function updateAll() {
        if (updates.length === 0 || updating !== "") return
        updating = "all"
        say("updating " + updates.length + " mods…", false)
        listActJob.go(["updateall", instId()], r => {
            updating = ""
            if (r && r.ok) say("updated " + r.updated.length + (r.failed.length ? ", " + r.failed.length + " failed: " + r.failed[0] : "") , r.failed.length > 0)
            else say(r && r.error ? r.error : "update failed", true)
            reload(); checkUpdates(true)
        })
    }

    // ── Saved mod lists ───────────────────────────────────
    function openLists() { listsOpen = true; loadLists() }
    function loadLists() { listsJob.go(["lists"], r => { if (Array.isArray(r)) saved = r }) }
    function saveList(name) {
        if (!name.trim() || listBusy !== "") return
        listBusy = "save"
        say("saving the list…", false)
        listActJob.go(["save", instId(), name.trim()], r => {
            listBusy = ""
            if (r && r.ok) say("saved “" + r.name + "” (" + r.count + " mods" + (r.unknown ? ", " + r.unknown + " not on Modrinth were left out" : "") + ")", false)
            else say(r && r.error ? r.error : "could not save", true)
            loadLists()
        })
    }
    function applyList(name) {
        if (listBusy !== "") return
        listBusy = "apply"
        say("installing “" + name + "” — this can take a minute…", false)
        listActJob.go(["apply", instId(), name], r => {
            listBusy = ""
            if (r && r.ok) say("installed " + r.installed + " mods" + (r.skipped ? ", " + r.skipped + " already there" : "") + (r.failed.length ? ", " + r.failed.length + " had no matching version" : ""), r.failed.length > 0)
            else say(r && r.error ? r.error : "could not apply the list", true)
            listsOpen = false
            reload()
        })
    }
    function dropList(name) { listActJob.go(["droplist", name], r => loadLists()) }

    // ── Installed ─────────────────────────────────────────
    readonly property var ignoredDeps: ["minecraft", "java", "fabricloader", "fabric-loader", "quilt_loader", "quilt-loader", "fabric", "forge", "neoforge"]
    // mod id (or an id it provides) -> names of enabled mods that depend on it
    readonly property var neededBy: {
        var provider = {}
        mods.forEach(m => { provider[m.id] = m.id; (m.provides || []).forEach(p => provider[p] = m.id) })
        var out = {}
        mods.forEach(m => {
            if (!m.enabled) return
            ;(m.depends || []).forEach(d => {
                if (ignoredDeps.indexOf(d) >= 0 || !provider[d] || provider[d] === m.id) return
                var key = provider[d]
                ;(out[key] = out[key] || []).push(m.name)
            })
        })
        return out
    }
    readonly property var shownMods: {
        var q = filter.trim().toLowerCase()
        var list = q ? mods.filter(m => (m.name + " " + m.id + " " + m.file + " " + m.desc).toLowerCase().indexOf(q) >= 0) : mods
        return list.filter(m => m.enabled).concat(list.filter(m => !m.enabled))
    }
    readonly property int enabledCount: mods.filter(m => m.enabled).length

    function toggle(m) {
        var needed = m.enabled ? (neededBy[m.id] || []) : []
        if (needed.length > 0 && armedFile !== m.file) { armedFile = m.file; armTimer.restart(); return }
        armedFile = ""
        if (instance && instance.running) say("the game is running — this applies the next time you launch it", false)
        toggleJob.go(["toggle", instId(), m.file], r => {
            if (r && r.error) say(r.error, true)
            else if (!(instance && instance.running)) say((m.enabled ? "disabled " : "enabled ") + m.name, false)
            reload()
        })
    }
    Timer { id: armTimer; interval: 5000; onTriggered: root.armedFile = "" }

    // ── Browse / install ──────────────────────────────────
    Timer { id: searchTimer; interval: 450; onTriggered: root.runSearch(0) }
    function runSearch(offset) {
        var q = filter.trim()
        if (!searchJob.go(["search", instId(), q, String(offset)], r => {
            if (!r) { say("no answer from Modrinth", true); return }
            if (r.error) { say(r.error, true); return }
            hits = offset > 0 ? hits.concat(r.hits) : r.hits
            total = r.total; searched = q
        })) searchTimer.restart()
    }
    function isInstalled(h) {
        if (projects.indexOf(h.id) >= 0) return true
        return mods.some(m => m.id === h.slug || (m.provides || []).indexOf(h.slug) >= 0)
    }
    function askInstall(h) {
        say("looking up " + h.title + "…", false)
        planJob.go(["plan", instId(), h.id], r => {
            if (!r || r.error) { say(r && r.error ? r.error : "could not look that up", true); return }
            if (!r.items.length || r.items[0].missing) { say(h.title + " has no version for " + mc + " " + loaderText(), true); return }
            status = ""
            plan = { project: h.id, title: h.title, items: r.items, bytes: r.bytes }
        })
    }
    function confirmInstall() {
        if (!plan) return
        var p = plan
        plan = null
        installing = p.project
        say("installing " + p.title + "…", false)
        installJob.go(["install", instId(), p.project], r => {
            installing = ""
            if (r && r.ok) {
                var n = r.installed.length
                say("installed " + p.title + (n > 1 ? " + " + (n - 1) + " dependenc" + (n === 2 ? "y" : "ies") : ""), false)
                reload()
            } else say(r && r.error ? r.error : "install failed", true)
        })
    }
    function sizeText(b) { return b >= 1e6 ? (b / 1e6).toFixed(1) + " MB" : Math.max(1, Math.round(b / 1e3)) + " KB" }
    function countText(n) { return n >= 1e6 ? (n / 1e6).toFixed(n >= 1e7 ? 0 : 1) + "M" : n >= 1e3 ? Math.round(n / 1e3) + "K" : String(n) }

    // ══ UI ═══════════════════════════════════════════════
    Rectangle { anchors.fill: parent; color: Theme.panel }   // covers the instance page underneath

    AppHeader {
        id: head
        bar: root.bar; icon: "󰏖"; title: "Mods"; accent: root.accent
        anchors { top: parent.top; left: parent.left; right: parent.right }
        onBack: root.back()
        Text {
            visible: root.status.length > 0
            text: root.status; color: root.statusErr ? Theme.red : Theme.green
            elide: Text.ElideRight; width: Math.min(implicitWidth, 300)
            font { family: root.font; pixelSize: 11 }
        }
        Text {
            text: "lists"; color: root.accent; font { family: root.font; pixelSize: 11 }
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.openLists() }
        }
        Text {
            text: "open folder"; color: Theme.dim; font { family: root.font; pixelSize: 11 }
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                        onClicked: { if (root.dir) { openProc.command = ["xdg-open", root.dir]; openProc.running = true } } }
        }
    }
    Text {
        id: sub
        anchors { top: head.bottom; left: parent.left; leftMargin: 16 }
        text: (root.instance ? root.instance.display : "") + "  ·  Minecraft " + root.mc + "  ·  " + root.loaderText()
        color: Theme.dim; font { family: root.font; pixelSize: 10 }
        elide: Text.ElideRight; width: parent.width - 32
    }
    Rectangle { id: sep; anchors { top: sub.bottom; topMargin: 6; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 } height: 1; color: Theme.sep }

    Row {
        id: tabs
        anchors { top: sep.bottom; topMargin: 10; left: parent.left; leftMargin: 14 }
        spacing: 6
        Repeater {
            model: [["installed", "Installed"], ["browse", "Get more"]]
            delegate: Rectangle {
                id: tb
                required property var modelData
                width: 120; height: 28; radius: 9
                color: root.tab === modelData[0] ? Qt.alpha(Theme.green, 0.16) : "transparent"
                border { color: root.tab === modelData[0] ? Qt.alpha(Theme.green, 0.4) : Theme.cardBorder; width: 1 }
                Text { anchors.centerIn: parent; text: tb.modelData[1]; color: root.tab === tb.modelData[0] ? root.accent : Theme.dim; font { family: root.font; pixelSize: 11 } }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.tab = tb.modelData[0]; root.armedFile = ""; input.text = ""; root.filter = ""
                        if (root.tab === "browse" && root.hits.length === 0) root.runSearch(0)
                        input.forceActiveFocus()
                    }
                }
            }
        }
    }
    Rectangle {
        visible: root.tab === "installed" && root.updates.length > 0
        anchors { verticalCenter: tabs.verticalCenter; right: parent.right; rightMargin: 14 }
        height: 26; width: updTxt.implicitWidth + 24; radius: 13
        color: updArea.containsMouse ? Qt.lighter(Theme.yellow, 1.1) : Theme.yellow
        opacity: root.updating === "" ? 1 : 0.6
        Text { id: updTxt; anchors.centerIn: parent; color: Theme.crust; font { family: root.font; pixelSize: 10; bold: true }
               text: root.updating === "all" ? "updating…" : "󰚰 Update all (" + root.updates.length + ")" }
        MouseArea { id: updArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.updateAll() }
    }
    Text {
        visible: !(root.tab === "installed" && root.updates.length > 0)
        anchors { verticalCenter: tabs.verticalCenter; right: parent.right; rightMargin: 16 }
        text: root.tab === "installed" ? (root.enabledCount + " enabled  ·  " + (root.mods.length - root.enabledCount) + " disabled")
                                       : (root.total > 0 ? root.total + " compatible mods" : "")
        color: Theme.dim; font { family: root.font; pixelSize: 10 }
    }

    // search / filter box
    Rectangle {
        id: box
        anchors { top: tabs.bottom; topMargin: 10; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 }
        height: 34; radius: 10
        color: Qt.alpha(Theme.mauve, 0.07)
        border { color: input.activeFocus ? Qt.alpha(Theme.green, 0.45) : Theme.sep; width: 1 }
        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            spacing: 8
            Text { text: root.tab === "browse" ? "󰍉" : "󰈲"; color: input.activeFocus ? root.accent : Theme.dim; font { family: root.font; pixelSize: 14 } }
            TextInput {
                id: input
                Layout.fillWidth: true; color: Theme.text; clip: true
                font { family: root.font; pixelSize: 12 }
                onTextChanged: { root.filter = text; if (root.tab === "browse") searchTimer.restart() }
                Keys.onReturnPressed: { if (root.tab === "browse") { searchTimer.stop(); root.runSearch(0) } }
                Keys.onEscapePressed: { if (text.length > 0) text = ""; else root.back() }
                Text {
                    visible: input.text.length === 0; anchors.verticalCenter: parent.verticalCenter
                    text: root.tab === "browse" ? "search Modrinth for " + root.mc + " " + root.loaderText() + " mods (empty = most popular)" : "filter installed mods"
                    color: Theme.dim; font { family: root.font; pixelSize: 11 }
                }
            }
            Text { visible: input.text.length > 0; text: "✕"; color: Theme.dim; font { family: root.font; pixelSize: 11 }
                   MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: input.text = "" } }
        }
    }

    component Switch: Rectangle {
        id: sw
        property bool on: false
        signal flipped
        width: 38; height: 22; radius: 11
        color: on ? root.accent : Qt.alpha(Theme.mauve, 0.16)
        Behavior on color { ColorAnimation { duration: 120 } }
        Rectangle {
            y: 3; x: sw.on ? parent.width - width - 3 : 3; width: 16; height: 16; radius: 8
            color: sw.on ? Theme.crust : Theme.subtext
            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
        MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: sw.flipped() }
    }

    // ── installed list ────────────────────────────────────
    ListView {
        id: installedList
        visible: root.tab === "installed"
        anchors { top: box.bottom; topMargin: 10; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 12 }
        clip: true; spacing: 4; boundsBehavior: Flickable.StopAtBounds
        model: root.shownMods

        delegate: Rectangle {
            id: mr
            required property var modelData
            readonly property var needs: root.neededBy[modelData.id] || []
            readonly property bool armed: root.armedFile === modelData.file
            width: installedList.width
            height: Math.max(52, mcol.implicitHeight + 16)
            radius: 10
            color: mh.hovered ? Qt.alpha(Theme.green, 0.08) : Theme.card
            border { color: armed ? Theme.yellow : Theme.cardBorder; width: 1 }
            opacity: modelData.enabled ? 1 : 0.6
            HoverHandler { id: mh }

            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 12; topMargin: 6; bottomMargin: 6 }
                spacing: 10
                Rectangle {
                    Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 8; clip: true
                    color: Qt.alpha(Theme.green, 0.10)
                    Image {
                        id: ic
                        anchors.fill: parent; asynchronous: true; fillMode: Image.PreserveAspectFit; smooth: false
                        sourceSize: Qt.size(68, 68)
                        source: mr.modelData.icon ? "file://" + mr.modelData.icon : ""
                        visible: status === Image.Ready
                    }
                    Text { visible: ic.status !== Image.Ready; anchors.centerIn: parent; text: "󰏖"; color: root.accent; font { family: root.font; pixelSize: 16 } }
                }
                ColumnLayout {
                    id: mcol
                    Layout.fillWidth: true; spacing: 1
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text { text: mr.modelData.name; color: Theme.text; elide: Text.ElideRight; Layout.maximumWidth: 250
                               textFormat: Text.PlainText; font { family: root.font; pixelSize: 12; bold: true } }
                        Text { text: mr.modelData.version; color: Theme.dim; elide: Text.ElideRight; Layout.fillWidth: true
                               textFormat: Text.PlainText; font { family: root.font; pixelSize: 10 } }
                    }
                    Text {
                        visible: !mr.armed
                        text: mr.modelData.desc || mr.modelData.file
                        color: Theme.dim; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText
                        font { family: root.font; pixelSize: 10 }
                    }
                    Text {
                        visible: mr.armed
                        text: "Needed by " + mr.needs.slice(0, 3).join(", ") + (mr.needs.length > 3 ? " +" + (mr.needs.length - 3) : "") + " — click again to disable anyway"
                        color: Theme.yellow; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText
                        font { family: root.font; pixelSize: 10 }
                    }
                }
                Rectangle {
                    readonly property var upd: root.updateFor(mr.modelData)
                    visible: upd !== null
                    Layout.preferredHeight: 22; Layout.preferredWidth: chipTxt.implicitWidth + 16; radius: 11
                    color: chipArea.containsMouse ? Qt.alpha(Theme.yellow, 0.35) : Qt.alpha(Theme.yellow, 0.18)
                    border { color: Qt.alpha(Theme.yellow, 0.6); width: 1 }
                    Text { id: chipTxt; anchors.centerIn: parent; color: Theme.yellow; font { family: root.font; pixelSize: 9; bold: true }
                           text: root.updating === mr.modelData.file ? "…" : "󰚰 " + (parent.upd ? parent.upd.latest : "") }

                    MouseArea { id: chipArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.updateOne(mr.modelData) }
                }
                Text {
                    visible: mr.needs.length > 0 && mr.modelData.enabled && !mr.armed
                    text: "󰌷 " + mr.needs.length; color: Theme.dim; font { family: root.font; pixelSize: 10 }
                }
                Switch { on: mr.modelData.enabled; onFlipped: root.toggle(mr.modelData) }
            }
        }

        Text {
            visible: installedList.count === 0
            anchors.centerIn: parent
            text: !root.loaded ? "reading mods…" : (root.mods.length === 0 ? "No mods in this instance yet — try “Get more”" : "No matches")
            color: Theme.dim; font { family: root.font; pixelSize: 11 }
        }
    }

    // ── browse list ───────────────────────────────────────
    ListView {
        id: browseList
        visible: root.tab === "browse"
        anchors { top: box.bottom; topMargin: 10; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 12 }
        clip: true; spacing: 4; boundsBehavior: Flickable.StopAtBounds
        model: root.hits
        footer: Item {
            width: browseList.width; height: root.hits.length < root.total ? 44 : 0
            visible: root.hits.length < root.total
            Rectangle {
                anchors.centerIn: parent; width: 140; height: 30; radius: 9; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                Text { anchors.centerIn: parent; text: searchJob.running ? "loading…" : "load more"; color: Theme.text; font { family: root.font; pixelSize: 11 } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.runSearch(root.hits.length) }
            }
        }

        delegate: Rectangle {
            id: hr
            required property var modelData
            readonly property bool have: root.isInstalled(modelData)
            readonly property bool busy: root.installing === modelData.id
            width: browseList.width
            height: Math.max(60, hcol.implicitHeight + 16)
            radius: 10
            color: hh.hovered ? Qt.alpha(Theme.green, 0.08) : Theme.card
            border { color: Theme.cardBorder; width: 1 }
            HoverHandler { id: hh }
            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 12; topMargin: 6; bottomMargin: 6 }
                spacing: 10
                Rectangle {
                    Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 9; clip: true
                    color: Qt.alpha(Theme.green, 0.10)
                    Image {
                        id: hic
                        anchors.fill: parent; asynchronous: true; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(80, 80)
                        source: hr.modelData.icon || ""; visible: status === Image.Ready
                    }
                    Text { visible: hic.status !== Image.Ready; anchors.centerIn: parent; text: "󰏖"; color: root.accent; font { family: root.font; pixelSize: 18 } }
                }
                ColumnLayout {
                    id: hcol
                    Layout.fillWidth: true; spacing: 1
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text { text: hr.modelData.title; color: Theme.text; elide: Text.ElideRight; Layout.maximumWidth: 230
                               textFormat: Text.PlainText; font { family: root.font; pixelSize: 12; bold: true } }
                        Text { text: "by " + hr.modelData.author; color: Theme.dim; elide: Text.ElideRight; Layout.fillWidth: true
                               textFormat: Text.PlainText; font { family: root.font; pixelSize: 10 } }
                        Text { text: "󰇚 " + root.countText(hr.modelData.downloads); color: Theme.dim; font { family: root.font; pixelSize: 10 } }
                    }
                    Text { text: hr.modelData.desc; color: Theme.subtext; Layout.fillWidth: true; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                           textFormat: Text.PlainText; font { family: root.font; pixelSize: 10 } }
                }
                Rectangle {
                    Layout.preferredWidth: 84; Layout.preferredHeight: 30; radius: 9
                    color: hr.have ? "transparent" : (ba.containsMouse ? Qt.lighter(root.accent, 1.1) : root.accent)
                    border { color: hr.have ? Theme.cardBorder : root.accent; width: 1 }
                    Text {
                        anchors.centerIn: parent
                        text: hr.have ? "󰄬 Installed" : (hr.busy ? "…" : "Install")
                        color: hr.have ? Theme.dim : Theme.crust
                        font { family: root.font; pixelSize: 11; bold: !hr.have }
                    }
                    MouseArea { id: ba; anchors.fill: parent; hoverEnabled: true; cursorShape: hr.have ? Qt.ArrowCursor : Qt.PointingHandCursor
                                enabled: !hr.have && !hr.busy && root.installing === ""; onClicked: root.askInstall(hr.modelData) }
                }
            }
        }

        Text {
            visible: browseList.count === 0
            anchors.centerIn: parent
            text: searchJob.running ? "searching Modrinth…" : "No results"
            color: Theme.dim; font { family: root.font; pixelSize: 11 }
        }
    }

    // ── saved lists ───────────────────────────────────────
    MouseArea { anchors.fill: parent; visible: root.listsOpen; z: 20; onClicked: root.listsOpen = false }
    Rectangle {
        visible: root.listsOpen
        z: 21
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 14 }
        height: listsCol.implicitHeight + 28
        radius: 14; color: Qt.alpha(Theme.base, 0.99)
        border { color: root.accent; width: 1 }
        ColumnLayout {
            id: listsCol
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
            spacing: 8
            Text { text: "Saved mod lists"; color: Theme.text; font { family: root.font; pixelSize: 13; bold: true } }
            Text {
                Layout.fillWidth: true; wrapMode: Text.Wrap; color: Theme.dim; font { family: root.font; pixelSize: 10 }
                text: "A list remembers which Modrinth mods an instance has. Apply it to another instance to install the same mods there (for that instance's version and loader)."
            }
            Repeater {
                model: root.saved
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true; spacing: 8
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 0
                        Text { text: modelData.name; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 11; bold: true } }
                        Text { text: modelData.count + " mods  ·  Minecraft " + modelData.mc + (modelData.loaders.length ? "  ·  " + modelData.loaders[0] : ""); color: Theme.dim; font { family: root.font; pixelSize: 9 } }
                    }
                    Rectangle {
                        Layout.preferredWidth: 70; Layout.preferredHeight: 26; radius: 9; color: root.accent; opacity: root.listBusy === "" ? 1 : 0.5
                        Text { anchors.centerIn: parent; text: "Apply"; color: Theme.crust; font { family: root.font; pixelSize: 11; bold: true } }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.applyList(modelData.name) }
                    }
                    Text { text: "✕"; color: Theme.dim; font { family: root.font; pixelSize: 12 }
                           MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: root.dropList(modelData.name) } }
                }
            }
            Text { visible: root.saved.length === 0; text: "No saved lists yet."; color: Theme.dim; font { family: root.font; pixelSize: 11 } }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.cardBorder }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 32; radius: 9; color: Qt.alpha(Theme.mauve, 0.07)
                    border { color: listInput.activeFocus ? Qt.alpha(root.accent, 0.5) : Theme.sep; width: 1 }
                    TextInput {
                        id: listInput
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text; clip: true; font { family: root.font; pixelSize: 11 }
                        Keys.onReturnPressed: { root.saveList(text); text = "" }
                        Text { visible: listInput.text.length === 0; anchors.verticalCenter: parent.verticalCenter; text: "name for this instance's list"; color: Theme.dim; font { family: root.font; pixelSize: 11 } }
                    }
                }
                Rectangle {
                    Layout.preferredWidth: 110; Layout.preferredHeight: 32; radius: 9; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                    opacity: listInput.text.trim().length > 0 && root.listBusy === "" ? 1 : 0.5
                    Text { anchors.centerIn: parent; text: root.listBusy === "save" ? "saving…" : "Save current"; color: Theme.text; font { family: root.font; pixelSize: 11 } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.saveList(listInput.text); listInput.text = "" } }
                }
            }
        }
    }

    // ── install confirmation ──────────────────────────────
    MouseArea { anchors.fill: parent; visible: root.plan !== null; z: 20; onClicked: root.plan = null }
    Rectangle {
        visible: root.plan !== null
        z: 21
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 14 }
        height: planCol.implicitHeight + 28
        radius: 14; color: Qt.alpha(Theme.base, 0.99)
        border { color: root.accent; width: 1 }
        ColumnLayout {
            id: planCol
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
            spacing: 8
            Text { text: root.plan ? "Install " + root.plan.title + "?" : ""; color: Theme.text; font { family: root.font; pixelSize: 13; bold: true } }
            Repeater {
                model: root.plan ? root.plan.items : []
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true; spacing: 8
                    Text { text: modelData.required ? "󰁞 needed" : "󰏖"; color: modelData.required ? Theme.yellow : root.accent; font { family: root.font; pixelSize: 10 } }
                    Text { text: modelData.title + (modelData.version ? "  " + modelData.version : ""); color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true
                           textFormat: Text.PlainText; font { family: root.font; pixelSize: 11 } }
                    Text { text: modelData.missing ? "no version for " + root.mc : root.sizeText(modelData.size || 0); color: modelData.missing ? Theme.red : Theme.dim; font { family: root.font; pixelSize: 10 } }
                }
            }
            Text { text: root.plan ? "Downloads " + root.sizeText(root.plan.bytes) + " from Modrinth (checksum verified) into this instance's mods folder." : ""
                   color: Theme.dim; wrapMode: Text.Wrap; Layout.fillWidth: true; font { family: root.font; pixelSize: 10 } }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 32; radius: 10; color: root.accent
                    Text { anchors.centerIn: parent; text: "Install"; color: Theme.crust; font { family: root.font; pixelSize: 12; bold: true } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.confirmInstall() }
                }
                Rectangle {
                    Layout.preferredWidth: 90; Layout.preferredHeight: 32; radius: 10; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                    Text { anchors.centerIn: parent; text: "Cancel"; color: Theme.text; font { family: root.font; pixelSize: 12 } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.plan = null }
                }
            }
        }
    }
}
