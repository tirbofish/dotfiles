import QtQuick
import QtQuick.Layouts
import "../lib" as Lib

Item {
    id: root
    required property QtObject theme
    property string cities: "Australia/Sydney, UTC, America/New_York, Asia/Tokyo"
    readonly property var clocks: times.value || []

    WidgetLook { id: look; host: root }

    Lib.CommandPoll {
        id: times
        interval: 30000
        command: ["python3", Qt.resolvedUrl("../lib/worldclock.py").toString().replace("file://", ""), root.cities]
        onCommandChanged: poll()
        parse: function(output) {
            try { return JSON.parse(String(output || "[]")) }
            catch (e) { return [] }
        }
    }

    Tile {
        anchors.fill: parent
        visible: look.small
        theme: root.theme
        value: root.clocks.length ? root.clocks[0].time : "--:--"
        label: root.clocks.length ? root.clocks[0].city : ""
    }

    ColumnLayout {
        visible: !look.small
        anchors.fill: parent
        anchors.margins: look.row ? 10 : 14
        spacing: 4

        Text {
            visible: !look.row && !look.column
            text: "World Clocks"
            font.family: root.theme.textFont
            font.pixelSize: 14
            font.weight: 800
            color: root.theme.textPrimary
            Layout.fillWidth: true
        }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            interactive: !Lib.WidgetService.editing
            cellWidth: look.row ? Math.max(130, width / Math.max(1, Math.floor(width / 130)))
                : look.wide ? Math.max(140, width / 2) : width
            cellHeight: look.column ? 46 : 36
            model: root.clocks
            delegate: Item {
                required property var modelData
                width: grid.cellWidth
                height: grid.cellHeight
                // 1×N column: city stacked over time.
                GridLayout {
                    anchors.fill: parent
                    anchors.rightMargin: look.wide ? 10 : 0
                    columns: look.column ? 1 : 3
                    rowSpacing: -2
                    columnSpacing: 8
                    Text {
                        text: modelData.city
                        font.family: root.theme.textFont
                        font.pixelSize: 12
                        font.weight: 600
                        color: root.theme.textPrimary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        visible: !look.column
                        text: modelData.day
                        font.family: root.theme.textFont
                        font.pixelSize: 10
                        color: root.theme.textSecondary
                    }
                    Text {
                        text: modelData.time
                        font.family: root.theme.textFont
                        font.pixelSize: 17
                        font.weight: 700
                        color: root.theme.accent
                        Layout.preferredWidth: look.column ? -1 : 58
                        horizontalAlignment: look.column ? Text.AlignLeft : Text.AlignRight
                    }
                }
            }
        }
    }
}
