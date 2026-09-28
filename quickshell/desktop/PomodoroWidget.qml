import QtQuick
import QtQuick.Layouts
import Quickshell
import "../lib" as Lib
import "pomodoro.js" as Pomo

// Pick how long you want to work; pomodoro.js splits it into 25 min focus
// blocks with 5 min breaks (15 after every 4th). Blocks roll into each other
// with a chime + notification. Tap the ring to pause.
Item {
    id: root
    required property QtObject theme
    property int sessionMin: 50
    property bool active: false        // a session is in progress (running or paused)
    property int step: 0               // index into plan
    property bool running: false
    property double endsAt: 0
    property double remainingMs: -1
    property int total: 0              // focus blocks finished today
    property int focusMin: 0           // focus minutes finished today
    property string day: ""
    property double shownMs: 0
    property bool ready: false

    signal sessionChanged(var state)

    WidgetLook { id: look; host: root }

    readonly property var plan: Pomo.plan(root.sessionMin)
    readonly property var cur: root.plan[Math.min(root.step, root.plan.length - 1)]
    readonly property bool onBreak: root.active && root.cur.phase !== "work"
    readonly property color phaseColor: root.onBreak ? root.theme.accentSlider2 : root.theme.accent
    readonly property int blocks: root.plan.filter(s => s.phase === "work").length
    readonly property int blockNo: root.plan.slice(0, root.step + 1).filter(s => s.phase === "work").length
    readonly property string phaseLabel: !root.active ? "Session"
        : root.cur.phase === "work" ? "Focus " + root.blockNo + " of " + root.blocks
        : root.cur.phase === "long" ? "Long break" : "Break"
    readonly property double sessionLeftMs: !root.active ? root.sessionMin * 60000
        : root.shownMs + root.plan.slice(root.step + 1).reduce((a, s) => a + s.min, 0) * 60000

    function stepMs(i) { return root.plan[i].min * 60000 }
    function today() { return new Date().toDateString() }

    function clock(ms) {
        var s = Math.ceil(Math.max(0, ms) / 1000)
        var m = Math.floor(s / 60), r = s % 60
        return (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r
    }
    function hm(min) {
        min = Math.round(min)
        return min >= 60 ? Math.floor(min / 60) + "h" + (min % 60 ? " " + (min % 60) + "m" : "") : min + "m"
    }

    function persist() {
        root.sessionChanged({
            active: root.active, step: root.step, running: root.running, endsAt: root.endsAt,
            remainingMs: root.remainingMs, total: root.total, focusMin: root.focusMin, day: root.day
        })
    }

    function setSession(min) {
        if (Lib.WidgetService.editing || root.active) return
        root.sessionChanged({ sessionMin: Math.max(10, Math.min(240, min)) })
    }
    function nudge(dir) {
        var s = root.sessionMin
        var by = (dir > 0 ? s >= 60 : s > 60) ? 15 : 5
        setSession(Math.round((s + dir * by) / by) * by)
    }

    function tick() {
        root.shownMs = !root.active ? root.sessionMin * 60000
            : root.running ? Math.max(0, root.endsAt - Date.now()) : Math.max(0, root.remainingMs)
        ring.requestPaint()
        if (root.running && root.shownMs <= 0) root.advance(true)
    }

    function begin(i, run) {
        root.step = i
        root.remainingMs = stepMs(i)
        root.running = run
        root.endsAt = run ? Date.now() + root.remainingMs : 0
        persist()
        tick()
    }

    function toggle() {
        if (Lib.WidgetService.editing) return
        if (!root.active) {
            root.active = true
            begin(0, true)
        } else if (root.running) {
            root.remainingMs = Math.max(0, root.endsAt - Date.now())
            root.running = false
            root.endsAt = 0
            persist()
            tick()
        } else {
            root.running = true
            root.endsAt = Date.now() + root.remainingMs
            persist()
            tick()
        }
    }

    // Ending a session takes two taps (the first arms it for 3 s), so a stray
    // click can't throw away an hour of focus.
    property bool confirmCancel: false
    Timer { id: disarm; interval: 3000; onTriggered: root.confirmCancel = false }
    function cancel() {
        if (!root.confirmCancel) { root.confirmCancel = true; disarm.restart(); return }
        root.confirmCancel = false
        stop()
    }
    onActiveChanged: if (!active) confirmCancel = false

    function stop() {
        if (Lib.WidgetService.editing) return
        root.active = false
        begin(0, false)
    }

    // completed: the block ran out (counts, chimes). autoStart false when we
    // find it already expired on load — move on, but don't start ticking.
    function advance(completed, autoStart) {
        var done = root.cur
        if (root.day !== today()) { root.day = today(); root.total = 0; root.focusMin = 0 }
        if (completed && done.phase === "work") { root.total += 1; root.focusMin += done.min }
        var last = root.step + 1 >= root.plan.length
        if (completed && autoStart !== false) notify(done, last ? null : root.plan[root.step + 1])
        if (last) {
            root.active = false
            begin(0, false)
        } else {
            begin(root.step + 1, completed && autoStart !== false)
        }
    }

    function skip() {
        if (Lib.WidgetService.editing || !root.active) return
        advance(false)
    }

    function notify(done, next) {
        var title = !next ? "Session complete" : done.phase === "work" ? "Focus block done" : "Break's over"
        var body = !next ? hm(root.sessionMin) + " done · " + root.total + " blocks today"
            : next.phase === "work" ? "Focus · " + next.min + " min"
            : (next.phase === "long" ? "Long break · " : "Break · ") + next.min + " min"
        Quickshell.execDetached(["notify-send", "-a", "Pomodoro", "-i", "alarm-symbolic", title, body])
        Quickshell.execDetached(["paplay", "/usr/share/sounds/freedesktop/stereo/"
            + (next ? "alarm-clock-elapsed.oga" : "complete.oga")])
    }

    onSessionMinChanged: if (root.ready) tick()
    onPhaseColorChanged: ring.requestPaint()

    Component.onCompleted: {
        if (root.day !== today()) { root.day = today(); root.total = 0; root.focusMin = 0 }
        if (root.step >= root.plan.length) root.step = 0
        if (root.active && root.remainingMs < 0) root.remainingMs = stepMs(root.step)
        root.ready = true
        if (root.active && root.running && Date.now() >= root.endsAt) advance(true, false)
        tick()
    }

    Timer {
        interval: 250
        running: root.running
        repeat: true
        onTriggered: root.tick()
    }

    component Pill: Rectangle {
        id: pill
        property string label: ""
        property string icon: ""
        property bool primary: false
        property bool danger: false
        signal activated
        implicitWidth: Math.max(primary && label ? 88 : 34, content.implicitWidth + (label ? 26 : 18))
        implicitHeight: 34
        radius: 17
        // Themes with a grey "danger" colour still get a red that reads as a warning.
        readonly property color red: root.theme.accentRed.hslSaturation > 0.3 ? root.theme.accentRed : "#e5484d"
        color: danger ? (press.containsMouse ? Qt.lighter(red, 1.1) : red)
            : primary ? (press.containsMouse ? Qt.lighter(root.phaseColor, 1.12) : root.phaseColor)
            : (press.containsMouse ? root.theme.subtleFillHover : root.theme.subtleFill)
        Behavior on color { ColorAnimation { duration: 120 } }
        Row {
            id: content
            anchors.centerIn: parent
            spacing: 6
            Text {
                visible: pill.icon.length > 0
                text: pill.icon
                font.family: root.theme.iconFont
                font.pixelSize: 14
                color: pill.primary || pill.danger ? root.theme.textOnAccent : root.theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: pill.label.length > 0
                text: pill.label
                font.family: root.theme.textFont
                font.pixelSize: 12
                font.weight: 800
                color: pill.primary || pill.danger ? root.theme.textOnAccent : root.theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            id: press
            anchors.fill: parent
            enabled: !Lib.WidgetService.editing
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.activated()
        }
    }

    // The whole session at a glance: one segment per block, sized by length.
    component PlanBar: Row {
        id: bar
        spacing: 3
        height: 8
        Repeater {
            model: root.plan
            Rectangle {
                required property var modelData
                required property int index
                readonly property bool isWork: modelData.phase === "work"
                readonly property real fill: !root.active || index > root.step ? 0
                    : index < root.step ? 1 : 1 - root.shownMs / root.stepMs(index)
                width: Math.max(3, (bar.width - bar.spacing * (root.plan.length - 1)) * modelData.min / root.sessionMin)
                height: isWork ? bar.height : bar.height / 2
                anchors.verticalCenter: parent.verticalCenter
                radius: height / 2
                color: root.theme.subtleFillHover
                Rectangle {
                    width: parent.width * parent.fill
                    height: parent.height
                    radius: parent.radius
                    color: parent.isWork ? root.theme.accent : root.theme.accentSlider2
                }
            }
        }
    }

    component SessionPicker: RowLayout {
        spacing: 8
        Pill { icon: "󰍴"; onActivated: root.nudge(-1) }
        Text {
            Layout.fillWidth: true
            text: root.hm(root.sessionMin)
            font.family: root.theme.textFont
            font.pixelSize: 20
            font.weight: 800
            color: root.theme.textPrimary
            horizontalAlignment: Text.AlignHCenter
        }
        Pill { icon: "󰐕"; onActivated: root.nudge(1) }
    }

    // 1×1: ring only (tap = start/pause). N×1 / wide: ring beside controls.
    // 1×N / square: ring above controls.
    GridLayout {
        anchors.fill: parent
        anchors.margins: look.small ? 8 : 14
        columns: look.small || look.column ? 1 : (look.wide || look.row ? 2 : 1)
        columnSpacing: 16
        rowSpacing: 10

        Item {
            id: ringBox
            Layout.fillHeight: true
            Layout.fillWidth: look.small || look.column || !(look.wide || look.row)
            Layout.preferredWidth: look.wide || look.row ? Math.min(height, root.width * 0.42) : -1
            Layout.minimumHeight: 60

            Canvas {
                id: ring
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height)
                height: width
                antialiasing: true
                onWidthChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    var stroke = Math.max(4, Math.min(10, width * 0.06))
                    var c = width / 2, r = c - stroke / 2 - 1
                    if (r <= 0) return
                    ctx.lineWidth = stroke
                    ctx.lineCap = "round"
                    ctx.beginPath()
                    ctx.arc(c, c, r, 0, Math.PI * 2)
                    ctx.strokeStyle = root.theme.subtleFillHover
                    ctx.stroke()
                    var left = root.active ? root.shownMs / root.stepMs(root.step) : 1
                    if (left > 0) {
                        ctx.beginPath()
                        ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(1, left))
                        ctx.strokeStyle = root.phaseColor
                        ctx.globalAlpha = root.running ? 1 : 0.5
                        ctx.stroke()
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                width: ring.width * 0.78
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    visible: ring.width > 90
                    text: root.phaseLabel.toUpperCase()
                    font.family: root.theme.textFont
                    font.pixelSize: 9
                    font.weight: 800
                    font.letterSpacing: 1.2
                    color: root.phaseColor
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: root.active ? root.clock(root.shownMs) : root.hm(root.sessionMin)
                    font.family: "Inter"
                    font.pixelSize: Math.max(14, Math.min(ring.width * 0.24, 50))
                    font.weight: 500
                    font.features: { "tnum": 1 }
                    color: root.theme.textPrimary
                    opacity: root.running || !root.active ? 1 : 0.6
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    Layout.fillWidth: true
                    visible: ring.width > 120
                    text: !root.active ? "tap to start" : root.running ? root.hm(root.sessionLeftMs / 60000) + " left" : "paused · right-click ends"
                    font.family: root.theme.textFont
                    font.pixelSize: 10
                    color: root.theme.textSecondary
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            MouseArea {
                anchors.centerIn: parent
                width: ring.width
                height: ring.height
                enabled: !Lib.WidgetService.editing
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                // Right-click is deliberate enough to end the session outright.
                onClicked: (m) => m.button === Qt.RightButton ? (root.active && root.stop()) : root.toggle()
            }
        }

        ColumnLayout {
            visible: !look.small
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: look.row ? 6 : 10

            SessionPicker {
                visible: !root.active && !look.row && !look.column
                Layout.fillWidth: true
            }
            Text {
                visible: root.active && !look.row && !look.column
                Layout.fillWidth: true
                text: root.cur.phase === "work"
                    ? (root.step + 1 < root.plan.length ? "then " + root.plan[root.step + 1].min + " min break" : "last block")
                    : "then " + root.plan[root.step + 1].min + " min focus"
                font.family: root.theme.textFont
                font.pixelSize: 12
                font.weight: 600
                color: root.theme.textSecondary
                horizontalAlignment: look.wide ? Text.AlignLeft : Text.AlignHCenter
            }
            PlanBar { Layout.fillWidth: true; visible: !look.column }
            Text {
                visible: !look.row && !look.column && (look.wide || root.height > 300)
                Layout.fillWidth: true
                text: root.plan.map(s => s.min).join(" · ") + " min   ·   " + root.total + " today"
                font.family: root.theme.textFont
                font.pixelSize: 10
                color: root.theme.textSecondary
                elide: Text.ElideRight
                horizontalAlignment: look.wide ? Text.AlignLeft : Text.AlignHCenter
            }
            Row {
                Layout.alignment: look.wide || look.row ? Qt.AlignLeft : Qt.AlignHCenter
                spacing: 6
                Pill {
                    primary: true
                    icon: root.running ? "󰏤" : "󰐊"
                    label: look.column || (look.row && root.width < 400) ? "" : (root.running ? "Pause" : root.active ? "Resume" : "Start")
                    onActivated: root.toggle()
                }
                readonly property bool roomy: !look.column && root.width > 300
                Pill { visible: root.active && parent.roomy; icon: "󰒭"; onActivated: root.skip() }
                Pill {
                    visible: root.active
                    danger: root.confirmCancel
                    icon: "󰅖"
                    label: !parent.roomy ? "" : root.confirmCancel ? "Sure?" : "Cancel"
                    onActivated: root.cancel()
                }
                Pill { visible: !root.active && look.row && parent.roomy; icon: "󰍴"; onActivated: root.nudge(-1) }
                Pill { visible: !root.active && look.row && parent.roomy; icon: "󰐕"; onActivated: root.nudge(1) }
            }
        }
    }
}
