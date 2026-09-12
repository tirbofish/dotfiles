import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../lib" as Lib

Item {
    id: root
    required property QtObject theme
    property var items: []
    signal todosChanged(var items)

    function clearFocus() { addField.focus = false }

    function persist(next) {
        root.items = next
        root.todosChanged(next)
    }

    function addItem() {
        var t = addField.text.trim()
        if (!t || Lib.WidgetService.editing) return
        var next = (root.items || []).slice()
        next.push({
            id: "t_" + Date.now().toString(36) + "_" + Math.floor(Math.random() * 10000).toString(36),
            text: t,
            done: false
        })
        addField.text = ""
        root.persist(next)
    }

    function toggleAt(index) {
        if (Lib.WidgetService.editing) return
        var next = (root.items || []).slice()
        if (!next[index]) return
        var row = Object.assign({}, next[index])
        row.done = !row.done
        next[index] = row
        root.persist(next)
    }

    function removeAt(index) {
        if (Lib.WidgetService.editing) return
        var next = (root.items || []).slice()
        next.splice(index, 1)
        root.persist(next)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Text {
            text: "Todo"
            font.family: root.theme.textFont
            font.pixelSize: 14
            font.weight: 700
            color: root.theme.textPrimary
            Layout.fillWidth: true
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            interactive: !Lib.WidgetService.editing
            model: root.items || []
            ScrollBar.vertical: ScrollBar {}

            delegate: Rectangle {
                required property var modelData
                required property int index
                width: list.width
                height: Math.max(28, row.implicitHeight + 10)
                radius: 8
                color: root.theme.subtleFill

                RowLayout {
                    id: row
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 6
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        radius: 4
                        color: modelData.done ? root.theme.accent : "transparent"
                        border.width: 1
                        border.color: modelData.done ? root.theme.accent : root.theme.outline
                        Text {
                            anchors.centerIn: parent
                            visible: modelData.done
                            text: "✓"
                            font.pixelSize: 10
                            font.weight: 700
                            color: root.theme.textOnAccent
                        }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            enabled: !Lib.WidgetService.editing
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleAt(index)
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.text || ""
                        font.family: root.theme.textFont
                        font.pixelSize: 13
                        font.strikeout: !!modelData.done
                        color: modelData.done ? root.theme.textSecondary : root.theme.textPrimary
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        maximumLineCount: 3
                    }

                    Text {
                        text: "✕"
                        font.pixelSize: 11
                        color: root.theme.textSecondary
                        opacity: delMa.containsMouse ? 1 : 0.55
                        MouseArea {
                            id: delMa
                            anchors.fill: parent
                            anchors.margins: -6
                            enabled: !Lib.WidgetService.editing
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.removeAt(index)
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: "Nothing queued"
                font.family: root.theme.textFont
                font.pixelSize: 12
                color: root.theme.textSecondary
            }
        }

        TextField {
            id: addField
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            placeholderText: "Add a task…"
            placeholderTextColor: root.theme.textSecondary
            color: root.theme.textPrimary
            font.family: root.theme.textFont
            font.pixelSize: 13
            readOnly: Lib.WidgetService.editing
            selectByMouse: true
            background: Rectangle {
                radius: 8
                color: root.theme.subtleFill
                border.width: addField.activeFocus ? 1 : 0
                border.color: root.theme.accent
            }
            onAccepted: root.addItem()
        }
    }
}
