import QtQuick
import "../lib" as Lib

Item {
    id: root
    required property QtObject theme

    Lib.CavaVisualizer {
        anchors.fill: parent
        anchors.margins: 12
        compact: false
        barMax: Math.max(16, height - 8)
        backdrop: true
        centerBars: true
        bg: "transparent"
        accent: root.theme.accent
        border: "transparent"
    }
}
