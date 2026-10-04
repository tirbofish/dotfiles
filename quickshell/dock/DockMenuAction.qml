import QtQuick

Rectangle {
  id: root

  required property string text
  property bool dimmed: false
  signal triggered()

  implicitWidth: 248
  implicitHeight: visible ? 34 : 0
  radius: 8
  color: hover.hovered && enabled ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
  opacity: enabled ? 1 : 0.42

  Text {
    anchors {
      verticalCenter: parent.verticalCenter
      left: parent.left
      right: parent.right
      leftMargin: 12
      rightMargin: 12
    }
    text: root.text
    elide: Text.ElideMiddle
    color: root.dimmed ? Qt.rgba(0.96, 0.96, 0.96, 0.55) : "#f5f5f5"
    font.pixelSize: 13
  }

  HoverHandler {
    id: hover
    enabled: root.enabled
    cursorShape: Qt.PointingHandCursor
  }

  TapHandler {
    enabled: root.enabled
    acceptedButtons: Qt.LeftButton
    onTapped: root.triggered()
  }
}
