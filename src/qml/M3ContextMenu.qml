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

    readonly property bool isTrackFavorite: {
        var dummy = LibraryManager.favoriteCount;
        if (!selectedTrackPaths || selectedTrackPaths.length === 0) return false;
        for (var i = 0; i < selectedTrackPaths.length; i++) {
            if (!LibraryManager.isFavorite(selectedTrackPaths[i])) return false;
        }
        return true;
    }

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

    // Soft Diffuse M3 Elevation Shadow (blur: 16px, offset: 4px, Theme.shadow at 0.12 opacity)
    Item {
        anchors.fill: menuBox
        z: menuBox.z - 1
        visible: menuRoot.visible
        opacity: menuRoot.opacity

        // Outer soft ambient layer (spread ~6px, offset 4px)
        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -6
            anchors.rightMargin: -6
            anchors.topMargin: -2
            anchors.bottomMargin: -10
            radius: menuBox.radius + 6
            color: Qt.rgba(Theme.shadow.r, Theme.shadow.g, Theme.shadow.b, 0.03)
        }
        // Mid diffusion layer (spread ~4px, offset 3px)
        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -4
            anchors.rightMargin: -4
            anchors.topMargin: -1
            anchors.bottomMargin: -7
            radius: menuBox.radius + 4
            color: Qt.rgba(Theme.shadow.r, Theme.shadow.g, Theme.shadow.b, 0.04)
        }
        // Inner key directional layer (spread ~2px, offset 2px)
        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -2
            anchors.rightMargin: -2
            anchors.topMargin: 0
            anchors.bottomMargin: -4
            radius: menuBox.radius + 2
            color: Qt.rgba(Theme.shadow.r, Theme.shadow.g, Theme.shadow.b, 0.05)
        }
    }

    // Floating Menu Card (Harmonious Material You Surface Container, Radius: 8px)
    Rectangle {
        id: menuBox
        width: 236
        height: menuCol.implicitHeight + 16
        radius: 8
        color: Theme.surfaceContainer
        border.width: 1
        border.color: Qt.rgba(Theme.outlineVariant.r, Theme.outlineVariant.g, Theme.outlineVariant.b, 0.18)
        clip: true

        ColumnLayout {
            id: menuCol
            anchors.top: parent.top
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 0
            anchors.rightMargin: 0
            spacing: 2

            // Group 1: Playback & Playlist Management
            // Item 1: Insert to Queue
            M3MenuItem {
                iconSource: "qrc:/assets/icons/queue.svg"
                text: qsTr("Insert to Queue")
                onClicked: {
                    LibraryManager.insertTracksToQueue(menuRoot.selectedTrackPaths);
                    menuRoot.close();
                }
            }

            // Item 2: Favorite / Unfavorite (Dynamic Favorite State)
            M3MenuItem {
                property bool isFav: menuRoot.isTrackFavorite
                iconSource: isFav ? "qrc:/assets/icons/heart_filled.svg" : "qrc:/assets/icons/heart_outline.svg"
                iconColor: isFav ? (Theme.isDark ? "#EF4444" : Theme.error) : "transparent"
                hoverIconColor: isFav ? (Theme.isDark ? "#EF4444" : Theme.error) : "transparent"
                text: isFav ? qsTr("Unfavorite") : qsTr("Favorite")
                onClicked: {
                    LibraryManager.toggleFavorites(menuRoot.selectedTrackPaths);
                    menuRoot.close();
                }
            }

            // Item 3: Add to Playlist
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

            // Single Middle Separator: 1px height, Theme.outlineVariant at 0.15 opacity, 12px horizontal inset
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 13
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    height: 1
                    color: Theme.outlineVariant
                    opacity: 0.15
                }
            }

            // Group 2: Metadata, File Operations & Actions
            // Item 4: Track Details
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

            // Item 5: Show in File Explorer
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

            // Destructive Action: Naturally Anchored at Bottom (Item 6a: Remove from Playlist)
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

            // Destructive Action: Naturally Anchored at Bottom (Item 6b: Delete / Remove from Library)
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
        }
    }
}
