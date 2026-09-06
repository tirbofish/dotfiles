import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root
    required property QtObject theme
    spacing: 8

    function barColor(used) {
        if (used >= 90) return root.theme.accentRed
        if (used >= 75) return root.theme.accentSlider2 || root.theme.accent
        return root.theme.accent
    }

    Repeater {
        model: CodexBarService.rows
        delegate: ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: modelData.label
                font.family: root.theme.textFont
                font.pixelSize: 12
                font.weight: 700
                color: root.theme.textPrimary
            }
            Repeater {
                model: [
                    { name: "5 hour", used: modelData.sessionUsed, reset: modelData.sessionReset },
                    { name: "Weekly", used: modelData.weeklyUsed, reset: modelData.weeklyReset }
                ]
                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 2
                    visible: modelData.used >= 0
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: modelData.name
                            font.family: root.theme.textFont
                            font.pixelSize: 11
                            color: root.theme.textSecondary
                            Layout.fillWidth: true
                        }
                        Text {
                            text: (100 - modelData.used) + "% left"
                            font.family: root.theme.textFont
                            font.pixelSize: 11
                            font.weight: 600
                            color: root.barColor(modelData.used)
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        height: 6
                        radius: 3
                        color: root.theme.subtleFill
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, modelData.used / 100))
                            height: parent.height
                            radius: 3
                            color: root.barColor(modelData.used)
                        }
                    }
                    Text {
                        visible: modelData.reset !== ""
                        text: "Resets " + modelData.reset
                        font.family: root.theme.textFont
                        font.pixelSize: 10
                        color: root.theme.textSecondary
                        opacity: 0.8
                    }
                }
            }
        }
    }

    Text {
        visible: CodexBarService.rows.length === 0
        text: CodexBarService.loading ? "Loading CodexBar…" : (CodexBarService.error || "No CodexBar data")
        font.family: root.theme.textFont
        font.pixelSize: 12
        color: root.theme.textSecondary
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
}
