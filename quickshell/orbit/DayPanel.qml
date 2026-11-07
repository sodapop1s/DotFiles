import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import "schoolutil.js" as U

// Right panel: what the day looks like. Classes and deadlines come from the existing calendar
// and Canvas helpers (SchoolData); media comes from whatever player is running.
ColumnLayout {
    id: root
    anchors.fill: parent
    spacing: 16

    required property var school
    readonly property var players: Mpris.players.values
    readonly property var player: players.find(p => p.isPlaying) || players[0] || null

    component Label: Text { color: Theme.muted; font { family: Theme.fontUi; pixelSize: 11; capitalization: Font.AllUppercase; letterSpacing: 1 } }
    component Rule: Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.hairline }
    component Body: Text { color: Theme.text; elide: Text.ElideRight; textFormat: Text.PlainText; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
    component Note: Text { color: Theme.muted; wrapMode: Text.WordWrap; Layout.fillWidth: true; font { family: Theme.fontUi; pixelSize: 12 } }
    component Button: Rectangle {
        id: btn
        property string text
        signal clicked()
        implicitWidth: label.implicitWidth + 24; implicitHeight: 30
        radius: 8; color: area.containsMouse ? Theme.raised : "transparent"
        border { width: 1; color: Theme.hairline }
        Text { id: label; anchors.centerIn: parent; text: btn.text; color: Theme.text; font { family: Theme.fontUi; pixelSize: 12 } }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: btn.clicked() }
    }

    Label { text: "Classes" }
    Repeater {
        model: root.school.todayEvents.slice(0, 5)
        delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true; spacing: 10
            Text { text: U.clock(modelData.startMs); color: Theme.muted; Layout.preferredWidth: 64; font { family: Theme.fontUi; pixelSize: 12 } }
            Body { text: modelData.title; Layout.fillWidth: true }
        }
    }
    Note {
        visible: root.school.todayEvents.length === 0
        text: root.school.calendarOn ? "No more classes today." : "Calendar not connected."
    }
    Rule {}

    Label { text: "Due soon" }
    Repeater {
        model: root.school.upcoming.slice(0, 5)
        delegate: ColumnLayout {
            required property var modelData
            Layout.fillWidth: true; spacing: 1
            Body { text: modelData.name; Layout.fillWidth: true }
            Text {
                text: U.shortCourse(modelData.course) + "  ·  " + U.dueLabel(modelData.due * 1000, root.school.nowMs)
                color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 }
            }
        }
    }
    Text {
        visible: root.school.overdue.length > 0
        text: root.school.overdue.length + " past due"
        color: Theme.crit; font { family: Theme.fontUi; pixelSize: 12 }
    }
    Note {
        visible: root.school.upcoming.length === 0 && root.school.overdue.length === 0
        text: root.school.configured ? "Nothing due." : "Canvas not connected."
    }
    Rule {}

    Label { text: "Now playing" }
    ColumnLayout {
        visible: root.player !== null
        Layout.fillWidth: true; spacing: 10
        ColumnLayout {
            Layout.fillWidth: true; spacing: 1
            Body { text: root.player ? root.player.trackTitle : ""; Layout.fillWidth: true }
            Text { text: root.player ? root.player.trackArtist : ""; color: Theme.muted; elide: Text.ElideRight; Layout.fillWidth: true; font { family: Theme.fontUi; pixelSize: 12 } }
        }
        RowLayout {
            spacing: 8
            Button { text: "Previous"; onClicked: if (root.player) root.player.previous() }
            Button { text: root.player && root.player.isPlaying ? "Pause" : "Play"; onClicked: if (root.player) root.player.togglePlaying() }
            Button { text: "Next"; onClicked: if (root.player) root.player.next() }
        }
    }
    Note { visible: root.player === null; text: "Nothing playing." }

    Item { Layout.fillHeight: true }
}
