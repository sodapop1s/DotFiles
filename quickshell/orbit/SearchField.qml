import QtQuick

// A single-line search box. Emits key events for the list below it.
Rectangle {
    id: root
    property alias text: input.text
    property string placeholder: "Search"
    signal up()
    signal down()
    signal accepted()
    signal deleteRequested()
    function focusInput() { input.forceActiveFocus() }

    height: 44
    radius: 10
    color: Theme.bg
    border { width: 1; color: input.activeFocus ? Theme.accent : Theme.hairline }

    TextInput {
        id: input
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 14 }
        color: Theme.text
        selectionColor: Theme.raised
        selectedTextColor: Theme.text
        font { family: Theme.fontUi; pixelSize: 16 }
        clip: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Down || (event.key === Qt.Key_N && event.modifiers & Qt.ControlModifier)) { root.down(); event.accepted = true }
            else if (event.key === Qt.Key_Up || (event.key === Qt.Key_P && event.modifiers & Qt.ControlModifier)) { root.up(); event.accepted = true }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.accepted(); event.accepted = true }
            else if (event.key === Qt.Key_Delete && event.modifiers & Qt.ShiftModifier) { root.deleteRequested(); event.accepted = true }
        }
    }
    Text {
        visible: input.text.length === 0
        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 14 }
        text: root.placeholder
        color: Theme.muted
        font { family: Theme.fontUi; pixelSize: 16 }
    }
}
