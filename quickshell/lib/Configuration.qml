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

    // Shaders
    property string currentShader: "none"

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

    // Persistence
    function save() { writeTimer.restart() }

    Timer {
        id: writeTimer
        interval: 60
        onTriggered: root._flush()
    }

    function _flush() {
        configFile.setText(JSON.stringify({
            barStyle:                 root.barStyle,
            barForceWorkspaceMode:    root.barForceWorkspaceMode,
            barShowBattery:           root.barShowBattery,
            barShowTray:              root.barShowTray,
            barHeight:                root.barHeight,
            iconSize:                 root.iconSize,
            showScreenBorders:        root.showScreenBorders,
            desktopMode:              root.desktopMode,
            wallpaperDir:             root.collapseHome(root.wallpaperDir),
            maxEvents:                root.maxEvents,
            useCustomColors:          root.useCustomColors,
            customAccent:             String(root.customAccent),
            customBg:                 String(root.customBg),
            customForeground:         String(root.customForeground),
            customSecondary:          String(root.customSecondary),
            customDanger:             String(root.customDanger),
            currentShader:            root.currentShader,
            borderThickness:          root.borderThickness,
            borderFrameColor:         String(root.borderFrameColor),
            bordersEnabled:           root.bordersEnabled,
            bordersForceVisible:      root.bordersForceVisible,
            borderUseCustomColor:     root.borderUseCustomColor,
            taskbarExclusiveZone:     root.taskbarExclusiveZone,
            taskbarForceDockMode:     root.taskbarForceDockMode,
            taskbarForceWorkspaceMode:root.taskbarForceWorkspaceMode,
            taskbarCustomBg:          root.taskbarCustomBg,
            taskbarCustomBgColor:     String(root.taskbarCustomBgColor),
            taskbarAccent:            String(root.taskbarAccent),
            profileImageOverride:     root.collapseHome(root.profileImageOverride),
            powerMenuLifeDark:        String(root.powerMenuLifeDark),
            powerMenuLifeLight:       String(root.powerMenuLifeLight),
            powerMenuCassiniDark:     String(root.powerMenuCassiniDark),
            powerMenuCassiniLight:    String(root.powerMenuCassiniLight),
            idleLockMin:              root.idleLockMin,
            idleScreenOffMin:         root.idleScreenOffMin,
            idleSleepMin:             root.idleSleepMin,
            codexbarTray:             root.codexbarTray,
            codexbarRefreshSec:       root.codexbarRefreshSec,
            currentTheme:             root.currentTheme
        }))
    }

    function reloadFromDisk() { configFile.reload() }

    function load() {
        try {
            var raw = configFile.text()
            if (!raw || raw.length === 0) return
            var d = JSON.parse(raw)
            if (d.barStyle                 !== undefined) root.barStyle                 = d.barStyle
            if (d.barForceWorkspaceMode    !== undefined) root.barForceWorkspaceMode    = d.barForceWorkspaceMode
            if (d.barShowBattery           !== undefined) root.barShowBattery           = d.barShowBattery
            if (d.barShowTray              !== undefined) root.barShowTray              = d.barShowTray
            if (d.barHeight                !== undefined) root.barHeight                = d.barHeight
            if (d.iconSize                 !== undefined) root.iconSize                 = d.iconSize
            if (d.showScreenBorders        !== undefined) root.showScreenBorders        = d.showScreenBorders
            if (d.desktopMode              !== undefined) root.desktopMode              = d.desktopMode
            if (d.wallpaperDir             !== undefined) root.wallpaperDir             = root.expandHome(d.wallpaperDir)
            if (d.maxEvents                !== undefined) root.maxEvents                = d.maxEvents
            if (d.useCustomColors          !== undefined) root.useCustomColors          = d.useCustomColors
            if (d.customAccent             !== undefined) root.customAccent             = d.customAccent
            if (d.customBg                 !== undefined) root.customBg                 = d.customBg
            if (d.customForeground         !== undefined) root.customForeground         = d.customForeground
            if (d.customSecondary          !== undefined) root.customSecondary          = d.customSecondary
            if (d.customDanger             !== undefined) root.customDanger             = d.customDanger
            if (d.currentShader            !== undefined) root.currentShader            = d.currentShader
            if (d.borderThickness          !== undefined) root.borderThickness          = d.borderThickness
            if (d.borderFrameColor         !== undefined) root.borderFrameColor         = d.borderFrameColor
            if (d.bordersEnabled           !== undefined) root.bordersEnabled           = d.bordersEnabled
            if (d.bordersForceVisible      !== undefined) root.bordersForceVisible      = d.bordersForceVisible
            if (d.borderUseCustomColor     !== undefined) root.borderUseCustomColor     = d.borderUseCustomColor
            if (d.taskbarExclusiveZone     !== undefined) root.taskbarExclusiveZone     = d.taskbarExclusiveZone
            if (d.taskbarForceDockMode     !== undefined) root.taskbarForceDockMode     = d.taskbarForceDockMode
            if (d.taskbarForceWorkspaceMode!== undefined) root.taskbarForceWorkspaceMode= d.taskbarForceWorkspaceMode
            if (d.taskbarCustomBg          !== undefined) root.taskbarCustomBg          = d.taskbarCustomBg
            if (d.taskbarCustomBgColor     !== undefined) root.taskbarCustomBgColor     = d.taskbarCustomBgColor
            if (d.taskbarAccent            !== undefined) root.taskbarAccent            = d.taskbarAccent
            if (d.profileImageOverride     !== undefined) root.profileImageOverride     = root.expandHome(d.profileImageOverride)
            if (d.powerMenuLifeDark        !== undefined) root.powerMenuLifeDark        = d.powerMenuLifeDark
            if (d.powerMenuLifeLight       !== undefined) root.powerMenuLifeLight       = d.powerMenuLifeLight
            if (d.powerMenuCassiniDark     !== undefined) root.powerMenuCassiniDark     = d.powerMenuCassiniDark
            if (d.powerMenuCassiniLight    !== undefined) root.powerMenuCassiniLight    = d.powerMenuCassiniLight
            if (d.idleLockMin              !== undefined) root.idleLockMin              = d.idleLockMin
            if (d.idleScreenOffMin         !== undefined) root.idleScreenOffMin         = d.idleScreenOffMin
            if (d.idleSleepMin             !== undefined) root.idleSleepMin             = d.idleSleepMin
            if (d.codexbarTray             !== undefined) root.codexbarTray             = d.codexbarTray
            if (d.codexbarRefreshSec       !== undefined) root.codexbarRefreshSec       = d.codexbarRefreshSec
            if (d.currentTheme             !== undefined) root.currentTheme             = d.currentTheme
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
        onLoaded: { root.load(); root.ready = true; root.writePowerMenuColors() }
        onLoadFailed: root.ready = true
        onFileChanged: reload()
    }

    FileView {
        id: weatherConfigFile
        path: root.weatherConfigPath
        preload: true
        onLoaded: root.loadWeatherConfig(text())
    }
}
