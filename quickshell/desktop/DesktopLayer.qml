import QtQuick
import Quickshell
import Quickshell.Wayland
import "../lib" as Lib
import "grid.js" as Grid

// Every desktop widget on one screen, in one fullscreen layer surface.
// Input only reaches the cards (mask), so the desktop underneath stays usable.
PanelWindow {
    id: desk

    required property QtObject theme
    required property string outputKey

    readonly property bool editing: Lib.WidgetService.editing
    readonly property var specs: {
        var _ = Lib.WidgetService.stamp
        return Lib.WidgetService.widgetsOn(desk.outputKey)
    }
    readonly property bool hasInput: desk.specs.some(s => s.type === "notes" || s.type === "todo")
    property bool capturingKeys: false

    anchors { left: true; top: true; right: true; bottom: true }
    color: "transparent"
    // Fill whatever the bars leave free; the grid spans all of it.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    aboveWindows: desk.editing || desk.capturingKeys
    WlrLayershell.layer: desk.editing ? WlrLayer.Overlay : (desk.capturingKeys ? WlrLayer.Top : WlrLayer.Bottom)
    WlrLayershell.namespace: "desktop-widget"
    focusable: !desk.editing && desk.hasInput
    WlrLayershell.keyboardFocus: focusable ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    readonly property bool windowActive: contentItem.window ? contentItem.window.active : false
    onWindowActiveChanged: {
        desk.capturingKeys = desk.windowActive && desk.hasInput && !desk.editing
        if (!desk.windowActive)
            for (var i = 0; i < cards.count; i++) if (cards.itemAt(i)) cards.itemAt(i).clearFocus()
    }
    onEditingChanged: if (desk.editing) desk.capturingKeys = false

    // Whole screen while arranging, otherwise just the cards.
    property int regionStamp: 0
    Region { id: everything; item: stage }
    Region {
        id: cardsOnly
        regions: {
            var _ = desk.regionStamp
            var out = []
            for (var i = 0; i < cards.count; i++) if (cards.itemAt(i)) out.push(cards.itemAt(i).region)
            return out
        }
    }
    mask: desk.editing ? everything : cardsOnly

    Item {
        id: stage
        anchors.fill: parent
        property Item dragCard: null
        readonly property var grid: Grid.layout(width, height)

        // Grid + landing spot while arranging.
        Repeater {
            model: stage.dragCard ? stage.grid.cols * stage.grid.rows : 0
            Rectangle {
                required property int index
                readonly property var cell: Grid.rect(index % stage.grid.cols, Math.floor(index / stage.grid.cols), 1, 1, stage.grid)
                x: cell.x
                y: cell.y
                width: cell.w
                height: cell.h
                radius: 10
                color: "transparent"
                border.width: 1
                border.color: desk.theme.outline
            }
        }
        Rectangle {
            visible: !!stage.dragCard
            x: stage.dragCard ? stage.dragCard.snapped.x : 0
            y: stage.dragCard ? stage.dragCard.snapped.y : 0
            width: stage.dragCard ? stage.dragCard.snapped.w : 0
            height: stage.dragCard ? stage.dragCard.snapped.h : 0
            radius: desk.theme.radiusOuter
            color: Qt.rgba(desk.theme.accent.r, desk.theme.accent.g, desk.theme.accent.b, 0.14)
            border.width: 2
            border.color: desk.theme.accent
            Behavior on x { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        }

        Repeater {
            id: cards
            // ScriptModel keeps cards alive when the list changes, so adding
            // one widget doesn't rebuild (and re-poll) all the others.
            model: ScriptModel { values: desk.specs }
            delegate: WidgetShell {
                theme: desk.theme
                outputKey: desk.outputKey
            }
            onItemAdded: desk.regionStamp++
            onItemRemoved: desk.regionStamp++
        }
    }
}
