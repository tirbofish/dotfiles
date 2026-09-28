import QtQuick
import QtQuick.Layouts
import "../lib" as Lib

Item {
    id: root
    required property QtObject theme

    WidgetLook { id: look; host: root }

    Tile {
        anchors.fill: parent
        visible: look.small
        theme: root.theme
        icon: "󰚩"
        label: "Codex"
    }

    ColumnLayout {
        visible: !look.small
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "CodexBar"
                font.family: root.theme.textFont
                font.pixelSize: 12
                font.weight: 700
                color: root.theme.accent
                Layout.fillWidth: true
            }
            Text {
                text: Lib.CodexBarService.loading ? "…" : (Lib.CodexBarService.updatedAt || "")
                font.family: root.theme.textFont
                font.pixelSize: 10
                color: root.theme.textSecondary
            }
        }

        Lib.CodexBarPanel {
            theme: root.theme
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
