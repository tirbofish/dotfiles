import QtQuick
import QtQuick.Layouts
import "../lib" as Lib

Item {
    id: root

    property bool compact: false
    property bool backdrop: false
    property bool centerBars: false
    property color bg: Qt.rgba(0.12, 0.14, 0.15, 0.78)
    property color accent: "#7AA1A6"
    property color border: Qt.rgba(1, 1, 1, 0.10)
    property int requestedBarCount: 0

    readonly property int sourceBarCount: Lib.CavaService.barCount
    readonly property int barCount: requestedBarCount > 0
        ? requestedBarCount : (compact ? Math.min(12, sourceBarCount) : sourceBarCount)
    readonly property int barWidth: compact ? 2 : 3
    readonly property int barGap: compact ? 2 : 2
    property int barMax: compact ? 14 : 18

    implicitHeight: compact ? 28 : 34
    implicitWidth: backdrop ? 0 : (barsRow.implicitWidth + (compact ? 14 : 18))
    Layout.preferredHeight: implicitHeight
    Layout.preferredWidth: backdrop ? 0 : implicitWidth
    Layout.alignment: Qt.AlignVCenter

    function levelAt(index) {
        var position = (index + 0.5) * sourceBarCount / barCount - 0.5
        var lower = Math.max(0, Math.min(sourceBarCount - 1, Math.floor(position)))
        var upper = Math.max(0, Math.min(sourceBarCount - 1, lower + 1))
        var mix = Math.max(0, Math.min(1, position - lower))
        var a = Number(Lib.CavaService.values[lower] || 0)
        var b = Number(Lib.CavaService.values[upper] || 0)
        return (a + (b - a) * mix) / 100
    }

    Rectangle {
        visible: !root.backdrop
        anchors.fill: parent
        radius: compact ? 9 : 17
        color: root.bg
        border.width: 1
        border.color: root.border
    }

    Row {
        id: barsRow
        visible: !root.backdrop
        anchors.centerIn: parent
        spacing: root.barGap
        height: root.barMax

        Repeater {
            model: root.barCount
            Item {
                width: root.barWidth
                height: root.barMax

                Rectangle {
                    width: parent.width
                    height: {
                        var level = root.levelAt(index)
                        return Math.max(2, Math.round(level * parent.height))
                    }
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    radius: width / 2
                    color: root.accent
                    opacity: 0.45 + Math.min(0.55, (height / parent.height) * 0.55)
                }
            }
        }
    }

    Item {
        visible: root.backdrop
        anchors.fill: parent

        Repeater {
            model: root.barCount
            Item {
                property real slot: parent.width / Math.max(1, root.barCount)
                width: Math.max(3, Math.round(slot * 0.62))
                height: parent.height
                x: index * slot + (slot - width) / 2

                Rectangle {
                    width: parent.width
                    height: {
                        var level = root.levelAt(index)
                        return Math.max(4, Math.round(Math.min(1, level * 1.6) * parent.height))
                    }
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: root.centerBars ? undefined : parent.top
                    anchors.verticalCenter: root.centerBars ? parent.verticalCenter : undefined
                    radius: width / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.52) }
                        GradientStop { position: 0.55; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22) }
                        GradientStop { position: 1.0; color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.03) }
                    }
                }
            }
        }
    }
}
