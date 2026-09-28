import QtQuick
import "../lib" as Lib

// No card behind it (see WidgetShell.bare); bars multiply as it widens.
Item {
    id: root
    required property QtObject theme

    Lib.CavaVisualizer {
        anchors.fill: parent
        anchors.margins: 6
        compact: false
        backdrop: true
        centerBars: true
        requestedBarCount: Math.max(6, Math.min(Lib.CavaService.barCount, Math.round(width / 14)))
        bg: "transparent"
        accent: root.theme.accent
        border: "transparent"
    }
}
