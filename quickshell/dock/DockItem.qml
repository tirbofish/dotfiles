import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
  id: root

  required property string desktopId
  required property bool pinned
  required property var windows      // HyprlandToplevel[] for this app, every workspace
  required property var windowsHere  // the ones on this screen's workspace (or minimized)
  required property var dock
  required property int itemIndex    // position among pinned items, -1 if not pinned
  property real reorderOffset: 0

  readonly property int slotSize: dock.itemSize
  readonly property int iconSize: dock.iconSize
  readonly property string position: dock.position
  readonly property bool vertical: dock.vertical
  readonly property real iconX: iconContainer.x
  readonly property real iconY: iconContainer.y

  // Reading the model makes this binding update when Quickshell finishes its
  // asynchronous desktop-entry scan. Calling byId() alone is not reactive.
  readonly property var entry: {
    var revision = dock.applications.length
    return DesktopEntries.byId(desktopId)
  }
  readonly property bool running: windowsHere.length > 0
  readonly property real dragOffset: dragHandler.active
    ? vertical ? dragHandler.activeTranslation.y : dragHandler.activeTranslation.x
    : 0
  readonly property real itemCenter: (vertical ? y + height / 2 : x + width / 2)
    + dragOffset + reorderOffset
  readonly property real distance: Math.abs(dock.pointerPosition - itemCenter)
  readonly property real influence: dock.pointerPosition < -1000
    ? 0
    : Math.exp(-(distance * distance) / (dock.magnificationRadius * dock.magnificationRadius))
  readonly property real iconScale: 1 + (dock.magnification - 1) * influence

  // Most recently focused first; this workspace's windows ahead of the rest.
  function sortedWindows() {
    return windows.slice().sort((a, b) => {
      var ha = windowsHere.indexOf(a) >= 0 ? 0 : 1
      var hb = windowsHere.indexOf(b) >= 0 ? 0 : 1
      if (ha !== hb) return ha - hb
      var fa = a.lastIpcObject ? a.lastIpcObject.focusHistoryID : 999
      var fb = b.lastIpcObject ? b.lastIpcObject.focusHistoryID : 999
      return (fa === undefined ? 999 : fa) - (fb === undefined ? 999 : fb)
    })
  }

  function launch() {
    bounce.restart()
    if (entry)
      entry.execute()
    else
      Quickshell.execDetached(["gtk-launch", desktopId + ".desktop"])
  }

  function focusWindow(toplevel) {
    if (dock.isMinimized(toplevel)) {
      dock.host.restore(toplevel.address)
      return
    }
    dock.host.dispatch('hl.dsp.focus({ window = "address:0x' + dock.host.normAddress(toplevel.address) + '" })')
  }

  // macOS: show the app's latest window; if every window is minimized, bring the latest back.
  function activateOrLaunch() {
    var list = sortedWindows()
    if (dock.clickAction !== "focus-or-launch" || list.length === 0) {
      launch()
      return
    }
    for (var i = 0; i < list.length; ++i) {
      if (!dock.isMinimized(list[i])) {
        focusWindow(list[i])
        return
      }
    }
    focusWindow(list[0])
  }

  function quit() {
    for (var i = 0; i < windows.length; ++i)
      if (windows[i].wayland) windows[i].wayland.close()
  }

  width: vertical ? slotSize + 6 : slotSize
  height: vertical ? slotSize : slotSize + 6
  z: dragHandler.active ? 2 : 0
  transform: Translate {
    x: root.vertical ? 0 : root.dragOffset + root.reorderOffset
    y: root.vertical ? root.dragOffset + root.reorderOffset : 0
  }

  Behavior on reorderOffset {
    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
  }

  Item {
    id: iconContainer

    property real lift: 0

    x: root.vertical
      ? root.position === "left" ? 6 : root.width - root.iconSize - 6
      : (root.width - root.iconSize) / 2
    y: root.vertical
      ? (root.height - root.iconSize) / 2
      : root.position === "top" ? 6 : root.height - root.iconSize - 6
    width: root.iconSize
    height: root.iconSize
    transformOrigin: root.position === "top"
      ? Item.Top
      : root.position === "left"
        ? Item.Left
        : root.position === "right" ? Item.Right : Item.Bottom
    scale: root.iconScale
    transform: Translate { y: root.position === "bottom" ? -iconContainer.lift : iconContainer.lift }

    Behavior on scale {
      NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
    }

    // Launch bounce, like the real dock.
    SequentialAnimation {
      id: bounce
      loops: 2
      NumberAnimation { target: iconContainer; property: "lift"; to: root.iconSize * 0.35; duration: 220; easing.type: Easing.OutQuad }
      NumberAnimation { target: iconContainer; property: "lift"; to: 0; duration: 220; easing.type: Easing.InQuad }
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: -4
      radius: 14
      color: mouse.hovered ? Qt.rgba(1, 1, 1, 0.10) : "transparent"

      Behavior on color { ColorAnimation { duration: 100 } }
    }

    IconImage {
      anchors.fill: parent
      // Unchecked lookup: the checked one misses icons that only live in
      // hicolor/pixmaps (brave, kitty, anki) after a reload.
      source: Quickshell.iconPath(root.entry && root.entry.icon ? root.entry.icon : String(root.desktopId).toLowerCase(),
                                  "application-x-executable")
      asynchronous: true
    }
  }

  // Running indicator.
  Rectangle {
    width: 4
    height: 4
    radius: 2
    x: root.position === "left"
      ? iconContainer.x + iconContainer.width + 2
      : root.position === "right"
        ? iconContainer.x - 6
        : iconContainer.x + (iconContainer.width - width) / 2
    y: root.position === "top"
      ? iconContainer.y - 6
      : root.position === "bottom"
        ? iconContainer.y + iconContainer.height + 2
        : iconContainer.y + (iconContainer.height - height) / 2
    color: root.running ? "#f5f5f5" : "transparent"
  }

  Rectangle {
    id: tooltip

    visible: mouse.hovered && !contextMenu.visible
    x: root.position === "left"
      ? iconContainer.x + iconContainer.width + 12
      : root.position === "right"
        ? iconContainer.x - width - 12
        : (root.width - width) / 2
    y: root.position === "top"
      ? iconContainer.y + iconContainer.height * root.iconScale + 12
      : root.position === "bottom"
        ? iconContainer.y + iconContainer.height * (1 - root.iconScale) - height - 12
        : (root.height - height) / 2
    width: tooltipText.implicitWidth + 18
    height: tooltipText.implicitHeight + 10
    radius: 8
    color: Qt.rgba(0.08, 0.09, 0.11, 0.96)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.16)
    z: 10

    Text {
      id: tooltipText
      anchors.centerIn: parent
      text: root.entry ? root.entry.name : root.desktopId
      color: "#f5f5f5"
      font.pixelSize: 13
    }
  }

  HoverHandler {
    id: mouse
    cursorShape: Qt.PointingHandCursor
  }

  TapHandler {
    acceptedButtons: Qt.LeftButton
    onTapped: root.activateOrLaunch()
  }

  TapHandler {
    acceptedButtons: Qt.MiddleButton
    onTapped: root.launch()
  }

  TapHandler {
    acceptedButtons: Qt.RightButton
    onTapped: contextMenu.open()
  }

  // Only kept (pinned) apps can be dragged to reorder.
  DragHandler {
    id: dragHandler

    enabled: root.pinned
    target: null
    acceptedButtons: Qt.LeftButton
    xAxis.enabled: !root.vertical
    yAxis.enabled: root.vertical
    onActiveChanged: {
      if (active) {
        root.dock.dragSource = root.itemIndex
        root.dock.dragTarget = root.itemIndex
      } else {
        root.dock.finishDrag()
      }
    }
    onActiveTranslationChanged: {
      if (active)
        root.dock.updateDragTarget((root.vertical ? root.y + root.height / 2 : root.x + root.width / 2)
          + (root.vertical ? activeTranslation.y : activeTranslation.x))
    }
  }

  DockContextMenu {
    id: contextMenu

    anchorItem: root
    position: root.position
    windows: root.sortedWindows()
    pinned: root.pinned
    autoHide: root.dock.autoHide
    isMinimized: toplevel => root.dock.isMinimized(toplevel)
    // Counted once per open menu, and released if this item is removed while its
    // menu is open ("Remove from Dock"); a stuck count kept auto-hide from hiding.
    property bool counted: false
    function setCounted(on) {
      if (on === counted) return
      counted = on
      root.dock.openMenuCount = Math.max(0, root.dock.openMenuCount + (on ? 1 : -1))
    }
    onVisibleChanged: setCounted(visible)
    Component.onDestruction: setCounted(false)
    onWindowChosen: toplevel => root.focusWindow(toplevel)
    onOpenNewWindow: root.launch()
    onQuit: root.quit()
    onTogglePinned: root.pinned ? root.dock.unpinRequested(root.desktopId) : root.dock.pinRequested(root.desktopId)
    onAddApplication: root.dock.openAppPicker()
    onToggleAutoHide: root.dock.autoHideRequested(!root.dock.autoHide)
  }
}
