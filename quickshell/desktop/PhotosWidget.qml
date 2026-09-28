import QtQuick
import "../lib" as Lib

Item {
    id: root
    required property QtObject theme
    property int rotationMinutes: 5
    readonly property string picture: photos.value || ""

    WidgetLook { id: look; host: root }

    Lib.CommandPoll {
        id: photos
        interval: Math.max(1, root.rotationMinutes) * 60000
        command: ["bash", "-lc", "find \"$HOME/Pictures\" -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) -print 2>/dev/null | shuf -n1"]
        parse: function(output) {
            var path = String(output || "").trim()
            return path ? "file://" + encodeURI(path) : ""
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: root.theme.radiusOuter
        clip: true

        Image {
            anchors.fill: parent
            source: root.picture
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }

        Rectangle {
            visible: !look.small
            anchors.left: parent.left
            anchors.right: look.wide ? undefined : parent.right
            anchors.bottom: parent.bottom
            anchors.top: look.wide ? parent.top : undefined
            width: look.wide ? Math.min(160, parent.width * 0.38) : undefined
            height: look.wide ? undefined : 42
            color: "#88000000"
            Text {
                anchors.left: parent.left
                anchors.verticalCenter: look.wide ? undefined : parent.verticalCenter
                anchors.top: look.wide ? parent.top : undefined
                anchors.margins: 12
                text: root.picture ? "Photos" : "No photos in ~/Pictures"
                font.family: root.theme.textFont
                font.pixelSize: 12
                font.weight: 700
                color: "white"
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: look.wide ? undefined : parent.verticalCenter
                anchors.bottom: look.wide ? parent.bottom : undefined
                anchors.margins: 12
                text: "󰑐"
                font.family: root.theme.iconFont
                font.pixelSize: 16
                color: "white"
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    enabled: !Lib.WidgetService.editing
                    cursorShape: Qt.PointingHandCursor
                    onClicked: photos.poll()
                }
            }
        }
    }
}
