import QtQuick
import QtQuick.Layouts
import Quickshell
import "schoolutil.js" as U
import "grades.js" as G

// Study > Grades: current grade per course (from Canvas), and a "what do I need?" calculator.
Item {
    id: root
    required property var bar
    signal closeRequested()
    readonly property var sc: bar.school

    property var    course: null               // the course whose detail page is open
    property var    detail: null               // canvas.sh groups result
    property bool   loading: false
    property string error: ""
    property real   target: 90
    property real   assume: 90
    property string pickName: ""               // chosen pending item ("" = all remaining work)

    function gradeTone(s) { return s === null || s === undefined ? Theme.muted : s < 60 ? Theme.crit : s < 70 ? Theme.warn : Theme.text }

    Job { id: grpJob; script: Quickshell.shellPath("canvas.sh") }
    function activate() {}
    function open(c) {
        course = c; detail = null; error = ""; loading = true; pickName = ""
        var id = c.id
        grpJob.go(["groups", String(id)], r => {
            loading = false
            if (!course || course.id !== id) return
            if (r && r.groups) {
                detail = r
                var cur = G.current(r)
                assume = cur === null ? 90 : Math.round(cur)
                target = Math.min(100, Math.ceil((cur === null ? 85 : cur) / 5) * 5 + (cur !== null && cur % 5 === 0 ? 5 : 0))
                if (target <= (cur || 0)) target = Math.min(100, Math.floor((cur || 80) / 5) * 5 + 5)
            } else error = r && r.error ? r.error : "Could not load this course."
        })
    }

    readonly property var pending: detail ? G.pendingList(detail) : []
    readonly property var result: {
        if (!detail || pending.length === 0) return null
        if (pickName === "") return G.neededOnRest(detail, target)
        var p = pending.find(x => x.name === pickName)
        return p ? G.neededOnItem(detail, p.group, p.name, target, assume) : null
    }

    // ── course list ──
    ColumnLayout {
        visible: root.course === null && root.sc.configured
        anchors { fill: parent; topMargin: 6 }
        spacing: 10
        Text { text: "Grades"; color: Theme.text; font { family: Theme.fontUi; pixelSize: 18; weight: Font.DemiBold } }
        ListView {
            id: courses
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: 8
            boundsBehavior: Flickable.StopAtBounds
            model: root.sc.courses
            delegate: Rectangle {
                id: cr
                required property var modelData
                readonly property var score: modelData.score
                width: courses.width; height: 64; radius: 12
                color: ch.hovered ? Theme.bg : Theme.raised
                border { width: 1; color: Theme.hairline }
                HoverHandler { id: ch }
                MouseArea { anchors.fill: parent; onClicked: root.open(cr.modelData) }
                RowLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                    spacing: 14
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 3
                        Text { text: cr.modelData.name; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
                        Text { text: cr.modelData.code + (cr.modelData.term ? "  ·  " + cr.modelData.term : ""); color: Theme.muted; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: Theme.fontUi; pixelSize: 12 } }
                        Meter { Layout.fillWidth: true; value: (cr.score || 0) / 100; tone: root.gradeTone(cr.score) === Theme.text ? Theme.muted : root.gradeTone(cr.score) }
                    }
                    ColumnLayout {
                        spacing: 0
                        Text { Layout.alignment: Qt.AlignRight; text: cr.score === null || cr.score === undefined ? "–" : cr.score.toFixed(1) + "%"; color: root.gradeTone(cr.score); font { family: Theme.fontUi; pixelSize: 16 } }
                        Text { Layout.alignment: Qt.AlignRight; text: cr.modelData.grade || (cr.score !== null && cr.score !== undefined ? G.letter(cr.score) : ""); color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 } }
                    }
                }
            }
            Text {
                visible: courses.count === 0
                anchors.centerIn: parent; color: Theme.muted; font { family: Theme.fontUi; pixelSize: Theme.sizeUi }
                text: root.sc.syncing ? "Loading from Canvas…" : "No courses yet."
            }
        }
    }
    Text {
        visible: !root.sc.configured
        anchors.centerIn: parent; horizontalAlignment: Text.AlignHCenter; color: Theme.muted; font { family: Theme.fontUi; pixelSize: Theme.sizeUi }
        text: "Connect Canvas on the Due tab\nto see your grades here."
    }

    // ── one course ──
    Flickable {
        id: det
        visible: root.course !== null
        anchors { fill: parent; topMargin: 6 }
        contentHeight: detCol.implicitHeight + 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: detCol
            width: det.width; spacing: 10

            RowLayout {
                Layout.fillWidth: true; spacing: 12
                Chip { text: "Back"; onClicked: { root.course = null; root.detail = null } }
                Text { text: root.course ? root.course.name : ""; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: Theme.fontUi; pixelSize: 18; weight: Font.DemiBold } }
                Text {
                    readonly property real cur: root.detail ? (root.detail.score !== null && root.detail.score !== undefined ? root.detail.score : (G.current(root.detail) === null ? -1 : G.current(root.detail))) : -1
                    text: cur < 0 ? "" : cur.toFixed(1) + "%  " + G.letter(cur)
                    color: root.gradeTone(cur < 0 ? null : cur); font { family: Theme.fontUi; pixelSize: 16 }
                }
            }
            Text { visible: root.loading; text: "Loading…"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
            Text { visible: root.error.length > 0; text: root.error; color: Theme.crit; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }

            Repeater {
                model: root.detail ? G.prep(root.detail) : []
                delegate: Rectangle {
                    id: gr
                    required property var modelData
                    Layout.fillWidth: true; implicitHeight: 54; radius: 10; color: "transparent"; border { width: 1; color: Theme.hairline }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                        spacing: 12
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 4
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: gr.modelData.name; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
                                Text { visible: root.detail && root.detail.weighted; text: gr.modelData.weight + "% of grade"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 } }
                            }
                            Meter { Layout.fillWidth: true; value: (gr.modelData.pct || 0) / 100 }
                        }
                        ColumnLayout {
                            spacing: 0
                            Text { Layout.alignment: Qt.AlignRight; text: gr.modelData.pct === null ? "–" : gr.modelData.pct.toFixed(1) + "%"; color: Theme.text; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
                            Text { Layout.alignment: Qt.AlignRight; visible: gr.modelData.pendingItems.length > 0; text: gr.modelData.pendingItems.length + " to go"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 } }
                        }
                    }
                }
            }

            Card {
                visible: root.detail !== null
                spacing: 10
                Text { text: "What do I need?"; color: Theme.text; font { family: Theme.fontUi; pixelSize: Theme.sizeUi; weight: Font.DemiBold } }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Text { text: "I want to finish with"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
                    Field {
                        id: targetIn
                        Layout.preferredWidth: 64; implicitHeight: 32
                        text: String(Math.round(root.target))
                        input.inputMethodHints: Qt.ImhFormattedNumbersOnly
                        input.onTextEdited: { var v = parseFloat(text); if (isFinite(v)) root.target = Math.max(0, Math.min(150, v)) }
                    }
                    Text { text: "%"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
                    Item { Layout.fillWidth: true }
                    Repeater {
                        model: [90, 80, 70]
                        delegate: Chip { required property int modelData; text: G.letter(modelData); selected: Math.round(root.target) === modelData; onClicked: { root.target = modelData; targetIn.text = String(modelData) } }
                    }
                }
                Flow {
                    Layout.fillWidth: true; spacing: 6
                    Repeater {
                        model: [{ name: "", label: "All remaining work" }].concat(root.pending.slice(0, 14).map(p => ({ name: p.name, label: p.name })))
                        delegate: Chip {
                            required property var modelData
                            text: modelData.label.length > 28 ? modelData.label.slice(0, 27) + "…" : modelData.label
                            selected: root.pickName === modelData.name
                            onClicked: root.pickName = modelData.name
                        }
                    }
                }
                RowLayout {
                    visible: root.pickName !== ""
                    Layout.fillWidth: true; spacing: 8
                    Text { text: "If everything else scores"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
                    Field {
                        Layout.preferredWidth: 64; implicitHeight: 32
                        text: String(root.assume)
                        input.onTextEdited: { var v = parseFloat(text); if (isFinite(v)) root.assume = Math.max(0, Math.min(150, v)) }
                    }
                    Text { text: "%"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
                }
                Text {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                    readonly property var r: root.result
                    text: {
                        if (!root.detail) return ""
                        if (root.pending.length === 0) return "Everything in this course is already graded."
                        if (!r || r.none) return "Not enough information to work that out."
                        var what = root.pickName === "" ? "your remaining work" : root.pickName
                        if (r.secure) return "You are already safe: even 0% on " + what + " keeps you at or above " + Math.round(root.target) + "%."
                        if (r.impossible) return Math.round(root.target) + "% is out of reach. It would take " + r.pct.toFixed(1) + "% on " + what + ". Try a lower target."
                        return "You need " + r.pct.toFixed(1) + "% on " + what + (root.pickName !== "" && r.points !== undefined ? " (" + r.points.toFixed(1) + " of " + r.outOf + " points)" : " (on average).")
                    }
                    color: !r || r.none ? Theme.muted : r.secure ? Theme.good : r.impossible ? Theme.crit : Theme.text
                    font { family: Theme.fontUi; pixelSize: Theme.sizeUi }
                }
            }
        }
    }
}
