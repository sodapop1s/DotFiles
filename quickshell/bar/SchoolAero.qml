import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "orbit.js" as O
import "formulas.js" as F

// School > Aero: a Hohmann transfer calculator with a diagram, a planner that lists the Δv to every other planet and moon,
// and a formula sheet. Three systems: the real solar system, Kerbal Space Program, and KSP with the Outer Planets Mod.
Item {
    id: root
    required property var bar
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.sky
    property string sub: "orbit"                 // orbit | planner | formulas

    // ── orbit state ──
    property int    sysIndex: 0
    readonly property var system: O.SYSTEMS[sysIndex]
    property string bodyId: "earth"
    readonly property var body: O.findBody(system, bodyId) || system.bodies[0]
    property bool   byAltitude: true            // inputs are heights above the surface, not distances from the centre
    property string fromText: "400"
    property string toText: "35786"
    property string incText: "0"
    readonly property real fromKm: parseFloat(fromText)
    readonly property real toKm: parseFloat(toText)
    readonly property real incDeg: parseFloat(incText) || 0
    readonly property real r1: (byAltitude ? body.R : 0) + fromKm * 1000
    readonly property real r2: (byAltitude ? body.R : 0) + toKm * 1000
    readonly property bool valid: isFinite(r1) && isFinite(r2) && r1 > 0 && r2 > 0 && r1 !== r2 && (!byAltitude || (fromKm >= 0 && toKm >= 0))
    readonly property var res: valid ? O.hohmann(body.mu, r1, r2, incDeg * Math.PI / 180) : null
    readonly property var bi: (valid && Math.max(r1, r2) / Math.min(r1, r2) > 8) ? O.biElliptic(body.mu, Math.min(r1, r2), Math.max(r1, r2), 4 * Math.max(r1, r2)) : null
    readonly property var presets: ({
        earth: [["LEO → GEO", 400, 35786], ["LEO → ISS 1000 km", 400, 1000], ["LEO → Moon distance", 400, 378000]],
        moon: [["100 km → 2000 km", 100, 2000]],
        mars: [["low → areostationary", 400, 17032]],
        venus: [["300 km → 2000 km", 300, 2000]],
        jupiter: [["Io-ish → Europa-ish", 300000, 600000]],
        kerbin: [["80 km → synchronous", 80, 2863], ["80 km → Mun's orbit", 80, 11400], ["80 km → Minmus' orbit", 80, 47000]],
        mun: [["30 km → 200 km", 30, 200]], minmus: [["20 km → 200 km", 20, 200]],
        eve: [["100 km → 1000 km", 100, 1000]], duna: [["60 km → 1000 km", 60, 1000]], jool: [["210 km → 5000 km", 210, 5000]],
        laythe: [["60 km → 1000 km", 60, 1000]], sarnus: [["600 km → 12000 km", 600, 12000]],
        sun: [["Earth → Mars (radii)", 149598000, 227940000]]
    })
    function usePreset(p) { fromText = String(p[1]); toText = String(p[2]) }
    // a starting point for any body: just above the air (or 10% of the radius) out to ten times that distance
    function defaults() {
        var p = presets[body.id]
        byAltitude = body.parent !== null
        if (p && p.length) { usePreset(p[0]); return }
        if (!body.parent) { byAltitude = false; fromText = String(Math.round(body.R / 1000 * 4)); toText = String(Math.round(body.R / 1000 * 8)); return }
        var lo = O.lowAlt(body) / 1000
        fromText = String(lo); toText = String(Math.round(lo * 10))
    }
    function setBody(id) { bodyId = id; defaults(); diagram.requestPaint() }
    function setSystem(i) { sysIndex = i; bodyId = i === 0 ? "earth" : "kerbin"; defaults(); planOrigin = bodyId; diagram.requestPaint() }
    onResChanged: diagram.requestPaint()
    onBodyIdChanged: diagram.requestPaint()

    // ── planner state ──
    property string planOrigin: "earth"
    property string parkText: ""               // parking orbit height in km; empty = the body's default low orbit
    property bool   aerobrake: true
    readonly property var planBody: O.findBody(system, planOrigin) || O.findBody(system, system.id === "real" ? "earth" : "kerbin")
    readonly property real parkKm: parkText.length && isFinite(parseFloat(parkText)) ? parseFloat(parkText) : O.lowAlt(planBody) / 1000
    readonly property var plan: planBody ? O.deltaVTable(system, planBody, parkKm * 1000, aerobrake) : []
    readonly property var planets: O.planetsOf(system)
    function dvText(v) { return system.id === "real" ? (v / 1000).toFixed(2) + " km/s" : Math.round(v).toLocaleString() + " m/s" }
    function windowText(sec) { var d = sec / 86400; return d > 700 ? (d / 365.25).toFixed(1) + " y" : Math.round(d) + " d" }
    function kindColor(b) { return Theme[b.color] || Theme.sky }

    // ── formulas ──
    property var custom: []
    FileView {
        path: Quickshell.env("HOME") + "/.config/qs-bar/formulas.json"
        onLoaded: { try { var a = JSON.parse(text()); if (Array.isArray(a)) root.custom = a } catch (e) {} }
    }
    readonly property var allFormulas: F.FORMULAS.concat(custom)
    property string cat: ""
    property string query: ""
    readonly property var cats: { var seen = {}, out = []; allFormulas.forEach(f => { if (!seen[f.cat]) { seen[f.cat] = 1; out.push(f.cat) } }); return out }
    readonly property var shown: {
        var q = query.trim().toLowerCase()
        return allFormulas.filter(f => (cat === "" || f.cat === cat) && (q === "" || (f.name + " " + f.pretty + " " + f.note + " " + f.cat).toLowerCase().indexOf(q) >= 0))
    }
    property string copied: ""
    Process { id: copyProc }
    function copyLatex(f) {
        copyProc.command = ["wl-copy", f.latex]; copyProc.running = true
        copied = f.name; copyTimer.restart()
    }
    Timer { id: copyTimer; interval: 1800; onTriggered: root.copied = "" }
    function activate() {}

    component Chip: Rectangle {
        id: ch
        property string label: ""
        property bool sel: false
        property color tint: root.accent
        signal clicked
        height: 26; width: lt.implicitWidth + 18; radius: 13
        color: sel ? Qt.alpha(tint, 0.22) : Theme.card; border { color: sel ? tint : Theme.cardBorder; width: 1 }
        Text { id: lt; anchors.centerIn: parent; text: ch.label; color: sel ? Theme.text : Theme.subtext; font { family: root.font; pixelSize: 10 } }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ch.clicked() }
    }
    component Field: Rectangle {
        id: fd
        property alias text: inp.text
        property string suffix: ""
        signal edited(string t)
        implicitHeight: 30; radius: 8; color: Qt.alpha(Theme.mauve, 0.08); border { color: inp.activeFocus ? Qt.alpha(root.accent, 0.6) : Theme.sep; width: 1 }
        RowLayout {
            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
spacing: 4
            TextInput { id: inp; Layout.fillWidth: true; color: Theme.text; selectByMouse: true; clip: true; font { family: root.font; pixelSize: 12 }
onTextEdited: fd.edited(text) }
            Text { text: fd.suffix; color: Theme.dim; font { family: root.font; pixelSize: 10 } }
        }
    }

    // sub tabs
    Row {
        id: subTabs
        anchors { top: parent.top; topMargin: 8; left: parent.left; leftMargin: 14 }
        spacing: 6
        Repeater {
            model: [["orbit", "󰀲  Orbit"], ["planner", "󰇧  Planner"], ["formulas", "󰊕  Formulas"]]
            delegate: Chip { required property var modelData; label: modelData[1]; sel: root.sub === modelData[0]; onClicked: root.sub = modelData[0] }
        }
    }

    // ═══ Orbit ═══
    Flickable {
        id: orbitView
        visible: root.sub === "orbit"
        anchors { top: subTabs.bottom; topMargin: 8; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentHeight: orbitCol.implicitHeight + 16; clip: true; boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: orbitCol
            x: 14; width: orbitView.width - 28; spacing: 8

            Flow {
                Layout.fillWidth: true; spacing: 5
                Repeater {
                    model: O.SYSTEMS
                    delegate: Chip { required property var modelData; required property int index; label: modelData.name; sel: root.sysIndex === index; tint: Theme.mauve; onClicked: root.setSystem(index) }
                }
            }
            Flow {
                Layout.fillWidth: true; spacing: 5
                Repeater {
                    model: root.system.bodies
                    delegate: Chip { required property var modelData; label: modelData.name; sel: root.body.id === modelData.id; tint: Theme[modelData.color] || root.accent; onClicked: root.setBody(modelData.id) }
                }
            }
            Flow {
                Layout.fillWidth: true; spacing: 5
                Repeater {
                    model: root.presets[root.body.id] || []
                    delegate: Chip { required property var modelData; label: modelData[0]; tint: Theme.mauve; onClicked: root.usePreset(modelData) }
                }
            }
            Row {
                id: inputs
                Layout.fillWidth: true; spacing: 8
                readonly property real half: (width - 90 - 2 * spacing) / 2
                Column {
                    width: inputs.half; spacing: 3
                    Text { text: "from " + (root.byAltitude ? "altitude" : "radius"); color: Theme.dim; font { family: root.font; pixelSize: 9 } }
                    Field { width: parent.width; text: root.fromText; suffix: "km"; onEdited: t => root.fromText = t }
                }
                Column {
                    width: inputs.half; spacing: 3
                    Text { text: "to " + (root.byAltitude ? "altitude" : "radius"); color: Theme.dim; font { family: root.font; pixelSize: 9 } }
                    Field { width: parent.width; text: root.toText; suffix: "km"; onEdited: t => root.toText = t }
                }
                Column {
                    width: 90; spacing: 3
                    Text { text: "plane change"; color: Theme.dim; font { family: root.font; pixelSize: 9 } }
                    Field { width: parent.width; text: root.incText; suffix: "°"; onEdited: t => root.incText = t }
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Chip { label: root.byAltitude ? "heights above the surface" : "distances from the centre"; tint: Theme.mauve; onClicked: root.byAltitude = !root.byAltitude }
                Text { Layout.fillWidth: true; text: "μ " + root.body.mu.toExponential(4).replace("e+", "e") + " m³/s²  ·  R " + O.km(root.body.R) + " km" + (root.body.parent ? "  ·  SOI " + (O.soi(root.system, root.body) / 1000).toExponential(3).replace("e+", "e") + " km" : ""); color: Theme.dim; elide: Text.ElideRight; font { family: root.font; pixelSize: 9 } }
            }

            Text {
                visible: !root.valid
                Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.yellow; font { family: root.font; pixelSize: 11 }
                text: root.fromText.length && root.toText.length ? "Pick two different orbits above the surface." : "Type the two orbits."
            }
            Text {
                visible: root.valid && root.byAltitude && Math.min(root.fromKm, root.toKm) * 1000 < root.body.atmo
                Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.yellow; font { family: root.font; pixelSize: 10 }
                text: "Heads up: " + root.body.name + "'s atmosphere reaches about " + O.km(root.body.atmo) + " km, so an orbit that low would decay."
            }

            // results
            RowLayout {
                visible: root.res !== null
                Layout.fillWidth: true; spacing: 8
                Repeater {
                    model: root.res ? [{ k: "burn 1", v: O.speed(root.res.dv1), c: Theme.peach }, { k: "burn 2", v: O.speed(root.res.dv2), c: Theme.peach }, { k: "total Δv", v: O.speed(root.res.dv), c: Theme.green }] : []
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true; Layout.preferredWidth: 1; implicitHeight: 52; radius: 12; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                        ColumnLayout { anchors.centerIn: parent; spacing: 0
                            Text { Layout.alignment: Qt.AlignHCenter; text: modelData.v; color: modelData.c; font { family: root.font; pixelSize: 14; bold: true } }
                            Text { Layout.alignment: Qt.AlignHCenter; text: modelData.k; color: Theme.dim; font { family: root.font; pixelSize: 9 } } }
                    }
                }
            }
            // diagram
            Rectangle {
                visible: root.res !== null
                Layout.fillWidth: true; Layout.preferredHeight: 200; radius: 12; color: Qt.alpha(Theme.crust, 0.35); border { color: Theme.cardBorder; width: 1 }
                Canvas {
                    id: diagram
                    anchors { fill: parent; margins: 1 }
                    onPaint: {
                        var ctx = getContext("2d"); ctx.reset()
                        if (!root.res) return
                        var w = width, h = height, cx = w / 2, cy = h / 2
                        var big = Math.max(root.r1, root.r2), small = Math.min(root.r1, root.r2)
                        var sc = (Math.min(w, h) / 2 - 16) / big
                        var R = Math.max(5, root.body.R * sc)
                        // body
                        ctx.fillStyle = Qt.alpha(Theme[root.body.color] || Theme.sky, 0.55)
                        ctx.beginPath(); ctx.arc(cx, cy, Math.min(R, small * sc - 3), 0, 2 * Math.PI); ctx.fill()
                        // the two circular orbits
                        ctx.lineWidth = 1.5
                        ctx.strokeStyle = Theme.subtext
                        ctx.beginPath(); ctx.arc(cx, cy, root.r1 * sc, 0, 2 * Math.PI); ctx.stroke()
                        ctx.strokeStyle = Theme.sky
                        ctx.beginPath(); ctx.arc(cx, cy, root.r2 * sc, 0, 2 * Math.PI); ctx.stroke()
                        // transfer half-ellipse: periapsis on the right, apoapsis on the left
                        var e = root.res.e, p = root.res.rp * (1 + e)
                        ctx.strokeStyle = Theme.peach; ctx.lineWidth = 2.5
                        ctx.beginPath()
                        for (var i = 0; i <= 90; i++) {
                            var th = Math.PI * i / 90, r = p / (1 + e * Math.cos(th))
                            var x = cx + r * Math.cos(th) * sc, y = cy - r * Math.sin(th) * sc
                            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                        }
                        ctx.stroke()
                        // burns: where the transfer touches each orbit
                        var up = root.r2 > root.r1
                        var b1x = up ? cx + root.r1 * sc : cx - root.r1 * sc, b2x = up ? cx - root.r2 * sc : cx + root.r2 * sc
                        ctx.fillStyle = Theme.red
                        ctx.beginPath(); ctx.arc(b1x, cy, 5, 0, 2 * Math.PI); ctx.fill()
                        ctx.fillStyle = Theme.green
                        ctx.beginPath(); ctx.arc(b2x, cy, 5, 0, 2 * Math.PI); ctx.fill()
                        ctx.fillStyle = Theme.bright; ctx.font = "10px '" + root.font + "'"
                        ctx.fillText("burn 1", Math.min(w - 44, Math.max(2, b1x + (up ? 8 : -44))), cy - 8)
                        ctx.fillText("burn 2", Math.min(w - 44, Math.max(2, b2x + (up ? -44 : 8))), cy - 8)
                    }
                }
            }
            GridLayout {
                visible: root.res !== null
                Layout.fillWidth: true; columns: 2; columnSpacing: 12; rowSpacing: 3
                Repeater {
                    model: root.res ? [
                        ["transfer time", O.dur(root.res.tof)],
                        ["transfer orbit", "a " + O.km(root.res.a) + " km,  e " + root.res.e.toFixed(3)],
                        ["start orbit", O.speed(root.res.v1) + ",  period " + O.dur(root.res.t1)],
                        ["end orbit", O.speed(root.res.v2) + ",  period " + O.dur(root.res.t2)],
                        ["escape from start", O.speed(O.escapeSpeed(root.body.mu, root.r1)) + "  (+" + O.speed(O.escapeSpeed(root.body.mu, root.r1) - root.res.v1) + ")"],
                        ["phase angle", (root.res.phase >= 0 ? "target " + root.res.phase.toFixed(1) + "° ahead" : "target " + (-root.res.phase).toFixed(1) + "° behind") + " at burn"]
                    ] : []
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true; Layout.columnSpan: 2; spacing: 8
                        Text { text: modelData[0]; color: Theme.dim; Layout.preferredWidth: 110; font { family: root.font; pixelSize: 10 } }
                        Text { text: modelData[1]; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; font { family: root.font; pixelSize: 11 } }
                    }
                }
            }
            Text {
                visible: root.bi !== null && root.res !== null
                Layout.fillWidth: true; wrapMode: Text.WordWrap; font { family: root.font; pixelSize: 10 }
                color: root.bi && root.res && root.bi.dv < root.res.dv ? Theme.green : Theme.dim
                text: root.bi && root.res ? "Bi-elliptic through " + O.km(4 * Math.max(root.r1, root.r2)) + " km: " + O.speed(root.bi.dv) + " in " + O.dur(root.bi.tof)
                                            + (root.bi.dv < root.res.dv ? "  — cheaper than Hohmann by " + O.speed(root.res.dv - root.bi.dv) + ", but much slower." : "  — not worth it at this ratio.") : ""
            }

        }
    }

    // ═══ Planner ═══
    Flickable {
        id: planView
        visible: root.sub === "planner"
        anchors { top: subTabs.bottom; topMargin: 8; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentHeight: planCol.implicitHeight + 16; clip: true; boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: planCol
            x: 14; width: planView.width - 28; spacing: 8
            Flow {
                Layout.fillWidth: true; spacing: 5
                Repeater {
                    model: O.SYSTEMS
                    delegate: Chip { required property var modelData; required property int index; label: modelData.name; sel: root.sysIndex === index; tint: Theme.mauve; onClicked: root.setSystem(index) }
                }
            }
            Text { text: "LEAVE FROM"; color: Theme.dim; font { family: root.font; pixelSize: 9; bold: true; letterSpacing: 1 } }
            Flow {
                Layout.fillWidth: true; spacing: 5
                Repeater {
                    model: root.planets
                    delegate: Chip { required property var modelData; label: modelData.name; sel: root.planBody && root.planBody.id === modelData.id; tint: Theme[modelData.color] || root.accent
                                     onClicked: { root.planOrigin = modelData.id; root.parkText = "" } }
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text { text: "parking orbit"; color: Theme.subtext; font { family: root.font; pixelSize: 11 } }
                Field { Layout.preferredWidth: 100; text: root.parkText; suffix: "km"; onEdited: t => root.parkText = t }
                Text { text: "(" + root.parkKm.toFixed(0) + " km high)"; color: Theme.dim; font { family: root.font; pixelSize: 9 } }
                Item { Layout.fillWidth: true }
                Chip { label: root.aerobrake ? "aerobrake on" : "aerobrake off"; sel: root.aerobrake; tint: Theme.green; onClicked: root.aerobrake = !root.aerobrake }
            }
            // header
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                Text { text: "to"; Layout.preferredWidth: 66; color: Theme.dim; font { family: root.font; pixelSize: 9 } }
                Text { text: "leave"; Layout.fillWidth: true; Layout.preferredWidth: 1; color: Theme.dim; horizontalAlignment: Text.AlignRight; font { family: root.font; pixelSize: 9 } }
                Text { text: "arrive"; Layout.fillWidth: true; Layout.preferredWidth: 1; color: Theme.dim; horizontalAlignment: Text.AlignRight; font { family: root.font; pixelSize: 9 } }
                Text { text: "total"; Layout.fillWidth: true; Layout.preferredWidth: 1; color: Theme.dim; horizontalAlignment: Text.AlignRight; font { family: root.font; pixelSize: 9 } }
                Text { text: "flight"; Layout.preferredWidth: 58; color: Theme.dim; horizontalAlignment: Text.AlignRight; font { family: root.font; pixelSize: 9 } }
                Text { text: "phase"; Layout.preferredWidth: 46; color: Theme.dim; horizontalAlignment: Text.AlignRight; font { family: root.font; pixelSize: 9 } }
            }
            Repeater {
                model: root.plan
                delegate: Rectangle {
                    id: pr
                    required property var modelData
                    readonly property var tb: O.findBody(root.system, modelData.id)
                    Layout.fillWidth: true; implicitHeight: 40; radius: 10; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
spacing: 6
                        ColumnLayout {
                            Layout.preferredWidth: 60; spacing: 0
                            Text { text: pr.modelData.name; color: root.kindColor(pr.tb); font { family: root.font; pixelSize: 11; bold: true } }
                            Text { text: pr.modelData.kind === "moon" ? "moon" : (pr.modelData.synodic ? "every " + root.windowText(pr.modelData.synodic) : ""); color: Theme.dim; font { family: root.font; pixelSize: 8 } }
                        }
                        Text { text: root.dvText(pr.modelData.depart); Layout.fillWidth: true; Layout.preferredWidth: 1; color: Theme.text; horizontalAlignment: Text.AlignRight; font { family: root.font; pixelSize: 10 } }
                        Text { text: pr.modelData.aero ? "aero" : root.dvText(pr.modelData.arrive); Layout.fillWidth: true; Layout.preferredWidth: 1; color: pr.modelData.aero ? Theme.green : Theme.text; horizontalAlignment: Text.AlignRight; font { family: root.font; pixelSize: 10 } }
                        Text { text: root.dvText(pr.modelData.total); Layout.fillWidth: true; Layout.preferredWidth: 1; color: Theme.peach; horizontalAlignment: Text.AlignRight; font { family: root.font; pixelSize: 10; bold: true } }
                        Text { text: O.dur(pr.modelData.tof).replace(" days", " d"); Layout.preferredWidth: 58; color: Theme.subtext; horizontalAlignment: Text.AlignRight; font { family: root.font; pixelSize: 9 } }
                        Text { text: pr.modelData.phase.toFixed(0) + "°"; Layout.preferredWidth: 46; color: Theme.subtext; horizontalAlignment: Text.AlignRight; font { family: root.font; pixelSize: 9 } }
                    }
                }
            }
            Text {
                Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.dim; font { family: root.font; pixelSize: 9 }
                text: "Ideal numbers: circular, flat (same-plane) orbits, one Hohmann transfer. “leave” is the burn out of your parking orbit (for a planet, it ejects you onto the transfer and includes the Oberth effect); “arrive” is the burn into a low orbit there. “aero” means the planet has air, so you can brake in it for free. Phase is where the target should be relative to you when you leave (positive = ahead). Real trips cost a bit more: plane changes, correction burns, and launching to orbit are not included."
            }
        }
    }

    // ═══ Formulas ═══
    ColumnLayout {
        visible: root.sub === "formulas"
        anchors { top: subTabs.bottom; topMargin: 8; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 10 }
        spacing: 8
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 34; radius: 10; color: Qt.alpha(Theme.mauve, 0.07); border { color: fInput.activeFocus ? Qt.alpha(root.accent, 0.5) : Theme.sep; width: 1 }
            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
spacing: 8
                Text { text: "󰍉"; color: Theme.dim; font { family: root.font; pixelSize: 14 } }
                TextInput {
                    id: fInput
                    Layout.fillWidth: true; color: Theme.text; clip: true; font { family: root.font; pixelSize: 12 }
                    onTextChanged: root.query = text
                    Text { visible: fInput.text.length === 0; anchors.verticalCenter: parent.verticalCenter; color: Theme.dim; font { family: root.font; pixelSize: 11 }
text: "search formulas (rocket, buckling, Mach…)" }
                }
                Text { visible: root.copied.length > 0; text: "copied LaTeX"; color: Theme.green; font { family: root.font; pixelSize: 10 } }
            }
        }
        Flow {
            Layout.fillWidth: true; spacing: 5
            Chip { label: "All"; sel: root.cat === ""; onClicked: root.cat = "" }
            Repeater { model: root.cats; delegate: Chip { required property string modelData; label: modelData; sel: root.cat === modelData; onClicked: root.cat = (root.cat === modelData ? "" : modelData) } }
        }
        ListView {
            id: flist
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: 5; boundsBehavior: Flickable.StopAtBounds
            model: root.shown
            delegate: Rectangle {
                id: fr
                required property var modelData
                width: flist.width; height: fcol.implicitHeight + 16; radius: 10
                color: fh.hovered ? Qt.alpha(root.accent, 0.10) : Theme.card; border { color: root.copied === fr.modelData.name ? Theme.green : Theme.cardBorder; width: 1 }
                HoverHandler { id: fh; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: root.copyLatex(fr.modelData) }
                ColumnLayout {
                    id: fcol
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 12 }
                    spacing: 2
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: fr.modelData.name; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 11; bold: true } }
                        Text { text: fr.modelData.cat; color: Theme.dim; font { family: root.font; pixelSize: 9 } }
                    }
                    Text { text: fr.modelData.pretty; color: root.accent; wrapMode: Text.WordWrap; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 12 } }
                    Text { visible: fr.modelData.note.length > 0; text: fr.modelData.note; color: Theme.dim; wrapMode: Text.WordWrap; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 9 } }
                }
            }
            Text { visible: flist.count === 0; anchors.centerIn: parent; text: "no formula matches"; color: Theme.dim; font { family: root.font; pixelSize: 11 } }
        }
    }
}
