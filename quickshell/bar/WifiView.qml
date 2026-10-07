import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

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
            Text { text: "WiFi"; color: Theme.sky; font { family: "JetBrainsMono Nerd Font"; pixelSize: 14; bold: true } }
            Item { Layout.fillWidth: true }
            Text {
                text: bar.wifiScanProc.running ? "scanning…" : "rescan"
                color: Theme.dim; font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (!bar.wifiScanProc.running) bar.wifiScanProc.running = true } }
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.sep; Layout.bottomMargin: 2 }

        Repeater {
            model: bar.wifiNetworks
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true; implicitHeight: 40; radius: 6
                color: modelData.active ? Qt.alpha(Theme.sky, 0.12) : "transparent"

                RowLayout {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    spacing: 8
                    Text {
                        text: modelData.signal > 75 ? "󰤨" : modelData.signal > 50 ? "󰤥" : modelData.signal > 25 ? "󰤢" : "󰤟"
                        color: modelData.active ? Theme.sky : Theme.dim
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                    }
                    Text {
                        text: modelData.ssid; color: modelData.active ? Theme.text : Theme.dim
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                    Text {
                        text: modelData.security || "Open"; color: Theme.dim
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
                    }
                    Text {
                        visible: modelData.active; text: "●"; color: Theme.green
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 8 }
                    }
                }

                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.active) bar.wifiConnectProc.disconnectWifi()
                        else bar.wifiConnectProc.connectTo(modelData.ssid)
                    }
                }
            }
        }

        Text {
            visible: bar.wifiNetworks.length === 0 && !bar.wifiScanProc.running
            Layout.fillWidth: true; Layout.topMargin: 16
            text: "No networks found"; color: Theme.dim
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
