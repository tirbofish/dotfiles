import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import "../lib" as Lib

Item {
    id: root
    required property QtObject theme
    property bool showArtwork: true

    WidgetLook { id: look; host: root }

    property var players: Mpris.players.values
    property var player: null
    property bool hasPlayer: player !== null
    property bool isPlaying: player ? player.isPlaying : false
    property string title: player && player.trackTitle ? player.trackTitle : "Not playing"
    property string artist: player && player.trackArtist ? player.trackArtist : ""

    function pickPlayer() {
        var ps = root.players || []
        if (ps.length === 0) { root.player = null; return }
        for (var i = 0; i < ps.length; i++)
            if (ps[i] && ps[i].isPlaying) { root.player = ps[i]; return }
        root.player = ps[0]
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.pickPlayer()
    }

    // 1×1: album art as the tile, tap to play/pause.
    Item {
        anchors.fill: parent
        visible: look.small
        Rectangle {
            anchors.fill: parent
            radius: root.theme.radiusOuter
            color: root.theme.subtleFill
            clip: true
            Image {
                anchors.fill: parent
                source: art.source
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
                opacity: 0.85
            }
        }
        Text {
            anchors.centerIn: parent
            text: !root.hasPlayer ? "󰎆" : root.isPlaying ? "󰏤" : "󰐊"
            font.family: root.theme.iconFont
            font.pixelSize: 30
            color: art.status === Image.Ready ? "white" : root.theme.accent
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.35)
        }
        MouseArea {
            anchors.fill: parent
            enabled: root.hasPlayer && !Lib.WidgetService.editing
            cursorShape: Qt.PointingHandCursor
            onClicked: root.player.togglePlaying()
        }
    }

    Tile {
        anchors.fill: parent
        visible: !look.small && !root.hasPlayer
        theme: root.theme
        icon: "󰎆"
        label: "Nothing playing"
    }

    GridLayout {
        visible: !look.small && root.hasPlayer
        anchors.centerIn: parent
        width: Math.max(0, Math.min(parent.width - 24, 480))
        columns: look.wide ? 2 : 1
        columnSpacing: 10
        rowSpacing: 8

        Rectangle {
            visible: root.showArtwork
            Layout.preferredWidth: Math.max(32, Math.min(look.wide ? (root.height - 24) : (root.width - 48), root.width * 0.28, 120))
            Layout.preferredHeight: Layout.preferredWidth
            Layout.alignment: Qt.AlignHCenter
            Layout.rowSpan: look.wide ? 3 : 1
            radius: 10
            color: root.theme.bgItem
            clip: true
            Text {
                anchors.centerIn: parent
                text: "󰎆"
                font.family: root.theme.iconFont
                font.pixelSize: 22
                color: root.theme.accent
                visible: !art.status || art.status !== Image.Ready
            }
            Image {
                id: art
                anchors.fill: parent
                source: root.player && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
            }
        }

        Text {
            text: root.title
            font.family: root.theme.textFont
            font.pixelSize: 14
            font.weight: 700
            color: root.theme.textPrimary
            elide: Text.ElideRight
            Layout.fillWidth: true
            horizontalAlignment: look.wide ? Text.AlignLeft : Text.AlignHCenter
        }
        Text {
            text: root.artist
            font.family: root.theme.textFont
            font.pixelSize: 12
            color: root.theme.textSecondary
            elide: Text.ElideRight
            Layout.fillWidth: true
            horizontalAlignment: look.wide ? Text.AlignLeft : Text.AlignHCenter
        }
        Row {
            Layout.alignment: look.wide ? Qt.AlignLeft : Qt.AlignHCenter
            spacing: 6
            visible: root.hasPlayer
            enabled: !Lib.WidgetService.editing
            Lib.MediaButton {
                icon: "󰒮"
                size: 28
                tint: root.theme.textSecondary
                opacity: root.player && root.player.canGoPrevious ? 1 : 0.35
                onClicked: if (root.player && root.player.canGoPrevious) root.player.previous()
            }
            Lib.MediaButton {
                icon: root.isPlaying ? "" : ""
                size: 32
                tint: root.theme.textPrimary
                onClicked: if (root.player) root.player.togglePlaying()
            }
            Lib.MediaButton {
                icon: "󰒭"
                size: 28
                tint: root.theme.textSecondary
                opacity: root.player && root.player.canGoNext ? 1 : 0.35
                onClicked: if (root.player && root.player.canGoNext) root.player.next()
            }
        }
    }
}
