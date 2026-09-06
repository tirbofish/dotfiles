pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    readonly property string configPath:
        Qt.resolvedUrl("plugins.json").toString().replace("file://", "")
    property var trayPlugins: []
    property bool ready: false

    function isEnabled(id) {
        return root.trayPlugins.indexOf(id) !== -1
    }

    function setEnabled(id, on) {
        var next = []
        for (var i = 0; i < root.trayPlugins.length; i++) {
            if (root.trayPlugins[i] !== id)
                next.push(root.trayPlugins[i])
        }
        if (on)
            next.push(id)
        root.trayPlugins = next
        root.save()
    }

    function save() {
        configFile.setText(JSON.stringify({ tray: root.trayPlugins }, null, 2) + "\n")
    }

    function load() {
        try {
            var raw = configFile.text()
            if (!raw || raw.length === 0)
                return
            var d = JSON.parse(raw)
            if (d && d.tray && d.tray.length !== undefined)
                root.trayPlugins = d.tray
        } catch (e) {
            console.warn("[PluginHost] load failed:", e)
        }
    }

    FileView {
        id: configFile
        path: root.configPath
        preload: true
        onLoaded: { root.load(); root.ready = true }
        onLoadFailed: root.ready = true
    }
}
