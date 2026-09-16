pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    readonly property string configHome:
        Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"
    readonly property string configPath:
        Qt.resolvedUrl("usersettings.json").toString().replace("file://", "")
    readonly property string weatherConfigPath:
        configHome + "/quickshell/weather_api.conf"

    // Bar / Dock
    // Settings from disk a beat after startup;
    property bool ready: false

    property string barStyle:              "task"
    property bool   barForceWorkspaceMode: false
    property bool   barShowBattery:        true
    property bool   barShowTray:           true
    property int    barHeight:             50
    property int    iconSize:              24

    // Desktop
    property bool   showScreenBorders: true
    property string desktopMode:       "tirbofish"
    property string wallpaperDir:      Quickshell.env("HOME") + "/Pictures/Wallpapers"

    // External tools
    readonly property string nowPlayingBin:
        Qt.resolvedUrl("../bin/now_playing").toString().replace("file://", "")
    readonly property string screenshotScript: configHome + "/hypr/screenshots/captureArea.sh"
    readonly property string evercalBin:       "/opt/evercal/ever_cal"

    // Hub
    property int    maxEvents:       1
    property bool   useCustomColors: false
    property color  customAccent:    "#7AA1A6"
    property color  customBg:        "#141719"
    property color  customForeground:"#DDE5DF"
    property color  customSecondary: "#7AA1A6"
    property color  customDanger:    "#E67E80"

    // Weather
    property string weatherApiKey: ""
    property string weatherLat:    ""
    property string weatherLon:    ""

    // Screen borders
    property int    borderThickness:    7
    property color  borderFrameColor:   "#141719"
    property bool   bordersEnabled:     true
    property bool   bordersForceVisible: false
    property bool   borderUseCustomColor: false

    // Taskbar
    property int    taskbarExclusiveZone:      53
    property bool   taskbarForceDockMode:      false
    property bool   taskbarForceWorkspaceMode: false
    property bool   taskbarCustomBg:           false
    property color  taskbarCustomBgColor:      "#141719"
    property color  taskbarAccent:             customAccent

    // Profile
    property string profileImageOverride: ""

    // CodexBar
    property bool codexbarTray: true
    property int  codexbarRefreshSec: 300

    // Theme packs (~/.config/themes/<id>)
    property string currentTheme: ""

    // Top-bar hanging cava. 1 = current baked-in look.
    property real barCavaOpacity: 1.0

    // Shaders
    property string currentShader: "none"

    // Clipboard history (cliphist). Queue of at most N items; wiped on reboot.
    property int clipboardMaxItems: 20
    readonly property string clipboardScript:
        (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/clipboard-history.sh"

    function clampClipboard() {
        if (root.clipboardMaxItems < 1) root.clipboardMaxItems = 1
        if (root.clipboardMaxItems > 200) root.clipboardMaxItems = 200
    }

    Timer {
        id: clipboardApplyTimer
        interval: 400
        onTriggered: Quickshell.execDetached(["bash", root.clipboardScript, "apply"])
    }

    function applyClipboard() {
        root.clampClipboard()
        root.save()
        clipboardApplyTimer.restart()
    }

    function wipeClipboard() {
        Quickshell.execDetached(["bash", root.clipboardScript, "wipe"])
    }

    // Idle / sleep (minutes). 0 = never.
    property int idleLockMin: 3
    property int idleScreenOffMin: 6
    property int idleSleepMin: 20
    readonly property string idleScript:
        (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/idle.sh"

    function clampIdle() {
        if (root.idleLockMin < 0) root.idleLockMin = 0
        if (root.idleScreenOffMin < 0) root.idleScreenOffMin = 0
        if (root.idleSleepMin < 0) root.idleSleepMin = 0
        if (root.idleLockMin > 0 && root.idleScreenOffMin > 0 && root.idleScreenOffMin < root.idleLockMin)
            root.idleScreenOffMin = root.idleLockMin
        if (root.idleScreenOffMin > 0 && root.idleSleepMin > 0 && root.idleSleepMin < root.idleScreenOffMin)
            root.idleSleepMin = root.idleScreenOffMin
        else if (root.idleLockMin > 0 && root.idleSleepMin > 0 && root.idleSleepMin < root.idleLockMin)
            root.idleSleepMin = root.idleLockMin
    }

    Timer {
        id: idleApplyTimer
        interval: 400
        onTriggered: Quickshell.execDetached(["bash", root.idleScript, "apply"])
    }

    function applyIdle() {
        root.clampIdle()
        root.save()
        idleApplyTimer.restart()
    }

    function toggleCaffeine() {
        Quickshell.execDetached(["bash", root.idleScript, "toggle"])
    }

    // Power menu
    // Skin selector shared with utils/PowerMenu.qml.
    property string powerMenuStyle: "life"

    // Per-skin accent colours
    property color powerMenuLifeDark:     customAccent
    property color powerMenuLifeLight:    customAccent
    property color powerMenuCassiniDark:  customAccent
    property color powerMenuCassiniLight: customAccent

    readonly property string _baseDir:
        Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, "")
    readonly property string _cacheDir: _baseDir.split("/").slice(0, -1).join("/") + "/.cache"
    readonly property string powerMenuStyleFile:  _cacheDir + "/power_menu_style"
    readonly property string powerMenuColorsFile: _cacheDir + "/power_menu_colors"

    function setPowerMenuStyle(s) {
        if (s !== "life" && s !== "cassini") return
        powerMenuStyle = s
        Quickshell.execDetached(["bash", "-c",
            "mkdir -p \"$(dirname '" + powerMenuStyleFile + "')\"; " +
            "printf '%s' '" + s + "' > '" + powerMenuStyleFile + "'"])
    }

    // Set one accent for (style x theme) and republish the colours cache that
    // utils/PowerMenu.qml reads on launch.
    function setPowerMenuColor(style, dark, hex) {
        if (style === "cassini") { if (dark) powerMenuCassiniDark = hex; else powerMenuCassiniLight = hex }
        else                     { if (dark) powerMenuLifeDark    = hex; else powerMenuLifeLight    = hex }
        save()
        writePowerMenuColors()
    }

    // Restore all power-menu accents to their built-in defaults.
    function resetPowerMenuColors() {
        powerMenuLifeDark     = customAccent
        powerMenuLifeLight    = customAccent
        powerMenuCassiniDark  = customAccent
        powerMenuCassiniLight = customAccent
        save()
        writePowerMenuColors()
    }

    function writePowerMenuColors() {
        var json = JSON.stringify({
            lifeDark:     String(powerMenuLifeDark),
            lifeLight:    String(powerMenuLifeLight),
            cassiniDark:  String(powerMenuCassiniDark),
            cassiniLight: String(powerMenuCassiniLight)
        })
        Quickshell.execDetached(["bash", "-c",
            "mkdir -p \"$(dirname '" + powerMenuColorsFile + "')\"; " +
            "printf '%s' '" + json + "' > '" + powerMenuColorsFile + "'"])
    }

    FileView {
        id: pmStyleFile
        path: root.powerMenuStyleFile
        preload: true
        onLoaded: {
            var s = String(text() || "").trim().toLowerCase()
            if (s === "cassini" || s === "life") root.powerMenuStyle = s
        }
    }

    function expandHome(path) {
        var home = Quickshell.env("HOME")
        if (typeof path !== "string" || home === "") return path
        if (path === "$HOME" || path === "~") return home
        if (path.indexOf("$HOME/") === 0) return home + path.slice(5)
        if (path.indexOf("~/") === 0) return home + path.slice(1)
        return path
    }

    function collapseHome(path) {
        var home = Quickshell.env("HOME")
        if (typeof path !== "string" || home === "") return path
        if (path === home) return "$HOME"
        if (path.indexOf(home + "/") === 0) return "$HOME" + path.slice(home.length)
        return path
    }

    // Persistence — every user-facing setting goes through this list.
    readonly property var persistKeys: [
        "barStyle", "barForceWorkspaceMode", "barShowBattery", "barShowTray",
        "barHeight", "iconSize", "barCavaOpacity",
        "showScreenBorders", "desktopMode", "wallpaperDir",
        "maxEvents", "useCustomColors", "customAccent", "customBg",
        "customForeground", "customSecondary", "customDanger",
        "currentShader",
        "borderThickness", "borderFrameColor", "bordersEnabled",
        "bordersForceVisible", "borderUseCustomColor",
        "taskbarExclusiveZone", "taskbarForceDockMode", "taskbarForceWorkspaceMode",
        "taskbarCustomBg", "taskbarCustomBgColor", "taskbarAccent",
        "profileImageOverride",
        "powerMenuStyle",
        "powerMenuLifeDark", "powerMenuLifeLight",
        "powerMenuCassiniDark", "powerMenuCassiniLight",
        "clipboardMaxItems",
        "idleLockMin", "idleScreenOffMin", "idleSleepMin",
        "codexbarTray", "codexbarRefreshSec",
        "currentTheme"
    ]
    readonly property var persistHomeKeys: ["wallpaperDir", "profileImageOverride"]
    readonly property var persistColorKeys: [
        "customAccent", "customBg", "customForeground", "customSecondary", "customDanger",
        "borderFrameColor", "taskbarCustomBgColor", "taskbarAccent",
        "powerMenuLifeDark", "powerMenuLifeLight",
        "powerMenuCassiniDark", "powerMenuCassiniLight"
    ]

    readonly property string themesRoot: root.configHome + "/themes"
    readonly property string themeSettingsPath: root.currentTheme
        ? (root.themesRoot + "/" + root.currentTheme + "/settings.json")
        : ""

    property bool ioLock: false

    function save() { writeTimer.restart() }

    Timer {
        id: writeTimer
        interval: 60
        onTriggered: root._flush()
    }

    Timer {
        id: unlockTimer
        interval: 80
        onTriggered: root.ioLock = false
    }

    function _lockIo() {
        root.ioLock = true
        unlockTimer.restart()
    }

    function _isColorKey(k) {
        return root.persistColorKeys.indexOf(k) >= 0
    }
    function _isHomeKey(k) {
        return root.persistHomeKeys.indexOf(k) >= 0
    }

    function snapshot(includeThemeId) {
        var o = {}
        var keys = root.persistKeys
        for (var i = 0; i < keys.length; i++) {
            var k = keys[i]
            if (!includeThemeId && k === "currentTheme") continue
            var v = root[k]
            if (root._isHomeKey(k)) v = root.collapseHome(v)
            else if (root._isColorKey(k)) v = String(v)
            o[k] = v
        }
        return o
    }

    function applySnapshot(d) {
        if (d === undefined || d === null || d === "") return false
        if (typeof d === "string") {
            try { d = JSON.parse(d) } catch (e) {
                console.warn("[Configuration] theme snapshot parse failed:", e)
                return false
            }
        }
        if (typeof d !== "object") return false
        var keys = root.persistKeys
        for (var i = 0; i < keys.length; i++) {
            var k = keys[i]
            if (k === "currentTheme") continue
            if (d[k] === undefined) continue
            var v = d[k]
            if (root._isHomeKey(k)) v = root.expandHome(v)
            root[k] = v
        }
        return true
    }

    function _writeSideFiles() {
        root.writePowerMenuColors()
        if (root.powerMenuStyle === "life" || root.powerMenuStyle === "cassini")
            Quickshell.execDetached(["bash", "-c",
                "mkdir -p \"$(dirname '" + root.powerMenuStyleFile + "')\"; " +
                "printf '%s' '" + root.powerMenuStyle + "' > '" + root.powerMenuStyleFile + "'"])
    }

    function _flush() {
        root._lockIo()
        var full = root.snapshot(true)
        configFile.setText(JSON.stringify(full))
        if (root.currentTheme && themeFile.path)
            themeFile.setText(JSON.stringify(root.snapshot(false)))
        root._writeSideFiles()
    }

    function reloadFromDisk() { configFile.reload() }

    function reloadAll() {
        configFile.reload()
        weatherConfigFile.reload()
        pmStyleFile.reload()
        if (root.currentTheme)
            themeFile.reload()
        root.clampIdle()
        root.clampClipboard()
        root.writePowerMenuColors()
        idleApplyTimer.restart()
        clipboardApplyTimer.restart()
    }

    function quickReload() {
        writeTimer.stop()
        root._flush()
        root.reloadAll()
        Quickshell.reload(false)
    }

    // Save the live settings into the old pack, then load the new pack.
    function switchTheme(id) {
        id = String(id || "")
        if (!id) return
        writeTimer.stop()
        root._flush()
        root.currentTheme = id
        root._lockIo()
        configFile.setText(JSON.stringify(root.snapshot(true)))
        themeFile.reload()
    }

    function load() {
        try {
            var raw = configFile.text()
            if (!raw || raw.length === 0) return
            var d = JSON.parse(raw)
            var keys = root.persistKeys
            for (var i = 0; i < keys.length; i++) {
                var k = keys[i]
                if (d[k] === undefined) continue
                var v = d[k]
                if (root._isHomeKey(k)) v = root.expandHome(v)
                root[k] = v
            }
        } catch(e) {
            console.warn("[Configuration] load failed:", e)
        }
    }

    function loadWeatherConfig(raw) {
        var key = /(?:^|\n)API_KEY="([^"]*)"/.exec(raw)
        var lat = /(?:^|\n)LAT="([^"]*)"/.exec(raw)
        var lon = /(?:^|\n)LON="([^"]*)"/.exec(raw)
        if (key) weatherApiKey = key[1]
        if (lat) weatherLat = lat[1]
        if (lon) weatherLon = lon[1]
    }

    FileView {
        id: configFile
        path: root.configPath
        preload: true
        watchChanges: true
        onLoaded: {
            if (root.ioLock) return
            root.load()
            root.ready = true
            root.writePowerMenuColors()
            if (root.currentTheme)
                themeFile.reload()
        }
        onLoadFailed: root.ready = true
        onFileChanged: if (!root.ioLock) reload()
    }

    FileView {
        id: themeFile
        path: root.themeSettingsPath
        preload: true
        watchChanges: true
        onLoaded: {
            if (!root.currentTheme) return
            root.applySnapshot(text())
            root._writeSideFiles()
            root.clampIdle()
            root.clampClipboard()
        }
        onLoadFailed: {
            // First visit to this pack: keep live settings and seed the file.
            if (root.currentTheme)
                root._flush()
        }
        onFileChanged: if (!root.ioLock && root.currentTheme) reload()
    }

    FileView {
        id: weatherConfigFile
        path: root.weatherConfigPath
        preload: true
        onLoaded: root.loadWeatherConfig(text())
    }
}
