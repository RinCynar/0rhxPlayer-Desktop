import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Dialogs
import rhx.plugin 1.0
import rhx.config 1.0
import rhx.theme 1.0
import rhx.ui 1.0
import "components"

Item {
    id: root
    objectName: "pluginsView"
    clip: true

    signal navigateTab(string tabId)

    property string activeTab: "discover" // "discover", "installed", "tasks"
    property string selectedCategory: "All"
    property string searchQuery: ""
    property string toastMessage: ""

    function saveStateSnapshot() {
        return {
            activeTab: activeTab,
            selectedCategory: selectedCategory,
            searchQuery: searchQuery
        };
    }

    function restoreStateSnapshot(snap) {
        if (!snap) return;
        if (snap.activeTab) activeTab = snap.activeTab;
        if (snap.selectedCategory) selectedCategory = snap.selectedCategory;
        if (snap.searchQuery !== undefined) searchQuery = snap.searchQuery;
    }

    Component.onCompleted: {
        PluginManager.refreshInstalledPlugins();
        if (PluginManager.marketPlugins.length === 0 && !PluginManager.isFetchingMarket) {
            PluginManager.fetchMarketIndex();
        }
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
        interval: 3500
        onTriggered: root.toastMessage = ""
    }

    // Filter helper for discover (market) plugins
    function getMarketList() {
        var market = PluginManager.marketPlugins;
        var query = searchQuery.trim().toLowerCase();
        var list = [];
        for (var i = 0; i < market.length; ++i) {
            var p = market[i];
            if (selectedCategory !== "All" && (p.category || "").toLowerCase() !== selectedCategory.toLowerCase()) {
                continue;
            }
            if (query.length > 0) {
                var nameM = (p.name || "").toLowerCase().indexOf(query) !== -1;
                var descM = (p.description || "").toLowerCase().indexOf(query) !== -1;
                var authM = (p.author || "").toLowerCase().indexOf(query) !== -1;
                if (!nameM && !descM && !authM) continue;
            }
            list.push(p);
        }
        return list;
    }

    // Filter helper for installed plugins
    function getInstalledList() {
        var installed = PluginManager.installedPlugins;
        var query = searchQuery.trim().toLowerCase();
        var list = [];
        for (var i = 0; i < installed.length; ++i) {
            var p = installed[i];
            if (query.length > 0) {
                var nameM = (p.name || "").toLowerCase().indexOf(query) !== -1;
                var descM = (p.description || "").toLowerCase().indexOf(query) !== -1;
                var idM = (p.id || "").toLowerCase().indexOf(query) !== -1;
                if (!nameM && !descM && !idM) continue;
            }
            list.push(p);
        }
        return list;
    }

    // Connections to PluginManager signals
    Connections {
        target: PluginManager
        function onPluginInstalled(id) {
            showToast(qsTr("Installed plugin: %1").arg(id));
        }
        function onPluginUninstalled(id) {
            showToast(qsTr("Uninstalled plugin: %1").arg(id));
        }
        function onPluginStatusChanged(id, enabled) {
            showToast(enabled ? qsTr("Enabled: %1").arg(id) : qsTr("Disabled: %1").arg(id));
        }
        function onInstallFinished(id, success, message) {
            showToast(message || (success ? qsTr("Installation completed.") : qsTr("Installation failed.")));
        }
        function onErrorOccurred(error) {
            if (error.indexOf("fetch plugin index") === -1 && error.indexOf("fetch market index") === -1) {
                showToast(error);
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 18

        // --------------------------------------------------------------------
        // 1. Top Header Area: Title, Navigation Tabs & Global Actions
        // --------------------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Text {
                text: qsTr("Plugins")
                font.pixelSize: 26
                font.bold: true
                color: Theme.textPrimary
            }

            // Tab Switcher Pill Bar (Discover, Installed, Tasks)
            Rectangle {
                height: 38
                radius: 19
                color: Theme.surfaceContainerHigh
                border.color: Theme.borderSubtle
                Layout.leftMargin: 12

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 4

                    // Tab: Discover
                    Rectangle {
                        Layout.preferredWidth: tabDiscoverText.implicitWidth + 24
                        Layout.fillHeight: true
                        radius: 16
                        color: root.activeTab === "discover" ? Theme.primary : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            id: tabDiscoverText
                            anchors.centerIn: parent
                            text: qsTr("Discover")
                            font.pixelSize: 13
                            font.bold: root.activeTab === "discover"
                            color: root.activeTab === "discover" ? Theme.colorOnPrimary : Theme.textPrimary
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeTab = "discover"
                        }
                    }

                    // Tab: Installed
                    Rectangle {
                        Layout.preferredWidth: tabInstalledText.implicitWidth + 24
                        Layout.fillHeight: true
                        radius: 16
                        color: root.activeTab === "installed" ? Theme.primary : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                id: tabInstalledText
                                text: qsTr("Installed")
                                font.pixelSize: 13
                                font.bold: root.activeTab === "installed"
                                color: root.activeTab === "installed" ? Theme.colorOnPrimary : Theme.textPrimary
                            }
                            Rectangle {
                                width: 18
                                height: 18
                                radius: 9
                                color: root.activeTab === "installed" ? Theme.colorOnPrimary : Theme.surfaceContainerHighest
                                Text {
                                    anchors.centerIn: parent
                                    text: PluginManager.installedPlugins.length
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: root.activeTab === "installed" ? Theme.primary : Theme.textSecondary
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeTab = "installed"
                        }
                    }

                    // Tab: Tasks
                    Rectangle {
                        Layout.preferredWidth: tabTasksText.implicitWidth + 24
                        Layout.fillHeight: true
                        radius: 16
                        color: root.activeTab === "tasks" ? Theme.primary : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                id: tabTasksText
                                text: qsTr("Tasks")
                                font.pixelSize: 13
                                font.bold: root.activeTab === "tasks"
                                color: root.activeTab === "tasks" ? Theme.colorOnPrimary : Theme.textPrimary
                            }
                            Rectangle {
                                visible: PluginManager.taskModel.activeCount > 0
                                width: 18
                                height: 18
                                radius: 9
                                color: root.activeTab === "tasks" ? Theme.colorOnPrimary : Theme.primary
                                Text {
                                    anchors.centerIn: parent
                                    text: PluginManager.taskModel.activeCount
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: root.activeTab === "tasks" ? Theme.primary : Theme.colorOnPrimary
                                }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeTab = "tasks"
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Install Local Package Button
            M3Button {
                text: qsTr("Install .0px")
                icon: "qrc:/assets/icons/folder_plus.svg"
                iconSize: 16
                variant: "tonal"
                implicitHeight: 38
                onClicked: fileDialog.open()
            }

            // Refresh Button
            M3IconButton {
                icon: "qrc:/assets/icons/refresh.svg"
                size: 38
                iconSize: 16
                variant: "standard"
                onClicked: {
                    PluginManager.refreshInstalledPlugins();
                    PluginManager.fetchMarketIndex();
                }
            }
        }

        // --------------------------------------------------------------------
        // 2. Search & Category Filter Controls (for Discover & Installed tabs)
        // --------------------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            visible: root.activeTab !== "tasks"

            // Search Bar
            M3TextField {
                id: searchInput
                Layout.preferredWidth: 320
                Layout.preferredHeight: 38
                placeholderText: root.activeTab === "discover" ? qsTr("Search marketplace...") : qsTr("Search installed plugins...")
                leadingIcon: "qrc:/assets/icons/search.svg"
                text: root.searchQuery
                onTextEdited: root.searchQuery = text
            }

            // Category Filter Pills (in Discover tab only)
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: root.activeTab === "discover"

                Repeater {
                    model: PluginManager.categories
                    delegate: M3Chip {
                        readonly property bool isSelected: root.selectedCategory === modelData
                        text: {
                            if (modelData === "All") return qsTr("All");
                            if (modelData === "Installed") return qsTr("Installed");
                            return qsTr(modelData);
                        }
                        selected: isSelected
                        onClicked: root.selectedCategory = modelData
                    }
                }
            }
        }

        // --------------------------------------------------------------------
        // 3. Tab Body 1: Discover (Marketplace)
        // --------------------------------------------------------------------
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.activeTab === "discover"

            // Empty state
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12
                visible: !PluginManager.isFetchingMarket && root.getMarketList().length === 0

                SvgIcon {
                    Layout.alignment: Qt.AlignHCenter
                    width: 32
                    height: 32
                    source: "qrc:/assets/icons/plugin.svg"
                    color: Theme.iconNeutral
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("No marketplace plugins found.")
                    font.pixelSize: 14
                    color: Theme.textMuted
                }
            }

            // Cards Grid
            ScrollView {
                anchors.fill: parent
                clip: true
                visible: root.getMarketList().length > 0

                Flickable {
                    contentWidth: width
                    contentHeight: marketFlow.implicitHeight + 40

                    Flow {
                        id: marketFlow
                        width: parent.width
                        spacing: 16

                        Repeater {
                            model: root.getMarketList()
                            delegate: Rectangle {
                                width: (marketFlow.width > 800) ? Math.floor((marketFlow.width - 16) / 2) : marketFlow.width
                                height: 164
                                radius: 16
                                color: Theme.surfaceContainerLow
                                border.color: mCardMouse.containsMouse ? Theme.primary : Theme.borderSubtle
                                border.width: 1

                                readonly property bool isInstalled: PluginManager.isPluginInstalled(modelData.id)
                                readonly property int pStatus: PluginManager.getPluginStatus(modelData.id)

                                MouseArea {
                                    id: mCardMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 18
                                    spacing: 16

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

                                            Rectangle {
                                                height: 18
                                                radius: 9
                                                width: mVerText.implicitWidth + 12
                                                color: Theme.surfaceContainerHighest
                                                Text {
                                                    id: mVerText
                                                    anchors.centerIn: parent
                                                    text: "v" + (modelData.version || "1.0.0")
                                                    font.pixelSize: 10
                                                    color: Theme.textSecondary
                                                }
                                            }

                                            Rectangle {
                                                height: 18
                                                radius: 9
                                                width: mCatChip.implicitWidth + 12
                                                color: Theme.primaryContainer
                                                Text {
                                                    id: mCatChip
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

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 12

                                            // Status pill
                                            Rectangle {
                                                height: 22
                                                radius: 11
                                                width: statusPillText.implicitWidth + 16
                                                color: isInstalled ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                                Text {
                                                    id: statusPillText
                                                    anchors.centerIn: parent
                                                    text: isInstalled ? qsTr("Installed") : qsTr("Available")
                                                    font.pixelSize: 11
                                                    color: isInstalled ? Theme.primary : Theme.textMuted
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            // Open button if already installed
                                            M3Button {
                                                visible: isInstalled
                                                text: qsTr("Open")
                                                variant: "tonal"
                                                implicitHeight: 30
                                                implicitWidth: 72
                                                onClicked: {
                                                    if (typeof window !== "undefined") {
                                                        window.currentTab = "plugin:" + modelData.id;
                                                    }
                                                }
                                            }

                                            // Install / Update button
                                            M3Button {
                                                text: isInstalled ? qsTr("Reinstall") : qsTr("Install")
                                                variant: "filled"
                                                implicitHeight: 30
                                                implicitWidth: 86
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

        // --------------------------------------------------------------------
        // 4. Tab Body 2: Installed Plugins View
        // --------------------------------------------------------------------
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.activeTab === "installed"

            // Empty state
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12
                visible: root.getInstalledList().length === 0

                SvgIcon {
                    Layout.alignment: Qt.AlignHCenter
                    width: 32
                    height: 32
                    source: "qrc:/assets/icons/plugin.svg"
                    color: Theme.iconNeutral
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: qsTr("No installed plugins matching query.")
                    font.pixelSize: 14
                    color: Theme.textMuted
                }
            }

            ScrollView {
                anchors.fill: parent
                clip: true
                visible: root.getInstalledList().length > 0

                ListView {
                    width: parent.width
                    spacing: 14
                    model: root.getInstalledList()

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: diagBox.visible ? 186 : 142
                        radius: 16
                        color: Theme.surfaceContainerLow
                        border.color: Theme.borderSubtle
                        border.width: 1

                        readonly property int pStatus: modelData.status !== undefined ? modelData.status : 0
                        readonly property bool hasDiag: (modelData.diagnosticDetails && modelData.diagnosticDetails.length > 0) || (modelData.statusText === "MissingDependency" || modelData.statusText === "RuntimeError")

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14

                                Rectangle {
                                    Layout.preferredWidth: 44
                                    Layout.preferredHeight: 44
                                    radius: 12
                                    color: Theme.surfaceContainerHigh

                                    SvgIcon {
                                        anchors.centerIn: parent
                                        width: 24
                                        height: 24
                                        source: modelData.icon || "qrc:/assets/icons/plugin.svg"
                                        color: Theme.primary
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Text {
                                            text: modelData.name || modelData.id
                                            font.pixelSize: 15
                                            font.bold: true
                                            color: Theme.textPrimary
                                        }

                                        Rectangle {
                                            height: 18
                                            radius: 9
                                            width: instVerText.implicitWidth + 10
                                            color: Theme.surfaceContainerHighest
                                            Text {
                                                id: instVerText
                                                anchors.centerIn: parent
                                                text: "v" + (modelData.version || "1.0.0")
                                                font.pixelSize: 10
                                                color: Theme.textSecondary
                                            }
                                        }

                                        // Status Pill Indicator
                                        Rectangle {
                                            height: 20
                                            radius: 10
                                            width: stStatusText.implicitWidth + 14
                                            color: {
                                                if (modelData.statusText === "MissingDependency") return Qt.rgba(1.0, 0.6, 0.0, 0.18);
                                                if (modelData.statusText === "RuntimeError") return Qt.rgba(1.0, 0.2, 0.2, 0.18);
                                                if (modelData.statusText === "UpdateAvailable") return Qt.rgba(0.2, 0.6, 1.0, 0.18);
                                                return Qt.rgba(0.2, 0.8, 0.4, 0.18);
                                            }
                                            Text {
                                                id: stStatusText
                                                anchors.centerIn: parent
                                                text: {
                                                    if (modelData.statusText === "MissingDependency") return qsTr("Incompatible");
                                                    if (modelData.statusText === "RuntimeError") return qsTr("Error");
                                                    if (modelData.statusText === "UpdateAvailable") return qsTr("Update Available");
                                                    return qsTr("Ready");
                                                }
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: {
                                                    if (modelData.statusText === "MissingDependency") return "#f59e0b";
                                                    if (modelData.statusText === "RuntimeError") return "#ef4444";
                                                    if (modelData.statusText === "UpdateAvailable") return "#3b82f6";
                                                    return "#10b981";
                                                }
                                            }
                                        }

                                        Item { Layout.fillWidth: true }
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.description || ""
                                        font.pixelSize: 11
                                        color: Theme.textSecondary
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }
                                }

                                // Open Workbench Button
                                M3Button {
                                    text: qsTr("Workbench")
                                    variant: "tonal"
                                    implicitHeight: 32
                                    implicitWidth: 80
                                    onClicked: {
                                        if (typeof window !== "undefined") {
                                            window.currentTab = "plugin:" + modelData.id;
                                        }
                                    }
                                }

                                // Enable/Disable Switch Toggle
                                M3Switch {
                                    checked: modelData.enabled
                                    onToggled: function(c) {
                                        PluginManager.setPluginEnabled(modelData.id, c);
                                    }
                                }

                                // Uninstall Button
                                M3IconButton {
                                    icon: "qrc:/assets/icons/trash.svg"
                                    size: 32
                                    iconSize: 14
                                    variant: "standard"
                                    onClicked: PluginManager.uninstallPlugin(modelData.id)
                                }
                            }

                            // Declared Permissions Chips Row
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    text: qsTr("Permissions:")
                                    font.pixelSize: 10
                                    color: Theme.textMuted
                                }

                                Repeater {
                                    model: (modelData.permissions && modelData.permissions.length > 0) ? modelData.permissions : ["none"]
                                    delegate: Rectangle {
                                        height: 16
                                        radius: 8
                                        width: permText.implicitWidth + 10
                                        color: Theme.surfaceContainerHighest
                                        Text {
                                            id: permText
                                            anchors.centerIn: parent
                                            text: modelData
                                            font.pixelSize: 9
                                            color: Theme.textSecondary
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }
                            }

                            // Diagnostic Panel (Visible when error or incompatible)
                            Rectangle {
                                id: diagBox
                                Layout.fillWidth: true
                                height: 36
                                radius: 8
                                visible: hasDiag
                                color: (modelData.statusText === "MissingDependency") ? Qt.rgba(1.0, 0.6, 0.0, 0.12) : Qt.rgba(1.0, 0.2, 0.2, 0.12)
                                border.color: (modelData.statusText === "MissingDependency") ? Qt.rgba(1.0, 0.6, 0.0, 0.3) : Qt.rgba(1.0, 0.2, 0.2, 0.3)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    SvgIcon {
                                        width: 14
                                        height: 14
                                        source: "qrc:/assets/icons/refresh.svg"
                                        color: (modelData.statusText === "MissingDependency") ? "#f59e0b" : "#ef4444"
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.diagnosticDetails || modelData.statusMessage || qsTr("Diagnostics warning reported.")
                                        font.pixelSize: 11
                                        color: (modelData.statusText === "MissingDependency") ? "#d97706" : "#dc2626"
                                        elide: Text.ElideRight
                                    }

                                    M3Button {
                                        text: qsTr("Retry")
                                        variant: "tonal"
                                        implicitHeight: 24
                                        implicitWidth: 58
                                        onClicked: PluginManager.retryPluginInstall(modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // --------------------------------------------------------------------
        // 5. Tab Body 3: Tasks (PluginTaskModel Bus)
        // --------------------------------------------------------------------
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.activeTab === "tasks"

            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                // Tasks Header Actions
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: qsTr("Background & Download Tasks (%1)").arg(PluginManager.taskModel.count)
                        font.pixelSize: 14
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 90
                        height: 30
                        radius: 15
                        color: clrM.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                        border.color: Theme.borderSubtle
                        visible: PluginManager.taskModel.count > 0

                        Text {
                            anchors.centerIn: parent
                            text: qsTr("Clear All")
                            font.pixelSize: 11
                            color: Theme.textSecondary
                        }
                        MouseArea {
                            id: clrM
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PluginManager.taskModel.clearTasks()
                        }
                    }

                    Rectangle {
                        width: 96
                        height: 30
                        radius: 15
                        color: cnlM.containsMouse ? Qt.rgba(1, 0.2, 0.2, 0.15) : Theme.surfaceContainerHigh
                        border.color: Theme.borderSubtle
                        visible: PluginManager.taskModel.activeCount > 0

                        Text {
                            anchors.centerIn: parent
                            text: qsTr("Cancel All")
                            font.pixelSize: 11
                            color: "#ef4444"
                        }
                        MouseArea {
                            id: cnlM
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PluginManager.taskModel.cancelAllTasks()
                        }
                    }
                }

                // Tasks ListView
                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    visible: PluginManager.taskModel.count > 0

                    ListView {
                        width: parent.width
                        spacing: 10
                        model: PluginManager.taskModel

                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 78
                            radius: 14
                            color: Theme.surfaceContainerLow
                            border.color: Theme.borderSubtle
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: model.title || model.id
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: Theme.textPrimary
                                    }

                                    Rectangle {
                                        height: 16
                                        radius: 8
                                        width: taskPid.implicitWidth + 8
                                        color: Theme.surfaceContainerHighest
                                        Text {
                                            id: taskPid
                                            anchors.centerIn: parent
                                            text: model.pluginId || ""
                                            font.pixelSize: 9
                                            color: Theme.textSecondary
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    // Status Pill
                                    M3Badge {
                                        text: model.status
                                        variant: {
                                            if (model.status === "completed") return "success";
                                            if (model.status === "failed") return "error";
                                            if (model.status === "running") return "primary";
                                            return "tonal";
                                        }
                                    }

                                    // Action buttons (Cancel / Retry)
                                    M3IconButton {
                                        visible: model.canCancel
                                        icon: "qrc:/assets/icons/trash.svg"
                                        size: 26
                                        iconSize: 12
                                        variant: "standard"
                                        onClicked: PluginManager.taskModel.cancelTask(model.id)
                                    }

                                    M3IconButton {
                                        visible: model.canRetry || model.status === "failed"
                                        icon: "qrc:/assets/icons/refresh.svg"
                                        size: 26
                                        iconSize: 12
                                        variant: "standard"
                                        onClicked: PluginManager.taskModel.retryTask(model.id)
                                    }
                                }

                                // Animated Progress Bar
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 5
                                    radius: 2.5
                                    color: Theme.surfaceContainerHighest

                                    Rectangle {
                                        height: parent.height
                                        radius: 2.5
                                        width: Math.max(0, parent.width * (model.progress / 100.0))
                                        color: model.status === "failed" ? "#ef4444" : Theme.primary
                                        Behavior on width { NumberAnimation { duration: 150 } }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        Layout.fillWidth: true
                                        text: model.errorMsg ? model.errorMsg : (model.sourcePath ? (model.sourcePath + " -> " + model.targetPath) : "")
                                        font.pixelSize: 10
                                        color: model.errorMsg ? "#ef4444" : Theme.textMuted
                                        elide: Text.ElideMiddle
                                    }
                                    Text {
                                        text: model.progress + "%"
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: Theme.textSecondary
                                    }
                                }
                            }
                        }
                    }
                }

                // Tasks Empty state
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12
                    visible: PluginManager.taskModel.count === 0

                    SvgIcon {
                        Layout.alignment: Qt.AlignHCenter
                        width: 32
                        height: 32
                        source: "qrc:/assets/icons/refresh.svg"
                        color: Theme.iconNeutral
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("No background tasks running.")
                        font.pixelSize: 14
                        color: Theme.textMuted
                    }
                }
            }
        }
    }

    // Toast Notification Banner
    Rectangle {
        id: toastBanner
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        anchors.horizontalCenter: parent.horizontalCenter
        height: 38
        width: Math.min(parent.width - 48, toastText.implicitWidth + 32)
        radius: 19
        color: Theme.surfaceContainerHighest
        border.color: Theme.primary
        border.width: 1
        visible: root.toastMessage.length > 0
        z: 9999

        Text {
            id: toastText
            anchors.centerIn: parent
            width: Math.min(parent.width - 64, implicitWidth)
            text: root.toastMessage
            font.pixelSize: 13
            font.bold: true
            color: Theme.textPrimary
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }
}
