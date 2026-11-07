import QtQuick

// A damped spring on a 0..1 progress value, integrated with the same parameters niri uses
// (unit mass, stiffness, damping ratio), so the shell and the compositor move alike.
// Set `target`; read `value` (it overshoots slightly, then settles). `moving` is false once at rest.
Item {
    id: root
    property real target: 0
    property real value: 0
    property real velocity: 0
    readonly property bool moving: anim.running

    Component.onCompleted: value = target
    onTargetChanged: anim.running = true

    FrameAnimation {
        id: anim
        onTriggered: {
            var k = Theme.springStiffness
            var c = 2 * Theme.springDampingRatio * Math.sqrt(k)
            var dt = Math.min(frameTime, 0.05)
            var n = Math.max(1, Math.ceil(dt / 0.004)), h = dt / n
            for (var i = 0; i < n; i++) {
                root.velocity += (-k * (root.value - root.target) - c * root.velocity) * h
                root.value += root.velocity * h
            }
            if (Math.abs(root.value - root.target) < Theme.springEpsilon && Math.abs(root.velocity) < 0.001) {
                root.value = root.target; root.velocity = 0; running = false
            }
        }
    }
}
