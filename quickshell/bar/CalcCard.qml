import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "calc.js" as Calc

// Calculator card for the launcher: type "= \frac{1}{2} + \sqrt{9}" or anything with a \command.
// Maths is written in LaTeX; see calc.js for what is understood. Expressions with an unknown x are drawn as a graph
// (scroll to zoom, drag to move, double-click to reset); "x^2 - 2 = 0" also lists the solutions.
Rectangle {
    id: card
    required property string query
    readonly property string font: "JetBrainsMono Nerd Font"

    // a query is "maths" if it starts with =, has a \command, or is plain arithmetic like 12*(3+4)
    readonly property bool wanted: {
        var q = query.trim()
        if (q.length === 0) return false
        if (q[0] === "?") return false
        if (q[0] === "=") return true
        if (q.indexOf("\\") >= 0) return true
        return /\d/.test(q) && /[+\-*\/^]/.test(q.replace(/^[+-]/, "")) && /^[\d\s.()+\-*\/^!%,]+$/.test(q)
    }
    readonly property var res: wanted ? Calc.run(query) : null
    readonly property bool ok: res !== null && res.ok && res.text.length > 0
    readonly property bool plotted: ok && res.curves.length > 0
    visible: wanted && (query.replace(/^=\s*/, "").length > 0)

    property bool copied: false
    function copy() {
        if (!ok) return
        var t = res.kind === "value" ? res.text.replace(/ × 10/, "e").replace(/[⁰¹²³⁴⁵⁶⁷⁸⁹⁻]+/, function (s) { return "" }) : res.text
        copyProc.command = ["wl-copy", res.kind === "value" && res.value !== undefined && typeof res.value === "number" ? String(res.value) : t]
        copyProc.running = true
        copied = true; copyTimer.restart()
    }
    Process { id: copyProc }
    Timer { id: copyTimer; interval: 1500; onTriggered: card.copied = false }

    Layout.fillWidth: true; Layout.topMargin: 8
    implicitHeight: col.implicitHeight + 20
    radius: 12; color: Qt.alpha(Theme.sky, 0.07); border { color: Qt.alpha(Theme.sky, 0.35); width: 1 }

    // ── graph state ──
    property real xmin: -10
    property real xmax: 10
    property real ymin: -6
    property real ymax: 6
    property var  ys: []
    function resetView() {
        var lo = -10, hi = 10
        if (res && res.kind === "solve" && res.roots.length) {      // make sure the nearest solutions are in view
            var far = Math.max.apply(null, res.roots.map(function (r) { return Math.abs(r) }))
            var m = Math.max(10, far * 1.4)
            lo = -m; hi = m
        }
        xmin = lo; xmax = hi
        resample(true)
    }
    function resample(fit) {
        if (!plotted) { ys = []; return }
        ys = Calc.sample(res.curves, xmin, xmax, 480)
        if (fit) { var r = Calc.fitY(ys); ymin = r.lo; ymax = r.hi }
        graph.requestPaint()
    }
    onResChanged: Qt.callLater(function () { if (card.plotted) card.resetView(); else card.ys = [] })

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            Text { text: "󰪚"; color: Theme.sky; font { family: card.font; pixelSize: 14 } }
            Text { text: "Calculator"; color: Theme.sky; font { family: card.font; pixelSize: 11; bold: true } }
            Item { Layout.fillWidth: true }
            Text {
                visible: card.ok
                text: card.copied ? "copied" : (card.res && card.res.kind === "plot" ? "" : "↵ copy")
                color: card.copied ? Theme.green : Theme.dim; font { family: card.font; pixelSize: 10 }
            }
        }
        Text {
            visible: card.res !== null && card.res.parsed.length > 0 && (card.ok || card.res.error.length > 0)
            text: card.res ? card.res.parsed : ""; color: Theme.dim; elide: Text.ElideRight; Layout.fillWidth: true
            textFormat: Text.PlainText; font { family: card.font; pixelSize: 10 }
        }
        Text {
            visible: card.res !== null && !card.ok && card.res.error.length > 0
            text: card.res ? card.res.error : ""; color: Theme.red; wrapMode: Text.WordWrap; Layout.fillWidth: true
            font { family: card.font; pixelSize: 12 }
        }
        Text {
            visible: card.ok
            text: card.res ? (card.res.kind === "value" ? "= " + card.res.text : card.res.text) : ""
            color: Theme.text; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true; textFormat: Text.PlainText
            font { family: card.font; pixelSize: card.res && card.res.kind === "value" ? 20 : 13; bold: true }
        }
        Text {
            visible: card.ok && card.res.exact.length > 0
            text: "exactly  " + (card.res ? card.res.exact : ""); color: Theme.subtext; font { family: card.font; pixelSize: 11 }
        }

        // ── graph ──
        Item {
            visible: card.plotted
            Layout.fillWidth: true; Layout.preferredHeight: 210; Layout.topMargin: 4
            Rectangle { anchors.fill: parent; radius: 8; color: Qt.alpha(Theme.crust, 0.35); border { color: Theme.cardBorder; width: 1 } }

            Canvas {
                id: graph
                anchors { fill: parent; margins: 1 }
                renderStrategy: Canvas.Cooperative
                property real hx: -1e9       // hover position in graph units
                property real hy: 0
                readonly property var palette: [Theme.mauve, Theme.green, Theme.peach, Theme.sky, Theme.pink, Theme.yellow]
                onPaint: {
                    var ctx = getContext("2d"), w = width, h = height
                    ctx.reset()
                    var X = function (x) { return (x - card.xmin) / (card.xmax - card.xmin) * w }
                    var Y = function (y) { return h - (y - card.ymin) / (card.ymax - card.ymin) * h }
                    // grid at a "nice" step
                    var nice = function (span) {
                        var raw = span / 6, p = Math.pow(10, Math.floor(Math.log(raw) / Math.LN10)), f = raw / p
                        return (f < 1.5 ? 1 : f < 3.5 ? 2 : f < 7.5 ? 5 : 10) * p
                    }
                    var sx = nice(card.xmax - card.xmin), sy = nice(card.ymax - card.ymin)
                    ctx.lineWidth = 1
                    ctx.font = "9px '" + card.font + "'"
                    ctx.fillStyle = Theme.dim
                    for (var gx = Math.ceil(card.xmin / sx) * sx; gx <= card.xmax; gx += sx) {
                        ctx.strokeStyle = Qt.alpha(Theme.mauve, Math.abs(gx) < sx * 1e-6 ? 0.55 : 0.12)
                        ctx.beginPath(); ctx.moveTo(X(gx), 0); ctx.lineTo(X(gx), h); ctx.stroke()
                        if (Math.abs(gx) > sx * 1e-6) ctx.fillText(Number(gx.toPrecision(6)).toString(), X(gx) + 3, Math.min(h - 3, Math.max(10, Y(0) + 10)))
                    }
                    for (var gy = Math.ceil(card.ymin / sy) * sy; gy <= card.ymax; gy += sy) {
                        ctx.strokeStyle = Qt.alpha(Theme.mauve, Math.abs(gy) < sy * 1e-6 ? 0.55 : 0.12)
                        ctx.beginPath(); ctx.moveTo(0, Y(gy)); ctx.lineTo(w, Y(gy)); ctx.stroke()
                        if (Math.abs(gy) > sy * 1e-6) ctx.fillText(Number(gy.toPrecision(6)).toString(), Math.min(w - 30, Math.max(3, X(0) + 3)), Y(gy) - 3)
                    }
                    // curves (broken where the function is undefined or jumps)
                    var n = card.ys.length ? card.ys[0].length - 1 : 0
                    for (var c = 0; c < card.ys.length; c++) {
                        ctx.strokeStyle = palette[c % palette.length]; ctx.lineWidth = 2
                        ctx.beginPath()
                        var pen = false, py = 0
                        for (var i = 0; i <= n; i++) {
                            var y = card.ys[c][i]
                            if (y === null || Math.abs(Y(y)) > 1e5) { pen = false; continue }
                            var px = i / n * w, qy = Y(y)
                            if (pen && Math.abs(qy - py) > h * 1.5) pen = false      // vertical asymptote
                            if (!pen) ctx.moveTo(px, qy); else ctx.lineTo(px, qy)
                            pen = true; py = qy
                        }
                        ctx.stroke()
                    }
                    // solutions
                    if (card.res && card.res.kind === "solve") {
                        ctx.fillStyle = Theme.red
                        card.res.roots.forEach(function (r) { ctx.beginPath(); ctx.arc(X(r), Y(0), 4, 0, 2 * Math.PI); ctx.fill() })
                    }
                    // hover read-out
                    if (hx > -1e8 && card.ys.length) {
                        var yy = Calc.valueAt(card.res.curves[0], hx)
                        ctx.strokeStyle = Qt.alpha(Theme.text, 0.35); ctx.lineWidth = 1
                        ctx.beginPath(); ctx.moveTo(X(hx), 0); ctx.lineTo(X(hx), h); ctx.stroke()
                        if (isFinite(yy)) {
                            ctx.fillStyle = Theme.text; ctx.beginPath(); ctx.arc(X(hx), Y(yy), 3.5, 0, 2 * Math.PI); ctx.fill()
                            var label = "(" + Number(hx.toPrecision(4)) + ", " + Number(yy.toPrecision(5)) + ")"
                            ctx.fillStyle = Theme.bright; ctx.font = "10px '" + card.font + "'"
                            ctx.fillText(label, Math.min(w - 110, Math.max(4, X(hx) + 8)), Math.max(12, Math.min(h - 6, Y(yy) - 8)))
                        }
                    }
                }
            }
            MouseArea {
                id: gm
                anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton
                property real lastX: 0; property real lastY: 0
                onPositionChanged: m => {
                    graph.hx = card.xmin + m.x / width * (card.xmax - card.xmin)
                    if (pressed) {
                        var dx = (m.x - lastX) / width * (card.xmax - card.xmin), dy = (m.y - lastY) / height * (card.ymax - card.ymin)
                        card.xmin -= dx; card.xmax -= dx; card.ymin += dy; card.ymax += dy
                        card.resample(false)
                    }
                    lastX = m.x; lastY = m.y
                    graph.requestPaint()
                }
                onPressed: m => { lastX = m.x; lastY = m.y }
                onExited: { graph.hx = -1e9; graph.requestPaint() }
                onDoubleClicked: card.resetView()
                onWheel: w => {
                    var f = w.angleDelta.y > 0 ? 0.8 : 1.25
                    var cx = card.xmin + w.x / width * (card.xmax - card.xmin), cy = card.ymax - w.y / height * (card.ymax - card.ymin)
                    card.xmin = cx - (cx - card.xmin) * f; card.xmax = cx + (card.xmax - cx) * f
                    card.ymin = cy - (cy - card.ymin) * f; card.ymax = cy + (card.ymax - cy) * f
                    card.resample(false)
                }
            }
        }
        RowLayout {
            visible: card.plotted
            Layout.fillWidth: true; spacing: 10
            Repeater {
                model: card.plotted ? card.res.curves : []
                delegate: RowLayout {
                    required property var modelData
                    required property int index
                    spacing: 5
                    Rectangle { Layout.preferredWidth: 10; Layout.preferredHeight: 3; radius: 1.5; color: graph.palette[index % graph.palette.length] }
                    Text { text: modelData.label; color: Theme.subtext; textFormat: Text.PlainText; elide: Text.ElideRight; Layout.maximumWidth: 200
                           font { family: card.font; pixelSize: 9 } }
                }
            }
            Item { Layout.fillWidth: true }
            Text { text: "scroll: zoom · drag: move · double-click: reset"; color: Theme.dim; font { family: card.font; pixelSize: 8 } }
        }
    }
}
