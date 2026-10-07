import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Wi-Fi network list: click a network to join it, click the connected one to disconnect.
Item {
    id: root
    required property var bar
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.sky

    AppHeader {
        id: head
        bar: root.bar; icon: "󰤨"; title: "Wi-Fi"; accent: root.accent
        subtitle: root.bar.wifiNetworks.length + " networks in range"
        anchors { top: parent.top; left: parent.left; right: parent.right }
        onBack: root.bar.hubView = "main"
        HeaderButton {
            text: root.bar.wifiScanProc.running ? "󰑐  scanning…" : "󰑐  rescan"; accent: root.accent; active: root.bar.wifiScanProc.running
            onClicked: { if (!root.bar.wifiScanProc.running) root.bar.wifiScanProc.running = true }
        }
    }

    ListView {
        id: list
        anchors { top: head.bottom; topMargin: 8; left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 14; rightMargin: 14; bottomMargin: 12 }
        clip: true; spacing: 6
        boundsBehavior: Flickable.StopAtBounds
        model: root.bar.wifiNetworks

        delegate: Rectangle {
            id: row
            required property var modelData
            readonly property bool active: modelData.active
            readonly property bool secured: !!modelData.security && modelData.security !== "--"
            width: list.width; height: 46; radius: 12
            color: active ? Qt.alpha(root.accent, 0.12) : (hh.hovered ? Qt.alpha(root.accent, 0.08) : Theme.card)
            border { color: active ? Qt.alpha(root.accent, 0.5) : (hh.hovered ? Qt.alpha(root.accent, 0.25) : Theme.cardBorder); width: 1 }
            Behavior on color { ColorAnimation { duration: 100 } }
            HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (row.active) root.bar.wifiConnectProc.disconnectWifi()
                    else root.bar.wifiConnectProc.connectTo(row.modelData.ssid)
                }
            }
            RowLayout {
                anchors { fill: parent; leftMargin: 10; rightMargin: 12 }
                spacing: 10
                Rectangle {
                    Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 9
                    color: row.active ? Qt.alpha(root.accent, 0.22) : Qt.alpha(Theme.mauve, 0.08)
                    Text {
                        anchors.centerIn: parent
                        text: row.modelData.signal > 75 ? "󰤨" : row.modelData.signal > 50 ? "󰤥" : row.modelData.signal > 25 ? "󰤢" : "󰤟"
                        color: row.active ? root.accent : Theme.subtext
                        font { family: root.font; pixelSize: 16 }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 0
                    Text { text: row.modelData.ssid; color: row.active ? Theme.bright : Theme.text; elide: Text.ElideRight; Layout.fillWidth: true
                           textFormat: Text.PlainText; font { family: root.font; pixelSize: 12; bold: row.active } }
                    Text { text: row.active ? "connected  ·  " + row.modelData.signal + "%" : (row.secured ? row.modelData.security : "open network") + "  ·  " + row.modelData.signal + "%"
                           color: row.active ? Theme.green : Theme.dim; font { family: root.font; pixelSize: 9 } }
                }
                Text { text: row.secured ? "󰌾" : "󰌿"; color: row.secured ? Theme.dim : Theme.yellow; font { family: root.font; pixelSize: 13 } }
                Rectangle { visible: row.active; Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4; color: Theme.green }
            }
        }

        EmptyState {
            visible: list.count === 0
            anchors.centerIn: parent
            icon: root.bar.wifiScanProc.running ? "󰑐" : "󰤭"; accent: root.accent
            title: root.bar.wifiScanProc.running ? "Scanning…" : "No networks found"
            hint: root.bar.wifiScanProc.running ? "" : "Press rescan to look again."
        }
    }
}
