import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// The default view: a small floating pill, bottom centre. Workspace dots, time, battery.
// Anything else (no network, ...) shows up here only while it needs attention.
PanelWindow {
    id: pill

    required property var host     // the shell root: the study timer lives on host.studyFocus

    anchors.bottom: true
    margins.bottom: 14
    implicitWidth: row.implicitWidth + 36
    implicitHeight: 38
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "orbit-pill"

    SystemClock { id: clock; precision: SystemClock.Minutes }

    readonly property color batTone: Sys.charging ? Theme.good : Sys.batLevel <= 10 ? Theme.crit : Sys.batLevel <= 20 ? Theme.warn : Theme.text

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.panel
        border { width: 1; color: Theme.hairline }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 14

            Row {
                spacing: 6
                Repeater {
                    model: Sys.workspaceList
                    delegate: Item {
                        id: dot
                        required property var modelData
                        readonly property bool active: modelData.is_active
                        width: 8 + 14 * Math.max(0, dotSpring.value)
                        height: 18
                        Spring { id: dotSpring; target: dot.active ? 1 : 0 }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width; height: 8; radius: 4
                            color: dot.active ? Theme.accent : dot.modelData.active_window_id !== null ? Theme.muted : Theme.hairline
                        }
                        MouseArea { anchors.fill: parent; onClicked: Sys.focusWorkspace(dot.modelData.idx) }
                    }
                }
            }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 14; color: Theme.hairline }

            Text {
                text: Qt.formatDateTime(clock.date, "h:mm AP")
                color: Theme.text
                font { family: Theme.fontUi; pixelSize: Theme.sizeUi }
            }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 14; color: Theme.hairline }

            Row {
                spacing: 6
                Item {
                    width: 24; height: 18
                    Rectangle {
                        x: 0; anchors.verticalCenter: parent.verticalCenter
                        width: 21; height: 11; radius: 3; color: "transparent"
                        border { width: 1; color: Theme.muted }
                        Rectangle {
                            x: 2; y: 2; height: parent.height - 4; radius: 1.5
                            width: Math.max(2, (parent.width - 4) * Sys.batLevel / 100)
                            color: pill.batTone
                        }
                    }
                    Rectangle { x: 22; anchors.verticalCenter: parent.verticalCenter; width: 2; height: 5; radius: 1; color: Theme.muted }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Sys.batLevel + "%"
                    color: pill.batTone
                    font { family: Theme.fontUi; pixelSize: Theme.sizeUi }
                }
            }

            // appears only while the study timer is running or paused
            Row {
                visible: pill.host.studyFocus.phase !== "idle"
                spacing: 8
                Rectangle { width: 1; height: 14; color: Theme.hairline; anchors.verticalCenter: parent.verticalCenter }
                Rectangle { width: 8; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: pill.host.studyFocus.running ? Theme.good : Theme.muted }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property var fs: pill.host.studyFocus
                    text: (fs.phase === "focus" ? "Focus " : fs.phase === "break" ? "Break " : "Long break ") + fs.clock(fs.remaining) + (fs.running ? "" : " (paused)")
                    color: Theme.text
                    font { family: Theme.fontUi; pixelSize: Theme.sizeUi }
                }
            }

            // appears only when the network needs attention
            Row {
                visible: Sys.netState !== "connected"
                spacing: 8
                Rectangle { width: 1; height: 14; color: Theme.hairline; anchors.verticalCenter: parent.verticalCenter }
                Rectangle { width: 8; height: 8; radius: 4; color: Sys.netState === "none" ? Theme.crit : Theme.warn; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Sys.netState === "none" ? "No network" : "Limited network"
                    color: Theme.text
                    font { family: Theme.fontUi; pixelSize: Theme.sizeUi }
                }
            }
        }
    }
}
