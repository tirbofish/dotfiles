import QtQuick
import QtQuick.Layouts
import "../lib" as Lib

Item {
    id: root
    required property QtObject theme
    property bool showDetails: true
    readonly property var info: battery.value || ({})
    readonly property int percent: Number(info.batPct || 0)

    WidgetLook { id: look; host: root }

    Lib.CommandPoll {
        id: battery
        interval: 10000
        command: ["python3", Qt.resolvedUrl("../lib/sysinfo.py").toString().replace("file://", "")]
        parse: function(output) {
            try { return JSON.parse(String(output || "{}").trim()) }
            catch (e) { return root.info }
        }
    }

    Tile {
        anchors.fill: parent
        visible: look.small
        theme: root.theme
        tint: root.percent < 20 ? root.theme.accentRed : root.theme.accent
        icon: info.acOnline ? "󰂄" : (root.percent < 20 ? "󰂃" : "󰁹")
        value: root.percent + "%"
        label: info.batStatus || ""
    }

    ColumnLayout {
        visible: !look.small
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        Item { Layout.fillHeight: true }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                visible: !look.column
                text: info.acOnline ? "󰂄" : (root.percent < 20 ? "󰂃" : "󰁹")
                font.family: root.theme.iconFont
                font.pixelSize: 30
                color: root.percent < 20 ? root.theme.accentRed : root.theme.accent
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: -2
                Text {
                    Layout.fillWidth: true
                    text: root.percent + "%"
                    font.family: root.theme.textFont
                    font.pixelSize: look.column ? 24 : 28
                    font.weight: 800
                    color: root.theme.textPrimary
                    horizontalAlignment: look.column ? Text.AlignHCenter : Text.AlignLeft
                }
                Text {
                    Layout.fillWidth: true
                    text: (info.acOnline && look.column ? "󰂄 " : "") + (info.batStatus || "No battery")
                    font.family: root.theme.textFont
                    font.pixelSize: 11
                    color: root.theme.textSecondary
                    horizontalAlignment: look.column ? Text.AlignHCenter : Text.AlignLeft
                    elide: Text.ElideRight
                }
            }
            Text {
                visible: root.showDetails && !look.column && Number(info.powerW || 0) > 0
                text: Number(info.powerW || 0).toFixed(1) + " W"
                font.family: root.theme.textFont
                font.pixelSize: 12
                color: root.theme.textSecondary
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 8
            radius: 4
            color: root.theme.subtleFill
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.percent / 100))
                height: parent.height
                radius: parent.radius
                color: root.percent < 20 ? root.theme.accentRed : root.theme.accent
                Behavior on width { NumberAnimation { duration: 220 } }
            }
        }

        // Details need a second grid row (or a wide strip) to breathe.
        GridLayout {
            visible: root.showDetails && (look.rows > 1 || look.cols > 2)
            Layout.fillWidth: true
            columns: look.column ? 1 : 2
            rowSpacing: 2
            Text {
                Layout.fillWidth: true
                text: "Health " + (info.batHealth || "—") + "%"
                font.family: root.theme.textFont
                font.pixelSize: 11
                color: root.theme.textSecondary
                horizontalAlignment: look.column ? Text.AlignHCenter : Text.AlignLeft
            }
            Text {
                Layout.fillWidth: true
                text: (info.cycles || "—") + " cycles"
                font.family: root.theme.textFont
                font.pixelSize: 11
                color: root.theme.textSecondary
                horizontalAlignment: look.column ? Text.AlignHCenter : Text.AlignRight
            }
        }
        Item { Layout.fillHeight: true }
    }
}
