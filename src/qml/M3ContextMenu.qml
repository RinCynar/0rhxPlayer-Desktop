import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import rhx.ui 1.0
import rhx.theme 1.0
import rhx.library 1.0
import rhx.plugin 1.0

Item {
    id: menuRoot
    anchors.fill: parent
    z: 14000
    visible: opacity > 0.0
    opacity: 0.0

    property var selectedTrackPaths: []
    property string singleTrackTitle: ""
    property string singleTrackArtist: ""
    property string contextType: "library" // "library", "queue", "playlist", "home"

    signal deleteRequested(var paths)

    function show(posX, posY, paths, title, artist, ctx) {
        if (!paths) paths = [];
        if (typeof paths === "string") paths = [paths];
        selectedTrackPaths = paths;
        singleTrackTitle = title || "";
        singleTrackArtist = artist || "";
        contextType = ctx || "library";

        // Bound within window dimensions
        var targetX = Math.max(10, Math.min(menuRoot.width - menuBox.width - 10, posX));
        var targetY = Math.max(10, Math.min(menuRoot.height - menuBox.height - 10, posY));

        menuBox.x = targetX;
        menuBox.y = targetY;
        menuRoot.opacity = 1.0;
    }

    function close() {
        menuRoot.opacity = 0.0;
    }

    Behavior on opacity {
        NumberAnimation { duration: 120 }
    }

    // Dismiss Backdrop
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: menuRoot.close()
    }

    // Subtle ChromeOS / M3 Ambient Elevation Shadow
    Rectangle {
        anchors.fill: menuBox
        anchors.topMargin: 2
        anchors.bottomMargin: -3
        anchors.leftMargin: -1
        anchors.rightMargin: -1
        radius: menuBox.radius + 1
        color: Qt.rgba(0, 0, 0, Theme.isDark ? 0.28 : 0.06)
        opacity: menuRoot.opacity
        visible: menuRoot.visible
        z: menuBox.z - 1
    }

    // Floating Menu Card (Solid ChromeOS / Material You Surface, Radius: 8px)
    Rectangle {
        id: menuBox
        width: 236
        height: menuCol.implicitHeight + 16
        radius: 8
        color: Theme.isDark ? Theme.surfaceContainer : Theme.surfaceContainerLowest
        border.width: 1
        border.color: Qt.rgba(Theme.outlineVariant.r, Theme.outlineVariant.g, Theme.outlineVariant.b, Theme.isDark ? 0.35 : 0.45)
        clip: true

        ColumnLayout {
            id: menuCol
            anchors.top: parent.top
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            spacing: 2

            // Menu Item 1: Insert to Queue
            M3MenuItem {
                iconSource: "qrc:/assets/icons/queue.svg"
                text: qsTr("Insert to Queue")
                onClicked: {
                    LibraryManager.insertTracksToQueue(menuRoot.selectedTrackPaths);
                    menuRoot.close();
                }
            }

            // Menu Item 2: Favorite (Add to Favorites)
            M3MenuItem {
                iconSource: "qrc:/assets/icons/heart_outline.svg"
                text: qsTr("Favorite")
                onClicked: {
                    LibraryManager.toggleFavorites(menuRoot.selectedTrackPaths);
                    menuRoot.close();
                }
            }

            // Menu Item 3: Add to Playlist
            M3MenuItem {
                iconSource: "qrc:/assets/icons/playlist_add.svg"
                text: qsTr("Add to Playlist...")
                onClicked: {
                    var paths = menuRoot.selectedTrackPaths;
                    menuRoot.close();
                    if (typeof playlistSelectDialog !== "undefined") {
                        playlistSelectDialog.openForTracks(paths);
                    }
                }
            }

            // Separator: 1px height, Theme.outlineVariant with 0.3 opacity, 8px indent, 6px vertical spacing
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 9
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    height: 1
                    color: Theme.outlineVariant
                    opacity: 0.3
                }
            }

            // Menu Item 4a: Remove from Playlist (when in playlist view)
            M3MenuItem {
                visible: menuRoot.contextType === "playlist"
                iconSource: "qrc:/assets/icons/trash.svg"
                text: qsTr("Remove from Playlist")
                isDestructive: true
                onClicked: {
                    var paths = menuRoot.selectedTrackPaths;
                    menuRoot.close();
                    LibraryManager.removeTracksFromPlaylist(LibraryManager.currentPlaylistId, paths);
                }
            }

            // Menu Item 4b: Delete / Remove from Library
            M3MenuItem {
                visible: menuRoot.contextType !== "playlist"
                iconSource: "qrc:/assets/icons/trash.svg"
                text: qsTr("Delete")
                isDestructive: true
                onClicked: {
                    var paths = menuRoot.selectedTrackPaths;
                    menuRoot.close();
                    menuRoot.deleteRequested(paths);
                }
            }

            // Separator: 1px height, Theme.outlineVariant with 0.3 opacity, 8px indent, 6px vertical spacing
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 9
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    height: 1
                    color: Theme.outlineVariant
                    opacity: 0.3
                }
            }

            // Menu Item 5: Track Details
            M3MenuItem {
                iconSource: "qrc:/assets/icons/info.svg"
                text: qsTr("Track Details")
                onClicked: {
                    var p = (menuRoot.selectedTrackPaths && menuRoot.selectedTrackPaths.length > 0) ? menuRoot.selectedTrackPaths[0] : "";
                    menuRoot.close();
                    if (p && typeof trackInfoDialog !== "undefined") {
                        trackInfoDialog.showTrack(p);
                    }
                }
            }

            // Menu Item 6: Show in File Explorer
            M3MenuItem {
                iconSource: "qrc:/assets/icons/folder_open.svg"
                text: qsTr("Open in File Explorer")
                onClicked: {
                    var p = (menuRoot.selectedTrackPaths && menuRoot.selectedTrackPaths.length > 0) ? menuRoot.selectedTrackPaths[0] : "";
                    menuRoot.close();
                    if (p) {
                        LibraryManager.showInExplorer(p);
                    }
                }
            }

            // Injected Context Menu Items from Active Plugins (Phase 17)
            Repeater {
                model: PluginManager.getInjectedMenuItems(menuRoot.contextType === "playlist" ? "playlist" : "track", {
                    paths: menuRoot.selectedTrackPaths,
                    title: menuRoot.singleTrackTitle,
                    artist: menuRoot.singleTrackArtist
                })
                delegate: M3MenuItem {
                    iconSource: modelData.icon || "qrc:/assets/icons/plugin.svg"
                    text: modelData.title
                    isDestructive: Boolean(modelData.isDestructive)
                    onClicked: {
                        var p = (menuRoot.selectedTrackPaths && menuRoot.selectedTrackPaths.length > 0) ? menuRoot.selectedTrackPaths[0] : "";
                        var payload = {
                            filePath: p,
                            path: p,
                            paths: menuRoot.selectedTrackPaths,
                            title: menuRoot.singleTrackTitle,
                            artist: menuRoot.singleTrackArtist,
                            data: {
                                filePath: p,
                                path: p,
                                paths: menuRoot.selectedTrackPaths,
                                title: menuRoot.singleTrackTitle,
                                artist: menuRoot.singleTrackArtist
                            }
                        };
                        PluginManager.triggerPluginAction(modelData.pluginId, modelData.id, menuRoot.contextType === "playlist" ? "playlist" : "track", payload);
                        menuRoot.close();
                    }
                }
            }
        }
    }
}
