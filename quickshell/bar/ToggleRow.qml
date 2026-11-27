import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: tr
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool   on: false
    property bool   hasPanel: false
    property color  accent: Theme.mauve
    signal toggled
    signal opened

    implicitHeight: 52

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { if (tr.hasPanel) tr.opened(); else tr.toggled() }
        Rectangle { anchors.fill: parent; radius: 12; color: Qt.alpha(Theme.mauve, 0.07); visible: parent.containsMouse }
    }

    RowLayout {
        anchors { fill: parent; leftMargin: 14; rightMargin: 12 }
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 10
            color: tr.on ? Qt.rgba(tr.accent.r, tr.accent.g, tr.accent.b, 0.20) : Qt.alpha(Theme.mauve, 0.08)
            Behavior on color { ColorAnimation { duration: 120 } }
            Text { anchors.centerIn: parent; text: tr.icon; color: tr.on ? tr.accent : Theme.dim
                   font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 } }
        }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 0
            Text { text: tr.title; color: Theme.text; Layout.fillWidth: true; elide: Text.ElideRight
                   font { family: "JetBrainsMono Nerd Font"; pixelSize: 12; bold: true } }
            Text { text: tr.subtitle; color: tr.on ? Qt.lighter(tr.accent, 1.1) : Theme.dim; Layout.fillWidth: true; elide: Text.ElideRight
                   textFormat: Text.PlainText
                   font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 } }
        }
        Text {
            visible: tr.hasPanel
            text: "󰅂"; color: Theme.dim
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
        }
        // the switch
        Rectangle {
            Layout.preferredWidth: 38; Layout.preferredHeight: 22; radius: 11
            color: tr.on ? tr.accent : Qt.alpha(Theme.mauve, 0.16)
            Behavior on color { ColorAnimation { duration: 120 } }
            Rectangle {
                y: 3; x: tr.on ? parent.width - width - 3 : 3
                width: 16; height: 16; radius: 8
                color: tr.on ? Theme.crust : Theme.subtext
                Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            }
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: tr.toggled() }
        }
    }
}
