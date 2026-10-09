import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

// Bluetooth devices: click to connect / disconnect (pairs unknown devices first), right-click to forget.
Item {
    id: root
    required property var bar
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.blue
    readonly property bool on: Bluetooth.defaultAdapter?.enabled ?? false
    readonly property bool scanning: Bluetooth.defaultAdapter?.discovering ?? false

    AppHeader {
        id: head
        bar: root.bar; icon: root.on ? "󰂯" : "󰂲"; title: "Bluetooth"; accent: root.accent
        subtitle: !root.on ? "turned off" : root.bar.btDevices.filter(d => d.connected).length + " connected"
        anchors { top: parent.top; left: parent.left; right: parent.right }
        onBack: root.bar.hubView = "main"
        HeaderButton {
            visible: root.on
            text: root.scanning ? "󰑐  scanning…" : "󰑐  scan"; accent: root.accent; active: root.scanning
            onClicked: { if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering }
        }
        HeaderButton {
            text: root.on ? "on" : "off"; accent: root.on ? Theme.green : Theme.dim; active: root.on
            onClicked: { if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled }
        }
    }

    ListView {
        id: list
        anchors { top: head.bottom; topMargin: 8; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 12 }
        clip: true; spacing: 6
        boundsBehavior: Flickable.StopAtBounds
        model: root.bar.btDevices

        delegate: Rectangle {
            id: btRow
            required property var modelData
            readonly property bool known:      modelData.paired || modelData.bonded || modelData.trusted
            readonly property bool connecting: modelData.state === BluetoothDeviceState.Connecting || modelData.pairing
            readonly property bool connected:  modelData.connected
            width: list.width; height: 46; radius: 12
            color: connected ? Qt.alpha(root.accent, 0.12) : (hh.hovered ? Qt.alpha(root.accent, 0.08) : Theme.card)
            border { color: connected ? Qt.alpha(root.accent, 0.5) : (hh.hovered ? Qt.alpha(root.accent, 0.25) : Theme.cardBorder); width: 1 }
            Behavior on color { ColorAnimation { duration: 100 } }
            HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
            MouseArea {
                anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    var d = btRow.modelData
                    if (mouse.button === Qt.RightButton) { if (btRow.known) d.forget(); return }
                    if (btRow.connecting) return
                    if (d.connected) d.disconnect()
                    else if (btRow.known) { d.trusted = true; d.connect() }
                    else { d.trusted = true; d.pair() }
                }
            }
            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 12 }
                spacing: 10
                Rectangle {
                    Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 9
                    color: btRow.connected ? Qt.alpha(root.accent, 0.22) : Qt.alpha(Theme.mauve, 0.08)
                    Text { anchors.centerIn: parent; text: btRow.connected ? "󰂱" : "󰂲"; color: btRow.connected ? root.accent : Theme.subtext
                           font { family: root.font; pixelSize: 16 } }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 0
                    Text { text: btRow.modelData.name || btRow.modelData.address; color: btRow.connected ? Theme.bright : Theme.text
                           elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText
                           font { family: root.font; pixelSize: 12; bold: btRow.connected } }
                    Text {
                        text: btRow.connecting ? (btRow.modelData.pairing ? "pairing…" : "connecting…")
                            : btRow.modelData.state === BluetoothDeviceState.Disconnecting ? "disconnecting…"
                            : btRow.connected ? "connected"
                            : btRow.known ? "paired  ·  right-click to forget" : "click to pair"
                        color: btRow.connected ? Theme.green : (btRow.connecting ? Theme.mauve : Theme.dim)
                        font { family: root.font; pixelSize: 9 }
                    }
                }
                Rectangle {
                    visible: btRow.connected && btRow.modelData.batteryAvailable
                    implicitWidth: batTxt.implicitWidth + 14; implicitHeight: 20; radius: 10
                    color: Qt.alpha(Theme.yellow, 0.16)
                    Text { id: batTxt; anchors.centerIn: parent; color: Theme.yellow; font { family: root.font; pixelSize: 10; bold: true }
                           text: "󰁹 " + Math.round(btRow.modelData.battery * (btRow.modelData.battery <= 1 ? 100 : 1)) + "%" }
                }
            }
        }

        EmptyState {
            visible: list.count === 0
            anchors.centerIn: parent
            icon: root.on ? "󰂯" : "󰂲"; accent: root.accent
            title: root.on ? "No devices yet" : "Bluetooth is off"
            hint: root.on ? "Press scan to look for nearby devices." : "Use the switch at the top right to turn it on."
        }
    }
}
