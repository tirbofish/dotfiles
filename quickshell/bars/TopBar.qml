import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import Quickshell.Hyprland

import "../lib" as Lib

PanelWindow {
    id: win
    signal requestHubToggle()
    signal requestHubBattery()

    anchors { top: true; left: true; right: true }
    height: 40
    color: "transparent"

    readonly property bool isDarkMode: theme.isDarkMode

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusiveZone: height
    WlrLayershell.namespace: "shell-bar"
//--------------------------------------------------------------------------------
    function sh(cmd) { return ["bash", "-c", cmd] }
    function det(cmd) { Quickshell.execDetached(sh(cmd)) }

    readonly property var screenMonitor: {
        var monitors = Hyprland.monitors?.values ?? []
        for (var i = 0; i < monitors.length; i++)
            if (screen && monitors[i].name === screen.name) return monitors[i]
        return null
    }
    readonly property var workspaces: {
        var all = Hyprland.workspaces?.values ?? []
        return all.filter(function(workspace) {
            return workspace && workspace.id > 0 && workspace.monitor
                && screen && workspace.monitor.name === screen.name
        }).sort(function(a, b) { return a.id - b.id })
    }
    function workspaceIndex(id) {
        for (var i = 0; i < workspaces.length; i++)
            if (workspaces[i].id === id) return i
        return -1
    }
    readonly property int activeWsId: {
        var active = Number(screenMonitor?.activeWorkspace?.id ?? 0)
        return active > 0 ? active : (workspaces.length ? workspaces[0].id : 0)
    }

    Lib.ThemeEngine {
        id: theme
    }

    // Mirrors the taskbar palette
    QtObject {
        id: pal
        property color bg:             Qt.rgba(theme.bgCard.r, theme.bgCard.g, theme.bgCard.b, 0.78)
        property color textPrimary:    String(theme.textPrimary)
        property color textSecondary:  String(theme.textSecondary)
        property color accent:         String(Lib.Configuration.taskbarAccent)
        property color activePill:     String(Lib.Configuration.taskbarAccent)
        property color hoverSpotlight: String(theme.hoverSpotlight)
        property color border:         String(theme.outline)

        property color hoverPillG0: Qt.rgba(Lib.Configuration.taskbarAccent.r, Lib.Configuration.taskbarAccent.g, Lib.Configuration.taskbarAccent.b, 0.35)
        property color hoverPillG1: Qt.rgba(Lib.Configuration.taskbarAccent.r, Lib.Configuration.taskbarAccent.g, Lib.Configuration.taskbarAccent.b, 0.55)
        property color hoverPillG2: Qt.rgba(Lib.Configuration.taskbarAccent.r, Lib.Configuration.taskbarAccent.g, Lib.Configuration.taskbarAccent.b, 0.35)
    }

    // 3. HYPRLAND CACHE
    QtObject {
        id: hyCache
        property var wsMap: ({}) // wsId
        property int minimizedCount: 0
        property bool pending: false

        function rebuild() {
            const m = {}
            var minimized = 0
            const list = Hyprland.toplevels?.values ?? []
            for (const tl of list) {
                if (tl?.workspace?.name === "special:minimized") minimized++
                const id = tl?.workspace?.id
                if (!id) continue
                if (!m[id]) m[id] = []
                m[id].push(tl)
            }
            wsMap = m
            minimizedCount = minimized
        }

        // Collapses burst events into 1 rebuild per frame
        function scheduleRebuild() {
            if (pending) return
            pending = true
            Qt.callLater(() => {
                pending = false
                rebuild()
            })
        }

        Component.onCompleted: rebuild()
    }

    // 4. HYPR POLLERS
    Timer {
        interval: 500
        running: true; repeat: false
        onTriggered: hyCache.rebuild()
    }

    // Safety Check at 2s
    Timer {
        interval: 2000
        running: true; repeat: false
        onTriggered: hyCache.rebuild()
    }

    // 5. Event Listener + scheduleRebuild)
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (!ev || !ev.name) return

            // Check for events
            if (ev.name === "openwindow" || ev.name === "closewindow" ||
                ev.name === "movewindowv2" || ev.name === "urgent") {

                // Re-fetch the window list from Hyprland immediately
                Hyprland.refreshToplevels()
                hyCache.scheduleRebuild()
            }
        }
    }

    // POLLERS
    // 6.2 BATTERY %, STATUS POLLER
    Lib.CommandPoll {
        id: powerPoll
        interval: {
            const s = String(batStatus.value ?? "").trim()
            const cap = Number(batCap.value ?? 0)
            if (s === "Discharging" && cap <= 20) return 2000
            return 6000
        }
        command: ["bash","-lc", `
            cap=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1)
            status=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1)
            ac=$(cat /sys/class/power_supply/AC*/online /sys/class/power_supply/ADP*/online 2>/dev/null | head -n1)
            echo "$cap|$status|$ac"
        `]
        parse: function(o) {
            var s = String(o ?? "").trim()
            var p = s.split("|")
            return { cap: Number(p[0]) || 0, status: (p[1] || "").trim(), ac: (p[2] || "").trim() }
        }
    }

    // 6.2.1 Battery Notifications
    QtObject {
        id: batLogic
        property bool f20: false
        property bool f10: false

        function check(cap, status) {
            if (status !== "Discharging") {
                f20 = false; f10 = false; return
            }
            if (cap === 0) return
            // Critical 10%
            if (cap <= 10 && !f10) {
                win.det("notify-send -u critical 'Battery Critically Low' 'Please Plug in your Charger'")
                f10 = true; f20 = true
            // Warning 20%
            } else if (cap <= 20 && cap > 10 && !f20) {
                win.det("notify-send 'Battery Low' 'Please Plug in your Charger'")
                f20 = true
            }
        }
    }
    QtObject {
        id: batCap
        property var value: (powerPoll.value ? powerPoll.value.cap : 0)
        onValueChanged: batLogic.check(value, batStatus.value)
    }
    QtObject {
        id: batStatus
        property var value: (powerPoll.value ? powerPoll.value.status : "")
        onValueChanged: batLogic.check(batCap.value, value)
    }
    QtObject { id: acOnline; property var value: (powerPoll.value ? powerPoll.value.ac : "") }

    Lib.CommandPoll {
        id: wifiConnected
        interval: 3000
        command: win.sh("nmcli -t -f ACTIVE dev wifi 2>/dev/null | grep -q '^yes$' && echo 1 || echo 0")
        parse: function(o) { return String(o).trim() === "1" }
    }

    Lib.CommandPoll {
        id: bluetoothOn
        interval: 3000
        command: win.sh("rfkill list bluetooth 2>/dev/null | grep -q 'Soft blocked: no' && echo 1 || echo 0")
        parse: function(o) { return String(o).trim() === "1" }
    }

    Lib.CommandPoll {
        id: bluetoothConnections
        interval: 2500
        command: win.sh("bluetoothctl devices Connected 2>/dev/null | wc -l")
        parse: function(o) { return Number(String(o).trim()) || 0 }
    }

// ------------------ THE BAR ---------------------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        color: "transparent"

        RowLayout {
            anchors.fill: parent
            spacing: 10
// LEFT----------------------------------------------------------------------------------------------------------

            // 7. LAUNCHER
            Item {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                Layout.alignment: Qt.AlignVCenter
                scale: launchPress.pressed ? 0.94 : 1.0
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }
                HoverHandler { id: hoverLaunch }
                
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.rgba(launchIcon.color.r, launchIcon.color.g, launchIcon.color.b, 1)
                    opacity: launchPress.pressed ? 0.10 : (hoverLaunch.hovered ? 0.08 : 0.0)
                    Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }

                Item {
                    id: launchIcon
                    anchors.centerIn: parent
                    width: 22; height: 22
                    property color color: {
                        if (hoverLaunch.hovered) return win.isDarkMode ? "#89b4fa" : "#1e66f5"
                        return win.isDarkMode ? "#89b4fa" : "#1e66f5"
                    }

                    Image { 
                        id: lImg
                        source: "../lib/arch.svg"
                        visible: false
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        // Rasterize at 2x (44px) relative to container (22px)
                        sourceSize: Qt.size(44, 44)
                        smooth: false
                    }
                    ColorOverlay {
                        anchors.fill: parent
                        source: lImg
                        color: parent.color
                        cached: true
                        antialiasing: true
                    }
                    rotation: hoverLaunch.hovered ? -14 : 0
                    scale: hoverLaunch.hovered ? 1.20 : 1.0
                    y: hoverLaunch.hovered ? -2 : 0
                    Behavior on rotation { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }
                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }
                    Behavior on y { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 160 } }
                }
                MouseArea {
                    id: launchPress
                    anchors.fill: parent
                    hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) win.det("pkill -x rofi || " + (win.isDarkMode ? "~/.config/rofi/launcher.sh" : "~/.config/rofi/launcher_2.sh"))
                        else if (mouse.button === Qt.RightButton) theme.toggle()
                    }
                }
            }

            // 8. WORKSPACES
            Rectangle {
                id: wsContainer
                Layout.preferredHeight: 34
                Layout.preferredWidth: wsRow.width + 22
                Layout.alignment: Qt.AlignVCenter
                radius: 17
                color: pal.bg
                clip: true
                Behavior on Layout.preferredWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                property int hoveredId: 0
                property var hoveredItem: wsRepeater.itemAt(win.workspaceIndex(hoveredId))
                property int pressedId: 0
                property var pressedItem: wsRepeater.itemAt(win.workspaceIndex(pressedId))
                // Re-evaluate the active pill once Repeater has created its delegates.
                property int delegateRevision: 0

                // ACTIVE PILL
                Rectangle {
                    id: activePill
                    property int currentId: win.activeWsId
                    property var targetItem: {
                        wsContainer.delegateRevision
                        return wsRepeater.itemAt(win.workspaceIndex(currentId))
                    }
                    x: targetItem ? (wsRow.x + targetItem.x) : 0
                    width: targetItem ? targetItem.width : 0
                    height: 22
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 13
                    color: pal.activePill
                    Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                }

                // HOVER PILL
                Item {
                    id: hoverPillLayer
                    anchors.fill: parent
                    visible: wsContainer.hoveredId > 0 && wsContainer.hoveredId !== win.activeWsId
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    Rectangle {
                        property var t: wsContainer.hoveredItem
                        x: t ? (wsRow.x + t.x) : 0; width: t ? t.width : 0; height: 25
                        anchors.verticalCenter: parent.verticalCenter; radius: 13
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: pal.hoverPillG0 }
                            GradientStop { position: 0.45; color: pal.hoverPillG1 }
                            GradientStop { position: 1.0; color: pal.hoverPillG2 }
                        }
                        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.10 } }
                        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }
                    }
                }

                Item {
                    id: pressPillLayer
                    anchors.fill: parent
                    visible: wsContainer.pressedId > 0
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

                    Rectangle {
                        property var t: wsContainer.pressedItem
                        x: t ? (wsRow.x + t.x) : 0
                        width: t ? t.width : 0
                        height: 25
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 13
                        color: Qt.rgba(pal.textPrimary.r, pal.textPrimary.g, pal.textPrimary.b, 1)
                        opacity: 0.10
                        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                        Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }
                }

                Row {
                    id: wsRow
                    anchors.left: parent.left
                    anchors.leftMargin: 11
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Repeater {
                        id: wsRepeater
                        model: win.workspaces
                        onItemAdded: wsContainer.delegateRevision++
                        Item {
                            id: wsDelegate
                            required property var modelData
                            property int wsId: modelData.id
                            property bool isActive: win.activeWsId === wsId

                            // --- READ FROM CACHE ---
                            property var wsWindows: hyCache.wsMap[wsId] ?? []
                            property int winCount: wsWindows.length
                            property bool hasWindows: winCount > 0
                            property bool isUrgent: wsWindows.some(tl => tl.urgent)

                            width: hasWindows ? (winCount * 22 + 12) : 26
                            height: 34

                            HoverHandler {
                                id: wsHover
                                onHoveredChanged: {
                                    if (hovered) wsContainer.hoveredId = wsId
                                    else if (wsContainer.hoveredId === wsId) wsContainer.hoveredId = 0
                                }
                            }

                            y: wsPress.pressed ? 1 : ((!isActive && wsHover.hovered) ? -2 : 0)
                            scale: (wsPress.pressed ? 0.96 : 1.0) * ((!isActive && wsHover.hovered) ? 1.10 : 1.0)
                            Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }

                            Text {
                                anchors.centerIn: parent
                                visible: !wsDelegate.hasWindows
                                text: "•"
                                font.family: theme.iconFont; font.pixelSize: 14; lineHeight: 0.8
                                verticalAlignment: Text.AlignVCenter
                                Behavior on color { ColorAnimation { duration: 140 } }
                                color: isActive ? "#2d353b" : (wsHover.hovered ? (win.isDarkMode ? "#f2f2f2" : pal.accent) : (win.isDarkMode ? "#d5c9b2" : "#5c6a72"))
                            }

                            Row {
                                anchors.centerIn: parent; spacing: 0
                                visible: wsDelegate.hasWindows
                                Repeater {
                                    model: wsDelegate.wsWindows
                                    Item {
                                        id: appSlot
                                        width: 22; height: 22

                                        // --- ipc ---
                                        property string safeClass: {
                                            const o = modelData?.lastIpcObject;
                                            var c = o?.class ?? "";
                                            if (!c) c = o?.initialClass ?? "";
                                            if (!c) c = o?.initialTitle ?? "";
                                            if (!c) c = modelData?.title ?? "";
                                            return String(c);
                                        }
                                        property var appIcon: Lib.AppIcons.lookup(safeClass)
                                        property bool iconTinted: !!appIcon.tint
                                        property bool iconFailed: customAppIcon.status === Image.Error
                                        property color appColor: (wsDelegate.isActive ? appIcon.activeColor : appIcon.inactiveColor) || (wsDelegate.isActive ? "#2d353b" :
                                                                 (modelData.urgent ? flashColor.val :
                                                                 (wsHover.hovered ? (win.isDarkMode ? "#f2f2f2" : pal.accent) :
                                                                 (win.isDarkMode ? "#d5c9b2" : "#1e2326"))))

                                        QtObject {
                                            id: flashColor
                                            property color val: win.isDarkMode ? "#d5c9b2" : "#1e2326"
                                            SequentialAnimation on val {
                                                running: modelData.urgent
                                                loops: Animation.Infinite
                                                ColorAnimation { to: "#e67e80"; duration: 200 }
                                                ColorAnimation { to: "#dbbc7f"; duration: 200 }
                                            }
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            visible: parent.appIcon.source === "" || parent.iconFailed
                                            text: parent.appIcon.glyph || ""
                                            font.family: theme.iconFont; font.pixelSize: 18; lineHeight: 0.8
                                            verticalAlignment: Text.AlignVCenter
                                            font.hintingPreference: Font.PreferNoHinting
                                            layer.enabled: true
                                            layer.smooth: true
                                            layer.mipmap: true
                                            Behavior on color { enabled: !modelData.urgent; ColorAnimation { duration: 140 } }
                                            scale: (wsDelegate.isActive && wsHover.hovered) ? 1.25 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.5 } }
                                            color: parent.appColor
                                        }
                                        Image {
                                            id: customAppIcon
                                            anchors.centerIn: parent
                                            width: 18; height: 18
                                            visible: parent.appIcon.source !== "" && !parent.iconFailed
                                            source: parent.appIcon.source
                                            sourceSize: Qt.size(36, 36)
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                            layer.enabled: visible && parent.iconTinted
                                            layer.smooth: true
                                            layer.effect: ColorOverlay { color: appSlot.appColor }
                                        }

                                    }
                                }
                            }
                            MouseArea {
                                id: wsPress
                                anchors.fill: parent
                                hoverEnabled: true
                                onPressed: wsContainer.pressedId = wsId
                                onReleased: if (wsContainer.pressedId === wsId) wsContainer.pressedId = 0
                                onCanceled: if (wsContainer.pressedId === wsId) wsContainer.pressedId = 0
                                onClicked: det("hyprctl dispatch 'hl.dsp.focus({ workspace = " + wsId + " })'")
                            }
                        }
                    }
                }
            }
//------------------------------------------------- CENTER -----------------------------------------------------

            // 9. MEDIA & TITLE
            Item {
                id: mediaCenter
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: false
                property var player: Mpris.players.values[0] ?? null
                property bool isPlaying: player && player.playbackState === MprisPlaybackState.Playing
                property string trackTitle: player ? player.trackTitle : ""
                property string trackArtist: player ? player.trackArtist : ""
                property string nowPlaying: {
                    var t = trackTitle || ""
                    var a = trackArtist || ""
                    if (t && a) return t + " <font color='" + pal.textSecondary + "'>- " + a + "</font>"
                    return t || a || "Playing"
                }

                Item {
                    id: cavaHost
                    visible: mediaCenter.isPlaying
                    anchors.left: parent.left
                    anchors.right: parent.right
                    y: -4
                    height: win.height
                    z: 0

                    Lib.CavaVisualizer {
                        id: hangingCava
                        anchors.fill: parent
                        backdrop: true
                        requestedBarCount: Math.max(12, Math.min(64, Math.round(cavaHost.width / 24)))
                        accent: pal.accent
                        layer.enabled: true
                        layer.smooth: true
                        layer.effect: OpacityMask { maskSource: cavaEdgeMask }
                    }

                    Rectangle {
                        id: cavaEdgeMask
                        anchors.fill: parent
                        visible: false
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.00; color: "#00ffffff" }
                            GradientStop { position: 0.08; color: "#ffffffff" }
                            GradientStop { position: 0.92; color: "#ffffffff" }
                            GradientStop { position: 1.00; color: "#00ffffff" }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: !mediaCenter.isPlaying
                    z: 1
                    text: Hyprland.activeToplevel?.title ?? "Desktop"
                    font.family: theme.iconFont
                    font.weight: 700
                    font.pixelSize: 13
                    color: pal.textPrimary
                    width: Math.min(implicitWidth, Math.max(80, parent.width - 16))
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }

                Row {
                    visible: mediaCenter.isPlaying
                    anchors.centerIn: parent
                    spacing: 8
                    z: 1
                    layer.enabled: true
                    layer.effect: DropShadow {
                        transparentBorder: true
                        horizontalOffset: 0
                        verticalOffset: 1
                        radius: 10
                        samples: 20
                        color: win.isDarkMode ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(1, 1, 1, 0.45)
                    }

                    Text {
                        text: ""
                        font.family: theme.iconFont
                        font.pixelSize: 14
                        color: pal.accent
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: mediaCenter.nowPlaying
                        textFormat: Text.StyledText
                        font.family: theme.iconFont
                        font.weight: 700
                        font.pixelSize: 13
                        color: pal.textPrimary
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, Math.max(80, mediaCenter.width - 44))
                        verticalAlignment: Text.AlignVCenter
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

//----------------------------------------------------------------------------------------RIGHT----------

            Item {
                id: minimizedButton
                readonly property bool shown: hyCache.minimizedCount > 0
                Layout.preferredWidth: shown ? 52 : 0
                Layout.preferredHeight: 34
                opacity: shown ? 1 : 0
                scale: shown ? 1 : 0.55
                visible: opacity > 0

                Behavior on Layout.preferredWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.25 } }

                TopBarItem {
                    anchors.fill: parent
                    icon: "󰖰"
                    text: String(hyCache.minimizedCount)
                    bgColor: pal.bg
                    iconColor: pal.accent
                    textColor: pal.accent
                    borderWidth: 0
                    borderColor: "transparent"
                    hoverColor: pal.hoverSpotlight
                    onClicked: win.det("~/.config/hypr/scripts/minimized-windows.sh menu")
                }
            }

            TopBarItem {
                id: wifiItem
                Layout.preferredWidth: 34
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                iconSource: wifiConnected.value ? "../lib/wifi_connected.svg" : "../lib/wifi_off.svg"
                bgColor: pal.bg
                iconColor: wifiConnected.value ? pal.accent : pal.textSecondary
                borderWidth: 0
                borderColor: "transparent"
                hoverColor: pal.hoverSpotlight

                SequentialAnimation on iconScale {
                    running: Boolean(wifiConnected.value)
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) wifiItem.iconScale = 1.0
                    NumberAnimation { to: 1.12; duration: 850; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 850; easing.type: Easing.InOutSine }
                }

                onClicked: {
                    var name = win.screen ? win.screen.name : ""
                    if (Lib.Overlays.wifiOpen && Lib.Overlays.wifiScreen === name)
                        Lib.Overlays.wifiOpen = false
                    else
                        Lib.Overlays.openWifi(name)
                }
            }

            TopBarItem {
                id: bluetoothItem
                Layout.preferredWidth: 34
                property int previousConnections: -1
                iconSource: bluetoothConnections.value > 0 ? "../lib/bt_connected.svg"
                    : (bluetoothOn.value ? "../lib/bt_on.svg" : "../lib/bt_off.svg")
                bgColor: pal.bg
                iconColor: bluetoothConnections.value > 0 ? pal.accent : pal.textSecondary
                borderWidth: 0
                borderColor: "transparent"
                hoverColor: pal.hoverSpotlight

                Connections {
                    target: bluetoothConnections
                    function onUpdated() {
                        const count = Number(bluetoothConnections.value) || 0
                        if (bluetoothItem.previousConnections >= 0 &&
                            count !== bluetoothItem.previousConnections &&
                            !(bluetoothItem.previousConnections === 0 && count > 0)) {
                            bluetoothBounce.restart()
                        }
                        bluetoothItem.previousConnections = count
                    }
                }

                SequentialAnimation on iconScale {
                    running: bluetoothConnections.value > 0
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) bluetoothItem.iconScale = 1.0
                    NumberAnimation { to: 1.12; duration: 850; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 850; easing.type: Easing.InOutSine }
                }

                SequentialAnimation {
                    id: bluetoothBounce
                    NumberAnimation { target: bluetoothItem; property: "iconY"; to: -4; duration: 120; easing.type: Easing.OutCubic }
                    NumberAnimation { target: bluetoothItem; property: "iconY"; to: 0; duration: 260; easing.type: Easing.OutBounce }
                }

                onClicked: win.det("blueman-manager")
            }

            // 12. BATTERY
            TopBarItem {
                id: batteryItem
                Layout.preferredWidth: 74
                property string status: String(batStatus.value).trim()
                property int rawCap: Number(batCap.value) || 0
                property int cap: (rawCap === 0 && status !== "Discharging") ? 50 : rawCap
                property bool plugged: (String(acOnline.value).trim() === "1")
                property bool isCharging: plugged || status === "Charging" || status === "Full"

                property string battColor: {
                    const dark = win.isDarkMode;
                    if (isCharging) return pal.accent;
                    const crit = dark ? '#ff0004' : '#ff001e';
                    const low  = dark ? "#e69875" : '#a55524';
                    const mid  = dark ? "#dbbc7f" : "#7a5b00";
                    if (cap <= 10) return crit;
                    if (cap <= 20) return low;
                    if (cap <= 30) return mid;
                    return pal.textPrimary;
                }
                property string dynamicIcon: {
                    if (isCharging) return "󰂄"
                    if (cap >= 98) return "󰁹"
                    if (cap >= 90) return "󰂂"; if (cap >= 80) return "󰂁"
                    if (cap >= 70) return "󰂀"; if (cap >= 60) return "󰁿"
                    if (cap >= 50) return "󰁾"; if (cap >= 40) return "󰁽"
                    if (cap >= 30) return "󰁼"; if (cap >= 20) return "󰁻"
                    return "󰁺"
                }

                icon: dynamicIcon; text: cap + "%"
                bgColor: pal.bg; iconColor: battColor; textColor: battColor
                borderWidth: 0; borderColor: "transparent"; hoverColor: pal.hoverSpotlight

                SequentialAnimation {
                    running: batteryItem.cap <= 10 && !batteryItem.isCharging
                    loops: Animation.Infinite
                    NumberAnimation { target: batteryItem; property: "opacity"; to: 0.3; duration: 500 }
                    NumberAnimation { target: batteryItem; property: "opacity"; to: 1.0; duration: 500 }
                }

                Rectangle {
                    id: powerSurge
                    anchors.centerIn: parent; width: parent.width; height: parent.height
                    radius: parent.height / 2; color: "transparent"
                    border.width: 0; border.color: "transparent"
                    opacity: 0; scale: 1.0
                }
                onPluggedChanged: if (plugged) surgeAnim.restart()
                ParallelAnimation {
                    id: surgeAnim
                    NumberAnimation { target: powerSurge; property: "scale"; from: 1.0; to: 1.45; duration: 520; easing.type: Easing.OutCubic }
                    NumberAnimation { target: powerSurge; property: "opacity"; from: 1.0; to: 0.0; duration: 520; easing.type: Easing.OutCubic }
                }

                onClicked: win.requestHubBattery()
            }

            // 13. CLOCK/DATE
            Item {
                id: clockContainer
                Layout.preferredHeight: 34
                Layout.preferredWidth: clockRow.implicitWidth + 30
                
                scale: clockArea.pressed ? 0.98 : (clockArea.containsMouse ? 1.02 : 1.0)
                y: clockArea.pressed ? 1 : 0
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.05 } }
                Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                // MASKED BACKGROUND LAYER 
                Item {
                    anchors.fill: parent
                    layer.enabled: true
                    layer.effect: OpacityMask { maskSource: clockMask }

                    Rectangle {
                        anchors.fill: parent
                        color: pal.bg
                    }

                    // Shimmer 
                    Rectangle {
                        id: clockShimmer
                        width: 44; height: parent.height * 2; rotation: 20
                        x: -100; y: -parent.height/2
                        color: "transparent"
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.5; color: win.isDarkMode ? Qt.rgba(1,1,1,0.20) : Qt.rgba(0,0,0,0.1) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }
                    
                    Rectangle {
                        anchors.fill: parent
                        color: win.isDarkMode ? "#ffffff" : "#000000"
                        opacity: clockArea.pressed ? 0.18 : (clockArea.containsMouse ? 0.12 : 0.0)
                        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }
                }

                // Mask Source (Hidden)
                Rectangle {
                    id: clockMask
                    anchors.fill: parent
                    radius: 17
                    visible: false
                    antialiasing: true
                }

                // CONTENT (Unmasked)
                RowLayout {
                    id: clockRow
                    anchors.centerIn: parent; spacing: 8
                    Text { id: dateText; text: Qt.formatDateTime(new Date(), "ddd, MMM d"); font.family: theme.textFont; font.pixelSize: 12; font.weight: 600; color: pal.accent }
                    Text { text: "•"; font.pixelSize: 10; color: pal.textSecondary }
                    Text { id: timeText; text: Qt.formatDateTime(new Date(), "h:mm AP"); font.family: theme.textFont; font.pixelSize: 13; font.weight: 800; color: pal.textPrimary }
                    Timer {
                        interval: 1000; running: true; repeat: true
                        onTriggered: { var now = new Date(); dateText.text = Qt.formatDateTime(now, "ddd, MMM d"); timeText.text = Qt.formatDateTime(now, "h:mm AP") }
                    }
                }

                NumberAnimation { id: clockShimmerAnim; target: clockShimmer; property: "x"; from: -60; to: clockContainer.width + 60; duration: 800; easing.type: Easing.InOutQuad }
                
                MouseArea {
                    id: clockArea
                    anchors.fill: parent; hoverEnabled: true
                    onPressed: (mouse) => { win.requestHubToggle(); mouse.accepted = true }
                    onEntered: clockShimmerAnim.restart()
                }
            }

            Lib.SysInfoDropdown {
                barWindow: win
                bg: pal.bg
                textPrimary: pal.textPrimary
                textSecondary: pal.textSecondary
                accent: pal.accent
                hover: pal.hoverSpotlight
                border: pal.border
                warning: win.isDarkMode ? "#e69875" : "#a55524"
                critical: win.isDarkMode ? "#ff0004" : "#ff001e"
                textFont: theme.textFont
                iconFont: theme.iconFont
            }

            // 11. TRAY
            Lib.TrayDropdown {
                barWindow: win
                bg: pal.bg
                textPrimary: pal.textPrimary
                textSecondary: pal.textSecondary
                accent: pal.accent
                hover: pal.hoverSpotlight
                border: pal.border
                warning: win.isDarkMode ? "#e69875" : "#a55524"
                critical: win.isDarkMode ? "#ff0004" : "#ff001e"
                textFont: theme.textFont
                iconFont: theme.iconFont
            }
        }
    }
}
