import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// The desktop background: Earth as seen from orbit, lit by the real sun, with the ISS marked.
// Day/night maps and the compiled shader live in /run/current-system/sw/share/orbit (nixos/modules/wallpaper).
// Nothing animates. The sun position is recomputed once a minute (every 5 minutes on battery) and the
// ISS position is re-read when the orbit-iss timer rewrites its file, so the scene redraws only then.
PanelWindow {
    id: win

    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: Theme.bg
    WlrLayershell.layer: WlrLayershell.Background
    WlrLayershell.namespace: "orbit-wallpaper"

    readonly property string assets: Quickshell.env("ORBIT_ASSETS") || "/run/current-system/sw/share/orbit"
    // the place the lower-middle of the screen looks at, degrees (US east coast)
    readonly property real focusLat: 38
    readonly property real focusLon: -78

    property real sunLat: 0      // degrees, where the sun is overhead
    property real sunLon: 0
    property var iss: null       // { lat, lon } or null

    // low-precision solar position (about 0.01 degrees), plenty for a wallpaper
    function sunPosition(ms) {
        var rad = Math.PI / 180
        var n = ms / 86400000 - 10957.5                       // days since J2000
        var L = 280.460 + 0.9856474 * n
        var g = (357.528 + 0.9856003 * n) * rad
        var lambda = (L + 1.915 * Math.sin(g) + 0.020 * Math.sin(2 * g)) * rad
        var eps = (23.439 - 0.0000004 * n) * rad
        var dec = Math.asin(Math.sin(eps) * Math.sin(lambda))
        var ra = Math.atan2(Math.cos(eps) * Math.sin(lambda), Math.cos(lambda))
        var gmst = (280.46061837 + 360.98564736629 * n) * rad
        var lon = ra - gmst
        lon = Math.atan2(Math.sin(lon), Math.cos(lon))        // wrap to -pi..pi
        return { lat: dec / rad, lon: lon / rad }
    }
    function refresh() { var s = sunPosition(Date.now()); sunLat = s.lat; sunLon = s.lon }

    Timer {
        interval: Sys.onBattery ? 300000 : 60000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: win.refresh()
    }

    FileView {
        path: Quickshell.env("HOME") + "/.cache/orbit/iss.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { var j = JSON.parse(text()); win.iss = { lat: j.lat, lon: j.lon } } catch (e) { win.iss = null } }
        onLoadFailed: win.iss = null
    }

    Image { id: dayImg;   visible: false; asynchronous: true; mipmap: false; source: "file://" + win.assets + "/earth-day.jpg" }
    Image { id: nightImg; visible: false; asynchronous: true; mipmap: false; source: "file://" + win.assets + "/earth-night.jpg" }

    ShaderEffect {
        id: earth
        anchors.fill: parent
        visible: dayImg.status === Image.Ready && nightImg.status === Image.Ready

        // The globe is big and mostly below the screen: only the curved horizon and a cap show.
        readonly property real globeR: width * 0.85
        readonly property real cy: height * 0.58 + globeR             // top of the globe sits 58% down the screen
        readonly property real deg: Math.PI / 180
        // which angle from the sphere's centre the lower-middle of the screen is, so focusLat appears there
        readonly property real refAngle: Math.asin(Math.min(1, (cy - height * 0.79) / globeR))

        property vector2d resolution: Qt.vector2d(width, height)
        property vector2d subsolar: Qt.vector2d(win.sunLat * deg, win.sunLon * deg)
        property vector2d view: Qt.vector2d(win.focusLat * deg - refAngle, win.focusLon * deg)
        property vector3d sphere: Qt.vector3d(width * 0.5, cy, globeR)
        property vector2d iss: win.iss ? Qt.vector2d(win.iss.lat * deg, win.iss.lon * deg) : Qt.vector2d(0, 0)
        property real issOn: win.iss ? 1 : 0
        property color bgColor: Theme.bg
        property color issColor: Theme.text
        property variant dayTex: dayImg
        property variant nightTex: nightImg

        fragmentShader: "file://" + win.assets + "/earth.frag.qsb"
    }
}
