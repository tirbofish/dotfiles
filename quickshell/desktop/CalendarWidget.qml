import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../lib" as Lib

Item {
    id: root
    required property QtObject theme
    readonly property var calendar: Lib.ProtonCalendar
    readonly property var next: calendar.upcoming.length ? calendar.upcoming[0] : null
    readonly property int todayCount: calendar.upcoming.filter(e => dayLabel(e.start) === "Today").length

    WidgetLook { id: look; host: root }

    // 1×1: the date, like a calendar app icon.
    Tile {
        anchors.fill: parent
        visible: look.small
        theme: root.theme
        icon: Qt.formatDate(root.calendar.now, "ddd").toUpperCase()
        value: Qt.formatDate(root.calendar.now, "d")
        label: root.todayCount ? root.todayCount + " today" : "free"
        clickable: true
        onClicked: Qt.openUrlExternally("https://calendar.proton.me")
    }

    // N×1: just what's next.
    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        visible: look.row
        spacing: 12
        ColumnLayout {
            spacing: -4
            Text {
                text: Qt.formatDate(root.calendar.now, "ddd").toUpperCase()
                font.family: root.theme.textFont
                font.pixelSize: 10
                font.weight: 800
                color: root.theme.accentRed
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: Qt.formatDate(root.calendar.now, "d")
                font.family: root.theme.textFont
                font.pixelSize: 30
                font.weight: 800
                color: root.theme.textPrimary
                Layout.alignment: Qt.AlignHCenter
            }
        }
        Rectangle {
            Layout.preferredWidth: 3
            Layout.fillHeight: true
            Layout.margins: 6
            radius: 2
            color: root.next ? (root.calendar.colors[root.next.calendarId] || root.theme.accent) : root.theme.outline
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                Layout.fillWidth: true
                text: root.next ? root.next.title : (root.calendar.error ? "Calendar unavailable" : "Nothing coming up")
                font.family: root.theme.textFont
                font.pixelSize: 13
                font.weight: 700
                color: root.theme.textPrimary
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: !!root.next
                text: root.next ? root.dayLabel(root.next.start) + " · " + root.timeLabel(root.next) : ""
                font.family: root.theme.textFont
                font.pixelSize: 11
                color: root.theme.textSecondary
                elide: Text.ElideRight
            }
        }
    }

    function dayKey(time) { return new Date(time).toDateString() }

    function dayLabel(time) {
        var date = new Date(time)
        var today = calendar.now
        var tomorrow = new Date(today)
        tomorrow.setDate(tomorrow.getDate() + 1)
        // Events that started earlier but are still running belong to today.
        if (date < today || date.toDateString() === today.toDateString()) return "Today"
        if (date.toDateString() === tomorrow.toDateString()) return "Tomorrow"
        return Qt.formatDate(date, "dddd, d MMM")
    }

    function timeLabel(e) {
        if (e.allDay) return "All day"
        var s = new Date(e.start), en = new Date(e.end)
        // Multi-day events read better as a span than as two clock times.
        if (en - s >= 86400000) return "Until " + Qt.formatDate(en, "ddd d MMM")
        return Qt.formatTime(s, "h:mm AP") + " – " + Qt.formatTime(en, "h:mm AP")
    }

    component LinkButton: Text {
        id: link
        signal activated
        property bool busy: false
        font.family: root.theme.textFont
        font.pixelSize: 12
        font.weight: 700
        color: linkMa.containsMouse ? root.theme.textPrimary : root.theme.accent
        opacity: busy ? 0.4 : 1
        MouseArea {
            id: linkMa
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            enabled: !link.busy && !Lib.WidgetService.editing
            cursorShape: Qt.PointingHandCursor
            onClicked: link.activated()
        }
    }

    ColumnLayout {
        visible: !look.small && !look.row
        anchors.fill: parent
        anchors.margins: look.column ? 10 : 14
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            Item { visible: look.column; Layout.fillWidth: true }
            Text {
                text: "󰃭"
                font.family: root.theme.iconFont
                font.pixelSize: 16
                color: root.theme.accent
            }
            Text {
                visible: !look.column
                text: "Calendar"
                font.family: root.theme.textFont
                font.pixelSize: 15
                font.weight: 800
                color: root.theme.textPrimary
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            LinkButton {
                text: "󰑐"
                font.family: root.theme.iconFont
                font.pixelSize: 14
                busy: root.calendar.busy
                onActivated: root.calendar.refresh()
            }
            LinkButton {
                visible: !look.column
                text: "Open ↗"
                onActivated: Qt.openUrlExternally("https://calendar.proton.me")
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.calendar.error || (root.calendar.busy && !root.calendar.updatedAt ? "Syncing…"
                : root.calendar.upcoming.length + " events · next 30 days"
                  + (root.calendar.updatedAt ? " · " + Qt.formatTime(root.calendar.updatedAt, "h:mm AP") : ""))
            textFormat: Text.PlainText
            font.family: root.theme.textFont
            font.pixelSize: 11
            color: root.calendar.error ? root.theme.accentRed : root.theme.textSecondary
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        ListView {
            id: agenda
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 4
            clip: true
            spacing: 4
            model: root.calendar.upcoming
            interactive: !Lib.WidgetService.editing
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: ColumnLayout {
                id: row
                required property var modelData
                required property int index
                readonly property bool firstOfDay: index === 0
                    || root.dayLabel(root.calendar.upcoming[index - 1].start) !== root.dayLabel(modelData.start)
                readonly property bool live: modelData.start <= root.calendar.now.getTime()
                readonly property color tint: root.calendar.colors[modelData.calendarId] || root.theme.accent
                width: agenda.width - 8
                spacing: 4

                Text {
                    visible: row.firstOfDay
                    Layout.topMargin: row.index === 0 ? 0 : 8
                    text: root.dayLabel(row.modelData.start).toUpperCase()
                    font.family: root.theme.textFont
                    font.pixelSize: 10
                    font.weight: 800
                    font.letterSpacing: 1.2
                    color: root.theme.textSecondary
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: body.implicitHeight + 16
                    radius: 10
                    color: Qt.rgba(row.tint.r, row.tint.g, row.tint.b, row.live ? 0.28 : 0.13)

                    Rectangle {
                        width: 3
                        radius: 2
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 8 }
                        color: row.tint
                        opacity: row.live ? 1 : 0.8
                    }

                    ColumnLayout {
                        id: body
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                        anchors.leftMargin: 20
                        anchors.rightMargin: 10
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.title
                            textFormat: Text.PlainText
                            font.family: root.theme.textFont
                            font.pixelSize: 13
                            font.weight: 700
                            color: root.theme.textPrimary
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: (row.live && !row.modelData.allDay ? "Now · " : "") + root.timeLabel(row.modelData)
                                + (row.modelData.location ? "  ·  " + row.modelData.location : "")
                            textFormat: Text.PlainText
                            font.family: root.theme.textFont
                            font.pixelSize: 11
                            color: row.live ? root.theme.accent : root.theme.textSecondary
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 24
                visible: agenda.count === 0
                text: root.calendar.busy ? "Loading your calendars…"
                    : root.calendar.error ? "Events unavailable"
                    : "Nothing in the next 30 days"
                font.family: root.theme.textFont
                font.pixelSize: 13
                color: root.theme.textSecondary
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
