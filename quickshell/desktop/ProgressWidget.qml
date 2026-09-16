import QtQuick
import QtQuick.Layouts
import Quickshell
import "../lib" as Lib

Item {
    id: root
    required property QtObject theme
    readonly property var items: progress.value?.items || []

    function run(args) {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/progress"].concat(args))
    }

    Lib.CommandPoll {
        id: progress
        interval: 1000
        command: [Quickshell.env("HOME") + "/.local/bin/progress", "show"]
        parse: function(output) {
            try { return JSON.parse(String(output || "{}")) }
            catch (e) { return { items: [] } }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: "Progress"
                font.family: root.theme.textFont
                font.pixelSize: 15
                font.weight: 800
                color: root.theme.textPrimary
            }
            Text {
                text: "+"
                font.pixelSize: 20
                font.weight: 700
                color: root.theme.accent
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -7
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.run(["edit", "--new"])
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 7
            model: root.items

            delegate: Item {
                id: row
                required property var modelData
                width: list.width
                height: 42
                readonly property real fraction: modelData.total
                    ? Math.max(0, Math.min(1, Number(modelData.current) / Number(modelData.total))) : 0

                Text {
                    id: label
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.right: value.left
                    anchors.rightMargin: 8
                    text: row.modelData.label || row.modelData.id
                    elide: Text.ElideRight
                    font.family: root.theme.textFont
                    font.pixelSize: 12
                    font.weight: 700
                    color: root.theme.textPrimary
                }
                Text {
                    id: value
                    anchors.top: parent.top
                    anchors.right: edit.left
                    anchors.rightMargin: 10
                    text: row.modelData.current + (row.modelData.total ? "/" + row.modelData.total : "")
                    font.family: root.theme.textFont
                    font.pixelSize: 11
                    color: root.theme.textSecondary
                }
                Text {
                    id: edit
                    anchors.top: parent.top
                    anchors.right: remove.left
                    anchors.rightMargin: 12
                    text: "✎"
                    color: root.theme.accent
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -5
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.run(["edit", "--id", row.modelData.id])
                    }
                }
                Text {
                    id: remove
                    anchors.top: parent.top
                    anchors.right: parent.right
                    text: "×"
                    color: root.theme.accentRed
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -5
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.run(["delete", row.modelData.id])
                    }
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 9
                    radius: 5
                    color: root.theme.subtleFill
                    Rectangle {
                        width: parent.width * row.fraction
                        height: parent.height
                        radius: parent.radius
                        color: row.modelData.status === "failed" ? root.theme.accentRed : root.theme.accent
                        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: list.count === 0
                text: "No progress bars · press +"
                font.family: root.theme.textFont
                font.pixelSize: 12
                color: root.theme.textSecondary
            }
        }
    }
}
