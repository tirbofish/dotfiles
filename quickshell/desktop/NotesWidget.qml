import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../lib" as Lib

Item {
    id: root
    required property QtObject theme
    property string text: ""
    signal noteChanged(string text)

    function clearFocus() { area.focus = false }

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        TextArea {
            id: area
            Layout.fillWidth: true
            Layout.fillHeight: true
            horizontalAlignment: TextEdit.AlignLeft
            verticalAlignment: TextEdit.AlignTop
            padding: 12
            wrapMode: TextEdit.Wrap
            readOnly: Lib.WidgetService.editing
            selectByMouse: true
            activeFocusOnPress: true
            color: root.theme.textPrimary
            placeholderText: "Write something…"
            placeholderTextColor: root.theme.textSecondary
            font.family: root.theme.textFont
            font.pixelSize: Math.max(13, Math.min(22, root.height * 0.12))
            background: Rectangle { color: "transparent" }
            Component.onCompleted: text = root.text
            onPressed: area.forceActiveFocus()
            onEditingFinished: root.noteChanged(text)
            onTextChanged: saveDebounce.restart()
        }
    }

    onTextChanged: if (area && !area.activeFocus && area.text !== root.text) area.text = root.text

    Timer {
        id: saveDebounce
        interval: 400
        onTriggered: if (area.text !== root.text) root.noteChanged(area.text)
    }
}
