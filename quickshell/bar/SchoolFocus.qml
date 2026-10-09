import QtQuick
import QtQuick.Layouts
import Quickshell
import "schoolutil.js" as U

// School > Focus: study timer, focus mode (needs your password to end early), nudges, and the battery/bedtime helpers.
Flickable {
    id: root
    required property var bar
    readonly property var fs: bar.studyFocus
    readonly property var sc: bar.school
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.green
    contentHeight: col.implicitHeight + 24
    clip: true; boundsBehavior: Flickable.StopAtBounds

    component Card: Rectangle {
        default property alias content: inner.data
        Layout.fillWidth: true; implicitHeight: inner.implicitHeight + 24; radius: 12; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
        ColumnLayout { id: inner; anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
spacing: 8 }
    }
    component Stepper: RowLayout {
        id: st
        property string label: ""
        property int value: 0
        property int from: 1
        property int to: 90
        property int step: 1
        property string unit: "m"
        signal changed(int v)
        spacing: 6
        Text { text: st.label; color: Theme.subtext; Layout.fillWidth: true; font { family: root.font; pixelSize: 11 } }
        Rectangle { Layout.preferredWidth: 22; Layout.preferredHeight: 22; radius: 11; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                    Text { anchors.centerIn: parent; text: "−"; color: Theme.text; font { family: root.font; pixelSize: 13 } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: st.changed(Math.max(st.from, st.value - st.step)) } }
        Text { text: st.value + st.unit; color: Theme.text; Layout.preferredWidth: 38; horizontalAlignment: Text.AlignHCenter; font { family: root.font; pixelSize: 11; bold: true } }
        Rectangle { Layout.preferredWidth: 22; Layout.preferredHeight: 22; radius: 11; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                    Text { anchors.centerIn: parent; text: "+"; color: Theme.text; font { family: root.font; pixelSize: 13 } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: st.changed(Math.min(st.to, st.value + st.step)) } }
    }
    component Toggle: RowLayout {
        id: tg
        property string label: ""
        property string sub: ""
        property bool on: false
        signal flipped
        spacing: 10
        ColumnLayout {
            Layout.fillWidth: true; spacing: 0
            Text { text: tg.label; color: Theme.text; font { family: root.font; pixelSize: 12 } }
            Text { visible: tg.sub.length > 0; text: tg.sub; color: Theme.dim; wrapMode: Text.WordWrap; Layout.fillWidth: true; font { family: root.font; pixelSize: 9 } }
        }
        Rectangle {
            Layout.preferredWidth: 38; Layout.preferredHeight: 22; radius: 11; color: tg.on ? root.accent : Qt.alpha(Theme.mauve, 0.16)
            Behavior on color { ColorAnimation { duration: 120 } }
            Rectangle { y: 3; x: tg.on ? parent.width - width - 3 : 3; width: 16; height: 16; radius: 8; color: tg.on ? Theme.crust : Theme.subtext; Behavior on x { NumberAnimation { duration: 120 } } }
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: tg.flipped() }
        }
    }

    ColumnLayout {
        id: col
        x: 14; width: root.width - 28; y: 8
        spacing: 10

        // ── timer ──
        Card {
            RowLayout {
                Layout.fillWidth: true
                Text { text: root.fs.phase === "idle" ? "Study timer" : root.fs.phase === "focus" ? "Focus" : root.fs.phase === "break" ? "Break" : "Long break"; color: root.fs.phase === "focus" ? root.accent : Theme.sky; font { family: root.font; pixelSize: 12; bold: true } }
                Item { Layout.fillWidth: true }
                Repeater {     // dots for the sessions of this cycle
                    model: root.fs.cfg.every
                    delegate: Rectangle { required property int index; width: 8; height: 8; radius: 4; color: index < root.fs.cycle ? root.accent : Qt.alpha(Theme.mauve, 0.2) }
                }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.fs.clock(root.fs.remaining); color: Theme.text
                font { family: root.font; pixelSize: 44; bold: true }
            }
            RowLayout {
                Layout.alignment: Qt.AlignHCenter; spacing: 10
                Rectangle {
                    Layout.preferredWidth: 110; Layout.preferredHeight: 36; radius: 18; color: root.accent
                    Text { anchors.centerIn: parent; text: root.fs.running ? "󰏤  Pause" : (root.fs.phase === "idle" ? "󰐊  Start" : "󰐊  Resume"); color: Theme.crust; font { family: root.font; pixelSize: 12; bold: true } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.fs.toggle() }
                }
                Rectangle {
                    visible: root.fs.phase !== "idle"
                    Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 18; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                    Text { anchors.centerIn: parent; text: "󰒭"; color: Theme.text; font { family: root.font; pixelSize: 16 } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.fs.skip() }
                }
                Rectangle {
                    visible: root.fs.phase !== "idle"
                    Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 18; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                    Text { anchors.centerIn: parent; text: "󰜺"; color: Theme.text; font { family: root.font; pixelSize: 16 } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.fs.reset() }
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 16
                Stepper { Layout.fillWidth: true; label: "focus"; value: root.fs.cfg.focus; from: 5; to: 90; step: 5; onChanged: v => root.fs.setCfg("focus", v) }
                Stepper { Layout.fillWidth: true; label: "break"; value: root.fs.cfg.brk; from: 1; to: 30; onChanged: v => root.fs.setCfg("brk", v) }
            }
            // the assignment being worked on (set with the ▶ button on the Due list)
            RowLayout {
                visible: root.fs.taskItem !== null
                Layout.fillWidth: true; spacing: 8
                Text { text: "working on"; color: Theme.dim; font { family: root.font; pixelSize: 10 } }
                Text { text: root.fs.taskItem ? root.fs.taskItem.name : ""; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 11; bold: true } }
                Text { text: root.fs.taskItem ? U.minutesText(root.sc.taskLog[String(root.fs.taskItem.id)] || 0) + " so far" : ""; color: Theme.subtext; font { family: root.font; pixelSize: 10 } }
                Text { text: "✕"; color: Theme.dim; font { family: root.font; pixelSize: 11 }
                       MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: root.fs.setTask("") } }
            }
            // what are you studying? (the time is logged against it)
            Text { text: "STUDYING"; color: Theme.dim; font { family: root.font; pixelSize: 9; bold: true; letterSpacing: 1 } }
            Flow {
                Layout.fillWidth: true; spacing: 5
                Repeater {
                    model: [{ code: "", label: "General" }].concat(root.sc.courses.map(c => ({ code: c.code, label: c.code })))
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool sel: root.fs.course === modelData.code
                        height: 24; width: cl.implicitWidth + 16; radius: 12; color: sel ? Qt.alpha(root.accent, 0.22) : Theme.card; border { color: sel ? root.accent : Theme.cardBorder; width: 1 }
                        Text { id: cl; anchors.centerIn: parent; text: modelData.label; color: sel ? Theme.text : Theme.subtext; font { family: root.font; pixelSize: 10 } }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.fs.flushLog(); root.fs.setCourse(modelData.code) } }
                    }
                }
            }
            Toggle { Layout.fillWidth: true; label: "Silence notifications while focusing"; on: root.fs.cfg.autoDnd; onFlipped: { root.fs.setCfg("autoDnd", !root.fs.cfg.autoDnd); root.fs.applyDnd() } }
            // this week
            RowLayout {
                Layout.fillWidth: true; spacing: 12
                ColumnLayout {
                    spacing: 0
                    Text { text: U.minutesText(root.fs.todayMinutes); color: root.accent; font { family: root.font; pixelSize: 16; bold: true } }
                    Text { text: "focused today"; color: Theme.dim; font { family: root.font; pixelSize: 9 } }
                }
                ColumnLayout {
                    spacing: 0
                    Text { text: U.minutesText(root.fs.weekMinutes); color: Theme.text; font { family: root.font; pixelSize: 16; bold: true } }
                    Text { text: "this week"; color: Theme.dim; font { family: root.font; pixelSize: 9 } }
                }
                Item { Layout.fillWidth: true }
                Row {
                    spacing: 5; Layout.alignment: Qt.AlignBottom
                    Repeater {
                        model: root.fs.week
                        delegate: Column {
                            required property var modelData
                            spacing: 2
                            Item { width: 14; height: 34
                                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: Math.max(2, Math.min(34, modelData.min / 180 * 34)); radius: 3; color: modelData.min > 0 ? root.accent : Qt.alpha(Theme.mauve, 0.15) } }
                            Text { text: modelData.day; color: Theme.dim; anchors.horizontalCenter: parent.horizontalCenter; font { family: root.font; pixelSize: 8 } }
                        }
                    }
                }
            }
        }

        // ── this week, by course ──
        Card {
            visible: root.fs.byCourse.length > 0
            Text { text: "󰔟  This week by course"; color: Theme.text; font { family: root.font; pixelSize: 12; bold: true } }
            Repeater {
                model: root.fs.byCourse
                delegate: ColumnLayout {
                    id: cb
                    required property var modelData
                    readonly property real maxMin: root.fs.byCourse.length ? root.fs.byCourse[0].min : 1
                    Layout.fillWidth: true; spacing: 2
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: cb.modelData.course === "" ? "General" : cb.modelData.course; color: Theme.text; font { family: root.font; pixelSize: 11 } }
                        Item { Layout.fillWidth: true }
                        Text { text: U.minutesText(cb.modelData.min); color: Theme.subtext; font { family: root.font; pixelSize: 10 } }
                    }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 5; radius: 2.5; color: Qt.alpha(root.accent, 0.15)
                                Rectangle { width: parent.width * cb.modelData.min / cb.maxMin; height: parent.height; radius: 2.5; color: root.accent } }
                }
            }
        }

        // ── focus mode ──
        Card {
            id: modeCard
            property bool askingPw: false
            RowLayout {
                Layout.fillWidth: true
                Text { text: "󰈈  Focus mode"; color: root.fs.modeOn ? Theme.red : Theme.text; font { family: root.font; pixelSize: 12; bold: true } }
                Item { Layout.fillWidth: true }
                Text { visible: root.fs.modeOn; text: "ends " + U.clock(root.fs.modeUntil) + "  (" + U.rel(root.fs.modeUntil, root.fs.now).replace("in ", "") + ")"; color: Theme.dim; font { family: root.font; pixelSize: 10 } }
            }
            Text {
                visible: !root.fs.modeOn
                Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.dim; font { family: root.font; pixelSize: 10 }
                text: "Silences notifications and keeps " + (root.fs.blocked.length ? root.fs.blocked.slice(0, 4).join(", ") + (root.fs.blocked.length > 4 ? " and more" : "") : "Steam, Discord, Lutris, Prism and Spotify") + " closed until the time is up. Turning it off early needs your login password. Edit the list in ~/.config/qs-bar/focus.json."
            }
            RowLayout {
                visible: !root.fs.modeOn
                Layout.fillWidth: true; spacing: 8
                Repeater {
                    model: [30, 60, 90, 120, 180]
                    delegate: Rectangle {
                        required property int modelData
                        Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.preferredHeight: 32; radius: 10
                        color: da.containsMouse ? Qt.alpha(Theme.red, 0.18) : Theme.card; border { color: da.containsMouse ? Theme.red : Theme.cardBorder; width: 1 }
                        Text { anchors.centerIn: parent; text: U.minutesText(modelData); color: Theme.text; font { family: root.font; pixelSize: 11 } }
                        MouseArea { id: da; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.fs.startMode(modelData) }
                    }
                }
            }
            Text { visible: root.fs.modeOn && !modeCard.askingPw; text: "Notifications are silenced and your distraction apps stay closed."; color: Theme.subtext; Layout.fillWidth: true; wrapMode: Text.WordWrap; font { family: root.font; pixelSize: 10 } }
            Rectangle {
                visible: root.fs.modeOn && !modeCard.askingPw
                Layout.fillWidth: true; Layout.preferredHeight: 32; radius: 10; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                Text { anchors.centerIn: parent; text: "Turn off early…"; color: Theme.text; font { family: root.font; pixelSize: 11 } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { modeCard.askingPw = true; pwIn.forceActiveFocus() } }
            }
            ColumnLayout {
                visible: root.fs.modeOn && modeCard.askingPw
                Layout.fillWidth: true; spacing: 6
                Text { text: "Type your login password to end focus mode:"; color: Theme.subtext; font { family: root.font; pixelSize: 10 } }
                RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 34; radius: 10; color: Qt.alpha(Theme.mauve, 0.07); border { color: pwIn.activeFocus ? Qt.alpha(Theme.red, 0.6) : Theme.sep; width: 1 }
                        TextInput {
                            id: pwIn
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password; color: Theme.text; font { family: root.font; pixelSize: 12 }
                            onAccepted: { root.fs.endWithPassword(text); text = "" }
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 80; Layout.preferredHeight: 34; radius: 10; color: Theme.red; opacity: root.fs.checking ? 0.5 : 1
                        Text { anchors.centerIn: parent; text: root.fs.checking ? "…" : "End it"; color: Theme.crust; font { family: root.font; pixelSize: 11; bold: true } }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.fs.endWithPassword(pwIn.text); pwIn.text = "" } }
                    }
                }
                Text { visible: root.fs.endError.length > 0; text: root.fs.endError; color: Theme.red; font { family: root.font; pixelSize: 10 } }
            }
            Connections { target: root.fs; function onModeOnChanged() { if (!root.fs.modeOn) modeCard.askingPw = false } }
        }

        // ── nudges ──
        Card {
            Text { text: "󰂚  Nudges"; color: Theme.text; font { family: root.font; pixelSize: 12; bold: true } }
            Repeater {
                model: Object.keys(root.fs.nudges)
                delegate: Toggle {
                    required property string modelData
                    Layout.fillWidth: true
                    label: root.fs.nudges[modelData].label; sub: root.fs.nudges[modelData].sub
                    on: !!root.fs.nudgeOn[modelData]; onFlipped: root.fs.setNudge(modelData, !root.fs.nudgeOn[modelData])
                }
            }
        }

        // ── assistants ──
        Card {
            Text { text: "󰂄  Battery and sleep"; color: Theme.text; font { family: root.font; pixelSize: 12; bold: true } }
            Toggle {
                Layout.fillWidth: true; label: "Charge before long classes"; sub: "Warns you when the battery will not last to the end of an event in your calendar"
                on: root.sc.pref("batteryAssist", true); onFlipped: root.sc.setPref("batteryAssist", !root.sc.pref("batteryAssist", true))
            }
            Toggle {
                Layout.fillWidth: true; label: "Bedtime reminder"; sub: root.sc.bedtime ? "Next: bed by " + U.clock(root.sc.bedtime.ms) + " for " + root.sc.bedtime.title + " at " + U.clock(root.sc.bedtime.startMs) : "Needs your calendar (Calendar app → add your link)"
                on: root.sc.pref("bedtimeAssist", true); onFlipped: root.sc.setPref("bedtimeAssist", !root.sc.pref("bedtimeAssist", true))
            }
            Stepper { Layout.fillWidth: true; label: "study hours I can fit in a day"; value: root.sc.dailyHours; from: 1; to: 12; unit: "h"; onChanged: v => root.sc.setPref("dailyHours", v) }
            Stepper { Layout.fillWidth: true; label: "sleep I want"; value: root.sc.pref("sleepHours", 8); from: 5; to: 11; unit: "h"; onChanged: v => root.sc.setPref("sleepHours", v) }
            Stepper { Layout.fillWidth: true; label: "time to get ready"; value: root.sc.pref("prepMinutes", 75); from: 15; to: 180; step: 15; onChanged: v => root.sc.setPref("prepMinutes", v) }
        }
    }
}
