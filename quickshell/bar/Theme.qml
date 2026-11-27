pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The one place colours live. Every other file reads Theme.<token>; switching `name` repaints the whole shell.
//   qs -c bar ipc call theme set nord      qs -c bar ipc call theme next      qs -c bar ipc call theme list
// Your own palettes go in ~/.config/qs-bar/themes.json as { "name": { "label": "...", "text": "#...", ... } }
// (any token you leave out is taken from Mocha). The choice is remembered in ~/.local/state/qs-bar-theme.json.
Singleton {
    id: root

    property string name: "mocha"

    readonly property var builtin: ({
        mocha:     { label: "Catppuccin Mocha",     base: "#1e1e2e", panel: "#242436", surface: "#313244", crust: "#11111b", text: "#b4befe", bright: "#cdd6f4", subtext: "#a6adc8", dim: "#6c7086",
                     mauve: "#cba6f7", pink: "#f5c2e7", peach: "#fab387", teal: "#94e2d5", sky: "#89dceb", green: "#a6e3a1", yellow: "#f9e2af", red: "#f38ba8", blue: "#89b4fa" },
        macchiato: { label: "Catppuccin Macchiato", base: "#24273a", panel: "#1e2030", surface: "#363a4f", crust: "#181926", text: "#b7bdf8", bright: "#cad3f5", subtext: "#a5adcb", dim: "#6e738d",
                     mauve: "#c6a0f6", pink: "#f5bde6", peach: "#f5a97f", teal: "#8bd5ca", sky: "#91d7e3", green: "#a6da95", yellow: "#eed49f", red: "#ed8796", blue: "#8aadf4" },
        frappe:    { label: "Catppuccin Frappé",    base: "#303446", panel: "#292c3c", surface: "#414559", crust: "#232634", text: "#babbf1", bright: "#c6d0f5", subtext: "#a5adce", dim: "#737994",
                     mauve: "#ca9ee6", pink: "#f4b8e4", peach: "#ef9f76", teal: "#81c8be", sky: "#99d1db", green: "#a6d189", yellow: "#e5c890", red: "#e78284", blue: "#8caaee" },
        latte:     { label: "Catppuccin Latte (light)", base: "#eff1f5", panel: "#e6e9ef", surface: "#ccd0da", crust: "#eff1f5", text: "#4c4f69", bright: "#4c4f69", subtext: "#5c5f77", dim: "#8c8fa1",
                     mauve: "#8839ef", pink: "#ea76cb", peach: "#fe640b", teal: "#179299", sky: "#04a5e5", green: "#40a02b", yellow: "#df8e1d", red: "#d20f39", blue: "#1e66f5" },
        tokyo:     { label: "Tokyo Night",          base: "#1a1b26", panel: "#16161e", surface: "#292e42", crust: "#15161e", text: "#c0caf5", bright: "#c0caf5", subtext: "#a9b1d6", dim: "#565f89",
                     mauve: "#bb9af7", pink: "#ff9cc8", peach: "#ff9e64", teal: "#73daca", sky: "#7dcfff", green: "#9ece6a", yellow: "#e0af68", red: "#f7768e", blue: "#7aa2f7" },
        gruvbox:   { label: "Gruvbox Dark",         base: "#282828", panel: "#1d2021", surface: "#3c3836", crust: "#1d2021", text: "#ebdbb2", bright: "#fbf1c7", subtext: "#d5c4a1", dim: "#928374",
                     mauve: "#d3869b", pink: "#f2a6c0", peach: "#fe8019", teal: "#8ec07c", sky: "#7fb3b0", green: "#b8bb26", yellow: "#fabd2f", red: "#fb4934", blue: "#83a598" },
        nord:      { label: "Nord",                 base: "#2e3440", panel: "#272c36", surface: "#3b4252", crust: "#242933", text: "#d8dee9", bright: "#eceff4", subtext: "#c2c9d6", dim: "#616e88",
                     mauve: "#b48ead", pink: "#c895bf", peach: "#d08770", teal: "#8fbcbb", sky: "#88c0d0", green: "#a3be8c", yellow: "#ebcb8b", red: "#bf616a", blue: "#81a1c1" },
        rosepine:  { label: "Rosé Pine",            base: "#191724", panel: "#1f1d2e", surface: "#26233a", crust: "#12101c", text: "#e0def4", bright: "#e0def4", subtext: "#908caa", dim: "#6e6a86",
                     mauve: "#c4a7e7", pink: "#ebbcba", peach: "#f6c177", teal: "#9ccfd8", sky: "#a5d4de", green: "#a9d4a0", yellow: "#f6d58f", red: "#eb6f92", blue: "#6aa6d6" },
        dracula:   { label: "Dracula",              base: "#282a36", panel: "#21222c", surface: "#44475a", crust: "#191a21", text: "#f8f8f2", bright: "#f8f8f2", subtext: "#c0c4d6", dim: "#6272a4",
                     mauve: "#bd93f9", pink: "#ff79c6", peach: "#ffb86c", teal: "#7fe5c8", sky: "#8be9fd", green: "#50fa7b", yellow: "#f1fa8c", red: "#ff5555", blue: "#6d9bf7" }
    })
    property var custom: ({})
    readonly property var all: Object.assign({}, builtin, custom)
    readonly property var names: Object.keys(builtin).concat(Object.keys(custom).filter(n => !(n in builtin)))
    readonly property var p: Object.assign({}, builtin.mocha, all[name] || {})

    readonly property color base:    p.base
    readonly property color panel:   p.panel
    readonly property color surface: p.surface
    readonly property color crust:   p.crust
    readonly property color text:    p.text
    readonly property color bright:  p.bright
    readonly property color subtext: p.subtext
    readonly property color dim:     p.dim
    readonly property color mauve:   p.mauve
    readonly property color pink:    p.pink
    readonly property color peach:   p.peach
    readonly property color teal:    p.teal
    readonly property color sky:     p.sky
    readonly property color green:   p.green
    readonly property color yellow:  p.yellow
    readonly property color red:     p.red
    readonly property color blue:    p.blue
    // shared surfaces, all derived from the palette
    readonly property color card:         Qt.alpha(mauve, 0.06)
    readonly property color cardBorder:   Qt.alpha(mauve, 0.10)
    readonly property color sep:          Qt.alpha(mauve, 0.25)
    readonly property color islandBg:     Qt.alpha(surface, 0.92)
    readonly property color islandBorder: Qt.alpha(mauve, 0.15)
    // light themes need dark scrims/overlays and the other way round
    readonly property bool light: base.hslLightness > 0.6

    function setTheme(n) {
        if (!(n in all)) return false
        name = n
        stateFile.setText(JSON.stringify({ name: n }))
        return true
    }
    function next() { setTheme(names[(names.indexOf(name) + 1) % names.length]) }

    FileView {
        id: stateFile
        path: Quickshell.env("HOME") + "/.local/state/qs-bar-theme.json"
        onLoaded: { try { var n = JSON.parse(stateFile.text()).name; if (n) root.name = n } catch (e) {} }
    }
    FileView {
        path: Quickshell.env("HOME") + "/.config/qs-bar/themes.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.custom = JSON.parse(text()) } catch (e) { root.custom = ({}) } }
    }

    IpcHandler {
        target: "theme"
        function set(name: string): string { return root.setTheme(name) ? "ok" : "unknown theme; try: " + root.names.join(", ") }
        function next(): void { root.next() }
        function list(): string { return root.names.map(n => (n === root.name ? "* " : "  ") + n).join("\n") }
    }
}
