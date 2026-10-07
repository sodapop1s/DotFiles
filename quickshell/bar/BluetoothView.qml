import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

Item {
    required property var bar

    ColumnLayout {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        anchors { leftMargin: 12; rightMargin: 12 }
        spacing: 0

        // nav row
        RowLayout {
            Layout.fillWidth: true; Layout.preferredHeight: 40; spacing: 8
            Text {
                text: "󰁍"
                color: Theme.dim; font { family: "JetBrainsMono Nerd Font"; pixelSize: 16 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: bar.hubView = "main" }
            }
            Text { text: "Bluetooth"; color: Theme.sky; font { family: "JetBrainsMono Nerd Font"; pixelSize: 14; bold: true } }
            Item { Layout.fillWidth: true }
            Text {
                property bool on: Bluetooth.defaultAdapter?.enabled ?? false
                text: on ? "󰂯 on" : "󰂲 off"
                color: on ? Theme.teal : Theme.dim; font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                MouseArea {
                    anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                    onClicked: { if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled }
                }
            }
            Text {
                visible: Bluetooth.defaultAdapter?.enabled ?? false
                property bool scanning: Bluetooth.defaultAdapter?.discovering ?? false
                text: scanning ? "scanning…" : "scan"
                color: Theme.dim; font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.sep; Layout.bottomMargin: 2 }

        Repeater {
            model: bar.btDevices
            delegate: Rectangle {
                id: btRow
                required property var modelData
                property bool known:      modelData.paired || modelData.bonded || modelData.trusted
                property bool connecting: modelData.state === BluetoothDeviceState.Connecting || modelData.pairing
                Layout.fillWidth: true; implicitHeight: 40; radius: 6
                color: modelData.connected ? Qt.alpha(Theme.teal, 0.12) : "transparent"

                RowLayout {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    spacing: 8
                    Text {
                        text: btRow.modelData.connected ? "󰂯" : "󰂲"
                        color: btRow.modelData.connected ? Theme.teal : Theme.dim
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                    }
                    Text {
                        text: btRow.modelData.name || btRow.modelData.address
                        color: btRow.modelData.connected ? Theme.text : Theme.dim
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                    Text {
                        visible: btRow.modelData.connected && btRow.modelData.batteryAvailable
                        text: Math.round(btRow.modelData.battery * (btRow.modelData.battery <= 1 ? 100 : 1)) + "%"
                        color: Theme.yellow
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
                    }
                    Text {
                        text: btRow.connecting ? (btRow.modelData.pairing ? "pairing…" : "connecting…")
                            : btRow.modelData.state === BluetoothDeviceState.Disconnecting ? "disconnecting…"
                            : btRow.modelData.connected ? "connected"
                            : btRow.known ? "paired" : "pair"
                        color: btRow.modelData.connected ? Theme.green : (btRow.connecting ? Theme.mauve : Theme.dim)
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
                    }
                }

                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        var d = btRow.modelData
                        if (mouse.button === Qt.RightButton) { if (btRow.known) d.forget(); return }
                        if (btRow.connecting) return
                        if (d.connected) d.disconnect()
                        else if (btRow.known) { d.trusted = true; d.connect() }
                        else { d.trusted = true; d.pair() }
                    }
                }
            }
        }

        Text {
            visible: bar.btDevices.length === 0
            Layout.fillWidth: true; Layout.topMargin: 16
            text: (Bluetooth.defaultAdapter?.enabled ?? false) ? "No devices — press scan" : "Bluetooth is off"; color: Theme.dim
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
