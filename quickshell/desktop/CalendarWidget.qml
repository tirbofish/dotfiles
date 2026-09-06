import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../lib" as Lib

Item {
    id: root
    required property QtObject theme
    readonly property var calendar: Lib.ProtonCalendar

    Rectangle {
        anchors.fill: parent
        radius: root.theme.radiusOuter
        color: root.theme.bgCard
    }

    function dayLabel(time) {
        var date = new Date(time)
        var today = calendar.now
        var tomorrow = new Date(today)
        tomorrow.setDate(tomorrow.getDate() + 1)
        if (date.toDateString() === today.toDateString()) return "Today"
        if (date.toDateString() === tomorrow.toDateString()) return "Tomorrow"
        return Qt.formatDate(date, "ddd, d MMM")
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.max(0, Math.min(parent.width - 24, 560))
        height: Math.max(0, parent.height - 24)
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Proton Calendar"
                font.family: root.theme.textFont
                font.pixelSize: 14
                font.weight: 700
                color: root.theme.textPrimary
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Button {
                text: "Refresh"
                flat: true
                enabled: !root.calendar.busy && !Lib.WidgetService.editing
                onClicked: root.calendar.refresh()
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.calendar.error || (root.calendar.busy ? "Refreshing events…"
                : "Next 30 days · Updated " + (root.calendar.updatedAt
                    ? Qt.formatTime(root.calendar.updatedAt, "h:mm AP") : "—"))
            textFormat: Text.PlainText
            font.pixelSize: 11
            color: root.calendar.error ? root.theme.accentRed : root.theme.textSecondary
            wrapMode: Text.WordWrap
        }

        ListView {
            id: agenda
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: root.calendar.upcoming
            interactive: !Lib.WidgetService.editing
            ScrollBar.vertical: ScrollBar {}
            delegate: Rectangle {
                required property var modelData
                width: agenda.width - 10
                x: 5
                height: details.implicitHeight + 16
                radius: 8
                color: root.theme.subtleFill
                ColumnLayout {
                    id: details
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                    spacing: 3
                    Text {
                        Layout.fillWidth: true
                        text: root.dayLabel(modelData.start) + " · " + (modelData.allDay
                            ? "All day" + (new Date(modelData.start).toDateString() !== new Date(modelData.end - 1).toDateString()
                                ? " through " + root.dayLabel(modelData.end - 1) : "")
                            : Qt.formatTime(new Date(modelData.start), "h:mm AP") + " – "
                                + (new Date(modelData.start).toDateString() !== new Date(modelData.end).toDateString()
                                    ? root.dayLabel(modelData.end) + " " : "")
                                + Qt.formatTime(new Date(modelData.end), "h:mm AP"))
                        font.pixelSize: 11
                        color: root.theme.accent
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.title
                        textFormat: Text.PlainText
                        font.family: root.theme.textFont
                        font.pixelSize: 13
                        font.weight: 600
                        color: root.theme.textPrimary
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        text: modelData.location
                        textFormat: Text.PlainText
                        font.pixelSize: 11
                        color: root.theme.textSecondary
                        wrapMode: Text.WordWrap
                    }
                }
            }
            Text {
                anchors.fill: parent
                visible: agenda.count === 0
                text: root.calendar.busy ? "Loading your calendars…"
                    : root.calendar.error ? "Events unavailable"
                    : "No upcoming events in the next 30 days"
                font.pixelSize: 13
                color: root.theme.textSecondary
                wrapMode: Text.WordWrap
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Button {
            text: "Open Proton Calendar ↗"
            flat: true
            Layout.alignment: Qt.AlignRight
            enabled: !Lib.WidgetService.editing
            onClicked: Qt.openUrlExternally("https://calendar.proton.me")
        }
    }
}
