import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
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
    property var pluginQueue: []
    property var pluginOptions: ({})
    property string selectedFormat: "MP3"

    function getCleanId() {
        var id = root.pluginId || "";
        if (id.indexOf("plugin:") === 0) {
            id = id.substring(7);
        }
        return id;
    }

    onPluginIdChanged: {
        loadSchema();
        refreshQueue();
    }

    Component.onCompleted: {
        loadSchema();
        refreshQueue();
    }

    function loadSchema() {
        var cid = getCleanId();
        if (!cid) return;
        schemaData = PluginManager.getPluginViewSchema(cid) || {};
    }

    function refreshQueue() {
        var cid = getCleanId();
        if (!cid) {
            pluginQueue = [];
            return;
        }
        var q = PluginManager.getPluginQueue(cid);
        pluginQueue = q || [];
    }

    Connections {
        target: PluginManager
        function onPluginsChanged() {
            root.loadSchema();
            root.refreshQueue();
        }
        function onPluginViewUpdated(id) {
            if (id === root.getCleanId()) {
                root.refreshQueue();
            }
        }
        function onPluginActionTriggered(id, actionId, slotType, data) {
            if (id === root.getCleanId()) {
                root.refreshQueue();
            }
        }
    }

    // Dynamic poll timer while tasks are being converted
    Timer {
        id: processingPollTimer
        interval: 200
        repeat: true
        running: {
            if (!pluginQueue || pluginQueue.length === 0) return false;
            for (var i = 0; i < pluginQueue.length; ++i) {
                if (pluginQueue[i].status === "converting") {
                    return true;
                }
            }
            return false;
        }
        onTriggered: root.refreshQueue()
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

                        readonly property var sectionData: modelData
                        readonly property bool isQueueSection: Boolean(modelData && (modelData.type === "queue" || (modelData.title && modelData.title.indexOf("Queue") !== -1)))
                        readonly property bool isFormatSection: Boolean(modelData && (modelData.type === "format" || (modelData.key === "format") || (modelData.title && (modelData.title.indexOf("Target Audio Format") !== -1 || modelData.title.indexOf("Target Format") !== -1))))
                        readonly property bool isOptionsSection: Boolean(modelData && (modelData.type === "options" || (modelData.options && modelData.options.length > 0 && !isFormatSection)))
                        readonly property string optionKey: (modelData && modelData.key) ? String(modelData.key) : ""
                        readonly property bool isActionSection: Boolean(modelData && (modelData.type === "action" || (modelData.title && (modelData.title.indexOf("Start Transcoding") !== -1 || modelData.title.indexOf("Batch Execution") !== -1))))

                        ColumnLayout {
                            id: sectionContent
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            // 1. Title Row (with optional Queue Action buttons / count badge)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Text {
                                    text: modelData.title || ""
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: Theme.primary
                                    Layout.fillWidth: true
                                }

                                // Queue Item Count Badge
                                Rectangle {
                                    visible: sectionCard.isQueueSection && root.pluginQueue.length > 0
                                    implicitWidth: countText.implicitWidth + 16
                                    implicitHeight: 24
                                    radius: 12
                                    color: Theme.primaryContainer

                                    Text {
                                        id: countText
                                        anchors.centerIn: parent
                                        text: qsTr("%1 items").arg(root.pluginQueue.length)
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: Theme.colorOnPrimaryContainer
                                    }
                                }

                                // Clear Queue Button
                                Rectangle {
                                    visible: sectionCard.isQueueSection && root.pluginQueue.length > 0
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
                                            PluginManager.clearPluginQueue(root.getCleanId());
                                            root.refreshQueue();
                                        }
                                    }
                                }
                            }

                            // 2. Subtitle / Details description
                            Text {
                                text: modelData.subtitle || modelData.details || ""
                                font.pixelSize: 13
                                color: Theme.textSecondary
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                                visible: text.length > 0
                            }

                            // 3. Dynamic Section: Queue List View
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                visible: sectionCard.isQueueSection

                                // Empty placeholder when queue is empty
                                Rectangle {
                                    visible: root.pluginQueue.length === 0
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
                                            text: qsTr("Queue is empty. Right-click any track in your library and select 'Add to Convert Queue'.")
                                            font.pixelSize: 13
                                            color: Theme.textMuted
                                        }
                                    }
                                }

                                // Active Queue Items List
                                Repeater {
                                    model: root.pluginQueue
                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 52
                                        radius: 10
                                        color: Theme.surfaceContainerHigh
                                        border.color: Theme.borderSubtle

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 14
                                            anchors.rightMargin: 14
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
                                                    text: modelData.title || (modelData.sourcePath ? modelData.sourcePath.split(/[\\/]/).pop() : qsTr("Track"))
                                                    font.pixelSize: 13
                                                    font.bold: true
                                                    color: Theme.textPrimary
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    text: modelData.sourcePath || modelData.filePath || ""
                                                    font.pixelSize: 11
                                                    color: Theme.textMuted
                                                    Layout.fillWidth: true
                                                    elide: Text.ElideMiddle
                                                }
                                            }

                                            // Target Format Pill
                                            Rectangle {
                                                implicitWidth: queueFormatText.implicitWidth + 12
                                                implicitHeight: 22
                                                radius: 6
                                                color: Theme.surfaceContainerHighest

                                                Text {
                                                    id: queueFormatText
                                                    anchors.centerIn: parent
                                                    text: (modelData.format || root.selectedFormat || "MP3").toUpperCase()
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                    color: Theme.primary
                                                }
                                            }

                                            // Status Badge
                                            Rectangle {
                                                readonly property string s: (modelData.status || "pending").toLowerCase()
                                                implicitWidth: statusText.implicitWidth + 14
                                                implicitHeight: 22
                                                radius: 11
                                                color: s === "completed" ? Theme.primaryContainer :
                                                       s === "converting" ? Theme.primary : Theme.surfaceContainerLowest
                                                border.color: Theme.borderSubtle

                                                Text {
                                                    id: statusText
                                                    anchors.centerIn: parent
                                                    text: {
                                                        if (parent.s === "completed") return qsTr("Completed");
                                                        if (parent.s === "converting") return qsTr("Converting...");
                                                        if (parent.s === "failed") return qsTr("Failed");
                                                        return qsTr("Pending");
                                                    }
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                    color: parent.s === "completed" ? Theme.colorOnPrimaryContainer :
                                                           parent.s === "converting" ? Theme.colorOnPrimary : Theme.textSecondary
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // 4. Dynamic Section: Target Format Selection Chips
                            Flow {
                                Layout.fillWidth: true
                                spacing: 10
                                visible: sectionCard.isFormatSection

                                Repeater {
                                    model: (sectionCard.sectionData && sectionCard.sectionData.options && sectionCard.sectionData.options.length > 0) ? sectionCard.sectionData.options : ["MP3", "WAV", "FLAC", "AAC", "Opus", "OGG"]
                                    delegate: Rectangle {
                                        readonly property string optVal: String(modelData)
                                        readonly property bool isSelected: root.selectedFormat.toUpperCase() === optVal.toUpperCase()
                                        implicitWidth: chipText.implicitWidth + 24
                                        implicitHeight: 32
                                        radius: 16
                                        color: isSelected ? Theme.primary : (chipMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
                                        border.color: isSelected ? Theme.primary : Theme.borderSubtle

                                        Text {
                                            id: chipText
                                            anchors.centerIn: parent
                                            text: optVal
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
                                                root.selectedFormat = optVal;
                                                PluginManager.callPluginMethod(root.getCleanId(), "setFormat", [optVal.toLowerCase()]);
                                                PluginManager.showToast(qsTr("Target format set to %1").arg(optVal));
                                                root.refreshQueue();
                                            }
                                        }
                                    }
                                }
                            }

                            // 5. Dynamic Section: General Options Chips (Resampling, Channels, Quality, Output Dir)
                            Flow {
                                Layout.fillWidth: true
                                spacing: 10
                                visible: sectionCard.isOptionsSection

                                Repeater {
                                    model: (sectionCard.sectionData && sectionCard.sectionData.options) ? sectionCard.sectionData.options : []
                                    delegate: Rectangle {
                                        readonly property string optVal: String(modelData)
                                        readonly property bool isSelected: {
                                            var cur = root.pluginOptions[sectionCard.optionKey];
                                            if (cur !== undefined) return cur === optVal;
                                            var def = sectionCard.sectionData ? sectionCard.sectionData.default : "";
                                            return def ? (optVal === def) : (index === 0);
                                        }
                                        implicitWidth: chipOptText.implicitWidth + 24
                                        implicitHeight: 32
                                        radius: 16
                                        color: isSelected ? Theme.primary : (chipOptMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
                                        border.color: isSelected ? Theme.primary : Theme.borderSubtle

                                        Text {
                                            id: chipOptText
                                            anchors.centerIn: parent
                                            text: optVal
                                            font.pixelSize: 12
                                            font.bold: isSelected
                                            color: isSelected ? Theme.colorOnPrimary : Theme.textPrimary
                                        }

                                        MouseArea {
                                            id: chipOptMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var opts = Object.assign({}, root.pluginOptions);
                                                opts[sectionCard.optionKey] = optVal;
                                                root.pluginOptions = opts;
                                                PluginManager.callPluginMethod(root.getCleanId(), "setOption", [sectionCard.optionKey, optVal]);
                                                root.refreshQueue();
                                            }
                                        }
                                    }
                                }
                            }

                            // 6. Dynamic Section: Start Transcoding Action Button
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                visible: sectionCard.isActionSection

                                Rectangle {
                                    id: actionBtn
                                    readonly property bool hasQueue: root.pluginQueue.length > 0
                                    implicitWidth: 180
                                    implicitHeight: 40
                                    radius: 20
                                    color: hasQueue ? (actionMouse.containsMouse ? Qt.lighter(Theme.primary, 1.1) : Theme.primary) : Theme.surfaceContainerHighest
                                    opacity: hasQueue ? 1.0 : 0.6
                                    border.color: hasQueue ? Theme.primary : Theme.borderSubtle

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 8

                                        SvgIcon {
                                            width: 16
                                            height: 16
                                            source: "qrc:/assets/icons/play.svg"
                                            color: actionBtn.hasQueue ? Theme.colorOnPrimary : Theme.textMuted
                                        }

                                        Text {
                                            text: qsTr("Start Transcoding")
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: actionBtn.hasQueue ? Theme.colorOnPrimary : Theme.textMuted
                                        }
                                    }

                                    MouseArea {
                                        id: actionMouse
                                        anchors.fill: parent
                                        hoverEnabled: actionBtn.hasQueue
                                        cursorShape: actionBtn.hasQueue ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            if (!actionBtn.hasQueue) return;
                                            PluginManager.triggerPluginAction(root.getCleanId(), "start_transcoding", "workbench", {});
                                            root.refreshQueue();
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
