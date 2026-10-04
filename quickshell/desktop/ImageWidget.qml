import QtQuick
import "../lib" as Lib

Item {
    id: root
    required property QtObject theme
    property string sourceUrl: ""
    property bool folderMode: false
    property int rotationMinutes: 5
    property bool crop: true
    readonly property var folderResult: photos.value && photos.value.source === sourceUrl
        ? photos.value : null
    readonly property string picture: folderMode
        ? (folderResult ? folderResult.image : "") : sourceUrl
    readonly property string message: !sourceUrl ? "Choose an image or folder in Settings"
        : image.status === Image.Error ? "Image is unavailable"
        : folderMode && !picture ? (folderResult ? folderResult.error : "Loading images…") : ""

    onSourceUrlChanged: refresh.restart()
    onFolderModeChanged: refresh.restart()

    Timer {
        id: refresh
        interval: 100
        onTriggered: {
            if (photos.busy) restart()
            else photos.poll()
        }
    }

    Lib.CommandPoll {
        id: photos
        running: root.folderMode && root.sourceUrl !== ""
        interval: Math.max(1, root.rotationMinutes) * 60000
        command: ["python3", Qt.resolvedUrl("../bin/widget-image.py").toString().replace("file://", ""),
            root.sourceUrl, root.picture]
        parse: function(output) {
            try { return JSON.parse(output) }
            catch (e) { return { source: root.sourceUrl, image: "", error: "Cannot read this folder" } }
        }
    }

    Image {
        id: image
        anchors.fill: parent
        source: root.picture
        fillMode: root.crop ? Image.PreserveAspectCrop : Image.PreserveAspectFit
        asynchronous: true
        cache: !root.folderMode
    }

    Text {
        anchors.centerIn: parent
        width: parent.width - 32
        visible: root.message !== ""
        text: root.message
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        font.family: root.theme.textFont
        font.pixelSize: 13
        color: root.theme.textSecondary
    }
}
