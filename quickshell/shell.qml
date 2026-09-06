//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import "lib" as Lib
import "bars" as Bars
import "dock" as Dock
import "desktop" as Desktop
import "hub" as SystemHub

ShellRoot {
    // Keep persisted pointer settings applied even before the settings page opens.
    readonly property var inputService: Lib.InputService

    SystemHub.SettingsWindow {}

    // Hyprland forwards taskbar-style minimize requests but leaves policy to the shell.
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (!ev || ev.name !== "minimized") return
            const fields = ev.parse(2)
            if (fields.length === 2)
                Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/minimized-windows.sh",
                    fields[1] === "1" ? "hide" : "show", fields[0]])
        }
    }

    Timer {
        id: inputAfterMonitorUpdate
        interval: 1000
        onTriggered: Lib.InputService.refresh()
    }

    Connections {
        target: Lib.MonitorService
        function onMonitorApplied() {
            inputAfterMonitorUpdate.restart()
        }
    }

    GlobalShortcut {
        name: "widgetEdit"
        description: "Edit desktop widgets"
        onPressed: Lib.WidgetService.toggleEditing()
    }

    Variants {
        model: Quickshell.screens
        Scope {
            id: v
            property var modelData

            readonly property bool topStyle: Lib.Configuration.barStyle === "top"

            Lib.ThemeEngine {
                id: screenTheme
            }

            Desktop.ScreenBorder {
                id: border
                screen: v.modelData
                visible: !v.topStyle
                theme: screenTheme
            }

            LazyLoader {
                active: v.modelData === Quickshell.screens[0]
                Desktop.DesktopFiles {
                    screen: v.modelData
                    theme: screenTheme
                }
            }

            Variants {
                model: {
                    var _ = Lib.WidgetService.stamp
                    return Lib.WidgetService.widgetsOn(Lib.WidgetService.outputKeyForScreen(v.modelData))
                }
                Desktop.WidgetShell {
                    property var modelData
                    screen: v.modelData
                    theme: screenTheme
                    spec: modelData
                    outputKey: Lib.WidgetService.outputKeyForScreen(v.modelData)
                }
            }

            Desktop.EditBar {
                screen: v.modelData
                theme: screenTheme
                outputKey: {
                    var _ = Lib.WidgetService.stamp
                    return Lib.WidgetService.outputKeyForScreen(v.modelData)
                }
                outputName: v.modelData ? v.modelData.name : ""
            }

            // Held until the settings load
            Loader {
                id: barLoader
                active: Lib.Configuration.ready
                sourceComponent: v.topStyle ? topBarComponent : taskBarComponent
            }

            Component {
                id: taskBarComponent
                Bars.TaskBar {
                    screen: v.modelData
                    onHasWindowsChanged: border.setTopSidesVisible(!hasWindows)
                    onLauncherClicked: isDockMode ? appDrawer.toggle() : wideDrawer.toggle()
                    onRequestHubToggle: v.toggleHub()
                    onRequestHubBattery: v.openHubBattery()
                }
            }

            // The top bar keeps rofi as its launcher, so the dock drawers stay unused
            Component {
                id: topBarComponent
                Bars.TopBar {
                    screen: v.modelData
                    onRequestHubToggle: v.toggleHub()
                    onRequestHubBattery: v.openHubBattery()
                }
            }

            SystemHub.HubWindow {
                id: hubWindow
                screen: v.modelData
                visible: false
            }

            // PanelWindow is not an Item; LazyLoader creates/destroys the layer
            // so it maps already-visible instead of toggling a blank surface.
            LazyLoader {
                active: Lib.Overlays.wifiOpen &&
                    Lib.Overlays.wifiScreen === v.modelData.name
                Lib.WifiMenu {
                    screen: v.modelData
                    standalone: false
                    visible: true
                    onCloseRequested: Lib.Overlays.wifiOpen = false
                }
            }

            // Display picker, laptop panel only so it does not appear twice
            Loader {
                id: monitorPromptLoader
                active: v.modelData && v.modelData.name === Lib.MonitorService.promptOutput
                sourceComponent: Lib.MonitorPrompt {
                    theme: screenTheme
                    screen: v.modelData
                    onMoreOptionsRequested: {
                        hubWindow.showMonitors()
                        hubWindow.visible = true
                    }
                }
            }

            Connections {
                target: Lib.MonitorService
                function onGuestConnected(mon) {
                    if (monitorPromptLoader.item) monitorPromptLoader.item.open(mon)
                }
                function onKnownConnected(mon) {
                    if (monitorPromptLoader.item) monitorPromptLoader.item.notify(mon)
                }
                // Unplugged while the card was still up
                function onMonitorGone(name) {
                    var item = monitorPromptLoader.item
                    if (item && item.mon && item.mon.name === name) item.close()
                }
            }

            Lib.BrightnessOSD {
                theme: screenTheme
                screen: v.modelData
            }
            Lib.VolumeOSD {
                theme: screenTheme
                screen: v.modelData
            }
            Lib.ThemeOSD {
                theme: screenTheme
                screen: v.modelData
            }

            Dock.Drawer {
                id: appDrawer
                isDarkMode: screenTheme.isDarkMode
            }

            Dock.WideDrawer {
                id: wideDrawer
                theme: screenTheme
            }

            function toggleHub() {
                if (hubWindow.visible) {
                    // Route through closeAll() so the exit animation plays before hiding
                    hubWindow.closeAll()
                } else {
                    // HubWindow.onVisibleChanged grabs keyboard focus on its inner
                    // Item; PanelWindow itself has no forceActiveFocus().
                    hubWindow.visible = true
                }
            }

            function openHubBattery() {
                hubWindow.showBattery()
                if (!hubWindow.visible)
                    hubWindow.visible = true
            }

            GlobalShortcut {
                name: "hubToggle"
                description: "Toggle hub"
                onPressed: v.toggleHub()
            }

            // rofi is the launcher in top style, so this only binds for the taskbar
            GlobalShortcut {
                name: "drawerToggle"
                description: "Toggle app drawer"
                onPressed: {
                    if (v.topStyle) Quickshell.execDetached(["bash", "-c",
                        "pkill -x rofi || ~/.config/rofi/launcher.sh"])
                    else wideDrawer.toggle()
                }
            }

            // Picker if an unconfigured screen is waiting, otherwise the hub panel
            GlobalShortcut {
                name: "monitorPicker"
                description: "Display layout"
                onPressed: {
                    var pending = Lib.MonitorService.pending
                    if (pending && monitorPromptLoader.item) {
                        monitorPromptLoader.item.open(pending)
                    } else {
                        hubWindow.showMonitors()
                        if (!hubWindow.visible) hubWindow.visible = true
                    }
                }
            }
        }
    }
}
