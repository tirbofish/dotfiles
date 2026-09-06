import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../lib" as Lib

FloatingWindow {
    id: win
    title: "Settings"
    implicitWidth: 960
    implicitHeight: 680
    minimumSize: Qt.size(760, 520)
    color: theme.bgMain
    visible: Lib.Overlays.settingsOpen

    onClosed: Lib.Overlays.settingsOpen = false
    onVisibleChanged: {
        if (visible && Lib.Overlays.settingsPage !== "") {
            page = Lib.Overlays.settingsPage
            Lib.Overlays.settingsPage = ""
        }
        if (!visible) Lib.Overlays.settingsOpen = false
    }

    Lib.ThemeEngine { id: theme }

    property string page: "appearance"
    readonly property var pages: [
        { id: "appearance", label: "Appearance" },
        { id: "themes",     label: "Themes" },
        { id: "wallpaper",  label: "Wallpaper" },
        { id: "displays",   label: "Displays" },
        { id: "sound",      label: "Sound" },
        { id: "mouse",      label: "Mouse" },
        { id: "touchpad",   label: "Touchpad" },
        { id: "layout",     label: "Layout" },
        { id: "borders",    label: "Borders" },
        { id: "widgets",    label: "Widgets" },
        { id: "codexbar",   label: "CodexBar" },
        { id: "power",      label: "Power" },
        { id: "weather",    label: "Weather" },
        { id: "profile",    label: "Profile" }
    ]

    Shortcut { sequence: "Esc"; enabled: win.visible; onActivated: Lib.Overlays.settingsOpen = false }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            color: theme.bgCard
            MouseArea {
                anchors.fill: parent
                onPressed: win.startSystemMove()
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 10
                spacing: 8
                Text {
                    text: "Settings"
                    font.family: theme.textFont
                    font.pixelSize: 15
                    font.weight: 700
                    color: theme.textPrimary
                    Layout.fillWidth: true
                }
                Rectangle {
                    width: 28; height: 28; radius: 8
                    color: closeHov.hovered ? theme.accentRed : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 12
                        color: closeHov.hovered ? theme.textOnAccent : theme.textSecondary
                    }
                    HoverHandler { id: closeHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: Lib.Overlays.settingsOpen = false }
                }
            }
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 1
                color: theme.outline
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Rectangle {
                Layout.preferredWidth: 220
                Layout.fillHeight: true
                color: theme.bgCard
                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 2
                    Repeater {
                        model: win.pages
                        delegate: Rectangle {
                            required property var modelData
                            width: parent.width
                            height: 36
                            radius: 8
                            color: win.page === modelData.id
                                ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.28)
                                : (rowHov.hovered ? theme.subtleFillHover : "transparent")
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                Text {
                                    text: modelData.label
                                    font.family: theme.textFont
                                    font.pixelSize: 13
                                    font.weight: win.page === modelData.id ? 600 : 400
                                    color: win.page === modelData.id ? theme.accent : theme.textPrimary
                                    Layout.fillWidth: true
                                }
                            }
                            HoverHandler { id: rowHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: win.page = modelData.id }
                        }
                    }
                }
                Rectangle {
                    anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.right: parent.right
                    width: 1
                    color: theme.outline
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: theme.bgMain

                Text {
                    id: pageTitle
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 16
                    anchors.leftMargin: 18
                    anchors.rightMargin: 18
                    text: {
                        for (var i = 0; i < win.pages.length; i++)
                            if (win.pages[i].id === win.page) return win.pages[i].label
                        return "Settings"
                    }
                    font.family: theme.textFont
                    font.pixelSize: 20
                    font.weight: 700
                    color: theme.textPrimary
                    visible: win.page !== "wallpaper"
                }

                SettingsPanel {
                    anchors.top: pageTitle.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.topMargin: 8
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    anchors.bottomMargin: 14
                    visible: win.page !== "wallpaper"
                    theme: theme
                    category: win.page === "wallpaper" ? "appearance" : win.page
                    profileImagePath: Lib.Configuration.profileImageOverride
                    onWallpaperRequested: win.page = "wallpaper"
                }

                WallpaperPanel {
                    anchors.fill: parent
                    anchors.margins: 14
                    visible: win.page === "wallpaper"
                    theme: theme
                    live: visible
                    onCloseRequested: win.page = "appearance"
                }
            }
        }
    }
}
