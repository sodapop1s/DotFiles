import QtQuick
import QtQuick.Layouts

// A number with minus and plus buttons. Emits changed(v); the owner stores it.
RowLayout {
    id: st
    property string label: ""
    property int value: 0
    property int from: 1
    property int to: 90
    property int step: 1
    property string unit: " min"
    signal changed(int v)

    Layout.fillWidth: true
    spacing: 8
    Text { text: st.label; color: Theme.muted; Layout.fillWidth: true; elide: Text.ElideRight; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
    Chip { implicitWidth: 28; implicitHeight: 28; text: "−"; onClicked: st.changed(Math.max(st.from, st.value - st.step)) }
    Text { text: st.value + st.unit; color: Theme.text; Layout.preferredWidth: 56; horizontalAlignment: Text.AlignHCenter; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
    Chip { implicitWidth: 28; implicitHeight: 28; text: "+"; onClicked: st.changed(Math.min(st.to, st.value + st.step)) }
}
