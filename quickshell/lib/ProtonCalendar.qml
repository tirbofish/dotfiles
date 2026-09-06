pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property var events: []
    property date now: new Date()
    property var updatedAt: null
    property string error: ""
    readonly property bool busy: fetch.running
    readonly property var upcoming: events.filter(e => e.end > now.getTime())

    function parseEvents(text) {
        var data = JSON.parse(text)
        if (!data || !Array.isArray(data.events)) throw new Error("Invalid events response")
        return data.events.filter(e => e && e.status !== "cancelled").map(e => {
            function timestamp(value) {
                if (typeof value !== "string") throw new Error("Missing event date")
                // All-day dates belong to the calendar day, not a UTC offset.
                var parts = value.slice(0, 10).split("-").map(Number)
                var date = e.all_day ? new Date(parts[0], parts[1] - 1, parts[2]) : new Date(value)
                if (!isFinite(date.getTime())) throw new Error("Invalid event date")
                return date.getTime()
            }
            return { title: String(e.title || "Untitled event"),
                location: String(e.location || ""), allDay: !!e.all_day,
                start: timestamp(e.start), end: timestamp(e.end) }
        }).sort((a, b) => a.start - b.start)
    }

    function refresh() {
        if (fetch.running) return
        root.now = new Date()
        var end = new Date(root.now)
        end.setDate(end.getDate() + 30)
        fetch.command = ["timeout", "120", Quickshell.env("HOME") + "/.local/bin/proton",
            "--no-input", "--no-log", "--log-level", "error", "--output", "json",
            "calendar", "events", "list", "--start", Qt.formatDate(root.now, "yyyy-MM-dd"),
            "--end", Qt.formatDate(end, "yyyy-MM-dd")]
        fetch.running = true
    }

    Process {
        id: fetch
        stdout: StdioCollector { id: response }
        stderr: StdioCollector {}
        onExited: (code) => {
            if (code !== 0) {
                root.error = code === 124 ? "Proton timed out. Try Refresh."
                    : "Couldn't refresh Proton. Check connection or CLI sign-in."
                return
            }
            try {
                root.events = root.parseEvents(response.text)
                root.now = new Date()
                root.updatedAt = root.now
                root.error = ""
                console.info("[ProtonCalendar] Loaded", root.events.length, "events")
            } catch (e) {
                root.error = "Couldn't read Proton's calendar response."
            }
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
