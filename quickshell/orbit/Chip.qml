import QtQuick

// A small text button. `selected` marks the chosen option in a group; `filled` is the one primary action.
Rectangle {
    id: chip
    property string text
    property bool selected: false
    property bool filled: false
    property bool danger: false          // outline turns red on hover (destructive)
    signal clicked()

    implicitWidth: label.implicitWidth + 22
    implicitHeight: 30
    radius: 8
    opacity: enabled ? 1 : 0.5
    color: filled ? Theme.text : (selected || area.containsMouse ? Theme.raised : "transparent")
    border { width: 1; color: selected ? Theme.accent : (danger && area.containsMouse ? Theme.crit : filled ? Theme.text : Theme.hairline) }

    Text {
        id: label
        anchors.centerIn: parent
        text: chip.text
        color: chip.filled ? Theme.bg : Theme.text
        font { family: Theme.fontUi; pixelSize: 12 }
    }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: chip.clicked() }
}
