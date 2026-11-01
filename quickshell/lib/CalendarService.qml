pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Upcoming events from Proton (proton CLI) and Google (gws). Each calendar
// widget picks its own provider (proton | google | both); a source only runs
// while some widget uses it, and widgets on the same source share its data.
Scope {
    id: root
    readonly property string protonBin: Quickshell.env("HOME") + "/.local/bin/proton"
    readonly property string gwsBin: Quickshell.env("HOME") + "/.bun/bin/gws"
    property var users: ({ proton: 0, google: 0 })
    property date now: new Date()

    function sourcesFor(provider) {
        return provider === "google" ? [google] : provider === "both" ? [proton, google] : [proton]
    }

    function use(provider, delta) {
        var next = Object.assign({}, root.users)
        for (const s of root.sourcesFor(provider)) {
            var k = s === google ? "google" : "proton"
            next[k] = Math.max(0, next[k] + delta)
        }
        root.users = next
    }

    function refresh(provider) {
        root.now = new Date()
        for (const s of provider ? root.sourcesFor(provider) : [proton, google]) s.refresh()
    }

    CalendarSource {
        id: proton
        name: "Proton"
        enabled: root.users.proton > 0
        fetchCommand: function() {
            var end = new Date(root.now)
            end.setDate(end.getDate() + 30)
            return ["timeout", "120", root.protonBin,
                "--no-input", "--no-log", "--log-level", "error", "--output", "json",
                "calendar", "events", "list", "--limit", "0",
                "--after", Qt.formatDate(root.now, "yyyy-MM-dd"),
                "--before", Qt.formatDate(end, "yyyy-MM-dd")]
        }
        colorsCommand: ["timeout", "60", root.protonBin,
            "--no-input", "--no-log", "--log-level", "error", "--output", "json",
            "calendar", "settings", "calendars", "list"]
        toEvents: (d) => d.events
        toColors: function(d) {
            var map = {}
            for (const c of d.calendars || [])
                if (c.id && /^#[0-9a-f]{6}$/i.test(c.color)) map[c.id] = c.color
            return map
        }
    }

    CalendarSource {
        id: google
        name: "Google"
        enabled: root.users.google > 0
        fetchCommand: () => ["timeout", "120", root.gwsBin, "calendar", "+agenda", "--days", "30", "--format", "json"]
        colorsCommand: ["timeout", "60", root.gwsBin, "calendar", "calendarList", "list",
            "--params", JSON.stringify({ fields: "items(summary,backgroundColor)" })]
        // +agenda names calendars instead of giving ids, so colours key on the name.
        toEvents: (d) => (d.events || []).map(e => ({
            title: e.summary, location: e.location, calendar_id: e.calendar,
            all_day: String(e.start).indexOf("T") === -1, start: e.start, end: e.end }))
        toColors: function(d) {
            var map = {}
            for (const g of d.items || [])
                if (/^#[0-9a-f]{6}$/i.test(g.backgroundColor)) map[g.summary] = g.backgroundColor
            return map
        }
    }

    Timer {
        interval: 300000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }
}
