import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import "../lib" as Lib

Item {
    id: root
    required property QtObject theme

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

    RowLayout {
        anchors.centerIn: parent
        width: Math.max(0, Math.min(parent.width - 24, 480))
        spacing: 10

        Rectangle {
            Layout.preferredWidth: Math.max(32, Math.min(root.height - 24, root.width * 0.28, 120))
            Layout.preferredHeight: Layout.preferredWidth
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

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: root.title
                font.family: root.theme.textFont
                font.pixelSize: 14
                font.weight: 700
                color: root.theme.textPrimary
                elide: Text.ElideRight
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                text: root.artist
                font.family: root.theme.textFont
                font.pixelSize: 12
                color: root.theme.textSecondary
                elide: Text.ElideRight
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }
            Lib.MediaButton {
                Layout.alignment: Qt.AlignHCenter
                icon: root.isPlaying ? "" : ""
                size: 28
                tint: root.theme.textPrimary
                visible: root.hasPlayer
                enabled: !Lib.WidgetService.editing
                onClicked: if (root.player) root.player.togglePlaying()
            }
        }
    }
}
