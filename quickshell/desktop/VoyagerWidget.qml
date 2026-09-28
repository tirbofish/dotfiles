import QtQuick
import QtQuick.Layouts
import "../lib" as Lib

// Voyager 1, live. Distances are JPL Horizons ephemerides (lib/voyager.py),
// interpolated between daily samples so the kilometres tick in real time.
// In November 2026 it becomes the first spacecraft one light-day from Earth.
Item {
    id: root
    required property QtObject theme

    WidgetLook { id: look; host: root }

    readonly property real auKm: 149597870.7
    readonly property real cKmS: 299792.458
    readonly property var feed: poll.value || ({})
    property double now: Date.now()

    // [ms, AU, km/s] rows → where the probe is at `now`.
    function at(rows) {
        if (!rows || !rows.length) return null
        var i = 0
        while (i < rows.length - 2 && rows[i + 1][0] <= root.now) i++
        var a = rows[i], b = rows[i + 1] || a
        var f = b[0] > a[0] ? (root.now - a[0]) / (b[0] - a[0]) : 0
        if (f > 1 || b === a)   // past our samples (offline): coast on the last speed
            return { au: b[1] + b[2] * (root.now - b[0]) / 1000 / root.auKm, kms: b[2] }
        return { au: a[1] + (b[1] - a[1]) * f, kms: a[2] + (b[2] - a[2]) * f }
    }
    readonly property var v1: at(feed.v1)
    readonly property var v2: at(feed.v2)
    readonly property real km: v1 ? v1.au * auKm : 0
    readonly property real lightS: km / cKmS
    readonly property real lightDays: v1 ? v1.au / (feed.lightDayAu || 173.1446) : 0
    readonly property bool crossed: lightDays >= 1

    function thousands(n) { return Math.floor(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",") }
    function pad(n) { return (n < 10 ? "0" : "") + n }
    function hms(s) {
        s = Math.floor(s)
        return Math.floor(s / 3600) + "h " + pad(Math.floor(s / 60) % 60) + "m " + pad(s % 60) + "s"
    }
    function dhm(ms) {
        var m = Math.floor(Math.abs(ms) / 60000)
        return Math.floor(m / 1440) + "d " + Math.floor(m / 60) % 24 + "h " + pad(m % 60) + "m"
    }

    Lib.CommandPoll {
        id: poll
        interval: 3600000
        command: ["python3", Qt.resolvedUrl("../lib/voyager.py").toString().replace("file://", "")]
        parse: function(out) {
            try { return JSON.parse(String(out || "{}")) } catch (e) { return root.feed }
        }
    }
    Timer {
        interval: 100
        running: root.visible && !!root.v1
        repeat: true
        onTriggered: root.now = Date.now()
    }

    // Stars. Deterministic, painted once per resize.
    Canvas {
        anchors.fill: parent
        visible: !look.small
        opacity: 0.55
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var seed = 1977
            function rnd() { seed = (seed * 16807) % 2147483647; return seed / 2147483647 }
            var n = Math.round(width * height / 2600)
            for (var i = 0; i < n; i++) {
                var r = rnd() < 0.9 ? 0.6 : 1.2
                ctx.globalAlpha = 0.25 + rnd() * 0.6
                ctx.fillStyle = root.theme.textPrimary
                ctx.beginPath()
                ctx.arc(rnd() * width, rnd() * height, r, 0, Math.PI * 2)
                ctx.fill()
            }
        }
    }

    component Label: Text {
        font.family: root.theme.textFont
        font.pixelSize: 10
        font.weight: 800
        font.letterSpacing: 1.4
        color: root.theme.textSecondary
    }
    component Value: Text {
        font.family: "Inter"
        font.features: { "tnum": 1 }
        font.weight: 600
        color: root.theme.textPrimary
    }

    // ── 1×1 ─────────────────────────────────────────────────────────────
    Tile {
        anchors.fill: parent
        visible: look.small
        theme: root.theme
        icon: "✦"
        value: root.v1 ? Math.floor(root.lightS / 3600) + "h " + root.pad(Math.floor(root.lightS / 60) % 60) + "m" : "…"
        label: "light to Voyager 1"
    }

    // ── N×1 strip ───────────────────────────────────────────────────────
    RowLayout {
        visible: look.row
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Label { text: "VOYAGER 1 · KM FROM EARTH" }
            Value {
                Layout.fillWidth: true
                text: root.v1 ? root.thousands(root.km) : "—"
                font.pixelSize: 26
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: 14
            }
        }
        ColumnLayout {
            visible: root.width > 330
            spacing: 0
            Label { text: "SIGNAL"; Layout.alignment: Qt.AlignRight }
            Value { text: root.v1 ? root.hms(root.lightS) : "—"; font.pixelSize: 15; color: root.theme.accent }
        }
    }

    // ── column / full ───────────────────────────────────────────────────
    ColumnLayout {
        visible: !look.small && !look.row
        anchors.fill: parent
        anchors.margins: look.column ? 12 : 18
        spacing: look.column ? 6 : 8

        RowLayout {
            Layout.fillWidth: true
            Label {
                text: look.column ? "VOYAGER 1" : "VOYAGER 1  ·  INTERSTELLAR SPACE"
                color: root.theme.accent
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Rectangle {
                visible: !look.column
                width: 6; height: 6; radius: 3
                color: poll.value && !poll.value.error ? "#4ade80" : root.theme.accentRed
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.25; duration: 900 }
                    NumberAnimation { to: 1; duration: 900 }
                }
            }
            Label { visible: !look.column; text: "LIVE"; font.pixelSize: 9 }
        }

        Value {
            Layout.fillWidth: true
            text: !root.v1 ? (root.feed.error || "Contacting JPL…")
                : look.column ? Math.floor(root.lightS / 3600) + "h\n" + root.pad(Math.floor(root.lightS / 60) % 60) + "m"
                : root.thousands(root.km) + " km"
            font.pixelSize: look.column ? 34 : 34
            lineHeight: 0.9
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 14
        }
        Text {
            Layout.fillWidth: true
            visible: !!root.v1
            text: !root.v1 ? "" : look.column ? "light-time" : root.v1.au.toFixed(4) + " AU from Earth  ·  "
                + (root.v1.kms >= 0 ? "receding at " : "closing at ") + Math.abs(root.v1.kms).toFixed(2) + " km/s"
            font.family: root.theme.textFont
            font.pixelSize: 11
            color: root.theme.textSecondary
            elide: Text.ElideRight
        }

        // The whole trip. Planets on a log scale, then a break, then the
        // outer 110–180 AU drawn to scale: heliopause, both Voyagers and the
        // one-light-day line, close enough to see the gap closing.
        Item {
            id: journey
            visible: !look.column && root.height > 200
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 56
            readonly property real mid: height / 2
            readonly property real split: 0.36
            readonly property real resume: 0.42
            function xOf(au) {
                if (au <= 35) return (Math.log(au) - Math.log(0.7)) / (Math.log(35) - Math.log(0.7)) * split * width
                var f = Math.max(0, Math.min(1, (au - 110) / (180 - 110)))
                return (resume + f * (1 - resume)) * width
            }
            readonly property real ld: root.feed.lightDayAu || 173.1446

            Rectangle { x: 0; y: journey.mid; width: journey.split * journey.width; height: 1; color: root.theme.outline }
            Rectangle {
                x: journey.resume * journey.width; y: journey.mid
                width: (1 - journey.resume) * journey.width; height: 1; color: root.theme.outline
            }
            Text {   // axis break
                x: (journey.split + journey.resume) / 2 * journey.width - width / 2
                y: journey.mid - height / 2
                text: "//"
                font.pixelSize: 11
                font.weight: 700
                color: root.theme.textSecondary
            }

            component Mark: Item {
                id: mark
                property real au: 1
                property string label: ""
                property color tint: root.theme.textSecondary
                property bool above: false
                property real size: 6
                x: journey.xOf(au)
                y: journey.mid
                Rectangle { x: -mark.size / 2; y: -mark.size / 2 + 0.5; width: mark.size; height: width; radius: width / 2; color: mark.tint }
                Text {
                    x: -width / 2
                    y: mark.above ? -height - 8 : 8
                    text: mark.label
                    font.family: root.theme.textFont
                    font.pixelSize: 9
                    font.weight: 700
                    color: mark.tint
                }
            }
            Mark { au: 1; label: "Earth" }
            Mark { au: 5.2; label: "Jupiter"; above: true }
            Mark { au: 9.5; label: "Saturn" }
            Mark { au: 19.2; label: "Uranus"; above: true }
            Mark { au: 30.1; label: "Neptune" }

            // Heliopause: where the solar wind gives out. Voyager 1 crossed it in 2012.
            Item {
                x: journey.xOf(121.6)
                Rectangle { x: -0.5; y: journey.mid - 12; width: 1; height: 24; color: root.theme.textSecondary; opacity: 0.6 }
                Text {
                    x: -width / 2; y: journey.mid + 14
                    text: "heliopause"
                    font.family: root.theme.textFont; font.pixelSize: 9
                    color: root.theme.textSecondary
                }
            }
            Item {
                x: journey.xOf(journey.ld)
                Rectangle { x: -0.5; y: journey.mid - 16; width: 1; height: 32; color: root.theme.accentSlider2 }
                Text {
                    x: -width / 2; y: journey.mid - 30
                    text: "1 light-day"
                    font.family: root.theme.textFont; font.pixelSize: 9; font.weight: 800
                    color: root.theme.accentSlider2
                }
            }
            Mark {
                visible: !!root.v2
                au: root.v2 ? root.v2.au : 0
                label: "Voyager 2"
                tint: root.theme.textPrimary
                above: true
                size: 7
            }
            Item {        // Voyager 1, pinging
                visible: !!root.v1
                x: root.v1 ? journey.xOf(root.v1.au) : 0
                y: journey.mid
                Rectangle {
                    anchors.centerIn: dot
                    width: 8; height: width; radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: root.theme.accent
                    NumberAnimation on width { loops: Animation.Infinite; from: 8; to: 34; duration: 2200; easing.type: Easing.OutCubic }
                    NumberAnimation on opacity { loops: Animation.Infinite; from: 0.9; to: 0; duration: 2200; easing.type: Easing.OutCubic }
                }
                Rectangle { id: dot; x: -5; y: -4.5; width: 10; height: 10; radius: 5; color: root.theme.accent }
                Text {
                    x: -width + 2; y: 10
                    text: "Voyager 1"
                    font.family: root.theme.textFont; font.pixelSize: 9; font.weight: 800
                    color: root.theme.accent
                }
            }
            // A radio pulse, forever crossing the gap.
            Rectangle {
                visible: !!root.v1
                y: journey.mid - 1.5; width: 16; height: 4; radius: 2
                color: root.theme.accentSlider2
                NumberAnimation on x {
                    loops: Animation.Infinite
                    from: journey.xOf(1)
                    to: root.v1 ? journey.xOf(root.v1.au) - 16 : 0
                    duration: 5000
                    easing.type: Easing.InOutSine
                }
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { from: 0; to: 0.9; duration: 600 }
                    PauseAnimation { duration: 3800 }
                    NumberAnimation { from: 0.9; to: 0; duration: 600 }
                }
            }
        }

        GridLayout {
            visible: !!root.v1
            Layout.fillWidth: true
            columns: look.column ? 1 : 2
            columnSpacing: 16
            rowSpacing: 4
            ColumnLayout {
                visible: !look.column
                spacing: 0
                Label { text: "SIGNAL TIME, ONE WAY" }
                Value { text: root.hms(root.lightS); font.pixelSize: 17; color: root.theme.accent }
            }
            ColumnLayout {
                spacing: 0
                Label { text: root.crossed ? (look.column ? "PAST 1 LT-DAY" : "PAST ONE LIGHT-DAY") : (look.column ? "1 LT-DAY IN" : "ONE LIGHT-DAY IN") }
                Value {
                    text: !root.feed.crossing ? (root.lightDays * 100).toFixed(2) + "%"
                        : root.crossed ? Qt.formatDate(new Date(root.feed.crossing), "d MMM yyyy")
                        : root.dhm(root.feed.crossing - root.now)
                    font.pixelSize: look.column ? 13 : 17
                    color: root.theme.accentSlider2
                }
            }
        }

        Text {
            visible: !!root.v1 && !look.column && root.height > 250
            Layout.fillWidth: true
            text: "Say hello now and it arrives " + Qt.formatDateTime(new Date(root.now + root.lightS * 1000), "ddd d MMM, h:mm AP")
                + (root.v2 ? "   ·   Voyager 2 is " + (root.v2.au / (root.feed.lightDayAu || 173.1446)).toFixed(3) + " light-days out" : "")
            font.family: root.theme.textFont
            font.pixelSize: 11
            color: root.theme.textSecondary
            wrapMode: Text.WordWrap
        }
        Item { Layout.fillHeight: true; visible: !journey.visible }
    }
}
