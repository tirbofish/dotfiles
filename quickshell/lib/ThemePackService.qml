pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property var packs: []
    property int packCount: 0
    property string currentId: ""
    property string error: ""
    readonly property string script:
        (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/theme.sh"
    readonly property string cachePath:
        (Quickshell.env("HOME") || "") + "/.cache/quickshell/theme-packs.json"

    function refresh() {
        listProc.running = false
        listProc.running = true
    }

    function apply(id) {
        if (!id) return
        Configuration.switchTheme(String(id))
        applyProc.command = ["bash", root.script, "apply", String(id)]
        applyProc.running = false
        applyProc.running = true
    }

    function loadPacks(raw) {
        try {
            var data = JSON.parse(String(raw || "[]").trim() || "[]")
            if (!Array.isArray(data)) data = []
            root.packs = data
            root.packCount = data.length
            root.error = data.length ? "" : "No theme packs in ~/.config/themes"
            for (var i = 0; i < data.length; i++) {
                if (data[i].active) {
                    root.currentId = data[i].id
                    break
                }
            }
        } catch (e) {
            root.error = "Could not list themes"
        }
    }

    Process {
        id: listProc
        command: ["bash", "-lc",
            "mkdir -p \"$HOME/.cache/quickshell\"; " + root.script + " list | tee \"" + root.cachePath + "\""]
        stdout: StdioCollector {
            onStreamFinished: root.loadPacks(this.text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                var t = String(this.text || "").trim()
                if (t) root.error = t
            }
        }
    }

    Process {
        id: applyProc
        onExited: function(code) {
            root.refresh()
            if (code !== 0) {
                root.error = "Theme apply failed"
                return
            }
            Configuration.reloadFromDisk()
        }
    }

    FileView {
        path: root.cachePath
        watchChanges: true
        onLoaded: root.loadPacks(text())
        onTextChanged: root.loadPacks(text())
        onFileChanged: reload()
        onLoadFailed: root.refresh()
    }

    Timer {
        interval: 400
        running: true
        repeat: false
        onTriggered: root.refresh()
    }
}
