import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Dialogs
import rhx.plugin 1.0
import rhx.config 1.0
import rhx.theme 1.0
import rhx.ui 1.0

Item {
    id: root
    objectName: "pluginsView"
    clip: true

    signal navigateTab(string tabId)

    property string selectedCategory: "All"
    property string searchQuery: ""
    property string toastMessage: ""

    Component.onCompleted: {
        PluginManager.refreshInstalledPlugins();
        PluginManager.fetchMarketIndex();
    }

    // Local file installer dialog
    FileDialog {
        id: fileDialog
        title: qsTr("Select .0px or .zip Plugin Package")
        nameFilters: [qsTr("Plugin Packages (*.0px *.zip)"), qsTr("All Files (*.*)")]
        onAccepted: {
            var path = selectedFile.toString();
            if (path.indexOf("file:///") === 0) {
                path = path.substring(8);
            } else if (path.indexOf("file://") === 0) {
                path = path.substring(7);
            }
            var ok = PluginManager.installPluginFrom0px(path);
            if (ok) {
                showToast(qsTr("Plugin installed successfully!"));
            } else {
                showToast(PluginManager.lastErrorMessage || qsTr("Failed to install plugin package."));
            }
        }
    }

    function showToast(msg) {
        toastMessage = msg;
        toastTimer.restart();
    }

    Timer {
        id: toastTimer
        interval: 3000
        onTriggered: root.toastMessage = ""
    }

    // Filtered model combiner
    function getFilteredList() {
        var market = PluginManager.marketPlugins;
        var installed = PluginManager.installedPlugins;
        var combined = [];
        var seenIds = {};

        // Merge installed plugins first
        for (var i = 0; i < installed.length; ++i) {
            var item = installed[i];
            item.installed = true;
            combined.push(item);
            seenIds[item.id] = true;
        }

        // Add non-installed market plugins
        for (var j = 0; j < market.length; ++j) {
            var mItem = market[j];
            if (!seenIds[mItem.id]) {
                mItem.installed = false;
                combined.push(mItem);
            }
        }

        var query = searchQuery.trim().toLowerCase();
        var result = [];

        for (var k = 0; k < combined.length; ++k) {
            var p = combined[k];

            // Category filter
            if (selectedCategory === "Installed") {
                if (!p.installed) continue;
            } else if (selectedCategory !== "All") {
                if ((p.category || "").toLowerCase() !== selectedCategory.toLowerCase()) continue;
            }

            // Search query filter
            if (query.length > 0) {
                var nameMatch = (p.name || "").toLowerCase().indexOf(query) !== -1;
                var descMatch = (p.description || "").toLowerCase().indexOf(query) !== -1;
                var authorMatch = (p.author || "").toLowerCase().indexOf(query) !== -1;
                var catMatch = (p.category || "").toLowerCase().indexOf(query) !== -1;
                if (!nameMatch && !descMatch && !authorMatch && !catMatch) {
                    continue;
                }
            }

            result.push(p);
        }

        return result;
    }

    // Connections to PluginManager signals
    Connections {
        target: PluginManager
        function onPluginInstalled(id) {
            showToast(qsTr("Installed plugin: %1").arg(id));
            cardsRepeater.model = getFilteredList();
        }
        function onPluginUninstalled(id) {
            showToast(qsTr("Uninstalled plugin: %1").arg(id));
            cardsRepeater.model = getFilteredList();
        }
        function onPluginStatusChanged(id, enabled) {
            showToast(enabled ? qsTr("Enabled: %1").arg(id) : qsTr("Disabled: %1").arg(id));
            cardsRepeater.model = getFilteredList();
        }
        function onMarketPluginsChanged() {
            cardsRepeater.model = getFilteredList();
        }
        function onPluginsChanged() {
            cardsRepeater.model = getFilteredList();
        }
        function onInstallFinished(id, success, message) {
            showToast(message || (success ? qsTr("Installation completed.") : qsTr("Installation failed.")));
            cardsRepeater.model = getFilteredList();
        }
        function onErrorOccurred(error) {
            showToast(error);
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 20

        // --------------------------------------------------------------------
        // 1. Top Header Area
        // --------------------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: qsTr("Plugins & Extensions")
                    font.pixelSize: 26
                    font.bold: true
                    color: Theme.textPrimary
                }

                Text {
                    text: qsTr("Explore, install and manage native 0rhxPlayer extensions (100% Native M3 • No WebView)")
                    font.pixelSize: 13
                    color: Theme.textSecondary
                }
            }

            // Install Local Package Button
            Rectangle {
                width: 140
                height: 38
                radius: 19
                color: localMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                border.color: Theme.borderSubtle
                scale: localMouse.pressed ? 0.96 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    SvgIcon {
                        width: 16
                        height: 16
                        source: "qrc:/assets/icons/folder_plus.svg"
                        color: Theme.textPrimary
                    }
                    Text {
                        text: qsTr("Install .0px")
                        font.pixelSize: 13
                        font.bold: true
                        color: Theme.textPrimary
                    }
                }
                MouseArea {
                    id: localMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: fileDialog.open()
                }
            }

            // Refresh Button
            Rectangle {
                width: 38
                height: 38
                radius: 19
                color: refMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                border.color: Theme.borderSubtle
                scale: refMouse.pressed ? 0.94 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }

                SvgIcon {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: "qrc:/assets/icons/refresh.svg"
                    color: Theme.textPrimary
                    NumberAnimation on rotation {
                        running: PluginManager.isFetchingMarket
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 800
                    }
                }
                MouseArea {
                    id: refMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: PluginManager.fetchMarketIndex()
                }
            }

            // Settings Jump Button
            Rectangle {
                width: 38
                height: 38
                radius: 19
                color: setMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                border.color: Theme.borderSubtle
                scale: setMouse.pressed ? 0.94 : 1.0
                Behavior on scale { NumberAnimation { duration: 100 } }

                SvgIcon {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: "qrc:/assets/icons/gear.svg"
                    color: Theme.textPrimary
                }
                MouseArea {
                    id: setMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (typeof window !== "undefined") {
                            window.currentTab = "settings";
                        }
                    }
                }
            }
        }

        // --------------------------------------------------------------------
        // 2. Filter & Search Controls
        // --------------------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Search Bar
            Rectangle {
                Layout.preferredWidth: 320
                Layout.preferredHeight: 38
                radius: 19
                color: Theme.surfaceContainerHigh
                border.color: searchInput.activeFocus ? Theme.primary : Theme.borderSubtle

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 8

                    SvgIcon {
                        width: 14
                        height: 14
                        source: "qrc:/assets/icons/search.svg"
                        color: Theme.iconNeutral
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        font.pixelSize: 13
                        color: Theme.textPrimary
                        selectByMouse: true
                        clip: true
                        onTextChanged: {
                            root.searchQuery = text;
                            cardsRepeater.model = getFilteredList();
                        }

                        Text {
                            anchors.fill: parent
                            text: qsTr("Search plugins...")
                            font.pixelSize: 13
                            color: Theme.textMuted
                            visible: !parent.text && !parent.activeFocus
                        }
                    }

                    SvgIcon {
                        width: 14
                        height: 14
                        source: "qrc:/assets/icons/trash.svg"
                        color: Theme.iconNeutral
                        visible: searchInput.text.length > 0
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: searchInput.text = ""
                        }
                    }
                }
            }

            // Category Filter Pills
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: ["All", "NetService", "Lyrics", "Metadata", "Test", "Installed"]
                    delegate: Rectangle {
                        readonly property bool isSelected: root.selectedCategory === modelData
                        height: 32
                        radius: 16
                        width: catText.implicitWidth + 24
                        color: isSelected ? Theme.primary : (catMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerLow)
                        border.color: isSelected ? Theme.primary : Theme.borderSubtle
                        scale: catMouse.pressed ? 0.95 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            id: catText
                            anchors.centerIn: parent
                            text: {
                                switch (modelData) {
                                    case "All": return qsTr("All");
                                    case "NetService": return qsTr("NetService");
                                    case "Lyrics": return qsTr("Lyrics");
                                    case "Metadata": return qsTr("Metadata");
                                    case "Test": return qsTr("Test");
                                    case "Installed": return qsTr("Installed");
                                    default: return modelData;
                                }
                            }
                            font.pixelSize: 12
                            font.bold: isSelected
                            color: isSelected ? Theme.colorOnPrimary : Theme.textPrimary
                        }

                        MouseArea {
                            id: catMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedCategory = modelData;
                                cardsRepeater.model = getFilteredList();
                            }
                        }
                    }
                }
            }
        }

        // Market Status Bar
        Text {
            text: PluginManager.marketStatusMessage
            font.pixelSize: 12
            color: Theme.textMuted
            visible: text.length > 0
        }

        // --------------------------------------------------------------------
        // 3. Plugin Cards Grid / Scrollable List
        // --------------------------------------------------------------------
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Flickable {
                contentWidth: width
                contentHeight: cardsFlow.implicitHeight + 40

                Flow {
                    id: cardsFlow
                    width: parent.width
                    spacing: 16

                    Repeater {
                        id: cardsRepeater
                        model: root.getFilteredList()

                        delegate: Rectangle {
                            id: card
                            width: (cardsFlow.width > 800) ? Math.floor((cardsFlow.width - 16) / 2) : cardsFlow.width
                            height: 160
                            radius: 16
                            color: Theme.surfaceContainerLow
                            border.color: cardMouse.containsMouse ? Theme.primary : Theme.borderSubtle
                            border.width: 1

                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 16

                                // Left: Plugin Icon
                                Rectangle {
                                    Layout.preferredWidth: 54
                                    Layout.preferredHeight: 54
                                    Layout.alignment: Qt.AlignTop
                                    radius: 16
                                    color: Theme.surfaceContainerHigh

                                    SvgIcon {
                                        anchors.centerIn: parent
                                        width: 28
                                        height: 28
                                        source: modelData.icon || "qrc:/assets/icons/plugin.svg"
                                        color: Theme.primary
                                    }
                                }

                                // Center: Info
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Text {
                                            text: modelData.name || modelData.id
                                            font.pixelSize: 16
                                            font.bold: true
                                            color: Theme.textPrimary
                                        }

                                        // Version Badge
                                        Rectangle {
                                            height: 18
                                            radius: 9
                                            width: verText.implicitWidth + 12
                                            color: Theme.surfaceContainerHighest
                                            Text {
                                                id: verText
                                                anchors.centerIn: parent
                                                text: "v" + (modelData.version || "1.0.0")
                                                font.pixelSize: 10
                                                color: Theme.textSecondary
                                            }
                                        }

                                        // Category Chip
                                        Rectangle {
                                            height: 18
                                            radius: 9
                                            width: catChipText.implicitWidth + 12
                                            color: Theme.primaryContainer
                                            Text {
                                                id: catChipText
                                                anchors.centerIn: parent
                                                text: modelData.category || "Other"
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: Theme.colorOnPrimaryContainer
                                            }
                                        }

                                        Item { Layout.fillWidth: true }
                                    }

                                    Text {
                                        text: qsTr("Author: %1").arg(modelData.author || "Community")
                                        font.pixelSize: 12
                                        color: Theme.textMuted
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        text: modelData.description || ""
                                        font.pixelSize: 12
                                        color: Theme.textSecondary
                                        wrapMode: Text.Wrap
                                        elide: Text.ElideRight
                                        maximumLineCount: 2
                                    }

                                    // Status & Action Row
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12

                                        // Status dot
                                        Rectangle {
                                            width: 8
                                            height: 8
                                            radius: 4
                                            color: modelData.installed ? (modelData.enabled ? Theme.primary : Theme.textMuted) : Theme.iconNeutral
                                        }

                                        Text {
                                            text: modelData.installed ? (modelData.enabled ? qsTr("Enabled") : qsTr("Disabled")) : qsTr("Available")
                                            font.pixelSize: 12
                                            color: modelData.installed ? (modelData.enabled ? Theme.primary : Theme.textSecondary) : Theme.textMuted
                                        }

                                        Item { Layout.fillWidth: true }

                                        // Open Button (if installed and has sidebar)
                                        Rectangle {
                                            visible: modelData.installed && modelData.enabled && modelData.sidebar && modelData.sidebar.route
                                            width: 64
                                            height: 30
                                            radius: 15
                                            color: openMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                            border.color: Theme.borderSubtle
                                            Text {
                                                anchors.centerIn: parent
                                                text: qsTr("Open")
                                                font.pixelSize: 11
                                                font.bold: true
                                                color: Theme.textPrimary
                                            }
                                            MouseArea {
                                                id: openMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (typeof window !== "undefined") {
                                                        window.currentTab = "plugin:" + modelData.id;
                                                    }
                                                }
                                            }
                                        }

                                        // Toggle Enabled Button (if installed)
                                        Rectangle {
                                            visible: modelData.installed
                                            width: 72
                                            height: 30
                                            radius: 15
                                            color: modelData.enabled ? Theme.primaryContainer : Theme.surfaceContainerHigh
                                            border.color: Theme.borderSubtle
                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.enabled ? qsTr("Disable") : qsTr("Enable")
                                                font.pixelSize: 11
                                                font.bold: true
                                                color: modelData.enabled ? Theme.colorOnPrimaryContainer : Theme.textPrimary
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    PluginManager.setPluginEnabled(modelData.id, !modelData.enabled);
                                                }
                                            }
                                        }

                                        // Uninstall Button (if installed)
                                        Rectangle {
                                            visible: modelData.installed
                                            width: 76
                                            height: 30
                                            radius: 15
                                            color: uninstMouse.containsMouse ? Qt.rgba(1, 0.2, 0.2, 0.15) : Theme.surfaceContainerHigh
                                            border.color: Theme.borderSubtle
                                            Text {
                                                anchors.centerIn: parent
                                                text: qsTr("Uninstall")
                                                font.pixelSize: 11
                                                color: Theme.textSecondary
                                            }
                                            MouseArea {
                                                id: uninstMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    PluginManager.uninstallPlugin(modelData.id);
                                                }
                                            }
                                        }

                                        // Install Button (if not installed)
                                        Rectangle {
                                            visible: !modelData.installed
                                            width: 86
                                            height: 30
                                            radius: 15
                                            color: instMouse.containsMouse ? Qt.darker(Theme.primary, 1.1) : Theme.primary
                                            scale: instMouse.pressed ? 0.95 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 80 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: qsTr("Install")
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: Theme.colorOnPrimary
                                            }
                                            MouseArea {
                                                id: instMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    PluginManager.installPluginFromMarket(modelData.id);
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
    }

    // Toast Notification Banner
    Rectangle {
        id: toastBanner
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        anchors.horizontalCenter: parent.horizontalCenter
        height: 38
        width: toastText.implicitWidth + 32
        radius: 19
        color: Theme.surfaceContainerHighest
        border.color: Theme.primary
        border.width: 1
        visible: root.toastMessage.length > 0
        z: 9999

        Text {
            id: toastText
            anchors.centerIn: parent
            text: root.toastMessage
            font.pixelSize: 13
            font.bold: true
            color: Theme.textPrimary
        }
    }
}
