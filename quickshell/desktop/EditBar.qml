import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../lib" as Lib

PanelWindow {
    id: win

    required property QtObject theme
    required property string outputKey
    required property string outputName

    visible: Lib.WidgetService.editing
    color: "transparent"
    exclusiveZone: 0
    aboveWindows: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "desktop-widget-edit"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { top: true; left: true; right: true; bottom: true }
    mask: Region { item: chrome }

    Item {
        id: stage
        anchors.fill: parent

        Column {
            id: chrome
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 56
            width: Math.min(560, win.screen.width - 40)
            spacing: 8

            Rectangle {
                id: bar
                width: parent.width
                height: 40
                radius: 12
                color: win.theme.bgCard
                border.width: 1
                border.color: win.theme.outline

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 8

                    Text {
                        text: "Arrange widgets · " + win.outputName
                        font.family: win.theme.textFont
                        font.pixelSize: 13
                        font.weight: 600
                        color: win.theme.textPrimary
                        Layout.leftMargin: 8
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        width: addTxt.implicitWidth + 20
                        height: 28
                        radius: 8
                        color: win.theme.subtleFill
                        Text {
                            id: addTxt
                            anchors.centerIn: parent
                            text: Lib.WidgetService.pickerOpen ? "Hide picker" : "+ Add"
                            font.pixelSize: 13
                            color: win.theme.textPrimary
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Lib.WidgetService.pickerOpen = !Lib.WidgetService.pickerOpen
                        }
                    }

                    Rectangle {
                        width: clearTxt.implicitWidth + 20
                        height: 28
                        radius: 8
                        color: clearMa.containsMouse ? win.theme.accentRed : win.theme.subtleFill
                        Text {
                            id: clearTxt
                            anchors.centerIn: parent
                            text: "Clear"
                            font.family: win.theme.textFont
                            font.pixelSize: 13
                            font.weight: 600
                            color: clearMa.containsMouse ? win.theme.textOnAccent : win.theme.textPrimary
                        }
                        MouseArea {
                            id: clearMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Lib.WidgetService.clearOutput(win.outputKey)
                        }
                    }

                    Rectangle {
                        width: doneTxt.implicitWidth + 20
                        height: 28
                        radius: 8
                        color: win.theme.accent
                        Text {
                            id: doneTxt
                            anchors.centerIn: parent
                            text: "Done"
                            font.family: win.theme.textFont
                            font.pixelSize: 13
                            font.weight: 600
                            color: win.theme.textOnAccent
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Lib.WidgetService.setEditing(false)
                        }
                    }
                }
            }

            Rectangle {
                id: store
                visible: Lib.WidgetService.pickerOpen
                width: parent.width
                height: grid.implicitHeight + 36
                radius: 12
                color: win.theme.bgCard
                border.width: 1
                border.color: win.theme.outline

                Text {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 10
                    text: "Click to add · Drag widgets to move · Drag the corner to resize"
                    font.family: win.theme.textFont
                    font.pixelSize: 11
                    font.weight: 600
                    color: win.theme.textSecondary
                }

                GridLayout {
                    id: grid
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                    anchors.topMargin: 28
                    columns: 2
                    columnSpacing: 6
                    rowSpacing: 6

                    Repeater {
                        model: Lib.WidgetService.catalog
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            height: 36
                            radius: 8
                            color: cellMa.pressed ? win.theme.subtleFillHover
                                 : cellMa.containsMouse ? win.theme.subtleFillHover : win.theme.subtleFill
                            Text {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.family: win.theme.textFont
                                font.pixelSize: 13
                                color: win.theme.textPrimary
                            }
                            MouseArea {
                                id: cellMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Lib.WidgetService.addWidget(win.outputKey, modelData.type,
                                        win.screen.width, win.screen.height)
                                    Lib.WidgetService.pickerOpen = false
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
