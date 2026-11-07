import QtQuick
import QtQuick.Layouts
import Quickshell
import "schoolutil.js" as U
import "grades.js" as G

// School > Grades: current grade per course (from Canvas), and a "what do I need?" calculator.
Item {
    id: root
    required property var bar
    readonly property var sc: bar.school
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.blue
    readonly property var palette: [Theme.mauve, Theme.sky, Theme.green, Theme.peach, Theme.pink, Theme.yellow, Theme.teal]

    property var    course: null               // the course whose detail page is open
    property var    detail: null               // canvas.sh groups result
    property bool   loading: false
    property string error: ""
    property real   target: 90
    property real   assume: 90
    property string pickName: ""               // chosen pending item ("" = all remaining work)

    Job { id: grpJob; script: Quickshell.shellPath("canvas.sh") }
    function activate() { if (!sc.configured) return }
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
            } else error = r && r.error ? r.error : "could not load this course"
        })
    }

    readonly property var pending: detail ? G.pendingList(detail) : []
    readonly property var result: {
        if (!detail || pending.length === 0) return null
        if (pickName === "") return G.neededOnRest(detail, target)
        var p = pending.find(x => x.name === pickName)
        return p ? G.neededOnItem(detail, p.group, p.name, target, assume) : null
    }

    // ── course list ───────────────────────────────────────
    ListView {
        id: courses
        visible: root.course === null && root.sc.configured
        anchors { fill: parent; leftMargin: 14; rightMargin: 14; topMargin: 8; bottomMargin: 10 }
        clip: true; spacing: 6; boundsBehavior: Flickable.StopAtBounds
        model: root.sc.courses
        delegate: Rectangle {
            id: cr
            required property var modelData
            required property int index
            readonly property color col: root.palette[index % root.palette.length]
            width: courses.width; height: 64; radius: 12
            color: ch.hovered ? Qt.alpha(cr.col, 0.10) : Theme.card; border { color: Theme.cardBorder; width: 1 }
            HoverHandler { id: ch; cursorShape: Qt.PointingHandCursor }
            MouseArea { anchors.fill: parent; onClicked: root.open(cr.modelData) }
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 14 }
                spacing: 12
                Rectangle { Layout.preferredWidth: 4; Layout.preferredHeight: 38; radius: 2; color: cr.col }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 3
                    Text { text: cr.modelData.name; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 12; bold: true } }
                    Text { text: cr.modelData.code + (cr.modelData.term ? "  ·  " + cr.modelData.term : ""); color: Theme.dim; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 10 } }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 4; radius: 2; color: Qt.alpha(cr.col, 0.15)
                        Rectangle { width: parent.width * Math.max(0, Math.min(1, (cr.modelData.score || 0) / 100)); height: parent.height; radius: 2; color: cr.col }
                    }
                }
                ColumnLayout {
                    spacing: 0
                    Text { Layout.alignment: Qt.AlignRight; text: cr.modelData.score === null || cr.modelData.score === undefined ? "–" : cr.modelData.score.toFixed(1) + "%"; color: cr.col; font { family: root.font; pixelSize: 15; bold: true } }
                    Text { Layout.alignment: Qt.AlignRight; text: cr.modelData.grade || (cr.modelData.score !== null && cr.modelData.score !== undefined ? G.letter(cr.modelData.score) : ""); color: Theme.dim; font { family: root.font; pixelSize: 10 } }
                }
            }
        }
        Text {
            visible: courses.count === 0
            anchors.centerIn: parent; color: Theme.dim; font { family: root.font; pixelSize: 12 }
            text: root.sc.syncing ? "loading from Canvas…" : "No courses yet"
        }
    }
    Text {
        visible: !root.sc.configured
        anchors.centerIn: parent; horizontalAlignment: Text.AlignHCenter; color: Theme.dim; font { family: root.font; pixelSize: 12 }
        text: "Connect Canvas on the Due tab\nto see your grades here."
    }

    // ── one course ────────────────────────────────────────
    Flickable {
        id: det
        visible: root.course !== null
        anchors { fill: parent; leftMargin: 14; rightMargin: 14; topMargin: 6; bottomMargin: 10 }
        contentHeight: detCol.implicitHeight + 8; clip: true; boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: detCol
            width: det.width; spacing: 8
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text {
                    text: "󰁍"; color: Theme.dim; font { family: root.font; pixelSize: 16 }
                    MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: { root.course = null; root.detail = null } }
                }
                Text { text: root.course ? root.course.name : ""; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 13; bold: true } }
                Text {
                    readonly property real cur: root.detail ? (root.detail.score !== null && root.detail.score !== undefined ? root.detail.score : (G.current(root.detail) === null ? -1 : G.current(root.detail))) : -1
                    text: cur < 0 ? "" : cur.toFixed(1) + "%  " + G.letter(cur); color: root.accent; font { family: root.font; pixelSize: 13; bold: true }
                }
            }
            Text { visible: root.loading; text: "loading…"; color: Theme.dim; font { family: root.font; pixelSize: 11 } }
            Text { visible: root.error.length > 0; text: root.error; color: Theme.red; font { family: root.font; pixelSize: 11 } }

            // groups
            Repeater {
                model: root.detail ? G.prep(root.detail) : []
                delegate: Rectangle {
                    id: gr
                    required property var modelData
                    Layout.fillWidth: true; implicitHeight: 48; radius: 10; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        spacing: 10
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 3
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: gr.modelData.name; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 11; bold: true } }
                                Text { visible: root.detail && root.detail.weighted; text: gr.modelData.weight + "%"; color: Theme.dim; font { family: root.font; pixelSize: 10 } }
                            }
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 4; radius: 2; color: Qt.alpha(root.accent, 0.15)
                                Rectangle { width: parent.width * Math.max(0, Math.min(1, (gr.modelData.pct || 0) / 100)); height: parent.height; radius: 2; color: root.accent }
                            }
                        }
                        ColumnLayout {
                            spacing: 0
                            Text { Layout.alignment: Qt.AlignRight; text: gr.modelData.pct === null ? "–" : gr.modelData.pct.toFixed(1) + "%"; color: Theme.text; font { family: root.font; pixelSize: 12; bold: true } }
                            Text { Layout.alignment: Qt.AlignRight; text: gr.modelData.pendingItems.length + " to go"; visible: gr.modelData.pendingItems.length > 0; color: Theme.dim; font { family: root.font; pixelSize: 9 } }
                        }
                    }
                }
            }

            // calculator
            Rectangle {
                visible: root.detail !== null
                Layout.fillWidth: true; implicitHeight: calcCol.implicitHeight + 24; radius: 12
                color: Qt.alpha(root.accent, 0.07); border { color: Qt.alpha(root.accent, 0.35); width: 1 }
                ColumnLayout {
                    id: calcCol
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                    spacing: 8
                    Text { text: "What do I need?"; color: root.accent; font { family: root.font; pixelSize: 12; bold: true } }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text { text: "I want to finish with"; color: Theme.subtext; font { family: root.font; pixelSize: 11 } }
                        Rectangle {
                            Layout.preferredWidth: 56; Layout.preferredHeight: 28; radius: 8; color: Qt.alpha(Theme.mauve, 0.08); border { color: Theme.sep; width: 1 }
                            TextInput {
                                id: targetIn
                                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
verticalAlignment: TextInput.AlignVCenter
                                text: String(Math.round(root.target)); color: Theme.text; selectByMouse: true; inputMethodHints: Qt.ImhFormattedNumbersOnly
                                font { family: root.font; pixelSize: 12 }
                                onTextEdited: { var v = parseFloat(text); if (isFinite(v)) root.target = Math.max(0, Math.min(150, v)) }
                            }
                        }
                        Text { text: "%"; color: Theme.dim; font { family: root.font; pixelSize: 11 } }
                        Item { Layout.fillWidth: true }
                        Repeater {
                            model: [90, 80, 70]
                            delegate: Rectangle {
                                required property int modelData
                                Layout.preferredWidth: 34; Layout.preferredHeight: 24; radius: 8; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                                Text { anchors.centerIn: parent; text: G.letter(modelData); color: Theme.text; font { family: root.font; pixelSize: 10 } }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.target = modelData; targetIn.text = String(modelData) } }
                            }
                        }
                    }
                    // which work to solve for
                    Flow {
                        Layout.fillWidth: true; spacing: 5
                        Repeater {
                            model: [{ name: "", label: "all remaining work" }].concat(root.pending.slice(0, 14).map(p => ({ name: p.name, label: p.name })))
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool sel: root.pickName === modelData.name
                                height: 24; width: Math.min(190, lt.implicitWidth + 18); radius: 12
                                color: sel ? Qt.alpha(root.accent, 0.22) : Theme.card; border { color: sel ? root.accent : Theme.cardBorder; width: 1 }
                                Text { id: lt; anchors.centerIn: parent; width: Math.min(172, implicitWidth); elide: Text.ElideRight; text: modelData.label; color: sel ? Theme.text : Theme.subtext; textFormat: Text.PlainText; font { family: root.font; pixelSize: 10 } }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.pickName = modelData.name }
                            }
                        }
                    }
                    RowLayout {
                        visible: root.pickName !== ""
                        Layout.fillWidth: true; spacing: 8
                        Text { text: "if everything else scores"; color: Theme.subtext; font { family: root.font; pixelSize: 11 } }
                        Rectangle {
                            Layout.preferredWidth: 56; Layout.preferredHeight: 28; radius: 8; color: Qt.alpha(Theme.mauve, 0.08); border { color: Theme.sep; width: 1 }
                            TextInput {
                                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
verticalAlignment: TextInput.AlignVCenter
                                text: String(root.assume); color: Theme.text; selectByMouse: true; font { family: root.font; pixelSize: 12 }
                                onTextEdited: { var v = parseFloat(text); if (isFinite(v)) root.assume = Math.max(0, Math.min(150, v)) }
                            }
                        }
                        Text { text: "%"; color: Theme.dim; font { family: root.font; pixelSize: 11 } }
                    }
                    Text {
                        Layout.fillWidth: true; wrapMode: Text.WordWrap
                        readonly property var r: root.result
                        text: {
                            if (!root.detail) return ""
                            if (root.pending.length === 0) return "Everything in this course is already graded."
                            if (!r || r.none) return "Not enough information to work that out."
                            var what = root.pickName === "" ? "your remaining work" : root.pickName
                            if (r.secure) return "You are already safe: even a 0% on " + what + " keeps you at or above " + Math.round(root.target) + "%."
                            if (r.impossible) return Math.round(root.target) + "% is out of reach — it would take " + r.pct.toFixed(1) + "% on " + what + ".   Try a lower target."
                            return "You need " + r.pct.toFixed(1) + "% on " + what + (root.pickName !== "" && r.points !== undefined ? "  (" + r.points.toFixed(1) + " / " + r.outOf + " pts)" : " (on average)") + "."
                        }
                        color: !r || r.none ? Theme.dim : r.secure ? Theme.green : r.impossible ? Theme.red : Theme.text
                        font { family: root.font; pixelSize: 12; bold: true }
                    }
                }
            }
        }
    }
}
