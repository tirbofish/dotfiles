import QtQuick
import QtQuick.Layouts
import Quickshell
import "../lib" as Lib
import "grid.js" as Grid

// One widget card. All cards on a screen share a single DesktopLayer window,
// so moving, resizing or toggling edit mode never resizes a Wayland surface.
Item {
    id: win

    required property QtObject theme
    required property var modelData
    required property string outputKey
    readonly property var spec: modelData

    readonly property bool editing: Lib.WidgetService.editing
    readonly property bool selected: editing && Lib.WidgetService.selectedId === spec.id
    readonly property var widgetSettings: {
        var _ = Lib.WidgetService.settingsStamp
        return spec && spec.settings ? spec.settings : ({})
    }
    readonly property real screenW: parent ? parent.width : 1920
    readonly property real screenH: parent ? parent.height : 1080
    property int posX: spec ? spec.x : 0
    property int posY: spec ? spec.y : 0
    property int boxW: spec ? spec.w : 240
    property int boxH: spec ? spec.h : 140
    property bool dragging: false
    property real grabX: 0
    property real grabY: 0
    // Input region for the layer's mask.
    property Region region: Region { item: chrome }

    function syncFromSpec() {
        if (!spec) return
        posX = spec.x
        posY = spec.y
        boxW = spec.w
        boxH = spec.h
    }
    function clearFocus() { if (body.item && body.item.clearFocus) body.item.clearFocus() }
    function setDragging(on) {
        win.dragging = on
        Lib.WidgetService.widgetDragging = on
        if (win.parent) win.parent.dragCard = on ? win : null
    }

    // Transparent card: the visualiser floats straight on the wallpaper.
    readonly property bool bare: spec && spec.type === "cava" && !editing
    readonly property var snapped: Grid.snap(posX, posY, boxW, boxH, screenW, screenH)

    Component.onCompleted: Qt.callLater(function() {
        if (win.screenW > 0 && Lib.WidgetService.snapWidget(win.outputKey, win.spec.id, win.screenW, win.screenH))
            win.syncFromSpec()
    })
    onSpecChanged: syncFromSpec()
    onEditingChanged: {
        if (!editing) {
            if (dragging) setDragging(false)
            syncFromSpec()
        }
    }
    Component.onDestruction: {
        if (dragging) Lib.WidgetService.widgetDragging = false
    }

    x: posX
    y: posY
    width: boxW
    height: boxH
    z: dragging ? 10 : 0

    Item {
        id: stage
        anchors.fill: parent

    Rectangle {
        id: chrome
        width: win.boxW
        height: win.boxH
        radius: win.theme.radiusOuter
        color: win.bare ? "transparent" : win.theme.glassFill
        border.width: win.bare ? 0 : (win.selected ? 2 : 1)
        border.color: win.selected ? win.theme.accent : win.theme.glassHighlight
        clip: true

        Rectangle {
            z: -1
            anchors.fill: parent
            anchors.topMargin: 6
            color: "black"
            opacity: win.theme.isDarkMode ? 0.18 : 0.10
            visible: !win.bare
            radius: parent.radius
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: !win.bare
            color: "transparent"
            border.width: 1
            border.color: win.theme.isDarkMode ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.28)
        }

        Loader {
            id: body
            anchors.fill: parent
            sourceComponent: {
                switch (win.spec.type) {
                case "clock": return clockComp
                case "worldclock": return worldClockComp
                case "weather": return weatherComp
                case "calendar": return calendarComp
                case "media": return mediaComp
                case "stats": return statsComp
                case "notes": return notesComp
                case "todo": return todoComp
                case "pomodoro": return pomodoroComp
                case "cava": return cavaComp
                case "codexbar": return codexbarComp
                case "progress": return progressComp
                case "battery": return batteryComp
                case "photos": return photosComp
                case "voyager": return voyagerComp
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
                Lib.WidgetService.settingsOpen = false
                var p = mapToItem(win.parent, ev.x, ev.y)
                win.grabX = p.x - win.posX
                win.grabY = p.y - win.posY
                win.setDragging(true)
            }
            onPositionChanged: (ev) => {
                if (!pressed || !win.dragging) return
                var p = mapToItem(win.parent, ev.x, ev.y)
                win.posX = Math.round(Math.max(0, Math.min(win.screenW - win.boxW, p.x - win.grabX)))
                win.posY = Math.round(Math.max(0, Math.min(win.screenH - win.boxH, p.y - win.grabY)))
            }
            onReleased: {
                Lib.WidgetService.moveWidget(
                    win.outputKey, win.spec.id, win.posX, win.posY,
                    win.screenW, win.screenH)
                win.setDragging(false)
                win.syncFromSpec()
            }
            onCanceled: {
                win.setDragging(false)
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
            visible: win.selected
            width: 22; height: 22; radius: 6
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            color: settingsMa.containsMouse ? win.theme.accent : "#c4c4c4"
            z: 5
            Text {
                anchors.centerIn: parent
                text: "󰒓"
                font.family: win.theme.iconFont
                font.pixelSize: 13
                color: settingsMa.containsMouse ? win.theme.textOnAccent : "#3a3a3a"
            }
            MouseArea {
                id: settingsMa
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Lib.WidgetService.settingsOpen = !Lib.WidgetService.settingsOpen
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
                    var p = mapToItem(win.parent, ev.x, ev.y)
                    grabX = p.x
                    grabY = p.y
                    win.setDragging(true)
                }
                onPositionChanged: (ev) => {
                    if (!pressed || !win.dragging) return
                    var p = mapToItem(win.parent, ev.x, ev.y)
                    win.boxW = Math.max(Grid.span(1), Math.min(win.screenW - win.posX, startW + p.x - grabX))
                    win.boxH = Math.max(Grid.span(1), Math.min(win.screenH - win.posY, startH + p.y - grabY))
                }
                onReleased: {
                    Lib.WidgetService.resizeWidget(
                        win.outputKey, win.spec.id, win.boxW, win.boxH,
                        win.screenW, win.screenH)
                    win.setDragging(false)
                    win.syncFromSpec()
                }
                onCanceled: {
                    win.setDragging(false)
                    win.syncFromSpec()
                }
            }
        }
    }

    }

    Component {
        id: clockComp
        ClockWidget {
            theme: win.theme
            hour24: win.widgetSettings.hour24 === undefined ? true : win.widgetSettings.hour24
            showDate: win.widgetSettings.showDate === undefined ? true : win.widgetSettings.showDate
        }
    }
    Component {
        id: worldClockComp
        WorldClockWidget {
            theme: win.theme
            cities: win.widgetSettings.cities || "Australia/Sydney, UTC, America/New_York, Asia/Tokyo"
        }
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
        MediaWidget {
            theme: win.theme
            showArtwork: win.widgetSettings.showArtwork === undefined ? true : win.widgetSettings.showArtwork
        }
    }
    Component {
        id: statsComp
        StatsWidget { theme: win.theme; refreshSeconds: Number(win.widgetSettings.interval || 2) }
    }
    Component {
        id: notesComp
        NotesWidget {
            theme: win.theme
            text: win.widgetSettings.note || ""
            onNoteChanged: (t) => Lib.WidgetService.setSetting(win.outputKey, win.spec.id, "note", t)
        }
    }
    Component {
        id: todoComp
        TodoWidget {
            theme: win.theme
            items: win.widgetSettings.todos || []
            onTodosChanged: (list) => Lib.WidgetService.setSetting(win.outputKey, win.spec.id, "todos", list)
        }
    }
    Component {
        id: pomodoroComp
        PomodoroWidget {
            theme: win.theme
            sessionMin: Number(win.widgetSettings.sessionMin || 50)
            active: !!win.widgetSettings.active
            step: Number(win.widgetSettings.step || 0)
            running: !!win.widgetSettings.running
            endsAt: Number(win.widgetSettings.endsAt || 0)
            remainingMs: win.widgetSettings.remainingMs === undefined ? -1 : Number(win.widgetSettings.remainingMs)
            total: Number(win.widgetSettings.total || 0)
            focusMin: Number(win.widgetSettings.focusMin || 0)
            day: win.widgetSettings.day || ""
            onSessionChanged: (s) => Lib.WidgetService.setSettings(win.outputKey, win.spec.id, s)
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
    Component {
        id: batteryComp
        BatteryWidget {
            theme: win.theme
            showDetails: win.widgetSettings.showDetails === undefined ? true : win.widgetSettings.showDetails
        }
    }
    Component {
        id: voyagerComp
        VoyagerWidget { theme: win.theme }
    }
    Component {
        id: photosComp
        PhotosWidget { theme: win.theme; rotationMinutes: Number(win.widgetSettings.interval || 5) }
    }
}
