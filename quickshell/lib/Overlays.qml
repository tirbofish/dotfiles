pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Shared switches for overlays the shell keeps loaded. Spawning a second
// quickshell process per menu costs a full Qt and QML startup before anything
// draws, so these are in the running instance instead.
Scope {
    id: root

    property bool wifiOpen: false
    // Name of the screen that requested the wifi menu; the menu is only
    // instantiated per-screen, so this decides which instance shows itself.
    property string wifiScreen: ""
    property bool settingsOpen: false
    property string settingsPage: ""

    IpcHandler {
        target: "control"
        function wifi(screen: string): void { root.openWifi(screen) }
        function closeWifi(): void { root.wifiOpen = false }
        function wifiState(): string { return root.wifiOpen + ":" + root.wifiScreen }
        function settings(): void { root.openSettings() }
        function closeSettings(): void { root.settingsOpen = false }
        function settingsState(): string { return String(root.settingsOpen) }
    }

    function openWifi(screenName) {
        var name = String(screenName || "")
        if (!name && Quickshell.screens && Quickshell.screens.length)
            name = Quickshell.screens[0].name
        root.wifiScreen = name
        root.wifiOpen = false
        wifiOpenTimer.restart()
    }

    function openSettings() {
        root.settingsOpen = true
    }

    Timer {
        id: wifiOpenTimer
        interval: 1
        onTriggered: root.wifiOpen = true
    }
}
