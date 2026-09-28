import QtQuick
import QtQuick.Layouts
import Quickshell
import "../lib" as Lib

Item {
    id: root
    required property QtObject theme

    WidgetLook { id: look; host: root }

    Lib.CommandPoll {
        id: weather
        running: true
        interval: 60000
        command: ["bash", "-lc", Qt.resolvedUrl("../lib/weather.sh").toString().replace("file://", "")]
        parse: function(out) {
            try {
                var d = JSON.parse(String(out))
                return { temp: d.temp ?? "--", icon: d.icon ?? "☁", desc: d.desc ?? "" }
            } catch (e) {
                return { temp: "--", icon: "☁", desc: "No data" }
            }
        }
    }

    Tile {
        anchors.fill: parent
        visible: look.small
        theme: root.theme
        icon: weather.value ? weather.value.icon : "☁"
        value: weather.value ? String(weather.value.temp) : "--"
        label: weather.value ? String(weather.value.desc) : ""
    }

    GridLayout {
        visible: !look.small
        anchors.centerIn: parent
        width: Math.max(0, parent.width - 24)
        columns: look.wide ? 2 : 1
        columnSpacing: 12
        rowSpacing: 4

        Text {
            text: weather.value ? weather.value.icon : "☁"
            font.family: root.theme.iconFont
            font.pixelSize: Math.max(24, Math.min(root.height * 0.32, root.width * 0.2, 72))
            color: root.theme.accent
            Layout.alignment: Qt.AlignHCenter
            Layout.rowSpan: look.wide ? 2 : 1
        }

        Text {
            text: weather.value ? String(weather.value.temp) : "--"
            font.family: root.theme.textFont
            font.pixelSize: Math.max(18, Math.min(root.height * 0.24, root.width * 0.14, 48))
            font.weight: 700
            color: root.theme.textPrimary
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            text: weather.value ? String(weather.value.desc) : ""
            font.family: root.theme.textFont
            font.pixelSize: 12
            font.weight: 500
            color: root.theme.textSecondary
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
