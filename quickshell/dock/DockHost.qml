pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// macOS-style dock. Based on nick-friedrich/hyprland-dock (see LICENSE),
// extended with running apps, per-app window lists and the genie effect.
//
// Every minimize/restore goes through hypr/scripts/minimized-windows.sh, which
// calls the IPC handler below (and falls back to a plain move without us).
Item {
  id: root

  readonly property string configPath: Qt.resolvedUrl("dock.json").toString().replace("file://", "")
  readonly property string minimizedWorkspace: "special:minimized"

  property var settings: ({
    iconSize: 48,
    magnification: 1.6,
    magnificationRadius: 110,
    margin: 8,
    backgroundOpacity: 0.72,
    position: "bottom",
    fullLength: false,
    reserveSpace: true,
    autoHide: false,
    clickAction: "focus-or-launch",
    pinned: []
  })

  // address -> { rect, screen }: where a window was when it was minimized,
  // so the restore genie flies back to the same place.
  property var minimizedFrom: ({})

  function normAddress(a) {
    return String(a || "").toLowerCase().replace(/^0x/, "")
  }

  function toplevelFor(address) {
    var wanted = normAddress(address)
    var list = Hyprland.toplevels.values || []
    for (var i = 0; i < list.length; ++i)
      if (normAddress(list[i].address) === wanted) return list[i]
    return null
  }

  function dockFor(screenName) {
    var docks = dockVariants.instances
    for (var i = 0; i < docks.length; ++i)
      if (docks[i].screen && docks[i].screen.name === screenName) return docks[i]
    return docks.length ? docks[0] : null
  }

  function focusedScreenName() {
    return Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
  }

  function dispatch(lua) {
    Hyprland.dispatch(lua)
  }

  function minimize(address, x, y, w, h, screenName) {
    var top = toplevelFor(address)
    var dock = dockFor(screenName)
    var addr = "0x" + normAddress(address)
    var moveOut = 'hl.dsp.window.move({ workspace = "' + minimizedWorkspace
      + '", follow = false, window = "address:' + addr + '" })'
    if (!top || !dock || !(w > 0 && h > 0)) {
      dispatch(moveOut)
      return
    }
    var from = Object.assign({}, minimizedFrom)
    from[normAddress(address)] = { rect: dock.localRect(x, y, w, h), screen: screenName }
    minimizedFrom = from
    dock.playGenie(top, from[normAddress(address)].rect, false, function() {})
    // Let the genie grab a live frame before the window leaves the screen.
    moveLater.command = moveOut
    moveLater.restart()
  }

  Timer {
    id: moveLater
    property string command: ""
    interval: 70
    onTriggered: root.dispatch(command)
  }

  function restore(address) {
    var addr = "0x" + normAddress(address)
    var bringBack = function() {
      var ws = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
      root.dispatch('hl.dsp.window.move({ workspace = ' + ws + ', follow = false, window = "address:' + addr + '" })')
      root.dispatch('hl.dsp.focus({ window = "address:' + addr + '" })')
      root.dispatch('hl.dsp.window.alter_zorder({ mode = "top", window = "address:' + addr + '" })')
    }
    var saved = minimizedFrom[normAddress(address)]
    var top = toplevelFor(address)
    var dock = dockFor(saved ? saved.screen : focusedScreenName())
    if (!saved || !top || !dock) {
      bringBack()
      return
    }
    var from = Object.assign({}, minimizedFrom)
    delete from[normAddress(address)]
    minimizedFrom = from
    dock.playGenie(top, saved.rect, true, bringBack)
  }

  function loadSettings(raw) {
    try {
      var parsed = JSON.parse(raw)
      if (!parsed.pinned || !Array.isArray(parsed.pinned))
        throw new Error("'pinned' must be an array")
      settings = parsed
    } catch (error) {
      console.warn("Dock: could not load " + configPath + ":", error)
    }
  }

  function reorderPinned(from, to) {
    if (from === to || from < 0 || to < 0
        || from >= settings.pinned.length || to >= settings.pinned.length)
      return
    var pinned = settings.pinned.slice()
    var moved = pinned.splice(from, 1)[0]
    pinned.splice(to, 0, moved)
    saveSetting("pinned", pinned)
  }

  function pinApplication(desktopId) {
    if (!desktopId || settings.pinned.indexOf(desktopId) >= 0) return
    saveSetting("pinned", settings.pinned.concat([desktopId]))
  }

  function unpinApplication(desktopId) {
    var index = settings.pinned.indexOf(desktopId)
    if (index < 0) return
    var pinned = settings.pinned.slice()
    pinned.splice(index, 1)
    saveSetting("pinned", pinned)
  }

  function saveSetting(key, value) {
    var updated = Object.assign({}, settings)
    updated[key] = value
    settings = updated
    configFile.setText(JSON.stringify(updated, null, 2) + "\n")
  }

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    blockWrites: true
    onLoaded: root.loadSettings(text())
    // text() is still stale inside onFileChanged; reload and parse on onLoaded.
    onFileChanged: reload()
    onSaveFailed: error => console.warn("Dock: could not save " + root.configPath + ":", error)
  }

  // Window geometry (lastIpcObject) only updates on refresh; smart hide needs it current.
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (/^(openwindow|closewindow|movewindow|changefloatingmode|fullscreen|workspace|focusedmon|activewindowv2)/.test(event.name))
        refreshSoon.restart()
    }
  }
  Timer {
    id: refreshSoon
    interval: 120
    onTriggered: Hyprland.refreshToplevels()
  }
  // ponytail: dragging a floating window sends no event, so poll slowly while
  // auto-hide is on; drop this if Hyprland grows a window-geometry event.
  Timer {
    running: root.settings.autoHide === true
    repeat: true
    interval: 1500
    onTriggered: Hyprland.refreshToplevels()
  }

  IpcHandler {
    target: "dock"
    function minimize(address: string, x: int, y: int, w: int, h: int, screen: string): void {
      root.minimize(address, x, y, w, h, screen)
    }
    function restore(address: string): void {
      root.restore(address)
    }
  }

  Variants {
    id: dockVariants
    model: Quickshell.screens

    delegate: Component {
      Dock {
        required property var modelData
        screen: modelData
        settings: root.settings
        host: root
        onReorderRequested: (from, to) => root.reorderPinned(from, to)
        onPinRequested: desktopId => root.pinApplication(desktopId)
        onUnpinRequested: desktopId => root.unpinApplication(desktopId)
        onAutoHideRequested: enabled => root.saveSetting("autoHide", enabled)
      }
    }
  }
}
