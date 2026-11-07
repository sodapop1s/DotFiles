import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Wi-Fi: the networks in range. Pick one to connect, disconnect or forget it. A secured network you have not used
// before asks for the password, which is handed to NetworkManager on its input (never on a command line).
ColumnLayout {
    id: root
    spacing: 10

    property bool active: false
    property var info: ({ enabled: true, device: "", networks: [] })
    property string selected: ""
    property string status: ""
    property bool statusBad: false
    property bool scanning: false

    function say(msg, bad) { status = msg; statusBad = !!bad }
    function reload(rescan) {
        if (listProc.running) return
        scanning = !!rescan
        listProc.command = ["python3", Quickshell.shellPath("connections.py"), "wifi"].concat(rescan ? ["--rescan"] : [])
        listProc.running = true
    }
    onActiveChanged: if (active) { selected = ""; say(""); reload(false); reload2.restart() }
    Timer { id: reload2; interval: 400; onTriggered: root.reload(true) }          // fresh scan right after the cached list
    Timer { interval: 8000; repeat: true; running: root.active; onTriggered: root.reload(false) }

    Process {
        id: listProc
        stdout: StdioCollector { onStreamFinished: { try { root.info = JSON.parse(text) } catch (e) {} root.scanning = false } }
        onExited: root.scanning = false
    }

    // one action at a time; a password, when needed, is written to nmcli's input
    property string pendingPassword: ""
    Process {
        id: act
        stdinEnabled: true
        property string out: ""
        stdout: StdioCollector { onStreamFinished: act.out += text }
        stderr: StdioCollector { onStreamFinished: act.out += text }
        onExited: code => {
            var line = act.out.trim().split("\n").filter(l => l.length).pop() || ""
            if (code === 0) { root.say(""); root.selected = "" }
            else if (/Secrets were required|password|802-1x/i.test(line)) root.say("That password was not accepted.", true)
            else if (/No network with SSID/i.test(line)) root.say("That network is no longer in range.", true)
            else root.say(line.replace(/^Error:\s*/, "") || "That did not work.", true)
            act.out = ""; root.pendingPassword = ""
            settle.restart()
        }
    }
    Timer { id: settle; interval: 1500; onTriggered: root.reload(false) }
    Timer { id: sendPw; interval: 500; onTriggered: { act.write(root.pendingPassword + "\n") } }
    function run(cmd, msg, password) {
        if (act.running) return
        say(msg, false); act.out = ""; root.pendingPassword = password || ""
        act.command = cmd; act.running = true
        if (password) sendPw.restart()
    }
    function connect(n, password) {
        if (n.saved) run(["nmcli", "connection", "up", "id", n.ssid], "Connecting to " + n.ssid + "…")
        else if (password !== undefined) run(["nmcli", "--ask", "device", "wifi", "connect", n.ssid], "Connecting to " + n.ssid + "…", password)
        else run(["nmcli", "device", "wifi", "connect", n.ssid], "Connecting to " + n.ssid + "…")
    }
    Process { id: radio; onExited: reload2.restart() }
    Process { id: editor }

    // header
    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Toggle {
            label: "Wi-Fi"
            on: root.info.enabled
            onFlipped: { radio.command = ["nmcli", "radio", "wifi", root.info.enabled ? "off" : "on"]; radio.running = true }
        }
        Chip { text: root.scanning ? "Scanning…" : "Scan"; enabled: root.info.enabled && !root.scanning; onClicked: root.reload(true) }
    }

    Text {
        visible: root.status.length > 0
        Layout.fillWidth: true; wrapMode: Text.WordWrap
        text: root.status; color: root.statusBad ? Theme.crit : Theme.muted
        font { family: Theme.fontUi; pixelSize: 12 }
    }

    Text {
        visible: !root.info.enabled
        text: "Wi-Fi is off."; color: Theme.muted; Layout.topMargin: 6
        font { family: Theme.fontUi; pixelSize: Theme.sizeUi }
    }

    ListView {
        id: list
        visible: root.info.enabled
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(440, contentHeight)
        clip: true; spacing: 6
        boundsBehavior: Flickable.StopAtBounds
        model: root.info.networks

        delegate: Rectangle {
            id: row
            required property var modelData
            readonly property bool open: root.selected === modelData.ssid
            width: list.width
            height: rowCol.implicitHeight + 20
            radius: 10
            color: open ? Theme.raised : "transparent"
            border { width: 1; color: open ? Theme.accent : Theme.hairline }

            MouseArea { anchors { left: parent.left; right: parent.right; top: parent.top } height: 52; onClicked: root.selected = row.open ? "" : row.modelData.ssid }

            ColumnLayout {
                id: rowCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12; topMargin: 10 }
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true; spacing: 12
                    Rectangle {   // connected marker
                        Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4
                        color: row.modelData.inUse ? Theme.good : "transparent"
                        border { width: row.modelData.inUse ? 0 : 1; color: Theme.hairline }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        Text { text: row.modelData.ssid; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
                        Text {
                            text: (row.modelData.inUse ? "Connected" : row.modelData.saved ? "Saved" : "")
                                  + ((row.modelData.inUse || row.modelData.saved) ? "  ·  " : "")
                                  + (row.modelData.security ? (row.modelData.enterprise ? "Needs a login" : "Secured") : "Open")
                            color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 }
                        }
                    }
                    Meter { Layout.preferredWidth: 46; value: row.modelData.signal / 100; tone: row.modelData.signal < 30 ? Theme.warn : Theme.muted }
                    Text { text: row.modelData.signal + "%"; color: Theme.muted; Layout.preferredWidth: 34; horizontalAlignment: Text.AlignRight; font { family: Theme.fontUi; pixelSize: 12 } }
                }

                // actions for the selected network
                ColumnLayout {
                    visible: row.open
                    Layout.fillWidth: true; spacing: 8

                    RowLayout {
                        spacing: 8
                        Chip { visible: row.modelData.inUse; text: "Disconnect"; onClicked: root.run(["nmcli", "device", "disconnect", root.info.device], "Disconnecting…") }
                        Chip { visible: !row.modelData.inUse && (row.modelData.saved || !row.modelData.security); filled: true; text: "Connect"; onClicked: root.connect(row.modelData) }
                        Chip { visible: row.modelData.saved; danger: true; text: "Forget"; onClicked: { root.run(["nmcli", "connection", "delete", "id", row.modelData.ssid], "Forgetting " + row.modelData.ssid + "…") } }
                    }
                    RowLayout {   // secured, never used: ask for the password
                        visible: !row.modelData.saved && row.modelData.security !== "" && !row.modelData.enterprise
                        Layout.fillWidth: true; spacing: 8
                        Field {
                            id: pw
                            Layout.fillWidth: true; password: true; placeholder: "Password"
                            onAccepted: if (text.length) { root.connect(row.modelData, text); text = "" }
                        }
                        Chip { filled: true; text: "Connect"; onClicked: if (pw.text.length) { root.connect(row.modelData, pw.text); pw.text = "" } }
                    }
                    ColumnLayout {   // 802.1X: needs more than a password
                        visible: row.modelData.enterprise && !row.modelData.saved
                        Layout.fillWidth: true; spacing: 8
                        Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "This network asks for a username or certificate, so it is set up in the network editor."; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 } }
                        Chip { text: "Open network editor"; onClicked: { editor.command = ["nm-connection-editor"]; editor.running = true } }
                    }
                }
            }
        }

        Text {
            visible: list.count === 0 && root.info.enabled
            anchors.centerIn: parent
            text: root.scanning ? "Looking for networks…" : "No networks found."
            color: Theme.muted; font { family: Theme.fontUi; pixelSize: Theme.sizeUi }
        }
    }
}
