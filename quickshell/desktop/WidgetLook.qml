import QtQuick
import "grid.js" as Grid

// Size class of a widget on the desktop grid.
//   small  1×1        → icon tile
//   strip  N×1 / 1×N  → compact row or column
//   wide / tall       → landscape / portrait full layout
QtObject {
    id: look
    required property Item host
    readonly property int cols: Grid.cells(host.width)
    readonly property int rows: Grid.cells(host.height)
    readonly property bool small: cols === 1 && rows === 1
    readonly property bool row: rows === 1 && cols > 1
    readonly property bool column: cols === 1 && rows > 1
    readonly property bool wide: host.width > host.height * 1.35
    readonly property bool tall: host.height > host.width * 1.35
}
