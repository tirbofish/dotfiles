import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import "../lib" as Lib
import "../theme.js" as Theme

Item {
    id: root

    property bool compact: false
    property bool opensUp: false
    property var barWindow
    property color bg: Qt.rgba(0.12, 0.14, 0.15, 0.78)
    property color textPrimary: "#dde5df"
    property color textSecondary: "#9da9a0"
    property color accent: "#7AA1A6"
    property color hover: Qt.rgba(1, 1, 1, 0.14)
    property color border: Qt.rgba(1, 1, 1, 0.10)
    property color warning: "#e69875"
    property color critical: "#e67e80"
    property string textFont: Theme.textFont
    property string iconFont: Theme.iconFont

    property bool open: false
    readonly property int trayCount: (SystemTray.items?.values ?? []).length
    readonly property int updateCount: Number(updates.value) || 0

    function openTrayMenu(item, menuAnchor) {
        if (!item)
            return
        if (item.hasMenu)
            menuAnchor.open()
        else
            item.secondaryActivate()
    }

    visible: Configuration.barShowTray
    implicitHeight: compact ? 28 : 34
    implicitWidth: compact ? 28 : 34

    scale: press.pressed ? 0.94 : (hoverH.hovered ? 1.06 : 1.0)
    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }

    Lib.CommandPoll {
        id: updates
        interval: updateProc.running ? 999999999 : 1800000
        command: ["bash", "-lc", `
            if [ -e /var/lib/pacman/db.lck ]; then
                cat /tmp/qs_updates_count 2>/dev/null || echo 0
                exit 0
            fi
            n=$(checkupdates 2>/dev/null | wc -l)
            echo "$n" | tee /tmp/qs_updates_count
        `]
        parse: function(o) { return String(o ?? "").trim() }
    }

    Timer {
        interval: 15000
        running: true
        repeat: false
        onTriggered: { if (!updateProc.running) updates.poll() }
    }

    Process {
        id: updateProc
        running: false
        command: ["kitty", "-e", "bash", "-lc", "sudo pacman -Syu"]
        onRunningChanged: { if (!running) updates.poll() }
    }

    Rectangle {
        anchors.fill: parent
        radius: compact ? 9 : 17
        color: root.bg
        border.width: 1
        border.color: hoverH.hovered ? Qt.rgba(1, 1, 1, 0.20) : root.border
        Behavior on border.color { ColorAnimation { duration: 160 } }
    }

    Rectangle {
        anchors.fill: parent
        radius: compact ? 9 : 17
        color: root.hover
        opacity: press.pressed ? 0.22 : (hoverH.hovered ? 0.14 : 0.0)
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    Text {
        anchors.centerIn: parent
        text: "󰍜"
        font.family: root.iconFont
        font.pixelSize: compact ? 13 : 15
        color: root.open ? root.accent : root.textPrimary
    }

    MouseArea {
        id: press
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.open = !root.open
    }
    HoverHandler { id: hoverH }

    PopupWindow {
        id: popup
        visible: root.open
        color: "transparent"
        implicitWidth: Math.max(44, card.implicitWidth)
        implicitHeight: Math.max(44, card.implicitHeight)
        grabFocus: true

        anchor {
            window: root.barWindow
            item: root
            edges: (root.opensUp ? Edges.Top : Edges.Bottom) | Edges.Right
            gravity: (root.opensUp ? Edges.Top : Edges.Bottom) | Edges.Left
            margins.top: root.opensUp ? 0 : 8
            margins.bottom: root.opensUp ? 8 : 0
        }

        onClosed: root.open = false
        onVisibleChanged: if (!visible) root.open = false

        Rectangle {
            id: card
            anchors.fill: parent
            radius: 14
            color: root.bg
            border.width: 1
            border.color: root.border
            implicitWidth: icons.implicitWidth + 16
            implicitHeight: icons.implicitHeight + 16

            Row {
                id: icons
                anchors.centerIn: parent
                spacing: 4

                Item {
                    id: cbIcon
                    visible: Configuration.codexbarTray
                    width: visible ? 32 : 0
                    height: 32

                    scale: cbPress.pressed ? 0.92 : (cbHover.hovered ? 1.08 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: root.hover
                        opacity: cbPress.pressed || cbPopup.visible ? 1.0 : (cbHover.hovered ? 0.8 : 0.0)
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }

                    Canvas {
                        id: cbPie
                        anchors.centerIn: parent
                        width: 18; height: 18
                        property int used: CodexBarService.sessionUsed
                        onUsedChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            var used = cbPie.used
                            var cx = width / 2, cy = height / 2, r = width / 2 - 1
                            ctx.beginPath()
                            ctx.arc(cx, cy, r, 0, Math.PI * 2)
                            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.18)
                            ctx.lineWidth = 2
                            ctx.stroke()
                            if (used >= 0) {
                                var left = Math.max(0, Math.min(1, (100 - used) / 100))
                                ctx.beginPath()
                                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * left)
                                ctx.strokeStyle = used >= 90 ? root.critical : root.accent
                                ctx.lineWidth = 2
                                ctx.lineCap = "round"
                                ctx.stroke()
                            }
                        }
                    }

                    MouseArea {
                        id: cbPress
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.RightButton) {
                                root.open = false
                                Overlays.settingsPage = "codexbar"
                                Overlays.openSettings()
                            } else {
                                cbPopup.visible = !cbPopup.visible
                            }
                        }
                    }
                    HoverHandler { id: cbHover }
                    ToolTip.visible: cbHover.hovered && !cbPopup.visible
                    ToolTip.delay: 350
                    ToolTip.text: CodexBarService.tooltip
                }

                Item {
                    id: pacIcon
                    width: 32
                    height: 32

                    scale: pacPress.pressed ? 0.92 : (pacHover.hovered ? 1.08 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: root.hover
                        opacity: pacPress.pressed ? 1.0 : (pacHover.hovered ? 0.8 : 0.0)
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }

                    Item {
                        anchors.centerIn: parent
                        width: 18
                        height: 18

                        Image {
                            id: pacSrc
                            anchors.fill: parent
                            source: Qt.resolvedUrl("pacman.svg")
                            sourceSize: Qt.size(36, 36)
                            visible: false
                        }

                        ColorOverlay {
                            anchors.fill: parent
                            source: pacSrc
                            color: (updateProc.running || root.updateCount > 0) ? root.accent : root.textSecondary
                            cached: true
                            antialiasing: true
                        }
                    }

                    Text {
                        visible: root.updateCount > 0 && !updateProc.running
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 1
                        text: root.updateCount > 99 ? "99" : String(root.updateCount)
                        font.family: root.textFont
                        font.pixelSize: 8
                        font.weight: 800
                        color: root.accent
                    }

                    MouseArea {
                        id: pacPress
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            updateProc.running = true
                            root.open = false
                        }
                    }
                    HoverHandler { id: pacHover }
                    ToolTip.visible: pacHover.hovered
                    ToolTip.delay: 350
                    ToolTip.text: updateProc.running
                        ? "Updating…"
                        : (root.updateCount > 0
                            ? (root.updateCount + " update" + (root.updateCount === 1 ? "" : "s"))
                            : "System up to date")
                }

                Repeater {
                    model: SystemTray.items

                    Item {
                        id: trayIcon
                        required property var modelData
                        width: 32
                        height: 32

                        scale: trayPress.pressed ? 0.92 : (trayHover.hovered ? 1.08 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: root.hover
                            opacity: trayPress.pressed ? 1.0 : (trayHover.hovered ? 0.8 : 0.0)
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }

                        IconImage {
                            anchors.centerIn: parent
                            implicitSize: 20
                            width: 20
                            height: 20
                            asynchronous: true
                            mipmap: true
                            source: trayIcon.modelData.icon
                        }

                        QsMenuAnchor {
                            id: trayMenu
                            menu: trayIcon.modelData.menu
                            anchor.window: popup
                            anchor.item: trayIcon
                            anchor.edges: root.opensUp ? Edges.Top : Edges.Bottom
                            anchor.gravity: root.opensUp ? Edges.Top : Edges.Bottom
                        }

                        MouseArea {
                            id: trayPress
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (mouse) => {
                                var item = trayIcon.modelData
                                if (!item)
                                    return
                                if (mouse.button === Qt.RightButton || item.onlyMenu) {
                                    root.openTrayMenu(item, trayMenu)
                                    return
                                }
                                item.activate()
                                root.open = false
                            }
                        }
                        HoverHandler { id: trayHover }
                    }
                }
            }
        }
    }

    PopupWindow {
        id: cbPopup
        visible: false
        color: "transparent"
        implicitWidth: 280
        implicitHeight: Math.max(80, cbCard.implicitHeight)
        grabFocus: true
        anchor {
            window: root.barWindow
            item: root
            edges: (root.opensUp ? Edges.Top : Edges.Bottom) | Edges.Right
            gravity: (root.opensUp ? Edges.Top : Edges.Bottom) | Edges.Left
            margins.top: root.opensUp ? 0 : 8
            margins.bottom: root.opensUp ? 8 : 0
        }
        onClosed: visible = false

        Rectangle {
            id: cbCard
            anchors.fill: parent
            radius: 14
            color: root.bg
            border.width: 1
            border.color: root.border
            implicitHeight: cbCol.implicitHeight + 20

            ColumnLayout {
                id: cbCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "CodexBar"
                        font.family: root.textFont
                        font.pixelSize: 13
                        font.weight: 700
                        color: root.accent
                        Layout.fillWidth: true
                    }
                    Text {
                        text: CodexBarService.loading ? "…" : "Refresh"
                        font.family: root.textFont
                        font.pixelSize: 11
                        color: root.textSecondary
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: CodexBarService.refresh()
                        }
                    }
                }

                CodexBarPanel {
                    theme: cbTheme
                    Layout.fillWidth: true
                }
            }
        }
    }

    QtObject {
        id: cbTheme
        property color accent: root.accent
        property color accentRed: root.critical
        property color accentSlider2: root.warning
        property color textPrimary: root.textPrimary
        property color textSecondary: root.textSecondary
        property color subtleFill: Qt.rgba(1, 1, 1, 0.08)
        property string textFont: root.textFont
    }
}
