import QtQuick
import QtQuick.Layouts

// Left panel: how the machine is doing.
Flickable {
    id: flick
    anchors.fill: parent
    contentHeight: root.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    property bool open: false
    signal manage(string tab)
    readonly property var s: Sys.stats
    readonly property var bat: s.battery || null
    readonly property var temps: s.temps || ({})

    ColumnLayout {
    id: root
    width: flick.width
    spacing: 16


    function tone(v, warn, crit) { return v >= crit ? Theme.crit : v >= warn ? Theme.warn : Theme.text }
    function mins(m) { return m === null || m === undefined ? "—" : (m >= 60 ? Math.floor(m / 60) + " h " + (m % 60) + " min" : m + " min") }
    function degrees(v) { return v === undefined ? "—" : v + " °C" }

    component Label: Text { color: Theme.muted; font { family: Theme.fontUi; pixelSize: 11; capitalization: Font.AllUppercase; letterSpacing: 1 } }
    component Rule: Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.hairline }

    Label { text: "Quick settings" }
    QuickSettings { onManage: tab => flick.manage(tab) }
    Rule {}

    Label { text: "Processor and memory" }
    StatRow { label: "Processor"; value: s.cpu === undefined ? "—" : s.cpu + "%"; fraction: (s.cpu || 0) / 100; tone: root.tone(s.cpu || 0, 80, 95) }
    StatRow { label: "Memory"; value: s.mem === undefined ? "—" : s.mem + "%"; fraction: (s.mem || 0) / 100; tone: root.tone(s.mem || 0, 80, 92) }
    Rule {}

    Label { text: "Temperatures" }
    StatRow { label: "Processor"; value: root.degrees(temps.cpu); tone: root.tone(temps.cpu || 0, 80, 90) }
    StatRow { label: "Graphics"; value: root.degrees(temps.gpu); tone: root.tone(temps.gpu || 0, 80, 90) }
    StatRow { label: "Storage"; value: root.degrees(temps.storage); tone: root.tone(temps.storage || 0, 65, 75) }
    Rule {}

    Label { text: "Battery" }
    StatRow {
        label: bat ? bat.status : "Status"
        value: bat ? bat.pct + "%" : "—"
        fraction: bat ? bat.pct / 100 : -1
        tone: !bat ? Theme.text : bat.status === "Charging" ? Theme.good : bat.pct <= 10 ? Theme.crit : bat.pct <= 20 ? Theme.warn : Theme.text
    }
    StatRow { visible: bat !== null && bat.minutes !== null; label: bat && bat.status === "Charging" ? "Time to full" : "Time remaining"; value: root.mins(bat ? bat.minutes : null) }
    StatRow { visible: bat !== null && bat.watts > 0; label: "Power draw"; value: bat ? bat.watts + " W" : "" }
    StatRow { visible: bat !== null && bat.health !== null; label: "Battery health"; value: bat ? bat.health + "%" : "" }
    Text {
        visible: Sys.batStatus === "Not charging" || (bat !== null && bat.pct >= Sys.batCap - 2 && Sys.batStatus !== "Discharging")
        text: "Charging is held at " + Sys.batCap + "%."
        color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 }
    }
    Rule {}

    Label { text: "Wi-Fi" }
    StatRow {
        label: s.wifi ? s.wifi.ssid : "Not connected"
        value: s.wifi ? s.wifi.signal + "%" : ""
        fraction: s.wifi ? s.wifi.signal / 100 : -1
        tone: s.wifi && s.wifi.signal < 30 ? Theme.warn : Theme.text
    }
    Rule {}

    Label { text: "Audio" }
    AudioSection {}
    Rule {}

    Label { text: "AirDrop" }
    AirDropSection { active: flick.open }
    Rule {}

    Label { text: "Services" }
    Repeater {
        model: s.services || []
        delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true
            Rectangle { Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4; color: modelData.up ? Theme.good : Theme.crit }
            Text { text: modelData.name; color: Theme.text; Layout.fillWidth: true; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
            Text { text: modelData.up ? "Up" : "Down"; color: modelData.up ? Theme.muted : Theme.crit; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
        }
    }
    Text {
        visible: (s.services || []).length === 0
        text: "No services configured.\nList them in ~/.config/orbit/services.json"
        color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 }
    }

    }
}
