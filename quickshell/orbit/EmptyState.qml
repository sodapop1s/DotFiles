import QtQuick
import QtQuick.Layouts

// Centered placeholder for a list with nothing in it: a big tinted glyph, a title and a hint.
ColumnLayout {
    property string icon: "󰍉"
    property string title: ""
    property string hint: ""
    property color  accent: Theme.mauve
    spacing: 6
    Rectangle {
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 56; Layout.preferredHeight: 56; radius: 28
        color: Qt.alpha(accent, 0.12); border { color: Qt.alpha(accent, 0.25); width: 1 }
        Text { anchors.centerIn: parent; text: icon; color: accent; font { family: "JetBrainsMono Nerd Font"; pixelSize: 24 } }
    }
    Text { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 6; text: title; color: Theme.text
           font { family: "JetBrainsMono Nerd Font"; pixelSize: 13; bold: true } }
    Text { visible: hint.length > 0; Layout.alignment: Qt.AlignHCenter; Layout.maximumWidth: 300
           horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; text: hint; color: Theme.dim
           font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 } }
}
