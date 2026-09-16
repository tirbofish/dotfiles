pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "MonitorScale.js" as MonitorScale

Scope {
    id: root

    // STATE
    readonly property string laptopOutput: "eDP-1"
    property var monitors: []              // parsed hyprctl monitors -j
    property var pending: null             // guest waiting for a choice
    property string appliedLayout: ""      // layout awaiting confirm
    property var revertSnapshot: null
    property int revertSeconds: 0

    signal guestConnected(var mon)
    signal monitorGone(string name)
    signal knownConnected(var mon)
    signal confirmNeeded(var mon, string layout)
    signal toast(string msg)
    signal monitorApplied()

    // Descriptions treated as configured screens. 
    property var knownPatterns: []
    property var remembered: ({})          // description -> layout
    property var configured: ({})          // description -> output, mode, position and scale
    property string primary: ""            // stable monitor description
    property string pinnedSwitcherOutput: ""
    property bool stateLoaded: false

    // Where the prompt shows. The laptop panel normally, but it is switched off
    // while the monitor is docked, so fall back to whatever screen is focused.
    readonly property string promptOutput: {
        for (var i = 0; i < root.monitors.length; i++)
            if (root.monitors[i].name === root.laptopOutput) return root.laptopOutput
        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name)
            return Hyprland.focusedMonitor.name
        return root.monitors.length ? root.monitors[0].name : root.laptopOutput
    }

    // Descriptions are the stable id, but some screens report an empty one
    function keyFor(m) {
        if (!m) return ""
        return String(m.description || "").length ? m.description : m.name
    }

    function isKnown(desc) {
        var d = String(desc || "")
        for (var i = 0; i < root.knownPatterns.length; i++)
            if (d.indexOf(root.knownPatterns[i]) !== -1) return true
        return false
    }

    function monitorFor(name) {
        for (var i = 0; i < root.monitors.length; i++)
            if (root.monitors[i].name === name || root.keyFor(root.monitors[i]) === name)
                return root.monitors[i]
        return null
    }

    function configuredForOutput(output) {
        var mon = root.monitorFor(output)
        if (mon && root.configured[root.keyFor(mon)])
            return root.configured[root.keyFor(mon)]
        for (var key in root.configured) {
            var spec = root.configured[key]
            if (spec && spec.output === output) return spec
        }
        return null
    }

    function hasRealMode(m) {
        return m && Number(m.width) >= 200 && Number(m.height) >= 200
    }

    function modeIsReal(mode) {
        var s = String(mode || "")
        if (!s || s === "preferred" || s === "highres" || s === "highrr") return true
        var match = s.match(/^(\d+)x(\d+)/)
        return !!(match && Number(match[1]) >= 200 && Number(match[2]) >= 200)
    }

    // Connector names (DP-3) rotate and, if pinned while empty, 0x0 the next
    // hotplug. Description rules only match once EDID is present.
    function selectorFor(monOrName) {
        var mon = typeof monOrName === "object" ? monOrName : root.monitorFor(monOrName)
        var desc = mon ? String(mon.description || "") : ""
        if (desc.length) return "desc:" + desc
        return typeof monOrName === "object" ? (monOrName && monOrName.name) : monOrName
    }

    function rememberCurrent(mon) {
        if (!mon || !hasRealMode(mon) || root.configured[root.keyFor(mon)]) return
        var next = {}
        for (var key in root.configured) next[key] = root.configured[key]
        next[root.keyFor(mon)] = {
            output: mon.name,
            mode: mon.width + "x" + mon.height + "@" + Number(mon.refreshRate).toFixed(3),
            position: Math.round(mon.x) + "x" + Math.round(mon.y),
            scale: mon.scale
        }
        root.configured = next
        root.save()
    }

    function profileMatches(mon, spec) {
        if (spec.scale !== undefined && Math.abs(Number(mon.scale) - Number(spec.scale)) > 0.001)
            return false

        var position = String(spec.position || "")
        var positionMatch = position.match(/^(-?\d+)x(-?\d+)$/)
        if (positionMatch && (Math.round(mon.x) !== Number(positionMatch[1])
                || Math.round(mon.y) !== Number(positionMatch[2])))
            return false

        var mode = String(spec.mode || "")
        var modeMatch = mode.match(/^(\d+)x(\d+)(?:@([\d.]+))?/)
        if (modeMatch && (Number(mon.width) !== Number(modeMatch[1])
                || Number(mon.height) !== Number(modeMatch[2])))
            return false
        if (modeMatch && modeMatch[3] && Math.abs(Number(mon.refreshRate) - Number(modeMatch[3])) > 0.1)
            return false

        return true
    }

    function primaryMonitor() {
        for (var i = 0; i < root.monitors.length; i++)
            if (root.primary && root.keyFor(root.monitors[i]) === root.primary)
                return root.monitors[i]
        return root.monitorFor(root.laptopOutput) || (root.monitors.length ? root.monitors[0] : null)
    }

    readonly property string primaryOutput: {
        var mon = root.primaryMonitor()
        return mon ? mon.name : root.laptopOutput
    }

    readonly property string pinSwitcherScript:
        Quickshell.env("HOME") + "/.config/hypr/scripts/alttab/pin-display.sh"

    function syncSwitcherOutput() {
        var mon = root.primaryMonitor()
        if (!mon || !mon.name || root.pinnedSwitcherOutput === mon.name) return
        root.pinnedSwitcherOutput = mon.name
        Quickshell.execDetached([root.pinSwitcherScript, mon.name])
    }

    function setPrimary(mon) {
        if (!mon) return
        root.primary = root.keyFor(mon)
        root.save()
        root.syncSwitcherOutput()
    }

    // DETECTION
    property var _seen: ({})
    property bool _primed: false

    Process {
        id: query
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                var list = []
                try { list = JSON.parse(this.text || "[]") } catch (e) { return }
                root.monitors = list

                var fresh = {}
                for (var i = 0; i < list.length; i++) {
                    var m = list[i]
                    fresh[m.name] = m.description
                    // Pyprland owns hotplug layouts; this query only updates the UI.
                }
                for (var name in root._seen) {
                    if (fresh[name] === undefined) {
                        if (root.pinnedSwitcherOutput === name) root.pinnedSwitcherOutput = ""
                        root.monitorGone(name)
                    }
                }

                root._seen = fresh
                root._primed = true
                if (root.stateLoaded) {
                    if (!root.primary) {
                        var fallback = root.primaryMonitor()
                        if (fallback) {
                            root.primary = root.keyFor(fallback)
                            root.save()
                        }
                    }
                    root.syncSwitcherOutput()
                }
            }
        }
    }

    function refresh() { query.running = false; query.running = true }
    function refreshSoon() { settle.restart() }

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (!ev || !ev.name) return
            if (ev.name === "monitoradded" || ev.name === "monitorremoved"
                || ev.name === "monitoraddedv2")
                settle.restart()
        }
    }

    // Hyprland applies its own monitor rules first; reading too early reports
    // the pre-rule mode (often 0x0 / 20x32).
    Timer {
        id: settle
        interval: 800
        onTriggered: root.refresh()
    }

    Timer {
        id: edidRetry
        interval: 400
        onTriggered: root.refresh()
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: root.refresh()

    // APPLY
    function _shortName(m) {
        var d = String(m.description || m.name)
        return d.length > 28 ? d.substring(0, 28) : d
    }

    function _luaStr(s) {
        return String(s ?? "").replace(/\\/g, "\\\\").replace(/"/g, '\\"')
    }

    function _mon(spec) {
        if (spec.scale !== undefined) {
            var monitor = root.monitors.find(function(m) { return root.selectorFor(m) === spec.output || m.name === spec.output })
            spec.scale = MonitorScale.nearest(spec.mode || (monitor ? monitor.width + "x" + monitor.height : ""), spec.scale)
        }
        var parts = ['output = "' + root._luaStr(spec.output) + '"']
        if (spec.mode      !== undefined) parts.push('mode = "' + root._luaStr(spec.mode) + '"')
        if (spec.position  !== undefined) parts.push('position = "' + root._luaStr(spec.position) + '"')
        if (spec.scale     !== undefined) parts.push("scale = " + spec.scale)
        if (spec.mirror    !== undefined) parts.push('mirror = "' + root._luaStr(spec.mirror) + '"')
        if (spec.disabled  !== undefined) parts.push("disabled = " + (spec.disabled ? "true" : "false"))
        Quickshell.execDetached(["hyprctl", "eval", "hl.monitor({ " + parts.join(", ") + " })"])
        root.monitorApplied()
    }

    function _on(output) {
        var mon = root.monitorFor(output)
        if (mon && output !== root.laptopOutput && !root.hasRealMode(mon))
            return
        var spec = root.configuredForOutput(output)
        var mode = spec?.mode ?? "preferred"
        if (!root.modeIsReal(mode)) mode = "preferred"
        _mon({
            output: root.selectorFor(output),
            mode: mode,
            position: spec?.position ?? "auto",
            scale: spec?.scale ?? 1,
            disabled: false
        })
    }
    function _off(output) { _mon({ output: root.selectorFor(output), disabled: true }) }

    function configure(spec, mon) {
        if (!mon || !root.modeIsReal(spec && spec.mode)) return
        spec.scale = MonitorScale.nearest(spec.mode, spec.scale)
        Quickshell.execDetached(["python3", Quickshell.env("HOME") + "/.config/hypr/scripts/save-kanshi.py",
            mon.name === root.laptopOutput ? mon.name : root.keyFor(mon), JSON.stringify(spec)])
        var next = {}
        for (var key in root.configured) next[key] = root.configured[key]
        next[root.keyFor(mon)] = {
            output: mon.name,
            mode: spec.mode,
            position: spec.position,
            scale: spec.scale
        }
        root.configured = next
        root.save()
        root._mon({
            output: root.selectorFor(mon),
            mode: spec.mode,
            position: spec.position,
            scale: spec.scale
        })
    }

    function _snapshot() {
        var laptop = root.monitorFor(root.laptopOutput)
        return {
            laptopDisabled: laptop === null,
            guest: root.pending ? root.pending.name : ""
        }
    }

    // layout: extend | duplicate | laptop | external
    function apply(layout, mon, needsConfirm) {
        if (!mon || !root.hasRealMode(mon)) return
        if (needsConfirm === undefined) needsConfirm = true
        root.revertSnapshot = root._snapshot()

        var name = mon.name
        switch (layout) {
        case "extend":
            _on(name)
            _on(root.laptopOutput)
            break
        case "duplicate":
            // Mirror the screen actually in use, which is not the laptop panel
            // while the monitor has it switched off
            _on(root.promptOutput)
            var mirrorSpec = root.configuredForOutput(name)
            var mirrorMode = mirrorSpec?.mode ?? "preferred"
            if (!root.modeIsReal(mirrorMode)) mirrorMode = "preferred"
            _mon({
                output: root.selectorFor(mon),
                mode: mirrorMode,
                position: mirrorSpec?.position ?? "auto",
                scale: mirrorSpec?.scale ?? 1,
                mirror: root.promptOutput
            })
            break
        case "laptop":
            _on(root.laptopOutput)
            _off(name)
            break
        case "external":
            _on(name)
            _off(root.laptopOutput)
            break
        default:
            return
        }

        root.appliedLayout = layout
        settle.restart()
        if (needsConfirm) root.confirmNeeded(mon, layout)
    }

    function remember(desc, layout) {
        var next = {}
        for (var k in root.remembered) next[k] = root.remembered[k]
        next[desc] = layout
        root.remembered = next
        save()
    }

    function forget(desc) {
        var next = {}
        for (var k in root.remembered) if (k !== desc) next[k] = root.remembered[k]
        root.remembered = next
        save()
    }

    // Put the guest back the way it was found and wake the laptop panel
    function revert() {
        var snap = root.revertSnapshot
        if (!snap) return
        if (snap.guest) _off(snap.guest)
        if (!snap.laptopDisabled) _on(root.laptopOutput)
        root.appliedLayout = ""
        settle.restart()
    }

    // PERSISTENCE
    readonly property string statePath:
        Qt.resolvedUrl("monitors.json").toString().replace("file://", "")

    function save() { writeTimer.restart() }

    Timer {
        id: writeTimer
        interval: 60
        onTriggered: stateFile.setText(JSON.stringify({
            knownPatterns: root.knownPatterns,
            remembered:    root.remembered,
            configured:    root.configured,
            primary:       root.primary
        }, null, 2))
    }

    FileView {
        id: stateFile
        path: root.statePath
        preload: true
        onLoaded: {
            try {
                var j = JSON.parse(text() || "{}")
                if (j.knownPatterns) root.knownPatterns = j.knownPatterns
                if (j.remembered)    root.remembered    = j.remembered
                if (j.configured)    root.configured    = j.configured
                if (j.primary)       root.primary       = j.primary
            } catch (e) { }
            root.stateLoaded = true
            root.refresh()
        }
        onLoadFailed: {
            root.stateLoaded = true
            root.refresh()
        }
    }
}
