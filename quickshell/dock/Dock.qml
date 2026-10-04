pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
  id: root

  required property var settings
  required property var host
  signal reorderRequested(int from, int to)
  signal pinRequested(string desktopId)
  signal unpinRequested(string desktopId)
  signal autoHideRequested(bool enabled)

  property int dragSource: -1
  property int dragTarget: -1
  property int openMenuCount: 0
  property bool autoHideRevealed: false

  readonly property int iconSize: settings.iconSize || 52
  readonly property real magnification: settings.magnification || 1.65
  readonly property real magnificationRadius: settings.magnificationRadius || 110
  readonly property int edgeMargin: settings.margin === undefined ? 10 : settings.margin
  readonly property real backgroundOpacity: {
    var value = Number(settings.backgroundOpacity)
    return settings.backgroundOpacity === undefined || isNaN(value)
      ? 0.88
      : Math.max(0, Math.min(1, value))
  }
  readonly property bool reserveSpace: settings.reserveSpace === undefined ? true : settings.reserveSpace
  readonly property bool autoHide: settings.autoHide === undefined ? false : settings.autoHide
  readonly property string clickAction: settings.clickAction || "focus-or-launch"
  readonly property string requestedPosition: settings.position || "bottom"
  readonly property string position: ["top", "bottom", "left", "right"].indexOf(requestedPosition) >= 0
    ? requestedPosition
    : "bottom"
  readonly property bool vertical: position === "left" || position === "right"
  readonly property bool fullLength: settings.fullLength === undefined ? false : settings.fullLength
  readonly property var pinned: settings.pinned || []
  readonly property int itemSize: iconSize + 14
  readonly property int reservedSize: iconSize + 24 + edgeMargin
  readonly property int mainPadding: 10
  readonly property int revealThickness: 3
  readonly property int crossExtent: vertical
    ? Math.ceil(iconSize * magnification + 80) + edgeMargin
    : Math.ceil(iconSize * magnification + 48) + edgeMargin
  readonly property bool keepAutoHideOpen: windowPointer.hovered
    || appPicker.visible || openMenuCount > 0 || dragSource >= 0 || genie.running
  readonly property bool dockShown: !autoHide || !windowInTheWay || autoHideRevealed
  readonly property real pointerPosition: !pointer.hovered
    ? -10000
    : vertical
      ? pointer.point.position.y - dockLayout.y
      : pointer.point.position.x - dockLayout.x

  // ---------------------------------------------------------- windows per app
  // Every Hyprland window, grouped by the dock entry it belongs to: a pinned
  // desktop ID when one matches, otherwise its own desktop entry (or app ID).
  readonly property var applications: DesktopEntries.applications.values || []
  readonly property var groups: {
    var revision = applications.length
    var out = {}
    var list = Hyprland.toplevels.values || []
    for (var i = 0; i < list.length; ++i) {
      var t = list[i]
      var appId = t.wayland ? t.wayland.appId : ""
      if (!appId) continue
      var key = keyForAppId(appId)
      ;(out[key] = out[key] || []).push(t)
    }
    return out
  }
  // This screen's workspace. Only its windows (plus minimized ones, which
  // belong everywhere) count as "running" here.
  readonly property var activeWorkspace: {
    var mon = Hyprland.monitorFor(root.screen)
    return mon ? mon.activeWorkspace : null
  }
  function isHere(toplevel) {
    return isMinimized(toplevel) || (!!toplevel.workspace && toplevel.workspace === activeWorkspace)
  }
  readonly property var groupsHere: {
    var out = {}
    for (var key in groups) {
      var here = groups[key].filter(t => isHere(t))
      if (here.length) out[key] = here
    }
    return out
  }
  readonly property var runningUnpinned: Object.keys(groupsHere).filter(key => pinned.indexOf(key) < 0)

  // Smart hide: the dock steps aside only while a window on this workspace
  // overlaps it; an empty workspace (or windows clear of it) keeps it shown.
  readonly property bool windowInTheWay: {
    if (!autoHide || !activeWorkspace) return false
    var top = root.screen.y + root.screen.height - dockBackground.height - edgeMargin
    var left = root.screen.x + (root.screen.width - dockBackground.width) / 2
    var right = left + dockBackground.width
    var list = Hyprland.toplevels.values || []
    for (var i = 0; i < list.length; ++i) {
      var t = list[i]
      if (t.workspace !== activeWorkspace) continue
      var ipc = t.lastIpcObject
      if (!ipc || !ipc.at || !ipc.size || ipc.hidden) continue
      if (ipc.at[1] + ipc.size[1] > top && ipc.at[0] < right && ipc.at[0] + ipc.size[0] > left)
        return true
    }
    return false
  }
  readonly property int itemCount: pinned.length + runningUnpinned.length

  function normalizedId(value) {
    return String(value || "").toLowerCase().replace(/\.desktop$/, "")
  }

  function keyForAppId(appId) {
    var id = normalizedId(appId)
    for (var i = 0; i < pinned.length; ++i) {
      var entry = DesktopEntries.byId(pinned[i])
      var ids = [pinned[i]]
      if (entry) ids.push(entry.id, entry.startupClass)
      for (var j = 0; j < ids.length; ++j)
        if (normalizedId(ids[j]) === id) return pinned[i]
    }
    var found = DesktopEntries.heuristicLookup(appId)
    return found ? found.id : appId
  }

  function isMinimized(toplevel) {
    return !!toplevel && !!toplevel.workspace && toplevel.workspace.name === host.minimizedWorkspace
  }

  // ---------------------------------------------------------- genie
  // Screen-local rect of a dock icon, for the genie to fly to / from.
  function iconRect(key) {
    var repeaters = [pinnedRepeater, runningRepeater]
    for (var r = 0; r < repeaters.length; ++r) {
      for (var i = 0; i < repeaters[r].count; ++i) {
        var item = repeaters[r].itemAt(i)
        if (item && item.desktopId === key) {
          var p = item.mapToItem(null, item.iconX, item.iconY)
          var winX = root.vertical ? (root.position === "left" ? 0 : root.screen.width - root.width)
                                   : (root.screen.width - root.width) / 2
          var winY = root.vertical ? (root.screen.height - root.height) / 2
                                   : (root.position === "top" ? 0 : root.screen.height - root.height)
          return Qt.rect(winX + p.x, winY + p.y, root.iconSize, root.iconSize)
        }
      }
    }
    return Qt.rect(root.screen.width / 2 - root.iconSize / 2, root.screen.height - root.iconSize - 12,
                   root.iconSize, root.iconSize)
  }

  // Global (layout) coordinates -> this screen's coordinates.
  function localRect(x, y, w, h) {
    return Qt.rect(x - root.screen.x, y - root.screen.y, w, h)
  }

  function playGenie(toplevel, rect, reverse, done) {
    var key = keyForAppId(toplevel.wayland ? toplevel.wayland.appId : "")
    root.autoHideRevealed = true
    genie.then = done
    genie.toRect = iconRect(key)
    genie.play(toplevel.wayland, rect, reverse)
  }

  Genie {
    id: genie
    property var then: null
    screen: root.screen
    onDone: reversed => { if (then) then(); then = null }
  }

  // ---------------------------------------------------------- drag to reorder
  function reorderOffset(index) {
    if (dragSource < 0) return 0
    if (dragSource < dragTarget && index > dragSource && index <= dragTarget)
      return -itemSize
    if (dragSource > dragTarget && index >= dragTarget && index < dragSource)
      return itemSize
    return 0
  }

  function updateDragTarget(position) {
    dragTarget = Math.max(0, Math.min(pinned.length - 1, Math.floor(position / itemSize)))
  }

  function finishDrag() {
    var from = dragSource
    var to = dragTarget
    dragSource = -1
    dragTarget = -1
    if (from >= 0 && to >= 0 && from !== to)
      reorderRequested(from, to)
  }

  function updateAutoHideState() {
    if (!autoHide) {
      hideTimer.stop()
      autoHideRevealed = false
    } else if (keepAutoHideOpen) {
      hideTimer.stop()
      autoHideRevealed = true
    } else if (autoHideRevealed) {
      hideTimer.restart()
    }
  }

  onAutoHideChanged: updateAutoHideState()
  onKeepAutoHideOpenChanged: updateAutoHideState()

  anchors {
    top: position === "top" || (vertical && fullLength)
    bottom: position === "bottom" || (vertical && fullLength)
    left: position === "left" || (!vertical && fullLength)
    right: position === "right" || (!vertical && fullLength)
  }
  implicitWidth: vertical
    ? crossExtent
    : fullLength ? 0 : dockLayout.implicitWidth + mainPadding * 2
  implicitHeight: vertical
    ? fullLength ? 0 : dockLayout.implicitHeight + mainPadding * 2
    : crossExtent
  color: "transparent"
  exclusionMode: reserveSpace && !autoHide ? ExclusionMode.Normal : ExclusionMode.Ignore
  WlrLayershell.exclusiveZone: reserveSpace && !autoHide ? reservedSize : 0
  WlrLayershell.namespace: "hyprland-dock"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {
    item: root.dockShown ? interactionArea : revealStrip
  }

  Item {
    id: interactionArea
    anchors.fill: parent
  }

  Timer {
    id: hideTimer
    interval: 800
    onTriggered: if (root.autoHide && !root.keepAutoHideOpen)
      root.autoHideRevealed = false
  }

  Item {
    id: revealStrip
    x: root.position === "right" ? parent.width - width : 0
    y: root.position === "bottom" ? parent.height - height : 0
    width: root.vertical ? root.revealThickness : parent.width
    height: root.vertical ? parent.height : root.revealThickness
  }

  Rectangle {
    id: dockBackground

    x: root.vertical
      ? root.position === "left" ? root.edgeMargin : parent.width - width - root.edgeMargin
      : 0
    y: root.vertical
      ? 0
      : root.position === "top" ? root.edgeMargin : parent.height - height - root.edgeMargin
    width: root.vertical ? root.iconSize + 24 : parent.width
    height: root.vertical ? parent.height : root.iconSize + 24
    radius: 20
    color: Qt.rgba(0.08, 0.09, 0.11, root.backgroundOpacity)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.18)
    transform: Translate {
      x: !root.autoHide || root.dockShown
        ? 0
        : root.position === "left"
          ? -(dockBackground.width + root.edgeMargin)
          : root.position === "right" ? dockBackground.width + root.edgeMargin : 0
      y: !root.autoHide || root.dockShown
        ? 0
        : root.position === "top"
          ? -(dockBackground.height + root.edgeMargin)
          : root.position === "bottom" ? dockBackground.height + root.edgeMargin : 0

      Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
      Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: 1
      radius: parent.radius - 1
      color: "transparent"
      border.width: 1
      border.color: Qt.rgba(0, 0, 0, 0.28)
    }

    Grid {
      id: dockLayout

      // Offset the layout toward the screen edge so the icon itself, rather
      // than the icon-plus-indicator slot, is centered in the background.
      x: root.vertical
        ? root.position === "left" ? 6 : parent.width - implicitWidth - 6
        : (parent.width - implicitWidth) / 2
      y: root.vertical
        ? (parent.height - implicitHeight) / 2
        : root.position === "top" ? 6 : parent.height - implicitHeight - 6

      // One spare cell so a reload cannot shrink the grid before the repeaters update.
      columns: root.vertical ? 1 : root.itemCount + 2
      rows: root.vertical ? root.itemCount + 2 : 1

      Repeater {
        id: pinnedRepeater
        model: root.pinned

        DockItem {
          required property string modelData
          required property int index

          desktopId: modelData
          pinned: true
          windows: root.groups[modelData] || []
          windowsHere: root.groupsHere[modelData] || []
          dock: root
          itemIndex: index
          reorderOffset: root.reorderOffset(index)
        }
      }

      // Separator between kept apps and apps that are only running.
      Item {
        visible: root.runningUnpinned.length > 0
        width: root.vertical ? root.itemSize : 12
        height: root.vertical ? 12 : root.itemSize + 6
        Rectangle {
          anchors.centerIn: parent
          width: root.vertical ? root.iconSize * 0.8 : 1
          height: root.vertical ? 1 : root.iconSize * 0.8
          color: Qt.rgba(1, 1, 1, 0.22)
        }
      }

      Repeater {
        id: runningRepeater
        model: root.runningUnpinned

        DockItem {
          required property string modelData
          required property int index

          desktopId: modelData
          pinned: false
          windows: root.groups[modelData] || []
          windowsHere: root.groupsHere[modelData] || []
          dock: root
          itemIndex: -1
        }
      }
    }

    HoverHandler {
      id: pointer
    }
  }

  DockAppPicker {
    id: appPicker
    anchorItem: dockBackground
    position: root.position
    pinned: root.pinned
    onApplicationSelected: desktopId => root.pinRequested(desktopId)
  }

  function openAppPicker() { appPicker.open() }

  HoverHandler {
    id: windowPointer
  }
}
