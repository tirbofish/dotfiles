import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../lib" as Lib

PanelWindow {
    id: win

    required property QtObject theme
    required property string outputKey
    required property string outputName
    property string storeTab: "plugins"
    property string renamingPackId: ""
    property string renameDraft: ""
    property bool editingWidgetSetting: false
    property string imagePickerWidgetId: ""
    property string imagePickerOutputKey: ""
    readonly property var selectedSpec: {
        var _ = Lib.WidgetService.settingsStamp
        return Lib.WidgetService.findSpec(win.outputKey, Lib.WidgetService.selectedId)
    }
    readonly property var selectedEntry: selectedSpec
        ? Lib.WidgetService.catalogEntry(selectedSpec.type) : ({})
    readonly property var selectedSettings: {
        var _ = Lib.WidgetService.settingsStamp
        return selectedSpec && selectedSpec.settings ? selectedSpec.settings : ({})
    }
    readonly property var selectedOptions: selectedEntry.options || []
    readonly property bool imageSettings: !!selectedSpec && selectedSpec.type === "image"
    readonly property string imageSource: imageSettings ? (selectedSettings.sourceUrl || "") : ""

    // Stays mapped (empty input mask, hidden content) so entering edit mode
    // doesn't wait on a new surface.
    readonly property bool shown: Lib.WidgetService.editing
    onShownChanged: if (!shown) editingWidgetSetting = false
    color: "transparent"
    exclusiveZone: 0
    aboveWindows: true
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "desktop-widget-edit"
    focusable: renamingPackId !== "" || editingWidgetSetting
    WlrLayershell.keyboardFocus: renamingPackId !== "" || editingWidgetSetting
        ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    anchors { top: true; left: true; right: true; bottom: true }
    mask: Region { item: win.shown ? chrome : null }

    function toggleStore() {
        Lib.WidgetService.pickerOpen = !Lib.WidgetService.pickerOpen
    }

    function beginRename(pack) {
        renamingPackId = pack.id
        renameDraft = pack.name || pack.id
    }

    function finishRename() {
        Lib.WidgetService.renamePack(renamingPackId, renameDraft)
        renamingPackId = ""
    }

    function openImagePicker(folder) {
        if (!win.imageSettings) return
        win.imagePickerWidgetId = win.selectedSpec.id
        win.imagePickerOutputKey = win.outputKey
        if (folder) folderPicker.open()
        else imagePicker.open()
    }

    function saveImageSource(url, folder) {
        if (!Lib.WidgetService.findSpec(win.imagePickerOutputKey, win.imagePickerWidgetId)) return
        Lib.WidgetService.setSettings(win.imagePickerOutputKey, win.imagePickerWidgetId,
            { sourceUrl: url.toString(), folderMode: folder })
    }

    FileDialog {
        id: imagePicker
        title: "Choose one image"
        fileMode: FileDialog.OpenFile
        currentFolder: "file://" + Quickshell.env("HOME") + "/Pictures"
        nameFilters: ["Images (*.jpg *.jpeg *.png *.webp *.gif *.bmp *.svg *.avif *.tif *.tiff *.JPG *.JPEG *.PNG *.WEBP *.GIF *.BMP *.SVG *.AVIF *.TIF *.TIFF)", "All files (*)"]
        onAccepted: win.saveImageSource(selectedFile, false)
    }

    FolderDialog {
        id: folderPicker
        title: "Choose an image folder"
        currentFolder: "file://" + Quickshell.env("HOME") + "/Pictures"
        onAccepted: win.saveImageSource(selectedFolder, true)
    }

    Item {
        anchors.fill: parent
        visible: win.shown

        Column {
            id: chrome
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 56
            width: Math.min(620, win.screen.width - 40)
            spacing: 8

            Rectangle {
                width: parent.width
                height: 40
                radius: 12
                color: win.theme.bgCard
                border.width: 1
                border.color: win.theme.outline

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 8

                    Text {
                        text: "Arrange widgets · " + win.outputName
                        font.family: win.theme.textFont
                        font.pixelSize: 13
                        font.weight: 600
                        color: win.theme.textPrimary
                        Layout.leftMargin: 8
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    StoreButton {
                        label: Lib.WidgetService.pickerOpen ? "Close Store" : "Store"
                        onClicked: win.toggleStore()
                    }
                    StoreButton {
                        label: "Clear"
                        danger: true
                        onClicked: Lib.WidgetService.clearOutput(win.outputKey)
                    }
                    StoreButton {
                        label: "Done"
                        accent: true
                        onClicked: Lib.WidgetService.setEditing(false)
                    }
                }
            }

            Rectangle {
                visible: Lib.WidgetService.settingsOpen && win.selectedSpec
                width: parent.width
                height: win.imageSettings ? 112 : 64
                radius: 12
                color: win.theme.bgCard
                border.width: 1
                border.color: win.theme.outline

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    anchors.bottomMargin: win.imageSettings ? 58 : 10
                    spacing: 12

                    ColumnLayout {
                        Layout.preferredWidth: 125
                        spacing: 0
                        Text {
                            text: win.selectedEntry.label || "Widget"
                            font.family: win.theme.textFont
                            font.pixelSize: 13
                            font.weight: 800
                            color: win.theme.textPrimary
                        }
                        Text {
                            text: "Settings"
                            font.family: win.theme.textFont
                            font.pixelSize: 10
                            color: win.theme.textSecondary
                        }
                    }

                    Repeater {
                        model: win.selectedOptions
                        delegate: RowLayout {
                            id: optionRow
                            required property var modelData
                            readonly property var currentValue:
                                win.selectedSettings[modelData.key] !== undefined
                                    ? win.selectedSettings[modelData.key] : modelData.value
                            spacing: 6
                            Text {
                                text: optionRow.modelData.label
                                font.family: win.theme.textFont
                                font.pixelSize: 11
                                color: win.theme.textSecondary
                            }
                            Rectangle {
                                visible: optionRow.modelData.kind !== "text"
                                width: optionValue.implicitWidth + 18
                                height: 28
                                radius: 8
                                color: optionMa.containsMouse ? win.theme.subtleFillHover : win.theme.subtleFill
                                Text {
                                    id: optionValue
                                    anchors.centerIn: parent
                                    text: optionRow.modelData.kind === "bool"
                                        ? (optionRow.currentValue ? "On" : "Off")
                                        : String(optionRow.currentValue) + (optionRow.modelData.suffix || "")
                                    font.family: win.theme.textFont
                                    font.pixelSize: 11
                                    font.weight: 700
                                    color: win.theme.accent
                                }
                                MouseArea {
                                    id: optionMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var next = !optionRow.currentValue
                                        if (optionRow.modelData.kind === "choice") {
                                            var values = optionRow.modelData.values || []
                                            var index = values.indexOf(optionRow.currentValue)
                                            next = values[(index + 1) % values.length]
                                        }
                                        Lib.WidgetService.setSetting(win.outputKey, win.selectedSpec.id,
                                            optionRow.modelData.key, next)
                                    }
                                }
                            }
                            TextField {
                                visible: optionRow.modelData.kind === "text"
                                Layout.preferredWidth: 245
                                Layout.preferredHeight: 28
                                text: String(optionRow.currentValue)
                                selectByMouse: true
                                font.family: win.theme.textFont
                                font.pixelSize: 11
                                color: win.theme.textPrimary
                                background: Rectangle {
                                    radius: 8
                                    color: win.theme.bgItem
                                    border.width: parent.activeFocus ? 1 : 0
                                    border.color: win.theme.accent
                                }
                                function save() {
                                    var value = text.trim()
                                    if (value) Lib.WidgetService.setSetting(win.outputKey,
                                        win.selectedSpec.id, optionRow.modelData.key, value)
                                }
                                onAccepted: { save(); focus = false }
                                onEditingFinished: save()
                                onActiveFocusChanged: win.editingWidgetSetting = activeFocus
                            }
                        }
                    }

                    Text {
                        visible: win.selectedOptions.length === 0
                        text: "No configurable options"
                        font.family: win.theme.textFont
                        font.pixelSize: 11
                        color: win.theme.textSecondary
                        Layout.fillWidth: true
                    }
                    Item { Layout.fillWidth: true }
                    StoreButton {
                        label: "Reset"
                        onClicked: Lib.WidgetService.resetSettings(win.outputKey, win.selectedSpec.id)
                    }
                    Text {
                        text: "×"
                        font.pixelSize: 18
                        color: win.theme.textSecondary
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -7
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Lib.WidgetService.settingsOpen = false
                        }
                    }
                }

                RowLayout {
                    visible: win.imageSettings
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 10
                    height: 34
                    spacing: 8

                    StoreButton {
                        label: "Choose image"
                        onClicked: win.openImagePicker(false)
                    }
                    StoreButton {
                        label: "Choose folder"
                        onClicked: win.openImagePicker(true)
                    }
                    Text {
                        Layout.fillWidth: true
                        text: win.imageSource
                            ? (win.selectedSettings.folderMode ? "Folder: " : "Image: ")
                                + decodeURIComponent(win.imageSource.replace(/\/$/, "").split("/").pop())
                            : "No image or folder selected"
                        elide: Text.ElideMiddle
                        font.family: win.theme.textFont
                        font.pixelSize: 11
                        color: win.theme.textSecondary
                        HoverHandler { id: sourceHover }
                        ToolTip.visible: sourceHover.hovered && win.imageSource !== ""
                        ToolTip.text: decodeURIComponent(win.imageSource)
                    }
                }
            }

            Rectangle {
                visible: Lib.WidgetService.pickerOpen
                width: parent.width
                height: 390
                radius: 12
                color: win.theme.bgCard
                border.width: 1
                border.color: win.theme.outline
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Widget Store"
                            font.family: win.theme.textFont
                            font.pixelSize: 16
                            font.weight: 800
                            color: win.theme.textPrimary
                            Layout.fillWidth: true
                        }
                        StoreButton {
                            id: packSave
                            visible: win.storeTab === "packs"
                            label: "+ Save current"
                            onClicked: Lib.WidgetService.savePack(win.outputKey,
                                win.screen.width, win.screen.height)
                        }
                        TabButton { label: "Plugins"; tab: "plugins" }
                        TabButton { label: "Packs"; tab: "packs" }
                    }

                    GridView {
                        id: pluginGrid
                        visible: win.storeTab === "plugins"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        cellWidth: width / 2
                        cellHeight: 66
                        model: Lib.WidgetService.catalog
                        delegate: Item {
                            required property var modelData
                            width: pluginGrid.cellWidth
                            height: pluginGrid.cellHeight
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 3
                                radius: 10
                                color: pluginMa.containsMouse ? win.theme.subtleFillHover : win.theme.subtleFill
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 10
                                    Text {
                                        text: modelData.icon
                                        font.family: win.theme.iconFont
                                        font.pixelSize: 22
                                        color: win.theme.accent
                                        Layout.preferredWidth: 28
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.label
                                            font.family: win.theme.textFont
                                            font.pixelSize: 13
                                            font.weight: 700
                                            color: win.theme.textPrimary
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.detail
                                            font.family: win.theme.textFont
                                            font.pixelSize: 10
                                            color: win.theme.textSecondary
                                            elide: Text.ElideRight
                                        }
                                    }
                                    Text { text: "+"; font.pixelSize: 18; color: win.theme.accent }
                                }
                                MouseArea {
                                    id: pluginMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Lib.WidgetService.addWidget(win.outputKey, modelData.type,
                                        win.screen.width, win.screen.height)
                                }
                            }
                        }
                    }

                    ListView {
                        id: packList
                        visible: win.storeTab === "packs"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 8
                        model: Lib.WidgetService.packs
                        delegate: Rectangle {
                            required property var modelData
                            width: packList.width
                            height: 72
                            radius: 10
                            color: packMa.containsMouse ? win.theme.subtleFillHover : win.theme.subtleFill
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 12
                                z: 1
                                RowLayout {
                                    Layout.preferredWidth: 120
                                    spacing: 7
                                    Repeater {
                                        model: (modelData.widgets || []).slice(0, 4)
                                        Text {
                                            required property var modelData
                                            text: Lib.WidgetService.catalogEntry(modelData.type).icon || "◻"
                                            font.family: win.theme.iconFont
                                            font.pixelSize: 18
                                            color: win.theme.accent
                                        }
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        visible: win.renamingPackId !== modelData.id
                                        text: modelData.name || modelData.id
                                        font.family: win.theme.textFont
                                        font.pixelSize: 14
                                        font.weight: 700
                                        color: win.theme.textPrimary
                                    }
                                    TextField {
                                        visible: win.renamingPackId === modelData.id
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 30
                                        text: win.renameDraft
                                        selectByMouse: true
                                        font.family: win.theme.textFont
                                        font.pixelSize: 13
                                        color: win.theme.textPrimary
                                        background: Rectangle {
                                            radius: 7
                                            color: win.theme.bgItem
                                            border.width: 1
                                            border.color: win.theme.accent
                                        }
                                        onTextEdited: win.renameDraft = text
                                        onAccepted: win.finishRename()
                                        onEditingFinished: if (win.renamingPackId === modelData.id)
                                            win.finishRename()
                                        Keys.onEscapePressed: win.renamingPackId = ""
                                        onVisibleChanged: if (visible) Qt.callLater(forceActiveFocus)
                                    }
                                    Text {
                                        text: (modelData.widgets || []).length + " widgets · works with every theme"
                                        font.family: win.theme.textFont
                                        font.pixelSize: 11
                                        color: win.theme.textSecondary
                                    }
                                }
                                Text {
                                    visible: win.renamingPackId !== modelData.id
                                    text: "✎"
                                    font.pixelSize: 15
                                    color: win.theme.textSecondary
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -8
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: win.beginRename(modelData)
                                    }
                                }
                                Text {
                                    text: "Apply"
                                    font.family: win.theme.textFont
                                    font.pixelSize: 12
                                    font.weight: 700
                                    color: win.theme.accent
                                }
                                Text {
                                    text: "×"
                                    font.pixelSize: 18
                                    color: win.theme.accentRed
                                    z: 2
                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -8
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Lib.WidgetService.removePack(modelData.id)
                                    }
                                }
                            }
                            MouseArea {
                                id: packMa
                                z: 0
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Lib.WidgetService.applyPack(win.outputKey, modelData,
                                    win.screen.width, win.screen.height)
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: packList.count === 0
                            text: "No widget packs yet"
                            font.family: win.theme.textFont
                            font.pixelSize: 12
                            color: win.theme.textSecondary
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: win.storeTab === "plugins"
                            ? "Click a plugin to add it · drag to move · drag the corner to resize"
                            : "Packs are reusable layouts and stay independent of themes"
                        font.family: win.theme.textFont
                        font.pixelSize: 10
                        color: win.theme.textSecondary
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }

    component StoreButton: Rectangle {
        id: button
        property string label: ""
        property bool accent: false
        property bool danger: false
        signal clicked()
        Layout.preferredWidth: buttonText.implicitWidth + 20
        Layout.preferredHeight: 28
        radius: 8
        color: accent ? win.theme.accent
            : danger && buttonMa.containsMouse ? win.theme.accentRed
            : buttonMa.containsMouse ? win.theme.subtleFillHover : win.theme.subtleFill
        Text {
            id: buttonText
            anchors.centerIn: parent
            text: button.label
            font.family: win.theme.textFont
            font.pixelSize: 13
            font.weight: 600
            color: button.accent || (button.danger && buttonMa.containsMouse)
                ? win.theme.textOnAccent : win.theme.textPrimary
        }
        MouseArea {
            id: buttonMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    component TabButton: Rectangle {
        id: tabButton
        required property string label
        required property string tab
        Layout.preferredWidth: tabText.implicitWidth + 22
        Layout.preferredHeight: 28
        radius: 8
        color: win.storeTab === tab ? win.theme.accent : win.theme.subtleFill
        Text {
            id: tabText
            anchors.centerIn: parent
            text: tabButton.label
            font.family: win.theme.textFont
            font.pixelSize: 12
            font.weight: 700
            color: win.storeTab === tabButton.tab ? win.theme.textOnAccent : win.theme.textPrimary
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                win.storeTab = tabButton.tab
            }
        }
    }
}
