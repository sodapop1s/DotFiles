import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

// Output and input volume, plus one slider per app that is playing sound.
// PipeWire pushes changes, so nothing is polled.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 12

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property var apps: Pipewire.nodes.values.filter(n => n.isStream && !n.isSink && n.audio)

    PwObjectTracker { objects: [root.sink, root.source].concat(root.sinks, root.apps).filter(n => n) }

    function appLabel(n) { return (n.properties && n.properties["application.name"]) || n.description || n.name }

    component VolumeRow: ColumnLayout {
        id: vr
        property var node: null
        property string label: ""
        visible: node !== null && node.audio !== null
        Layout.fillWidth: true
        spacing: 2
        RowLayout {
            Layout.fillWidth: true
            Text { text: vr.label; color: Theme.muted; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
            Text {
                text: vr.node && vr.node.audio ? Math.round(vr.node.audio.volume * 100) + "%" : ""
                color: vr.node && vr.node.audio && vr.node.audio.muted ? Theme.muted : Theme.text
                font { family: Theme.fontUi; pixelSize: Theme.sizeUi }
            }
            Text {
                text: vr.node && vr.node.audio && vr.node.audio.muted ? "Unmute" : "Mute"
                color: Theme.muted
                font { family: Theme.fontUi; pixelSize: 12 }
                MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: vr.node.audio.muted = !vr.node.audio.muted }
            }
        }
        Slider {
            Layout.fillWidth: true
            value: vr.node && vr.node.audio ? vr.node.audio.volume : 0
            tone: vr.node && vr.node.audio && vr.node.audio.muted ? Theme.muted : Theme.text
            onMoved: v => { vr.node.audio.volume = v; if (vr.node.audio.muted) vr.node.audio.muted = false }
        }
    }

    VolumeRow { node: root.sink; label: root.sink ? root.sink.description : "" }

    // switch output device (only shown when there is a choice)
    Repeater {
        model: root.sinks.length > 1 ? root.sinks : []
        delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true; spacing: 8
            Rectangle { Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4; color: modelData === root.sink ? Theme.accent : Theme.hairline }
            Text { text: modelData.description; color: modelData === root.sink ? Theme.text : Theme.muted; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: Theme.fontUi; pixelSize: 12 } }
            TapHandler { onTapped: Pipewire.preferredDefaultAudioSink = modelData }
        }
    }

    VolumeRow { node: root.source; label: root.source ? "Microphone · " + root.source.description : "" }

    Repeater {
        model: root.apps
        delegate: VolumeRow { required property var modelData; node: modelData; label: root.appLabel(modelData) }
    }
}
