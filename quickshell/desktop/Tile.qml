import QtQuick
import QtQuick.Layouts

// The 1×1 face shared by every widget: glyph, one big value, one caption.
Item {
    id: tile
    required property QtObject theme
    property string icon: ""
    property string value: ""
    property string label: ""
    property color tint: theme.accent
    signal clicked

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - 16
        spacing: 0
        Text {
            visible: tile.icon.length > 0
            Layout.alignment: Qt.AlignHCenter
            text: tile.icon
            font.family: tile.theme.iconFont
            font.pixelSize: tile.value ? 18 : 34
            color: tile.tint
        }
        Text {
            visible: tile.value.length > 0
            Layout.fillWidth: true
            text: tile.value
            font.family: tile.theme.textFont
            font.pixelSize: tile.value.length > 5 ? 17 : 24
            font.weight: 800
            color: tile.theme.textPrimary
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            fontSizeMode: Text.HorizontalFit
            minimumPixelSize: 12
        }
        Text {
            visible: tile.label.length > 0
            Layout.fillWidth: true
            text: tile.label
            font.family: tile.theme.textFont
            font.pixelSize: 10
            font.weight: 700
            color: tile.theme.textSecondary
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
    property bool clickable: false
    MouseArea {
        anchors.fill: parent
        enabled: tile.clickable
        onClicked: tile.clicked()
        cursorShape: Qt.PointingHandCursor
    }
}
