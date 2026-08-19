import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    property QtObject theme: null
    spacing: 8
    implicitHeight: content.implicitHeight

    function label(device) {
        return String(device.description || device.name || "Unknown device")
    }

    function selected(device, input) {
        if (!device) return false
        if (device.kind === "route") return Boolean(device.active)
        return device.nodeId === (input ? AudioService.defaultInputId : AudioService.defaultOutputId)
    }

    component DeviceRow: Rectangle {
        id: row
        required property var modelData
        readonly property var device: modelData
        property bool selected: false
        signal chosen()
        Layout.fillWidth: true
        Layout.preferredHeight: 34
        radius: 9
        color: selected
            ? Qt.rgba(root.theme.accent.r, root.theme.accent.g, root.theme.accent.b, 0.3)
            : (mouse.containsMouse ? root.theme.bgItemHover : root.theme.bgItem)
        border.width: 1
        border.color: selected ? root.theme.accent : root.theme.outline

        Text {
            anchors.fill: parent
            anchors.margins: 9
            verticalAlignment: Text.AlignVCenter
            text: root.label(row.device)
            elide: Text.ElideRight
            font.family: root.theme.textFont
            font.pixelSize: 12
            font.weight: row.selected ? Font.DemiBold : Font.Normal
            color: root.theme.textPrimary
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.chosen()
        }
    }

    ColumnLayout {
        id: content
        Layout.fillWidth: true
        spacing: 5

        Text {
            text: "Outputs"
            font.family: root.theme.textFont
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: root.theme.textSecondary
        }
        Repeater {
            model: AudioService.outputs
            DeviceRow {
                id: outputRow
                selected: root.selected(outputRow.device, false)
                onChosen: AudioService.setOutput(outputRow.device)
            }
        }
        Text {
            visible: AudioService.outputs.length === 0
            text: "No outputs found"
            font.family: root.theme.textFont
            font.pixelSize: 11
            color: root.theme.textSecondary
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: 3
            Layout.bottomMargin: 3
            color: root.theme.outline
        }

        Text {
            text: "Inputs"
            font.family: root.theme.textFont
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: root.theme.textSecondary
        }
        Repeater {
            model: AudioService.inputs
            DeviceRow {
                id: inputRow
                selected: root.selected(inputRow.device, true)
                onChosen: AudioService.setInput(inputRow.device)
            }
        }
        Text {
            visible: AudioService.inputs.length === 0
            text: "No inputs found"
            font.family: root.theme.textFont
            font.pixelSize: 11
            color: root.theme.textSecondary
        }

        Text {
            visible: AudioService.status !== ""
            Layout.fillWidth: true
            text: AudioService.status
            wrapMode: Text.WordWrap
            font.family: root.theme.textFont
            font.pixelSize: 11
            color: AudioService.statusError ? (root.theme.accentRed || root.theme.textSecondary) : root.theme.textSecondary
        }
    }

    onVisibleChanged: if (visible) AudioService.refresh()
}
