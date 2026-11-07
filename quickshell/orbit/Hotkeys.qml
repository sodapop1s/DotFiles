import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// The keys menu: the important shortcuts, read from the niri config by hotkeys.py, so it always matches
// what is actually bound. Opens with Super+Shift+/ (see niri/config-v2.kdl).
Item {
    id: root
    width: parent.width
    implicitHeight: col.implicitHeight

    property bool active: false
    property var groups: []
    onActiveChanged: if (active) load()

    function load() { if (!proc.running) proc.running = true }
    Process {
        id: proc
        command: ["python3", Quickshell.shellPath("hotkeys.py")]
        stdout: StdioCollector { onStreamFinished: { try { root.groups = JSON.parse(text).groups } catch (e) { root.groups = [] } } }
    }

    // three columns, each new group going to the shortest one so they stay balanced
    readonly property var columns: {
        var cols = [[], [], []], sizes = [0, 0, 0]
        groups.forEach(g => {
            var i = sizes.indexOf(Math.min.apply(null, sizes))
            cols[i].push(g); sizes[i] += g.rows.length + 2
        })
        return cols
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 18

        RowLayout {
            Layout.fillWidth: true
            Text { text: "Keyboard shortcuts"; color: Theme.text; font { family: Theme.fontUi; pixelSize: 18; weight: Font.DemiBold } }
            Item { Layout.fillWidth: true }
            Text { text: "Esc to close"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 } }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 32
            Repeater {
                model: root.columns
                delegate: ColumnLayout {
                    id: colItem
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    spacing: 18

                    Repeater {
                        model: colItem.modelData
                        delegate: ColumnLayout {
                            id: grp
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 8
                            Heading { text: grp.modelData.title }

                            Repeater {
                                model: grp.modelData.rows
                                delegate: RowLayout {
                                    id: row
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 10
                                    Text {
                                        text: row.modelData.label
                                        color: Theme.text
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignTop
                                        Layout.topMargin: 3
                                        elide: Text.ElideRight
                                        font { family: Theme.fontUi; pixelSize: Theme.sizeUi }
                                    }
                                    ColumnLayout {
                                        Layout.alignment: Qt.AlignRight | Qt.AlignTop
                                        spacing: 3
                                        Row {
                                            Layout.alignment: Qt.AlignRight
                                            spacing: 4
                                            Repeater { model: row.modelData.chords[0]; delegate: KeyCap { required property string modelData; text: modelData } }
                                        }
                                        Text {   // other ways to do the same thing
                                            visible: row.modelData.chords.length > 1
                                            Layout.alignment: Qt.AlignRight
                                            text: "or " + row.modelData.chords.slice(1).map(c => c.join(" + ")).join("  ·  ")
                                            color: Theme.muted
                                            font { family: Theme.fontUi; pixelSize: 11 }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
