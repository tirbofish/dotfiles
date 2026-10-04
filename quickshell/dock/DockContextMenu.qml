import QtQuick
import Quickshell

// Right-click menu: every window of the app (minimized ones marked), then the
// app actions, like the macOS dock menu.
PopupWindow {
  id: root

  required property Item anchorItem
  required property string position
  required property var windows
  required property bool pinned
  required property bool autoHide
  required property var isMinimized
  signal windowChosen(var toplevel)
  signal openNewWindow()
  signal quit()
  signal togglePinned()
  signal addApplication()
  signal toggleAutoHide()

  function open() {
    visible = true
  }

  function choose(action) {
    visible = false
    action()
  }

  implicitWidth: 260
  implicitHeight: menuColumn.implicitHeight + 12
  color: "transparent"
  grabFocus: true

  anchor {
    window: root.anchorItem ? root.anchorItem.QsWindow.window : null
    adjustment: PopupAdjustment.Slide
    edges: Edges.Top | Edges.Left
    gravity: Edges.Bottom | Edges.Right
    rect.width: 1
    rect.height: 1

    onAnchoring: {
      if (!root.anchorItem || !root.anchor.window) return

      var x = root.anchorItem.width / 2 - root.implicitWidth / 2
      var y = root.anchorItem.height + 8
      if (root.position === "bottom")
        y = -root.implicitHeight - 8
      else if (root.position === "left") {
        x = root.anchorItem.width + 8
        y = root.anchorItem.height / 2 - root.implicitHeight / 2
      } else if (root.position === "right") {
        x = -root.implicitWidth - 8
        y = root.anchorItem.height / 2 - root.implicitHeight / 2
      }

      var point = root.anchor.window.contentItem.mapFromItem(root.anchorItem, x, y)
      if (root.position === "top" || root.position === "bottom")
        point.x = Math.max(8, Math.min(point.x, root.anchor.window.width - root.implicitWidth - 8))
      else
        point.y = Math.max(8, Math.min(point.y, root.anchor.window.height - root.implicitHeight - 8))

      root.anchor.rect.x = Math.round(point.x)
      root.anchor.rect.y = Math.round(point.y)
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: 12
    color: Qt.rgba(0.08, 0.09, 0.11, 0.97)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.18)

    Column {
      id: menuColumn
      anchors.centerIn: parent

      Repeater {
        model: root.windows

        DockMenuAction {
          required property var modelData
          readonly property bool minimized: root.isMinimized(modelData)
          readonly property string where: minimized ? "minimized"
            : modelData.workspace ? (modelData.workspace.id > 0 ? "ws " + modelData.workspace.id : modelData.workspace.name) : ""
          text: (modelData.title || "Untitled") + (where ? "  ·  " + where : "")
          dimmed: minimized
          onTriggered: root.choose(() => root.windowChosen(modelData))
        }
      }

      MenuSeparator { visible: root.windows.length > 0 }

      DockMenuAction {
        text: "New Window"
        onTriggered: root.choose(root.openNewWindow)
      }

      DockMenuAction {
        text: root.pinned ? "Remove from Dock" : "Keep in Dock"
        onTriggered: root.choose(root.togglePinned)
      }

      DockMenuAction {
        text: "Add Application…"
        onTriggered: root.choose(root.addApplication)
      }

      DockMenuAction {
        text: root.autoHide ? "Turn Hiding Off" : "Turn Hiding On"
        onTriggered: root.choose(root.toggleAutoHide)
      }

      MenuSeparator { visible: root.windows.length > 0 }

      DockMenuAction {
        visible: root.windows.length > 0
        text: root.windows.length > 1 ? "Quit (" + root.windows.length + " windows)" : "Quit"
        onTriggered: root.choose(root.quit)
      }
    }
  }

  component MenuSeparator: Item {
    width: root.implicitWidth - 12
    height: visible ? 10 : 0

    Rectangle {
      anchors.centerIn: parent
      width: parent.width - 24
      height: 1
      color: Qt.rgba(1, 1, 1, 0.16)
    }
  }
}
