import QtQuick

// A single-line text input with a placeholder. The focus ring is the accent.
Rectangle {
    id: f
    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property bool password: false
    signal accepted()

    implicitHeight: 36
    radius: 8
    color: Theme.bg
    border { width: 1; color: input.activeFocus ? Theme.accent : Theme.hairline }

    TextInput {
        id: input
        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        selectionColor: Theme.raised
        selectedTextColor: Theme.text
        selectByMouse: true
        clip: true
        echoMode: f.password ? TextInput.Password : TextInput.Normal
        font { family: Theme.fontUi; pixelSize: Theme.sizeUi }
        onAccepted: f.accepted()
    }
    Text {
        visible: input.text.length === 0
        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 12; right: parent.right; rightMargin: 12 }
        text: f.placeholder
        color: Theme.muted
        elide: Text.ElideRight
        font { family: Theme.fontUi; pixelSize: Theme.sizeUi }
    }
}
