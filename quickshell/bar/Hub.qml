import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Io

PanelWindow {
    id: hub
    required property var barId

    visible: barId.hubOpen
    color: "transparent"
    anchors { top: true; left: true; right: true; bottom: true }
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.layer: WlrLayershell.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // ── Catppuccin Mocha (matches bar) ────────────────────
    readonly property color cIslandBg:     Qt.rgba(17/255,  17/255,  27/255,  0.97)
    readonly property color cModuleBg:     Qt.rgba(49/255,  50/255,  68/255,  0.90)
    readonly property color cBorder:       Qt.rgba(203/255, 166/255, 247/255, 0.12)
    readonly property color cSep:          Qt.rgba(203/255, 166/255, 247/255, 0.10)
    readonly property color cMauve:        "#cba6f7"
    readonly property color cText:         "#b4befe"
    readonly property color cSubtext:      "#6c7086"
    readonly property color cTeal:         "#94e2d5"
    readonly property color cSky:          "#89dceb"
    readonly property color cPeach:        "#fab387"
    readonly property color cGreen:        "#a6e3a1"
    readonly property color cRed:          "#f38ba8"
    readonly property color cYellow:       "#f9e2af"

    // ── Brightness ────────────────────────────────────────
    property int brightPct: 39

    Process {
        id: brightReadProc
        command: ["bash", "-c", "brightnessctl -m | cut -d, -f4 | tr -d '%'"]
        stdout: SplitParser {
            onRead: data => {
                var v = parseInt(data.trim())
                if (!isNaN(v)) hub.brightPct = v
            }
        }
        onExited: running = false
    }

    Process {
        id: brightSetProc
        onExited: { running = false; if (!brightReadProc.running) brightReadProc.running = true }
        function setTo(pct) { command = ["brightnessctl", "set", Math.max(1, pct) + "%"]; running = true }
    }

    Timer {
        interval: 3000; repeat: true; running: hub.visible; triggeredOnStart: hub.visible
        onTriggered: { if (!brightReadProc.running) brightReadProc.running = true }
    }

    // ── WiFi ──────────────────────────────────────────────
    property bool wifiOn: true

    Process {
        id: wifiReadProc
        command: ["nmcli", "radio", "wifi"]
        stdout: SplitParser { onRead: data => { hub.wifiOn = data.trim() === "enabled" } }
        onExited: running = false
    }

    Process {
        id: wifiToggleProc
        onExited: { running = false; if (!wifiReadProc.running) wifiReadProc.running = true }
        function toggle() { command = ["nmcli", "radio", "wifi", hub.wifiOn ? "off" : "on"]; running = true }
    }

    Timer {
        interval: 5000; repeat: true; running: hub.visible; triggeredOnStart: hub.visible
        onTriggered: { if (!wifiReadProc.running) wifiReadProc.running = true }
    }

    // ── DND (local only — mako not yet wired) ─────────────
    property bool dndOn: false

    // ── Click outside to close ────────────────────────────
    MouseArea {
        anchors.fill: parent
        onClicked: barId.hubOpen = false
    }

    // ── Hub panel ─────────────────────────────────────────
    Rectangle {
        id: panel
        x: Math.round((parent.width - width) / 2)
        y: 52
        width: 500
        radius: 14
        color: hub.cIslandBg
        border { color: hub.cBorder; width: 1 }
        height: mainCol.implicitHeight + 28

        MouseArea { anchors.fill: parent }  // eat clicks

        ColumnLayout {
            id: mainCol
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors { leftMargin: 16; rightMargin: 16; topMargin: 16 }
            spacing: 0

            // ── Quick toggles ─────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                // WiFi
                HubToggle {
                    Layout.fillWidth: true
                    icon: hub.wifiOn ? "󰖩" : "󰖪"
                    label: "WiFi"
                    active: hub.wifiOn
                    onToggled: wifiToggleProc.toggle()
                    colors: hub
                }

                // Bluetooth
                HubToggle {
                    Layout.fillWidth: true
                    property var adapter: Bluetooth.defaultAdapter
                    icon: "󰂯"
                    label: "Bluetooth"
                    active: adapter?.powered ?? false
                    onToggled: { if (adapter) adapter.powered = !adapter.powered }
                    colors: hub
                }

                // DND
                HubToggle {
                    Layout.fillWidth: true
                    icon: hub.dndOn ? "󰂛" : "󰂚"
                    label: "Do Not Disturb"
                    active: hub.dndOn
                    onToggled: hub.dndOn = !hub.dndOn
                    colors: hub
                }
            }

            HubSep { colors: hub }

            // ── Volume slider ─────────────────────────────
            HubSlider {
                Layout.fillWidth: true
                icon: {
                    if (barId.volMuted || barId.volPct === 0) return "󰝟"
                    if (barId.volPct > 66) return "󰕾"
                    if (barId.volPct > 33) return "󰖀"
                    return "󰕿"
                }
                label: "Volume"
                value: barId.volPct / 100
                displayText: barId.volPct + "%"
                accentColor: hub.cTeal
                colors: hub
                onSlid: pct => {
                    barId.volPct = Math.round(pct * 100)
                    if (!volSetProc.running) volSetProc.setTo(Math.round(pct * 100))
                }
            }

            // Brightness slider
            HubSlider {
                Layout.fillWidth: true
                icon: "󰃠"
                label: "Brightness"
                value: hub.brightPct / 100
                displayText: hub.brightPct + "%"
                accentColor: hub.cYellow
                colors: hub
                onSlid: pct => {
                    hub.brightPct = Math.round(pct * 100)
                    if (!brightSetProc.running) brightSetProc.setTo(Math.round(pct * 100))
                }
            }

            HubSep { colors: hub }

            // ── Stats ─────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                spacing: 0

                HubStat { Layout.fillWidth: true; icon: ""; label: "CPU";  value: barId.cpuUsage + "%";  accent: barId.cpuUsage  > 80 ? hub.cRed : hub.cTeal;  colors: hub }
                HubStat { Layout.fillWidth: true; icon: ""; label: "RAM";  value: barId.memPercent + "%"; accent: barId.memPercent > 80 ? hub.cRed : hub.cTeal;  colors: hub }
                HubStat { Layout.fillWidth: true; icon: ""; label: "Temp"; value: barId.cpuTemp + "°C";  accent: barId.cpuTemp   > 80 ? hub.cRed : (barId.cpuTemp > 70 ? hub.cYellow : hub.cPeach); colors: hub }
                HubStat { Layout.fillWidth: true; icon: "󰁹"; label: "Bat";  value: barId.batPct + "%";    accent: barId.batStatus === "Charging" ? hub.cGreen : (barId.batPct <= 20 ? hub.cRed : hub.cText); colors: hub }
            }

            HubSep { colors: hub }

            // ── Weather ───────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                spacing: 8

                Text {
                    text: barId.weatherStr
                    color: hub.cPeach
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
                }

                Text {
                    text: "updated hourly"
                    color: hub.cSubtext
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "󰃠  " + hub.brightPct + "% screen"
                    color: hub.cSubtext
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }

    // ── Sub-components ────────────────────────────────────

    component HubSep: Rectangle {
        required property var colors
        Layout.fillWidth: true
        Layout.topMargin: 10
        Layout.bottomMargin: 10
        height: 1
        color: colors.cSep
    }

    component HubToggle: Rectangle {
        id: toggle
        required property var colors
        property string icon: ""
        property string label: ""
        property bool active: false
        signal toggled

        height: 56
        radius: 10
        color: active ? Qt.rgba(203/255, 166/255, 247/255, 0.18) : colors.cModuleBg
        border { color: active ? Qt.rgba(203/255, 166/255, 247/255, 0.35) : colors.cBorder; width: 1 }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 3

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: toggle.icon
                color: toggle.active ? colors.cMauve : colors.cSubtext
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 18 }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: toggle.label.length > 12 ? toggle.label.substring(0, 10) + "…" : toggle.label
                color: toggle.active ? colors.cText : colors.cSubtext
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: toggle.toggled()
        }
    }

    component HubSlider: RowLayout {
        id: sliderRow
        required property var colors
        property string icon: ""
        property string label: ""
        property real value: 0
        property string displayText: ""
        property color accentColor: "#cba6f7"
        signal slid(real pct)

        height: 36
        spacing: 10

        Text {
            text: sliderRow.icon
            color: sliderRow.accentColor
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 15 }
            Layout.preferredWidth: 20
        }

        // Track + handle
        Item {
            Layout.fillWidth: true
            height: 20

            Rectangle {
                id: track
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                height: 5; radius: 3
                color: Qt.rgba(203/255, 166/255, 247/255, 0.12)

                Rectangle {
                    width: Math.max(handle.width / 2, track.width * sliderRow.value)
                    height: parent.height; radius: parent.radius
                    color: sliderRow.accentColor
                    opacity: 0.8
                }
            }

            Rectangle {
                id: handle
                x: (track.width - width) * sliderRow.value
                anchors.verticalCenter: track.verticalCenter
                width: 16; height: 16; radius: 8
                color: sliderRow.accentColor
                border { color: Qt.rgba(0,0,0,0.3); width: 1 }
            }

            MouseArea {
                anchors.fill: parent
                function emit(mx) {
                    var v = Math.max(0, Math.min(1, mx / track.width))
                    sliderRow.slid(v)
                }
                onPressed:         mouse => emit(mouse.x)
                onPositionChanged: mouse => { if (pressed) emit(mouse.x) }
            }
        }

        Text {
            text: sliderRow.displayText
            color: sliderRow.colors.cSubtext
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
            Layout.preferredWidth: 36
            horizontalAlignment: Text.AlignRight
        }
    }

    component HubStat: Item {
        required property var colors
        property string icon: ""
        property string label: ""
        property string value: ""
        property color accent: "#b4befe"

        height: 52

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 3

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.value
                color: parent.parent.accent
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 14; bold: true }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: parent.parent.label
                color: parent.parent.colors.cSubtext
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
            }
        }
    }
}
