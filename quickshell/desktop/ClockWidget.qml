import QtQuick
import QtQuick.Layouts

Item {
    id: root
    required property QtObject theme
    property bool hour24: true
    property bool showDate: true
    property date now: new Date()

    WidgetLook { id: look; host: root }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Tile {
        anchors.fill: parent
        visible: look.small
        theme: root.theme
        value: Qt.formatTime(root.now, root.hour24 ? "HH:mm" : "h:mm")
        label: Qt.formatDate(root.now, "ddd d")
    }

    GridLayout {
        visible: !look.small
        objectName: "centeredContent"
        anchors.centerIn: parent
        width: Math.max(0, parent.width - 24)
        columns: look.wide ? 2 : 1
        columnSpacing: 16
        rowSpacing: 0

        Text {
            text: Qt.formatDate(root.now, "dddd").toUpperCase()
            font.family: root.theme.textFont
            font.pixelSize: 11
            font.weight: 700
            font.letterSpacing: 1.4
            color: root.theme.accent
            opacity: 0.9
            Layout.row: 0
            Layout.column: look.wide ? 1 : 0
            Layout.fillWidth: true
            horizontalAlignment: look.wide ? Text.AlignLeft : Text.AlignHCenter
        }

        Text {
            // 1×N column: stack hours over minutes so the digits can stay big.
            text: Qt.formatTime(root.now, look.column ? (root.hour24 ? "HH\nmm" : "h\nmm") : (root.hour24 ? "HH:mm" : "h:mm AP"))
            lineHeight: 0.85
            font.family: "Inter"
            font.pixelSize: look.column ? Math.min((root.width - 24) * 0.62, (root.height - 60) * 0.4, 96)
                : Math.max(24, Math.min((root.height - 48) * 0.7, (root.width - 32) * (look.wide ? 0.3 : 0.28), 96))
            font.weight: 500
            color: root.theme.textPrimary
            Layout.row: look.wide ? 0 : 1
            Layout.column: 0
            Layout.rowSpan: look.wide ? 2 : 1
            Layout.fillWidth: true
            Layout.fillHeight: look.wide
            horizontalAlignment: look.wide ? Text.AlignRight : Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            visible: root.showDate
            text: Qt.formatDate(root.now, "MMM d")
            font.family: root.theme.textFont
            font.pixelSize: 14
            font.weight: 600
            color: root.theme.textSecondary
            Layout.row: look.wide ? 1 : 2
            Layout.column: look.wide ? 1 : 0
            Layout.fillWidth: true
            horizontalAlignment: look.wide ? Text.AlignLeft : Text.AlignHCenter
        }
    }
}
