import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "schoolutil.js" as U

// School > Exams: countdowns, a topic checklist for each exam, and a study plan that spreads the topics you have left
// over the days before it. Canvas exams (names with exam / midterm / quiz / final) appear by themselves; add others yourself.
Item {
    id: root
    required property var bar
    readonly property var sc: bar.school
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.red
    property string openId: ""                     // exam whose card is expanded
    property bool   adding: false
    property string addError: ""

    function days(e) { return U.dayCount(e.whenMs, sc.nowMs) }
    function countdown(e) {
        var d = days(e)
        if (d <= 0) { var h = Math.floor((e.whenMs - sc.nowMs) / 3600000); return e.whenMs <= sc.nowMs ? "now" : (h <= 0 ? "under an hour" : "in " + h + "h") }
        return d === 1 ? "tomorrow" : "in " + d + " days"
    }
    function urgency(e) { var d = days(e); return d <= 1 ? Theme.red : d <= 4 ? Theme.yellow : Theme.green }
    function activate() {}

    ColumnLayout {
        anchors { fill: parent; leftMargin: 14; rightMargin: 14; topMargin: 8; bottomMargin: 10 }
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            Text { text: "󰈙  Exams"; color: root.accent; font { family: root.font; pixelSize: 12; bold: true } }
            Item { Layout.fillWidth: true }
            Rectangle {
                Layout.preferredHeight: 26; Layout.preferredWidth: at.implicitWidth + 20; radius: 13; color: root.adding ? Qt.alpha(root.accent, 0.22) : Theme.card; border { color: root.adding ? root.accent : Theme.cardBorder; width: 1 }
                Text { id: at; anchors.centerIn: parent; text: root.adding ? "cancel" : "+ add exam"; color: Theme.text; font { family: root.font; pixelSize: 10 } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.adding = !root.adding; root.addError = ""; if (root.adding) nameIn.forceActiveFocus() } }
            }
        }

        // add form
        Rectangle {
            visible: root.adding
            Layout.fillWidth: true; implicitHeight: addCol.implicitHeight + 20; radius: 12; color: Qt.alpha(root.accent, 0.07); border { color: Qt.alpha(root.accent, 0.35); width: 1 }
            ColumnLayout {
                id: addCol
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                spacing: 6
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 32; radius: 8; color: Qt.alpha(Theme.mauve, 0.08); border { color: nameIn.activeFocus ? Qt.alpha(root.accent, 0.6) : Theme.sep; width: 1 }
                    TextInput { id: nameIn; anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
verticalAlignment: TextInput.AlignVCenter; color: Theme.text; clip: true; font { family: root.font; pixelSize: 12 }
                                KeyNavigation.tab: whenIn
                                Text { visible: nameIn.text.length === 0; anchors.verticalCenter: parent.verticalCenter; text: "name, e.g. Orbital Mechanics midterm"; color: Theme.dim; font { family: root.font; pixelSize: 11 } } }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 32; radius: 8; color: Qt.alpha(Theme.mauve, 0.08); border { color: whenIn.activeFocus ? Qt.alpha(root.accent, 0.6) : Theme.sep; width: 1 }
                    TextInput { id: whenIn; anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
verticalAlignment: TextInput.AlignVCenter; color: Theme.text; clip: true; font { family: root.font; pixelSize: 12 }
                                onAccepted: addBtn.go()
                                Text { visible: whenIn.text.length === 0; anchors.verticalCenter: parent.verticalCenter; text: "when: 10/22 2pm   or   oct 22 14:00   or   2026-10-22 14:00"; color: Theme.dim; font { family: root.font; pixelSize: 11 } } }
                }
                Flow {
                    Layout.fillWidth: true; spacing: 5
                    visible: root.sc.courses.length > 0
                    Repeater {
                        model: root.sc.courses
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool sel: courseVal.text === modelData.code
                            height: 24; width: cl.implicitWidth + 16; radius: 12; color: sel ? Qt.alpha(root.accent, 0.22) : Theme.card; border { color: sel ? root.accent : Theme.cardBorder; width: 1 }
                            Text { id: cl; anchors.centerIn: parent; text: modelData.code; color: Theme.text; font { family: root.font; pixelSize: 10 } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: courseVal.text = (parent.sel ? "" : modelData.code) }
                        }
                    }
                }
                Text { id: courseVal; visible: false; text: "" }
                Text { visible: root.addError.length > 0; text: root.addError; color: Theme.red; font { family: root.font; pixelSize: 10 } }
                Rectangle {
                    id: addBtn
                    function go() {
                        var ms = U.parseWhen(whenIn.text, Date.now())
                        if (!nameIn.text.trim()) { root.addError = "give the exam a name"; return }
                        if (isNaN(ms)) { root.addError = "I could not read that date — try  10/22 2pm"; return }
                        root.sc.addExam(nameIn.text.trim(), courseVal.text, ms)
                        nameIn.text = ""; whenIn.text = ""; courseVal.text = ""; root.adding = false; root.addError = ""
                    }
                    Layout.fillWidth: true; Layout.preferredHeight: 32; radius: 10; color: root.accent
                    Text { anchors.centerIn: parent; text: "Add"; color: Theme.crust; font { family: root.font; pixelSize: 12; bold: true } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: addBtn.go() }
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: 6; boundsBehavior: Flickable.StopAtBounds
            model: root.sc.exams
            delegate: Rectangle {
                id: ex
                required property var modelData
                readonly property bool open: root.openId === modelData.id
                readonly property var topics: root.sc.topicsOf(modelData.id)
                readonly property real ready: root.sc.examReadiness(modelData)
                readonly property var plan: U.studyPlan(topics, modelData.whenMs, root.sc.nowMs, 8)
                width: list.width; height: exCol.implicitHeight + 20; radius: 12
                color: Theme.card; border { color: open ? Qt.alpha(root.urgency(modelData), 0.6) : Theme.cardBorder; width: 1 }
                ColumnLayout {
                    id: exCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; topMargin: 10 }
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true; spacing: 10
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 1
                            Text { text: ex.modelData.name; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 12; bold: true } }
                            Text { text: (ex.modelData.course ? ex.modelData.course + "  ·  " : "") + U.dueLabel(ex.modelData.whenMs, root.sc.nowMs); color: Theme.dim; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 10 } }
                        }
                        Text { text: root.countdown(ex.modelData); color: root.urgency(ex.modelData); font { family: root.font; pixelSize: 13; bold: true } }
                    }
                    Rectangle {
                        visible: ex.topics.length > 0
                        Layout.fillWidth: true; Layout.preferredHeight: 5; radius: 2.5; color: Qt.alpha(root.urgency(ex.modelData), 0.15)
                        Rectangle { width: parent.width * Math.max(0, ex.ready); height: parent.height; radius: 2.5; color: root.urgency(ex.modelData) }
                    }
                    Text {
                        visible: !ex.open
                        text: ex.topics.length ? ex.topics.filter(t => t.done).length + " of " + ex.topics.length + " topics ready" + (ex.plan.length && ex.plan[0].day === 0 && ex.plan[0].topics.length ? "  ·  today: " + ex.plan[0].topics.join(", ") : "") : "tap to add topics and get a study plan"
                        color: Theme.subtext; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 10 }
                    }
                    // expanded
                    ColumnLayout {
                        visible: ex.open
                        Layout.fillWidth: true; spacing: 5
                        Repeater {
                            model: ex.topics
                            delegate: RowLayout {
                                id: tr
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true; spacing: 8
                                Rectangle {
                                    Layout.preferredWidth: 16; Layout.preferredHeight: 16; radius: 8; color: tr.modelData.done ? Theme.green : "transparent"; border { color: tr.modelData.done ? Theme.green : Theme.dim; width: 1.5 }
                                    Text { visible: tr.modelData.done; anchors.centerIn: parent; text: "✓"; color: Theme.crust; font { family: root.font; pixelSize: 10; bold: true } }
                                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                                                onClicked: { var a = ex.topics.slice(); a[tr.index] = { t: tr.modelData.t, done: !tr.modelData.done }; root.sc.setTopics(ex.modelData.id, a) } }
                                }
                                Text { text: tr.modelData.t; color: tr.modelData.done ? Theme.dim : Theme.text; font.strikeout: tr.modelData.done; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 11 } }
                                Text { text: "✕"; color: Theme.dim; font { family: root.font; pixelSize: 10 }
                                       MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: { var a = ex.topics.slice(); a.splice(tr.index, 1); root.sc.setTopics(ex.modelData.id, a) } } }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 30; radius: 8; color: Qt.alpha(Theme.mauve, 0.08); border { color: topicIn.activeFocus ? Qt.alpha(root.accent, 0.6) : Theme.sep; width: 1 }
                            TextInput {
                                id: topicIn
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
verticalAlignment: TextInput.AlignVCenter; color: Theme.text; clip: true; font { family: root.font; pixelSize: 11 }
                                onAccepted: {
                                    var add = text.split(/[;\n]/).map(x => x.trim()).filter(x => x.length)
                                    if (add.length) root.sc.setTopics(ex.modelData.id, ex.topics.concat(add.map(t => ({ t: t, done: false }))))
                                    text = ""
                                }
                                Text { visible: topicIn.text.length === 0; anchors.verticalCenter: parent.verticalCenter; text: "add a topic (enter) — separate several with ;"; color: Theme.dim; font { family: root.font; pixelSize: 10 } }
                            }
                        }
                        Text { visible: ex.plan.length > 0; text: "STUDY PLAN"; color: Theme.dim; topPadding: 4; font { family: root.font; pixelSize: 9; bold: true; letterSpacing: 1 } }
                        Repeater {
                            model: ex.plan
                            delegate: RowLayout {
                                required property var modelData
                                Layout.fillWidth: true; spacing: 8
                                Text { text: modelData.day === 0 ? "today" : modelData.day === 1 ? "tomorrow" : U.dueLabel(modelData.ms, root.sc.nowMs).replace(/ \d+(:\d+)? [AP]M$/, ""); color: modelData.day === 0 ? Theme.yellow : Theme.subtext; Layout.preferredWidth: 70; font { family: root.font; pixelSize: 10 } }
                                Text { text: modelData.review ? "review everything, rest well" : modelData.topics.join("  ·  "); color: modelData.review ? Theme.green : Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 11 } }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 12
                            Text { visible: ex.modelData.url.length > 0; text: "open in Canvas"; color: Theme.blue; font { family: root.font; pixelSize: 10 }
                                   MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: { openProc.command = ["xdg-open", ex.modelData.url]; openProc.running = true; root.bar.hubOpen = false } } }
                            Item { Layout.fillWidth: true }
                            Text { visible: ex.modelData.manual; text: "delete exam"; color: Theme.dim; font { family: root.font; pixelSize: 10 }
                                   MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: { root.openId = ""; root.sc.removeExam(ex.modelData.id) } } }
                        }
                    }
                }
                MouseArea { anchors { left: parent.left; right: parent.right; top: parent.top } height: 50; cursorShape: Qt.PointingHandCursor; onClicked: root.openId = ex.open ? "" : ex.modelData.id; z: -1 }
            }
            Text {
                visible: list.count === 0
                anchors.centerIn: parent; width: parent.width - 40; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; color: Theme.dim; font { family: root.font; pixelSize: 11 }
                text: "No exams coming up. Canvas assignments called exam, midterm, quiz or final show up here by themselves, or add one yourself."
            }
        }
    }
    Process { id: openProc; onExited: running = false }
}
