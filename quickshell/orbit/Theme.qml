pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Design tokens for the shell. Values come from nixos/modules/theme/tokens.nix, generated to tokens.json.
// The defaults below are the same values, so the shell still renders if the file is missing.
// The old Catppuccin-era names (mauve, peach, ...) are kept as aliases of the new palette so the
// legacy hub files keep working until step 5 ports or removes them.
Singleton {
    id: root

    property var tokens: ({
        color: { bg: "#0E1013", panel: "#171A1F", raised: "#20242B", hairline: "#2C313A", text: "#F2F4F7", muted: "#8B93A1",
                 accent: "#4C9EFF", good: "#3FCF8E", warn: "#F5A524", crit: "#F2555A" },
        font: { ui: "D-DIN", uiFallback: "Inter", mono: "JetBrainsMono Nerd Font", monoSize: 12, uiSize: 13 },
        motion: { spring: { dampingRatio: 0.75, stiffness: 700, epsilon: 0.0001 } },
        radius: 12, gap: 8
    })

    FileView {
        path: "/run/current-system/sw/share/rice-theme/tokens.json"
        onLoaded: { try { root.tokens = JSON.parse(text()) } catch (e) {} }
    }

    readonly property color bg:       tokens.color.bg
    readonly property color panel:    tokens.color.panel
    readonly property color raised:   tokens.color.raised
    readonly property color hairline: tokens.color.hairline
    readonly property color text:     tokens.color.text
    readonly property color muted:    tokens.color.muted
    readonly property color accent:   tokens.color.accent    // focus and selection only
    readonly property color good:     tokens.color.good      // states only
    readonly property color warn:     tokens.color.warn
    readonly property color crit:     tokens.color.crit

    readonly property real radius: tokens.radius
    readonly property real gap:    tokens.gap

    readonly property var families: Qt.fontFamilies()
    readonly property string fontUi:   families.indexOf(tokens.font.ui) >= 0 ? tokens.font.ui : tokens.font.uiFallback
    readonly property string fontMono: tokens.font.mono
    readonly property int sizeUi:   tokens.font.uiSize
    readonly property int sizeMono: tokens.font.monoSize

    // the one spring, shared with niri (see Spring.qml)
    readonly property real springDampingRatio: tokens.motion.spring.dampingRatio
    readonly property real springStiffness:    tokens.motion.spring.stiffness
    readonly property real springEpsilon:      tokens.motion.spring.epsilon

    // ── legacy aliases ──
    readonly property color base:    bg
    readonly property color crust:   bg
    readonly property color surface: raised
    readonly property color bright:  text
    readonly property color subtext: muted
    readonly property color dim:     Qt.alpha(muted, 0.7)
    readonly property color mauve:   accent
    readonly property color blue:    accent
    readonly property color sky:     accent
    readonly property color teal:    accent
    readonly property color pink:    accent
    readonly property color green:   good
    readonly property color yellow:  warn
    readonly property color peach:   warn
    readonly property color red:     crit
    readonly property color card:         Qt.alpha(raised, 0.6)
    readonly property color cardBorder:   hairline
    readonly property color sep:          hairline
    readonly property color islandBg:     Qt.alpha(panel, 0.96)
    readonly property color islandBorder: hairline
    readonly property bool light: false
}
