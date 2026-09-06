import QtQuick
import QtQuick.Layouts
import "../../lib" as Lib

Rectangle {
    id: root
    property int nId: 0
    property string app: "SYSTEM"
    property string summary: "Notification"
    property string body: ""
    property QtObject theme: null
    readonly property bool hasTheme: theme !== null
    readonly property bool isDarkMode: (!hasTheme || (theme.isDarkMode === undefined)) ? true : theme.isDarkMode

    readonly property color cBg:      hasTheme ? theme.bgItem : (isDarkMode ? "#2d353b" : Qt.rgba(0,0,0,0.05))
    readonly property color cBgHover: hasTheme ? theme.bgItemHover : (isDarkMode ? "#374145" : Qt.rgba(0,0,0,0.08))
    readonly property color cSheen:   hasTheme ? theme.subtleFillHover : Qt.rgba(1, 1, 1, 0.06)
    readonly property color cRipple:  hasTheme ? theme.hoverSpotlight : Qt.rgba(1,1,1,0.12)
    readonly property color cIconBg:  hasTheme ? theme.subtleFill : Qt.rgba(1,1,1,0.05)
    readonly property color cAccent:  hasTheme ? theme.accent : "#7aa1a6"
    readonly property color cFgMuted: hasTheme ? theme.textSecondary : "#9da9a0"
    readonly property color cFgMain:  hasTheme ? theme.textPrimary : "#dde5df"

    signal clicked()

    radius: 22
    color: hovered ? cBgHover : (hasTheme ? theme.bgCard : cBg)
    antialiasing: true
    border.width: 1
    border.color: hasTheme ? theme.border : "transparent"

    property bool hovered: false

    // subtle lift on hover
    scale: pressed ? 0.985 : (hovered ? 1.01 : 1.0)
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 140 } }

    // tiny highlight
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: cSheen
        opacity: hovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
    }

    // ripple
    Lib.Ripple {
        id: ripple
        rippleColor: cRipple
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Rectangle {
            width: 30
            height: 30
            radius: 999
            color: cIconBg
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: "󰋽"
                font.family: root.theme ? root.theme.iconFont : "JetBrainsMono Nerd Font"
                font.pixelSize: 15
                font.weight: 800
                color: cAccent
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: String(root.app).toUpperCase().replace(/\n/g, ' ')
                font.family: root.theme ? root.theme.textFont : "Manrope"
                font.pixelSize: 9
                font.weight: 700
                color: cFgMuted
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.summary.replace(/\n/g, ' ')
                font.family: root.theme ? root.theme.textFont : "Manrope"
                font.pixelSize: 12
                font.weight: 700
                color: cFgMain
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.body.replace(/\n/g, ' ')
                visible: root.body !== ""
                font.family: root.theme ? root.theme.textFont : "Manrope"
                font.pixelSize: 11
                font.weight: 300
                color: cFgMuted
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    property bool pressed: false

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered: root.hovered = true
        onExited: root.hovered = false

        onPressed: { root.pressed = true; ripple.burst(mouse.x, mouse.y) }
        onReleased: root.pressed = false

        onClicked: root.clicked()
    }
}
