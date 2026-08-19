pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Scope {
    id: root

    property real mouseSpeed: 0.35
    property bool mouseAcceleration: true
    property bool mouseNaturalScroll: false
    property bool mouseLeftHanded: false
    property real touchpadSpeed: 0.35
    property bool touchpadNaturalScroll: true
    property bool touchpadTapToClick: true
    property bool touchpadDisableWhileTyping: true
    property var mice: []
    property var touchpads: []

    readonly property string statePath:
        Qt.resolvedUrl("inputsettings.json").toString().replace("file://", "")

    function isTouchpad(device) {
        var text = String((device && device.name) || "").toLowerCase()
        return /touchpad|trackpad|clickpad/.test(text)
    }

    function luaString(value) {
        return '"' + String(value).replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"'
    }

    function applySettings() {
        var bool = function(value) { return value ? "true" : "false" }
        Quickshell.execDetached(["hyprctl", "eval",
            "hl.config({ input = { sensitivity = " + mouseSpeed
            + ", natural_scroll = " + bool(mouseNaturalScroll)
            + ", left_handed = " + bool(mouseLeftHanded)
            + ", touchpad = { natural_scroll = " + bool(touchpadNaturalScroll)
            + ", tap_to_click = " + bool(touchpadTapToClick)
            + ", disable_while_typing = " + bool(touchpadDisableWhileTyping)
            + " } } })"])
        for (var i = 0; i < mice.length; i++) {
            Quickshell.execDetached(["hyprctl", "eval",
                "hl.device({ name = " + luaString(mice[i].name)
                + ", accel_profile = " + luaString(mouseAcceleration ? "adaptive" : "flat")
                + " })"])
        }
        for (var i = 0; i < touchpads.length; i++) {
            Quickshell.execDetached(["hyprctl", "eval",
                "hl.device({ name = " + luaString(touchpads[i].name)
                + ", sensitivity = " + touchpadSpeed
                + ", natural_scroll = " + bool(touchpadNaturalScroll)
                + ", left_handed = false })"])
        }
    }

    function save() { writeTimer.restart(); applySettings() }
    function refresh() { deviceRefresh.restart() }

    Process {
        id: devicesQuery
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text || "{}")
                    root.touchpads = (data.mice || []).filter(root.isTouchpad)
                    root.mice = (data.mice || []).filter(function(device) { return !root.isTouchpad(device) })
                    root.applySettings()
                } catch (e) { console.warn("[InputService] device query failed:", e) }
            }
        }
    }

    Timer {
        id: writeTimer
        interval: 80
        onTriggered: stateFile.setText(JSON.stringify({
            version: 2,
            mouseSpeed: root.mouseSpeed,
            mouseAcceleration: root.mouseAcceleration,
            mouseNaturalScroll: root.mouseNaturalScroll,
            mouseLeftHanded: root.mouseLeftHanded,
            touchpadSpeed: root.touchpadSpeed,
            touchpadNaturalScroll: root.touchpadNaturalScroll,
            touchpadTapToClick: root.touchpadTapToClick,
            touchpadDisableWhileTyping: root.touchpadDisableWhileTyping
        }, null, 2))
    }

    Timer {
        id: deviceRefresh
        interval: 300
        onTriggered: {
            devicesQuery.running = false
            devicesQuery.running = true
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.applySettings()
    }

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (!ev || !ev.name) return
            if (ev.name === "deviceadded" || ev.name === "deviceaddedv2"
                || ev.name === "deviceremoved" || ev.name === "monitoradded"
                || ev.name === "monitoraddedv2" || ev.name === "monitorremoved")
                root.refresh()
        }
    }

    FileView {
        id: stateFile
        path: root.statePath
        preload: true
        onLoaded: {
            try {
                var data = JSON.parse(text() || "{}")
                for (var key in data)
                    if (root[key] !== undefined) root[key] = data[key]
                // Migrate the old -100..100 percentage scale to Hyprland's native -1..1 range.
                if (data.version !== 2) {
                    root.mouseSpeed /= 100
                    root.touchpadSpeed /= 100
                }
            } catch (e) { console.warn("[InputService] settings load failed:", e) }
            root.refresh()
        }
        onLoadFailed: root.refresh()
    }
}
