import QtQuick

// Clawd, drawn from the geometry in clawd-emotes-skill's references/anatomy.md
// (torso 11×7 units, 2×2 arms, four 1×2 legs, 1×2 eyes), at the same scale the
// emote GIFs play at, so drawn and GIF Clawd line up pixel for pixel.
// Pure drawing: Pet.qml decides what it does.
Item {
    id: clawd
    property color tint: "#DE886D"
    property string mood: "normal"     // normal happy sleep surprised dizzy love
    property real lookX: 0             // -1..1, where the eyes point
    property real lookY: 0
    property bool walking: false
    property bool dangling: false      // held by the cursor
    property bool perched: false       // resting on a window edge: legs hang over it
    property bool grounded: true       // draws the ground shadow
    property real squash: 1            // <1 flattened (landing), >1 stretched (falling)
    property bool hovered: false
    property string emote: ""          // "" | wave | think
    // An animated scene from emotes/ (clawd-<gif>.gif) replaces the drawn body.
    property string gif: ""

    // The GIFs are 240px for a 45-unit viewBox (5.33px/unit), played at 0.7x.
    readonly property real u: 240 / 45 * 0.7
    readonly property bool drawn: gif === ""
    function px(n) { return Math.round(n * u) }

    // Crab spans x 0..15 and y 0..9 units (torso top to feet bottom).
    width: px(15)
    height: px(9)

    AnimatedImage {
        visible: clawd.gif !== "" && status === Image.Ready
        source: clawd.gif ? Qt.resolvedUrl("emotes/clawd-" + clawd.gif + ".gif") : ""
        width: 168; height: 168
        x: clawd.width / 2 - width / 2
        // Feet sit at y≈214 in the GIF; scenes with props below the feet
        // (laptop, bed) rest on those instead.
        readonly property int ground: ({ sleeping: 233, coding: 220, exercise: 219 })[clawd.gif] || 214
        y: clawd.height - Math.round(ground * 0.7)
        smooth: false
        playing: visible
    }

    property real stride: 0
    NumberAnimation on stride {
        running: clawd.walking && clawd.drawn
        loops: Animation.Infinite
        from: 0; to: Math.PI * 2; duration: 360
    }

    transform: Scale {
        origin.x: clawd.width / 2
        origin.y: clawd.height
        yScale: clawd.squash
        xScale: 1 / Math.sqrt(clawd.squash)
    }

    component Px: Rectangle {        // one block, in crab units
        property real ux; property real uy; property real uw: 1; property real uh: 1
        x: clawd.px(ux); y: clawd.px(uy)
        width: clawd.px(ux + uw) - clawd.px(ux)
        height: Math.max(1, clawd.px(uy + uh) - clawd.px(uy))
        color: clawd.tint
        antialiasing: false
    }

    Item {
        anchors.fill: parent
        visible: clawd.drawn

        // ground shadow (anatomy: 3,15 9×1 → just under the feet)
        Px {
            visible: clawd.grounded && !clawd.dangling
            ux: 3; uy: 9; uw: 9; uh: 1
            color: "black"; opacity: 0.5
        }

        // legs x∈{3,5,9,11}; alternate pairs lift while walking
        Repeater {
            model: [3, 5, 9, 11]
            Px {
                required property int modelData
                required property int index
                readonly property bool lifted: clawd.walking && (index % 2 === 0) === (Math.sin(clawd.stride) > 0)
                ux: modelData
                uy: 7 + (clawd.perched ? 0.5 : 0) - (lifted ? 0.5 : 0)
                uh: clawd.dangling ? 3 : 2
            }
        }

        Item {
            id: body
            width: parent.width
            height: parent.height
            y: clawd.walking && Math.sin(clawd.stride * 2) > 0 ? -clawd.px(0.4) : 0

            Px { ux: 2; uy: 0; uw: 11; uh: 7 }                 // torso
            Px { ux: 0; uy: 3; uw: 2; uh: 2 }                  // left arm
            Px {                                               // right arm — waves
                id: rightArm
                ux: 13; uy: 3 - lift; uw: 2; uh: 2
                property real lift: 0
                SequentialAnimation on lift {
                    running: clawd.emote === "wave"
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) rightArm.lift = 0
                    PropertyAction { value: 2 }
                    PauseAnimation { duration: 170 }
                    PropertyAction { value: 1 }
                    PauseAnimation { duration: 170 }
                }
            }

            // eyes (anatomy: 4,8 and 10,8, 1×2)
            property bool blink: false
            Timer {
                interval: 2600 + Math.random() * 2600
                running: clawd.drawn && (clawd.mood === "normal" || clawd.mood === "love")
                repeat: true
                onTriggered: { body.blink = true; unblink.restart(); interval = 2400 + Math.random() * 3200 }
            }
            Timer { id: unblink; interval: 130; onTriggered: body.blink = false }

            readonly property real ex: (clawd.emote === "think" ? -1 : clawd.lookX) * 0.5
            readonly property real ey: (clawd.emote === "think" ? -1 : clawd.lookY) * 0.4
            readonly property string eyes: clawd.mood === "sleep" || (body.blink && clawd.mood === "normal") ? "shut"
                : clawd.mood === "surprised" ? "wide" : clawd.mood === "happy" ? "happy"
                : clawd.mood === "dizzy" ? "x" : clawd.mood === "love" ? "♥" : "open"

            Repeater {
                model: [4, 10]
                Item {
                    required property int modelData
                    // block eyes: open 1×2, wide 1.4×1.6, shut/happy thin slits
                    Px {
                        visible: body.eyes !== "x" && body.eyes !== "♥"
                        color: "black"
                        ux: modelData + body.ex - (body.eyes === "wide" ? 0.2 : 0)
                        uy: 2 + body.ey + (body.eyes === "shut" ? 1.3 : body.eyes === "happy" ? 0.6 : body.eyes === "wide" ? 0.2 : 0)
                        uw: body.eyes === "wide" ? 1.4 : 1
                        uh: body.eyes === "shut" ? 0.35 : body.eyes === "happy" ? 0.5 : body.eyes === "wide" ? 1.6 : 2
                    }
                    Text {
                        visible: body.eyes === "x" || body.eyes === "♥"
                        x: clawd.px(modelData + 0.5 + body.ex) - width / 2
                        y: clawd.px(3 + body.ey) - height / 2
                        text: body.eyes
                        font.family: "DejaVu Sans"
                        font.pixelSize: body.eyes === "♥" ? 8 : 9
                        font.bold: true
                        color: "black"
                    }
                }
            }

            // mouth (anatomy's optional #7a2230): only for the big feelings
            Px {
                visible: clawd.mood === "happy" || clawd.mood === "surprised" || clawd.mood === "love"
                color: "#7a2230"
                ux: clawd.mood === "surprised" ? 6.9 : 6.4
                uy: 4.8
                uw: clawd.mood === "surprised" ? 1.2 : 2.2
                uh: clawd.mood === "surprised" ? 1.3 : 1
                radius: clawd.px(0.5)
                antialiasing: true
            }
        }
    }
}
