import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import rhx.audio 1.0
import rhx.config 1.0
import rhx.theme 1.0
import rhx.library 1.0

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
    property bool isNowPlayingOpen: false
    property bool showTrans: true
    property var preNowPlayingNavCollapsed: null

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
                    StackLayout {
                        id: mainStackLayout
                        objectName: "mainStackLayout"
                        anchors.fill: parent
                        enabled: nowPlayingView.isFullyCollapsed
                        visible: !nowPlayingView.isFullyExpanded
                    currentIndex: {
                        switch (window.currentTab) {
                            case "home": return 0;
                            case "library": return 1;
                            case "search": return 2;
                            case "queue": return 3;
                            case "playlist": return 4;
                            case "eq": return 5;
                            case "settings": return 6;
                            default: return 0;
                        }
                    }

                    // 0: Home Page View (1:1 对齐原版设计)
                    HomeView {
                        id: homeView
                        objectName: "homeView"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        onNavigateTab: function(tabId) {
                            window.currentTab = tabId;
                        }
                        onNavigateToAlbum: function(albumName, artistName, coverUrl, trackCount) {
                            LibraryManager.filterTracksByAlbum(albumName, artistName);
                            libraryView.currentTab = "albums";
                            libraryView.openGroupDetails({
                                type: "album",
                                name: albumName,
                                subTitle: (artistName || "") + " • " + libraryView.formatCount(trackCount),
                                coverUrl: coverUrl || ""
                            });
                            window.currentTab = "library";
                        }
                    }

                    // 1: Library Page View
                    LibraryView {
                        id: libraryView
                        objectName: "libraryView"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    // 2: Search Page View
                    SearchView {
                        id: searchView
                        objectName: "searchView"
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        onNavigateToArtist: function(artistName, coverUrl) {
                            LibraryManager.filterTracksByArtist(artistName);
                            libraryView.currentTab = "artists";
                            libraryView.openGroupDetails({
                                type: "artist",
                                name: artistName,
                                subTitle: qsTr("Artist"),
                                coverUrl: coverUrl || ""
                            });
                            window.currentTab = "library";
                        }

                        onNavigateToAlbum: function(albumName, artistName, coverUrl) {
                            LibraryManager.filterTracksByAlbum(albumName, artistName);
                            libraryView.currentTab = "albums";
                            libraryView.openGroupDetails({
                                type: "album",
                                name: albumName,
                                subTitle: artistName,
                                coverUrl: coverUrl || ""
                            });
                            window.currentTab = "library";
                        }

                        onNavigateToLibraryTab: function(tabId) {
                            libraryView.selectedGroup = null;
                            libraryView.currentTab = (tabId === "titles" ? "tracks" : tabId);
                            window.currentTab = "library";
                        }
                    }

                    // 3: Queue Page View (Material 3 Parity)
                    QueueView {
                        id: queueView
                        objectName: "queueView"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        onNavigateToLibrary: {
                            window.currentTab = "library";
                        }
                    }

                    // 4: Playlist Page View (Phase 8 Parity)
                    PlaylistsView {
                        id: playlistsView
                        objectName: "playlistsView"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    // 5: Equalizer Page View (Phase 8 Parity)
                    EqualizerView {
                        id: equalizerView
                        objectName: "equalizerView"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    // 6: Modern Material You Settings Page View
                    SettingsView {
                        id: settingsView
                        objectName: "settingsView"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        onNavigateTab: function(tabId) {
                            window.currentTab = tabId;
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
}
