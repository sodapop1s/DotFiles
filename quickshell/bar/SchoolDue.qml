import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "schoolutil.js" as U

// School > Due: what is due (from Canvas), today's classes, and the connect-to-Canvas form.
Item {
    id: root
    required property var bar
    readonly property var sc: bar.school
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.blue
    readonly property var palette: [Theme.mauve, Theme.sky, Theme.green, Theme.peach, Theme.pink, Theme.yellow, Theme.teal]
    function courseColor(id) { var i = sc.courses.findIndex(c => c.id === id); return palette[(i < 0 ? 0 : i) % palette.length] }
    Process { id: openProc; onExited: running = false }
    function openUrl(u) { if (!/^https?:\/\//.test(u)) return; openProc.command = ["xdg-open", u]; openProc.running = true; root.bar.hubOpen = false }

    // flat list: section headers and rows
    readonly property var rows: {
        var out = [], now = sc.nowMs
        if (sc.overdue.length) {
            out.push({ t: "head", text: "Missing / overdue", color: Theme.red })
            sc.overdue.slice().sort((a, b) => b.due - a.due).forEach(a => out.push({ t: "item", a: a, late: true }))
        }
        var last = ""
        sc.upcoming.forEach(a => {
            var b = U.bucket(a.due * 1000, now)
            if (b !== last) { out.push({ t: "head", text: b, color: b === "Today" ? Theme.yellow : Theme.dim }); last = b }
            out.push({ t: "item", a: a, late: false })
        })
        if (sc.announce.length) {
            out.push({ t: "head", text: "Announcements", color: Theme.dim })
            sc.announce.slice(0, 4).forEach(n => out.push({ t: "ann", n: n }))
        }
        return out
    }

    // ── not connected yet ─────────────────────────────────
    Flickable {
        id: setup
        visible: root.sc.checked && !root.sc.configured
        anchors { fill: parent; margins: 14 }
        contentHeight: setupCol.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: setupCol
            width: setup.width; spacing: 10
            Rectangle {
                Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 10; Layout.preferredWidth: 56; Layout.preferredHeight: 56; radius: 18; color: Qt.alpha(root.accent, 0.16)
                Text { anchors.centerIn: parent; text: "󰑴"; color: root.accent; font { family: root.font; pixelSize: 28 } }
            }
            Text { Layout.alignment: Qt.AlignHCenter; text: "Connect Canvas"; color: Theme.text; font { family: root.font; pixelSize: 15; bold: true } }
            Text {
                Layout.fillWidth: true; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; color: Theme.dim; font { family: root.font; pixelSize: 11 }
                text: "Due dates, missing work and grades come straight from Canvas. This is read-only: nothing is ever submitted or changed."
            }
            Rectangle {
                Layout.fillWidth: true; implicitHeight: how.implicitHeight + 20; radius: 12; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                Text {
                    id: how
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                    wrapMode: Text.WordWrap; color: Theme.subtext; font { family: root.font; pixelSize: 10 }
                    text: "1. In Canvas, open Account → Settings.\n2. Under “Approved Integrations” click “+ New Access Token”, name it “bar”, and copy the token.\n3. Type your school's Canvas address below (like  yourschool.instructure.com) and paste the token.\n\nThe token is saved in ~/.config/qs-bar/ readable by you only, and is only ever sent to that address. If your school hides the token button, ask for the calendar-feed route instead."
                }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 36; radius: 10; color: Qt.alpha(Theme.mauve, 0.07)
                border { color: domainIn.activeFocus ? Qt.alpha(root.accent, 0.5) : Theme.sep; width: 1 }
                TextInput {
                    id: domainIn
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text; clip: true; font { family: root.font; pixelSize: 12 }
                    KeyNavigation.tab: tokenIn
                    Text { visible: domainIn.text.length === 0; anchors.verticalCenter: parent.verticalCenter; text: "school address, e.g. gatech.instructure.com"; color: Theme.dim; font { family: root.font; pixelSize: 11 } }
                }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 36; radius: 10; color: Qt.alpha(Theme.mauve, 0.07)
                border { color: tokenIn.activeFocus ? Qt.alpha(root.accent, 0.5) : Theme.sep; width: 1 }
                TextInput {
                    id: tokenIn
                    anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text; clip: true; echoMode: TextInput.Password; font { family: root.font; pixelSize: 12 }
                    onAccepted: connectBtn.go()
                    Text { visible: tokenIn.text.length === 0; anchors.verticalCenter: parent.verticalCenter; text: "access token (hidden as you paste)"; color: Theme.dim; font { family: root.font; pixelSize: 11 } }
                }
            }
            Text { visible: root.sc.setupError.length > 0; Layout.fillWidth: true; wrapMode: Text.WordWrap; text: root.sc.setupError; color: Theme.red; font { family: root.font; pixelSize: 11 } }
            Rectangle {
                id: connectBtn
                function go() { if (domainIn.text.trim() && tokenIn.text.trim()) { root.sc.connect(domainIn.text, tokenIn.text.trim()); tokenIn.text = "" } }
                Layout.fillWidth: true; Layout.preferredHeight: 38; radius: 12; color: root.accent; opacity: root.sc.connecting ? 0.6 : 1
                Text { anchors.centerIn: parent; text: root.sc.connecting ? "checking…" : "Connect"; color: Theme.crust; font { family: root.font; pixelSize: 12; bold: true } }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: connectBtn.go() }
            }
        }
    }

    // ── connected ─────────────────────────────────────────
    ColumnLayout {
        visible: root.sc.configured
        anchors { fill: parent; leftMargin: 14; rightMargin: 14; topMargin: 6; bottomMargin: 10 }
        spacing: 8

        // today's classes
        Rectangle {
            visible: root.sc.calendarOn && root.sc.todayEvents.length > 0
            Layout.fillWidth: true; implicitHeight: todayCol.implicitHeight + 18; radius: 12
            color: Qt.alpha(root.accent, 0.08); border { color: Qt.alpha(root.accent, 0.3); width: 1 }
            ColumnLayout {
                id: todayCol
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                spacing: 3
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Today"; color: root.accent; font { family: root.font; pixelSize: 11; bold: true } }
                    Item { Layout.fillWidth: true }
                    Text {
                        readonly property var ne: root.sc.nextEvent
                        visible: ne !== null
                        text: ne ? (ne.startMs > root.sc.nowMs ? "next " + U.rel(ne.startMs, root.sc.nowMs) : "now · ends " + U.rel(ne.endMs, root.sc.nowMs)) : ""
                        color: Theme.dim; font { family: root.font; pixelSize: 10 }
                    }
                }
                Repeater {
                    model: root.sc.todayEvents.slice(0, 3)
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true; spacing: 8
                        Text { text: U.clock(modelData.startMs); color: Theme.subtext; Layout.preferredWidth: 62; font { family: root.font; pixelSize: 10 } }
                        Text { text: modelData.title; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 11 } }
                        Text { visible: modelData.location.length > 0; text: modelData.location; color: Theme.dim; elide: Text.ElideRight; Layout.maximumWidth: 120; textFormat: Text.PlainText; font { family: root.font; pixelSize: 9 } }
                    }
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; spacing: 4; boundsBehavior: Flickable.StopAtBounds
            model: root.rows

            delegate: Loader {
                id: ld
                required property var modelData
                width: list.width
                sourceComponent: modelData.t === "head" ? headC : (modelData.t === "ann" ? annC : itemC)
                Component {
                    id: headC
                    Text { width: list.width; topPadding: 6; text: ld.modelData.text.toUpperCase(); color: ld.modelData.color; font { family: root.font; pixelSize: 9; bold: true; letterSpacing: 1 } }
                }
                Component {
                    id: annC
                    Rectangle {
                        width: list.width; height: 42; radius: 10; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                        ColumnLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
spacing: 0
                            Item { Layout.fillHeight: true }
                            Text { text: ld.modelData.n.title; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 11 } }
                            Text { text: ld.modelData.n.course + "  ·  " + U.rel(ld.modelData.n.posted * 1000, root.sc.nowMs); color: Theme.dim; font { family: root.font; pixelSize: 9 } }
                            Item { Layout.fillHeight: true }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openUrl(ld.modelData.n.url) }
                    }
                }
                Component {
                    id: itemC
                    Rectangle {
                        id: ir
                        readonly property var a: ld.modelData.a
                        readonly property real hoursLeft: (a.due * 1000 - root.sc.nowMs) / 3600000
                        readonly property color urgency: ld.modelData.late ? Theme.red : hoursLeft < 24 ? Theme.red : hoursLeft < 72 ? Theme.yellow : Theme.dim
                        width: list.width; height: 52; radius: 10
                        color: ih.hovered ? Qt.alpha(root.accent, 0.08) : Theme.card
                        border { color: ld.modelData.late ? Qt.alpha(Theme.red, 0.45) : Theme.cardBorder; width: 1 }
                        HoverHandler { id: ih }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openUrl(ir.a.url) }
                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 12 }
                            spacing: 10
                            Rectangle {      // tick it off yourself (paper hand-ins, anything Canvas cannot see)
                                Layout.preferredWidth: 20; Layout.preferredHeight: 20; radius: 10; color: "transparent"
                                border { color: root.courseColor(ir.a.courseId); width: 2 }
                                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.sc.toggleDone(ir.a) }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 1
                                Text { text: ir.a.name; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 12; bold: true } }
                                Text {
                                    text: ir.a.course + "  ·  " + U.dueLabel(ir.a.due * 1000, root.sc.nowMs) + (ir.a.points ? "  ·  " + ir.a.points + " pts" : "") + "  ·  " + (root.sc.learned(ir.a) ? "" : "~") + U.minutesText(root.sc.remainingMin(ir.a))
                                    color: root.courseColor(ir.a.courseId); elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 10 }
                                }
                            }
                            RowLayout {      // how far along you are: tap to move it on (not started → started → well along → nearly done)
                                spacing: 3; Layout.alignment: Qt.AlignVCenter
                                Repeater {
                                    model: 3
                                    delegate: Rectangle {
                                        required property int index
                                        Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4
                                        color: index < root.sc.progressOf(ir.a) ? root.courseColor(ir.a.courseId) : "transparent"
                                        border { color: root.courseColor(ir.a.courseId); width: 1 }
                                    }
                                }
                                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: root.sc.cycleProgress(ir.a) }
                            }
                            Rectangle {    // start the study timer on this one
                                Layout.preferredWidth: 22; Layout.preferredHeight: 22; radius: 11
                                color: pa.containsMouse ? root.courseColor(ir.a.courseId) : Qt.alpha(root.courseColor(ir.a.courseId), 0.18)
                                readonly property bool active: root.bar.studyFocus.task === String(ir.a.id) && root.bar.studyFocus.running
                                Text { anchors.centerIn: parent; text: parent.active ? "󰏤" : "󰐊"; color: pa.containsMouse ? Theme.crust : root.courseColor(ir.a.courseId); font { family: root.font; pixelSize: 11 } }
                                MouseArea { id: pa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: { if (parent.active) root.bar.studyFocus.pause(); else root.bar.studyFocus.startTask(ir.a) } }
                            }
                            Text { text: ld.modelData.late ? (ir.a.missing ? "missing" : "overdue") : U.rel(ir.a.due * 1000, root.sc.nowMs).replace("in ", ""); color: ir.urgency; font { family: root.font; pixelSize: 11; bold: true } }
                        }
                    }
                }
            }

            Text {
                visible: root.rows.length === 0
                anchors.centerIn: parent; horizontalAlignment: Text.AlignHCenter; color: Theme.dim; font { family: root.font; pixelSize: 12 }
                text: root.sc.syncing ? "loading from Canvas…" : (root.sc.canvasError.length ? root.sc.canvasError : "Nothing due in the next 30 days 🎉")
            }
        }

        // footer: sync state, unread mail, bedtime
        RowLayout {
            Layout.fillWidth: true; spacing: 10
            Text {
                readonly property int mins: root.sc.workMinutes(3)
                visible: root.sc.configured && mins > 0
                text: "next 3 days ≈ " + U.minutesText(mins)
                color: mins > root.sc.dailyHours * 3 * 60 ? Theme.red : mins > root.sc.dailyHours * 3 * 60 * 0.75 ? Theme.yellow : Theme.subtext
                font { family: root.font; pixelSize: 10 }
            }
            Text { text: root.sc.syncing ? "syncing…" : (root.sc.lastSync ? "synced " + U.rel(root.sc.lastSync, root.sc.nowMs).replace("in ", "") : ""); color: Theme.dim; font { family: root.font; pixelSize: 9 } }
            Text {
                visible: root.sc.inbox > 0
                text: "󰇮 " + root.sc.inbox + " unread"; color: Theme.yellow; font { family: root.font; pixelSize: 10 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openUrl(root.sc.domain + "/conversations") }
            }
            Item { Layout.fillWidth: true }
            Text {
                visible: root.sc.bedtime !== null
                text: root.sc.bedtime ? "󰒲 bed by " + U.clock(root.sc.bedtime.ms) : ""
                color: Theme.subtext; font { family: root.font; pixelSize: 10 }
            }
            Text {
                text: "refresh"; color: root.accent; font { family: root.font; pixelSize: 10 }
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: { root.sc.refresh(); root.sc.refreshEvents() } }
            }
            Text {
                text: "disconnect"; color: Theme.dim; font { family: root.font; pixelSize: 10 }
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.sc.disconnect() }
            }
        }
    }
}
