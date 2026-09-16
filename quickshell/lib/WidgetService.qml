pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Desktop widgets. Each physical display owns its own list. Plugging in
// an external does not copy or fork the laptop set.
Scope {
    id: root

    readonly property string configPath:
        Qt.resolvedUrl("../desktop/widgets.json").toString().replace("file://", "")

    property bool ready: false
    property bool editing: false
    property bool widgetDragging: false
    property bool pickerOpen: false
    property string selectedId: ""
    property var outputs: ({})
    property int stamp: 0

    readonly property var catalog: [
        { type: "clock",    label: "Clock",        w: 280, h: 168 },
        { type: "weather",  label: "Weather",      w: 260, h: 148 },
        { type: "calendar", label: "Proton Calendar", w: 360, h: 420 },
        { type: "media",    label: "Now playing",  w: 320, h: 118 },
        { type: "stats",    label: "System",       w: 280, h: 176 },
        { type: "notes",    label: "Notes",        w: 280, h: 180 },
        { type: "todo",     label: "Todo",         w: 280, h: 240 },
        { type: "cava",     label: "Visualizer",   w: 320, h: 88  },
        { type: "codexbar", label: "CodexBar",     w: 280, h: 176 },
        { type: "progress", label: "Progress",     w: 380, h: 140 }
    ]

    function connectedKeys() {
        var keys = []
        var mons = MonitorService.monitors
        for (var i = 0; i < mons.length; i++) {
            var k = MonitorService.keyFor(mons[i])
            if (k && keys.indexOf(k) === -1)
                keys.push(k)
        }
        return keys
    }

    function catalogEntry(type) {
        for (var i = 0; i < root.catalog.length; i++)
            if (root.catalog[i].type === type)
                return root.catalog[i]
        return { type: type, label: type, w: 240, h: 140 }
    }

    function outputKeyForScreen(screen) {
        if (!screen) return ""
        var mon = MonitorService.monitorFor(screen.name)
        if (mon) return MonitorService.keyFor(mon)
        return screen.name || ""
    }

    function widgetsOn(outputKey) {
        if (!outputKey) return []
        if (root.outputs[outputKey]) return root.outputs[outputKey]
        var mon = MonitorService.monitorFor(outputKey)
        if (mon) {
            var k = MonitorService.keyFor(mon)
            if (k && root.outputs[k]) return root.outputs[k]
            if (mon.name && root.outputs[mon.name]) return root.outputs[mon.name]
        }
        return []
    }

    function findSpec(outputKey, id) {
        var list = root.widgetsOn(outputKey)
        for (var i = 0; i < list.length; i++)
            if (list[i] && list[i].id === id)
                return list[i]
        return null
    }

    function toggleEditing() { root.setEditing(!root.editing) }

    function setEditing(on) {
        root.editing = !!on
        root.pickerOpen = false
        if (!root.editing) {
            root.selectedId = ""
            root.widgetDragging = false
        }
    }

    function _clone(obj) {
        try { return JSON.parse(JSON.stringify(obj)) } catch (e) { return obj }
    }

    function _migrateScenes(scenes) {
        var out = {}
        for (var sid in scenes) {
            var scene = scenes[sid]
            if (!scene) continue
            for (var key in scene) {
                if (!scene[key] || !scene[key].length) continue
                if (!out[key] || !out[key].length || String(sid) === key)
                    out[key] = root._clone(scene[key])
            }
        }
        return out
    }

    function ensureOutputs() {
        var keys = root.connectedKeys()
        if (!keys.length) return
        var next = root._clone(root.outputs)
        var changed = false
        for (var i = 0; i < keys.length; i++) {
            var k = keys[i]
            if (next[k]) continue
            next[k] = []
            changed = true
        }
        if (!changed) return
        root.outputs = next
        root.stamp++
        root.save()
    }

    function _replaceList(outputKey, list, bump) {
        if (!outputKey) return
        var next = root._clone(root.outputs)
        next[outputKey] = list
        root.outputs = next
        if (bump) root.stamp++
        root.save()
    }

    function addWidget(outputKey, type, screenW, screenH, x, y) {
        var entry = root.catalogEntry(type)
        var existing = root.widgetsOn(outputKey)
        var maxX = Math.max(8, (screenW || 800) - entry.w - 8)
        var maxY = Math.max(8, (screenH || 600) - entry.h - 8)
        var spec = {
            id: "w_" + Date.now().toString(36) + "_" + Math.floor(Math.random() * 10000).toString(36),
            type: type,
            x: Math.round(Math.max(8, Math.min(maxX, x !== undefined && x !== null ? x : ((screenW || 800) - entry.w) / 2))),
            y: Math.round(Math.max(8, Math.min(maxY, y !== undefined && y !== null ? y : ((screenH || 600) - entry.h) / 2))),
            w: entry.w,
            h: entry.h,
            settings: {}
        }
        var list = root._clone(existing)
        list.push(spec)
        root.selectedId = spec.id
        root._replaceList(outputKey, list, true)
        return spec.id
    }

    function removeWidget(outputKey, id) {
        var list = []
        var existing = root.widgetsOn(outputKey)
        for (var i = 0; i < existing.length; i++)
            if (existing[i].id !== id) list.push(existing[i])
        if (root.selectedId === id) root.selectedId = ""
        root._replaceList(outputKey, list, true)
    }

    function clearOutput(outputKey) {
        root.selectedId = ""
        root._replaceList(outputKey, [], true)
    }

    function moveWidget(outputKey, id, x, y, screenW, screenH) {
        var spec = root.findSpec(outputKey, id)
        if (!spec) return
        var w = spec.w || 100
        var h = spec.h || 80
        spec.x = Math.round(Math.max(8, Math.min((screenW || 9999) - w - 8, x)))
        spec.y = Math.round(Math.max(8, Math.min((screenH || 9999) - h - 8, y)))
        root.save()
    }

    function resizeWidget(outputKey, id, w, h, screenW, screenH) {
        var spec = root.findSpec(outputKey, id)
        if (!spec) return
        spec.w = Math.round(Math.max(140, Math.min((screenW || 9999) - spec.x - 8, w)))
        spec.h = Math.round(Math.max(72, Math.min((screenH || 9999) - spec.y - 8, h)))
        root.save()
    }

    function setSetting(outputKey, id, key, value) {
        var spec = root.findSpec(outputKey, id)
        if (!spec) return
        var s = spec.settings ? root._clone(spec.settings) : {}
        s[key] = value
        spec.settings = s
        root.save()
    }

    function save() { writeTimer.restart() }

    // Our own writes bounce back through FileView.onLoaded. Reloading
    // recreates every widget and drops notes/todo keyboard focus after the
    // save debounce, so ignore that echo.
    property bool suppressLoad: false

    Timer {
        id: writeTimer
        interval: 80
        onTriggered: root._flush()
    }

    Timer {
        id: unsuppressLoad
        interval: 400
        onTriggered: root.suppressLoad = false
    }

    function _flush() {
        root.suppressLoad = true
        configFile.setText(JSON.stringify({ outputs: root.outputs }, null, 2) + "\n")
        unsuppressLoad.restart()
    }

    function load() {
        try {
            var raw = configFile.text()
            if (!raw || raw.length === 0) return
            var d = JSON.parse(raw)
            if (d && d.outputs && typeof d.outputs === "object")
                root.outputs = d.outputs
            else if (d && d.scenes && typeof d.scenes === "object") {
                root.outputs = root._migrateScenes(d.scenes)
                root.save()
            }
        } catch (e) {
            console.warn("[WidgetService] load failed:", e)
        }
    }

    FileView {
        id: configFile
        path: root.configPath
        preload: true
        onLoaded: {
            if (root.suppressLoad)
                return
            root.load()
            var first = !root.ready
            root.ready = true
            root.ensureOutputs()
            if (first)
                lateBind.restart()
        }
        onLoadFailed: { root.ready = true; root.ensureOutputs(); lateBind.restart() }
    }

    Timer {
        id: lateBind
        interval: 500
        onTriggered: { root.ensureOutputs(); root.stamp++ }
    }

    Connections {
        target: MonitorService
        function onMonitorApplied() { root.ensureOutputs(); root.stamp++ }
        function onKnownConnected(mon) { root.ensureOutputs(); root.stamp++ }
        function onGuestConnected(mon) { root.ensureOutputs(); root.stamp++ }
        function onMonitorGone(name) { root.stamp++ }
    }
}
