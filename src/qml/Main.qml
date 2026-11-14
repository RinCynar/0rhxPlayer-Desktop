import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import rhx.audio 1.0
import rhx.config 1.0
import rhx.theme 1.0
import rhx.library 1.0
import rhx.ui 1.0
import rhx.plugin 1.0

ApplicationWindow {
    id: window
    visible: true
    width: 1200
    height: 800
    minimumWidth: 840
    minimumHeight: 600
    title: "0rhxPlayer"
    color: Theme.surface
    flags: Qt.Window | Qt.FramelessWindowHint

    function toggleMaximize() {
        if (window.visibility === Window.Maximized) {
            window.showNormal();
        } else {
            window.showMaximized();
        }
    }

    onClosing: function(close) {
        if (ConfigManager.systemTray) {
            close.accepted = false;
            window.hide();
        }
    }

    property string currentTab: "home"
    property string activeTab: "home"
    property string exitingTab: ""
    property var viewSnapshots: ({})
    property bool keepAllViewsLoaded: false
    property var pendingLibraryAction: null

    function isTabActive(tabId) {
        if (keepAllViewsLoaded) return true;
        if (nowPlayingView && nowPlayingView.isFullyExpanded) return false;
        if (window.currentTab === tabId || window.exitingTab === tabId) return true;
        if (tabId === "pluginSchema" && ((window.currentTab.indexOf("plugin:") === 0) || (window.exitingTab.indexOf("plugin:") === 0))) {
            return true;
        }
        return false;
    }

    function getLoaderForTab(tabId) {
        if (!tabId) return null;
        if (tabId === "home") return homeLoader;
        if (tabId === "library") return libraryLoader;
        if (tabId === "search") return searchLoader;
        if (tabId === "queue") return queueLoader;
        if (tabId === "playlist") return playlistsLoader;
        if (tabId === "eq") return equalizerLoader;
        if (tabId === "settings") return settingsLoader;
        if (tabId === "plugins") return pluginsLoader;
        if (tabId.indexOf("plugin:") === 0 || tabId === "pluginSchema") return pluginSchemaLoader;
        return null;
    }

    function saveSnapshot(tabId) {
        var loader = getLoaderForTab(tabId);
        if (!loader || !loader.item) return;
        if (typeof loader.item.saveStateSnapshot === "function") {
            viewSnapshots[tabId] = loader.item.saveStateSnapshot();
        } else {
            var snap = {};
            if (loader.item.contentItem && loader.item.contentItem.contentY !== undefined) {
                snap.contentY = loader.item.contentItem.contentY;
            } else if (loader.item.contentY !== undefined) {
                snap.contentY = loader.item.contentY;
            }
            viewSnapshots[tabId] = snap;
        }
    }

    function restoreSnapshot(tabId) {
        var loader = getLoaderForTab(tabId);
        if (!loader || !loader.item) return;
        var snap = viewSnapshots[tabId];
        if (!snap) return;
        if (typeof loader.item.restoreStateSnapshot === "function") {
            loader.item.restoreStateSnapshot(snap);
        } else {
            if (loader.item.contentItem && snap.contentY !== undefined && snap.contentY > 0) {
                Qt.callLater(function() {
                    if (loader.item && loader.item.contentItem) {
                        loader.item.contentItem.contentY = snap.contentY;
                    }
                });
            } else if (snap.contentY !== undefined && snap.contentY > 0) {
                Qt.callLater(function() {
                    if (loader.item) {
                        loader.item.contentY = snap.contentY;
                    }
                });
            }
        }
    }

    function loadAllViews() {
        keepAllViewsLoaded = true;
    }

    function startTransitionAnimation(fromTab, toTab) {
        var outLoader = getLoaderForTab(fromTab);
        var inLoader = getLoaderForTab(toTab);

        if (!inLoader) {
            exitingTab = "";
            return;
        }

        if (!outLoader || fromTab === toTab || keepAllViewsLoaded) {
            inLoader.opacity = 1.0;
            inLoader.y = 0;
            inLoader.visible = true;
            exitingTab = "";
            return;
        }

        pageTransitionAnim.outTarget = outLoader;
        pageTransitionAnim.inTarget = inLoader;
        pageTransitionAnim.fromTab = fromTab;
        pageTransitionAnim.toTab = toTab;
        pageTransitionAnim.start();
    }

    ParallelAnimation {
        id: pageTransitionAnim
        property var outTarget: null
        property var inTarget: null
        property string fromTab: ""
        property string toTab: ""

        NumberAnimation {
            target: pageTransitionAnim.inTarget
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 200
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: pageTransitionAnim.inTarget
            property: "y"
            from: 14
            to: 0
            duration: 200
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: pageTransitionAnim.outTarget
            property: "opacity"
            from: 1.0
            to: 0.0
            duration: 180
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: pageTransitionAnim.outTarget
            property: "y"
            from: 0
            to: -14
            duration: 180
            easing.type: Easing.OutCubic
        }

        onStopped: {
            if (outTarget && !window.keepAllViewsLoaded) {
                outTarget.opacity = 1.0;
                outTarget.y = 0;
                outTarget.visible = false;
            }
            window.exitingTab = "";
            gc();
            if (typeof ConfigManager !== "undefined" && ConfigManager.trimMemory) {
                ConfigManager.trimMemory();
            }
        }
    }

    onCurrentTabChanged: {
        var newTab = window.currentTab;
        if (newTab === activeTab && exitingTab === "") return;

        var prevTab = activeTab;
        saveSnapshot(prevTab);

        if (pageTransitionAnim.running) {
            pageTransitionAnim.stop();
            if (exitingTab !== "") {
                var prevLoader = getLoaderForTab(exitingTab);
                if (prevLoader && !keepAllViewsLoaded) {
                    prevLoader.opacity = 1.0;
                    prevLoader.y = 0;
                    prevLoader.visible = false;
                }
            }
        }

        exitingTab = prevTab;
        activeTab = newTab;

        var inLoader = getLoaderForTab(newTab);
        if (!inLoader) {
            exitingTab = "";
            return;
        }

        inLoader.opacity = 0.0;
        inLoader.y = 14;
        inLoader.visible = true;

        if (keepAllViewsLoaded) {
            inLoader.opacity = 1.0;
            inLoader.y = 0;
            restoreSnapshot(newTab);
            exitingTab = "";
            return;
        }

        if (inLoader.status === Loader.Ready) {
            restoreSnapshot(newTab);
            startTransitionAnimation(prevTab, newTab);
        }
    }

    property bool isNowPlayingOpen: false
    property bool showTrans: true
    property var preNowPlayingNavCollapsed: null
    property alias toastBanner: globalToast

    readonly property bool isForegroundActive: window.visible && (window.visibility !== Window.Minimized) && (window.visibility !== Window.Hidden) && window.active
    onIsForegroundActiveChanged: {
        AudioEngine.windowActive = isForegroundActive;
    }
    Component.onCompleted: {
        AudioEngine.windowActive = isForegroundActive;
    }

    onIsNowPlayingOpenChanged: {
        if (isNowPlayingOpen) {
            viewContainer.frozenWidth = viewContainer.width;
            if (ConfigManager.autoCollapseRail) {
                preNowPlayingNavCollapsed = navRail.collapsed;
                if (!navRail.collapsed) {
                    navRail.collapsed = true;
                }
            }
        } else {
            var willExpandRail = (preNowPlayingNavCollapsed === false && ConfigManager.autoCollapseRail);
            viewContainer.frozenWidth = rootContainer.width - (willExpandRail ? 220 : navRail.width);
            if (preNowPlayingNavCollapsed !== null) {
                navRail.collapsed = preNowPlayingNavCollapsed;
                preNowPlayingNavCollapsed = null;
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: window.isNowPlayingOpen
        onActivated: {
            window.isNowPlayingOpen = false;
        }
    }

    Connections {
        target: ConfigManager
        function onNavItemsChanged() {
            var items = ConfigManager.visibleNavItems;
            var isCurrentVisible = false;
            for (var i = 0; i < items.length; ++i) {
                if (items[i].id === window.currentTab) {
                    isCurrentVisible = true;
                    break;
                }
            }
            if (!isCurrentVisible && window.currentTab !== "settings") {
                window.currentTab = "home";
            }
        }
    }

    // ------------------------------------------------------------------------
    // Root Layout: Seamless Flat M3 Container (0 radius on maximized/fullscreen)
    // ------------------------------------------------------------------------
    Rectangle {
        id: rootContainer
        anchors.fill: parent
        color: Theme.surface
        radius: (window.visibility === Window.Maximized || window.visibility === Window.FullScreen) ? 0 : 8
        clip: (window.visibility !== Window.Maximized && window.visibility !== Window.FullScreen)

        RowLayout {
            anchors.fill: parent
            spacing: 0

        // 1. Left Navigation Rail (绝对锁定尺寸，禁止参与横向拉伸分配)
        NavigationRail {
            id: navRail
            objectName: "navRail"
            Layout.fillWidth: false
            Layout.fillHeight: true
            Layout.minimumWidth: 72
            Layout.maximumWidth: 220
            Layout.preferredWidth: navRail.width
            activeTab: window.currentTab
            onTabSelected: function(tabId) {
                if (window.isNowPlayingOpen) {
                    window.isNowPlayingOpen = false;
                }
                window.currentTab = tabId;
            }
            onEditNavRequested: {
                navCustomDialog.isOpen = true;
            }
        }

        // 2. Right Workspace Area (Vertical split: Main Content Top, Player Bar Bottom)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Main Dynamic Page View Area
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // Dynamic Viewport Container (Zero-FBO Overlay Architecture & Occlusion Culling)
                Item {
                    id: viewContainer
                    objectName: "viewContainer"
                    property real frozenWidth: parent.width
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    width: nowPlayingView.isAnimating ? frozenWidth : parent.width
                    visible: !nowPlayingView.isFullyExpanded
                    enabled: nowPlayingView.isFullyCollapsed

                    // Background: 100% solid flat dark (no live blur, no gradient masks)
                    Rectangle {
                        anchors.fill: parent
                        color: Theme.surface
                    }

                    // Dynamic Router View Stack (Global Viewport Occlusion Culling & Throttling)
                    Item {
                        id: mainStackLayout
                        objectName: "mainStackLayout"
                        anchors.fill: parent
                        enabled: nowPlayingView.isFullyCollapsed
                        visible: !nowPlayingView.isFullyExpanded
                        clip: true

                    // 0: Home Page View (Lazy Loaded & Dynamically Recycled)
                    Loader {
                        id: homeLoader
                        objectName: "homeLoader"
                        anchors.fill: parent
                        active: window.isTabActive("home")
                        visible: active && opacity > 0
                        opacity: (window.currentTab === "home" && window.exitingTab === "") ? 1.0 : 0.0
                        sourceComponent: Component {
                            HomeView {
                                id: homeView
                                objectName: "homeView"
                                anchors.fill: parent
                                onNavigateTab: function(tabId) {
                                    window.currentTab = tabId;
                                }
                                onNavigateToAlbum: function(albumName, artistName, coverUrl, trackCount) {
                                    LibraryManager.filterTracksByAlbum(albumName, artistName);
                                    window.pendingLibraryAction = function(lib) {
                                        lib.currentTab = "albums";
                                        lib.openGroupDetails({
                                            type: "album",
                                            name: albumName,
                                            subTitle: (artistName || "") + " • " + (lib.formatCount ? lib.formatCount(trackCount) : trackCount),
                                            coverUrl: coverUrl || ""
                                        });
                                    };
                                    window.currentTab = "library";
                                    if (libraryLoader.item) {
                                        window.pendingLibraryAction(libraryLoader.item);
                                        window.pendingLibraryAction = null;
                                    }
                                }
                            }
                        }
                        onLoaded: {
                            if (window.currentTab === "home" && window.activeTab === "home") {
                                window.restoreSnapshot("home");
                                if (!window.keepAllViewsLoaded && !pageTransitionAnim.running) {
                                    window.startTransitionAnimation(window.exitingTab, "home");
                                }
                            }
                        }
                    }

                    // 1: Library Page View (Lazy Loaded & Dynamically Recycled)
                    Loader {
                        id: libraryLoader
                        objectName: "libraryLoader"
                        anchors.fill: parent
                        active: window.isTabActive("library")
                        visible: active && opacity > 0
                        opacity: (window.currentTab === "library" && window.exitingTab === "") ? 1.0 : 0.0
                        sourceComponent: Component {
                            LibraryView {
                                id: libraryView
                                objectName: "libraryView"
                                anchors.fill: parent
                            }
                        }
                        onLoaded: {
                            if (window.pendingLibraryAction && libraryLoader.item) {
                                var act = window.pendingLibraryAction;
                                window.pendingLibraryAction = null;
                                act(libraryLoader.item);
                            }
                            if (window.currentTab === "library" && window.activeTab === "library") {
                                window.restoreSnapshot("library");
                                if (!window.keepAllViewsLoaded && !pageTransitionAnim.running) {
                                    window.startTransitionAnimation(window.exitingTab, "library");
                                }
                            }
                        }
                    }

                    // 2: Search Page View (Lazy Loaded & Dynamically Recycled)
                    Loader {
                        id: searchLoader
                        objectName: "searchLoader"
                        anchors.fill: parent
                        active: window.isTabActive("search")
                        visible: active && opacity > 0
                        opacity: (window.currentTab === "search" && window.exitingTab === "") ? 1.0 : 0.0
                        sourceComponent: Component {
                            SearchView {
                                id: searchView
                                objectName: "searchView"
                                anchors.fill: parent
                                onNavigateToArtist: function(artistName, coverUrl) {
                                    LibraryManager.filterTracksByArtist(artistName);
                                    window.pendingLibraryAction = function(lib) {
                                        lib.currentTab = "artists";
                                        lib.openGroupDetails({
                                            type: "artist",
                                            name: artistName,
                                            subTitle: lib.formatCount ? lib.formatCount(LibraryManager.filteredTracks.count) : "",
                                            coverUrl: coverUrl || ""
                                        });
                                    };
                                    window.currentTab = "library";
                                    if (libraryLoader.item) {
                                        window.pendingLibraryAction(libraryLoader.item);
                                        window.pendingLibraryAction = null;
                                    }
                                }
                                onNavigateToAlbum: function(albumName, artistName, coverUrl) {
                                    LibraryManager.filterTracksByAlbum(albumName, artistName);
                                    window.pendingLibraryAction = function(lib) {
                                        lib.currentTab = "albums";
                                        lib.openGroupDetails({
                                            type: "album",
                                            name: albumName,
                                            subTitle: (artistName || "") + " • " + (lib.formatCount ? lib.formatCount(LibraryManager.filteredTracks.count) : ""),
                                            coverUrl: coverUrl || ""
                                        });
                                    };
                                    window.currentTab = "library";
                                    if (libraryLoader.item) {
                                        window.pendingLibraryAction(libraryLoader.item);
                                        window.pendingLibraryAction = null;
                                    }
                                }
                                onNavigateToLibraryTab: function(tabId) {
                                    window.pendingLibraryAction = function(lib) {
                                        lib.selectedGroup = null;
                                        lib.currentTab = (tabId === "titles" ? "tracks" : tabId);
                                    };
                                    window.currentTab = "library";
                                    if (libraryLoader.item) {
                                        window.pendingLibraryAction(libraryLoader.item);
                                        window.pendingLibraryAction = null;
                                    }
                                }
                            }
                        }
                        onLoaded: {
                            if (window.currentTab === "search" && window.activeTab === "search") {
                                window.restoreSnapshot("search");
                                if (!window.keepAllViewsLoaded && !pageTransitionAnim.running) {
                                    window.startTransitionAnimation(window.exitingTab, "search");
                                }
                            }
                        }
                    }

                    // 3: Queue Page View (Lazy Loaded & Dynamically Recycled)
                    Loader {
                        id: queueLoader
                        objectName: "queueLoader"
                        anchors.fill: parent
                        active: window.isTabActive("queue")
                        visible: active && opacity > 0
                        opacity: (window.currentTab === "queue" && window.exitingTab === "") ? 1.0 : 0.0
                        sourceComponent: Component {
                            QueueView {
                                id: queueView
                                objectName: "queueView"
                                anchors.fill: parent
                                onNavigateToLibrary: {
                                    window.currentTab = "library";
                                }
                            }
                        }
                        onLoaded: {
                            if (window.currentTab === "queue" && window.activeTab === "queue") {
                                window.restoreSnapshot("queue");
                                if (!window.keepAllViewsLoaded && !pageTransitionAnim.running) {
                                    window.startTransitionAnimation(window.exitingTab, "queue");
                                }
                            }
                        }
                    }

                    // 4: Playlist Page View (Lazy Loaded & Dynamically Recycled)
                    Loader {
                        id: playlistsLoader
                        objectName: "playlistsLoader"
                        anchors.fill: parent
                        active: window.isTabActive("playlist")
                        visible: active && opacity > 0
                        opacity: (window.currentTab === "playlist" && window.exitingTab === "") ? 1.0 : 0.0
                        sourceComponent: Component {
                            PlaylistsView {
                                id: playlistsView
                                objectName: "playlistsView"
                                anchors.fill: parent
                            }
                        }
                        onLoaded: {
                            if (window.currentTab === "playlist" && window.activeTab === "playlist") {
                                window.restoreSnapshot("playlist");
                                if (!window.keepAllViewsLoaded && !pageTransitionAnim.running) {
                                    window.startTransitionAnimation(window.exitingTab, "playlist");
                                }
                            }
                        }
                    }

                    // 5: Equalizer Page View (Lazy Loaded & Dynamically Recycled)
                    Loader {
                        id: equalizerLoader
                        objectName: "equalizerLoader"
                        anchors.fill: parent
                        active: window.isTabActive("eq")
                        visible: active && opacity > 0
                        opacity: (window.currentTab === "eq" && window.exitingTab === "") ? 1.0 : 0.0
                        sourceComponent: Component {
                            EqualizerView {
                                id: equalizerView
                                objectName: "equalizerView"
                                anchors.fill: parent
                            }
                        }
                        onLoaded: {
                            if (window.currentTab === "eq" && window.activeTab === "eq") {
                                window.restoreSnapshot("eq");
                                if (!window.keepAllViewsLoaded && !pageTransitionAnim.running) {
                                    window.startTransitionAnimation(window.exitingTab, "eq");
                                }
                            }
                        }
                    }

                    // 6: Modern Material You Settings Page View (Lazy Loaded & Dynamically Recycled)
                    Loader {
                        id: settingsLoader
                        objectName: "settingsLoader"
                        anchors.fill: parent
                        active: window.isTabActive("settings")
                        visible: active && opacity > 0
                        opacity: (window.currentTab === "settings" && window.exitingTab === "") ? 1.0 : 0.0
                        sourceComponent: Component {
                            SettingsView {
                                id: settingsView
                                objectName: "settingsView"
                                anchors.fill: parent
                                onNavigateTab: function(tabId) {
                                    window.currentTab = tabId;
                                }
                            }
                        }
                        onLoaded: {
                            if (window.currentTab === "settings" && window.activeTab === "settings") {
                                window.restoreSnapshot("settings");
                                if (!window.keepAllViewsLoaded && !pageTransitionAnim.running) {
                                    window.startTransitionAnimation(window.exitingTab, "settings");
                                }
                            }
                        }
                    }

                    // 7: Plugins Marketplace & Local Extension View (Lazy Loaded & Dynamically Recycled)
                    Loader {
                        id: pluginsLoader
                        objectName: "pluginsLoader"
                        anchors.fill: parent
                        active: window.isTabActive("plugins")
                        visible: active && opacity > 0
                        opacity: (window.currentTab === "plugins" && window.exitingTab === "") ? 1.0 : 0.0
                        sourceComponent: Component {
                            PluginsView {
                                id: pluginsView
                                objectName: "pluginsView"
                                anchors.fill: parent
                                onNavigateTab: function(tabId) {
                                    window.currentTab = tabId;
                                }
                            }
                        }
                        onLoaded: {
                            if (window.currentTab === "plugins" && window.activeTab === "plugins") {
                                window.restoreSnapshot("plugins");
                                if (!window.keepAllViewsLoaded && !pageTransitionAnim.running) {
                                    window.startTransitionAnimation(window.exitingTab, "plugins");
                                }
                            }
                        }
                    }

                    // 8: Dynamic Native M3 Schema View for Plugins (Lazy Loaded & Dynamically Recycled)
                    Loader {
                        id: pluginSchemaLoader
                        objectName: "pluginSchemaLoader"
                        anchors.fill: parent
                        active: window.isTabActive("pluginSchema")
                        visible: active && opacity > 0
                        opacity: ((window.currentTab.indexOf("plugin:") === 0) && window.exitingTab === "") ? 1.0 : 0.0
                        sourceComponent: Component {
                            PluginSchemaView {
                                id: pluginSchemaView
                                objectName: "pluginSchemaView"
                                anchors.fill: parent
                                pluginId: window.currentTab
                            }
                        }
                        onLoaded: {
                            if (window.currentTab.indexOf("plugin:") === 0 && window.activeTab.indexOf("plugin:") === 0) {
                                window.restoreSnapshot("pluginSchema");
                                if (!window.keepAllViewsLoaded && !pageTransitionAnim.running) {
                                    window.startTransitionAnimation(window.exitingTab, "pluginSchema");
                                }
                            }
                        }
                    }
                }
                }

                // Global Singleton NowPlaying Overlay (Above main content, strictly within right workspace)
                NowPlayingView {
                    id: nowPlayingView
                    objectName: "nowPlayingView"
                    z: 100
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: parent.height
                    isOpen: window.isNowPlayingOpen
                    showTrans: window.showTrans
                    onCloseRequested: {
                        window.isNowPlayingOpen = false;
                    }
                }

                Connections {
                    target: nowPlayingView
                    function onIsFullyExpandedChanged() {
                        if (nowPlayingView.isFullyExpanded) {
                            window.saveSnapshot(window.currentTab);
                            gc();
                            if (typeof ConfigManager !== "undefined" && ConfigManager.trimMemory) {
                                ConfigManager.trimMemory();
                            }
                        }
                    }
                    function onIsOpenChanged() {
                        if (!nowPlayingView.isOpen) {
                            var curLoader = window.getLoaderForTab(window.currentTab);
                            if (curLoader) {
                                curLoader.opacity = 1.0;
                                curLoader.y = 0;
                                curLoader.visible = true;
                            }
                        }
                    }
                    function onIsFullyCollapsedChanged() {
                        if (nowPlayingView.isFullyCollapsed) {
                            window.restoreSnapshot(window.currentTab);
                            gc();
                            if (typeof ConfigManager !== "undefined" && ConfigManager.trimMemory) {
                                ConfigManager.trimMemory();
                            }
                        }
                    }
                }
            }

            // Bottom Player Control Bar (Strictly confined to right section)
            BottomPlayerBar {
                id: bottomBar
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                isNowPlayingOpen: window.isNowPlayingOpen
                showTrans: window.showTrans
                onToggleShowTransRequested: {
                    window.showTrans = !window.showTrans;
                }
                onToggleNowPlayingRequested: {
                    window.isNowPlayingOpen = !window.isNowPlayingOpen;
                }
                onQueueRequested: {
                    window.currentTab = "queue";
                    window.isNowPlayingOpen = false;
                }
                onAddToPlaylistRequested: function(trackPath) {
                    if (trackPath && trackPath.length > 0) {
                        playlistSelectDialog.openForTracks([trackPath]);
                    }
                }
            }
        }
    }
    }

    // Modal Custom Navigation Dialog (Phase 1.5)
    NavCustomDialog {
        id: navCustomDialog
        objectName: "navCustomDialog"
    }

    // Modal Track Details Dialog (Phase 9)
    TrackInfoDialog {
        id: trackInfoDialog
        objectName: "trackInfoDialog"
    }

    // Modal Add-to-Playlist Dialog (Phase 9)
    PlaylistSelectDialog {
        id: playlistSelectDialog
        objectName: "playlistSelectDialog"
    }

    // Global Desktop Right-Click Context Menu (Phase 9)
    M3ContextMenu {
        id: m3ContextMenu
        objectName: "m3ContextMenu"
        onDeleteRequested: function(paths) {
            if (m3ContextMenu.contextType === "queue") {
                for (var k = 0; k < paths.length; ++k) {
                    var pl = AudioEngine.playlist;
                    var idx = pl ? pl.indexOf(paths[k]) : -1;
                    if (idx !== -1) {
                        AudioEngine.removeFromQueue(idx);
                    }
                }
            } else if (window.currentTab === "playlist" && LibraryManager.currentPlaylistId.length > 0) {
                LibraryManager.removeTracksFromPlaylist(LibraryManager.currentPlaylistId, paths);
            } else {
                LibraryManager.removeTracksFromLibrary(paths);
            }
        }
    }

    // Android-style Centered Splash Transition Screen (Phase 9)
    SplashScreen {
        id: splashScreen
        objectName: "splashScreen"
    }

    // Custom Frameless Titlebar with Drag Area & Window Controls (Minimize, Maximize, Close)
    CustomTitleBar {
        id: customTitleBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
    }

    // Border and Corner Mouse Resize Handlers (Frameless window support)
    WindowResizeHandler {
        id: resizeHandler
    }

    // Static Window-level Seed Color Indicator (8x8, physically anchored at top-left x: 16, y: 16)
    Rectangle {
        id: seedIndicator
        x: 16
        y: 16
        width: 8
        height: 8
        radius: 4
        color: Theme.primary
        z: 10001
    }

    // Global Floating Toast Notification Banner (Host & Plugins)
    Rectangle {
        id: globalToast
        z: 99999
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 96
        implicitWidth: toastRow.implicitWidth + 36
        implicitHeight: 40
        radius: 20
        color: Theme.colorOnSurface
        opacity: toastTimer.running ? 0.95 : 0.0
        scale: toastTimer.running ? 1.0 : 0.88
        visible: opacity > 0.0

        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        RowLayout {
            id: toastRow
            anchors.centerIn: parent
            spacing: 8

            SvgIcon {
                width: 16
                height: 16
                source: "qrc:/assets/icons/info.svg"
                color: Theme.surface
            }

            Text {
                id: toastText
                font.pixelSize: 13
                font.bold: true
                color: Theme.surface
            }
        }

        Timer {
            id: toastTimer
            interval: 3200
            repeat: false
        }

        function show(msg) {
            toastText.text = msg || "";
            toastTimer.restart();
        }
    }

    Connections {
        target: PluginManager
        function onToastRequested(message) {
            globalToast.show(message);
        }
    }
}
