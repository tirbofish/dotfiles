import QtQuick
import Quickshell
import Quickshell.Wayland

// macOS genie effect (from Pomarchy, see LICENSE): a live capture of the
// window drains into its dock icon on minimize, and flows back out on restore.
// Its own overlay layer, no input; the real window leaves underneath.
PanelWindow {
  id: win

  property var toplevel: null
  // Rects in the dock screen's coordinates.
  property rect fromRect: Qt.rect(0, 0, 100, 100)
  property rect toRect: Qt.rect(0, 0, 54, 54)
  property real progress: 0
  property bool running: false
  property int duration: 560
  signal done(bool reversed)

  property bool reversed: false

  visible: running
  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.namespace: "dock-genie"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {}

  // Window -> dock (minimize) or dock -> window (restore, reverse = true).
  function play(toplevel, fromRect, reverse) {
    anim.stop()
    win.toplevel = toplevel
    win.fromRect = fromRect
    win.reversed = reverse === true
    win.progress = win.reversed ? 1 : 0
    win.running = true
    anim.from = win.progress
    anim.to = win.reversed ? 0 : 1
    anim.duration = win.duration
    anim.start()
  }

  function stop() {
    anim.stop()
    win.running = false
  }

  NumberAnimation {
    id: anim
    target: win
    property: "progress"
    easing.type: Easing.InOutSine
    onFinished: {
      win.running = false
      win.done(win.reversed)
    }
  }

  ScreencopyView {
    id: capture
    width: Math.max(1, win.fromRect.width)
    height: Math.max(1, win.fromRect.height)
    captureSource: win.running ? win.toplevel : null
    live: true
  }

  ShaderEffectSource {
    id: texture
    sourceItem: capture
    hideSource: true
    live: true
    smooth: true
  }

  ShaderEffect {
    anchors.fill: parent
    visible: capture.hasContent
    property variant source: texture
    property real progress: win.progress
    property real radius: 12
    property vector4d sourceRect: Qt.vector4d(win.fromRect.x, win.fromRect.y, win.fromRect.width, win.fromRect.height)
    property vector4d targetRect: Qt.vector4d(win.toRect.x, win.toRect.y, win.toRect.width, win.toRect.height)
    mesh: GridMesh { resolution: Qt.size(8, 48) }
    vertexShader: Qt.resolvedUrl("shaders/genie.vert.qsb")
    fragmentShader: Qt.resolvedUrl("shaders/genie.frag.qsb")
  }
}
