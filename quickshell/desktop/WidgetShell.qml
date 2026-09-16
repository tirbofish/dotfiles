import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../lib" as Lib

PanelWindow {
    id: win

    required property QtObject theme
    required property var spec
    required property string outputKey

    readonly property bool editing: Lib.WidgetService.editing
    readonly property bool selected: editing && Lib.WidgetService.selectedId === spec.id
    property int posX: spec ? spec.x : 0
    property int posY: spec ? spec.y : 0
    property int boxW: spec ? spec.w : 240
    property int boxH: spec ? spec.h : 140
    property bool dragging: false
    property real grabX: 0
    property real grabY: 0

    function syncFromSpec() {
        if (!spec) return
        posX = spec.x
        posY = spec.y
        boxW = spec.w
        boxH = spec.h
    }

    Component.onCompleted: syncFromSpec()
    onSpecChanged: syncFromSpec()
    onEditingChanged: {
        if (win.editing)
            win.capturingKeys = false
        if (!editing) {
            dragging = false
            syncFromSpec()
        }
    }
    Component.onDestruction: {
        if (dragging) Lib.WidgetService.widgetDragging = false
    }

    implicitWidth: win.boxW
    implicitHeight: win.boxH
    color: "transparent"
    exclusiveZone: -1
    property bool capturingKeys: false
    aboveWindows: win.editing || win.capturingKeys
    WlrLayershell.layer: win.editing ? WlrLayer.Overlay : (win.capturingKeys ? WlrLayer.Top : WlrLayer.Bottom)
    WlrLayershell.namespace: "desktop-widget"
    readonly property bool inputFocus: !win.editing && win.spec && (win.spec.type === "notes" || win.spec.type === "todo")
    readonly property bool notesFocus: win.inputFocus
    focusable: win.inputFocus
    WlrLayershell.keyboardFocus: win.inputFocus ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    readonly property bool windowActive: contentItem.window ? contentItem.window.active : false
    onWindowActiveChanged: {
        if (win.windowActive && win.inputFocus)
            win.capturingKeys = true
        else
            win.capturingKeys = false
        if (!windowActive && body.item && body.item.clearFocus) body.item.clearFocus()
    }
    // Keep the surface and coordinate system stable for the entire edit session.
    anchors { left: true; top: true; right: win.editing; bottom: win.editing }
    margins { left: win.editing ? 0 : win.posX; top: win.editing ? 0 : win.posY }
    mask: Region { item: win.dragging ? stage : chrome }

    Item {
        id: stage
        anchors.fill: parent

    Rectangle {
        id: chrome
        x: win.editing ? win.posX : 0
        y: win.editing ? win.posY : 0
        width: win.boxW
        height: win.boxH
        radius: win.theme.radiusOuter
        color: "transparent"
        border.width: win.selected ? 2 : 1
        border.color: win.selected
            ? win.theme.accent
            : (win.theme.isDarkMode ? Qt.rgba(1, 1, 1, 0.08) : win.theme.outline)
        clip: true

        Rectangle {
            z: -1
            anchors.fill: parent
            anchors.topMargin: 8
            color: "black"
            opacity: win.theme.isDarkMode ? 0.22 : 0.12
            radius: parent.radius
        }

        Loader {
            id: body
            anchors.fill: parent
            sourceComponent: {
                switch (win.spec.type) {
                case "clock": return clockComp
                case "weather": return weatherComp
                case "calendar": return calendarComp
                case "media": return mediaComp
                case "stats": return statsComp
                case "notes": return notesComp
                case "todo": return todoComp
                case "cava": return cavaComp
                case "codexbar": return codexbarComp
                case "progress": return progressComp
                default: return clockComp
                }
            }
            onLoaded: {
                if (!item) return
                item.width = Qt.binding(function() { return body.width })
                item.height = Qt.binding(function() { return body.height })
            }
        }

        // Drag / select surface. Sits above the body in edit mode so notes
        // still receive clicks when you are not arranging widgets.
        MouseArea {
            id: dragArea
            anchors.fill: parent
            enabled: win.editing
            hoverEnabled: true
            preventStealing: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            z: 2
            onPressed: (ev) => {
                Lib.WidgetService.selectedId = win.spec.id
                var p = mapToItem(stage, ev.x, ev.y)
                win.grabX = p.x - win.posX
                win.grabY = p.y - win.posY
                win.dragging = true
                Lib.WidgetService.widgetDragging = true
            }
            onPositionChanged: (ev) => {
                if (!pressed || !win.dragging) return
                var p = mapToItem(stage, ev.x, ev.y)
                win.posX = Math.round(Math.max(8, Math.min(win.screen.width - win.boxW - 8, p.x - win.grabX)))
                win.posY = Math.round(Math.max(8, Math.min(win.screen.height - win.boxH - 8, p.y - win.grabY)))
            }
            onReleased: {
                Lib.WidgetService.moveWidget(
                    win.outputKey, win.spec.id, win.posX, win.posY,
                    win.screen.width, win.screen.height)
                win.dragging = false
                Lib.WidgetService.widgetDragging = false
                win.syncFromSpec()
            }
            onCanceled: {
                win.dragging = false
                Lib.WidgetService.widgetDragging = false
                win.syncFromSpec()
            }
        }

        Rectangle {
            visible: win.editing
            width: 22; height: 22; radius: 11
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 6
            color: closeMa.containsMouse ? Qt.darker(win.theme.accentRed, 1.1) : "#c4c4c4"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.18)
            z: 5
            Text {
                anchors.centerIn: parent
                text: "−"
                font.pixelSize: 16
                font.weight: 700
                color: "#3a3a3a"
            }
            MouseArea {
                id: closeMa
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Lib.WidgetService.removeWidget(win.outputKey, win.spec.id)
            }
        }

        Rectangle {
            visible: win.editing
            width: 22; height: 22; radius: 5
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 4
            color: win.theme.accent
            opacity: 0.85
            z: 4
            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.SizeFDiagCursor
                property int startW: 0
                property int startH: 0
                property real grabX: 0
                property real grabY: 0
                onPressed: (ev) => {
                    Lib.WidgetService.selectedId = win.spec.id
                    startW = win.boxW
                    startH = win.boxH
                    var p = mapToItem(stage, ev.x, ev.y)
                    grabX = p.x
                    grabY = p.y
                    win.dragging = true
                    Lib.WidgetService.widgetDragging = true
                }
                onPositionChanged: (ev) => {
                    if (!pressed || !win.dragging) return
                    var p = mapToItem(stage, ev.x, ev.y)
                    win.boxW = Math.max(140, Math.min(win.screen.width - win.posX - 8, startW + p.x - grabX))
                    win.boxH = Math.max(72, Math.min(win.screen.height - win.posY - 8, startH + p.y - grabY))
                }
                onReleased: {
                    Lib.WidgetService.resizeWidget(
                        win.outputKey, win.spec.id, win.boxW, win.boxH,
                        win.screen.width, win.screen.height)
                    win.dragging = false
                    Lib.WidgetService.widgetDragging = false
                    win.syncFromSpec()
                }
                onCanceled: {
                    win.dragging = false
                    Lib.WidgetService.widgetDragging = false
                    win.syncFromSpec()
                }
            }
        }
    }

    }

    Component {
        id: clockComp
        ClockWidget { theme: win.theme }
    }
    Component {
        id: weatherComp
        WeatherWidget { theme: win.theme }
    }
    Component {
        id: calendarComp
        CalendarWidget { theme: win.theme }
    }
    Component {
        id: mediaComp
        MediaWidget { theme: win.theme }
    }
    Component {
        id: statsComp
        StatsWidget { theme: win.theme }
    }
    Component {
        id: notesComp
        NotesWidget {
            theme: win.theme
            text: (win.spec.settings && win.spec.settings.note) ? win.spec.settings.note : ""
            onNoteChanged: (t) => Lib.WidgetService.setSetting(win.outputKey, win.spec.id, "note", t)
        }
    }
    Component {
        id: todoComp
        TodoWidget {
            theme: win.theme
            items: (win.spec.settings && win.spec.settings.todos) ? win.spec.settings.todos : []
            onTodosChanged: (list) => Lib.WidgetService.setSetting(win.outputKey, win.spec.id, "todos", list)
        }
    }
    Component {
        id: cavaComp
        CavaWidget { theme: win.theme }
    }
    Component {
        id: codexbarComp
        CodexBarWidget { theme: win.theme }
    }
    Component {
        id: progressComp
        ProgressWidget { theme: win.theme }
    }
}
