import QtQuick

// One key, drawn as a small cap. A chord is several caps in a row.
Rectangle {
    id: cap
    property string text
    implicitWidth: Math.max(24, label.implicitWidth + 16)
    implicitHeight: 24
    radius: 6
    color: Theme.bg
    border { width: 1; color: Theme.hairline }
    Text {
        id: label
        anchors.centerIn: parent
        text: cap.text
        color: Theme.text
        font { family: Theme.fontUi; pixelSize: 12; weight: Font.DemiBold }
    }
}
