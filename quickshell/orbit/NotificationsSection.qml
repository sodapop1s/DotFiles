import QtQuick
import QtQuick.Layouts

// Recent notifications, newest first, with Do Not Disturb and Clear. `store` is the Notifications window,
// `host` is the shell root that owns dndOn.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 8

    required property var store
    required property var host
    property int tick: 0
    Timer { interval: 30000; repeat: true; running: true; onTriggered: root.tick++ }

    function ago(t, _tick) {
        var s = Math.max(0, Math.round((Date.now() - t) / 1000))
        if (s < 45) return "now"
        if (s < 3600) return Math.max(1, Math.round(s / 60)) + " min"
        if (s < 86400) return Math.round(s / 3600) + " h"
        return Math.round(s / 86400) + " d"
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Rectangle {
            implicitWidth: dndLabel.implicitWidth + 20; implicitHeight: 28; radius: 8
            color: root.host.dndOn ? Theme.raised : "transparent"
            border { width: 1; color: root.host.dndOn ? Theme.warn : Theme.hairline }
            Text { id: dndLabel; anchors.centerIn: parent; text: root.host.dndOn ? "Do not disturb: on" : "Do not disturb: off"; color: Theme.text; font { family: Theme.fontUi; pixelSize: 12 } }
            MouseArea { anchors.fill: parent; onClicked: root.host.dndOn = !root.host.dndOn }
        }
        Item { Layout.fillWidth: true }
        Text {
            visible: root.store.history.length > 0
            text: "Clear"
            color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 }
            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: root.store.clearHistory() }
        }
    }

    Repeater {
        model: root.store.history.slice(0, 6)
        delegate: ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 1
            RowLayout {
                Layout.fillWidth: true
                Text { text: modelData.appName || "Notification"; color: modelData.urgency === 2 ? Theme.crit : Theme.muted; Layout.fillWidth: true; elide: Text.ElideRight; textFormat: Text.PlainText; font { family: Theme.fontUi; pixelSize: 11 } }
                Text { text: root.ago(modelData.time, root.tick); color: Theme.muted; font { family: Theme.fontUi; pixelSize: 11 } }
            }
            Text { visible: text.length > 0; text: modelData.summary; color: Theme.text; Layout.fillWidth: true; elide: Text.ElideRight; textFormat: Text.PlainText; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
            Text { visible: text.length > 0; text: modelData.body; color: Theme.muted; Layout.fillWidth: true; elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.WordWrap; textFormat: Text.PlainText; font { family: Theme.fontUi; pixelSize: 12 } }
        }
    }
    Text {
        visible: root.store.history.length === 0
        text: "No notifications."
        color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 }
    }
}
