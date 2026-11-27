import QtQuick
import QtQuick.Layouts

// Wi-Fi and Bluetooth in one window. Opened from the System panel, or with
//   qs -c orbit ipc call network open wifi|bluetooth
Item {
    id: root
    width: parent.width
    implicitHeight: col.implicitHeight

    property bool active: false
    property string tab: "wifi"
    function setTab(t) { tab = t }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 14

        RowLayout {
            spacing: 8
            Chip { text: "Wi-Fi"; selected: root.tab === "wifi"; onClicked: root.tab = "wifi" }
            Chip { text: "Bluetooth"; selected: root.tab === "bluetooth"; onClicked: root.tab = "bluetooth" }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.hairline }

        WifiPage { visible: root.tab === "wifi"; Layout.fillWidth: true; active: root.active && root.tab === "wifi" }
        BluetoothPage { visible: root.tab === "bluetooth"; Layout.fillWidth: true; active: root.active && root.tab === "bluetooth" }
    }
}
