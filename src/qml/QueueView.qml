import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import rhx.audio 1.0
import rhx.library 1.0
import rhx.model 1.0
import rhx.ui 1.0
import rhx.config 1.0
import rhx.theme 1.0

Item {
    id: queueRoot
    objectName: "queueView"

    signal navigateToLibrary()

    property string subTab: "nexts" // 'played' | 'nexts'

    readonly property int totalQueueCount: AudioEngine.queueModel ? AudioEngine.queueModel.count : 0
    readonly property int currentListCount: {
        var cur = AudioEngine.currentIndex; // reactive dependency
        return subTab === "played"
            ? (AudioEngine.playedModel ? AudioEngine.playedModel.count : 0)
            : (AudioEngine.nextModel ? AudioEngine.nextModel.count : 0);
    }

    // Multi-Selection & Desktop Right-Click Context Menu
    property var selectedTrackPaths: []
    property int lastSelectedIndex: -1

    property int favVersion: 0
    Connections {
        target: LibraryManager
        function onFavoritesChanged() {
            queueRoot.favVersion++;
        }
    }
    readonly property bool isCurrentFav: {
        queueRoot.favVersion;
        return AudioEngine.currentTrack && AudioEngine.currentTrack.length > 0
            ? LibraryManager.isFavorite(AudioEngine.currentTrack)
            : false;
    }

    function isTrackSelected(path) {
        if (!path || !selectedTrackPaths) return false;
        return selectedTrackPaths.indexOf(path) !== -1;
    }

    function clearSelection() {
        selectedTrackPaths = [];
        lastSelectedIndex = -1;
    }

    function handleTrackClick(mouse, index, path, modelRef) {
        if (mouse.modifiers & Qt.ControlModifier) {
            var arr = selectedTrackPaths.slice();
            var idx = arr.indexOf(path);
            if (idx !== -1) arr.splice(idx, 1);
            else arr.push(path);
            selectedTrackPaths = arr;
            lastSelectedIndex = index;
        } else if (mouse.modifiers & Qt.ShiftModifier) {
            if (modelRef && typeof modelRef.getPathsInRange === "function") {
                var from = (lastSelectedIndex >= 0) ? lastSelectedIndex : 0;
                selectedTrackPaths = modelRef.getPathsInRange(from, index);
            } else {
                selectedTrackPaths = [path];
            }
        }
    }

    function handleTrackContextMenu(mouseArea, mouse, index, path, title, artist) {
        if (selectedTrackPaths.indexOf(path) === -1) {
            selectedTrackPaths = [path];
            lastSelectedIndex = index;
        }
        var pos = mouseArea.mapToItem(null, mouse.x, mouse.y);
        if (typeof m3ContextMenu !== "undefined") {
            m3ContextMenu.show(pos.x, pos.y, selectedTrackPaths, title, artist, "queue");
        }
    }

    // Solid Window-level Background
    Rectangle {
        anchors.fill: parent
        color: Theme.surface

        MouseArea {
            anchors.fill: parent
            onClicked: (mouse) => {
                if (!(mouse.modifiers & Qt.ControlModifier) && !(mouse.modifiers & Qt.ShiftModifier)) {
                    queueRoot.clearSelection();
                }
            }
        }
    }

    // Top Title Bar Safety Mask (Height 48px to prevent overlap with frameless buttons)
    Rectangle {
        id: titleBarMask
        objectName: "queueTitleBarMask"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 48
        color: Theme.surface
        z: 100
    }

    // Main Virtualized Scrollable Queue List
    ListView {
        id: queueListView
        objectName: "queueListView"
        anchors.top: titleBarMask.bottom
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        spacing: 8

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: (mouse) => {
                if (!(mouse.modifiers & Qt.ControlModifier) && !(mouse.modifiers & Qt.ShiftModifier)) {
                    queueRoot.clearSelection();
                }
            }
        }

        // Standard M3 Floating Capsule ScrollBar with 6px safe margin
        ScrollBar.vertical: M3ScrollBar {}

        model: {
            var cur = AudioEngine.currentIndex; // explicit reactive dependency
            return queueRoot.subTab === "played" ? AudioEngine.playedModel : AudioEngine.nextModel;
        }

        // Header: Top Hero Banner, Segmented Filter Pills, and Optional Empty Card
        header: Column {
            id: queueHeaderCol
            objectName: "queueMainContentCol"
            width: queueListView.width
            spacing: 20
            bottomPadding: 8

            // 1. Hero Cover Banner Card
            Item {
                width: parent.width
                height: 220

                Rectangle {
                    id: heroBanner
                    objectName: "queueHeroBanner"
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 32
                    anchors.rightMargin: 32
                    height: 220
                    radius: 20
                    color: Theme.surfaceContainer
                    clip: true

                    // Cover artwork as background (using RoundedImage with antialiased corner clipping)
                    RoundedImage {
                        id: bannerCover
                        anchors.fill: parent
                        radius: heroBanner.radius
                        fullResolution: true
                        source: AudioEngine.currentCoverUrl || ""
                        fallbackColor: Theme.surfaceContainerHigh
                    }

                    // Horizontal gradient overlay: opaque on left for text legibility, transparent on right
                    Rectangle {
                        anchors.fill: parent
                        radius: heroBanner.radius
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Qt.rgba(0.07, 0.07, 0.09, 0.94) }
                            GradientStop { position: 0.55; color: Qt.rgba(0.07, 0.07, 0.09, 0.65) }
                            GradientStop { position: 1.0; color: Qt.rgba(0.07, 0.07, 0.09, 0.25) }
                        }
                    }

                    // Vertical bottom-up gradient for title contrast
                    Rectangle {
                        anchors.fill: parent
                        radius: heroBanner.radius
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.05) }
                            GradientStop { position: 0.45; color: Qt.rgba(0, 0, 0, 0.20) }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.70) }
                        }
                    }

                    // Top-Right Badges: Total Count Capsule & Clear Button
                    RowLayout {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: 20
                        anchors.rightMargin: 20
                        spacing: 10
                        z: 10

                        // Total count pill
                        Rectangle {
                            implicitWidth: countBadgeText.implicitWidth + 24
                            implicitHeight: 28
                            radius: 14
                            color: Qt.rgba(0, 0, 0, 0.55)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.12)

                            Text {
                                id: countBadgeText
                                anchors.centerIn: parent
                                text: queueRoot.totalQueueCount === 1 ? qsTr("1 Track") : (queueRoot.totalQueueCount + " " + qsTr("Tracks"))
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                color: "#FFFFFF"
                            }
                        }

                        // Favorite current track pill
                        Rectangle {
                            visible: AudioEngine.currentTrack && AudioEngine.currentTrack.length > 0
                            implicitWidth: favBtnRow.implicitWidth + 20
                            implicitHeight: 28
                            radius: 14
                            color: qFavMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(0, 0, 0, 0.55)
                            border.width: 1
                            border.color: queueRoot.isCurrentFav ? Theme.primary : Qt.rgba(255, 255, 255, 0.12)

                            RowLayout {
                                id: favBtnRow
                                anchors.centerIn: parent
                                spacing: 6

                                SvgIcon {
                                    width: 13
                                    height: 13
                                    source: queueRoot.isCurrentFav ? "qrc:/assets/icons/heart.svg" : "qrc:/assets/icons/heart_outline.svg"
                                    color: queueRoot.isCurrentFav ? Theme.primary : "#FFFFFF"
                                }

                                Text {
                                    text: queueRoot.isCurrentFav ? qsTr("Favorited") : qsTr("Favorite")
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: queueRoot.isCurrentFav ? Theme.primary : "#FFFFFF"
                                }
                            }

                            MouseArea {
                                id: qFavMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    LibraryManager.toggleFavorite(AudioEngine.currentTrack);
                                }
                            }
                        }

                        // Add to playlist pill
                        Rectangle {
                            visible: AudioEngine.currentTrack && AudioEngine.currentTrack.length > 0
                            implicitWidth: qPlBtnRow.implicitWidth + 20
                            implicitHeight: 28
                            radius: 14
                            color: qPlMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(0, 0, 0, 0.55)
                            border.width: 1
                            border.color: Qt.rgba(255, 255, 255, 0.12)

                            RowLayout {
                                id: qPlBtnRow
                                anchors.centerIn: parent
                                spacing: 6

                                SvgIcon {
                                    width: 13
                                    height: 13
                                    source: "qrc:/assets/icons/playlist.svg"
                                    color: "#FFFFFF"
                                }

                                Text {
                                    text: qsTr("Add to Playlist")
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: "#FFFFFF"
                                }
                            }

                            MouseArea {
                                id: qPlMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (typeof playlistSelectDialog !== "undefined" && AudioEngine.currentTrack.length > 0) {
                                        playlistSelectDialog.openForTracks([AudioEngine.currentTrack]);
                                    }
                                }
                            }
                        }

                        // Clear queue button
                        Rectangle {
                            id: clearBtn
                            visible: queueRoot.totalQueueCount > 1 || (queueRoot.totalQueueCount === 1 && (!AudioEngine.currentTrack || !AudioEngine.currentTrack.length))
                            implicitWidth: clearBtnRow.implicitWidth + 24
                            implicitHeight: 28
                            radius: 14
                            color: clearMouse.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.3) : Qt.rgba(0, 0, 0, 0.55)
                            border.width: 1
                            border.color: clearMouse.containsMouse ? Theme.error : Qt.rgba(255, 255, 255, 0.12)
                            scale: clearMouse.pressed ? 0.94 : 1.0

                            Behavior on scale { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                id: clearBtnRow
                                anchors.centerIn: parent
                                spacing: 6

                                SvgIcon {
                                    width: 12
                                    height: 12
                                    source: "qrc:/assets/icons/trash.svg"
                                    color: clearMouse.containsMouse ? "#FF6B6B" : "#FFA3A3"
                                }

                                Text {
                                    text: qsTr("Clear")
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    color: clearMouse.containsMouse ? "#FF6B6B" : "#FFA3A3"
                                }
                            }

                            MouseArea {
                                id: clearMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: AudioEngine.clearQueue(true)
                            }
                        }
                    }

                    // Bottom-Left Info: Big Title & Currently Playing Details
                    ColumnLayout {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 24
                        anchors.bottomMargin: 24
                        spacing: 4
                        z: 10

                        Text {
                            text: qsTr("Playback Queue")
                            font.pixelSize: 32
                            font.weight: Font.ExtraBold
                            color: "#FFFFFF"
                        }

                        Text {
                            text: {
                                if (!AudioEngine.currentTrack) return "—";
                                var artist = AudioEngine.currentArtist;
                                var title = AudioEngine.currentTitle;
                                var album = AudioEngine.currentAlbum;
                                if (artist && title) return "『" + artist + "』 · " + title;
                                if (artist && album) return "『" + artist + "』 · " + album;
                                if (title) return title;
                                return "—";
                            }
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: "#D0D0D5"
                            elide: Text.ElideRight
                            Layout.maximumWidth: heroBanner.width - 48
                        }
                    }
                }
            }

            // 2. Centered Segmented Control (Played vs Nexts)
            Item {
                width: parent.width
                height: 40

                Rectangle {
                    id: segmentedContainer
                    objectName: "queueSegmentedContainer"
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitWidth: segmentedRow.implicitWidth + 8
                    implicitHeight: 40
                    radius: 20
                    color: Theme.surfaceContainer
                    border.width: 1
                    border.color: Theme.borderSubtle

                    RowLayout {
                        id: segmentedRow
                        anchors.centerIn: parent
                        spacing: 4

                        // Tab 1: Played
                        Rectangle {
                            objectName: "playedTabBtn"
                            implicitWidth: playedText.implicitWidth + 32
                            implicitHeight: 32
                            radius: 16
                            color: queueRoot.subTab === "played" ? Theme.primary : "transparent"
                            scale: playedMouse.pressed ? 0.95 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                id: playedText
                                anchors.centerIn: parent
                                text: "✓ " + qsTr("Played")
                                font.pixelSize: 12
                                font.weight: queueRoot.subTab === "played" ? Font.DemiBold : Font.Normal
                                color: queueRoot.subTab === "played" ? Theme.colorOnPrimary : (playedMouse.containsMouse ? Theme.textPrimary : Theme.textMuted)
                            }

                            MouseArea {
                                id: playedMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: queueRoot.subTab = "played"
                            }
                        }

                        // Tab 2: Nexts
                        Rectangle {
                            objectName: "nextsTabBtn"
                            implicitWidth: nextsText.implicitWidth + 32
                            implicitHeight: 32
                            radius: 16
                            color: queueRoot.subTab === "nexts" ? Theme.primary : "transparent"
                            scale: nextsMouse.pressed ? 0.95 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                id: nextsText
                                anchors.centerIn: parent
                                text: qsTr("Nexts")
                                font.pixelSize: 12
                                font.weight: queueRoot.subTab === "nexts" ? Font.DemiBold : Font.Normal
                                color: queueRoot.subTab === "nexts" ? Theme.colorOnPrimary : (nextsMouse.containsMouse ? Theme.textPrimary : Theme.textMuted)
                            }

                            MouseArea {
                                id: nextsMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: queueRoot.subTab = "nexts"
                            }
                        }
                    }
                }
            }

            // 3. Empty State Card (Visible when the active sub-list has no tracks)
            Item {
                width: parent.width
                height: 150
                visible: queueRoot.currentListCount === 0

                Rectangle {
                    id: emptyCard
                    objectName: "queueEmptyState"
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 32
                    anchors.rightMargin: 32
                    height: 150
                    radius: 20
                    color: Theme.surfaceContainer

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 12

                        SvgIcon {
                            Layout.alignment: Qt.AlignHCenter
                            width: 36
                            height: 36
                            source: "qrc:/assets/icons/list_ol.svg"
                            color: Theme.primary
                            opacity: 0.45
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: queueRoot.subTab === "played" ? qsTr("No played tracks") : qsTr("Queue is empty")
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: Theme.textMuted
                        }
                    }
                }
            }
        }

        // Minimalist M3 List Item Delegate (Cover Thumbnail, Title, Artist · Album, Delete Button)
        delegate: Item {
            id: delWrapper
            width: queueListView.width
            height: 56

            Rectangle {
                id: itemCard
                objectName: "queueItemDelegate"
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 32
                anchors.rightMargin: 32
                anchors.verticalCenter: parent.verticalCenter
                height: 50
                radius: 14
                readonly property bool isSelected: queueRoot.isTrackSelected(model.path)
                color: isSelected
                       ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
                       : (itemMouse.containsMouse || deleteMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                border.width: isSelected ? 1.5 : 0
                border.color: isSelected ? Theme.primary : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                readonly property int globalIndex: queueRoot.subTab === "played"
                                                   ? index
                                                   : (AudioEngine.currentIndex >= 0 ? (AudioEngine.currentIndex + 1 + index) : index)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 16
                    spacing: 14

                    // 38x38 Rounded Cover Thumbnail
                    Rectangle {
                        width: 38
                        height: 38
                        radius: 8
                        color: Theme.surfaceContainerHighest
                        clip: true

                        RoundedImage {
                            anchors.fill: parent
                            radius: 8
                            source: model.coverUrl || ""
                            fallbackColor: Theme.surfaceContainerHighest
                            fallbackIcon: "qrc:/assets/icons/music_note.svg"
                            fallbackIconColor: Theme.textMuted
                            fallbackIconSize: 18
                        }
                    }

                    // Title & Artist · Album
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: model.title || (model.path ? model.path.split(/[/\\]/).pop() : "")
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: itemMouse.containsMouse ? Theme.primary : Theme.textPrimary
                            elide: Text.ElideRight
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                var a = model.artist || "";
                                var alb = model.album || "";
                                if (a && alb) return a + " • " + alb;
                                if (a) return a;
                                if (alb) return alb;
                                return "—";
                            }
                            font.pixelSize: 11
                            color: Theme.textSecondary
                            elide: Text.ElideRight
                        }
                    }

                    // Remove from queue button (revealed on hover)
                    Rectangle {
                        id: removeBtn
                        width: 28
                        height: 28
                        radius: 14
                        color: deleteMouse.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.2) : "transparent"
                        opacity: itemMouse.containsMouse || deleteMouse.containsMouse ? 1.0 : 0.0
                        scale: deleteMouse.pressed ? 0.88 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        Behavior on color { ColorAnimation { duration: 120 } }

                        SvgIcon {
                            anchors.centerIn: parent
                            width: 12
                            height: 12
                            source: "qrc:/assets/icons/win_close.svg"
                            color: deleteMouse.containsMouse ? Theme.error : Theme.textMuted
                        }

                        MouseArea {
                            id: deleteMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: AudioEngine.removeFromQueue(itemCard.globalIndex)
                        }
                    }
                }

                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            queueRoot.handleTrackContextMenu(itemMouse, mouse, index, model.path, model.title, model.artist);
                        } else {
                            if (mouse.modifiers & Qt.ControlModifier) {
                                queueRoot.handleTrackClick(mouse, index, model.path, queueListView.model);
                            } else if (mouse.modifiers & Qt.ShiftModifier) {
                                queueRoot.handleTrackClick(mouse, index, model.path, queueListView.model);
                            } else {
                                queueRoot.clearSelection();
                                AudioEngine.playQueueIndex(itemCard.globalIndex);
                            }
                        }
                    }
                    onDoubleClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            AudioEngine.playQueueIndex(itemCard.globalIndex);
                        }
                    }
                }
            }
        }

        footer: Item {
            width: queueListView.width
            height: 32
        }
    }
}
