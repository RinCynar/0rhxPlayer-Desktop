import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import rhx.ui 1.0
import rhx.theme 1.0
import rhx.library 1.0

Item {
    id: plSelectRoot
    anchors.fill: parent
    z: 16000
    visible: opacity > 0.0
    opacity: 0.0

    property var targetTrackPaths: []
    property bool isCreatingNew: false

    function openForTracks(paths) {
        if (!paths) paths = [];
        if (typeof paths === "string") {
            paths = [paths];
        }
        targetTrackPaths = paths;
        isCreatingNew = false;
        if (newPlField) newPlField.text = "";
        plSelectRoot.opacity = 1.0;
    }

    function close() {
        isCreatingNew = false;
        plSelectRoot.opacity = 0.0;
    }

    Behavior on opacity {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    // Backdrop
    Rectangle {
        anchors.fill: parent
        color: "#99000000"

        MouseArea {
            anchors.fill: parent
            onClicked: plSelectRoot.close()
        }
    }

    // Modal Card
    Rectangle {
        id: card
        width: Math.min(420, parent.width - 48)
        height: Math.min(480, parent.height - 48)
        anchors.centerIn: parent
        radius: 16
        color: Theme.surfaceContainer
        border.width: 1
        border.color: Theme.borderSubtle

        MouseArea {
            anchors.fill: parent
            // Prevent backdrop click through
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                SvgIcon {
                    width: 20
                    height: 20
                    source: "qrc:/assets/icons/playlist.svg"
                    color: Theme.primary
                }

                Text {
                    text: qsTr("Add to Playlist")
                    font.pixelSize: 18
                    font.bold: true
                    color: Theme.textPrimary
                    Layout.fillWidth: true
                }

                // Close Button
                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: closeMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                    SvgIcon {
                        anchors.centerIn: parent
                        width: 13
                        height: 13
                        source: "qrc:/assets/icons/win_close.svg"
                        color: Theme.textMuted
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: plSelectRoot.close()
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.borderSubtle
            }

            // 1. PINNED FAVORITES ROW (Top item, unconditionally pinned!)
            Rectangle {
                Layout.fillWidth: true
                height: 48
                radius: 10
                color: favRowMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                border.width: 1
                border.color: Theme.borderSubtle

                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    // Heart gradient thumbnail
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 8
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#EF4444" }
                            GradientStop { position: 1.0; color: "#EC4899" }
                        }

                        SvgIcon {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            source: "qrc:/assets/icons/heart.svg"
                            color: "#FFFFFF"
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: qsTr("Favorites")
                            font.pixelSize: 13
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Text {
                            text: qsTr("System Playlist")
                            font.pixelSize: 10
                            color: Theme.textMuted
                        }
                    }

                    SvgIcon {
                        width: 14
                        height: 14
                        source: "qrc:/assets/icons/chevron_right.svg"
                        color: Theme.textMuted
                    }
                }

                MouseArea {
                    id: favRowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        LibraryManager.addTracksToPlaylist("__favorites__", plSelectRoot.targetTrackPaths);
                        plSelectRoot.close();
                    }
                }
            }

            // Custom Playlists Header (Clean section title)
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: qsTr("Custom Playlists")
                    font.pixelSize: 11
                    font.bold: true
                    color: Theme.textMuted
                    Layout.fillWidth: true
                }
            }

            // User Playlists List
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: plListCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: plListCol
                    width: parent.width
                    spacing: 8

                    // 1. Collapsed state: "+ Create New Playlist" action card
                    Rectangle {
                        Layout.fillWidth: true
                        height: 44
                        radius: 10
                        visible: !plSelectRoot.isCreatingNew
                        color: addPlRowMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                        border.width: 1
                        border.color: addPlRowMouse.containsMouse ? Theme.primary : Theme.borderSubtle

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Rectangle {
                                width: 28
                                height: 28
                                radius: 6
                                color: Theme.primaryContainer

                                SvgIcon {
                                    anchors.centerIn: parent
                                    width: 14
                                    height: 14
                                    source: "qrc:/assets/icons/plus.svg"
                                    color: Theme.primary
                                }
                            }

                            Text {
                                text: qsTr("Create New Playlist")
                                font.pixelSize: 13
                                font.bold: true
                                color: Theme.primary
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: addPlRowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                plSelectRoot.isCreatingNew = true;
                                newPlField.forceActiveFocus();
                            }
                        }
                    }

                    // 2. Expanded state: Dedicated Spacious M3 Creation Form
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: createFormCol.implicitHeight + 20
                        radius: 12
                        visible: plSelectRoot.isCreatingNew
                        color: Theme.surfaceContainerHigh
                        border.width: 1.5
                        border.color: Theme.primary

                        ColumnLayout {
                            id: createFormCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            // Input Box with clear border and background
                            Rectangle {
                                Layout.fillWidth: true
                                height: 38
                                radius: 8
                                color: Theme.surfaceContainerHighest
                                border.width: 1
                                border.color: newPlField.activeFocus ? Theme.primary : Theme.borderSubtle

                                TextField {
                                    id: newPlField
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    placeholderText: qsTr("Enter playlist name...")
                                    font.pixelSize: 13
                                    color: Theme.textPrimary
                                    placeholderTextColor: Theme.textMuted
                                    background: null
                                    selectByMouse: true
                                    onAccepted: confirmCreateBtn.createAndAdd()
                                    Keys.onEscapePressed: {
                                        newPlField.text = "";
                                        plSelectRoot.isCreatingNew = false;
                                    }
                                }
                            }

                            // Actions Row: Cancel & Create
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Item { Layout.fillWidth: true }

                                // Cancel Button
                                Rectangle {
                                    implicitWidth: cancelText.implicitWidth + 20
                                    implicitHeight: 28
                                    radius: 14
                                    color: cancelPlMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                                    Text {
                                        id: cancelText
                                        anchors.centerIn: parent
                                        text: qsTr("Cancel")
                                        font.pixelSize: 12
                                        color: Theme.textMuted
                                    }

                                    MouseArea {
                                        id: cancelPlMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            newPlField.text = "";
                                            plSelectRoot.isCreatingNew = false;
                                        }
                                    }
                                }

                                // Confirm Create & Add Button
                                Rectangle {
                                    id: confirmCreateBtn
                                    implicitWidth: confirmText.implicitWidth + 24
                                    implicitHeight: 28
                                    radius: 14
                                    color: confirmMouse.containsMouse ? Qt.lighter(Theme.primary, 1.1) : Theme.primary
                                    scale: confirmMouse.pressed ? 0.95 : 1.0

                                    function createAndAdd() {
                                        var name = newPlField.text.trim();
                                        if (name.length > 0) {
                                            LibraryManager.createPlaylistWithTracks(name, plSelectRoot.targetTrackPaths);
                                            newPlField.text = "";
                                            plSelectRoot.isCreatingNew = false;
                                            plSelectRoot.close();
                                        }
                                    }

                                    Text {
                                        id: confirmText
                                        anchors.centerIn: parent
                                        text: qsTr("Create & Add")
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: Theme.colorOnPrimary
                                    }

                                    MouseArea {
                                        id: confirmMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: confirmCreateBtn.createAndAdd()
                                    }
                                }
                            }
                        }
                    }

                    Repeater {
                        model: LibraryManager.playlists

                        Rectangle {
                            Layout.fillWidth: true
                            height: 44
                            radius: 8
                            color: plItemMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                            Behavior on color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 6
                                    color: Theme.surfaceContainerHighest
                                    clip: true

                                    RoundedImage {
                                        anchors.fill: parent
                                        radius: 6
                                        source: model.coverUrl || ""
                                        fallbackIcon: "qrc:/assets/icons/disc.svg"
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: model.name
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: (model.trackCount || 0) + " " + qsTr("tracks")
                                    font.pixelSize: 11
                                    color: Theme.textMuted
                                }
                            }

                            MouseArea {
                                id: plItemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    LibraryManager.addTracksToPlaylist(model.id, plSelectRoot.targetTrackPaths);
                                    plSelectRoot.close();
                                }
                            }
                        }
                    }

                    // Empty state if no custom playlists
                    Item {
                        Layout.fillWidth: true
                        height: 50
                        visible: LibraryManager.playlists ? LibraryManager.playlists.count === 0 : true

                        Text {
                            anchors.centerIn: parent
                            text: qsTr("No custom playlists yet")
                            font.pixelSize: 12
                            color: Theme.textMuted
                        }
                    }
                }
            }
        }
    }
}
