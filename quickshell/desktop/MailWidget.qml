import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../lib" as Lib

// Unread inbox mail from Proton (proton CLI), Gmail (gws) or both,
// refreshed every two minutes.
Item {
    id: root
    required property QtObject theme
    property string provider: "Google"          // Proton | Google | Both
    property string query: "is:unread in:inbox" // Gmail search; Proton always shows unread inbox
    readonly property int max: 25
    readonly property bool useProton: provider !== "Google"
    readonly property bool useGoogle: provider !== "Proton"
    property var protonMail: []
    property var gmail: []
    property int protonTotal: 0
    property string protonError: ""
    property string gmailError: ""
    readonly property var messages: (useProton ? protonMail : []).concat(useGoogle ? gmail : [])
        .sort((a, b) => b.time - a.time)
    readonly property string error: [useProton ? protonError : "", useGoogle ? gmailError : ""]
        .filter(e => e).join(" ")
    readonly property bool busy: protonFetch.running || gmailFetch.running
    readonly property string count: {
        var n = (useProton ? protonTotal : 0) + (useGoogle ? gmail.length : 0)
        return useGoogle && gmail.length >= max ? n + "+" : String(n)
    }
    readonly property string webUrl: provider === "Proton" ? "https://mail.proton.me" : "https://mail.google.com"

    WidgetLook { id: look; host: root }

    function refresh() {
        if (useProton && !protonFetch.running) {
            protonFetch.command = ["timeout", "90", Quickshell.env("HOME") + "/.local/bin/proton",
                "--no-input", "--no-log", "--log-level", "error", "--output", "json",
                "mail", "messages", "list", "--unread", "--limit", String(root.max)]
            protonFetch.running = true
        }
        if (useGoogle && !gmailFetch.running) {
            gmailFetch.command = ["timeout", "60", Quickshell.env("HOME") + "/.bun/bin/gws", "gmail", "+triage",
                "--max", String(root.max), "--query", root.query, "--format", "json"]
            gmailFetch.running = true
        }
    }
    onQueryChanged: refresh()
    onProviderChanged: refresh()

    function sender(from) {
        var m = String(from || "").match(/^\s*"?([^"<]+?)"?\s*</)
        return m ? m[1] : String(from || "")
    }

    function open(msg) {
        Qt.openUrlExternally(msg ? msg.url : root.webUrl)
    }

    // Messages are normalised to { from, subject, time, url, provider }.
    Process {
        id: protonFetch
        stdout: StdioCollector { id: protonOut }
        stderr: StdioCollector { id: protonErr }
        onExited: (code) => {
            if (code !== 0) {
                root.protonError = "Couldn't reach Proton Mail. Check `proton` sign-in."
                console.warn("[Mail] proton exit", code, protonErr.text)
                return
            }
            try {
                var d = JSON.parse(protonOut.text)
                root.protonMail = (d.messages || []).map(m => ({
                    from: m.from_name || m.from_address, subject: m.subject, time: m.time * 1000,
                    provider: "Proton", url: "https://mail.proton.me/u/0/inbox/" + m.conversation_id }))
                root.protonTotal = Number(d.total || root.protonMail.length)
                root.protonError = ""
            } catch (e) {
                root.protonError = "Couldn't read Proton Mail's response."
            }
        }
    }

    Process {
        id: gmailFetch
        stdout: StdioCollector { id: gmailOut }
        stderr: StdioCollector { id: gmailErr }
        onExited: (code) => {
            if (code !== 0) {
                root.gmailError = "Couldn't reach Gmail. Check `gws auth`."
                console.warn("[Mail] gmail exit", code, gmailErr.text)
                return
            }
            try {
                root.gmail = (JSON.parse(gmailOut.text).messages || []).map(m => ({
                    from: root.sender(m.from), subject: m.subject, time: Date.parse(m.date) || 0,
                    provider: "Gmail", url: "https://mail.google.com/mail/u/0/#all/" + m.id }))
                root.gmailError = ""
            } catch (e) {
                root.gmailError = "Couldn't read Gmail's response."
            }
        }
    }

    Timer {
        interval: 120000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Tile {
        anchors.fill: parent
        visible: look.small
        theme: root.theme
        icon: "󰇮"
        value: root.error ? "!" : root.count
        label: "unread"
        clickable: !Lib.WidgetService.editing
        onClicked: root.open(null)
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        visible: look.row
        spacing: 12
        Text {
            text: "󰇮"
            font.family: root.theme.iconFont
            font.pixelSize: 22
            color: root.theme.accent
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                Layout.fillWidth: true
                text: root.error || (root.messages.length ? root.messages[0].subject : "Inbox zero")
                font.family: root.theme.textFont
                font.pixelSize: 13
                font.weight: 700
                color: root.error ? root.theme.accentRed : root.theme.textPrimary
                textFormat: Text.PlainText
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: root.messages.length > 0
                text: root.messages.length ? root.messages[0].from + " · " + root.count + " unread" : ""
                font.family: root.theme.textFont
                font.pixelSize: 11
                color: root.theme.textSecondary
                textFormat: Text.PlainText
                elide: Text.ElideRight
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        visible: look.row
        enabled: !Lib.WidgetService.editing
        cursorShape: Qt.PointingHandCursor
        onClicked: root.open(root.messages.length ? root.messages[0] : null)
    }

    ColumnLayout {
        visible: !look.small && !look.row
        anchors.fill: parent
        anchors.margins: 14
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: "󰇮"
                font.family: root.theme.iconFont
                font.pixelSize: 16
                color: root.theme.accent
            }
            Text {
                text: root.provider === "Proton" ? "Proton Mail" : root.provider === "Google" ? "Gmail" : "Mail"
                font.family: root.theme.textFont
                font.pixelSize: 15
                font.weight: 800
                color: root.theme.textPrimary
                Layout.fillWidth: true
            }
            Text {
                text: root.error ? "" : root.count + " unread"
                font.family: root.theme.textFont
                font.pixelSize: 11
                font.weight: 700
                color: root.theme.textSecondary
            }
            Text {
                text: "󰑐"
                font.family: root.theme.iconFont
                font.pixelSize: 14
                color: root.theme.accent
                opacity: root.busy ? 0.4 : 1
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    enabled: !root.busy && !Lib.WidgetService.editing
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.refresh()
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: root.messages
            interactive: !Lib.WidgetService.editing
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Rectangle {
                required property var modelData
                width: list.width - 8
                implicitHeight: col.implicitHeight + 14
                radius: 10
                color: rowMa.containsMouse ? root.theme.subtleFillHover : root.theme.subtleFill

                ColumnLayout {
                    id: col
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 10 }
                    spacing: 1
                    Text {
                        Layout.fillWidth: true
                        text: modelData.from + (root.provider === "Both" ? "  ·  " + modelData.provider : "")
                        font.family: root.theme.textFont
                        font.pixelSize: 11
                        font.weight: 700
                        color: root.theme.textSecondary
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.subject || "(no subject)"
                        font.family: root.theme.textFont
                        font.pixelSize: 13
                        color: root.theme.textPrimary
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                    }
                }
                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !Lib.WidgetService.editing
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.open(modelData)
                }
            }

            Text {
                anchors.centerIn: parent
                width: parent.width - 24
                visible: list.count === 0
                text: root.error || (root.busy ? "Checking mail…" : "Inbox zero ✓")
                font.family: root.theme.textFont
                font.pixelSize: 13
                color: root.error ? root.theme.accentRed : root.theme.textSecondary
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
