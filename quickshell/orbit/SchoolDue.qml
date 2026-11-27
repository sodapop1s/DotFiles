import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "schoolutil.js" as U

// Study > Due: what is due (from Canvas), today's classes, and the connect-to-Canvas form.
Item {
    id: root
    required property var bar
    signal closeRequested()
    readonly property var sc: bar.school
    function activate() {}

    Process { id: openProc; onExited: running = false }
    function openUrl(u) {
        if (!/^https?:\/\//.test(u)) return
        openProc.command = ["xdg-open", u]; openProc.running = true
        closeRequested()
    }

    // flat list: section headings and rows
    readonly property var rows: {
        var out = [], now = sc.nowMs
        if (sc.overdue.length) {
            out.push({ t: "head", text: "Missing or overdue", tone: Theme.crit })
            sc.overdue.slice().sort((a, b) => b.due - a.due).forEach(a => out.push({ t: "item", a: a, late: true }))
        }
        var last = ""
        sc.upcoming.forEach(a => {
            var b = U.bucket(a.due * 1000, now)
            if (b !== last) { out.push({ t: "head", text: b, tone: Theme.muted }); last = b }
            out.push({ t: "item", a: a, late: false })
        })
        if (sc.announce.length) {
            out.push({ t: "head", text: "Announcements", tone: Theme.muted })
            sc.announce.slice(0, 4).forEach(n => out.push({ t: "ann", n: n }))
        }
        return out
    }

    // ── not connected yet ──
    Flickable {
        id: setup
        visible: root.sc.checked && !root.sc.configured
        anchors { fill: parent; margins: 6 }
        contentHeight: setupCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: setupCol
            width: setup.width
            spacing: 12
            Text { text: "Connect Canvas"; color: Theme.text; Layout.topMargin: 8; font { family: Theme.fontUi; pixelSize: 18; weight: Font.DemiBold } }
            Text {
                Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.muted; font { family: Theme.fontUi; pixelSize: Theme.sizeUi }
                text: "Due dates, missing work and grades come from Canvas. This is read-only: nothing is submitted or changed."
            }
            Card {
                Text {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 }
                    text: "1. In Canvas, open Account, then Settings.\n2. Under Approved Integrations, choose New Access Token, name it, and copy the token.\n3. Enter your school's Canvas address and the token below."
                }
            }
            Field { id: domainIn; Layout.fillWidth: true; placeholder: "School address, e.g. gatech.instructure.com"; input.KeyNavigation.tab: tokenIn.input }
            Field { id: tokenIn; Layout.fillWidth: true; password: true; placeholder: "Access token (hidden)"; onAccepted: connectBtn.go() }
            Text { visible: root.sc.setupError.length > 0; Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.sc.setupError; color: Theme.crit; font { family: Theme.fontUi; pixelSize: 12 } }
            Chip {
                id: connectBtn
                filled: true
                text: root.sc.connecting ? "Checking…" : "Connect"
                function go() { if (domainIn.text.trim() && tokenIn.text.trim()) { root.sc.connect(domainIn.text, tokenIn.text.trim()); tokenIn.text = "" } }
                onClicked: go()
            }
        }
    }

    // ── connected ──
    ColumnLayout {
        visible: root.sc.configured
        anchors { fill: parent; topMargin: 6 }
        spacing: 8

        Card {
            visible: root.sc.calendarOn && root.sc.todayEvents.length > 0
            spacing: 4
            RowLayout {
                Layout.fillWidth: true
                Text { text: "Today"; color: Theme.text; font { family: Theme.fontUi; pixelSize: Theme.sizeUi; weight: Font.DemiBold } }
                Item { Layout.fillWidth: true }
                Text {
                    readonly property var ne: root.sc.nextEvent
                    visible: ne !== null
                    text: ne ? (ne.startMs > root.sc.nowMs ? "Next " + U.rel(ne.startMs, root.sc.nowMs) : "Now, ends " + U.rel(ne.endMs, root.sc.nowMs)) : ""
                    color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 }
                }
            }
            Repeater {
                model: root.sc.todayEvents.slice(0, 3)
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true; spacing: 10
                    Text { text: U.clock(modelData.startMs); color: Theme.muted; Layout.preferredWidth: 70; font { family: Theme.fontUi; pixelSize: 12 } }
                    Text { text: modelData.title; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
                    Text { visible: modelData.location.length > 0; text: modelData.location; color: Theme.muted; elide: Text.ElideRight; Layout.maximumWidth: 160; textFormat: Text.PlainText; font { family: Theme.fontUi; pixelSize: 12 } }
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            model: root.rows

            delegate: Loader {
                id: ld
                required property var modelData
                width: list.width
                sourceComponent: modelData.t === "head" ? headC : (modelData.t === "ann" ? annC : itemC)

                Component {
                    id: headC
                    Heading { width: list.width; text: ld.modelData.text; color: ld.modelData.tone }
                }
                Component {
                    id: annC
                    Rectangle {
                        width: list.width; height: 48; radius: 10; color: "transparent"; border { width: 1; color: Theme.hairline }
                        Column {
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 12 }
                            Text { width: parent.width; text: ld.modelData.n.title; color: Theme.text; elide: Text.ElideRight; textFormat: Text.PlainText; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
                            Text { text: ld.modelData.n.course + "  ·  " + U.rel(ld.modelData.n.posted * 1000, root.sc.nowMs); color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 } }
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.openUrl(ld.modelData.n.url) }
                    }
                }
                Component {
                    id: itemC
                    Rectangle {
                        id: ir
                        readonly property var a: ld.modelData.a
                        readonly property bool late: ld.modelData.late
                        readonly property real hoursLeft: (a.due * 1000 - root.sc.nowMs) / 3600000
                        readonly property color urgency: late || hoursLeft < 24 ? Theme.crit : hoursLeft < 72 ? Theme.warn : Theme.muted
                        readonly property bool timing: root.bar.studyFocus.task === String(a.id) && root.bar.studyFocus.running
                        width: list.width; height: 58; radius: 10
                        color: hover.hovered ? Theme.raised : "transparent"
                        border { width: 1; color: late ? Theme.crit : Theme.hairline }
                        HoverHandler { id: hover }
                        MouseArea { anchors.fill: parent; onClicked: root.openUrl(ir.a.url) }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            spacing: 12
                            Rectangle {      // tick it off yourself (paper hand-ins, anything Canvas cannot see)
                                Layout.preferredWidth: 20; Layout.preferredHeight: 20; radius: 10; color: "transparent"
                                border { width: 1.5; color: Theme.muted }
                                MouseArea { anchors.fill: parent; anchors.margins: -5; onClicked: root.sc.toggleDone(ir.a) }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 1
                                Text { text: ir.a.name; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
                                Text {
                                    text: ir.a.course + "  ·  " + U.dueLabel(ir.a.due * 1000, root.sc.nowMs) + (ir.a.points ? "  ·  " + ir.a.points + " pts" : "")
                                          + "  ·  " + (root.sc.learned(ir.a) ? "" : "about ") + U.minutesText(root.sc.remainingMin(ir.a))
                                    color: Theme.muted; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: Theme.fontUi; pixelSize: 12 }
                                }
                            }
                            Row {      // progress: tap to move on (not started, started, well along, nearly done)
                                spacing: 4; Layout.alignment: Qt.AlignVCenter
                                Repeater {
                                    model: 3
                                    delegate: Rectangle {
                                        required property int index
                                        width: 8; height: 8; radius: 4
                                        color: index < root.sc.progressOf(ir.a) ? Theme.text : "transparent"
                                        border { width: 1; color: Theme.muted }
                                    }
                                }
                                TapHandler { onTapped: root.sc.cycleProgress(ir.a) }
                            }
                            Chip {
                                text: ir.timing ? "Pause" : "Start timer"
                                selected: ir.timing
                                onClicked: { if (ir.timing) root.bar.studyFocus.pause(); else root.bar.studyFocus.startTask(ir.a) }
                            }
                            Text {
                                Layout.preferredWidth: 64; horizontalAlignment: Text.AlignRight
                                text: ir.late ? (ir.a.missing ? "Missing" : "Overdue") : U.rel(ir.a.due * 1000, root.sc.nowMs).replace("in ", "")
                                color: ir.urgency; font { family: Theme.fontUi; pixelSize: Theme.sizeUi }
                            }
                        }
                    }
                }
            }

            Text {
                visible: root.rows.length === 0
                anchors.centerIn: parent; horizontalAlignment: Text.AlignHCenter; color: Theme.muted; font { family: Theme.fontUi; pixelSize: Theme.sizeUi }
                text: root.sc.syncing ? "Loading from Canvas…" : (root.sc.canvasError.length ? root.sc.canvasError : "Nothing due in the next 30 days.")
            }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: 14
            Text {
                readonly property int mins: root.sc.workMinutes(3)
                visible: mins > 0
                text: "Next 3 days: about " + U.minutesText(mins)
                color: mins > root.sc.dailyHours * 3 * 60 ? Theme.crit : mins > root.sc.dailyHours * 3 * 60 * 0.75 ? Theme.warn : Theme.muted
                font { family: Theme.fontUi; pixelSize: 12 }
            }
            Text { text: root.sc.syncing ? "Syncing…" : (root.sc.lastSync ? "Synced " + U.rel(root.sc.lastSync, root.sc.nowMs).replace("in ", "") : ""); color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 } }
            Text {
                visible: root.sc.inbox > 0
                text: root.sc.inbox + " unread in Canvas"; color: Theme.warn; font { family: Theme.fontUi; pixelSize: 12 }
                MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: root.openUrl(root.sc.domain + "/conversations") }
            }
            Item { Layout.fillWidth: true }
            Text { visible: root.sc.bedtime !== null; text: root.sc.bedtime ? "Bed by " + U.clock(root.sc.bedtime.ms) : ""; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 } }
            Text {
                text: "Refresh"; color: Theme.text; font { family: Theme.fontUi; pixelSize: 12 }
                MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: { root.sc.refresh(); root.sc.refreshEvents() } }
            }
            Text {
                text: "Disconnect"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 }
                MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: root.sc.disconnect() }
            }
        }
    }
}
