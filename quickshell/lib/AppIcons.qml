pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property var rules: []
    property string fallback: ""

    function load(raw) {
        try {
            const data = JSON.parse(raw)
            rules = data.icons || []
            fallback = data.default || ""
        } catch (error) {
            console.warn("[AppIcons] Invalid app-icons.json:", error)
        }
    }

    function source(path) {
        if (!path) return ""
        if (path.startsWith("file:") || path.startsWith("image:")) return path
        if (path.startsWith("~/")) return "file://" + Quickshell.env("HOME") + path.slice(1)
        if (path.startsWith("/")) return "file://" + path
        return Qt.resolvedUrl("../" + path)
    }

    function lookup(appClass) {
        const cls = String(appClass || "").toLowerCase()
        for (const rule of rules) {
            if ((rule.match || []).some(name => cls.includes(String(name).toLowerCase()))) {
                const icon = String(rule.icon || fallback)
                const isFile = icon.includes("/") || icon.startsWith("file:") || icon.startsWith("image:")
                return isFile
                    ? { glyph: "", source: source(icon), activeColor: String(rule.activeColor || ""), inactiveColor: String(rule.inactiveColor || "") }
                    : { glyph: icon, source: "", activeColor: "", inactiveColor: "" }
            }
        }
        return { glyph: fallback, source: "", activeColor: "", inactiveColor: "" }
    }

    FileView {
        id: iconFile
        path: Quickshell.env("HOME") + "/.config/quickshell/app-icons.json"
        preload: true
        watchChanges: true
        onFileChanged: reload()
        onTextChanged: root.load(text())
    }
}
