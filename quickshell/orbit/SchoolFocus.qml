import QtQuick
import QtQuick.Layouts
import "schoolutil.js" as U

// Study > Focus: study timer, focus mode (needs your password to end early), nudges, and the battery and bedtime helpers.
Flickable {
    id: root
    required property var bar
    signal closeRequested()
    readonly property var fs: bar.studyFocus
    readonly property var sc: bar.school
    function activate() {}

    contentHeight: col.implicitHeight + 12
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
        id: col
        y: 6
        width: root.width
        spacing: 12

        // ── timer ──
        Card {
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: root.fs.phase === "idle" ? "Study timer" : root.fs.phase === "focus" ? "Focus" : root.fs.phase === "break" ? "Break" : "Long break"
                    color: Theme.text; font { family: Theme.fontUi; pixelSize: Theme.sizeUi; weight: Font.DemiBold }
                }
                Item { Layout.fillWidth: true }
                Row {   // sessions finished in this cycle
                    spacing: 5
                    Repeater {
                        model: root.fs.cfg.every
                        delegate: Rectangle { required property int index; width: 8; height: 8; radius: 4; color: index < root.fs.cycle ? Theme.text : "transparent"; border { width: 1; color: Theme.muted } }
                    }
                }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.fs.clock(root.fs.remaining)
                color: Theme.text
                font { family: Theme.fontUi; pixelSize: 52; weight: Font.Light }
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter; spacing: 8
                Chip { filled: true; implicitWidth: 110; text: root.fs.running ? "Pause" : (root.fs.phase === "idle" ? "Start" : "Resume"); onClicked: root.fs.toggle() }
                Chip { visible: root.fs.phase !== "idle"; text: "Skip"; onClicked: root.fs.skip() }
                Chip { visible: root.fs.phase !== "idle"; text: "Reset"; onClicked: root.fs.reset() }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 24
                Stepper { label: "Focus"; value: root.fs.cfg.focus; from: 5; to: 90; step: 5; onChanged: v => root.fs.setCfg("focus", v) }
                Stepper { label: "Break"; value: root.fs.cfg.brk; from: 1; to: 30; onChanged: v => root.fs.setCfg("brk", v) }
            }
            RowLayout {   // the assignment being worked on (set with Start timer on the Due list)
                visible: root.fs.taskItem !== null
                Layout.fillWidth: true; spacing: 10
                Text { text: "Working on"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 } }
                Text { text: root.fs.taskItem ? root.fs.taskItem.name : ""; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
                Text { text: root.fs.taskItem ? U.minutesText(root.sc.taskLog[String(root.fs.taskItem.id)] || 0) + " so far" : ""; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 } }
                Text { text: "Clear"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 }
                       MouseArea { anchors.fill: parent; anchors.margins: -5; onClicked: root.fs.setTask("") } }
            }
            Heading { text: "Studying" }
            Flow {
                Layout.fillWidth: true; spacing: 6
                Repeater {
                    model: [{ code: "", label: "General" }].concat(root.sc.courses.map(c => ({ code: c.code, label: c.code })))
                    delegate: Chip { required property var modelData; text: modelData.label; selected: root.fs.course === modelData.code; onClicked: { root.fs.flushLog(); root.fs.setCourse(modelData.code) } }
                }
            }
            Toggle { label: "Silence notifications while focusing"; on: root.fs.cfg.autoDnd; onFlipped: { root.fs.setCfg("autoDnd", !root.fs.cfg.autoDnd); root.fs.applyDnd() } }
            RowLayout {   // this week
                Layout.fillWidth: true; spacing: 18
                ColumnLayout {
                    spacing: 0
                    Text { text: U.minutesText(root.fs.todayMinutes); color: Theme.text; font { family: Theme.fontUi; pixelSize: 18 } }
                    Text { text: "Focused today"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 } }
                }
                ColumnLayout {
                    spacing: 0
                    Text { text: U.minutesText(root.fs.weekMinutes); color: Theme.text; font { family: Theme.fontUi; pixelSize: 18 } }
                    Text { text: "This week"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 } }
                }
                Item { Layout.fillWidth: true }
                Row {
                    spacing: 6; Layout.alignment: Qt.AlignBottom
                    Repeater {
                        model: root.fs.week
                        delegate: Column {
                            required property var modelData
                            spacing: 3
                            Item {
                                width: 16; height: 36
                                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Math.max(2, Math.min(36, modelData.min / 180 * 36)); radius: 3; color: modelData.min > 0 ? Theme.text : Theme.hairline }
                            }
                            Text { text: modelData.day; color: Theme.muted; anchors.horizontalCenter: parent.horizontalCenter; font { family: Theme.fontUi; pixelSize: 10 } }
                        }
                    }
                }
            }
        }

        // ── this week, by course ──
        Card {
            visible: root.fs.byCourse.length > 0
            Text { text: "This week by course"; color: Theme.text; font { family: Theme.fontUi; pixelSize: Theme.sizeUi; weight: Font.DemiBold } }
            Repeater {
                model: root.fs.byCourse
                delegate: ColumnLayout {
                    id: cb
                    required property var modelData
                    readonly property real maxMin: root.fs.byCourse.length ? root.fs.byCourse[0].min : 1
                    Layout.fillWidth: true; spacing: 3
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: cb.modelData.course === "" ? "General" : cb.modelData.course; color: Theme.text; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
                        Item { Layout.fillWidth: true }
                        Text { text: U.minutesText(cb.modelData.min); color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 } }
                    }
                    Meter { Layout.fillWidth: true; value: cb.modelData.min / cb.maxMin }
                }
            }
        }

        // ── study time over a longer stretch ──
        SchoolHistory { fs: root.fs; sc: root.sc }

        // ── focus mode ──
        Card {
            id: modeCard
            property bool askingPw: false
            RowLayout {
                Layout.fillWidth: true
                Text { text: "Focus mode"; color: root.fs.modeOn ? Theme.warn : Theme.text; font { family: Theme.fontUi; pixelSize: Theme.sizeUi; weight: Font.DemiBold } }
                Item { Layout.fillWidth: true }
                Text {
                    visible: root.fs.modeOn
                    text: "Ends " + U.clock(root.fs.modeUntil) + "  (" + U.rel(root.fs.modeUntil, root.fs.now).replace("in ", "") + ")"
                    color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 }
                }
            }
            Text {
                visible: !root.fs.modeOn
                Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 }
                text: "Silences notifications and keeps " + (root.fs.blocked.length ? root.fs.blocked.slice(0, 4).join(", ") + (root.fs.blocked.length > 4 ? " and more" : "") : "your distraction apps") + " closed until it ends."
            }
            RowLayout {
                visible: !root.fs.modeOn
                Layout.fillWidth: true; spacing: 8
                Repeater {
                    model: [30, 60, 90, 120, 180]
                    delegate: Chip { required property int modelData; Layout.fillWidth: true; text: U.minutesText(modelData); onClicked: root.fs.startMode(modelData) }
                }
            }
            Text { visible: root.fs.modeOn && !modeCard.askingPw; text: "Notifications are silenced and your distraction apps stay closed."; color: Theme.muted; Layout.fillWidth: true; wrapMode: Text.WordWrap; font { family: Theme.fontUi; pixelSize: 12 } }
            Chip { visible: root.fs.modeOn && !modeCard.askingPw; text: "Turn off early…"; onClicked: { modeCard.askingPw = true; pwIn.input.forceActiveFocus() } }
            ColumnLayout {
                visible: root.fs.modeOn && modeCard.askingPw
                Layout.fillWidth: true; spacing: 8
                Text { text: "Type your login password to end focus mode:"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 } }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Field { id: pwIn; Layout.fillWidth: true; password: true; onAccepted: { root.fs.endWithPassword(text); text = "" } }
                    Chip { danger: true; text: root.fs.checking ? "…" : "End it"; onClicked: { root.fs.endWithPassword(pwIn.text); pwIn.text = "" } }
                }
                Text { visible: root.fs.endError.length > 0; text: root.fs.endError; color: Theme.crit; font { family: Theme.fontUi; pixelSize: 12 } }
            }
            Connections { target: root.fs; function onModeOnChanged() { if (!root.fs.modeOn) modeCard.askingPw = false } }
        }

        // ── nudges ──
        Card {
            spacing: 10
            Text { text: "Nudges"; color: Theme.text; font { family: Theme.fontUi; pixelSize: Theme.sizeUi; weight: Font.DemiBold } }
            Repeater {
                model: Object.keys(root.fs.nudges)
                delegate: Toggle {
                    required property string modelData
                    label: root.fs.nudges[modelData].label; sub: root.fs.nudges[modelData].sub
                    on: !!root.fs.nudgeOn[modelData]; onFlipped: root.fs.setNudge(modelData, !root.fs.nudgeOn[modelData])
                }
            }
        }

        // ── battery and sleep ──
        Card {
            spacing: 10
            Text { text: "Battery and sleep"; color: Theme.text; font { family: Theme.fontUi; pixelSize: Theme.sizeUi; weight: Font.DemiBold } }
            Toggle {
                label: "Charge before long classes"; sub: "Warns you when the battery will not last to the end of an event in your calendar"
                on: root.sc.pref("batteryAssist", true); onFlipped: root.sc.setPref("batteryAssist", !root.sc.pref("batteryAssist", true))
            }
            Toggle {
                label: "Bedtime reminder"
                sub: root.sc.bedtime ? "Next: bed by " + U.clock(root.sc.bedtime.ms) + " for " + root.sc.bedtime.title + " at " + U.clock(root.sc.bedtime.startMs) : "Based on your first class tomorrow"
                on: root.sc.pref("bedtimeAssist", true); onFlipped: root.sc.setPref("bedtimeAssist", !root.sc.pref("bedtimeAssist", true))
            }
            Stepper { label: "Study hours I can fit in a day"; value: root.sc.dailyHours; from: 1; to: 12; unit: " h"; onChanged: v => root.sc.setPref("dailyHours", v) }
            Stepper { label: "Sleep I want"; value: root.sc.pref("sleepHours", 8); from: 5; to: 11; unit: " h"; onChanged: v => root.sc.setPref("sleepHours", v) }
            Stepper { label: "Time to get ready"; value: root.sc.pref("prepMinutes", 75); from: 15; to: 180; step: 15; onChanged: v => root.sc.setPref("prepMinutes", v) }
        }
    }
}
