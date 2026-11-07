import QtQuick
import QtQuick.Layouts

// A label with an optional explanation and an on/off switch. The owner flips the state.
RowLayout {
    id: tg
    property string label: ""
    property string sub: ""
    property bool on: false
    signal flipped()

    Layout.fillWidth: true
    spacing: 12
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 1
        Text { text: tg.label; color: Theme.text; Layout.fillWidth: true; wrapMode: Text.WordWrap; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
        Text { visible: tg.sub.length > 0; text: tg.sub; color: Theme.muted; wrapMode: Text.WordWrap; Layout.fillWidth: true; font { family: Theme.fontUi; pixelSize: 12 } }
    }
    Rectangle {
        Layout.preferredWidth: 38; Layout.preferredHeight: 22; radius: 11
        color: tg.on ? Theme.accent : Theme.hairline
        Rectangle {
            y: 3; width: 16; height: 16; radius: 8
            x: tg.on ? parent.width - width - 3 : 3
            color: tg.on ? Theme.bg : Theme.muted
            Behavior on x { NumberAnimation { duration: 120 } }
        }
        MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: tg.flipped() }
    }
}
