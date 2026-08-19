pragma Singleton
import QtQuick
import Quickshell

// Shared switches for overlays the shell keeps loaded. Spawning a second
// quickshell process per menu costs a full Qt and QML startup before anything
// draws, so these are in the running instance instead.
Scope {
    id: root

    property bool wifiOpen: false
    // Name of the screen that requested the wifi menu; the menu is only
    // instantiated per-screen, so this decides which instance shows itself.
    property string wifiScreen: ""

    function openWifi(screenName) {
        root.wifiScreen = String(screenName || "")
        root.wifiOpen = false
        wifiOpenTimer.restart()
    }

    Timer {
        id: wifiOpenTimer
        interval: 1
        onTriggered: root.wifiOpen = true
    }
}
