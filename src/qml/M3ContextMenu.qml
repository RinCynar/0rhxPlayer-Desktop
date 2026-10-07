import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import rhx.ui 1.0
import rhx.theme 1.0
import rhx.library 1.0

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

    // Floating Menu Card
    Rectangle {
        id: menuBox
        width: 220
        height: menuCol.implicitHeight + 16
        radius: 12
        color: Theme.surfaceContainerHighest
        border.width: 1
        border.color: Theme.borderSubtle
        clip: true

        // Drop shadow feel via subtle outline
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: Theme.borderSubtle
        }

        ColumnLayout {
            id: menuCol
            anchors.top: parent.top
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 2

            // Menu Item 1: Insert to Queue
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                color: item1Mouse.containsMouse ? Theme.surfaceContainerLow : "transparent"
                radius: 6

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    SvgIcon {
                        width: 15
                        height: 15
                        source: "qrc:/assets/icons/queue.svg"
                        color: Theme.primary
                    }

                    Text {
                        text: qsTr("Insert to Queue")
                        font.pixelSize: 12
                        font.bold: true
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }
                }

                MouseArea {
                    id: item1Mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        LibraryManager.insertTracksToQueue(menuRoot.selectedTrackPaths);
                        menuRoot.close();
                    }
                }
            }

            // Menu Item 2: Favorite (Add to Favorites)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                color: item2Mouse.containsMouse ? Theme.surfaceContainerLow : "transparent"
                radius: 6

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    SvgIcon {
                        width: 15
                        height: 15
                        source: "qrc:/assets/icons/heart.svg"
                        color: "#EF4444"
                    }

                    Text {
                        text: qsTr("Favorite")
                        font.pixelSize: 12
                        font.bold: true
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }
                }

                MouseArea {
                    id: item2Mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        LibraryManager.toggleFavorites(menuRoot.selectedTrackPaths);
                        menuRoot.close();
                    }
                }
            }

            // Menu Item 3: Add to Playlist
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                color: item3Mouse.containsMouse ? Theme.surfaceContainerLow : "transparent"
                radius: 6

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    SvgIcon {
                        width: 15
                        height: 15
                        source: "qrc:/assets/icons/playlist.svg"
                        color: Theme.textPrimary
                    }

                    Text {
                        text: qsTr("Add to Playlist...")
                        font.pixelSize: 12
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }
                }

                MouseArea {
                    id: item3Mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var paths = menuRoot.selectedTrackPaths;
                        menuRoot.close();
                        if (typeof playlistSelectDialog !== "undefined") {
                            playlistSelectDialog.openForTracks(paths);
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                height: 1
                color: Theme.borderSubtle
            }

            // Menu Item 4a: Remove from Playlist (when in playlist view)
            Rectangle {
                visible: menuRoot.contextType === "playlist"
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                color: itemPlRemoveMouse.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.15) : "transparent"
                radius: 6

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    SvgIcon {
                        width: 14
                        height: 14
                        source: "qrc:/assets/icons/trash.svg"
                        color: itemPlRemoveMouse.containsMouse ? "#EF4444" : Theme.textMuted
                    }

                    Text {
                        text: qsTr("Remove from Playlist")
                        font.pixelSize: 12
                        color: itemPlRemoveMouse.containsMouse ? "#EF4444" : Theme.textPrimary
                        Layout.fillWidth: true
                    }
                }

                MouseArea {
                    id: itemPlRemoveMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var paths = menuRoot.selectedTrackPaths;
                        menuRoot.close();
                        LibraryManager.removeTracksFromPlaylist(LibraryManager.currentPlaylistId, paths);
                    }
                }
            }

            // Menu Item 4b: Delete / Remove from Library
            Rectangle {
                visible: menuRoot.contextType !== "playlist"
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                color: item4Mouse.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.15) : "transparent"
                radius: 6

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    SvgIcon {
                        width: 14
                        height: 14
                        source: "qrc:/assets/icons/trash.svg"
                        color: item4Mouse.containsMouse ? "#EF4444" : Theme.textMuted
                    }

                    Text {
                        text: qsTr("Delete")
                        font.pixelSize: 12
                        color: item4Mouse.containsMouse ? "#EF4444" : Theme.textPrimary
                        Layout.fillWidth: true
                    }
                }

                MouseArea {
                    id: item4Mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var paths = menuRoot.selectedTrackPaths;
                        menuRoot.close();
                        menuRoot.deleteRequested(paths);
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                height: 1
                color: Theme.borderSubtle
            }

            // Menu Item 5: Track Details
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                color: item5Mouse.containsMouse ? Theme.surfaceContainerLow : "transparent"
                radius: 6

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    SvgIcon {
                        width: 14
                        height: 14
                        source: "qrc:/assets/icons/info.svg"
                        color: Theme.textMuted
                    }

                    Text {
                        text: qsTr("Track Details")
                        font.pixelSize: 12
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }
                }

                MouseArea {
                    id: item5Mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var p = (menuRoot.selectedTrackPaths && menuRoot.selectedTrackPaths.length > 0) ? menuRoot.selectedTrackPaths[0] : "";
                        menuRoot.close();
                        if (p && typeof trackInfoDialog !== "undefined") {
                            trackInfoDialog.showTrack(p);
                        }
                    }
                }
            }

            // Menu Item 6: Show in File Explorer
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                color: item6Mouse.containsMouse ? Theme.surfaceContainerLow : "transparent"
                radius: 6

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    SvgIcon {
                        width: 14
                        height: 14
                        source: "qrc:/assets/icons/folder_open.svg"
                        color: Theme.textMuted
                    }

                    Text {
                        text: qsTr("Open in File Explorer")
                        font.pixelSize: 12
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }
                }

                MouseArea {
                    id: item6Mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var p = (menuRoot.selectedTrackPaths && menuRoot.selectedTrackPaths.length > 0) ? menuRoot.selectedTrackPaths[0] : "";
                        menuRoot.close();
                        if (p) {
                            LibraryManager.showInExplorer(p);
                        }
                    }
                }
            }
        }
    }
}
