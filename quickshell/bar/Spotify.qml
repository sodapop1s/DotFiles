import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Spotify view of the hub. State that the bar itself needs (what is playing, position, prefs)
// lives in Bar.qml; everything about browsing and controlling Spotify lives here.
// Data and actions go through spotify.sh; audio is played by `spotify_player -d`.
Item {
    id: sp
    required property var bar

    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accentBg: Qt.alpha(Theme.green, 0.10)
    readonly property color accentBorder: Qt.alpha(Theme.green, 0.25)

    // ── State ─────────────────────────────────────────────
    property string tab: "playlists"        // playlists | search | liked | albums | queue | devices
    property var    page: null              // {kind, id, uri, name} while inside a playlist/album
    property string query: ""
    property var    playlists: []
    property var    albums: []
    property var    likedTracks: []
    property var    searchRes: ({ tracks: [], albums: [], artists: [], playlists: [] })
    property var    queueData: ({ current: null, queue: [] })
    property var    devices: []
    property var    pageTracks: []
    property bool   liked: false            // is the current track in Liked Songs
    property string status: ""
    property bool   statusErr: false

    function say(msg, err) { status = msg; statusErr = !!err; statusTimer.restart() }
    Timer { id: statusTimer; interval: 5000; onTriggered: sp.status = "" }

    // ── Jobs: run spotify.sh, hand the parsed JSON to a callback ──
    component SpJob: Process {
        id: job
        property var done: null
        stdout: StdioCollector {
            onStreamFinished: {
                var r = null
                try { r = JSON.parse(text) } catch(e) {}
                if (job.done) job.done(r)
            }
        }
        function go(args, cb) {
            if (running) return false
            done = cb
            command = ["bash", sp.bar.spScript].concat(args)
            running = true
            return true
        }
    }
    SpJob { id: listJob }
    SpJob { id: albumsJob }
    SpJob { id: likedJob }
    SpJob { id: searchJob }
    SpJob { id: pageJob }
    SpJob { id: queueJob }
    SpJob { id: devJob }
    SpJob { id: playJob }
    SpJob { id: ctlJob }
    SpJob { id: likeJob }
    SpJob { id: isLikedJob }

    // returns the result if it is usable, otherwise reports the problem and returns null
    function ok(r) {
        if (r === null || r === undefined) { say("no answer from Spotify helper", true); return null }
        if (r.error) { say(r.error, true); return null }
        return r
    }

    function load(what) {
        switch (what) {
        case "playlists": listJob.go(["playlists"],   r => { if (ok(r)) playlists = r }); break
        case "albums":    albumsJob.go(["albums"],    r => { if (ok(r)) albums = r }); break
        case "liked":     likedJob.go(["tracks", "liked"], r => { if (ok(r)) likedTracks = r }); break
        case "queue":     queueJob.go(["queue"],      r => { if (ok(r)) queueData = r }); break
        case "devices":   devJob.go(["devices"],      r => { if (ok(r)) devices = r }); break
        }
    }
    function reload() {
        if (page) openPage(page)
        else if (tab === "search") runSearch()
        else load(tab)
    }
    function activate() {
        load("playlists")
        if (tab !== "playlists" && tab !== "search") load(tab)
        checkLiked()
        input.forceActiveFocus()
    }
    function setQuery(t) { input.text = t }
    function setTab(t) {
        tab = t; page = null; input.text = ""; query = ""
        if (t !== "search") load(t)
        input.forceActiveFocus()
    }

    // ── Search (debounced) ────────────────────────────────
    Timer { id: searchTimer; interval: 350; onTriggered: sp.runSearch() }
    function runSearch() {
        if (query.trim().length === 0) { searchRes = { tracks: [], albums: [], artists: [], playlists: [] }; return }
        if (!searchJob.go(["search", query.trim()], r => { if (ok(r)) searchRes = r })) searchTimer.restart()
    }

    // ── Pages (a playlist's or album's tracks) ────────────
    function openPage(it) {
        page = it; pageTracks = []; input.text = ""; query = ""
        pageJob.go(["tracks", it.kind, it.id], r => { if (ok(r)) pageTracks = r })
    }
    function back() {
        if (page) { page = null; input.text = ""; query = "" }
        else bar.hubView = "main"
    }

    // ── Actions ───────────────────────────────────────────
    function remember(uri) {
        var prefs = Object.assign({}, bar.spPrefs)
        prefs.recents = Object.assign({}, prefs.recents || {})
        prefs.recents[uri] = Date.now()
        // keep the newest 30
        var keys = Object.keys(prefs.recents).sort((a, b) => prefs.recents[b] - prefs.recents[a])
        keys.slice(30).forEach(k => delete prefs.recents[k])
        bar.spPrefs = prefs
        bar.saveSpPrefs()
    }
    function afterPlay(name, r) {
        if (!ok(r)) return
        say("▶ " + name, false)
        bar.pollMedia()
    }
    function playCtx(it) {
        remember(it.uri)
        say("starting " + it.name + "…", false)
        playJob.go(["play", it.uri], r => afterPlay(it.name, r))
    }
    function playTrack(it) {
        say("starting " + it.name + "…", false)
        if (page) {
            playJob.go(["play", page.uri, it.uri], r => afterPlay(it.name, r))
        } else if (tab === "liked") {
            var i = likedTracks.findIndex(t => t.uri === it.uri)
            var uris = likedTracks.slice(Math.max(0, i), Math.max(0, i) + 100).map(t => t.uri)
            playJob.go(["play-uris", "0"].concat(uris), r => afterPlay(it.name, r))
        } else {
            playJob.go(["play", it.uri], r => afterPlay(it.name, r))
        }
    }
    function addQueue(it) {
        ctlJob.go(["control", "queue", it.uri], r => {
            if (!ok(r)) return
            say("+ queued " + it.name, false)
            if (tab === "queue") load("queue")
        })
    }
    function transfer(d) {
        ctlJob.go(["control", "transfer", d.id], r => {
            if (!ok(r)) return
            say("moved playback to " + d.name, false)
            load("devices"); bar.pollMedia()
        })
    }
    function activateItem(it) {
        switch (it.kind) {
        case "playlist": case "album": openPage(it); break
        case "artist": playCtx(it); break
        case "track":  playTrack(it); break
        case "device": transfer(it); break
        }
    }

    function setShuffle() {
        var on = !bar.mediaShuffle
        bar.mediaShuffle = on; bar.ctlHoldUntil = Date.now() + 3000
        ctlJob.go(["control", "shuffle", on ? "on" : "off"], r => { ok(r) })
    }
    function cycleRepeat() {
        var next = bar.mediaRepeat === "off" ? "context" : (bar.mediaRepeat === "context" ? "track" : "off")
        bar.mediaRepeat = next; bar.ctlHoldUntil = Date.now() + 3000
        ctlJob.go(["control", "repeat", next], r => { ok(r) })
    }
    function setVolume(v) {
        v = Math.max(0, Math.min(100, Math.round(v)))
        bar.mediaVolume = v; bar.ctlHoldUntil = Date.now() + 3000
        ctlJob.go(["control", "volume", String(v)], r => { ok(r) })
    }
    function checkLiked() {
        if (!bar.spActive || !bar.mediaTrackId) { liked = false; return }
        isLikedJob.go(["control", "liked", bar.mediaTrackId], r => { liked = (r === true) })
    }
    function toggleLike() {
        var id = bar.mediaTrackId
        if (!id) return
        var want = !liked
        liked = want
        likeJob.go(["control", want ? "like" : "unlike", id], r => {
            if (!ok(r)) { liked = !want; return }
            say(want ? "♥ added to Liked Songs" : "removed from Liked Songs", false)
            likedTracks = []              // refetched the next time Liked is opened
            if (tab === "liked") load("liked")
        })
    }
    Connections {
        target: bar
        function onMediaTrackIdChanged() { if (sp.visible) sp.checkLiked() }
    }

    // ── The list shown in the main area ───────────────────
    function lc(s) { return (s || "").toLowerCase() }
    function match(it, q) { return !q || lc(it.name).includes(q) || lc(it.sub).includes(q) }

    readonly property var items: {
        var q = lc(query), out = []
        if (page) return pageTracks.filter(t => match(t, q))

        if (tab === "playlists") {
            var rec = bar.spPrefs.recents || {}
            var all = playlists.filter(p => match(p, q))
            var recent = all.filter(p => rec[p.uri]).sort((a, b) => rec[b.uri] - rec[a.uri]).slice(0, 3)
                             .map(p => Object.assign({}, p, { sub: "󰋚  " + p.sub }))
            var recentUris = recent.map(p => p.uri)
            return recent.concat(all.filter(p => recentUris.indexOf(p.uri) < 0))
        }
        if (tab === "search") {
            var r = searchRes
            var sec = (title, arr) => { if (arr && arr.length) { out.push({ kind: "header", name: title }); arr.forEach(x => out.push(x)) } }
            sec("Songs", r.tracks); sec("Albums", r.albums); sec("Artists", r.artists); sec("Playlists", r.playlists)
            return out
        }
        if (tab === "liked")  return likedTracks.filter(t => match(t, q))
        if (tab === "albums") return albums.filter(a => match(a, q))
        if (tab === "queue") {
            if (queueData.current) { out.push({ kind: "header", name: "Now playing" }); out.push(Object.assign({}, queueData.current, { now: true })) }
            if (queueData.queue && queueData.queue.length) { out.push({ kind: "header", name: "Up next" }); queueData.queue.forEach(x => out.push(x)) }
            return out
        }
        if (tab === "devices") {
            return devices.map(d => ({
                kind: "device", id: d.id, name: d.name, now: d.is_active, image: "", uri: d.id,
                sub: d.type + (d.is_active ? "  ·  active" : "") + (d.volume_percent !== null && d.volume_percent !== undefined ? "  ·  " + d.volume_percent + "%" : "")
            }))
        }
        return out
    }
    readonly property bool busy: listJob.running || albumsJob.running || likedJob.running || searchJob.running
                                 || pageJob.running || queueJob.running || devJob.running

    // ══ UI ═══════════════════════════════════════════════
    // header
    RowLayout {
        id: nav
        anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 }
        height: 40; spacing: 8
        Text {
            text: "󰁍"; color: Theme.dim; font { family: sp.font; pixelSize: 16 }
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: sp.back() }
        }
        Text { text: "󰓇 Spotify"; color: Theme.green; font { family: sp.font; pixelSize: 14; bold: true } }
        Item { Layout.fillWidth: true }
        Text {
            visible: sp.status.length > 0
            text: sp.status
            color: sp.statusErr ? Theme.red : Theme.green
            elide: Text.ElideRight; Layout.maximumWidth: 250
            font { family: sp.font; pixelSize: 11 }
        }
        Text {
            text: (bar.spPrefs.notify ? "󰂚 alerts on" : "󰂛 alerts off")
            color: bar.spPrefs.notify ? Theme.mauve : Theme.dim
            font { family: sp.font; pixelSize: 10 }
            MouseArea {
                anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                onClicked: { var p = Object.assign({}, bar.spPrefs); p.notify = !p.notify; bar.spPrefs = p; bar.saveSpPrefs() }
            }
        }
        Text {
            text: sp.busy ? "loading…" : "refresh"
            color: Theme.dim; font { family: sp.font; pixelSize: 11 }
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: sp.reload() }
        }
    }
    Rectangle { id: sep; anchors { top: nav.bottom; left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 } height: 1; color: Theme.sep }

    // now playing
    Rectangle {
        id: now
        visible: bar.mediaTitle.length > 0 && bar.mediaStatus !== "Stopped"
        anchors { top: sep.bottom; topMargin: 8; left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 }
        height: visible ? (bar.spActive ? 106 : 70) : 0
        radius: 8
        color: sp.accentBg
        border { color: sp.accentBorder; width: 1 }

        ColumnLayout {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12; topMargin: 6; bottomMargin: 6 }
            spacing: 2

            RowLayout {
                Layout.fillWidth: true; spacing: 12
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 0
                    Text { text: bar.mediaTitle; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true
                           font { family: sp.font; pixelSize: 12; bold: true } textFormat: Text.PlainText }
                    Text { visible: bar.mediaArtist.length > 0; text: bar.mediaArtist; color: Theme.dim; elide: Text.ElideRight; Layout.fillWidth: true
                           font { family: sp.font; pixelSize: 10 } textFormat: Text.PlainText }
                }
                Text { text: "󰒮"; color: Theme.text; font { family: sp.font; pixelSize: 18 }
                       MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: bar.mediaPrev() } }
                Text { text: bar.mediaStatus === "Playing" ? "󰏤" : "󰐊"; color: Theme.green; font { family: sp.font; pixelSize: 22 }
                       MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: bar.mediaPlayPause() } }
                Text { text: "󰒭"; color: Theme.text; font { family: sp.font; pixelSize: 18 }
                       MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: bar.mediaNext() } }
            }

            // progress / seek
            RowLayout {
                Layout.fillWidth: true; Layout.preferredHeight: 16; spacing: 8
                Text {
                    text: bar.fmtTime(seekArea.pressed ? seekArea.previewMs : bar.mediaNowMs(bar.mediaTick))
                    color: Theme.dim; font { family: sp.font; pixelSize: 10 }
                    Layout.preferredWidth: 34
                }
                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Rectangle {
                        id: seekTrack
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                        height: seekArea.containsMouse || seekArea.pressed ? 6 : 4; radius: 3
                        color: Qt.alpha(Theme.green, 0.18)
                        Behavior on height { NumberAnimation { duration: 100 } }
                        Rectangle {
                            width: bar.mediaLenMs > 0 ? parent.width * Math.min(1, (seekArea.pressed ? seekArea.previewMs : bar.mediaNowMs(bar.mediaTick)) / bar.mediaLenMs) : 0
                            height: parent.height; radius: parent.radius; color: Theme.green
                        }
                    }
                    Rectangle {
                        visible: seekArea.containsMouse || seekArea.pressed
                        width: 12; height: 12; radius: 6; color: Theme.green
                        anchors.verticalCenter: seekTrack.verticalCenter
                        x: bar.mediaLenMs > 0 ? Math.max(0, Math.min(seekTrack.width - width, seekTrack.width * ((seekArea.pressed ? seekArea.previewMs : bar.mediaNowMs(bar.mediaTick)) / bar.mediaLenMs) - width / 2)) : 0
                    }
                    MouseArea {
                        id: seekArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: bar.mediaLenMs > 0
                        cursorShape: Qt.PointingHandCursor
                        property real previewMs: 0
                        function msAt(x) { return Math.max(0, Math.min(1, x / width)) * bar.mediaLenMs }
                        onPressed: mouse => previewMs = msAt(mouse.x)
                        onPositionChanged: mouse => { if (pressed) previewMs = msAt(mouse.x) }
                        onReleased: mouse => bar.seekTo(msAt(mouse.x))
                    }
                }
                Text {
                    text: bar.mediaLenMs > 0 ? bar.fmtTime(bar.mediaLenMs) : "--:--"
                    color: Theme.dim; font { family: sp.font; pixelSize: 10 }
                    Layout.preferredWidth: 34; horizontalAlignment: Text.AlignRight
                }
            }

            // shuffle / repeat / like / device / volume (only when Spotify itself is the player)
            RowLayout {
                visible: bar.spActive
                Layout.fillWidth: true; Layout.preferredHeight: 22; spacing: 14
                Text {
                    text: "󰒟"; color: bar.mediaShuffle ? Theme.green : Theme.dim; font { family: sp.font; pixelSize: 16 }
                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: sp.setShuffle() }
                }
                Text {
                    text: bar.mediaRepeat === "track" ? "󰑘" : "󰑖"
                    color: bar.mediaRepeat === "off" ? Theme.dim : Theme.green; font { family: sp.font; pixelSize: 16 }
                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: sp.cycleRepeat() }
                }
                Text {
                    text: sp.liked ? "󰋑" : "󰋕"; color: sp.liked ? Theme.pink : Theme.dim; font { family: sp.font; pixelSize: 16 }
                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: sp.toggleLike() }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "󰓃 " + bar.mediaDevice; color: Theme.dim; elide: Text.ElideRight; Layout.maximumWidth: 110
                    font { family: sp.font; pixelSize: 10 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sp.setTab("devices") }
                }
                Text { text: bar.mediaVolume === 0 ? "󰝟" : "󰕾"; color: Theme.teal; font { family: sp.font; pixelSize: 14 } }
                Item {
                    Layout.preferredWidth: 90; Layout.fillHeight: true
                    Rectangle {
                        id: volTrack
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                        height: 4; radius: 2; color: Qt.alpha(Theme.teal, 0.18)
                        Rectangle { width: parent.width * (volArea.pressed ? volArea.preview : bar.mediaVolume) / 100; height: parent.height; radius: 2; color: Theme.teal }
                    }
                    Rectangle {
                        width: 10; height: 10; radius: 5; color: Theme.teal
                        anchors.verticalCenter: volTrack.verticalCenter
                        x: Math.max(0, Math.min(volTrack.width - width, volTrack.width * (volArea.pressed ? volArea.preview : bar.mediaVolume) / 100 - width / 2))
                    }
                    MouseArea {
                        id: volArea
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        property real preview: 0
                        function at(x) { return Math.max(0, Math.min(100, x / width * 100)) }
                        onPressed: mouse => preview = at(mouse.x)
                        onPositionChanged: mouse => { if (pressed) preview = at(mouse.x) }
                        onReleased: mouse => sp.setVolume(at(mouse.x))
                    }
                }
                Text { text: Math.round(volArea.pressed ? volArea.preview : bar.mediaVolume) + "%"; color: Theme.dim
                       font { family: sp.font; pixelSize: 10 }
                       Layout.preferredWidth: 28; horizontalAlignment: Text.AlignRight }
            }
        }
    }

    // tabs (hidden while inside a playlist/album)
    RowLayout {
        id: tabs
        visible: sp.page === null
        anchors { top: now.visible ? now.bottom : sep.bottom; topMargin: 8; left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 }
        height: visible ? 24 : 0
        spacing: 4
        Repeater {
            model: [["playlists", "Playlists"], ["search", "Search"], ["liked", "Liked"], ["albums", "Albums"], ["queue", "Queue"], ["devices", "Devices"]]
            delegate: Rectangle {
                id: tabBtn
                required property var modelData
                Layout.fillWidth: true; Layout.preferredHeight: 24; radius: 6
                color: sp.tab === modelData[0] ? sp.accentBg : "transparent"
                border { color: sp.tab === modelData[0] ? sp.accentBorder : "transparent"; width: 1 }
                Text {
                    anchors.centerIn: parent
                    text: tabBtn.modelData[1]
                    color: sp.tab === tabBtn.modelData[0] ? Theme.green : Theme.dim
                    font { family: sp.font; pixelSize: 11 }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sp.setTab(tabBtn.modelData[0]) }
            }
        }
    }

    // page title (inside a playlist/album)
    RowLayout {
        id: pageBar
        visible: sp.page !== null
        anchors { top: now.visible ? now.bottom : sep.bottom; topMargin: 8; left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 }
        height: visible ? 24 : 0
        spacing: 8
        Text { text: sp.page ? sp.page.name : ""; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true
               font { family: sp.font; pixelSize: 12; bold: true } textFormat: Text.PlainText }
        Rectangle {
            Layout.preferredHeight: 22; Layout.preferredWidth: playAll.implicitWidth + 20; radius: 6
            color: sp.accentBg; border { color: sp.accentBorder; width: 1 }
            Text { id: playAll; anchors.centerIn: parent; text: "󰐊 Play"; color: Theme.green; font { family: sp.font; pixelSize: 11 } }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (sp.page) sp.playCtx(sp.page) } }
        }
    }

    // filter / search box
    Rectangle {
        id: box
        visible: sp.page !== null || ["playlists", "search", "liked", "albums"].indexOf(sp.tab) >= 0
        anchors { top: sp.page ? pageBar.bottom : tabs.bottom; topMargin: 6; left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12 }
        height: visible ? 32 : 0
        radius: 8
        color: Qt.alpha(Theme.mauve, 0.07)
        border { color: input.activeFocus ? Qt.alpha(Theme.green, 0.45) : Theme.sep; width: 1 }
        RowLayout {
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            spacing: 8
            Text { text: sp.tab === "search" && !sp.page ? "󰍉" : "󰈲"; color: input.activeFocus ? Theme.green : Theme.dim; font { family: sp.font; pixelSize: 12 } }
            TextInput {
                id: input
                Layout.fillWidth: true
                color: Theme.text
                font { family: sp.font; pixelSize: 12 }
                clip: true
                onTextChanged: {
                    sp.query = text
                    if (sp.tab === "search" && !sp.page) searchTimer.restart()
                }
                Keys.onEscapePressed: {
                    if (text.length > 0) text = ""
                    else if (sp.page) sp.back()
                    else bar.hubOpen = false
                }
                Keys.onReturnPressed: { if (sp.tab === "search" && !sp.page) { searchTimer.stop(); sp.runSearch() } }
                Text {
                    visible: input.text.length === 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: sp.page ? "filter tracks…" : (sp.tab === "search" ? "search songs, albums, artists, playlists…" : "filter…")
                    color: Theme.dim; font { family: sp.font; pixelSize: 11 }
                }
            }
            Text {
                visible: input.text.length > 0
                text: "✕"; color: Theme.dim; font { family: sp.font; pixelSize: 11 }
                MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: input.text = "" }
            }
        }
    }

    // results
    ListView {
        id: list
        anchors {
            top: box.visible ? box.bottom : (sp.page ? pageBar.bottom : tabs.bottom); topMargin: 8
            left: parent.left; right: parent.right; bottom: parent.bottom
            leftMargin: 12; rightMargin: 12; bottomMargin: 10
        }
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        model: sp.items

        delegate: Rectangle {
            id: row
            required property var modelData
            readonly property string kind: modelData.kind
            readonly property bool isHeader: kind === "header"
            readonly property bool isTrack: kind === "track"
            width: list.width
            height: isHeader ? 26 : 46
            radius: 8
            color: !isHeader && hh.hovered ? sp.accentBg : (modelData.now ? Qt.alpha(Theme.green, 0.06) : "transparent")

            HoverHandler { id: hh; cursorShape: row.isHeader ? Qt.ArrowCursor : Qt.PointingHandCursor }

            Text {
                visible: row.isHeader
                anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                text: (row.modelData.name || "").toUpperCase(); color: Theme.dim
                font { family: sp.font; pixelSize: 10; bold: true; letterSpacing: 1 }
            }

            MouseArea {
                anchors.fill: parent
                enabled: !row.isHeader
                onClicked: sp.activateItem(row.modelData)
            }

            RowLayout {
                visible: !row.isHeader
                anchors { fill: parent; leftMargin: 6; rightMargin: 10 }
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 34; Layout.preferredHeight: 34
                    radius: row.kind === "artist" ? 17 : 6; clip: true
                    color: Qt.alpha(Theme.mauve, 0.10)
                    Image {
                        id: img
                        anchors.fill: parent
                        asynchronous: true
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(68, 68)
                        source: row.modelData.image || ""
                        visible: status === Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: img.status !== Image.Ready
                        text: row.kind === "device" ? "󰓃" : (row.kind === "artist" ? "󰠃" : "󰎆")
                        color: row.modelData.now ? Theme.green : Theme.dim
                        font { family: sp.font; pixelSize: 14 }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 0
                    Text {
                        text: row.modelData.name || ""; color: row.modelData.now ? Theme.green : Theme.text
                        elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText
                        font { family: sp.font; pixelSize: 12 }
                    }
                    Text {
                        text: row.modelData.sub || ""; color: Theme.dim
                        elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText
                        font { family: sp.font; pixelSize: 10 }
                    }
                }
                Text {
                    visible: row.isTrack && !hh.hovered && (row.modelData.dur || 0) > 0
                    text: bar.fmtTime(row.modelData.dur || 0); color: Theme.dim
                    font { family: sp.font; pixelSize: 10 }
                }
                // hover actions
                Text {
                    visible: hh.hovered && row.isTrack
                    text: "󰐕"; color: Theme.text; font { family: sp.font; pixelSize: 16 }
                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: sp.addQueue(row.modelData) }
                }
                Text {
                    visible: hh.hovered && (row.isTrack || row.kind === "playlist" || row.kind === "album" || row.kind === "artist")
                    text: "󰐊"; color: Theme.green; font { family: sp.font; pixelSize: 17 }
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor
                        onClicked: { if (row.isTrack) sp.playTrack(row.modelData); else sp.playCtx(row.modelData) }
                    }
                }
            }
        }

        Text {
            visible: list.count === 0
            anchors.centerIn: parent
            text: sp.busy ? "loading…"
                : (sp.tab === "search" && !sp.page && sp.query.trim().length === 0) ? "type to search Spotify"
                : "nothing here"
            color: Theme.dim; font { family: sp.font; pixelSize: 12 }
        }
    }
}
