import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// "New instance" wizard: name, Minecraft version, mod loader and a list of starter mods.
// create.sh makes the Prism instance; mods.sh then installs each chosen mod from Modrinth.
Item {
    id: root
    required property var bar
    signal back
    signal created(string id)

    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.green
    readonly property var loaderDefs: [
        { id: "fabric",   label: "Fabric" },
        { id: "quilt",    label: "Quilt" },
        { id: "neoforge", label: "NeoForge" },
        { id: "forge",    label: "Forge" },
        { id: "vanilla",  label: "Vanilla" }
    ]

    property string phase: "form"              // form | working | done
    property var    versions: []
    property string mc: ""
    property var    avail: ({})                // fabric/quilt/neoforge/forge -> loader version | null, java, javaPath
    property bool   loadingLoaders: false
    property string loader: "fabric"
    property var    presets: ({ fabric: [], neoforge: [], forge: [] })
    property var    picks: ({})                // slug -> bool
    property string name: ""
    property bool   nameEdited: false
    property bool   versionMenu: false
    property string error: ""

    // working / done
    property var    steps: []                  // { label, state: wait|run|ok|skip|fail, note }
    property string newId: ""
    property var    queue: []

    function loaderLabel(id) { var d = loaderDefs.find(x => x.id === id); return d ? d.label : id }
    function family(l) { return l === "quilt" ? "fabric" : l }
    function presetList() { return loader === "vanilla" ? [] : (presets[family(loader)] || []) }
    function autoName() { return "Minecraft " + mc + (loader === "vanilla" ? "" : " " + loaderLabel(loader)) }

    Job { id: verJob;    script: Quickshell.shellPath("create.sh") }
    Job { id: loadJob;   script: Quickshell.shellPath("create.sh") }
    Job { id: presetJob; script: Quickshell.shellPath("create.sh") }
    Job { id: createJob; script: Quickshell.shellPath("create.sh") }
    Job { id: modJob;    script: Quickshell.shellPath("mods.sh") }

    function demoDone() {   // for checking the layout only
        mc = "26.3"; loader = "fabric"; name = "Minecraft 26.3 Fabric"; newId = "demo"
        steps = [{ label: "Create the instance", state: "ok", note: "Java 25 set" },
                 { label: "Fabric API", state: "ok", note: "" }, { label: "Sodium", state: "ok", note: "" },
                 { label: "Lithium", state: "ok", note: "" }, { label: "Mod Menu", state: "ok", note: "+ 1 dependency" },
                 { label: "FerriteCore", state: "skip", note: "no version for 26.3 yet" },
                 { label: "Entity Culling", state: "run", note: "" }, { label: "ImmediatelyFast", state: "wait", note: "" }]
        phase = "working"
    }
    function open() {
        phase = "form"; error = ""; versionMenu = false; nameEdited = false; steps = []; newId = ""
        verJob.go(["versions"], r => {
            if (!Array.isArray(r)) { error = (r && r.error) || "could not load Minecraft versions"; return }
            versions = r
            if (r.length) pickVersion(r[0].version)
        })
        presetJob.go(["presets"], r => {
            if (r && !r.error) { presets = r; resetPicks() }
            else if (r && r.error) error = r.error
        })
    }
    function pickVersion(v) {
        mc = v; versionMenu = false; avail = ({}); loadingLoaders = true
        loadJob.go(["loaders", v], r => {
            loadingLoaders = false
            if (!r || r.error) { error = (r && r.error) || "could not check loaders"; return }
            avail = r
            // keep the chosen loader if it still exists, otherwise fall back
            if (loader !== "vanilla" && !r[loader]) {
                var first = ["fabric", "quilt", "neoforge", "forge"].find(l => r[l])
                setLoader(first || "vanilla")
            } else if (!nameEdited) name = autoName()
        })
    }
    function resetPicks() {
        var p = {}
        presetList().forEach(m => p[m.slug] = !!m.default)
        picks = p
    }
    function setLoader(l) {
        loader = l; resetPicks()
        if (!nameEdited) name = autoName()
    }
    function setAll(on) {
        var p = {}
        presetList().forEach(m => p[m.slug] = on)
        picks = p
    }
    function togglePick(slug) { var p = Object.assign({}, picks); p[slug] = !p[slug]; picks = p }
    readonly property int pickCount: presetList().filter(m => picks[m.slug]).length
    readonly property bool canCreate: name.trim().length > 0 && mc !== "" && !loadingLoaders && (loader === "vanilla" || !!avail[loader])

    // ── creating ──────────────────────────────────────────
    function setStep(i, state, note) {
        var s = steps.slice(); s[i] = Object.assign({}, s[i], { state: state, note: note || "" }); steps = s
    }
    function start() {
        if (!canCreate) return
        error = ""
        queue = presetList().filter(m => picks[m.slug])
        steps = [{ label: "Create the instance", state: "run", note: "" }]
                 .concat(queue.map(m => ({ label: m.label, state: "wait", note: "" })))
        phase = "working"
        createJob.go(["create", name.trim(), mc, loader], r => {
            if (!r || r.error) { setStep(0, "fail", r && r.error ? r.error : "failed"); phase = "done"; return }
            newId = r.id
            setStep(0, "ok", r.javaPath ? "Java " + r.javaMajor + " set" : (r.javaMajor ? "needs Java " + r.javaMajor + " (set it in Prism)" : ""))
            next(0)
        })
    }
    function next(i) {
        if (i >= queue.length) { phase = "done"; return }
        setStep(i + 1, "run")
        modJob.go(["install", newId, queue[i].slug], r => {
            if (r && r.ok) setStep(i + 1, "ok", r.installed.length > 1 ? "+ " + (r.installed.length - 1) + " dependency" : "")
            else {
                var e = (r && r.error) || "failed"
                setStep(i + 1, /no compatible version/.test(e) ? "skip" : "fail", /no compatible version/.test(e) ? "no version for " + mc + " yet" : e)
            }
            next(i + 1)
        })
    }
    readonly property int okMods: steps.slice(1).filter(s => s.state === "ok").length
    readonly property int skippedMods: steps.slice(1).filter(s => s.state === "skip" || s.state === "fail").length
    readonly property bool madeIt: steps.length > 0 && steps[0].state === "ok"

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

    // ══ UI ═══════════════════════════════════════════════
    Rectangle { anchors.fill: parent; color: Theme.panel }

    AppHeader {
        id: head
        bar: root.bar; icon: "󰐕"; title: "New instance"; accent: root.accent
        anchors { top: parent.top; left: parent.left; right: parent.right }
        onBack: { if (root.phase === "working") return; if (root.phase === "done" && root.madeIt) root.created(root.newId); else root.back() }
    }
    Rectangle { id: sep; anchors { top: head.bottom; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 } height: 1; color: Theme.sep }

    // ───────── form ─────────
    Flickable {
        id: form
        visible: root.phase === "form"
        anchors { top: sep.bottom; topMargin: 10; left: parent.left; right: parent.right; bottom: createBtn.top; leftMargin: 14; rightMargin: 14; bottomMargin: 10 }
        clip: true; contentHeight: fcol.implicitHeight; boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: fcol
            width: form.width; spacing: 12

            Text { visible: root.error.length > 0; text: root.error; color: Theme.red; wrapMode: Text.Wrap; Layout.fillWidth: true; font { family: root.font; pixelSize: 11 } }

            // name
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                Text { text: "NAME"; color: Theme.dim; font { family: root.font; pixelSize: 10; bold: true; letterSpacing: 1 } }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 10
                    color: Qt.alpha(Theme.mauve, 0.07)
                    border { color: nameInput.activeFocus ? root.accent : Theme.sep; width: 1 }
                    TextInput {
                        id: nameInput
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text; clip: true; maximumLength: 64
                        font { family: root.font; pixelSize: 13 }
                        text: root.name
                        onTextEdited: { root.name = text; root.nameEdited = true }
                        onActiveFocusChanged: { if (activeFocus) selectAll() }
                    }
                }
            }

            // version
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                Text { text: "MINECRAFT VERSION"; color: Theme.dim; font { family: root.font; pixelSize: 10; bold: true; letterSpacing: 1 } }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 40; radius: 10
                    color: vArea.containsMouse ? Qt.alpha(Theme.green, 0.10) : Theme.card
                    border { color: root.versionMenu ? root.accent : Theme.cardBorder; width: 1 }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        Text { text: root.mc || "loading…"; color: Theme.text; font { family: root.font; pixelSize: 13; bold: true } }
                        Text { visible: root.versions.length > 0 && root.mc === root.versions[0].version; text: "latest"; color: root.accent; font { family: root.font; pixelSize: 10 } }
                        Item { Layout.fillWidth: true }
                        Text { text: root.versionMenu ? "󰅃" : "󰅀"; color: Theme.dim; font { family: root.font; pixelSize: 16 } }
                    }
                    MouseArea { id: vArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.versionMenu = !root.versionMenu }
                }
            }

            // loader
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "MOD LOADER"; color: Theme.dim; font { family: root.font; pixelSize: 10; bold: true; letterSpacing: 1 } }
                    Item { Layout.fillWidth: true }
                    Text { visible: root.loadingLoaders; text: "checking…"; color: Theme.dim; font { family: root.font; pixelSize: 10 } }
                }
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    Repeater {
                        model: root.loaderDefs
                        delegate: Rectangle {
                            id: lc
                            required property var modelData
                            readonly property bool available: modelData.id === "vanilla" || !!root.avail[modelData.id]
                            readonly property bool sel: root.loader === modelData.id
                            Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.preferredHeight: 48; radius: 10
                            opacity: available ? 1 : 0.4
                            color: sel ? Qt.alpha(Theme.green, 0.18) : (la.containsMouse && available ? Qt.alpha(Theme.green, 0.08) : Theme.card)
                            border { color: sel ? root.accent : Theme.cardBorder; width: 1 }
                            ColumnLayout {
                                anchors.centerIn: parent; spacing: 0
                                Text { Layout.alignment: Qt.AlignHCenter; text: lc.modelData.label; color: lc.sel ? root.accent : Theme.text; font { family: root.font; pixelSize: 11; bold: lc.sel } }
                                Text { Layout.alignment: Qt.AlignHCenter
                                       text: lc.modelData.id === "vanilla" ? "no mods" : (root.avail[lc.modelData.id] ? String(root.avail[lc.modelData.id]).replace(/-beta.*/, "β") : "n/a")
                                       color: Theme.dim; elide: Text.ElideRight; font { family: root.font; pixelSize: 8 } }
                            }
                            MouseArea { id: la; anchors.fill: parent; hoverEnabled: true; enabled: lc.available; cursorShape: Qt.PointingHandCursor; onClicked: root.setLoader(lc.modelData.id) }
                        }
                    }
                }
                Text {
                    visible: root.avail.java !== undefined
                    text: root.avail.java ? ("Needs Java " + root.avail.java + (root.avail.javaPath ? " — found on this system" : " — not found; pick one in Prism afterwards")) : ""
                    color: root.avail.javaPath ? Theme.dim : Theme.yellow; font { family: root.font; pixelSize: 10 }
                }
            }

            // starter mods
            Rectangle {
                visible: root.loader !== "vanilla"
                Layout.fillWidth: true; implicitHeight: modsCol.implicitHeight + 20; radius: 12
                color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                ColumnLayout {
                    id: modsCol
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 12 }
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Starter mods"; color: Theme.text; font { family: root.font; pixelSize: 12; bold: true } }
                        Text { text: root.pickCount + " selected"; color: Theme.dim; font { family: root.font; pixelSize: 10 } }
                        Item { Layout.fillWidth: true }
                        Text { text: "all"; color: root.accent; font { family: root.font; pixelSize: 10 }
                               MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.setAll(true) } }
                        Text { text: "none"; color: root.accent; font { family: root.font; pixelSize: 10 }
                               MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.setAll(false) } }
                    }
                    Repeater {
                        model: root.presetList()
                        delegate: RowLayout {
                            id: pr
                            required property var modelData
                            Layout.fillWidth: true; spacing: 10
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 0
                                Text { text: pr.modelData.label; color: Theme.text; font { family: root.font; pixelSize: 12 } }
                                Text { visible: !!pr.modelData.note; text: pr.modelData.note || ""; color: Theme.dim; elide: Text.ElideRight; Layout.fillWidth: true; font { family: root.font; pixelSize: 9 } }
                            }
                            Switch { on: !!root.picks[pr.modelData.slug]; onFlipped: root.togglePick(pr.modelData.slug) }
                        }
                    }
                    Text { text: "Mods with no version for this Minecraft yet are skipped. Edit the list in ~/.config/qs-bar/mod-presets.json."
                           color: Theme.dim; wrapMode: Text.Wrap; Layout.fillWidth: true; font { family: root.font; pixelSize: 9 } }
                }
            }
        }
    }

    Rectangle {
        id: createBtn
        visible: root.phase === "form"
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 14 }
        height: 46; radius: 14
        color: root.canCreate ? (cbArea.containsMouse ? Qt.lighter(Theme.green, 1.1) : Theme.green) : Qt.alpha(Theme.mauve, 0.12)
        Text { anchors.centerIn: parent; text: root.canCreate ? "󰐕  Create instance" : "Create instance"
               color: root.canCreate ? Theme.crust : Theme.dim; font { family: root.font; pixelSize: 13; bold: true } }
        MouseArea { id: cbArea; anchors.fill: parent; hoverEnabled: true; enabled: root.canCreate; cursorShape: Qt.PointingHandCursor; onClicked: root.start() }
    }

    // version list (on top of the form)
    MouseArea { anchors.fill: parent; visible: root.versionMenu; z: 20; onClicked: root.versionMenu = false }
    Rectangle {
        visible: root.versionMenu
        z: 21
        x: 14; width: parent.width - 28
        y: 46 + 10 + 12 + 38 + 12 + 14 + 42       // just under the version button
        height: Math.min(300, root.height - y - 20)
        radius: 12; color: Qt.alpha(Theme.base, 0.99); border { color: root.accent; width: 1 }
        ListView {
            anchors { fill: parent; margins: 6 }
            clip: true; spacing: 2; boundsBehavior: Flickable.StopAtBounds
            model: root.versions
            delegate: Rectangle {
                id: vr
                required property var modelData
                required property int index
                width: ListView.view.width; height: 34; radius: 8
                color: vh.hovered ? Qt.alpha(Theme.green, 0.14) : (modelData.version === root.mc ? Qt.alpha(Theme.green, 0.08) : "transparent")
                HoverHandler { id: vh; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: root.pickVersion(vr.modelData.version) }
                RowLayout {
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                    Text { text: vr.modelData.version; color: Theme.text; font { family: root.font; pixelSize: 12 } }
                    Text { visible: vr.index === 0; text: "latest"; color: root.accent; font { family: root.font; pixelSize: 9 } }
                    Item { Layout.fillWidth: true }
                    Text { text: (vr.modelData.releaseTime || "").slice(0, 10); color: Theme.dim; font { family: root.font; pixelSize: 10 } }
                    Text { visible: vr.modelData.version === root.mc; text: "󰄬"; color: root.accent; font { family: root.font; pixelSize: 13 } }
                }
            }
        }
    }

    // ───────── working / done ─────────
    ColumnLayout {
        visible: root.phase !== "form"
        anchors { top: sep.bottom; topMargin: 14; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 }
        spacing: 10
        Text {
            text: root.phase === "working" ? "Setting up “" + root.name + "”…"
                : root.madeIt ? "“" + root.name + "” is ready" : "Something went wrong"
            color: root.madeIt || root.phase === "working" ? Theme.text : Theme.red
            font { family: root.font; pixelSize: 14; bold: true }
        }
        Text {
            visible: root.phase === "done" && root.madeIt
            text: "Minecraft " + root.mc + " · " + root.loaderLabel(root.loader) + " · " + root.okMods + " mod" + (root.okMods === 1 ? "" : "s") + " installed"
                  + (root.skippedMods ? " · " + root.skippedMods + " skipped" : "")
            color: Theme.dim; font { family: root.font; pixelSize: 11 }
        }
        Repeater {
            model: root.steps
            delegate: RowLayout {
                id: st
                required property var modelData
                Layout.fillWidth: true; spacing: 10
                Text {
                    Layout.preferredWidth: 18
                    text: st.modelData.state === "ok" ? "󰄬" : st.modelData.state === "run" ? "󰑐" : st.modelData.state === "fail" ? "󰅖" : st.modelData.state === "skip" ? "󰍴" : "·"
                    color: st.modelData.state === "ok" ? Theme.green : st.modelData.state === "fail" ? Theme.red : st.modelData.state === "skip" ? Theme.yellow : Theme.dim
                    font { family: root.font; pixelSize: 14 }
                    RotationAnimator on rotation { running: st.modelData.state === "run"; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                }
                Text { text: st.modelData.label; color: st.modelData.state === "wait" ? Theme.dim : Theme.text; font { family: root.font; pixelSize: 12 } }
                Text { text: st.modelData.note; color: st.modelData.state === "fail" ? Theme.red : Theme.dim; elide: Text.ElideRight; Layout.fillWidth: true
                       textFormat: Text.PlainText; font { family: root.font; pixelSize: 10 } }
            }
        }
        Item { Layout.preferredHeight: 6 }
        Rectangle {
            visible: root.phase === "done"
            Layout.fillWidth: true; Layout.preferredHeight: 44; radius: 14
            color: doneArea.containsMouse ? Qt.lighter(Theme.green, 1.1) : Theme.green
            Text { anchors.centerIn: parent; text: root.madeIt ? "Done" : "Back"; color: Theme.crust; font { family: root.font; pixelSize: 13; bold: true } }
            MouseArea { id: doneArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { if (root.madeIt) root.created(root.newId); else { root.phase = "form" } } }
        }
        Text { visible: root.phase === "done" && root.madeIt; Layout.fillWidth: true; wrapMode: Text.Wrap
               text: "Prism picks the new instance up by itself. If it is open and the instance is missing, restart it."
               color: Theme.dim; font { family: root.font; pixelSize: 10 } }
    }
}
