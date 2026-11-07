import QtQuick
import QtQuick.Layouts

// One labelled value, optionally with a thin bar. Colour is only for state (warn / crit / good).
ColumnLayout {
    id: row
    property string label
    property string value
    property real fraction: -1          // 0..1 draws a bar; negative hides it
    property color tone: Theme.text

    Layout.fillWidth: true
    spacing: 5

    RowLayout {
        Layout.fillWidth: true
        Text { text: row.label; color: Theme.muted; Layout.fillWidth: true; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
        Text { text: row.value; color: row.tone; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
    }
    Rectangle {
        visible: row.fraction >= 0
        Layout.fillWidth: true; Layout.preferredHeight: 3
        radius: 2; color: Theme.hairline
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, row.fraction)); height: parent.height; radius: 2
            color: row.tone === Theme.text ? Theme.muted : row.tone
        }
    }
}
