import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    required property var bar

    RowLayout {
        id: nhNav
        anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 }
        height: 40; spacing: 8
        Text {
            text: "󰁍"
            color: Theme.dim; font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: bar.hubView = "main" }
        }
        Text { text: "Notifications"; color: Theme.sky; font { family: "JetBrainsMono Nerd Font"; pixelSize: 14; bold: true } }
        Text {
            text: (bar.store?.history?.length ?? 0) + ""
            color: Theme.dim; font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
        }
        Item { Layout.fillWidth: true }
        Text {
            text: bar.dndOn ? "󰂛 DND on" : "󰂚 DND off"
            color: bar.dndOn ? Theme.peach : Theme.dim; font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: bar.dndOn = !bar.dndOn }
        }
        Text {
            visible: (bar.store?.history?.length ?? 0) > 0
            text: "clear all"
            color: Theme.dim; font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: bar.store.clearHistory() }
        }
    }

    Rectangle { id: nhSep; anchors { top: nhNav.bottom; left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 } height: 1; color: Theme.sep }

    ListView {
        id: nhList
        anchors { top: nhSep.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 12; rightMargin: 12; bottomMargin: 10 }
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        model: bar.store?.history ?? []

        delegate: Rectangle {
            id: nh
            required property var modelData
            required property int index
            readonly property bool critical: modelData.urgency === 2
            width: nhList.width
            implicitHeight: nhCol.implicitHeight + 14
            height: implicitHeight
            radius: 8
            color: nhHover.containsMouse ? Qt.alpha(Theme.mauve, 0.10) : Qt.alpha(Theme.mauve, 0.05)

            Rectangle {
                width: 3; radius: 1.5
                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 7; bottomMargin: 7; leftMargin: 4 }
                color: nh.critical ? Theme.red : (nh.modelData.urgency === 0 ? Theme.dim : Theme.mauve)
            }

            ColumnLayout {
                id: nhCol
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 16; rightMargin: 10 }
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true; spacing: 6
                    Text {
                        text: nh.modelData.appName || "Notification"
                        color: nh.critical ? Theme.red : Theme.mauve
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 9; bold: true; capitalization: Font.AllUppercase; letterSpacing: 0.8 }
                        elide: Text.ElideRight; Layout.fillWidth: true
                        textFormat: Text.PlainText
                    }
                    Text {
                        visible: nh.modelData.suppressed
                        text: "󰂛 muted"; color: Theme.peach
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 9 }
                    }
                    Text {
                        text: bar.ago(nh.modelData.time, bar.nowTick); color: Theme.dim
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
                    }
                    Text {
                        text: "✕"
                        color: delArea.containsMouse ? Theme.text : Theme.dim
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
                        MouseArea {
                            id: delArea
                            anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: bar.store.removeHistory(nh.index)
                        }
                    }
                }
                Text {
                    visible: text.length > 0
                    text: nh.modelData.summary
                    color: Theme.text
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 12; bold: true }
                    Layout.fillWidth: true; elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
                Text {
                    visible: text.length > 0
                    text: nh.modelData.body
                    color: Theme.dim
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
            }

            MouseArea { id: nhHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
        }

        Text {
            visible: nhList.count === 0
            anchors.centerIn: parent
            text: "No notifications"; color: Theme.dim
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
        }
    }
}
