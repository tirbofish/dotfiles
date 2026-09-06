import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property QtObject theme
    property date now: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    ColumnLayout {
        objectName: "centeredContent"
        anchors.centerIn: parent
        width: Math.max(0, parent.width - 24)
        spacing: 0

        Text {
            text: Qt.formatDate(root.now, "dddd").toUpperCase()
            font.family: root.theme.textFont
            font.pixelSize: 11
            font.weight: 700
            font.letterSpacing: 1.4
            color: root.theme.accent
            opacity: 0.9
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            text: Qt.formatTime(root.now, "hh:mm")
            font.family: "Inter"
            font.pixelSize: Math.max(24, Math.min((root.height - 48) * 0.7, (root.width - 24) * 0.3, 96))
            font.weight: 500
            color: root.theme.textPrimary
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            text: Qt.formatDate(root.now, "MMM d")
            font.family: root.theme.textFont
            font.pixelSize: 14
            font.weight: 600
            color: root.theme.textSecondary
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
