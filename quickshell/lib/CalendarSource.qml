import QtQuick
import Quickshell
import Quickshell.Io

// One calendar backend for CalendarService: runs its CLI, normalises events.
Scope {
    id: src
    property string name
    property bool enabled
    property var fetchCommand          // () → argv
    property var colorsCommand: []
    property var toEvents              // parsed JSON → normalised events
    property var toColors              // parsed JSON → { calendarId: color }
    property var events: []
    property var colors: ({})
    property string error: ""
    property var updatedAt: null
    readonly property bool busy: fetch.running

    onEnabledChanged: if (enabled) refresh()

    function refresh() {
        if (!enabled || fetch.running) return
        fetch.command = fetchCommand()
        fetch.running = true
        if (!colorsProc.running) colorsProc.running = true
    }

    Process {
        id: colorsProc
        command: src.colorsCommand
        stdout: StdioCollector { id: colorsOut }
        // Colours are cosmetic: on failure keep the last good set.
        onExited: (code) => {
            if (code !== 0) return
            try { src.colors = src.toColors(JSON.parse(colorsOut.text)) } catch (e) {}
        }
    }

    Process {
        id: fetch
        stdout: StdioCollector { id: response }
        stderr: StdioCollector { id: errText }
        onExited: (code) => {
            if (code !== 0) {
                var detail = errText.text.trim().split("\n").pop()
                src.error = code === 124 ? src.name + " timed out. Try Refresh."
                    : "Couldn't refresh " + src.name + (detail ? ": " + detail : ". Check connection or CLI sign-in.")
                console.warn("[CalendarService]", src.name, "exit", code, errText.text)
                return
            }
            try {
                src.events = src.parseEvents(src.toEvents(JSON.parse(response.text)))
                src.updatedAt = new Date()
                src.error = ""
                console.info("[CalendarService]", src.name, "loaded", src.events.length, "events")
            } catch (e) {
                src.error = "Couldn't read " + src.name + "'s calendar response."
            }
        }
    }

    // Normalised event: { title, location, all_day, calendar_id, start, end, status }.
    function parseEvents(list) {
        if (!Array.isArray(list)) throw new Error("Invalid events response")
        return list.filter(e => e && e.status !== "cancelled").map(e => {
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
                calendarId: String(e.calendar_id || ""),
                start: timestamp(e.start), end: timestamp(e.end) }
        })
    }
}
