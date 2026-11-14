import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Dialogs
import rhx.plugin 1.0
import rhx.config 1.0
import rhx.theme 1.0
import rhx.audio 1.0
import rhx.ui 1.0

Item {
    id: root
    objectName: "pluginSchemaView"
    clip: true

    property string pluginId: ""
    property var schemaData: ({})
    property var pluginState: ({})

    function getCleanId() {
        var id = root.pluginId || "";
        if (id.indexOf("plugin:") === 0) {
            id = id.substring(7);
        }
        return id;
    }

    onPluginIdChanged: {
        loadSchema();
    }

    Component.onCompleted: {
        loadSchema();
    }

    function loadSchema() {
        var cid = getCleanId();
        if (!cid) return;
        schemaData = PluginManager.getPluginViewSchema(cid) || {};
        pluginState = PluginManager.getAllPluginState(cid) || {};
        if (PluginManager.taskModel) {
            PluginManager.taskModel.pluginFilter = cid;
        }

        // Seed state store with default values defined in schema if key does not exist yet
        var s = Object.assign({}, pluginState);
        var changed = false;
        if (schemaData && schemaData.sections) {
            for (var i = 0; i < schemaData.sections.length; ++i) {
                var sec = schemaData.sections[i];
                if (sec && sec.key) {
                    var k = String(sec.key);
                    if (s[k] === undefined && sec.default !== undefined) {
                        s[k] = sec.default;
                        PluginManager.setPluginState(cid, k, sec.default);
                        changed = true;
                    }
                }
            }
        }
        if (changed) {
            pluginState = s;
        }
    }

    Connections {
        target: PluginManager
        function onPluginsChanged() {
            root.loadSchema();
        }
        function onPluginViewUpdated(id) {
            if (id === root.getCleanId()) {
                root.pluginState = PluginManager.getAllPluginState(id) || {};
            }
        }
        function onPluginStateChanged(id, key, value) {
            if (id === root.getCleanId()) {
                var s = Object.assign({}, root.pluginState);
                s[key] = value;
                root.pluginState = s;
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 20

        // Header with Back button and Plugin title
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Rectangle {
                width: 36
                height: 36
                radius: 18
                color: backMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                border.color: Theme.borderSubtle

                SvgIcon {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: "qrc:/assets/icons/chevron_left.svg"
                    color: Theme.textPrimary
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (typeof window !== "undefined") {
                            window.currentTab = "plugins";
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.schemaData.title || qsTr("Plugin")
                font.pixelSize: 24
                font.bold: true
                color: Theme.textPrimary
            }
        }

        // Content Scrollable Area
        ScrollView {
            id: scrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: scrollView.availableWidth
                spacing: 16

                Repeater {
                    model: root.schemaData.sections || []
                    delegate: Rectangle {
                        id: sectionCard
                        Layout.fillWidth: true
                        implicitHeight: sectionContent.implicitHeight + 32
                        radius: 16
                        color: Theme.surfaceContainerLow
                        border.color: Theme.borderSubtle

                        readonly property var sec: modelData
                        readonly property string secType: String(sec && sec.type ? sec.type : "card").toLowerCase()
                        readonly property string secKey: String(sec && sec.key ? sec.key : "")
                        readonly property var secVal: (secKey && root.pluginState[secKey] !== undefined) ? root.pluginState[secKey] : (sec && sec.default !== undefined ? sec.default : "")

                        ColumnLayout {
                            id: sectionContent
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            // 1. Title Row with count badge and clear button for task lists
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                visible: Boolean(sectionCard.sec && sectionCard.sec.title)

                                Text {
                                    text: sectionCard.sec ? (sectionCard.sec.title || "") : ""
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: Theme.primary
                                    Layout.fillWidth: true
                                }

                                // Queue Item Count Badge (driven by PluginTaskModel)
                                Rectangle {
                                    visible: (sectionCard.secType === "queue" || sectionCard.secType === "task_list") && PluginManager.taskModel && PluginManager.taskModel.count > 0
                                    implicitWidth: countText.implicitWidth + 16
                                    implicitHeight: 24
                                    radius: 12
                                    color: Theme.primaryContainer

                                    Text {
                                        id: countText
                                        anchors.centerIn: parent
                                        text: qsTr("%1 items").arg(PluginManager.taskModel ? PluginManager.taskModel.count : 0)
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: Theme.colorOnPrimaryContainer
                                    }
                                }

                                // Clear Queue Button
                                Rectangle {
                                    visible: (sectionCard.secType === "queue" || sectionCard.secType === "task_list") && PluginManager.taskModel && PluginManager.taskModel.count > 0
                                    implicitWidth: clearRow.implicitWidth + 16
                                    implicitHeight: 26
                                    radius: 13
                                    color: clearMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                    border.color: Theme.borderSubtle

                                    RowLayout {
                                        id: clearRow
                                        anchors.centerIn: parent
                                        spacing: 6

                                        SvgIcon {
                                            width: 13
                                            height: 13
                                            source: "qrc:/assets/icons/trash.svg"
                                            color: Theme.textSecondary
                                        }

                                        Text {
                                            text: qsTr("Clear Queue")
                                            font.pixelSize: 11
                                            color: Theme.textSecondary
                                        }
                                    }

                                    MouseArea {
                                        id: clearMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var cid = root.getCleanId();
                                            if (PluginManager.taskModel) {
                                                PluginManager.taskModel.clearTasks(cid);
                                            }
                                            PluginManager.clearPluginQueue(cid);
                                            PluginManager.invokePluginAction(cid, "clear_queue", {});
                                        }
                                    }
                                }
                            }

                            // 2. Subtitle / Details description
                            Text {
                                text: sectionCard.sec ? (sectionCard.sec.subtitle || sectionCard.sec.details || sectionCard.sec.description || "") : ""
                                font.pixelSize: 13
                                color: Theme.textSecondary
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                                visible: text.length > 0
                            }

                            // 3. Declarative Control Type: Options / Select / Format Chips
                            Flow {
                                Layout.fillWidth: true
                                spacing: 10
                                visible: sectionCard.secType === "options" || sectionCard.secType === "select" || sectionCard.secType === "format"

                                Repeater {
                                    model: (sectionCard.sec && sectionCard.sec.options) ? sectionCard.sec.options : []
                                    delegate: Rectangle {
                                        readonly property string optVal: String(typeof modelData === "object" && modelData.value !== undefined ? modelData.value : modelData)
                                        readonly property string optLabel: String(typeof modelData === "object" && modelData.label !== undefined ? modelData.label : modelData)
                                        readonly property bool isSelected: String(sectionCard.secVal).toUpperCase() === optVal.toUpperCase()

                                        implicitWidth: chipText.implicitWidth + 24
                                        implicitHeight: 32
                                        radius: 16
                                        color: isSelected ? Theme.primary : (chipMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
                                        border.color: isSelected ? Theme.primary : Theme.borderSubtle

                                        Text {
                                            id: chipText
                                            anchors.centerIn: parent
                                            text: optLabel
                                            font.pixelSize: 12
                                            font.bold: isSelected
                                            color: isSelected ? Theme.colorOnPrimary : Theme.textPrimary
                                        }

                                        MouseArea {
                                            id: chipMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var cid = root.getCleanId();
                                                var k = sectionCard.secKey;
                                                if (k) {
                                                    PluginManager.setPluginState(cid, k, optVal);
                                                }
                                                // Dispatch universal action
                                                var actId = (sectionCard.sec && sectionCard.sec.actionId) ? sectionCard.sec.actionId : (k ? (k + "_changed") : "option_selected");
                                                PluginManager.invokePluginAction(cid, actId, { key: k, value: optVal });

                                                // Backward compatibility for scripts implementing setFormat or setOption
                                                if (k === "format") {
                                                    PluginManager.callPluginMethod(cid, "setFormat", [optVal.toLowerCase()]);
                                                } else if (k) {
                                                    PluginManager.callPluginMethod(cid, "setOption", [k, optVal]);
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // 4. Declarative Control Type: Text Input
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                visible: sectionCard.secType === "text_input"

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 40
                                    radius: 10
                                    color: Theme.surfaceContainerHighest
                                    border.color: textInputField.activeFocus ? Theme.primary : Theme.borderSubtle

                                    TextInput {
                                        id: textInputField
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.pixelSize: 13
                                        color: Theme.textPrimary
                                        text: String(sectionCard.secVal || "")

                                        Text {
                                            anchors.fill: parent
                                            verticalAlignment: Text.AlignVCenter
                                            text: (sectionCard.sec && sectionCard.sec.placeholder) ? sectionCard.sec.placeholder : ""
                                            font.pixelSize: 13
                                            color: Theme.textMuted
                                            visible: !textInputField.text && !textInputField.activeFocus
                                        }

                                        onEditingFinished: {
                                            var cid = root.getCleanId();
                                            var k = sectionCard.secKey;
                                            if (k) {
                                                PluginManager.setPluginState(cid, k, text);
                                                var actId = (sectionCard.sec && sectionCard.sec.actionId) ? sectionCard.sec.actionId : (k + "_changed");
                                                PluginManager.invokePluginAction(cid, actId, { key: k, value: text });
                                            }
                                        }
                                    }
                                }
                            }

                            // 5. Declarative Control Type: File Picker / Folder Picker
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                visible: sectionCard.secType === "file_picker" || sectionCard.secType === "folder_picker"

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 40
                                    radius: 10
                                    color: Theme.surfaceContainerHighest
                                    border.color: Theme.borderSubtle

                                    TextInput {
                                        id: pathInputField
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        verticalAlignment: TextInput.AlignVCenter
                                        font.pixelSize: 12
                                        color: Theme.textPrimary
                                        text: String(sectionCard.secVal || "")

                                        Text {
                                            anchors.fill: parent
                                            verticalAlignment: Text.AlignVCenter
                                            text: qsTr("Select path...")
                                            font.pixelSize: 12
                                            color: Theme.textMuted
                                            visible: !pathInputField.text
                                        }

                                        onEditingFinished: {
                                            var cid = root.getCleanId();
                                            var k = sectionCard.secKey;
                                            if (k) {
                                                PluginManager.setPluginState(cid, k, text);
                                                PluginManager.invokePluginAction(cid, (sectionCard.sec && sectionCard.sec.actionId) ? sectionCard.sec.actionId : (k + "_changed"), { key: k, value: text });
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    implicitWidth: 80
                                    implicitHeight: 40
                                    radius: 10
                                    color: browseMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                    border.color: Theme.borderSubtle

                                    Text {
                                        anchors.centerIn: parent
                                        text: qsTr("Browse")
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: Theme.primary
                                    }

                                    MouseArea {
                                        id: browseMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (sectionCard.secType === "folder_picker") {
                                                folderDialog.open();
                                            } else {
                                                fileDialog.open();
                                            }
                                        }
                                    }

                                    FileDialog {
                                        id: fileDialog
                                        title: qsTr("Select File")
                                        onAccepted: {
                                            var p = selectedFile.toString();
                                            if (p.indexOf("file:///") === 0) p = p.substring(8);
                                            var cid = root.getCleanId();
                                            var k = sectionCard.secKey;
                                            if (k) {
                                                PluginManager.setPluginState(cid, k, p);
                                                PluginManager.invokePluginAction(cid, (sectionCard.sec && sectionCard.sec.actionId) ? sectionCard.sec.actionId : (k + "_changed"), { key: k, value: p });
                                            }
                                        }
                                    }

                                    FolderDialog {
                                        id: folderDialog
                                        title: qsTr("Select Directory")
                                        onAccepted: {
                                            var p = selectedFolder.toString();
                                            if (p.indexOf("file:///") === 0) p = p.substring(8);
                                            var cid = root.getCleanId();
                                            var k = sectionCard.secKey;
                                            if (k) {
                                                PluginManager.setPluginState(cid, k, p);
                                                PluginManager.invokePluginAction(cid, (sectionCard.sec && sectionCard.sec.actionId) ? sectionCard.sec.actionId : (k + "_changed"), { key: k, value: p });
                                            }
                                        }
                                    }
                                }
                            }

                            // 6. Declarative Control Type: Toggle / Switch
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                visible: sectionCard.secType === "toggle"

                                Text {
                                    Layout.fillWidth: true
                                    text: sectionCard.sec ? (sectionCard.sec.label || sectionCard.sec.title || "") : ""
                                    font.pixelSize: 13
                                    color: Theme.textPrimary
                                }

                                Rectangle {
                                    implicitWidth: 44
                                    implicitHeight: 24
                                    radius: 12
                                    color: Boolean(sectionCard.secVal) ? Theme.primary : Theme.surfaceContainerHighest
                                    border.color: Theme.borderSubtle

                                    Rectangle {
                                        width: 18
                                        height: 18
                                        radius: 9
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: Boolean(sectionCard.secVal) ? 22 : 4
                                        color: Boolean(sectionCard.secVal) ? Theme.colorOnPrimary : Theme.textSecondary
                                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var nextVal = !Boolean(sectionCard.secVal);
                                            var cid = root.getCleanId();
                                            var k = sectionCard.secKey;
                                            if (k) {
                                                PluginManager.setPluginState(cid, k, nextVal);
                                                PluginManager.invokePluginAction(cid, (sectionCard.sec && sectionCard.sec.actionId) ? sectionCard.sec.actionId : (k + "_changed"), { key: k, value: nextVal });
                                            }
                                        }
                                    }
                                }
                            }

                            // 7. Declarative Control Type: Slider
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                visible: sectionCard.secType === "slider"

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        Layout.fillWidth: true
                                        text: qsTr("Value: %1").arg(sliderCtrl.value)
                                        font.pixelSize: 12
                                        color: Theme.textSecondary
                                    }
                                }

                                Slider {
                                    id: sliderCtrl
                                    Layout.fillWidth: true
                                    from: (sectionCard.sec && sectionCard.sec.min !== undefined) ? sectionCard.sec.min : 0
                                    to: (sectionCard.sec && sectionCard.sec.max !== undefined) ? sectionCard.sec.max : 100
                                    stepSize: (sectionCard.sec && sectionCard.sec.step !== undefined) ? sectionCard.sec.step : 1
                                    value: Number(sectionCard.secVal || from)
                                    onMoved: {
                                        var cid = root.getCleanId();
                                        var k = sectionCard.secKey;
                                        if (k) {
                                            PluginManager.setPluginState(cid, k, value);
                                            PluginManager.invokePluginAction(cid, (sectionCard.sec && sectionCard.sec.actionId) ? sectionCard.sec.actionId : (k + "_changed"), { key: k, value: value });
                                        }
                                    }
                                }
                            }

                            // 8. Declarative Control Type: Progress Bar
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                visible: sectionCard.secType === "progress_bar"

                                readonly property real progVal: {
                                    var v = Number(sectionCard.secVal !== "" ? sectionCard.secVal : (sectionCard.sec && sectionCard.sec.value !== undefined ? sectionCard.sec.value : 0));
                                    return Math.max(0, Math.min(100, v));
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 8
                                    radius: 4
                                    color: Theme.surfaceContainerHighest

                                    Rectangle {
                                        width: parent.width * (parent.parent.progVal / 100.0)
                                        height: parent.height
                                        radius: 4
                                        color: Theme.primary
                                    }
                                }
                            }

                            // 9. Declarative Control Type: True Async Task List (ListView bound to PluginTaskModel)
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                visible: sectionCard.secType === "queue" || sectionCard.secType === "task_list"

                                // Empty placeholder when task model is empty
                                Rectangle {
                                    visible: !PluginManager.taskModel || PluginManager.taskModel.count === 0
                                    Layout.fillWidth: true
                                    implicitHeight: 64
                                    radius: 12
                                    color: Theme.surfaceContainerLowest
                                    border.color: Theme.borderSubtle

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 10

                                        SvgIcon {
                                            width: 18
                                            height: 18
                                            source: "qrc:/assets/icons/queue.svg"
                                            color: Theme.textMuted
                                        }

                                        Text {
                                            text: qsTr("No tasks in queue.")
                                            font.pixelSize: 13
                                            color: Theme.textMuted
                                        }
                                    }
                                }

                                // High-performance Incremental ListView (Zero Timer Polling)
                                ListView {
                                    id: taskListView
                                    visible: PluginManager.taskModel && PluginManager.taskModel.count > 0
                                    Layout.fillWidth: true
                                    implicitHeight: Math.min(Math.max(contentHeight, 56), 360)
                                    clip: true
                                    spacing: 8
                                    interactive: contentHeight > height
                                    model: PluginManager.taskModel

                                    delegate: Rectangle {
                                        width: taskListView.width
                                        implicitHeight: taskItemContent.implicitHeight + 16
                                        radius: 10
                                        color: Theme.surfaceContainerHigh
                                        border.color: Theme.borderSubtle

                                        ColumnLayout {
                                            id: taskItemContent
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            spacing: 6

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 12

                                                SvgIcon {
                                                    width: 18
                                                    height: 18
                                                    source: "qrc:/assets/icons/music_note.svg"
                                                    color: Theme.primary
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 2

                                                    Text {
                                                        text: model.title || qsTr("Task")
                                                        font.pixelSize: 13
                                                        font.bold: true
                                                        color: Theme.textPrimary
                                                        Layout.fillWidth: true
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        text: model.sourcePath || ""
                                                        font.pixelSize: 11
                                                        color: Theme.textMuted
                                                        Layout.fillWidth: true
                                                        elide: Text.ElideMiddle
                                                    }
                                                }

                                                // Format / Metadata Pill
                                                Rectangle {
                                                    visible: Boolean(model.format)
                                                    implicitWidth: queueFormatText.implicitWidth + 12
                                                    implicitHeight: 22
                                                    radius: 6
                                                    color: Theme.surfaceContainerHighest

                                                    Text {
                                                        id: queueFormatText
                                                        anchors.centerIn: parent
                                                        text: String(model.format || "").toUpperCase()
                                                        font.pixelSize: 10
                                                        font.bold: true
                                                        color: Theme.primary
                                                    }
                                                }

                                                // Status Badge
                                                Rectangle {
                                                    readonly property string s: String(model.status || "pending").toLowerCase()
                                                    implicitWidth: statusText.implicitWidth + 14
                                                    implicitHeight: 22
                                                    radius: 11
                                                    color: s === "completed" ? Theme.primaryContainer :
                                                           (s === "running" || s === "converting") ? Theme.primary :
                                                           (s === "failed" ? Theme.errorContainer : Theme.surfaceContainerLowest)
                                                    border.color: Theme.borderSubtle

                                                    Text {
                                                        id: statusText
                                                        anchors.centerIn: parent
                                                        text: {
                                                            if (parent.s === "completed") return qsTr("Completed");
                                                            if (parent.s === "running" || parent.s === "converting") return qsTr("Running %1%").arg(model.progress);
                                                            if (parent.s === "failed") return qsTr("Failed");
                                                            if (parent.s === "canceled") return qsTr("Canceled");
                                                            return qsTr("Pending");
                                                        }
                                                        font.pixelSize: 10
                                                        font.bold: true
                                                        color: parent.s === "completed" ? Theme.colorOnPrimaryContainer :
                                                               (parent.s === "running" || parent.s === "converting") ? Theme.colorOnPrimary :
                                                               (parent.s === "failed" ? Theme.colorOnErrorContainer : Theme.textSecondary)
                                                    }
                                                }

                                                // Cancel Button (visible when running/pending)
                                                Rectangle {
                                                    visible: Boolean(model.canCancel)
                                                    width: 26
                                                    height: 26
                                                    radius: 13
                                                    color: cancelMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                                                    SvgIcon {
                                                        anchors.centerIn: parent
                                                        width: 14
                                                        height: 14
                                                        source: "qrc:/assets/icons/close.svg"
                                                        color: Theme.textSecondary
                                                    }

                                                    MouseArea {
                                                        id: cancelMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (PluginManager.taskModel) {
                                                                PluginManager.taskModel.cancelTask(model.id);
                                                            }
                                                        }
                                                    }
                                                }

                                                // Retry Button (visible when failed/canceled)
                                                Rectangle {
                                                    visible: Boolean(model.canRetry)
                                                    width: 26
                                                    height: 26
                                                    radius: 13
                                                    color: retryMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                                                    SvgIcon {
                                                        anchors.centerIn: parent
                                                        width: 14
                                                        height: 14
                                                        source: "qrc:/assets/icons/refresh.svg"
                                                        color: Theme.primary
                                                    }

                                                    MouseArea {
                                                        id: retryMouse
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            if (PluginManager.taskModel) {
                                                                PluginManager.taskModel.retryTask(model.id);
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            // Smooth Progress Bar when task is running
                                            Rectangle {
                                                visible: String(model.status || "").toLowerCase() === "running"
                                                Layout.fillWidth: true
                                                implicitHeight: 4
                                                radius: 2
                                                color: Theme.surfaceContainerHighest

                                                Rectangle {
                                                    width: Math.max(0, Math.min(parent.width, parent.width * (Number(model.progress || 0) / 100.0)))
                                                    height: parent.height
                                                    radius: 2
                                                    color: Theme.primary
                                                    Behavior on width { NumberAnimation { duration: 120 } }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // 10. Declarative Control Type: Button / Action
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                visible: sectionCard.secType === "action" || sectionCard.secType === "button"

                                Rectangle {
                                    id: actionBtn
                                    readonly property bool isEnabled: {
                                        if (sectionCard.sec && sectionCard.sec.enabled !== undefined) return Boolean(sectionCard.sec.enabled);
                                        if (PluginManager.taskModel && PluginManager.taskModel.count > 0) return true;
                                        return true;
                                    }
                                    implicitWidth: 180
                                    implicitHeight: 40
                                    radius: 20
                                    color: isEnabled ? (actionMouse.containsMouse ? Qt.lighter(Theme.primary, 1.1) : Theme.primary) : Theme.surfaceContainerHighest
                                    opacity: isEnabled ? 1.0 : 0.6
                                    border.color: isEnabled ? Theme.primary : Theme.borderSubtle

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 8

                                        SvgIcon {
                                            width: 16
                                            height: 16
                                            source: (sectionCard.sec && sectionCard.sec.icon) ? sectionCard.sec.icon : "qrc:/assets/icons/play.svg"
                                            color: actionBtn.isEnabled ? Theme.colorOnPrimary : Theme.textMuted
                                        }

                                        Text {
                                            text: sectionCard.sec ? (sectionCard.sec.title || sectionCard.sec.text || qsTr("Execute")) : qsTr("Execute")
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: actionBtn.isEnabled ? Theme.colorOnPrimary : Theme.textMuted
                                        }
                                    }

                                    MouseArea {
                                        id: actionMouse
                                        anchors.fill: parent
                                        hoverEnabled: actionBtn.isEnabled
                                        cursorShape: actionBtn.isEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            if (!actionBtn.isEnabled) return;
                                            var cid = root.getCleanId();
                                            var actId = (sectionCard.sec && (sectionCard.sec.actionId || sectionCard.sec.action || sectionCard.sec.id)) ? (sectionCard.sec.actionId || sectionCard.sec.action || sectionCard.sec.id) : "start_transcoding";
                                            PluginManager.invokePluginAction(cid, actId, { section: sectionCard.sec });
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
