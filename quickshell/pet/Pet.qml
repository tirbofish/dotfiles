import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import "../lib" as Lib
import "physics.js" as Phys

// Clawd lives on one monitor, above your windows. Window tops are platforms:
// it walks on them, hops between them, rides along when you move them and
// falls when you close them. Drag to pick it up and fling it; click to make
// it happy; double-click to put it to bed; right-click and it follows you.
PanelWindow {
    id: pet

    property bool shown: true
    visible: shown
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: -1
    aboveWindows: true
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "desktop-pet"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { left: true; top: true; right: true; bottom: true }
    mask: Region { item: mochi }

    Lib.ThemeEngine { id: theme }

    // Bring it to the monitor you're on (or hide it if it's already here).
    function focusedScreen() {
        var s = Quickshell.screens
        for (var i = 0; i < s.length; i++)
            if (Hyprland.focusedMonitor && s[i].name === Hyprland.focusedMonitor.name) return s[i]
        return s.length ? s[0] : null
    }
    function summon() {
        var focused = focusedScreen()
        if (pet.shown && focused && focused !== pet.screen) { pet.screen = focused; drop(); return }
        pet.shown = !pet.shown
        if (pet.shown) drop()
    }
    function drop() {
        px = (pet.screen ? pet.screen.width : width) / 2; py = mochi.height;   // from the top: lands on the first window below vx = 0; vy = 0; mode = "air"; on = ""
        say("hi!", 1800)
        doEmote("wave", 1800)
        refresh()
    }

    // ── world ───────────────────────────────────────────────────────────
    readonly property real halfW: mochi.width / 2
    property var mon: ({ id: -1, x: 0, y: 0, width: 1440, top: 0, workspace: 0 })
    property real floorY: height
    property var plats: []            // filled from Hyprland; empty until then
    property real cursorX: -1
    property real cursorY: -1
    property double cursorSeen: 0
    property real lookAtX: -1
    property real lookAtY: -1
    property double lookUntil: 0

    function platform(id) {
        for (var i = 0; i < plats.length; i++) if (plats[i].id === id) return plats[i]
        return null
    }

    function refresh() { if (!world.running) world.running = true; else world.again = true }
    Process {
        id: world
        property bool again: false
        command: ["sh", "-c", "hyprctl -j monitors; echo @@; hyprctl -j clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parts = text.split("@@")
                    var m = JSON.parse(parts[0]).find(m => m.name === (pet.screen ? pet.screen.name : ""))
                    if (!m) return
                    var r = m.reserved || [0, 0, 0, 0]
                    pet.mon = { id: m.id, x: m.x, y: m.y, width: pet.width, top: r[1], workspace: m.activeWorkspace.id }
                    pet.floorY = pet.height - r[3]
                    // Any window top with room for the body counts, even under the bar.
                    var next = Phys.platforms(JSON.parse(parts[1]), Object.assign({}, pet.mon, { top: 0 }), pet.floorY, mochi.height)
                    // Ride along with a window that moved under us.
                    var old = pet.platform(pet.on), now = null
                    for (var i = 0; i < next.length; i++) if (next[i].id === pet.on) now = next[i]
                    pet.plats = next
                    var focus = JSON.parse(parts[1]).find(c => c.focusHistoryID === 0)
                    pet.activeClass = focus ? String(focus.class || "") : ""
                    if (pet.mode === "ground" && old && now && (old.x !== now.x || old.y !== now.y)) {
                        pet.px += now.x - old.x
                        pet.py = now.y
                    }
                    if (pet.wantWindow) {
                        var target = pet.platform(pet.wantWindow)
                        pet.wantWindow = ""
                        if (target && pet.mode === "ground" && Math.random() < 0.25) pet.hopOnto(target)
                    }
                } catch (e) { console.warn("[pet] world refresh:", e) }
            }
        }
        onExited: if (again) { again = false; running = true }
    }
    Timer { interval: 1200; running: pet.visible; repeat: true; onTriggered: pet.refresh() }

    Process {
        id: cursor
        command: ["hyprctl", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = text.split(",").map(Number)
                if (p.length !== 2 || isNaN(p[0])) return
                var x = p[0] - pet.mon.x, y = p[1] - pet.mon.y
                if (x !== pet.cursorX || y !== pet.cursorY) pet.cursorSeen = Date.now()
                pet.cursorX = x
                pet.cursorY = y
            }
        }
    }
    Timer {
        interval: 350
        running: pet.visible && pet.act !== "sleep"
        repeat: true
        onTriggered: if (!cursor.running) cursor.running = true
    }

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            var n = ev.name, addr = "0x" + String(ev.data || "").split(",")[0]
            if (n === "openwindow") {
                if (pet.act === "sleep" && Math.random() < 0.7) return
                pet.wake()
                pet.feel("surprised", 700)
                pet.say("!", 900)
                if (pet.mode === "ground") pet.vy = -380, pet.mode = "air"
                pet.wantWindow = addr
            } else if (n === "closewindow" && addr === pet.on) {
                pet.wake()
                pet.feel("surprised", 1200)
                pet.say("!!", 1000)
            } else if (n === "activewindowv2") {
                var p = pet.platform(addr)
                if (p) { pet.lookAtX = p.x + p.w / 2; pet.lookAtY = p.y; pet.lookUntil = Date.now() + 1500 }
            }
            if (["openwindow", "closewindow", "movewindowv2", "workspacev2", "changefloatingmode",
                 "fullscreen", "activewindowv2", "focusedmonv2"].indexOf(n) >= 0)
                refreshSoon.restart()
        }
    }
    Timer { id: refreshSoon; interval: 60; onTriggered: pet.refresh() }

    // ── coding agents ───────────────────────────────────────────────────
    // Claude Code / Codex hooks and the opencode plugin call bin/clawd-agent,
    // which writes "<agent>\t<work|ask|done|off>\t<project>" here.
    readonly property string agentPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/clawd-agent"
    property string agentState: ""
    property string agentName: ""
    property string agentProject: ""
    property double agentSeen: 0
    function onAgent(line) {
        var f = line.trim().split("\t")
        if (f.length < 2) return
        var was = agentState
        agentName = f[0]; agentState = f[1] === "off" ? "" : f[1]; agentProject = f[2] || ""; agentSeen = Date.now()
        if (agentState === was && agentState !== "ask") return
        if (bubbleUntil > Date.now() + 60000) bubble = ""      // drop a lingering "needs you"
        if (agentState === "work") { wake(); doEmote("think", 5000) }
        else if (agentState === "ask") {
            wake(); feel("surprised", 1500); say(agentName + " needs you!", 600000); doEmote("wave", 2500)
            if (mode === "ground") vy = -420, mode = "air"
        } else if (agentState === "done") {
            if (act === "sleep") return
            emote = ""; feel("happy", 2500); say("done ✻", 2500); doEmote("wave", 1600)
        }
    }
    // Create the file first so the watch has something to hold on to.
    Process {
        running: true
        command: ["touch", pet.agentPath]
        onExited: agentFile.path = pet.agentPath
    }
    FileView {
        id: agentFile
        property bool primed: false                   // ignore whatever was there at startup
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { if (primed) pet.onAgent(text()); primed = true }
    }

    // ── body state ──────────────────────────────────────────────────────
    property real px: width / 2       // feet, centre
    property real py: 0
    property real vx: 0
    property real vy: 0
    property string mode: "air"       // ground | air | drag
    property string on: ""            // platform id underfoot
    property string act: "idle"       // idle | walk | sit | sleep | follow
    property double actUntil: 0
    property int dir: 1
    property bool following: false
    property double lastPet: Date.now()
    property double awakeSince: Date.now()
    property string wantWindow: ""
    property string mood: "normal"
    property double moodUntil: 0
    property string bubble: ""
    property double bubbleUntil: 0
    // Emotes, borrowed from Claude Code's own UI: the ✻ thinking spinner with
    // its whimsical verbs, a wave, a sparkle.
    property string emote: ""
    property double emoteUntil: 0
    // Animated scenes (emotes/*.gif, from xixicc186/clawd-emotes-skill, MIT),
    // picked from what you're up to.
    property string gif: ""
    property double gifUntil: 0
    property string activeClass: ""
    readonly property bool musicPlaying: Mpris.players.values.some(p => p && p.isPlaying)
    function pickGif() {
        var d = new Date(), m = d.getMonth() + 1, day = d.getDate(), h = d.getHours()
        var fest = m === 12 && day >= 24 && day <= 26 ? "christmas" : m === 10 && day === 31 ? "halloween"
            : m === 1 && day === 1 ? "new-year" : m === 2 && day === 14 ? "valentine" : ""
        var cls = activeClass.toLowerCase()
        var opts = []
        if (fest) opts.push(fest, fest, fest)
        if (agentState === "work") opts.push("coding", "coding", "coding", "coding")
        if (musicPlaying) opts.push("listening", "listening", "singing")
        if (/code|cursor|zed|nvim|neovide|kitty|alacritty|foot|wezterm|ghostty|jetbrains/.test(cls)) opts.push("coding", "coding")
        if (/steam|lutris|minecraft|heroic|gamescope|prism/.test(cls)) opts.push("gaming", "gaming")
        if (/obsidian|zathura|okular|evince|calibre|foliate|papers/.test(cls)) opts.push("reading", "reading")
        if (/gimp|krita|inkscape|aseprite|blender|pinta/.test(cls)) opts.push("painting", "painting")
        if (h >= 6 && h < 11) opts.push("coffee", "coffee")
        if ((h >= 12 && h < 14) || (h >= 18 && h < 20)) opts.push("eating")
        opts.push("guitar", "watering", "exercise", "photo")
        return opts[Math.floor(Math.random() * opts.length)]
    }
    property double lastWave: 0
    property int spin: 0
    property string verb: ""
    readonly property var spinner: ["·", "✢", "✳", "✶", "✻", "✽", "✻", "✶", "✳", "✢"]
    readonly property var verbs: ["Pondering…", "Noodling…", "Percolating…", "Musing…", "Cogitating…",
        "Ruminating…", "Simmering…", "Brewing…", "Tinkering…", "Mulling…", "Scheming…", "Vibing…"]
    function doEmote(e, ms) {
        if (act === "sleep" || mode === "drag") return
        emote = e; emoteUntil = Date.now() + ms
        if (e === "think") verb = verbs[Math.floor(Math.random() * verbs.length)]
        if (e === "wave") lastWave = Date.now()
    }
    Timer {
        interval: 110
        running: pet.emote === "think"
        repeat: true
        onTriggered: pet.spin = (pet.spin + 1) % pet.spinner.length
    }

    readonly property bool moving: mode !== "ground" || act === "walk" || act === "follow" || squashAnim.running

    function feel(m, ms) { mood = m; moodUntil = Date.now() + ms }
    function say(t, ms) { bubble = t; bubbleUntil = Date.now() + ms }
    function wake() {
        if (act !== "sleep") return
        awakeSince = Date.now()
        act = "idle"; actUntil = Date.now() + 800
        mood = "normal"; bubble = ""
    }

    function land(p, impact) {
        mode = "ground"; on = p.id; py = p.y; vx = 0; vy = 0
        mochi.squash = impact > 1500 ? 0.62 : impact > 700 ? 0.8 : 0.92
        squashAnim.restart()
        if (impact > 1900) { feel("dizzy", 1600); say("✦", 1400) }
        act = "idle"; actUntil = Date.now() + 500 + Math.random() * 700
    }
    function fall(push) {
        mode = "air"; on = ""; vy = 0; vx = push
    }
    function hopOnto(p) {
        var tx = Math.max(p.x + 14, Math.min(p.x + p.w - 14, p.x + Math.random() * p.w))
        var v = Phys.jumpTo(px, py, tx, p.y, 50 + Math.random() * 40)
        vx = v.vx; vy = v.vy; mode = "air"; on = ""
        dir = vx >= 0 ? 1 : -1
    }

    function choose() {
        var now = Date.now()
        var hour = new Date().getHours()
        // Naps have to be earned: a good stretch awake first, then only a
        // modest chance per decision (higher at night or when ignored).
        var night = hour >= 23 || hour < 6
        var lonely = now - lastPet > 180000
        var rested = now - awakeSince < (night ? 360000 : 720000)
        var sleepy = rested ? 0 : night ? 0.2 : lonely ? 0.1 : 0.03
        var r = Math.random()
        if (following) { act = "follow"; actUntil = now + 1000; return }
        if (r < sleepy) { act = "sleep"; mood = "sleep"; actUntil = now + 120000 + Math.random() * 240000; return }
        // Mostly it just sits (perched, if it's on a window). Now and then it wanders or hops.
        r = Math.random()
        if (r < 0.55) {
            act = "sit"; actUntil = now + 8000 + Math.random() * 22000
            if (Math.random() < 0.5) { gif = pickGif(); gifUntil = now + 7000 + Math.random() * 9000 }
        }
        else if (r < 0.8) {
            act = "idle"; actUntil = now + 4000 + Math.random() * 8000
            var e = Math.random()
            if (e < 0.35) doEmote("think", 2500 + Math.random() * 3500)
            else if (e < 0.45) doEmote("wave", 1400)
        }
        else if (r < 0.94) { act = "walk"; dir = Math.random() < 0.5 ? -1 : 1; actUntil = now + 1000 + Math.random() * 2000 }
        else {
            // Hop to another window top within reach.
            // Hop somewhere to perch: any window top within sideways reach, floor as a last resort.
            var reach = plats.filter(p => p.id !== on && p.id !== "floor" && Math.abs(p.x + p.w / 2 - px) < 800)
            if (!reach.length && on !== "floor") reach = plats.filter(p => p.id === "floor")
            if (reach.length) hopOnto(reach[Math.floor(Math.random() * reach.length)])
            else { act = "walk"; dir = -dir; actUntil = now + 2000 }
        }
    }

    function step(dt) {
        dt = Math.min(dt, 0.04)
        if (!plats.length) return         // don't know the world yet
        if (mode === "drag") return
        if (mode === "air") {
            var prevY = py
            vy += Phys.G * dt
            px += vx * dt
            py += vy * dt
            if (px < halfW) { px = halfW; vx = Math.abs(vx) * 0.55 }
            if (px > width - halfW) { px = width - halfW; vx = -Math.abs(vx) * 0.55 }
            if (py - mochi.height < 0) { py = mochi.height; vy = Math.abs(vy) * 0.3 }
            if (vy > 0) {
                var p = Phys.landing(prevY, py, px, plats, halfW)
                if (p) land(p, vy)
                else if (py > height + 200) { px = width / 2; py = mon.top + 60; vx = 0; vy = 0 }
            }
            return
        }
        var g = platform(on)
        if (!g || !Phys.over(g, px, halfW)) { fall(dir * 60); return }
        py = g.y
        if (act === "follow" && cursorX >= 0) {
            var dx = cursorX - px
            if (Math.abs(dx) > 24) dir = dx > 0 ? 1 : -1
            // Cursor is on a higher window: jump for it.
            if (cursorY < py - 80 && Math.abs(dx) < 260) {
                var up = Phys.landing(-1, cursorY + 30, cursorX, plats.filter(p => p.y < py - 40 && p.y > cursorY), halfW)
                if (up) { hopOnto(up); return }
            }
            if (Math.abs(dx) <= 24) return
        }
        if (act === "walk" || act === "follow") {
            var speed = act === "follow" ? 150 : 50
            px += dir * speed * dt
            var left = g.x + 6, right = g.x + g.w - 6
            if (px < left || px > right) {
                if (g.id !== "floor" && Math.random() < 0.35) { fall(dir * 110); vy = -260 }
                else { px = Math.max(left, Math.min(right, px)); dir = -dir }
            }
            if (px < halfW) { px = halfW; dir = 1 }
            if (px > width - halfW) { px = width - halfW; dir = -1 }
        }
    }

    FrameAnimation {
        running: pet.visible && pet.moving
        onTriggered: pet.step(frameTime)
    }
    // Slow brain: decisions, moods, support checks while standing still.
    Timer {
        interval: 250
        running: pet.visible
        repeat: true
        onTriggered: {
            var now = Date.now()
            if (pet.mood !== "normal" && pet.mood !== "sleep" && now > pet.moodUntil) pet.mood = "normal"
            if (pet.bubble && now > pet.bubbleUntil) pet.bubble = ""
            if (pet.emote && (now > pet.emoteUntil || pet.act === "sleep" || pet.mode === "drag")) pet.emote = ""
            if (pet.gif && (now > pet.gifUntil || pet.mode !== "ground" || pet.act !== "sit")) pet.gif = ""
            if (pet.mode === "ground" && !pet.moving) pet.step(0)
            if (pet.mode === "ground" && now > pet.actUntil && pet.act !== "sleep") pet.choose()
            if (pet.act === "sleep" && now > pet.actUntil) pet.wake()
            // Keep thinking while an agent works; give up if it went quiet (killed mid-turn).
            if (pet.agentState === "work" && now - pet.agentSeen > 300000) pet.agentState = ""
            if (pet.agentState === "work" && !pet.emote && !pet.gif) pet.doEmote("think", 5000)
        }
    }
    Component.onCompleted: {
        var s = focusedScreen()
        if (s) pet.screen = s
        py = mon.top + 60
        refresh()
    }

    // ── the pet ─────────────────────────────────────────────────────────
    Clawd {
        id: mochi
        x: pet.px - width / 2
        y: pet.py - height
        mood: pet.act === "sleep" ? "sleep" : pet.mood === "normal" && mouse.containsMouse ? "love" : pet.mood
        walking: pet.mode === "ground" && (pet.act === "walk" || pet.act === "follow")
        dangling: pet.mode === "drag"
        grounded: pet.mode === "ground"
        perched: pet.mode === "ground" && pet.on !== "floor" && pet.on !== ""
            && pet.act !== "walk" && pet.act !== "follow"
        hovered: mouse.containsMouse
        emote: pet.emote
        gif: pet.act === "sleep" && pet.mode === "ground" ? "sleeping" : pet.gif
        squash: 1
        readonly property real tx: Date.now() < pet.lookUntil ? pet.lookAtX
            : pet.cursorX >= 0 && Date.now() - pet.cursorSeen < 4000 ? pet.cursorX : pet.px + pet.dir * 100
        readonly property real ty: Date.now() < pet.lookUntil ? pet.lookAtY
            : pet.cursorX >= 0 && Date.now() - pet.cursorSeen < 4000 ? pet.cursorY : pet.py - 20
        lookX: Math.max(-1, Math.min(1, (tx - pet.px) / 160))
        lookY: Math.max(-1, Math.min(1, (ty - (pet.py - 20)) / 160))

        // Falling stretches it, landing squashes it.
        Binding on squash {
            when: pet.mode === "air" && !squashAnim.running
            value: 1 + Math.min(0.25, Math.abs(pet.vy) / 5000)
        }
        NumberAnimation on squash {
            id: squashAnim
            running: false
            to: 1
            duration: 380
            easing.type: Easing.OutElastic
            easing.amplitude: 1.4
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onEntered: if (Date.now() - pet.lastWave > 15000 && pet.mode === "ground") pet.doEmote("wave", 1400)
            cursorShape: pet.mode === "drag" ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            property real sx: 0
            property real sy: 0
            property var trail: []
            property bool dragged: false    // a drag's release also fires clicked

            onPressed: (m) => {
                var p = mapToItem(pet.contentItem, m.x, m.y)
                sx = p.x; sy = p.y; trail = []; dragged = false
            }
            onPositionChanged: (m) => {
                if (!pressed || !(m.buttons & Qt.LeftButton)) return
                var p = mapToItem(pet.contentItem, m.x, m.y)
                if (pet.mode !== "drag" && Math.hypot(p.x - sx, p.y - sy) < 5) return
                if (pet.mode !== "drag") { dragged = true; pet.wake(); pet.mode = "drag"; pet.on = ""; pet.feel("surprised", 99999); pet.say("wheee", 99999) }
                pet.px = p.x
                pet.py = p.y + mochi.height / 2
                var now = Date.now()
                trail.push({ t: now, x: pet.px, y: pet.py })
                while (trail.length > 2 && now - trail[0].t > 90) trail.shift()
            }
            onReleased: {
                if (pet.mode !== "drag") return
                var a = trail[0], b = trail[trail.length - 1]
                var dt = a && b && b.t > a.t ? (b.t - a.t) / 1000 : 1
                pet.vx = a ? Math.max(-2600, Math.min(2600, (b.x - a.x) / dt)) : 0
                pet.vy = a ? Math.max(-2600, Math.min(2600, (b.y - a.y) / dt)) : 0
                pet.mode = "air"
                pet.feel(Math.hypot(pet.vx, pet.vy) > 900 ? "happy" : "normal", 1200)
                pet.say("", 0)
                pet.lastPet = Date.now()
            }
            onClicked: (m) => {
                if (dragged) return
                pet.lastPet = Date.now()
                if (m.button === Qt.RightButton) {
                    pet.following = !pet.following
                    pet.act = pet.following ? "follow" : "idle"
                    pet.say(pet.following ? "coming!" : "ok, bye", 1200)
                    return
                }
                if (pet.act === "sleep") { pet.wake(); pet.feel("surprised", 800); pet.say("?!", 900); return }
                clickTimer.restart()
            }
            onDoubleClicked: {
                clickTimer.stop()
                if (dragged) return
                pet.act = "sleep"; pet.mood = "sleep"; pet.actUntil = Date.now() + 120000
                pet.bubble = ""
            }
            Timer {
                id: clickTimer
                interval: 230
                onTriggered: {
                    pet.feel("happy", 1400)
                    pet.say("✻", 1400)
                    pet.doEmote("wave", 900)
                    if (pet.mode === "ground") { pet.mode = "air"; pet.on = ""; pet.vy = -620; pet.vx = 0 }
                }
            }
        }
    }

    // Speech bubble.
    Rectangle {
        visible: pet.bubble.length > 0 || pet.emote === "think"
        x: Math.max(4, Math.min(pet.width - width - 4, pet.px - width / 2))
        y: mochi.y - height - 8
        width: bubbleText.implicitWidth + 16
        height: bubbleText.implicitHeight + 8
        radius: height / 2
        color: "white"
        border.color: Qt.darker(mochi.tint, 1.4)
        border.width: 1
        Text {
            id: bubbleText
            anchors.centerIn: parent
            text: pet.emote === "think" && !pet.bubble
                ? pet.spinner[pet.spin] + "  " + pet.verb
                  + (pet.agentState === "work" && pet.agentProject ? "  · " + pet.agentProject : "")
                : pet.bubble
            font.family: "DejaVu Sans"
            font.pixelSize: 12
            font.weight: 800
            color: "#2b2530"
        }
    }
}
