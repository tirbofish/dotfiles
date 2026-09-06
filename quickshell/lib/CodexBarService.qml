pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property var rows: []
    property var catalog: []
    property string error: ""
    property bool loading: false
    property string updatedAt: ""
    readonly property var focus: rows.length ? rows[0] : null
    readonly property int sessionUsed: focus && focus.sessionUsed >= 0 ? focus.sessionUsed : -1
    readonly property int weeklyUsed: focus && focus.weeklyUsed >= 0 ? focus.weeklyUsed : -1
    readonly property string focusLabel: focus ? focus.label : "Codex"
    readonly property string tooltip: {
        if (error !== "") return error
        if (!focus) return "CodexBar"
        var parts = [focus.label]
        if (focus.sessionUsed >= 0)
            parts.push("5h " + (100 - focus.sessionUsed) + "% left")
        if (focus.weeklyUsed >= 0)
            parts.push("week " + (100 - focus.weeklyUsed) + "% left")
        if (focus.sessionReset !== "")
            parts.push("resets " + focus.sessionReset)
        return parts.join(" · ")
    }

    readonly property var pinnedIds: ["codex", "claude", "cursor", "gemini", "copilot"]

    function cli() {
        return Quickshell.env("HOME") + "/.local/bin/codexbar"
    }

    function remaining(used) {
        if (used === undefined || used === null || used < 0) return -1
        return Math.max(0, 100 - Number(used))
    }

    function meter(window) {
        if (!window) return { used: -1, reset: "" }
        var used = window.usedPercent
        if (used === undefined || used === null) used = -1
        return { used: Number(used), reset: String(window.resetDescription || "") }
    }

    function parseUsage(raw) {
        var text = String(raw || "").trim()
        if (!text) throw "empty CodexBar response"
        var data = JSON.parse(text)
        if (!Array.isArray(data)) data = [data]
        var next = []
        for (var i = 0; i < data.length; i++) {
            var item = data[i] || {}
            var usage = item.usage || {}
            var primary = root.meter(usage.primary)
            var secondary = root.meter(usage.secondary)
            var id = String(item.provider || usage.identity && usage.identity.providerID || "unknown")
            var label = id.charAt(0).toUpperCase() + id.slice(1)
            next.push({
                id: id,
                label: label,
                sessionUsed: primary.used,
                sessionReset: primary.reset,
                weeklyUsed: secondary.used,
                weeklyReset: secondary.reset,
                email: String(usage.accountEmail || ""),
                error: item.error ? String(item.error) : ""
            })
        }
        return next
    }

    function refresh() {
        if (usageProc.running) return
        root.loading = true
        usageProc.running = true
    }

    function refreshCatalog() {
        if (catProc.running) return
        catProc.running = true
    }

    function parseCatalog(raw) {
        var data = JSON.parse(String(raw || "[]").trim() || "[]")
        if (!Array.isArray(data)) data = []
        var out = []
        for (var i = 0; i < data.length; i++) {
            var p = data[i] || {}
            if (p.error) continue
            var id = String(p.provider || p.id || "")
            if (!id) continue
            out.push({
                id: id,
                name: String(p.displayName || id),
                enabled: !!p.enabled
            })
        }
        out.sort(function(a, b) {
            if (a.enabled !== b.enabled) return a.enabled ? -1 : 1
            return a.name.localeCompare(b.name)
        })
        return out
    }

    function setProviderEnabled(id, on) {
        var next = []
        for (var i = 0; i < root.catalog.length; i++) {
            var p = root.catalog[i]
            next.push({
                id: p.id,
                name: p.name,
                enabled: p.id === id ? !!on : !!p.enabled
            })
        }
        next.sort(function(a, b) {
            if (a.enabled !== b.enabled) return a.enabled ? -1 : 1
            return a.name.localeCompare(b.name)
        })
        root.catalog = next
        toggleProc.command = ["bash", "-lc",
            root.cli() + " config " + (on ? "enable" : "disable") + " --provider " + id]
        toggleProc.running = false
        toggleProc.running = true
        usageRefresh.restart()
    }

    Process {
        id: usageProc
        command: ["bash", "-lc", root.cli() + " usage --format json --no-color"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.rows = root.parseUsage(this.text)
                    root.error = root.rows.length ? "" : "No enabled CodexBar providers"
                    root.updatedAt = new Date().toLocaleTimeString()
                } catch (e) {
                    root.error = "CodexBar: " + e
                }
                root.loading = false
            }
        }
        onExited: function(code) {
            if (code !== 0 && root.rows.length === 0)
                root.error = "codexbar failed (exit " + code + ")"
            if (!usageProc.running) root.loading = false
        }
    }

    Process {
        id: catProc
        command: ["bash", "-lc", root.cli() + " config providers --format json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.catalog = root.parseCatalog(this.text)
                } catch (e) { }
            }
        }
    }

    Process {
        id: toggleProc
        onExited: catRefresh.restart()
    }

    Timer {
        id: usageRefresh
        interval: Math.max(60, Number(Configuration.codexbarRefreshSec) || 300) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    Timer {
        id: catRefresh
        interval: 400
        repeat: false
        onTriggered: root.refreshCatalog()
    }

    Component.onCompleted: root.refreshCatalog()
}
