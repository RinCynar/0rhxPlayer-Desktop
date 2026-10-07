import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import rhx.ui 1.0
import rhx.theme 1.0
import rhx.config 1.0
import rhx.audio 1.0
import rhx.library 1.0
import rhx.model 1.0

Item {
    id: root
    objectName: "playlistsView"

    property string selectedPlaylistId: ""
    property string activeRenameId: ""
    property string activeRenameOriginalName: ""

    // Format track count string
    function formatCount(cnt) {
        if (cnt === 1) return qsTr("1 Track");
        return cnt + " " + qsTr("Tracks");
    }

    // Format duration ms to mm:ss
    function formatDuration(ms) {
        if (!ms || ms <= 0) return "--:--";
        var totalSec = Math.floor(ms / 1000);
        var m = Math.floor(totalSec / 60);
        var s = totalSec % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    // Multi-Selection & Desktop Right-Click Context Menu
    property var selectedTrackPaths: []
    property int lastSelectedIndex: -1

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
            m3ContextMenu.show(pos.x, pos.y, selectedTrackPaths, title, artist, "playlist");
        }
    }

    // Solid Window-level Background (100% Flat M3)
    Rectangle {
        anchors.fill: parent
        color: Theme.surface

        MouseArea {
            anchors.fill: parent
            onClicked: (mouse) => {
                if (!(mouse.modifiers & Qt.ControlModifier) && !(mouse.modifiers & Qt.ShiftModifier)) {
                    root.clearSelection();
                }
            }
        }
    }

    // Top Title Bar Safety Mask (48px)
    Rectangle {
        id: titleBarMask
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 48
        color: Theme.surface
        z: 100
    }

    // ========================================================================
    // Standard Page Header: Title + Subtitle + Action Button
    // ========================================================================
    Item {
        id: pageHeader
        anchors.top: titleBarMask.bottom
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 32
        anchors.right: parent.right
        anchors.rightMargin: 32
        height: 52
        z: 90

        // In Grid View: standard title + subtitle
        ColumnLayout {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            visible: root.selectedPlaylistId === ""

            Text {
                text: qsTr("Playlists")
                font.pixelSize: 28
                font.bold: true
                color: Theme.textPrimary
            }

            Text {
                text: qsTr("%1 Playlists").arg(LibraryManager.playlistCount + 1)
                font.pixelSize: 13
                color: Theme.textMuted
            }
        }

        // In Grid View: "+ Create Playlist" M3 Capsule Button
        Rectangle {
            id: createBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.selectedPlaylistId === ""
            height: 38
            radius: 19
            color: createBtnMouse.containsMouse ? Qt.lighter(Theme.primary, 1.1) : Theme.primary
            implicitWidth: createBtnRow.implicitWidth + 28

            Behavior on color { ColorAnimation { duration: 150 } }

            RowLayout {
                id: createBtnRow
                anchors.centerIn: parent
                spacing: 8

                SvgIcon {
                    width: 14
                    height: 14
                    source: "qrc:/assets/icons/plus.svg"
                    color: Theme.onPrimary
                }

                Text {
                    text: qsTr("Create Playlist")
                    font.pixelSize: 13
                    font.bold: true
                    color: Theme.onPrimary
                }
            }

            MouseArea {
                id: createBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    createPlaylistDialog.openDialog();
                }
            }
        }

        // In Detail View: Back button
        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            visible: root.selectedPlaylistId !== ""
            height: 34
            radius: 17
            color: backBtnMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"
            implicitWidth: backBtnRow.implicitWidth + 24

            Behavior on color { ColorAnimation { duration: 150 } }

            RowLayout {
                id: backBtnRow
                anchors.centerIn: parent
                spacing: 8

                SvgIcon {
                    width: 14
                    height: 14
                    source: "qrc:/assets/icons/chevron_left.svg"
                    color: Theme.primary
                }

                Text {
                    text: qsTr("Back to Playlists")
                    font.pixelSize: 13
                    font.bold: true
                    color: Theme.primary
                }
            }

            MouseArea {
                id: backBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.selectedPlaylistId = "";
                    LibraryManager.clearSelectedPlaylist();
                }
            }
        }

        // In Detail View: Sorting ComboBox (1:1 with Library Titles)
        M3ComboBox {
            id: playlistSortCombo
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.selectedPlaylistId !== ""
            implicitWidth: 190
            implicitHeight: 36
            currentValue: "title_asc"
            model: [
                { value: "title_asc", label: qsTr("Title (A-Z)") },
                { value: "title_desc", label: qsTr("Title (Z-A)") },
                { value: "artist_asc", label: qsTr("Artist (A-Z)") },
                { value: "artist_desc", label: qsTr("Artist (Z-A)") },
                { value: "album_asc", label: qsTr("Album (A-Z)") },
                { value: "album_desc", label: qsTr("Album (Z-A)") },
                { value: "date_added_desc", label: qsTr("Date Added (New-Old)") },
                { value: "date_added_asc", label: qsTr("Date Added (Old-New)") },
                { value: "date_modified_desc", label: qsTr("Date Modified (New-Old)") },
                { value: "date_modified_asc", label: qsTr("Date Modified (Old-New)") },
                { value: "bitrate_desc", label: qsTr("Bitrate (High-Low)") },
                { value: "bitrate_asc", label: qsTr("Bitrate (Low-High)") },
                { value: "duration_desc", label: qsTr("Duration (Long)") },
                { value: "duration_asc", label: qsTr("Duration (Short)") },
                { value: "size_desc", label: qsTr("File Size (Large-Small)") },
                { value: "size_asc", label: qsTr("File Size (Small-Large)") }
            ]
            onValueChanged: function(v) {
                if (!v) return;
                LibraryManager.sortPlaylistTracks(v);
            }
        }
    }

    // ========================================================================
    // VIEWPORT 1: Playlists Card Grid View
    // ========================================================================
    Flickable {
        id: gridFlickable
        anchors.top: pageHeader.bottom
        anchors.topMargin: 20
        anchors.left: parent.left
        anchors.leftMargin: 32
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.bottom: parent.bottom
        contentWidth: width - 16
        contentHeight: gridCol.implicitHeight + 40
        clip: true
        visible: root.selectedPlaylistId === ""
        boundsBehavior: Flickable.StopAtBounds

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: (mouse) => {
                if (!(mouse.modifiers & Qt.ControlModifier) && !(mouse.modifiers & Qt.ShiftModifier)) {
                    root.clearSelection();
                }
            }
        }

        ScrollBar.vertical: M3ScrollBar {
            anchors.right: parent.right
            anchors.rightMargin: 6
        }

        ColumnLayout {
            id: gridCol
            width: gridFlickable.contentWidth
            spacing: 24

            // Adaptive Media Flow
            Flow {
                Layout.fillWidth: true
                spacing: 20

                // 1. System Favorites Card
                Rectangle {
                    id: favCard
                    width: 190
                    height: 250
                    radius: 20
                    color: favMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainerLow
                    border.width: 1
                    border.color: Theme.borderSubtle
                    scale: favMouse.pressed ? 0.97 : (favMouse.containsMouse ? 1.02 : 1.0)

                    Behavior on scale { NumberAnimation { duration: 150 } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Column {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 14
                        spacing: 10

                        // Red/Pink Gradient Cover
                        Rectangle {
                            width: parent.width
                            height: width
                            radius: 14
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "#EF4444" }
                                GradientStop { position: 1.0; color: "#EC4899" }
                            }

                            SvgIcon {
                                anchors.centerIn: parent
                                width: 56
                                height: 56
                                source: "qrc:/assets/icons/heart.svg"
                                color: "#FFFFFF"
                            }

                            // Track Count Badge
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.margins: 8
                                radius: 4
                                color: "#99000000"
                                implicitWidth: favCountText.implicitWidth + 10
                                implicitHeight: 20

                                Text {
                                    id: favCountText
                                    anchors.centerIn: parent
                                    text: root.formatCount(LibraryManager.favoriteCount)
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: "#FFFFFF"
                                }
                            }
                        }

                        // Info Text
                        Column {
                            width: parent.width
                            spacing: 3

                            Text {
                                width: parent.width
                                text: qsTr("Favorites")
                                font.pixelSize: 14
                                font.bold: true
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: qsTr("System Playlist")
                                font.pixelSize: 11
                                color: Theme.textMuted
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        id: favMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedPlaylistId = "__favorites__";
                            LibraryManager.selectPlaylist("__favorites__");
                        }
                    }
                }

                // 2. Custom Playlists Cards Repeater
                Repeater {
                    model: LibraryManager.playlists

                    delegate: Rectangle {
                        id: plCard
                        width: 190
                        height: 250
                        radius: 20
                        color: plMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainerLow
                        border.width: 1
                        border.color: Theme.borderSubtle
                        scale: plMouse.pressed ? 0.97 : (plMouse.containsMouse ? 1.02 : 1.0)

                        Behavior on scale { NumberAnimation { duration: 150 } }
                        Behavior on color { ColorAnimation { duration: 150 } }

                        MouseArea {
                            id: plMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedPlaylistId = model.id;
                                LibraryManager.selectPlaylist(model.id);
                            }
                        }

                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10

                            // Square Cover Container
                            Rectangle {
                                width: parent.width
                                height: width
                                radius: 14
                                color: Theme.surfaceContainer
                                clip: true

                                RoundedImage {
                                    anchors.fill: parent
                                    radius: parent.radius
                                    source: model.coverUrl || ""
                                    fallbackIcon: "qrc:/assets/icons/disc.svg"
                                }

                                // Track Count Badge
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.margins: 8
                                    radius: 4
                                    color: "#B3000000"
                                    implicitWidth: plCountText.implicitWidth + 10
                                    implicitHeight: 20

                                    Text {
                                        id: plCountText
                                        anchors.centerIn: parent
                                        text: root.formatCount(model.trackCount)
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: "#FFFFFF"
                                    }
                                }
                            }

                            // Info Text
                            Column {
                                width: parent.width
                                spacing: 3

                                Text {
                                    width: parent.width
                                    text: model.name
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: qsTr("Custom Playlist")
                                    font.pixelSize: 11
                                    color: Theme.textMuted
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        // Delete Button (Top-Right on Card, z: 20, unblocked hit-box)
                        Rectangle {
                            id: delBtn
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 16
                            width: 28
                            height: 28
                            radius: 14
                            color: delMouse.containsMouse ? "#EF4444" : "#B3000000"
                            visible: plMouse.containsMouse || delMouse.containsMouse
                            z: 20

                            Behavior on color { ColorAnimation { duration: 120 } }

                            SvgIcon {
                                anchors.centerIn: parent
                                width: 12
                                height: 12
                                source: "qrc:/assets/icons/trash.svg"
                                color: "#FFFFFF"
                            }

                            MouseArea {
                                id: delMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                preventStealing: true
                                propagateComposedEvents: false
                                onClicked: (mouse) => {
                                    mouse.accepted = true;
                                    LibraryManager.deletePlaylist(model.id);
                                }
                            }
                        }
                    }
                }
            }

            // Empty state if user has no playlists
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 180
                radius: 20
                color: Theme.surfaceContainerLow
                border.width: 1
                border.color: Theme.borderSubtle
                visible: LibraryManager.playlistCount === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    SvgIcon {
                        Layout.alignment: Qt.AlignHCenter
                        width: 44
                        height: 44
                        source: "qrc:/assets/icons/playlist.svg"
                        color: Theme.textMuted
                        opacity: 0.5
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("No custom playlists yet, click 'Create Playlist' above")
                        font.pixelSize: 13
                        color: Theme.textMuted
                    }
                }
            }
        }
    }

    // ========================================================================
    // VIEWPORT 2: Playlist Detail Drill-down View
    // ========================================================================
    Item {
        id: detailViewport
        anchors.top: pageHeader.bottom
        anchors.topMargin: 12
        anchors.left: parent.left
        anchors.leftMargin: 32
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.bottom: parent.bottom
        visible: root.selectedPlaylistId !== ""

        // Hero Banner Card
        Rectangle {
            id: detailBanner
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: 16
            height: 180
            radius: 20
            color: Theme.surfaceContainerLow
            border.width: 1
            border.color: Theme.borderSubtle

            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 24

                // 144x144 Square Cover
                Rectangle {
                    Layout.preferredWidth: 140
                    Layout.preferredHeight: 140
                    radius: 16
                    color: Theme.surfaceContainer
                    clip: true

                    // Favorites gradient cover
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        visible: LibraryManager.currentPlaylistIsFavorites
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#EF4444" }
                            GradientStop { position: 1.0; color: "#EC4899" }
                        }

                        SvgIcon {
                            anchors.centerIn: parent
                            width: 60
                            height: 60
                            source: "qrc:/assets/icons/heart.svg"
                            color: "#FFFFFF"
                        }
                    }

                    // Custom playlist cover
                    RoundedImage {
                        anchors.fill: parent
                        visible: !LibraryManager.currentPlaylistIsFavorites
                        radius: parent.radius
                        source: LibraryManager.currentPlaylistCoverUrl || ""
                        fallbackIcon: "qrc:/assets/icons/disc.svg"
                    }
                }

                // Metadata Column
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 6

                    // Tag
                    Text {
                        text: LibraryManager.currentPlaylistIsFavorites ? qsTr("SYSTEM PLAYLIST") : qsTr("CUSTOM PLAYLIST")
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.primary
                    }

                    // Title
                    Text {
                        Layout.fillWidth: true
                        text: LibraryManager.currentPlaylistName
                        font.pixelSize: 26
                        font.bold: true
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                    }

                    // Track count subtitle
                    Text {
                        text: root.formatCount(LibraryManager.playlistTracks ? LibraryManager.playlistTracks.count : 0)
                        font.pixelSize: 13
                        color: Theme.textMuted
                    }

                    Item { height: 4 }

                    // Action Buttons Row
                    RowLayout {
                        spacing: 12

                        // Play All Button
                        Rectangle {
                            height: 36
                            radius: 18
                            color: playAllMouse.containsMouse ? Qt.lighter(Theme.primary, 1.1) : Theme.primary
                            implicitWidth: playAllRow.implicitWidth + 24
                            opacity: (LibraryManager.playlistTracks && LibraryManager.playlistTracks.count > 0) ? 1.0 : 0.4

                            RowLayout {
                                id: playAllRow
                                anchors.centerIn: parent
                                spacing: 8

                                SvgIcon {
                                    width: 13
                                    height: 13
                                    source: "qrc:/assets/icons/play.svg"
                                    color: Theme.onPrimary
                                }

                                Text {
                                    text: qsTr("Play All")
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: Theme.onPrimary
                                }
                            }

                            MouseArea {
                                id: playAllMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    LibraryManager.playPlaylist(root.selectedPlaylistId, false);
                                }
                            }
                        }

                        // Shuffle Play Button
                        Rectangle {
                            height: 36
                            radius: 18
                            color: shuffleMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                            border.width: 1
                            border.color: Theme.borderSubtle
                            implicitWidth: shuffleRow.implicitWidth + 24
                            opacity: (LibraryManager.playlistTracks && LibraryManager.playlistTracks.count > 0) ? 1.0 : 0.4

                            RowLayout {
                                id: shuffleRow
                                anchors.centerIn: parent
                                spacing: 8

                                SvgIcon {
                                    width: 13
                                    height: 13
                                    source: "qrc:/assets/icons/shuffle.svg"
                                    color: Theme.textPrimary
                                }

                                Text {
                                    text: qsTr("Shuffle Play")
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: Theme.textPrimary
                                }
                            }

                            MouseArea {
                                id: shuffleMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    LibraryManager.playPlaylist(root.selectedPlaylistId, true);
                                }
                            }
                        }

                        // Rename Button (Custom Playlists Only)
                        Rectangle {
                            visible: !LibraryManager.currentPlaylistIsFavorites
                            width: 36
                            height: 36
                            radius: 18
                            color: renMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                            border.width: 1
                            border.color: Theme.borderSubtle

                            SvgIcon {
                                anchors.centerIn: parent
                                width: 14
                                height: 14
                                source: "qrc:/assets/icons/pen.svg"
                                color: Theme.textPrimary
                            }

                            MouseArea {
                                id: renMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    renamePlaylistDialog.openDialog(root.selectedPlaylistId, LibraryManager.currentPlaylistName);
                                }
                            }
                        }

                        // Delete Button (Custom Playlists Only)
                        Rectangle {
                            visible: !LibraryManager.currentPlaylistIsFavorites
                            width: 36
                            height: 36
                            radius: 18
                            color: delPlMouse.containsMouse ? "#EF4444" : Theme.surfaceContainerHigh
                            border.width: 1
                            border.color: Theme.borderSubtle

                            Behavior on color { ColorAnimation { duration: 120 } }

                            SvgIcon {
                                anchors.centerIn: parent
                                width: 14
                                height: 14
                                source: "qrc:/assets/icons/trash.svg"
                                color: delPlMouse.containsMouse ? "#FFFFFF" : Theme.textPrimary
                            }

                            MouseArea {
                                id: delPlMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var idToDelete = root.selectedPlaylistId;
                                    root.selectedPlaylistId = "";
                                    LibraryManager.deletePlaylist(idToDelete);
                                }
                            }
                        }
                    }
                }
            }
        }

        // Track List View
        ListView {
            id: playlistTracksList
            anchors.top: detailBanner.bottom
            anchors.topMargin: 16
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true
            reuseItems: true
            boundsBehavior: Flickable.StopAtBounds
            model: LibraryManager.playlistTracks
            spacing: 4

            MouseArea {
                anchors.fill: parent
                z: -1
                onClicked: (mouse) => {
                    if (!(mouse.modifiers & Qt.ControlModifier) && !(mouse.modifiers & Qt.ShiftModifier)) {
                        root.clearSelection();
                    }
                }
            }

            ScrollBar.vertical: M3ScrollBar {
                anchors.right: parent.right
                anchors.rightMargin: 6
            }

            delegate: Rectangle {
                id: trackRow
                width: playlistTracksList.width - 20
                height: 52
                radius: 12
                readonly property bool isSelected: root.isTrackSelected(model.path)
                color: isSelected
                       ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
                       : (trackRowMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent")
                border.width: isSelected ? 1.5 : 0
                border.color: isSelected ? Theme.primary : "transparent"

                Behavior on color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 16
                    spacing: 14

                    // Index
                    Text {
                        Layout.preferredWidth: 26
                        text: (index + 1).toString()
                        font.pixelSize: 12
                        font.bold: true
                        color: Theme.textMuted
                        horizontalAlignment: Text.AlignRight
                    }

                    // 38x38 Thumbnail
                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 38
                        radius: 6
                        color: Theme.surfaceContainer
                        clip: true

                        RoundedImage {
                            anchors.fill: parent
                            radius: parent.radius
                            source: model.coverUrl || ""
                            fallbackIcon: "qrc:/assets/icons/music.svg"
                        }
                    }

                    // Title & Artist • Album
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: model.title || model.path.split(/[/\\]/).pop()
                            font.pixelSize: 13
                            font.bold: true
                            color: (AudioEngine.currentTrack === model.path) ? Theme.primary : Theme.textPrimary
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: (model.artist || "—") + (model.album ? (" • " + model.album) : "")
                            font.pixelSize: 11
                            color: Theme.textMuted
                            elide: Text.ElideRight
                        }
                    }

                    // Codec Badge
                    Rectangle {
                        visible: !!model.format
                        radius: 4
                        color: Theme.surfaceContainerHighest
                        implicitWidth: formatText.implicitWidth + 8
                        implicitHeight: 18

                        Text {
                            id: formatText
                            anchors.centerIn: parent
                            text: (model.format || "").toUpperCase()
                            font.pixelSize: 9
                            font.bold: true
                            color: Theme.primary
                        }
                    }

                    // Duration
                    Text {
                        text: root.formatDuration(model.durationMs)
                        font.pixelSize: 12
                        color: Theme.textMuted
                    }

                    // Favorite Button
                    Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        color: "transparent"

                        SvgIcon {
                            anchors.centerIn: parent
                            width: 14
                            height: 14
                            source: "qrc:/assets/icons/heart.svg"
                            color: LibraryManager.isFavorite(model.path) ? "#EF4444" : Theme.textMuted
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                LibraryManager.toggleFavorite(model.path);
                            }
                        }
                    }

                    // Remove from Playlist Button (if not favorites)
                    Rectangle {
                        visible: !LibraryManager.currentPlaylistIsFavorites
                        width: 30
                        height: 30
                        radius: 15
                        color: rmTrkMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                        SvgIcon {
                            anchors.centerIn: parent
                            width: 13
                            height: 13
                            source: "qrc:/assets/icons/trash.svg"
                            color: rmTrkMouse.containsMouse ? "#EF4444" : Theme.textMuted
                        }

                        MouseArea {
                            id: rmTrkMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                LibraryManager.removeTrackFromPlaylist(root.selectedPlaylistId, model.path);
                            }
                        }
                    }
                }

                MouseArea {
                    id: trackRowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    z: -1
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.RightButton) {
                            root.handleTrackContextMenu(trackRowMouse, mouse, index, model.path, model.title, model.artist);
                        } else {
                            if (mouse.modifiers & Qt.ControlModifier) {
                                root.handleTrackClick(mouse, index, model.path, playlistTracksList.model);
                            } else if (mouse.modifiers & Qt.ShiftModifier) {
                                root.handleTrackClick(mouse, index, model.path, playlistTracksList.model);
                            } else {
                                root.clearSelection();
                                LibraryManager.playTrack(model.path, LibraryManager.getTrackPaths(LibraryManager.playlistTracks));
                            }
                        }
                    }
                    onDoubleClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            LibraryManager.playTrack(model.path, LibraryManager.getTrackPaths(LibraryManager.playlistTracks));
                        }
                    }
                }
            }

            // Empty Track List Hint
            Rectangle {
                anchors.centerIn: parent
                width: 320
                height: 120
                color: "transparent"
                visible: !LibraryManager.playlistTracks || LibraryManager.playlistTracks.count === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 10

                    SvgIcon {
                        Layout.alignment: Qt.AlignHCenter
                        width: 36
                        height: 36
                        source: "qrc:/assets/icons/music.svg"
                        color: Theme.textMuted
                        opacity: 0.4
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("No tracks in playlist, add tracks from library")
                        font.pixelSize: 13
                        color: Theme.textMuted
                    }
                }
            }
        }
    }

    // ========================================================================
    // MODAL: Create Playlist Dialog
    // ========================================================================
    Rectangle {
        id: createPlaylistDialog
        anchors.fill: parent
        color: "#80000000"
        z: 200
        visible: false

        function openDialog() {
            newPlaylistInput.text = "";
            visible = true;
            newPlaylistInput.forceActiveFocus();
        }

        function closeDialog() {
            visible = false;
        }

        function submit() {
            var name = newPlaylistInput.text.trim();
            if (name.length > 0) {
                LibraryManager.createPlaylist(name);
                closeDialog();
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: createPlaylistDialog.closeDialog()
        }

        Rectangle {
            anchors.centerIn: parent
            width: 380
            height: 200
            radius: 20
            color: Theme.surfaceContainerHigh
            border.width: 1
            border.color: Theme.borderSubtle

            MouseArea {
                anchors.fill: parent
                // Intercept clicks to prevent dismissing dialog
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16

                Text {
                    text: qsTr("Create Playlist")
                    font.pixelSize: 18
                    font.bold: true
                    color: Theme.textPrimary
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: 12
                    color: Theme.surfaceContainerHighest
                    border.width: newPlaylistInput.activeFocus ? 2 : 1
                    border.color: newPlaylistInput.activeFocus ? Theme.primary : Theme.borderSubtle

                    TextInput {
                        id: newPlaylistInput
                        anchors.fill: parent
                        anchors.margins: 12
                        font.pixelSize: 14
                        color: Theme.textPrimary
                        clip: true
                        onAccepted: createPlaylistDialog.submit()

                        Text {
                            anchors.fill: parent
                            text: qsTr("New playlist name...")
                            font.pixelSize: 14
                            color: Theme.textMuted
                            visible: !newPlaylistInput.text && !newPlaylistInput.activeFocus
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignRight
                    spacing: 12

                    Rectangle {
                        height: 36
                        radius: 18
                        color: "transparent"
                        implicitWidth: cancelTxt.implicitWidth + 24

                        Text {
                            id: cancelTxt
                            anchors.centerIn: parent
                            text: qsTr("Cancel")
                            font.pixelSize: 13
                            font.bold: true
                            color: Theme.textMuted
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: createPlaylistDialog.closeDialog()
                        }
                    }

                    Rectangle {
                        height: 36
                        radius: 18
                        color: Theme.primary
                        implicitWidth: confirmTxt.implicitWidth + 28

                        Text {
                            id: confirmTxt
                            anchors.centerIn: parent
                            text: qsTr("Create")
                            font.pixelSize: 13
                            font.bold: true
                            color: Theme.onPrimary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: createPlaylistDialog.submit()
                        }
                    }
                }
            }
        }
    }

    // ========================================================================
    // MODAL: Rename Playlist Dialog
    // ========================================================================
    Rectangle {
        id: renamePlaylistDialog
        anchors.fill: parent
        color: "#80000000"
        z: 200
        visible: false

        function openDialog(id, currentName) {
            root.activeRenameId = id;
            root.activeRenameOriginalName = currentName;
            renameInput.text = currentName;
            visible = true;
            renameInput.forceActiveFocus();
        }

        function closeDialog() {
            visible = false;
        }

        function submit() {
            var name = renameInput.text.trim();
            if (name.length > 0 && root.activeRenameId.length > 0) {
                LibraryManager.renamePlaylist(root.activeRenameId, name);
                closeDialog();
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: renamePlaylistDialog.closeDialog()
        }

        Rectangle {
            anchors.centerIn: parent
            width: 380
            height: 200
            radius: 20
            color: Theme.surfaceContainerHigh
            border.width: 1
            border.color: Theme.borderSubtle

            MouseArea {
                anchors.fill: parent
                // Intercept clicks
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16

                Text {
                    text: qsTr("Rename Playlist")
                    font.pixelSize: 18
                    font.bold: true
                    color: Theme.textPrimary
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: 12
                    color: Theme.surfaceContainerHighest
                    border.width: renameInput.activeFocus ? 2 : 1
                    border.color: renameInput.activeFocus ? Theme.primary : Theme.borderSubtle

                    TextInput {
                        id: renameInput
                        anchors.fill: parent
                        anchors.margins: 12
                        font.pixelSize: 14
                        color: Theme.textPrimary
                        clip: true
                        onAccepted: renamePlaylistDialog.submit()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignRight
                    spacing: 12

                    Rectangle {
                        height: 36
                        radius: 18
                        color: "transparent"
                        implicitWidth: renCancelTxt.implicitWidth + 24

                        Text {
                            id: renCancelTxt
                            anchors.centerIn: parent
                            text: qsTr("Cancel")
                            font.pixelSize: 13
                            font.bold: true
                            color: Theme.textMuted
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: renamePlaylistDialog.closeDialog()
                        }
                    }

                    Rectangle {
                        height: 36
                        radius: 18
                        color: Theme.primary
                        implicitWidth: renSaveTxt.implicitWidth + 28

                        Text {
                            id: renSaveTxt
                            anchors.centerIn: parent
                            text: qsTr("Save")
                            font.pixelSize: 13
                            font.bold: true
                            color: Theme.onPrimary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: renamePlaylistDialog.submit()
                        }
                    }
                }
            }
        }
    }
}
