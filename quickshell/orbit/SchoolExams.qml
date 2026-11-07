import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "schoolutil.js" as U

// Study > Exams: countdowns, a topic checklist for each exam, and a study plan that spreads the topics you have left
// over the days before it. Canvas exams (names with exam, midterm, quiz or final) appear by themselves; add others yourself.
Item {
    id: root
    required property var bar
    signal closeRequested()
    readonly property var sc: bar.school
    property string openId: ""                     // exam whose card is expanded
    property bool adding: false
    property string addError: ""
    property string newCourse: ""
    function activate() {}

    function days(e) { return U.dayCount(e.whenMs, sc.nowMs) }
    function countdown(e) {
        var d = days(e)
        if (d <= 0) { var h = Math.floor((e.whenMs - sc.nowMs) / 3600000); return e.whenMs <= sc.nowMs ? "Now" : (h <= 0 ? "Under an hour" : "In " + h + " h") }
        return d === 1 ? "Tomorrow" : "In " + d + " days"
    }
    function tone(e) { var d = days(e); return d <= 1 ? Theme.crit : d <= 4 ? Theme.warn : Theme.muted }

    Process { id: openProc; onExited: running = false }

    ColumnLayout {
        anchors { fill: parent; topMargin: 6 }
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Text { text: "Exams"; color: Theme.text; font { family: Theme.fontUi; pixelSize: 18; weight: Font.DemiBold } }
            Item { Layout.fillWidth: true }
            Chip { text: root.adding ? "Cancel" : "Add exam"; selected: root.adding; onClicked: { root.adding = !root.adding; root.addError = ""; if (root.adding) nameIn.input.forceActiveFocus() } }
        }

        Card {
            visible: root.adding
            spacing: 8
            Field { id: nameIn; Layout.fillWidth: true; placeholder: "Name, e.g. Orbital Mechanics midterm"; input.KeyNavigation.tab: whenIn.input }
            Field { id: whenIn; Layout.fillWidth: true; placeholder: "When: 10/22 2pm, or oct 22 14:00, or 2026-10-22 14:00"; onAccepted: addBtn.go() }
            Flow {
                Layout.fillWidth: true; spacing: 6
                visible: root.sc.courses.length > 0
                Repeater {
                    model: root.sc.courses
                    delegate: Chip { required property var modelData; text: modelData.code; selected: root.newCourse === modelData.code; onClicked: root.newCourse = selected ? "" : modelData.code }
                }
            }
            Text { visible: root.addError.length > 0; text: root.addError; color: Theme.crit; font { family: Theme.fontUi; pixelSize: 12 } }
            Chip {
                id: addBtn
                filled: true; text: "Add"
                function go() {
                    var ms = U.parseWhen(whenIn.text, Date.now())
                    if (!nameIn.text.trim()) { root.addError = "Give the exam a name."; return }
                    if (isNaN(ms)) { root.addError = "That date could not be read. Try 10/22 2pm."; return }
                    root.sc.addExam(nameIn.text.trim(), root.newCourse, ms)
                    nameIn.text = ""; whenIn.text = ""; root.newCourse = ""; root.adding = false; root.addError = ""
                }
                onClicked: go()
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: 8
            boundsBehavior: Flickable.StopAtBounds
            model: root.sc.exams

            delegate: Rectangle {
                id: ex
                required property var modelData
                readonly property bool open: root.openId === modelData.id
                readonly property var topics: root.sc.topicsOf(modelData.id)
                readonly property real ready: root.sc.examReadiness(modelData)
                readonly property var plan: U.studyPlan(topics, modelData.whenMs, root.sc.nowMs, 8)
                width: list.width
                height: exCol.implicitHeight + 24
                radius: 12; color: Theme.raised
                border { width: 1; color: open ? Theme.accent : Theme.hairline }

                MouseArea { anchors { left: parent.left; right: parent.right; top: parent.top } height: 58; onClicked: root.openId = ex.open ? "" : ex.modelData.id }

                ColumnLayout {
                    id: exCol
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14; topMargin: 12 }
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true; spacing: 12
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 1
                            Text { text: ex.modelData.name; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
                            Text { text: (ex.modelData.course ? ex.modelData.course + "  ·  " : "") + U.dueLabel(ex.modelData.whenMs, root.sc.nowMs); color: Theme.muted; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: Theme.fontUi; pixelSize: 12 } }
                        }
                        Text { text: root.countdown(ex.modelData); color: root.tone(ex.modelData); font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
                    }
                    Meter { visible: ex.topics.length > 0; Layout.fillWidth: true; value: ex.ready; tone: ex.ready >= 1 ? Theme.good : Theme.muted }
                    Text {
                        visible: !ex.open
                        text: ex.topics.length
                              ? ex.topics.filter(t => t.done).length + " of " + ex.topics.length + " topics ready"
                                + (ex.plan.length && ex.plan[0].day === 0 && ex.plan[0].topics.length ? "  ·  today: " + ex.plan[0].topics.join(", ") : "")
                              : "No topics yet. Open to add some."
                        color: Theme.muted; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: Theme.fontUi; pixelSize: 12 }
                    }

                    ColumnLayout {   // expanded
                        visible: ex.open
                        Layout.fillWidth: true; spacing: 8
                        Repeater {
                            model: ex.topics
                            delegate: RowLayout {
                                id: tr
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true; spacing: 10
                                Rectangle {
                                    Layout.preferredWidth: 16; Layout.preferredHeight: 16; radius: 8
                                    color: tr.modelData.done ? Theme.good : "transparent"
                                    border { width: 1.5; color: tr.modelData.done ? Theme.good : Theme.muted }
                                    MouseArea { anchors.fill: parent; anchors.margins: -4
                                                onClicked: { var a = ex.topics.slice(); a[tr.index] = { t: tr.modelData.t, done: !tr.modelData.done }; root.sc.setTopics(ex.modelData.id, a) } }
                                }
                                Text { text: tr.modelData.t; color: tr.modelData.done ? Theme.muted : Theme.text; font.strikeout: tr.modelData.done; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
                                Text { text: "Remove"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 }
                                       MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: { var a = ex.topics.slice(); a.splice(tr.index, 1); root.sc.setTopics(ex.modelData.id, a) } } }
                            }
                        }
                        Field {
                            id: topicIn
                            Layout.fillWidth: true
                            placeholder: "Add a topic and press Enter. Separate several with ;"
                            onAccepted: {
                                var add = text.split(/[;\n]/).map(x => x.trim()).filter(x => x.length)
                                if (add.length) root.sc.setTopics(ex.modelData.id, ex.topics.concat(add.map(t => ({ t: t, done: false }))))
                                text = ""
                            }
                        }
                        Heading { visible: ex.plan.length > 0; text: "Study plan" }
                        Repeater {
                            model: ex.plan
                            delegate: RowLayout {
                                required property var modelData
                                Layout.fillWidth: true; spacing: 12
                                Text {
                                    text: modelData.day === 0 ? "Today" : modelData.day === 1 ? "Tomorrow" : U.dueLabel(modelData.ms, root.sc.nowMs).replace(/ \d+(:\d+)? [AP]M$/, "")
                                    color: modelData.day === 0 ? Theme.text : Theme.muted; Layout.preferredWidth: 90; font { family: Theme.fontUi; pixelSize: 12 }
                                }
                                Text {
                                    text: modelData.review ? "Review everything and rest" : modelData.topics.join("  ·  ")
                                    color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: Theme.fontUi; pixelSize: 12 }
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 12
                            Text {
                                visible: ex.modelData.url.length > 0; text: "Open in Canvas"; color: Theme.text; font { family: Theme.fontUi; pixelSize: 12 }
                                MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: { openProc.command = ["xdg-open", ex.modelData.url]; openProc.running = true; root.closeRequested() } }
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                visible: ex.modelData.manual; text: "Delete exam"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 }
                                MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: { root.openId = ""; root.sc.removeExam(ex.modelData.id) } }
                            }
                        }
                    }
                }
            }

            Text {
                visible: list.count === 0
                anchors.centerIn: parent; width: parent.width - 40; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                color: Theme.muted; font { family: Theme.fontUi; pixelSize: Theme.sizeUi }
                text: "No exams coming up. Canvas assignments called exam, midterm, quiz or final show up here by themselves, or add one yourself."
            }
        }
    }
}
