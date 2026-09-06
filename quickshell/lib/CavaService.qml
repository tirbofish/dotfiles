pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    readonly property int barCount: 24
    property var values: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property bool available: false
    readonly property string configPath:
        Qt.resolvedUrl("../cava-bars.conf").toString().replace("file://", "")

    function applyLine(data) {
        var parts = String(data || "").trim().split(";")
        var out = []
        for (var i = 0; i < root.barCount; i++) {
            var n = parseInt(parts[i], 10)
            out.push(isNaN(n) ? 0 : Math.max(0, Math.min(100, n)))
        }
        root.values = out
        root.available = true
    }

    Process {
        id: cavaProc
        running: true
        command: ["bash", "-lc",
            "command -v cava >/dev/null || exit 127; " +
            "exec stdbuf -oL cava -p '" + root.configPath + "'"]
        stdout: SplitParser {
            onRead: (data) => root.applyLine(data)
        }
        onExited: (code) => {
            root.available = false
            restartTimer.interval = (code === 127) ? 30000 : 4000
            restartTimer.restart()
        }
    }

    Timer {
        id: restartTimer
        interval: 4000
        repeat: false
        onTriggered: {
            cavaProc.running = false
            cavaProc.running = true
        }
    }
}
