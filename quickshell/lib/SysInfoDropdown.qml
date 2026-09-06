import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
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
    readonly property var info: stats.value || ({})

    implicitHeight: compact ? 28 : 34
    implicitWidth: compact ? 28 : 34

    scale: press.pressed ? 0.94 : (hoverH.hovered ? 1.06 : 1.0)
    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.08 } }

    function n(key, fallback) {
        var v = info[key]
        if (v === undefined || v === null || v === "")
            return fallback
        return v
    }

    function barColor(pct) {
        if (pct > 85) return root.critical
        if (pct > 70) return root.warning
        return root.accent
    }

    Lib.CommandPoll {
        id: stats
        running: root.open
        interval: 1500
        command: ["python3", Qt.resolvedUrl("sysinfo.py").toString().replace("file://", "")]
        parse: function(o) {
            try {
                return JSON.parse(String(o || "").trim() || "{}")
            } catch (e) {
                return root.info
            }
        }
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
        text: ""
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
    ToolTip.visible: hoverH.hovered && !root.open
    ToolTip.delay: 350
    ToolTip.text: "System info"

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
            implicitWidth: 292
            implicitHeight: body.implicitHeight + 22

            ColumnLayout {
                id: body
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: ""
                        font.family: root.iconFont
                        font.pixelSize: 16
                        color: root.accent
                    }
                    ColumnLayout {
                        spacing: 0
                        Layout.fillWidth: true
                        Text {
                            text: String(root.n("cpuModel", "CPU"))
                            color: root.textPrimary
                            font.family: root.textFont
                            font.pixelSize: 13
                            font.weight: 800
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: String(root.n("host", "")) + " · " + String(root.n("cpuGov", ""))
                            color: root.textSecondary
                            font.family: root.textFont
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }

                Metric {
                    label: "CPU"
                    valueText: root.n("cpuPct", 0) + "%  " + root.n("cpuFreq", 0) + " GHz"
                    fraction: Number(root.n("cpuPct", 0)) / 100
                    tint: root.barColor(Number(root.n("cpuPct", 0)))
                }

                Metric {
                    label: "RAM"
                    valueText: root.n("ramUsed", 0) + " / " + root.n("ramTotal", 0) + " GiB"
                    fraction: Number(root.n("ramPct", 0)) / 100
                    tint: root.barColor(Number(root.n("ramPct", 0)))
                }

                Metric {
                    visible: Number(root.n("swapTotal", 0)) > 0
                    label: "Swap"
                    valueText: root.n("swapUsed", 0) + " / " + root.n("swapTotal", 0) + " GiB"
                    fraction: Number(root.n("swapPct", 0)) / 100
                    tint: root.barColor(Number(root.n("swapPct", 0)))
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    StatChip {
                        Layout.fillWidth: true
                        icon: ""
                        label: "CPU"
                        value: root.n("cpuTemp", "—") + "°"
                        tint: Number(root.n("cpuTemp", 0)) >= 85 ? root.critical
                            : Number(root.n("cpuTemp", 0)) >= 70 ? root.warning : root.accent
                    }
                    StatChip {
                        Layout.fillWidth: true
                        icon: "󰋊"
                        label: "NVMe"
                        value: root.n("nvmeTemp", "—") + "°"
                        tint: Number(root.n("nvmeTemp", 0)) >= 70 ? root.warning : root.accent
                    }
                    StatChip {
                        Layout.fillWidth: true
                        icon: "󰓅"
                        label: "Power"
                        value: root.n("powerW", 0) > 0 ? (root.n("powerW", 0) + " W") : "—"
                        tint: Number(root.n("powerW", 0)) >= 25 ? root.warning : root.accent
                    }
                }

                Metric {
                    label: "Battery"
                    valueText: {
                        var st = String(root.n("batStatus", ""))
                        var pct = root.n("batPct", 0) + "%"
                        if (st) pct += " · " + st
                        if (Number(root.n("cycles", 0)) > 0)
                            pct += " · " + root.n("cycles", 0) + " cycles"
                        return pct
                    }
                    fraction: Number(root.n("batPct", 0)) / 100
                    tint: Number(root.n("batPct", 0)) <= 15 ? root.critical
                        : Number(root.n("batPct", 0)) <= 30 ? root.warning : root.accent
                }

                Metric {
                    label: "Disk"
                    valueText: root.n("diskUsed", 0) + " / " + root.n("diskTotal", 0) + " GiB"
                    fraction: Number(root.n("diskPct", 0)) / 100
                    tint: root.barColor(Number(root.n("diskPct", 0)))
                }

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Load  " + root.n("load1", "0") + "  " + root.n("load5", "0") + "  " + root.n("load15", "0")
                        color: root.textSecondary
                        font.family: root.textFont
                        font.pixelSize: 11
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "up " + root.n("uptime", "—")
                        color: root.textSecondary
                        font.family: root.textFont
                        font.pixelSize: 11
                    }
                }
            }
        }
    }

    component Metric: ColumnLayout {
        property string label: ""
        property string valueText: ""
        property real fraction: 0
        property color tint: root.accent
        spacing: 4
        Layout.fillWidth: true

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: label
                color: root.textSecondary
                font.family: root.textFont
                font.pixelSize: 10
                font.weight: 700
            }
            Item { Layout.fillWidth: true }
            Text {
                text: valueText
                color: root.textPrimary
                font.family: root.textFont
                font.pixelSize: 11
                font.weight: 700
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 6
            radius: 3
            color: Qt.rgba(root.textPrimary.r, root.textPrimary.g, root.textPrimary.b, 0.10)
            Rectangle {
                height: parent.height
                radius: 3
                color: tint
                width: Math.max(4, parent.width * Math.max(0, Math.min(1, fraction)))
                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            }
        }
    }

    component StatChip: Rectangle {
        property string icon: ""
        property string label: ""
        property string value: ""
        property color tint: root.accent
        radius: 9
        color: Qt.rgba(tint.r, tint.g, tint.b, 0.12)
        implicitHeight: chipCol.implicitHeight + 12
        ColumnLayout {
            id: chipCol
            anchors.centerIn: parent
            spacing: 1
            Text {
                text: icon + " " + label
                color: root.textSecondary
                font.family: root.iconFont
                font.pixelSize: 10
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: value
                color: tint
                font.family: root.textFont
                font.pixelSize: 13
                font.weight: 800
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
