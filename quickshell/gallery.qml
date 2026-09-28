// Visual check of every widget at each grid size:
//   GALLERY="clock,weather" qs -p ~/.config/quickshell/gallery.qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import "lib" as Lib
import "desktop" as Desktop
import "desktop/grid.js" as Grid

ShellRoot {
    FloatingWindow {
        id: win
        implicitWidth: 1400
        implicitHeight: 900
        color: "#15181a"
        Lib.ThemeEngine { id: theme }
        readonly property var types: (Quickshell.env("GALLERY") || "clock,weather,calendar,pomodoro").split(",")
        readonly property var sizes: (Quickshell.env("SIZES") || "1x1,2x1,3x1,1x2,2x2,3x2").split(",").map(s => s.split("x").map(Number))

        Column {
            x: 12; y: 12
            spacing: 12
            Repeater {
                model: win.types
                Row {
                    id: typeRow
                    required property string modelData
                    spacing: 12
                    Repeater {
                        model: win.sizes
                        Rectangle {
                            required property var modelData
                            width: Grid.span(modelData[0])
                            height: Grid.span(modelData[1])
                            radius: theme.radiusOuter
                            color: typeRow.modelData === "cava" ? "transparent" : theme.glassFill
                            border.width: 1
                            border.color: theme.glassHighlight
                            clip: true
                            Loader {
                                anchors.fill: parent
                                readonly property string file: {
                                    var t = typeRow.modelData
                                    var m = {worldclock: "WorldClock", codexbar: "CodexBar"}
                                    return "desktop/" + (m[t] || t[0].toUpperCase() + t.slice(1)) + "Widget.qml"
                                }
                                Component.onCompleted: {
                                    var props = { theme: theme }
                                    if (typeRow.modelData === "todo") props.items = [{id: "a", text: "Finish maths homework", done: false}, {id: "b", text: "Email Ms Lee", done: true}]
                                    if (typeRow.modelData === "notes") props.text = "Buy milk\nCall mum"
                                    setSource(file, props)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
