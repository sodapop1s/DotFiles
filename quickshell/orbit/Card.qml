import QtQuick
import QtQuick.Layouts

// A raised block with a hairline border. Children are laid out in a column.
Rectangle {
    id: card
    default property alias content: inner.data
    property alias spacing: inner.spacing
    property color edge: Theme.hairline

    Layout.fillWidth: true
    implicitHeight: inner.implicitHeight + 28
    radius: 12
    color: Theme.raised
    border { width: 1; color: card.edge }

    ColumnLayout {
        id: inner
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
        spacing: 8
    }
}
