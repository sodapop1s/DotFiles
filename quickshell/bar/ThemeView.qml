import QtQuick
import QtQuick.Layouts
import Quickshell

// Theme picker: click a palette and the whole shell repaints. Palettes live in Theme.qml;
// add your own in ~/.config/qs-bar/themes.json.
Item {
    id: root
    required property var bar
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.mauve

    AppHeader {
        id: head
        bar: root.bar; icon: "󰏘"; title: "Theme"; accent: root.accent
        subtitle: Theme.all[Theme.name].label || Theme.name
        anchors { top: parent.top; left: parent.left; right: parent.right }
        onBack: root.bar.hubView = "main"
        HeaderButton { text: "󰒭  next"; accent: root.accent; onClicked: Theme.next() }
    }
    Item { id: sep; anchors.top: head.bottom; height: 0 }

    ListView {
        id: list
        anchors { top: sep.bottom; topMargin: 10; left: parent.left; right: parent.right; bottom: hint.top; leftMargin: 14; rightMargin: 14; bottomMargin: 8 }
        clip: true; spacing: 6; boundsBehavior: Flickable.StopAtBounds
        model: Theme.names

        delegate: Rectangle {
            id: row
            required property string modelData
            readonly property var pal: Theme.all[modelData]
            readonly property var full: Object.assign({}, Theme.builtin.mocha, pal)
            readonly property bool sel: Theme.name === modelData
            width: list.width; height: 54; radius: 12
            color: rh.hovered ? Qt.alpha(Theme.mauve, 0.10) : Theme.card
            border { color: sel ? root.accent : Theme.cardBorder; width: sel ? 2 : 1 }
            HoverHandler { id: rh; cursorShape: Qt.PointingHandCursor }
            MouseArea { anchors.fill: parent; onClicked: Theme.setTheme(row.modelData) }

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                spacing: 12
                // a small preview of the palette: surface chip with the accent colours on it
                Rectangle {
                    Layout.preferredWidth: 96; Layout.preferredHeight: 34; radius: 9; color: row.full.base
                    border { color: Qt.alpha(row.full.text, 0.25); width: 1 }
                    Row {
                        anchors.centerIn: parent; spacing: 4
                        Repeater {
                            model: ["mauve", "pink", "peach", "green", "sky", "red"]
                            delegate: Rectangle { required property string modelData; width: 11; height: 11; radius: 5.5; color: row.full[modelData] }
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 0
                    Text { text: row.pal.label || row.modelData; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true
                           font { family: root.font; pixelSize: 12; bold: true } textFormat: Text.PlainText }
                    Text { text: row.modelData; color: Theme.dim; font { family: root.font; pixelSize: 9 } }
                }
                Text { visible: row.sel; text: "󰄬"; color: root.accent; font { family: root.font; pixelSize: 16 } }
            }
        }
    }
    Text {
        id: hint
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 16; rightMargin: 16; bottomMargin: 10 }
        wrapMode: Text.WordWrap; color: Theme.dim; font { family: root.font; pixelSize: 9 }
        text: "Your own palettes: ~/.config/qs-bar/themes.json.  Or from a shell:  qs -c bar ipc call theme set <name>"
    }
}
