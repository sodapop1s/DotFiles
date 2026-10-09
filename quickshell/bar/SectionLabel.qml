import QtQuick
import QtQuick.Layouts

// "● OUTPUT ────────" divider used between groups in a list.
RowLayout {
    property string text: ""
    property color  accent: Theme.mauve
    spacing: 8
    Rectangle { Layout.preferredWidth: 6; Layout.preferredHeight: 6; radius: 3; color: accent }
    Text { text: parent.text.toUpperCase(); color: Theme.subtext; font { family: "JetBrainsMono Nerd Font"; pixelSize: 10; bold: true; letterSpacing: 1.2 } }
    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.cardBorder }
}
