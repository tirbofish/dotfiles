import QtQuick
import QtQuick.Controls
import QtCore
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property QtObject theme
    property var positions: ({})

    function loadPositions() {
        try { positions = JSON.parse(settings.value("positions", "{}")) }
        catch (e) { positions = ({}) }
    }

    function savePosition(key, x, y) {
        var next = Object.assign({}, positions)
        next[key] = { x: Math.round(x), y: Math.round(y) }
        positions = next
        settings.setValue("positions", JSON.stringify(next))
    }

    function iconFor(url, suffix, isDir) {
        if (isDir) return "image://icon/folder"
        if (["png", "jpg", "jpeg", "webp", "gif", "svg"].indexOf(suffix.toLowerCase()) >= 0)
            return url
        return "image://icon/" + (suffix === "desktop" ? "application-x-executable" : "text-x-generic")
    }

    Component.onCompleted: loadPositions()
    color: "transparent"
    exclusiveZone: -1
    anchors { top: true; right: true; bottom: true; left: true }
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "desktop-files"

    Settings {
        id: settings
        location: "file://" + Quickshell.env("HOME") + "/.local/state/quickshell-desktop-icons.ini"
    }

    FolderListModel {
        id: files
        folder: "file://" + Quickshell.env("HOME") + "/Desktop"
        showDotAndDotDot: false
        showHidden: false
        showDirsFirst: true
        sortField: FolderListModel.Name
    }

    Repeater {
        model: files

        delegate: Rectangle {
            id: tile
            required property int index
            required property string fileName
            required property url fileUrl
            required property string fileSuffix
            required property bool fileIsDir

            readonly property string positionKey: String(fileUrl)
            readonly property string localPath: decodeURIComponent(String(fileUrl).replace("file://", ""))
            readonly property var savedPosition: root.positions[positionKey]
            readonly property int rows: Math.max(1, Math.floor((root.height - 64) / 108))

            x: savedPosition ? savedPosition.x : 24 + Math.floor(index / rows) * 96
            y: savedPosition ? savedPosition.y : 24 + (index % rows) * 108
            width: 88
            height: 100
            radius: 8
            color: mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 6
                width: 58
                height: 58
                source: root.iconFor(tile.fileUrl, tile.fileSuffix, tile.fileIsDir)
                sourceSize: Qt.size(64, 64)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            Text {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 32
                text: tile.fileName
                color: root.theme.textPrimary
                font.family: root.theme.textFont
                font.pixelSize: 12
                font.weight: 600
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignTop
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.75)
            }

            Menu {
                id: fileMenu

                MenuItem {
                    text: "Open"
                    onTriggered: Quickshell.execDetached(tile.fileSuffix === "desktop"
                        ? ["gio", "launch", tile.localPath]
                        : ["xdg-open", String(tile.fileUrl)])
                }
                MenuItem {
                    text: "Rename…"
                    onTriggered: Quickshell.execDetached(["thunar", "--bulk-rename", tile.localPath])
                }
                MenuItem {
                    text: "Show in Folder"
                    onTriggered: Quickshell.execDetached(["thunar",
                        Quickshell.env("HOME") + "/Desktop"])
                }
                MenuSeparator {}
                MenuItem {
                    text: "Move to Trash"
                    onTriggered: Quickshell.execDetached(["gio", "trash", tile.localPath])
                }
            }

            MouseArea {
                acceptedButtons: Qt.AllButtons
                id: mouse
                anchors.fill: parent
                // Both buttons are accepted above.
                hoverEnabled: true
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                drag.target: (pressedButtons & Qt.LeftButton) ? tile : null
                drag.minimumX: 0
                drag.maximumX: root.width - tile.width
                drag.minimumY: 0
                drag.maximumY: root.height - tile.height
                drag.smoothed: false
                onClicked: event => {
                    if (event.button === Qt.RightButton) fileMenu.popup()
                }
                onReleased: event => {
                    if (event.button === Qt.LeftButton)
                        root.savePosition(tile.positionKey, tile.x, tile.y)
                }
                onDoubleClicked: event => {
                    if (event.button === Qt.LeftButton)
                        Quickshell.execDetached(tile.fileSuffix === "desktop"
                            ? ["gio", "launch", tile.localPath]
                            : ["xdg-open", String(tile.fileUrl)])
                }
            }
        }
    }
}
