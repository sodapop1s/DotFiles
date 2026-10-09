import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    required property var bar

    AppHeader {
        id: nhNav
        bar: parent.bar; icon: "󰂚"; title: "Notifications"; accent: Theme.mauve
        subtitle: (bar.store?.history?.length ?? 0) + " in history"
        anchors { top: parent.top; left: parent.left; right: parent.right }
        onBack: bar.hubView = "main"
        HeaderButton {
            text: bar.dndOn ? "󰂛  DND on" : "󰂚  DND off"; accent: Theme.peach; active: bar.dndOn
            onClicked: bar.dndOn = !bar.dndOn
        }
        HeaderButton {
            visible: (bar.store?.history?.length ?? 0) > 0
            text: "clear all"; accent: Theme.red
            onClicked: bar.store.clearHistory()
        }
    }

    ListView {
        id: nhList
        anchors { top: nhNav.bottom; topMargin: 8; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 12 }
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
            radius: 12
            color: nhHover.containsMouse ? Qt.alpha(Theme.mauve, 0.10) : Theme.card
            border { color: nh.critical ? Qt.alpha(Theme.red, 0.4) : Theme.cardBorder; width: 1 }

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

        EmptyState {
            visible: nhList.count === 0
            anchors.centerIn: parent
            icon: "󰂜"; accent: Theme.mauve; title: "All caught up"; hint: "New notifications will collect here."
        }
    }
}
