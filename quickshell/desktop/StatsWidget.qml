import QtQuick
import QtQuick.Layouts
import "../lib" as Lib

Item {
    id: root
    required property QtObject theme
    readonly property var info: stats.value || ({})

    function n(key, fallback) {
        var v = info[key]
        if (v === undefined || v === null || v === "") return fallback
        return v
    }

    Lib.CommandPoll {
        id: stats
        running: true
        interval: 2000
        command: ["python3", Qt.resolvedUrl("../lib/sysinfo.py").toString().replace("file://", "")]
        parse: function(o) {
            try { return JSON.parse(String(o || "").trim() || "{}") }
            catch (e) { return root.info }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.max(0, Math.min(parent.width - 24, 480))
        spacing: 8

        Repeater {
            model: [
                { label: "CPU", pct: Number(root.n("cpuPct", 0)), sub: root.n("cpuTemp", 0) + "°" },
                { label: "RAM", pct: Number(root.n("ramPct", 0)), sub: root.n("ramUsed", 0) + "G" },
                { label: "BAT", pct: Number(root.n("batPct", 0)), sub: root.n("batStatus", "") }
            ]
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: modelData.label
                    font.family: root.theme.textFont
                    font.pixelSize: 11
                    font.weight: 700
                    color: root.theme.textSecondary
                    Layout.preferredWidth: 32
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 7
                    radius: 4
                    color: root.theme.subtleFill
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, modelData.pct / 100))
                        height: parent.height
                        radius: 4
                        color: modelData.pct > 85 ? root.theme.accentRed : root.theme.accent
                    }
                }
                Text {
                    text: modelData.pct + "%  " + modelData.sub
                    font.family: root.theme.textFont
                    font.pixelSize: 11
                    color: root.theme.textSecondary
                    Layout.preferredWidth: 78
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        Text {
            text: root.n("uptime", "")
            font.family: root.theme.textFont
            font.pixelSize: 11
            color: root.theme.textSecondary
            opacity: 0.8
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
