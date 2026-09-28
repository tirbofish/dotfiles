pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../desktop/grid.js" as Grid

// Desktop widgets. Each physical display owns its own list. Plugging in
// an external does not copy or fork the laptop set.
Scope {
    id: root

    readonly property string configPath:
        Qt.resolvedUrl("../desktop/widgets.json").toString().replace("file://", "")
    readonly property string packsPath:
        Qt.resolvedUrl("../desktop/packs.json").toString().replace("file://", "")

    property bool ready: false
    property bool editing: false
    property bool widgetDragging: false
    property bool pickerOpen: false
    property bool settingsOpen: false
    property string selectedId: ""
    property var outputs: ({})
    property var packs: []
    property int stamp: 0
    property int settingsStamp: 0

    readonly property var catalog: [
        { type: "clock",       label: "Clock",           detail: "Local time and date",          icon: "󰥔", w: Grid.span(2), h: Grid.span(1),
            options: [{ key: "hour24", label: "24-hour time", kind: "bool", value: true }, { key: "showDate", label: "Show date", kind: "bool", value: true }] },
        { type: "worldclock",  label: "World Clocks",    detail: "Times around the world",       icon: "󰗊", w: Grid.span(3), h: Grid.span(2),
            options: [{ key: "cities", label: "Time zones", kind: "text", value: "Australia/Sydney, UTC, America/New_York, Asia/Tokyo" }] },
        { type: "weather",     label: "Weather",         detail: "Current local conditions",     icon: "󰖐", w: Grid.span(2), h: Grid.span(1)},
        { type: "calendar",    label: "Proton Calendar", detail: "Your upcoming events",         icon: "󰃭", w: Grid.span(3), h: Grid.span(4)},
        { type: "media",       label: "Now Playing",     detail: "Media artwork and controls",   icon: "󰎆", w: Grid.span(3), h: Grid.span(1),
            options: [{ key: "showArtwork", label: "Show artwork", kind: "bool", value: true }] },
        { type: "battery",     label: "Batteries",       detail: "Charge, health and power",     icon: "󰁹", w: Grid.span(2), h: Grid.span(1),
            options: [{ key: "showDetails", label: "Show health and cycles", kind: "bool", value: true }] },
        { type: "photos",      label: "Photos",          detail: "Rotates through ~/Pictures",   icon: "󰋩", w: Grid.span(3), h: Grid.span(2),
            options: [{ key: "interval", label: "Rotate every", kind: "choice", value: 5, values: [1, 5, 15, 30], suffix: " min" }] },
        { type: "stats",       label: "System",          detail: "CPU, memory and uptime",       icon: "󰍛", w: Grid.span(2), h: Grid.span(2),
            options: [{ key: "interval", label: "Refresh every", kind: "choice", value: 2, values: [1, 2, 5, 10], suffix: " sec" }] },
        { type: "notes",       label: "Notes",           detail: "A persistent quick note",      icon: "󰎚", w: Grid.span(3), h: Grid.span(2)},
        { type: "todo",        label: "Todo",            detail: "Interactive reminders",        icon: "󰄬", w: Grid.span(3), h: Grid.span(3)},
        { type: "pomodoro",    label: "Pomodoro",        detail: "Focus timer with breaks",      icon: "󰄉", w: Grid.span(2), h: Grid.span(2),
            options: [{ key: "sessionMin", label: "Session", kind: "choice", value: 50, values: [25, 50, 60, 90, 120, 180], suffix: " min" }] },
        { type: "voyager",     label: "Voyager 1",       detail: "Live distance to the farthest spacecraft", icon: "✦", w: Grid.span(4), h: Grid.span(3) },
        { type: "cava",        label: "Visualizer",      detail: "Live audio spectrum",          icon: "󰝚", w: Grid.span(3), h: Grid.span(1) },
        { type: "codexbar",    label: "CodexBar",        detail: "Codex session status",         icon: "󰚩", w: Grid.span(3), h: Grid.span(2)},
        { type: "progress",    label: "Progress",        detail: "Track long-running work",      icon: "󰔟", w: Grid.span(3), h: Grid.span(1)}
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
        root.settingsOpen = false
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
        var next = Object.assign({}, root.outputs)
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
        var next = Object.assign({}, root.outputs)
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
        var r = Grid.snap(
            Math.max(8, Math.min(maxX, x !== undefined && x !== null ? x : ((screenW || 800) - entry.w) / 2)),
            Math.max(8, Math.min(maxY, y !== undefined && y !== null ? y : ((screenH || 600) - entry.h) / 2)),
            entry.w, entry.h, screenW || 800, screenH || 600)
        var spec = {
            id: "w_" + Date.now().toString(36) + "_" + Math.floor(Math.random() * 10000).toString(36),
            type: type, x: r.x, y: r.y, w: r.w, h: r.h,
            settings: {}
        }
        var list = existing.slice()
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

    function _snapSpec(spec, x, y, w, h, screenW, screenH) {
        var r = Grid.snap(x, y, w, h, screenW || 1920, screenH || 1080)
        var changed = spec.x !== r.x || spec.y !== r.y || spec.w !== r.w || spec.h !== r.h
        spec.x = r.x; spec.y = r.y; spec.w = r.w; spec.h = r.h
        if (changed) root.save()
        return changed
    }

    function moveWidget(outputKey, id, x, y, screenW, screenH) {
        var spec = root.findSpec(outputKey, id)
        if (spec) root._snapSpec(spec, x, y, spec.w, spec.h, screenW, screenH)
    }

    function resizeWidget(outputKey, id, w, h, screenW, screenH) {
        var spec = root.findSpec(outputKey, id)
        if (spec) root._snapSpec(spec, spec.x, spec.y, w, h, screenW, screenH)
    }

    // Pulls widgets saved before the grid existed onto it.
    function snapWidget(outputKey, id, screenW, screenH) {
        var spec = root.findSpec(outputKey, id)
        return spec ? root._snapSpec(spec, spec.x, spec.y, spec.w, spec.h, screenW, screenH) : false
    }

    function setSetting(outputKey, id, key, value) {
        var spec = root.findSpec(outputKey, id)
        if (!spec) return
        var s = spec.settings ? root._clone(spec.settings) : {}
        s[key] = value
        spec.settings = s
        root.settingsStamp++
        root.save()
    }

    function setSettings(outputKey, id, values) {
        var spec = root.findSpec(outputKey, id)
        if (!spec || !values) return
        var s = spec.settings ? root._clone(spec.settings) : {}
        for (var k in values)
            s[k] = values[k]
        spec.settings = s
        root.settingsStamp++
        root.save()
    }

    function resetSettings(outputKey, id) {
        var spec = root.findSpec(outputKey, id)
        if (!spec) return
        spec.settings = {}
        root.settingsStamp++
        root.save()
    }

    function savePack(outputKey, screenW, screenH) {
        var widgets = root._clone(root.widgetsOn(outputKey))
        for (var i = 0; i < widgets.length; i++) {
            delete widgets[i].id
            widgets[i].settings = {}
        }
        var next = root._clone(root.packs)
        next.push({
            id: "pack_" + Date.now().toString(36),
            name: "My pack " + (next.length + 1),
            screenW: screenW,
            screenH: screenH,
            widgets: widgets
        })
        root.packs = next
        packFile.setText(JSON.stringify({ packs: next }, null, 2) + "\n")
    }

    function removePack(id) {
        var next = []
        for (var i = 0; i < root.packs.length; i++)
            if (root.packs[i].id !== id) next.push(root.packs[i])
        root.packs = next
        packFile.setText(JSON.stringify({ packs: next }, null, 2) + "\n")
    }

    function renamePack(id, name) {
        name = String(name || "").trim()
        if (!name) return
        var next = root._clone(root.packs)
        for (var i = 0; i < next.length; i++)
            if (next[i].id === id) next[i].name = name
        root.packs = next
        packFile.setText(JSON.stringify({ packs: next }, null, 2) + "\n")
    }

    function applyPack(outputKey, pack, screenW, screenH) {
        if (!pack || !pack.widgets) return
        var old = root.widgetsOn(outputKey)
        var settings = {}
        for (var i = 0; i < old.length; i++) {
            if (!settings[old[i].type]) settings[old[i].type] = []
            settings[old[i].type].push(root._clone(old[i].settings || {}))
        }
        var refW = Number(pack.screenW || screenW || 800)
        var refH = Number(pack.screenH || screenH || 600)
        var next = []
        for (var j = 0; j < pack.widgets.length; j++) {
            var p = pack.widgets[j]
            var w = Math.min(Number(p.w || 240), Math.max(140, screenW - 16))
            var h = Math.min(Number(p.h || 140), Math.max(72, screenH - 16))
            var refX = Math.max(1, refW - Number(p.w || w) - 16)
            var refY = Math.max(1, refH - Number(p.h || h) - 16)
            var maxX = Math.max(8, screenW - w - 8)
            var maxY = Math.max(8, screenH - h - 8)
            var saved = settings[p.type] && settings[p.type].length ? settings[p.type].shift() : root._clone(p.settings || {})
            var r = Grid.snap(
                8 + Math.max(0, Number(p.x || 8) - 8) / refX * Math.max(0, maxX - 8),
                8 + Math.max(0, Number(p.y || 8) - 8) / refY * Math.max(0, maxY - 8),
                w, h, screenW, screenH)
            next.push({
                id: "w_" + Date.now().toString(36) + "_" + j,
                type: p.type, x: r.x, y: r.y, w: r.w, h: r.h,
                settings: saved
            })
        }
        root.selectedId = ""
        root._replaceList(outputKey, next, true)
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

    FileView {
        id: packFile
        path: root.packsPath
        preload: true
        onLoaded: {
            try {
                var d = JSON.parse(text() || "{}")
                root.packs = d && Array.isArray(d.packs) ? d.packs : []
            } catch (e) {
                console.warn("[WidgetService] pack load failed:", e)
            }
        }
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
