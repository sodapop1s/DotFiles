import QtQuick
import QtQuick.Layouts

// A small toggle button for the hub's quick-settings row: icon on top, label under it, lit when on.
Rectangle {
    id: qp
    property string icon: ""
    property string label: ""
    property string sub: ""
    property bool   on: false
    property bool   enabled: true
    property color  accent: Theme.mauve
    signal clicked

    implicitHeight: 62
    radius: 12
    opacity: enabled ? 1 : 0.45
    color: on ? Qt.alpha(accent, 0.18) : (qa.containsMouse ? Qt.alpha(Theme.mauve, 0.10) : Theme.card)
    border { color: on ? Qt.alpha(accent, 0.55) : Theme.cardBorder; width: 1 }
    Behavior on color { ColorAnimation { duration: 120 } }

    ColumnLayout {
        anchors.centerIn: parent; spacing: 2
        Text { Layout.alignment: Qt.AlignHCenter; text: qp.icon; color: qp.on ? qp.accent : Theme.dim; font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 } }
        Text { Layout.alignment: Qt.AlignHCenter; text: qp.label; color: Theme.text; font { family: "JetBrainsMono Nerd Font"; pixelSize: 10; bold: qp.on } }
        Text { Layout.alignment: Qt.AlignHCenter; text: qp.sub; visible: text.length > 0; color: Theme.dim; font { family: "JetBrainsMono Nerd Font"; pixelSize: 8 } }
    }
    MouseArea { id: qa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (qp.enabled) qp.clicked() }
}
