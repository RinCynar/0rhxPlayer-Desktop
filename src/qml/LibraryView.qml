import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import rhx.audio 1.0
import rhx.library 1.0
import rhx.model 1.0
import rhx.ui 1.0
import rhx.config 1.0
import rhx.theme 1.0
import rhx.i18n 1.0

Item {
    id: libraryRoot

    // Navigation and Filtering State
    property string currentTab: "tracks" // "tracks" | "albums" | "artists" | "folders"
    readonly property string activeTabMode: {
        if (currentTab === "tracks" || currentTab === "titles") return ConfigManager.tracksViewMode;
        if (currentTab === "albums") return ConfigManager.albumsViewMode;
        if (currentTab === "artists") return ConfigManager.artistsViewMode;
        if (currentTab === "folders") return ConfigManager.foldersViewMode;
        return "compact";
    }
    property string viewMode: activeTabMode === "list" ? "list" : "grid"
    onViewModeChanged: {
        if (viewMode === "grid" && activeTabMode === "list") {
            ConfigManager.setViewModeForTab(currentTab, "compact");
        } else if (viewMode === "list" && activeTabMode !== "list") {
            ConfigManager.setViewModeForTab(currentTab, "list");
        }
    }
    property var selectedGroup: null    // null | { type: "album"|"artist"|"folder", name: "", subTitle: "", coverUrl: "" }
    property var loadedTabs: ({ "tracks": true, "titles": true })
    property bool detailsLoaded: false
    property bool gridModeLoaded: activeTabMode !== "list"

    onActiveTabModeChanged: {
        if (activeTabMode !== "list") gridModeLoaded = true;
    }

    function resetAndApplySort() {
        if (selectedGroup || currentTab === "tracks" || currentTab === "titles") {
            sortCombo.currentValue = "title_asc";
            LibraryManager.sortTracks("title_asc");
        } else if (currentTab === "albums") {
            sortCombo.currentValue = "album_asc";
            LibraryManager.sortAlbums("album_asc");
        } else if (currentTab === "artists") {
            sortCombo.currentValue = "artist_asc";
            LibraryManager.sortArtists("artist_asc");
        } else if (currentTab === "folders") {
            sortCombo.currentValue = "folder_asc";
            LibraryManager.sortFolders("folder_asc");
        }
    }

    onCurrentTabChanged: {
        var copy = Object.assign({}, loadedTabs);
        copy[currentTab] = true;
        loadedTabs = copy;
        resetAndApplySort();
    }
    onSelectedGroupChanged: {
        if (selectedGroup != null) {
            detailsLoaded = true;
        }
        resetAndApplySort();
    }
    Component.onCompleted: resetAndApplySort()

    function openGroupDetails(group) {
        selectedGroup = group;
        if (group != null) {
            detailsLoaded = true;
        }
    }

    function formatDuration(ms) {
        if (!ms || ms <= 0) return "--:--";
        var totalSec = Math.floor(ms / 1000);
        var m = Math.floor(totalSec / 60);
        var s = totalSec % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    function formatCount(cnt) {
        if (cnt === 1) return qsTr("1 Track");
        return cnt + " " + qsTr("Tracks");
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
            if (idx !== -1) {
                arr.splice(idx, 1);
            } else {
                arr.push(path);
            }
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

    function handleTrackContextMenu(mouseArea, mouse, index, path, title, artist, ctx, modelRef) {
        if (selectedTrackPaths.indexOf(path) === -1) {
            selectedTrackPaths = [path];
            lastSelectedIndex = index;
        }
        var pos = mouseArea.mapToItem(null, mouse.x, mouse.y);
        if (typeof m3ContextMenu !== "undefined") {
            m3ContextMenu.show(pos.x, pos.y, selectedTrackPaths, title, artist, ctx || "library");
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
                    libraryRoot.clearSelection();
                }
            }
        }
    }

    // Top Title Bar Safety Mask
    Rectangle {
        id: titleBarMask
        objectName: "libraryTitleBarMask"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 48
        color: Theme.surface
        z: 100
    }

    // Header and Content Column (Positioned below the 48px titleBarMask with 16px safety buffer)
    ColumnLayout {
        id: libraryMainContentCol
        objectName: "libraryMainContentCol"
        anchors.top: titleBarMask.bottom
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 0

        // ====================================================================
        // 1. Library Header & Controls Toolbar
        // ====================================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: selectedGroup ? 68 : 116
            color: Theme.surface
            z: 90

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 32
                anchors.rightMargin: 32
                spacing: 24

                // Top Line: Title / Drill-Down Info + Actions
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    // Left Title & Back button
                    RowLayout {
                        spacing: 12
                        Layout.fillWidth: true

                        // Back Button (Visible when drilled down)
                        Rectangle {
                            visible: libraryRoot.selectedGroup != null
                            width: 38
                            height: 38
                            radius: 19
                            color: backMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer
                            border.width: 1
                            border.color: Theme.borderSubtle
                            scale: backMouse.pressed ? 0.92 : 1.0

                            Behavior on scale { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            SvgIcon {
                                anchors.centerIn: parent
                                width: 16
                                height: 16
                                source: "qrc:/assets/icons/chevron_left.svg"
                                color: Theme.textPrimary
                            }

                            MouseArea {
                                id: backMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    libraryRoot.selectedGroup = null;
                                }
                            }
                        }

                        ColumnLayout {
                            spacing: 4
                            Text {
                                text: libraryRoot.selectedGroup ? libraryRoot.selectedGroup.name : qsTr("Library")
                                font.pixelSize: 28
                                font.bold: true
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                                Layout.maximumWidth: 460
                            }

                            Text {
                                text: libraryRoot.selectedGroup
                                      ? (libraryRoot.selectedGroup.subTitle || "")
                                      : (LibraryManager.trackCount + " " + qsTr("Tracks in Library"))
                                font.pixelSize: 13
                                font.weight: Font.Normal
                                color: Theme.textMuted
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Right Actions Toolbar
                    RowLayout {
                        spacing: 10

                        // Sorting ComboBox
                        M3ComboBox {
                            id: sortCombo
                            implicitWidth: 190
                            implicitHeight: 36
                            currentValue: "title_asc"
                            model: {
                                if (libraryRoot.selectedGroup || libraryRoot.currentTab === "tracks" || libraryRoot.currentTab === "titles") {
                                    return [
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
                                    ];
                                } else if (libraryRoot.currentTab === "albums") {
                                    return [
                                        { value: "album_asc", label: qsTr("Album (A-Z)") },
                                        { value: "album_desc", label: qsTr("Album (Z-A)") },
                                        { value: "artist_asc", label: qsTr("Artist (A-Z)") },
                                        { value: "artist_desc", label: qsTr("Artist (Z-A)") },
                                        { value: "track_count_desc", label: qsTr("Tracks (High-Low)") },
                                        { value: "track_count_asc", label: qsTr("Tracks (Low-High)") }
                                    ];
                                } else if (libraryRoot.currentTab === "artists") {
                                    return [
                                        { value: "artist_asc", label: qsTr("Artist (A-Z)") },
                                        { value: "artist_desc", label: qsTr("Artist (Z-A)") },
                                        { value: "track_count_desc", label: qsTr("Tracks (High-Low)") },
                                        { value: "track_count_asc", label: qsTr("Tracks (Low-High)") }
                                    ];
                                } else {
                                    return [
                                        { value: "folder_asc", label: qsTr("Folder (A-Z)") },
                                        { value: "folder_desc", label: qsTr("Folder (Z-A)") },
                                        { value: "track_count_desc", label: qsTr("Tracks (High-Low)") },
                                        { value: "track_count_asc", label: qsTr("Tracks (Low-High)") }
                                    ];
                                }
                            }
                            onValueChanged: function(v) {
                                if (!v) return;
                                if (libraryRoot.selectedGroup || libraryRoot.currentTab === "tracks" || libraryRoot.currentTab === "titles") {
                                    LibraryManager.sortTracks(v);
                                } else if (libraryRoot.currentTab === "albums") {
                                    LibraryManager.sortAlbums(v);
                                } else if (libraryRoot.currentTab === "artists") {
                                    LibraryManager.sortArtists(v);
                                } else if (libraryRoot.currentTab === "folders") {
                                    LibraryManager.sortFolders(v);
                                }
                            }
                        }

                        // Rescan Button
                        Rectangle {
                            implicitWidth: rescanRow.implicitWidth + 24
                            implicitHeight: 36
                            radius: 18
                            color: rescanMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer
                            border.width: 1
                            border.color: Theme.borderSubtle
                            scale: rescanMouse.pressed ? 0.94 : 1.0

                            Behavior on scale { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                id: rescanRow
                                anchors.centerIn: parent
                                spacing: 6

                                SvgIcon {
                                    width: 14
                                    height: 14
                                    source: "qrc:/assets/icons/refresh.svg"
                                    color: LibraryManager.isScanning ? Theme.primary : Theme.textPrimary
                                    rotation: LibraryManager.isScanning ? spinAnim.rot : 0
                                    NumberAnimation on rotation {
                                        id: spinAnim
                                        property real rot: 0
                                        running: LibraryManager.isScanning
                                        loops: Animation.Infinite
                                        from: 0; to: 360; duration: 1000
                                    }
                                }

                                Text {
                                    text: qsTr("Rescan")
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: Theme.textPrimary
                                }
                            }

                            MouseArea {
                                id: rescanMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ConfigManager.rescanLibrary();
                                }
                            }
                        }

                        // View Mode Switcher: Tri-State [ List | Card | Compact ]
                        Rectangle {
                            visible: libraryRoot.selectedGroup == null
                            implicitWidth: 108
                            implicitHeight: 36
                            radius: 18
                            color: Theme.surfaceContainer
                            border.width: 1
                            border.color: Theme.borderSubtle

                            Row {
                                anchors.centerIn: parent
                                spacing: 2

                                // 1. List Mode
                                Rectangle {
                                    width: 32
                                    height: 30
                                    radius: 15
                                    readonly property bool isCurrent: libraryRoot.activeTabMode === "list"
                                    color: isCurrent ? Theme.primary : (lMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent")
                                    scale: lMouse.pressed ? 0.92 : 1.0

                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    SvgIcon {
                                        anchors.centerIn: parent
                                        width: 15
                                        height: 15
                                        source: "qrc:/assets/icons/view_list.svg"
                                        color: parent.isCurrent ? Theme.colorOnPrimary : Theme.textPrimary
                                    }

                                    MouseArea {
                                        id: lMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: ConfigManager.setViewModeForTab(libraryRoot.currentTab, "list")
                                    }
                                }

                                // 2. Standard Card Mode
                                Rectangle {
                                    width: 32
                                    height: 30
                                    radius: 15
                                    readonly property bool isCurrent: libraryRoot.activeTabMode === "card"
                                    color: isCurrent ? Theme.primary : (cMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent")
                                    scale: cMouse.pressed ? 0.92 : 1.0

                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    SvgIcon {
                                        anchors.centerIn: parent
                                        width: 15
                                        height: 15
                                        source: "qrc:/assets/icons/album.svg"
                                        color: parent.isCurrent ? Theme.colorOnPrimary : Theme.textPrimary
                                    }

                                    MouseArea {
                                        id: cMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: ConfigManager.setViewModeForTab(libraryRoot.currentTab, "card")
                                    }
                                }

                                // 3. Compact Card Mode
                                Rectangle {
                                    width: 32
                                    height: 30
                                    radius: 15
                                    readonly property bool isCurrent: libraryRoot.activeTabMode === "compact"
                                    color: isCurrent ? Theme.primary : (gMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent")
                                    scale: gMouse.pressed ? 0.92 : 1.0

                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    SvgIcon {
                                        anchors.centerIn: parent
                                        width: 15
                                        height: 15
                                        source: "qrc:/assets/icons/view_grid.svg"
                                        color: parent.isCurrent ? Theme.colorOnPrimary : Theme.textPrimary
                                    }

                                    MouseArea {
                                        id: gMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: ConfigManager.setViewModeForTab(libraryRoot.currentTab, "compact")
                                    }
                                }
                            }
                        }
                    }
                }

                // Filter Tabs (Chips) - Hidden when drilled down
                RowLayout {
                    visible: libraryRoot.selectedGroup == null
                    spacing: 8
                    Layout.fillWidth: true

                    Repeater {
                        model: [
                            { id: "tracks", label: qsTr("Tracks"), icon: "qrc:/assets/icons/music.svg" },
                            { id: "albums", label: qsTr("Albums"), icon: "qrc:/assets/icons/album.svg" },
                            { id: "artists", label: qsTr("Artists"), icon: "qrc:/assets/icons/artist.svg" },
                            { id: "folders", label: qsTr("Folders"), icon: "qrc:/assets/icons/folder.svg" }
                        ]

                        delegate: Rectangle {
                            id: tabChip
                            readonly property bool isSelected: libraryRoot.currentTab === modelData.id || (modelData.id === "tracks" && libraryRoot.currentTab === "titles")
                            implicitWidth: chipRow.implicitWidth + 24
                            implicitHeight: 32
                            radius: 16
                            color: isSelected ? Theme.primary : (chipMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer)
                            border.width: isSelected ? 0 : 1
                            border.color: Theme.borderSubtle
                            scale: chipMouse.pressed ? 0.95 : 1.0

                            Behavior on scale {
                                NumberAnimation {
                                    duration: chipMouse.pressed ? 90 : 240
                                    easing.type: chipMouse.pressed ? Easing.OutQuad : Easing.OutBack
                                    easing.overshoot: 1.3
                                }
                            }
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 6

                                SvgIcon {
                                    width: 13
                                    height: 13
                                    source: modelData.icon
                                    color: tabChip.isSelected ? Theme.colorOnPrimary : Theme.textPrimary
                                }

                                Text {
                                    text: modelData.label
                                    font.pixelSize: 12
                                    font.bold: tabChip.isSelected
                                    color: tabChip.isSelected ? Theme.colorOnPrimary : Theme.textPrimary
                                }
                            }

                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    libraryRoot.currentTab = modelData.id;
                                    libraryRoot.selectedGroup = null;
                                }
                            }
                        }
                    }
                }
            }
        }

        // ====================================================================
        // 2. Main Content View Area
        // ====================================================================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ----------------------------------------------------------------
            // A. Empty State (When Library has 0 tracks)
            // ----------------------------------------------------------------
            Rectangle {
                visible: LibraryManager.trackCount === 0 && !LibraryManager.isScanning
                anchors.centerIn: parent
                width: Math.min(parent.width - 64, 460)
                height: 300
                radius: 24
                color: Theme.surfaceContainerLow
                border.width: 1
                border.color: Theme.borderSubtle

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 16

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 72
                        height: 72
                        radius: 36
                        color: Theme.primaryContainer

                        SvgIcon {
                            anchors.centerIn: parent
                            width: 32
                            height: 32
                            source: "qrc:/assets/icons/music_note.svg"
                            color: Theme.primary
                        }
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 4

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("Your Library is Empty")
                            font.pixelSize: 18
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: qsTr("Scan a folder on your computer to import audio tracks")
                            font.pixelSize: 12
                            color: Theme.textMuted
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 12

                        Rectangle {
                            implicitWidth: emptyAddRow.implicitWidth + 28
                            implicitHeight: 38
                            radius: 19
                            color: Theme.primary
                            scale: emptyAddMouse.pressed ? 0.94 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            RowLayout {
                                id: emptyAddRow
                                anchors.centerIn: parent
                                spacing: 8
                                SvgIcon {
                                    width: 15
                                    height: 15
                                    source: "qrc:/assets/icons/folder_plus.svg"
                                    color: Theme.colorOnPrimary
                                }
                                Text {
                                    text: qsTr("Add Music Folder")
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: Theme.colorOnPrimary
                                }
                            }

                            MouseArea {
                                id: emptyAddMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: LibraryManager.openFolderDialog()
                            }
                        }
                    }
                }
            }

            // ----------------------------------------------------------------
            // Common Delegate: M3 Track Capsule Card
            // ----------------------------------------------------------------
            Component {
                id: trackCapsuleDelegate

                Rectangle {
                    id: trackCard
                    width: ListView.view ? (ListView.view.width - 32) : parent.width
                    height: 56
                    radius: 14
                    readonly property bool isCurrent: AudioEngine.currentTrack === model.path
                    readonly property bool isSelected: libraryRoot.isTrackSelected(model.path)
                    color: isSelected
                           ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
                           : (isCurrent
                              ? Theme.surfaceContainerHighest
                              : (cardMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainerLow))
                    border.width: isSelected ? 1.5 : (isCurrent ? 1.5 : (cardMouse.containsMouse ? 1 : 0))
                    border.color: isSelected ? Theme.primary : (isCurrent ? Theme.primary : (cardMouse.containsMouse ? Theme.outlineVariant : "transparent"))

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 16
                        spacing: 12

                        // Left Slot: Sequence Number / Play Icon / Volume indicator
                        Item {
                            width: 26
                            height: parent.height

                            Text {
                                anchors.centerIn: parent
                                visible: !trackCard.isCurrent && !cardMouse.containsMouse
                                text: (index + 1).toString()
                                font.pixelSize: 12
                                color: Theme.textMuted
                            }

                            SvgIcon {
                                anchors.centerIn: parent
                                visible: trackCard.isCurrent
                                width: 15
                                height: 15
                                source: "qrc:/assets/icons/volume_up.svg"
                                color: Theme.primary
                            }

                            SvgIcon {
                                anchors.centerIn: parent
                                visible: !trackCard.isCurrent && cardMouse.containsMouse
                                width: 14
                                height: 14
                                source: "qrc:/assets/icons/play.svg"
                                color: Theme.primary
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (libraryRoot.selectedGroup) {
                                        var q = LibraryManager.getTrackPaths(LibraryManager.filteredTracks);
                                        LibraryManager.playTrack(model.path, q);
                                    } else {
                                        LibraryManager.playTrack(model.path);
                                    }
                                }
                            }
                        }

                        // Square Cover Thumbnail (40x40)
                        Rectangle {
                            width: 40
                            height: 40
                            radius: 8
                            color: Theme.surfaceContainer
                            clip: true

                            RoundedImage {
                                anchors.fill: parent
                                radius: 8
                                source: model.coverUrl || ""
                                fallbackColor: Theme.surfaceContainer
                                fallbackIcon: "qrc:/assets/icons/music_note.svg"
                                fallbackIconColor: Theme.textMuted
                                fallbackIconSize: 18
                            }
                        }

                        // Middle Details: Title & "Artist · Album"
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: model.title || model.path.split(/[/\\]/).pop()
                                font.pixelSize: 13
                                font.bold: true
                                color: trackCard.isCurrent ? Theme.primary : Theme.textPrimary
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: {
                                    var a = model.artist || "";
                                    var alb = model.album || "";
                                    if (a && alb) return a + " · " + alb;
                                    if (a) return a;
                                    if (alb) return alb;
                                    return "—";
                                }
                                font.pixelSize: 11
                                color: Theme.textMuted
                                elide: Text.ElideRight
                            }
                        }

                        // Right Slot: Format Badge Pill & Monospace Duration
                        RowLayout {
                            spacing: 12
                            Layout.alignment: Qt.AlignVCenter

                            Rectangle {
                                radius: 4
                                color: Theme.primaryContainer
                                implicitWidth: formatBadgeText.implicitWidth + 12
                                implicitHeight: 20

                                Text {
                                    id: formatBadgeText
                                    anchors.centerIn: parent
                                    text: (model.format || "MP3").toUpperCase()
                                    font.pixelSize: 10
                                    font.bold: true
                                    font.family: "monospace"
                                    color: Theme.primary
                                }
                            }

                            Text {
                                Layout.preferredWidth: 46
                                width: 46
                                horizontalAlignment: Text.AlignRight
                                text: libraryRoot.formatDuration(model.durationMs)
                                font.pixelSize: 11
                                font.family: "monospace"
                                color: Theme.textMuted
                            }
                        }
                    }

                    MouseArea {
                        id: cardMouse
                        anchors.fill: parent
                        hoverEnabled: ListView.view ? !ListView.view.moving : true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.RightButton) {
                                libraryRoot.handleTrackContextMenu(cardMouse, mouse, index, model.path, model.title, model.artist, "library", ListView.view ? ListView.view.model : null);
                            } else {
                                if (mouse.modifiers & Qt.ControlModifier) {
                                    libraryRoot.handleTrackClick(mouse, index, model.path, ListView.view ? ListView.view.model : null);
                                } else if (mouse.modifiers & Qt.ShiftModifier) {
                                    libraryRoot.handleTrackClick(mouse, index, model.path, ListView.view ? ListView.view.model : null);
                                } else {
                                    libraryRoot.clearSelection();
                                    if (libraryRoot.selectedGroup) {
                                        var q = LibraryManager.getTrackPaths(LibraryManager.filteredTracks);
                                        LibraryManager.playTrack(model.path, q);
                                    } else {
                                        LibraryManager.playTrack(model.path);
                                    }
                                }
                            }
                        }
                        onDoubleClicked: (mouse) => {
                            if (mouse.button === Qt.LeftButton) {
                                if (libraryRoot.selectedGroup) {
                                    var q = LibraryManager.getTrackPaths(LibraryManager.filteredTracks);
                                    LibraryManager.playTrack(model.path, q);
                                } else {
                                    LibraryManager.playTrack(model.path);
                                }
                            }
                        }
                    }
                }
            }

            // ----------------------------------------------------------------
            // B. Drill-Down Group Details Component (Lazy Loaded)
            // ----------------------------------------------------------------
            Component {
                id: detailsTabComponent

                Item {
                    id: detailsTabRoot
                    anchors.fill: parent
                    anchors.leftMargin: 32
                    anchors.rightMargin: 0

                    function ensureTopPosition() {
                        filteredTracksView.contentY = 0;
                        filteredTracksView.positionViewAtBeginning();
                    }

                    Timer {
                        id: settleTopTimer
                        interval: 40
                        repeat: false
                        onTriggered: detailsTabRoot.ensureTopPosition()
                    }

                    Connections {
                        target: libraryRoot
                        function onSelectedGroupChanged() {
                            if (libraryRoot.selectedGroup != null) {
                                detailsTabRoot.ensureTopPosition();
                                settleTopTimer.restart();
                            }
                        }
                    }

                    Connections {
                        target: LibraryManager
                        function onFilteredTracksChanged() {
                            detailsTabRoot.ensureTopPosition();
                            settleTopTimer.restart();
                        }
                        function onArtistAlbumsChanged() {
                            detailsTabRoot.ensureTopPosition();
                            settleTopTimer.restart();
                        }
                    }

                    ListView {
                        id: filteredTracksView
                        anchors.fill: parent
                        anchors.topMargin: 8
                        anchors.rightMargin: 0
                        spacing: 6
                        clip: true
                        reuseItems: true
                        cacheBuffer: 240
                        boundsBehavior: Flickable.StopAtBounds
                        model: LibraryManager.filteredTracks
                        delegate: trackCapsuleDelegate

                        MouseArea {
                            anchors.fill: parent
                            z: -1
                            onClicked: (mouse) => {
                                if (!(mouse.modifiers & Qt.ControlModifier) && !(mouse.modifiers & Qt.ShiftModifier)) {
                                    libraryRoot.clearSelection();
                                }
                            }
                        }

                        onCountChanged: {
                            detailsTabRoot.ensureTopPosition();
                            settleTopTimer.restart();
                        }

                        onContentHeightChanged: {
                            if (contentY < 40) {
                                detailsTabRoot.ensureTopPosition();
                            }
                        }

                        Component.onCompleted: {
                            detailsTabRoot.ensureTopPosition();
                            settleTopTimer.restart();
                        }

                        ScrollBar.vertical: M3ScrollBar {}

                        header: ColumnLayout {
                            width: filteredTracksView.width - 32
                            spacing: 16

                        Item { height: 2 }

                        // 1. Group Hero Banner
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 88
                            radius: 20
                            color: Theme.surfaceContainerLow
                            border.width: 1
                            border.color: Theme.borderSubtle

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 20
                                anchors.rightMargin: 20
                                spacing: 18

                                // Cover or Icon
                                Rectangle {
                                    width: 56
                                    height: 56
                                    radius: libraryRoot.selectedGroup && libraryRoot.selectedGroup.type === "artist" ? 28 : 12
                                    color: Theme.surfaceContainerHigh
                                    clip: true

                                    RoundedImage {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        source: (libraryRoot.selectedGroup && libraryRoot.selectedGroup.coverUrl) || ""
                                        fallbackColor: Theme.surfaceContainerHigh
                                        fallbackIcon: {
                                            if (!libraryRoot.selectedGroup) return "qrc:/assets/icons/music.svg";
                                            if (libraryRoot.selectedGroup.type === "album") return "qrc:/assets/icons/album.svg";
                                            if (libraryRoot.selectedGroup.type === "artist") return "qrc:/assets/icons/artist.svg";
                                            return "qrc:/assets/icons/folder.svg";
                                        }
                                        fallbackIconColor: Theme.primary
                                        fallbackIconSize: 24
                                    }
                                }

                                // Texts
                                ColumnLayout {
                                    spacing: 3
                                    Layout.fillWidth: true

                                    Text {
                                        text: libraryRoot.selectedGroup ? libraryRoot.selectedGroup.name : ""
                                        font.pixelSize: 18
                                        font.bold: true
                                        color: Theme.textPrimary
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: libraryRoot.selectedGroup ? libraryRoot.selectedGroup.subTitle : ""
                                        font.pixelSize: 12
                                        color: Theme.textMuted
                                    }
                                }

                                // Play All Button
                                Rectangle {
                                    implicitWidth: playAllRow.implicitWidth + 24
                                    implicitHeight: 38
                                    radius: 19
                                    color: Theme.primary
                                    scale: playAllMouse.pressed ? 0.94 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 100 } }

                                    RowLayout {
                                        id: playAllRow
                                        anchors.centerIn: parent
                                        spacing: 6

                                        SvgIcon {
                                            width: 14
                                            height: 14
                                            source: "qrc:/assets/icons/play.svg"
                                            color: Theme.colorOnPrimary
                                        }

                                        Text {
                                            text: qsTr("Play All")
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: Theme.colorOnPrimary
                                        }
                                    }

                                    MouseArea {
                                        id: playAllMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (!libraryRoot.selectedGroup) return;
                                            if (libraryRoot.selectedGroup.type === "album") {
                                                LibraryManager.playAlbum(libraryRoot.selectedGroup.name);
                                            } else if (libraryRoot.selectedGroup.type === "artist") {
                                                LibraryManager.playArtist(libraryRoot.selectedGroup.name);
                                            } else if (libraryRoot.selectedGroup.type === "folder") {
                                                LibraryManager.playFolder(libraryRoot.selectedGroup.path);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 2. Featured Albums Section (For artist drill-down)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            visible: !!(libraryRoot.selectedGroup && libraryRoot.selectedGroup.type === "artist" && LibraryManager.artistAlbums && LibraryManager.artistAlbums.count() > 0)

                            Text {
                                text: qsTr("Featured Albums") + " (" + (LibraryManager.artistAlbums ? LibraryManager.artistAlbums.count() : 0) + ")"
                                font.pixelSize: 15
                                font.bold: true
                                color: Theme.textPrimary
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: 14

                                Repeater {
                                    model: (libraryRoot.selectedGroup && libraryRoot.selectedGroup.type === "artist") ? LibraryManager.artistAlbums : null

                                    delegate: Rectangle {
                                        width: 160
                                        height: 215
                                        radius: 16
                                        color: albMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainerLow
                                        border.width: 1
                                        border.color: Theme.borderSubtle
                                        scale: albMouse.pressed ? 0.96 : (albMouse.containsMouse ? 1.02 : 1.0)

                                        Behavior on scale { NumberAnimation { duration: 150 } }
                                        Behavior on color { ColorAnimation { duration: 150 } }

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            spacing: 8

                                            Rectangle {
                                                width: parent.width
                                                height: width
                                                radius: 12
                                                color: Theme.surfaceContainer
                                                clip: true

                                                RoundedImage {
                                                    anchors.fill: parent
                                                    radius: 12
                                                    source: model.coverUrl || ""
                                                    fallbackColor: Theme.surfaceContainer
                                                    fallbackIcon: "qrc:/assets/icons/album.svg"
                                                    fallbackIconColor: Theme.primary
                                                    fallbackIconSize: 32
                                                }
                                            }

                                            Text {
                                                width: parent.width
                                                text: model.name
                                                font.pixelSize: 12
                                                font.bold: true
                                                color: Theme.textPrimary
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: libraryRoot.formatCount(model.trackCount)
                                                font.pixelSize: 11
                                                font.bold: true
                                                color: Theme.primary
                                            }
                                        }

                                        MouseArea {
                                            id: albMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                LibraryManager.filterTracksByAlbum(model.name, model.artist);
                                                libraryRoot.selectedGroup = {
                                                    type: "album",
                                                    name: model.name,
                                                    subTitle: model.artist + " • " + libraryRoot.formatCount(model.trackCount),
                                                    coverUrl: model.coverUrl
                                                };
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // 3. Section Title for All Tracks (When in artist view)
                        RowLayout {
                            Layout.fillWidth: true
                            visible: !!(libraryRoot.selectedGroup && libraryRoot.selectedGroup.type === "artist")

                            Text {
                                text: qsTr("All Tracks") + " (" + (LibraryManager.filteredTracks ? LibraryManager.filteredTracks.count : 0) + ")"
                                font.pixelSize: 15
                                font.bold: true
                                color: Theme.textPrimary
                            }
                        }

                        Item { height: 2 }
                    }
                }
            }
        }

            // ----------------------------------------------------------------
            // C. Root Tab 1: Single Tracks (Titles) Component
            // ----------------------------------------------------------------
            Component {
                id: titlesTabComponent

                Item {
                    anchors.fill: parent

                // List Table View Mode
                ListView {
                    id: trackListView
                    visible: ConfigManager.tracksViewMode === "list"
                    anchors.fill: parent
                    anchors.topMargin: 8
                    anchors.rightMargin: 0
                    spacing: 6
                    clip: true
                    reuseItems: true
                    cacheBuffer: 240
                    boundsBehavior: Flickable.StopAtBounds
                    model: LibraryManager.allTracks
                    delegate: trackCapsuleDelegate

                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        onClicked: (mouse) => {
                            if (!(mouse.modifiers & Qt.ControlModifier) && !(mouse.modifiers & Qt.ShiftModifier)) {
                                libraryRoot.clearSelection();
                            }
                        }
                    }

                    ScrollBar.vertical: M3ScrollBar {}
                }

                Loader {
                    anchors.fill: parent
                    active: libraryRoot.gridModeLoaded
                    sourceComponent: trackGridComponent
                }
            }
        }

        // ----------------------------------------------------------------
        // Track Grid Component (Lazy Loaded for Tracks Tab)
        // ----------------------------------------------------------------
        Component {
            id: trackGridComponent

            GridView {
                id: trackGrid
                visible: ConfigManager.tracksViewMode !== "list"
                readonly property bool isCardMode: ConfigManager.tracksViewMode === "card"
                anchors.fill: parent
                anchors.topMargin: 8
                anchors.rightMargin: 0
                clip: true
                reuseItems: true
                cacheBuffer: 240
                boundsBehavior: Flickable.StopAtBounds
                readonly property int cardCols: {
                    var c = Math.floor((width + 16) / (160 + 16));
                    return Math.max(2, Math.min(c, 6));
                }
                readonly property int compactCols: {
                    var w = width;
                    if (w < 380) return 2;
                    if (w < 540) return 3;
                    if (w < 700) return 4;
                    if (w < 880) return 5;
                    if (w < 1060) return 6;
                    if (w < 1240) return 7;
                    return Math.max(7, Math.floor(w / 170));
                }
                readonly property int cols: isCardMode ? cardCols : compactCols
                cellWidth: Math.floor((width - 32) / cols)
                cellHeight: isCardMode ? (cellWidth + 66) : (cellWidth + 58)
                model: LibraryManager.allTracks

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    onClicked: (mouse) => {
                        if (!(mouse.modifiers & Qt.ControlModifier) && !(mouse.modifiers & Qt.ShiftModifier)) {
                            libraryRoot.clearSelection();
                        }
                    }
                }

                ScrollBar.vertical: M3ScrollBar {}

                    delegate: Item {
                        width: trackGrid.cellWidth
                        height: trackGrid.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: trackGrid.isCardMode ? 8 : 6
                            radius: trackGrid.isCardMode ? 24 : 16
                            readonly property bool isCurrent: AudioEngine.currentTrack === model.path
                            readonly property bool isSelected: libraryRoot.isTrackSelected(model.path)
                            color: isSelected
                                   ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
                                   : (isCurrent ? Theme.surfaceContainerHighest : (tgMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainerLow))
                            border.width: isSelected ? 2 : (isCurrent ? 2 : 1)
                            border.color: isSelected ? Theme.primary : (isCurrent ? Theme.primary : Theme.borderSubtle)
                            scale: tgMouse.pressed ? 0.96 : (tgMouse.containsMouse ? 1.02 : 1.0)

                            Behavior on scale { NumberAnimation { duration: 150 } }
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Column {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: trackGrid.isCardMode ? 12 : 10
                                spacing: 8

                                // Square Cover
                                Rectangle {
                                    width: parent.width
                                    height: width
                                    radius: trackGrid.isCardMode ? 16 : 14
                                    color: Theme.surfaceContainer

                                    RoundedImage {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        source: model.coverUrl || ""
                                        fallbackIcon: "qrc:/assets/icons/music_note.svg"
                                    }

                                    // Hover Play Button (Bottom-right corner)
                                    Rectangle {
                                        id: trkPlayBtnCircle
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.rightMargin: 8
                                        anchors.bottomMargin: 8
                                        width: 36
                                        height: 36
                                        radius: 18
                                        color: trkPlayMouse.pressed ? Qt.darker(Theme.primary, 1.1) : Theme.primary
                                        scale: trkPlayMouse.pressed ? 0.92 : (trkPlayMouse.containsMouse ? 1.08 : 1.0)
                                        visible: opacity > 0
                                        opacity: (tgMouse.containsMouse || trkPlayMouse.containsMouse) ? 1.0 : 0.0
                                        z: 10

                                        Behavior on opacity { NumberAnimation { duration: 120 } }
                                        Behavior on scale { NumberAnimation { duration: 100 } }
                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        SvgIcon {
                                            anchors.centerIn: parent
                                            anchors.horizontalCenterOffset: 1
                                            width: 14
                                            height: 14
                                            source: "qrc:/assets/icons/play.svg"
                                            color: Theme.colorOnPrimary
                                        }

                                        MouseArea {
                                            id: trkPlayMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            preventStealing: true
                                            propagateComposedEvents: false
                                            onClicked: (mouse) => {
                                                mouse.accepted = true;
                                                LibraryManager.playTrack(model.path);
                                            }
                                        }
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: model.title || model.path.split(/[/\\]/).pop()
                                    font.pixelSize: trackGrid.isCardMode ? 12 : 13
                                    font.bold: true
                                    color: parent.parent.isCurrent ? Theme.primary : Theme.textPrimary
                                    elide: Text.ElideRight
                                }

                                RowLayout {
                                    width: parent.width
                                    spacing: 6

                                    Text {
                                        Layout.fillWidth: true
                                        text: model.artist || "—"
                                        font.pixelSize: 11
                                        color: Theme.textMuted
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        visible: !!model.format
                                        radius: 4
                                        color: Theme.surfaceContainerHighest
                                        implicitWidth: codecBadgeText.implicitWidth + 8
                                        implicitHeight: 16
                                        Layout.alignment: Qt.AlignVCenter

                                        Text {
                                            id: codecBadgeText
                                            anchors.centerIn: parent
                                            text: (model.format || "").toUpperCase()
                                            font.pixelSize: 9
                                            font.bold: true
                                            font.family: "monospace"
                                            color: Theme.primary
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: tgMouse
                                anchors.fill: parent
                                hoverEnabled: !trackGrid.moving
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        libraryRoot.handleTrackContextMenu(tgMouse, mouse, index, model.path, model.title, model.artist, "library", trackGrid.model);
                                    } else {
                                        if (mouse.modifiers & Qt.ControlModifier) {
                                            libraryRoot.handleTrackClick(mouse, index, model.path, trackGrid.model);
                                        } else if (mouse.modifiers & Qt.ShiftModifier) {
                                            libraryRoot.handleTrackClick(mouse, index, model.path, trackGrid.model);
                                        } else {
                                            libraryRoot.clearSelection();
                                            LibraryManager.playTrack(model.path);
                                        }
                                    }
                                }
                                onDoubleClicked: (mouse) => {
                                    if (mouse.button === Qt.LeftButton) {
                                        LibraryManager.playTrack(model.path);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ----------------------------------------------------------------
            // D. Root Tab 2: Albums Component (Lazy Loaded)
            // ----------------------------------------------------------------
            Component {
                id: albumsTabComponent

                Item {
                    anchors.fill: parent

                // Grid View Mode
                GridView {
                    id: albumGrid
                    visible: ConfigManager.albumsViewMode !== "list"
                    readonly property bool isCardMode: ConfigManager.albumsViewMode === "card"
                    anchors.fill: parent
                    anchors.topMargin: 8
                    anchors.rightMargin: 0
                    clip: true
                    reuseItems: true
                    cacheBuffer: 240
                    boundsBehavior: Flickable.StopAtBounds
                    readonly property int cardCols: {
                        var c = Math.floor((width + 16) / (160 + 16));
                        return Math.max(2, Math.min(c, 6));
                    }
                    readonly property int compactCols: {
                        var w = width;
                        if (w < 380) return 2;
                        if (w < 540) return 3;
                        if (w < 700) return 4;
                        if (w < 880) return 5;
                        if (w < 1060) return 6;
                        if (w < 1240) return 7;
                        return Math.max(7, Math.floor(w / 170));
                    }
                    readonly property int cols: isCardMode ? cardCols : compactCols
                    cellWidth: Math.floor((width - 32) / cols)
                    cellHeight: isCardMode ? (cellWidth + 66) : (cellWidth + 58)
                    model: LibraryManager.allAlbums

                    ScrollBar.vertical: M3ScrollBar {}

                    delegate: Item {
                        width: albumGrid.cellWidth
                        height: albumGrid.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: albumGrid.isCardMode ? 8 : 6
                            radius: 24
                            color: agMouse.pressed ? Theme.surfaceContainerHighest : (agMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                            border.width: 1
                            border.color: Theme.borderSubtle
                            scale: agMouse.pressed ? 0.98 : (agMouse.containsMouse ? 1.02 : 1.0)

                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            MouseArea {
                                id: agMouse
                                anchors.fill: parent
                                hoverEnabled: !albumGrid.moving
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    if (!(mouse.modifiers & Qt.ControlModifier) && !(mouse.modifiers & Qt.ShiftModifier)) {
                                        libraryRoot.clearSelection();
                                        LibraryManager.filterTracksByAlbum(model.name, model.artist);
                                        libraryRoot.selectedGroup = {
                                            type: "album",
                                            name: model.name,
                                            subTitle: (model.artist || "") + " • " + libraryRoot.formatCount(model.trackCount),
                                            coverUrl: model.coverUrl
                                        };
                                    }
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10

                                // Square Cover
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: width
                                    radius: 16
                                    color: Theme.surfaceContainerHigh
                                    clip: true

                                    RoundedImage {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        source: model.coverUrl || ""
                                        fallbackColor: Theme.surfaceContainerHigh
                                        fallbackIcon: "qrc:/assets/icons/album.svg"
                                        fallbackIconColor: Theme.primary
                                        fallbackIconSize: 38
                                    }

                                    // Track Count Badge Pill (Bottom-Left of Cover)
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.margins: 8
                                        height: 20
                                        width: albBadgeText.implicitWidth + 14
                                        radius: 6
                                        color: "#B3000000"

                                        Text {
                                            id: albBadgeText
                                            anchors.centerIn: parent
                                            text: model.trackCount + " " + qsTr("Tracks")
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                            color: "#FFFFFF"
                                        }
                                    }

                                    // Quick Play Button Overlay (Full cover overlay with bottom-right 36x36 play button)
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 16
                                        color: "#30000000"
                                        visible: opacity > 0
                                        opacity: (agMouse.containsMouse || albPlayBtnMouse.containsMouse) ? 1.0 : 0.0

                                        Behavior on opacity {
                                            NumberAnimation { duration: 120 }
                                        }

                                        Rectangle {
                                            id: albPlayBtnCircle
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            anchors.rightMargin: 8
                                            anchors.bottomMargin: 8
                                            width: 36
                                            height: 36
                                            radius: 18
                                            color: albPlayBtnMouse.pressed ? Qt.darker(Theme.primary, 1.1) : Theme.primary
                                            scale: albPlayBtnMouse.pressed ? 0.92 : (albPlayBtnMouse.containsMouse ? 1.08 : 1.0)
                                            z: 10

                                            Behavior on scale { NumberAnimation { duration: 100 } }
                                            Behavior on color { ColorAnimation { duration: 100 } }

                                            SvgIcon {
                                                anchors.centerIn: parent
                                                anchors.horizontalCenterOffset: 1
                                                width: 14
                                                height: 14
                                                source: "qrc:/assets/icons/play.svg"
                                                color: Theme.colorOnPrimary
                                            }

                                            MouseArea {
                                                id: albPlayBtnMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                preventStealing: true
                                                propagateComposedEvents: false
                                                onClicked: (mouse) => {
                                                    mouse.accepted = true;
                                                    LibraryManager.playAlbum(model.name, model.artist);
                                                }
                                            }
                                        }
                                    }
                                }

                                // Compact two-line text beneath cover (Left-aligned)
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    // Album Title (12px, bold, white, elide right)
                                    Text {
                                        Layout.fillWidth: true
                                        text: model.name
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: (agMouse.containsMouse || albPlayBtnMouse.containsMouse) ? Theme.primary : Theme.textPrimary
                                        elide: Text.ElideRight
                                    }

                                    // Artist Name (11px, gray, elide right)
                                    Text {
                                        Layout.fillWidth: true
                                        text: model.artist || "—"
                                        font.pixelSize: 11
                                        color: Theme.textMuted
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }

                // List View Mode
                ListView {
                    id: albumList
                    visible: ConfigManager.albumsViewMode === "list"
                    anchors.fill: parent
                    anchors.topMargin: 8
                    anchors.rightMargin: 0
                    spacing: 6
                    clip: true
                    reuseItems: true
                    cacheBuffer: 240
                    boundsBehavior: Flickable.StopAtBounds
                    model: LibraryManager.allAlbums

                    ScrollBar.vertical: M3ScrollBar {}

                    delegate: Rectangle {
                        width: albumList.width - 32
                        height: 56
                        radius: 14
                        color: alMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainerLow
                        border.width: 1
                        border.color: Theme.borderSubtle
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 16
                            spacing: 14

                            // 40x40 Cover Thumbnail
                            Rectangle {
                                width: 40
                                height: 40
                                radius: 8
                                color: Theme.surfaceContainerHigh

                                RoundedImage {
                                    anchors.fill: parent
                                    radius: 8
                                    source: model.coverUrl || ""
                                    fallbackIcon: "qrc:/assets/icons/album.svg"
                                }
                            }

                            // Details
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: model.name
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: model.artist || "—"
                                    font.pixelSize: 11
                                    color: Theme.textMuted
                                    elide: Text.ElideRight
                                }
                            }

                            // Track Count Pill Badge
                            Rectangle {
                                radius: 6
                                color: Theme.surfaceContainerHigh
                                implicitWidth: albCountText.implicitWidth + 12
                                implicitHeight: 22

                                Text {
                                    id: albCountText
                                    anchors.centerIn: parent
                                    text: libraryRoot.formatCount(model.trackCount)
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: Theme.primary
                                }
                            }

                            // Quick Play Button on Hover
                            Rectangle {
                                width: 32
                                height: 32
                                radius: 16
                                color: Theme.primary
                                opacity: alMouse.containsMouse ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 120 } }

                                SvgIcon {
                                    anchors.centerIn: parent
                                    width: 12
                                    height: 12
                                    source: "qrc:/assets/icons/play.svg"
                                    color: Theme.colorOnPrimary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        LibraryManager.playAlbum(model.name, model.artist);
                                    }
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
                            id: alMouse
                            anchors.fill: parent
                            hoverEnabled: !albumList.moving
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                LibraryManager.filterTracksByAlbum(model.name, model.artist);
                                libraryRoot.selectedGroup = {
                                    type: "album",
                                    name: model.name,
                                    subTitle: model.artist + " • " + libraryRoot.formatCount(model.trackCount),
                                    coverUrl: model.coverUrl
                                };
                            }
                        }
                    }
                }
            }
        }

            // ----------------------------------------------------------------
            // E. Root Tab 3: Artists Component (Lazy Loaded)
            // ----------------------------------------------------------------
            Component {
                id: artistsTabComponent

                Item {
                    anchors.fill: parent

                // Grid View Mode
                GridView {
                    id: artistGrid
                    visible: ConfigManager.artistsViewMode !== "list"
                    readonly property bool isCardMode: ConfigManager.artistsViewMode === "card"
                    anchors.fill: parent
                    anchors.topMargin: 8
                    anchors.rightMargin: 0
                    clip: true
                    reuseItems: true
                    cacheBuffer: 240
                    boundsBehavior: Flickable.StopAtBounds
                    readonly property int cardCols: {
                        var c = Math.floor((width + 16) / (160 + 16));
                        return Math.max(2, Math.min(c, 6));
                    }
                    readonly property int compactCols: {
                        var w = width;
                        if (w < 380) return 2;
                        if (w < 540) return 3;
                        if (w < 700) return 4;
                        if (w < 880) return 5;
                        if (w < 1060) return 6;
                        if (w < 1240) return 7;
                        return Math.max(7, Math.floor(w / 170));
                    }
                    readonly property int cols: isCardMode ? cardCols : compactCols
                    cellWidth: Math.floor((width - 32) / cols)
                    cellHeight: isCardMode ? 216 : 196
                    model: LibraryManager.allArtists

                    ScrollBar.vertical: M3ScrollBar {}

                    delegate: Item {
                        width: artistGrid.cellWidth
                        height: artistGrid.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: artistGrid.isCardMode ? 8 : 6
                            radius: artistGrid.isCardMode ? 24 : 16
                            color: artgMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainerLow
                            border.width: 1
                            border.color: Theme.borderSubtle
                            scale: artgMouse.pressed ? 0.96 : (artgMouse.containsMouse ? 1.02 : 1.0)

                            Behavior on scale { NumberAnimation { duration: 150 } }
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Column {
                                anchors.centerIn: parent
                                width: parent.width - 24
                                spacing: 8

                                // Circular Avatar
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: artistGrid.isCardMode ? 96 : 80
                                    height: width
                                    radius: width / 2
                                    color: Theme.surfaceContainer

                                    RoundedImage {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        source: model.coverUrl || ""
                                        fallbackIcon: "qrc:/assets/icons/artist.svg"
                                    }
                                }

                                Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: model.name
                                    font.pixelSize: artistGrid.isCardMode ? 12 : 13
                                    font.bold: true
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: libraryRoot.formatCount(model.trackCount)
                                    font.pixelSize: 11
                                    color: Theme.textMuted
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: artgMouse
                                anchors.fill: parent
                                hoverEnabled: !artistGrid.moving
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    LibraryManager.filterTracksByArtist(model.name);
                                    libraryRoot.selectedGroup = {
                                        type: "artist",
                                        name: model.name,
                                        subTitle: libraryRoot.formatCount(model.trackCount),
                                        coverUrl: model.coverUrl
                                    };
                                }
                            }
                        }
                    }
                }

                // List View Mode
                ListView {
                    id: artistList
                    visible: ConfigManager.artistsViewMode === "list"
                    anchors.fill: parent
                    anchors.topMargin: 8
                    anchors.rightMargin: 0
                    spacing: 6
                    clip: true
                    reuseItems: true
                    cacheBuffer: 240
                    boundsBehavior: Flickable.StopAtBounds
                    model: LibraryManager.allArtists

                    ScrollBar.vertical: M3ScrollBar {}

                    delegate: Rectangle {
                        width: artistList.width - 32
                        height: 56
                        radius: 14
                        color: artlMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainerLow
                        border.width: 1
                        border.color: Theme.borderSubtle
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 16
                            spacing: 14

                            // 40x40 Circular Avatar
                            Rectangle {
                                width: 40
                                height: 40
                                radius: 20
                                color: Theme.surfaceContainerHigh

                                RoundedImage {
                                    anchors.fill: parent
                                    radius: 20
                                    source: model.coverUrl || ""
                                    fallbackIcon: "qrc:/assets/icons/artist.svg"
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

                            // Track Count Pill Badge
                            Rectangle {
                                radius: 6
                                color: Theme.surfaceContainerHigh
                                implicitWidth: artCountText.implicitWidth + 12
                                implicitHeight: 22

                                Text {
                                    id: artCountText
                                    anchors.centerIn: parent
                                    text: libraryRoot.formatCount(model.trackCount)
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: Theme.primary
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
                            id: artlMouse
                            anchors.fill: parent
                            hoverEnabled: !artistList.moving
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                LibraryManager.filterTracksByArtist(model.name);
                                libraryRoot.selectedGroup = {
                                    type: "artist",
                                    name: model.name,
                                    subTitle: libraryRoot.formatCount(model.trackCount),
                                    coverUrl: model.coverUrl
                                };
                            }
                        }
                    }
                }
            }
        }

            // ----------------------------------------------------------------
            // F. Root Tab 4: Folders Component (Lazy Loaded)
            // ----------------------------------------------------------------
            Component {
                id: foldersTabComponent

                Item {
                    anchors.fill: parent

                // Grid View Mode
                GridView {
                    id: folderGrid
                    visible: ConfigManager.foldersViewMode !== "list"
                    readonly property bool isCardMode: ConfigManager.foldersViewMode === "card"
                    anchors.fill: parent
                    anchors.topMargin: 8
                    anchors.rightMargin: 0
                    clip: true
                    reuseItems: true
                    cacheBuffer: 240
                    boundsBehavior: Flickable.StopAtBounds
                    readonly property int cardCols: {
                        var c = Math.floor((width + 16) / (160 + 16));
                        return Math.max(2, Math.min(c, 6));
                    }
                    readonly property int compactCols: {
                        var w = width;
                        if (w < 380) return 2;
                        if (w < 540) return 3;
                        if (w < 700) return 4;
                        if (w < 880) return 5;
                        if (w < 1060) return 6;
                        if (w < 1240) return 7;
                        return Math.max(7, Math.floor(w / 170));
                    }
                    readonly property int cols: isCardMode ? cardCols : compactCols
                    cellWidth: Math.floor((width - 32) / cols)
                    cellHeight: isCardMode ? 216 : 196
                    model: LibraryManager.allFolders

                    ScrollBar.vertical: M3ScrollBar {}

                    delegate: Item {
                        width: folderGrid.cellWidth
                        height: folderGrid.cellHeight

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: folderGrid.isCardMode ? 8 : 6
                            radius: folderGrid.isCardMode ? 24 : 16
                            color: fldGMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainerLow
                            border.width: 1
                            border.color: Theme.borderSubtle
                            scale: fldGMouse.pressed ? 0.96 : (fldGMouse.containsMouse ? 1.02 : 1.0)

                            Behavior on scale { NumberAnimation { duration: 150 } }
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Column {
                                anchors.centerIn: parent
                                width: parent.width - 24
                                spacing: 8

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: folderGrid.isCardMode ? 96 : 80
                                    height: width
                                    radius: width / 2
                                    color: Theme.primaryContainer

                                    SvgIcon {
                                        anchors.centerIn: parent
                                        width: folderGrid.isCardMode ? 42 : 36
                                        height: width
                                        source: "qrc:/assets/icons/folder.svg"
                                        color: Theme.primary
                                    }
                                }

                                Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: model.name
                                    font.pixelSize: folderGrid.isCardMode ? 12 : 13
                                    font.bold: true
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: libraryRoot.formatCount(model.trackCount)
                                    font.pixelSize: 11
                                    color: Theme.textMuted
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: fldGMouse
                                anchors.fill: parent
                                hoverEnabled: !folderGrid.moving
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    LibraryManager.filterTracksByFolder(model.path);
                                    libraryRoot.selectedGroup = {
                                        type: "folder",
                                        name: model.name,
                                        path: model.path,
                                        subTitle: model.path + " (" + libraryRoot.formatCount(model.trackCount) + ")",
                                        coverUrl: ""
                                    };
                                }
                            }
                        }
                    }
                }

                // List View Mode
                ListView {
                    id: folderList
                    visible: ConfigManager.foldersViewMode === "list"
                    anchors.fill: parent
                    anchors.topMargin: 8
                    anchors.rightMargin: 0
                    spacing: 6
                    clip: true
                    reuseItems: true
                    cacheBuffer: 240
                    boundsBehavior: Flickable.StopAtBounds
                    model: LibraryManager.allFolders

                    ScrollBar.vertical: M3ScrollBar {}

                    delegate: Rectangle {
                        width: folderList.width - 32
                        height: 56
                        radius: 14
                        color: fldLMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainerLow
                        border.width: 1
                        border.color: Theme.borderSubtle
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 16
                            spacing: 14

                            // 40x40 Circle Folder Icon
                            Rectangle {
                                width: 40
                                height: 40
                                radius: 20
                                color: Theme.primaryContainer

                                SvgIcon {
                                    anchors.centerIn: parent
                                    width: 20
                                    height: 20
                                    source: "qrc:/assets/icons/folder.svg"
                                    color: Theme.primary
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: model.name
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: model.path
                                    font.pixelSize: 11
                                    color: Theme.textMuted
                                    elide: Text.ElideRight
                                }
                            }

                            // Track Count Pill Badge
                            Rectangle {
                                radius: 6
                                color: Theme.surfaceContainerHigh
                                implicitWidth: fldCountText.implicitWidth + 12
                                implicitHeight: 22

                                Text {
                                    id: fldCountText
                                    anchors.centerIn: parent
                                    text: libraryRoot.formatCount(model.trackCount)
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: Theme.primary
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
                            id: fldLMouse
                            anchors.fill: parent
                            hoverEnabled: !folderList.moving
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                LibraryManager.filterTracksByFolder(model.path);
                                libraryRoot.selectedGroup = {
                                    type: "folder",
                                    name: model.name,
                                    path: model.path,
                                    subTitle: model.path + " (" + libraryRoot.formatCount(model.trackCount) + ")",
                                    coverUrl: ""
                                };
                            }
                        }
                    }
                }
            }
        }

        // ====================================================================
        // Active View Containers with Material 3 Motion Transitions
        // ====================================================================

        // --------------------------------------------------------------------
        // 1. Drill-Down Group Details View (Album / Artist / Folder details)
        // --------------------------------------------------------------------
        Item {
            id: detailsContainer
            objectName: "detailsContainer"
            z: 2
            anchors.fill: parent
            visible: libraryRoot.selectedGroup != null && LibraryManager.trackCount > 0
            opacity: libraryRoot.selectedGroup != null ? 1.0 : 0.0
            enabled: libraryRoot.selectedGroup != null
            transform: Translate {
                y: libraryRoot.selectedGroup != null ? 0 : 16
                Behavior on y {
                    NumberAnimation {
                        duration: 280
                        easing.type: libraryRoot.selectedGroup != null ? Easing.OutBack : Easing.OutCubic
                        easing.overshoot: 1.1
                    }
                }
            }
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            Loader {
                anchors.fill: parent
                active: libraryRoot.detailsLoaded
                sourceComponent: detailsTabComponent
            }
        }

        // --------------------------------------------------------------------
        // 2. Root Tabs Container (Titles, Albums, Artists, Folders)
        // --------------------------------------------------------------------
        Item {
            id: rootTabsContainer
            objectName: "rootTabsContainer"
            z: 1
            anchors.fill: parent
            visible: libraryRoot.selectedGroup == null && LibraryManager.trackCount > 0
            opacity: libraryRoot.selectedGroup == null ? 1.0 : 0.0
            enabled: libraryRoot.selectedGroup == null
            transform: Translate {
                y: libraryRoot.selectedGroup == null ? 0 : -10
                Behavior on y {
                    NumberAnimation {
                        duration: 280
                        easing.type: libraryRoot.selectedGroup == null ? Easing.OutBack : Easing.OutCubic
                        easing.overshoot: 1.1
                    }
                }
            }
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            // Tab 1: Single Tracks (Tracks)
            Item {
                id: titlesTabItem
                anchors.fill: parent
                anchors.leftMargin: 32
                anchors.rightMargin: 0
                readonly property bool isTabActive: libraryRoot.currentTab === "tracks" || libraryRoot.currentTab === "titles"
                visible: isTabActive || opacity > 0
                opacity: isTabActive ? 1.0 : 0.0
                enabled: isTabActive
                transform: Translate {
                    y: titlesTabItem.isTabActive ? 0 : 12
                    Behavior on y {
                        NumberAnimation {
                            duration: 260
                            easing.type: titlesTabItem.isTabActive ? Easing.OutBack : Easing.OutCubic
                            easing.overshoot: 1.12
                        }
                    }
                }
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                Loader {
                    anchors.fill: parent
                    active: true
                    sourceComponent: titlesTabComponent
                }
            }

            // Tab 2: Albums
            Item {
                id: albumsTabItem
                anchors.fill: parent
                anchors.leftMargin: 32
                anchors.rightMargin: 0
                visible: libraryRoot.currentTab === "albums" || opacity > 0
                opacity: libraryRoot.currentTab === "albums" ? 1.0 : 0.0
                enabled: libraryRoot.currentTab === "albums"
                transform: Translate {
                    y: libraryRoot.currentTab === "albums" ? 0 : 12
                    Behavior on y {
                        NumberAnimation {
                            duration: 260
                            easing.type: libraryRoot.currentTab === "albums" ? Easing.OutBack : Easing.OutCubic
                            easing.overshoot: 1.12
                        }
                    }
                }
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                Loader {
                    anchors.fill: parent
                    active: !!libraryRoot.loadedTabs["albums"]
                    sourceComponent: albumsTabComponent
                }
            }

            // Tab 3: Artists
            Item {
                id: artistsTabItem
                anchors.fill: parent
                anchors.leftMargin: 32
                anchors.rightMargin: 0
                visible: libraryRoot.currentTab === "artists" || opacity > 0
                opacity: libraryRoot.currentTab === "artists" ? 1.0 : 0.0
                enabled: libraryRoot.currentTab === "artists"
                transform: Translate {
                    y: libraryRoot.currentTab === "artists" ? 0 : 12
                    Behavior on y {
                        NumberAnimation {
                            duration: 260
                            easing.type: libraryRoot.currentTab === "artists" ? Easing.OutBack : Easing.OutCubic
                            easing.overshoot: 1.12
                        }
                    }
                }
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                Loader {
                    anchors.fill: parent
                    active: !!libraryRoot.loadedTabs["artists"]
                    sourceComponent: artistsTabComponent
                }
            }

            // Tab 4: Folders
            Item {
                id: foldersTabItem
                anchors.fill: parent
                anchors.leftMargin: 32
                anchors.rightMargin: 0
                visible: libraryRoot.currentTab === "folders" || opacity > 0
                opacity: libraryRoot.currentTab === "folders" ? 1.0 : 0.0
                enabled: libraryRoot.currentTab === "folders"
                transform: Translate {
                    y: libraryRoot.currentTab === "folders" ? 0 : 12
                    Behavior on y {
                        NumberAnimation {
                            duration: 260
                            easing.type: libraryRoot.currentTab === "folders" ? Easing.OutBack : Easing.OutCubic
                            easing.overshoot: 1.12
                        }
                    }
                }
                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                Loader {
                    anchors.fill: parent
                    active: !!libraryRoot.loadedTabs["folders"]
                    sourceComponent: foldersTabComponent
                }
            }
        }
    }
}
}
