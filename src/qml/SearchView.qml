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
    id: searchRoot

    signal navigateToArtist(string artistName, string coverUrl)
    signal navigateToAlbum(string albumName, string artistName, string coverUrl)
    signal navigateToLibraryTab(string tabId)

    function formatDuration(ms) {
        if (!ms || ms <= 0) return "--:--";
        var totalSec = Math.floor(ms / 1000);
        var m = Math.floor(totalSec / 60);
        var s = totalSec % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    function formatCount(count) {
        return (count || 0) + " " + qsTr("tracks");
    }

    Timer {
        id: searchDebounceTimer
        interval: 180
        repeat: false
        onTriggered: {
            LibraryManager.search(searchField.text);
        }
    }

    readonly property bool hasQuery: searchField.text.trim().length > 0
    readonly property real topAnchorY: 144
    readonly property real centerAnchorY: Math.max(220, Math.round(searchRoot.height * 0.35))

    onHasQueryChanged: {
        if (!hasQuery) {
            searchFlickable.contentY = 0;
        }
    }

    // Top Title Bar Safety Mask (48px height, 100% Theme.surface)
    Rectangle {
        id: titleBarMask
        objectName: "searchTitleBarMask"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 48
        color: Theme.surface
        z: 100
    }

    // ========================================================================
    // 1. Standard Page Header: Title + Subtitle (与曲库/设置页 100% 绝对对齐: x=32, y=64)
    // ========================================================================
    ColumnLayout {
        id: searchHeaderCol
        objectName: "searchHeaderCol"
        anchors.top: parent.top
        anchors.topMargin: 64
        anchors.left: parent.left
        anchors.leftMargin: 32
        spacing: 4
        z: 90

        Text {
            text: qsTr("Search")
            font.pixelSize: 28
            font.bold: true
            color: Theme.textPrimary
        }

        Text {
            text: qsTr("Search tracks, artists, and albums")
            font.pixelSize: 13
            font.weight: Font.Normal
            color: Theme.textMuted
        }
    }

    // ========================================================================
    // 2. Google-Style Hero Search Bar (空状态居中，输入内容流畅升空)
    // ========================================================================
    Item {
        id: searchBarContainer
        anchors.horizontalCenter: parent.horizontalCenter
        width: hasQuery ? (parent.width - 64) : Math.min(parent.width - 64, 640)
        height: 48
        z: 50

        y: hasQuery ? topAnchorY : centerAnchorY

        Behavior on y {
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutCubic
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutCubic
            }
        }

        // Material 3 Capsule Search Bar
        Rectangle {
            anchors.fill: parent
            radius: 24
            color: Theme.surfaceContainer
            border.width: searchField.activeFocus ? 2 : 1
            border.color: searchField.activeFocus ? Theme.primary : Theme.borderSubtle
            Behavior on border.color { ColorAnimation { duration: 150 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 12
                spacing: 12

                SvgIcon {
                    width: 18
                    height: 18
                    source: "qrc:/assets/icons/search.svg"
                    color: searchField.activeFocus ? Theme.primary : Theme.textMuted
                }

                TextField {
                    id: searchField
                    objectName: "searchField"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    background: null
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                    placeholderText: qsTr("Search tracks, artists or albums...")
                    placeholderTextColor: Theme.textMuted
                    selectByMouse: true
                    onTextChanged: {
                        searchDebounceTimer.restart();
                    }
                    Keys.onEscapePressed: {
                        text = "";
                        focus = false;
                        searchDebounceTimer.stop();
                        LibraryManager.clearSearch();
                    }
                    Keys.onReturnPressed: {
                        var trimmed = text.trim();
                        if (trimmed.length > 0) {
                            ConfigManager.addSearchHistory(trimmed);
                            searchDebounceTimer.stop();
                            LibraryManager.search(trimmed);
                        }
                    }
                }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: clearMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                    visible: searchField.text.length > 0

                    SvgIcon {
                        anchors.centerIn: parent
                        width: 10
                        height: 10
                        source: "qrc:/assets/icons/win_close.svg"
                        color: Theme.textSecondary
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchField.text = "";
                            searchDebounceTimer.stop();
                            LibraryManager.clearSearch();
                            searchField.forceActiveFocus();
                        }
                    }
                }
            }
        }
    }

    // ========================================================================
    // 3. Empty State Area (快捷分类胶囊、历史标签与推荐推荐，居中平衡布局)
    // ========================================================================
    Flickable {
        id: emptyStateFlickable
        anchors.top: searchBarContainer.bottom
        anchors.topMargin: 20
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - 64, 640)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        clip: true
        contentWidth: width
        contentHeight: emptyCol.implicitHeight + 20
        boundsBehavior: Flickable.StopAtBounds
        visible: opacity > 0
        opacity: hasQuery ? 0.0 : 1.0

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        ScrollBar.vertical: M3ScrollBar {}

        ColumnLayout {
            id: emptyCol
            width: parent.width - 16
            spacing: 24

            // 3.1 Quick Category Shortcuts (Google style)
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12

                // Tracks Shortcut
                Rectangle {
                    height: 34
                    radius: 17
                    color: trackChipMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer
                    border.width: 1
                    border.color: trackChipMouse.containsMouse ? Theme.primary : Theme.borderSubtle
                    implicitWidth: trackChipRow.implicitWidth + 24

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        id: trackChipRow
                        anchors.centerIn: parent
                        spacing: 8
                        SvgIcon {
                            width: 14
                            height: 14
                            source: "qrc:/assets/icons/music_note.svg"
                            color: trackChipMouse.containsMouse ? Theme.primary : Theme.textSecondary
                        }
                        Text {
                            text: qsTr("Tracks")
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: trackChipMouse.containsMouse ? Theme.primary : Theme.textPrimary
                        }
                    }

                    MouseArea {
                        id: trackChipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: searchRoot.navigateToLibraryTab("tracks")
                    }
                }

                // Albums Shortcut
                Rectangle {
                    height: 34
                    radius: 17
                    color: albumChipMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer
                    border.width: 1
                    border.color: albumChipMouse.containsMouse ? Theme.primary : Theme.borderSubtle
                    implicitWidth: albumChipRow.implicitWidth + 24

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        id: albumChipRow
                        anchors.centerIn: parent
                        spacing: 8
                        SvgIcon {
                            width: 14
                            height: 14
                            source: "qrc:/assets/icons/album.svg"
                            color: albumChipMouse.containsMouse ? Theme.primary : Theme.textSecondary
                        }
                        Text {
                            text: qsTr("Albums")
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: albumChipMouse.containsMouse ? Theme.primary : Theme.textPrimary
                        }
                    }

                    MouseArea {
                        id: albumChipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: searchRoot.navigateToLibraryTab("albums")
                    }
                }

                // Artists Shortcut
                Rectangle {
                    height: 34
                    radius: 17
                    color: artistChipMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer
                    border.width: 1
                    border.color: artistChipMouse.containsMouse ? Theme.primary : Theme.borderSubtle
                    implicitWidth: artistChipRow.implicitWidth + 24

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        id: artistChipRow
                        anchors.centerIn: parent
                        spacing: 8
                        SvgIcon {
                            width: 14
                            height: 14
                            source: "qrc:/assets/icons/artist.svg"
                            color: artistChipMouse.containsMouse ? Theme.primary : Theme.textSecondary
                        }
                        Text {
                            text: qsTr("Artists")
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            color: artistChipMouse.containsMouse ? Theme.primary : Theme.textPrimary
                        }
                    }

                    MouseArea {
                        id: artistChipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: searchRoot.navigateToLibraryTab("artists")
                    }
                }
            }

            // 3.1 Search History Chips (Visible when query is empty)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                visible: ConfigManager.searchHistory.length > 0

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: qsTr("Search History")
                        font.pixelSize: 13
                        font.bold: true
                        color: Theme.textSecondary
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: qsTr("Clear")
                        font.pixelSize: 12
                        color: clearHistMouse.containsMouse ? Theme.primary : Theme.textMuted

                        MouseArea {
                            id: clearHistMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ConfigManager.clearSearchHistory()
                        }
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: ConfigManager.searchHistory

                        delegate: Rectangle {
                            height: 32
                            radius: 16
                            color: chipMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer
                            border.width: 1
                            border.color: Theme.borderSubtle
                            implicitWidth: chipRow.implicitWidth + 24

                            RowLayout {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    text: modelData
                                    font.pixelSize: 12
                                    color: Theme.textPrimary
                                }

                                Rectangle {
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: removeChipMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                                    SvgIcon {
                                        anchors.centerIn: parent
                                        width: 8
                                        height: 8
                                        source: "qrc:/assets/icons/win_close.svg"
                                        color: Theme.textMuted
                                    }

                                    MouseArea {
                                        id: removeChipMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: ConfigManager.removeSearchHistory(modelData)
                                    }
                                }
                            }

                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    searchField.text = modelData;
                                    LibraryManager.search(modelData);
                                }
                            }
                        }
                    }
                }
            }

            // 3.2 Default Quick View: Recommendations (When query is empty)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                visible: LibraryManager.recommendedTracks && LibraryManager.recommendedTracks.count > 0

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: qsTr("Recommendations")
                        font.pixelSize: 15
                        font.bold: true
                        color: Theme.textPrimary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: LibraryManager.recommendedTracks
                        delegate: trackCapsuleDelegate
                    }
                }
            }

            // 3.3 Subtle Guide Text (When no history and no recommendations)
            Item {
                visible: ConfigManager.searchHistory.length === 0 && (!LibraryManager.recommendedTracks || LibraryManager.recommendedTracks.count === 0)
                Layout.fillWidth: true
                height: 120

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    SvgIcon {
                        Layout.alignment: Qt.AlignHCenter
                        width: 32
                        height: 32
                        source: "qrc:/assets/icons/search.svg"
                        color: Theme.textMuted
                        opacity: 0.4
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Type to search your local music library")
                        font.pixelSize: 13
                        color: Theme.textMuted
                    }
                }
            }
        }
    }

    // ========================================================================
    // 4. Search Results Scrollable Area (输入搜索词后平滑淡入)
    // ========================================================================
    Flickable {
        id: searchFlickable
        objectName: "searchFlickable"
        anchors.top: parent.top
        anchors.topMargin: topAnchorY + 48 + 16
        anchors.left: parent.left
        anchors.leftMargin: 32
        anchors.right: parent.right
        anchors.rightMargin: 0
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        clip: true
        contentWidth: width
        contentHeight: contentCol.implicitHeight + 40
        boundsBehavior: Flickable.StopAtBounds
        visible: opacity > 0
        opacity: hasQuery ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }

        ScrollBar.vertical: M3ScrollBar {}

        ColumnLayout {
            id: contentCol
            width: parent.width - 32
            spacing: 24

            // 4.1 No Results Found State
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 24
                implicitHeight: 200
                radius: 24
                color: Theme.surfaceContainer
                border.width: 1
                border.color: Theme.borderSubtle
                visible: searchField.text.trim().length > 0 && LibraryManager.searchTotalMatches === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12

                    SvgIcon {
                        Layout.alignment: Qt.AlignHCenter
                        width: 44
                        height: 44
                        source: "qrc:/assets/icons/search.svg"
                        color: Theme.primary
                        opacity: 0.35
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("No Results")
                        font.pixelSize: 18
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("No matching music found for \"%1\"").arg(searchField.text.trim())
                        font.pixelSize: 13
                        color: Theme.textSecondary
                    }
                }
            }

            // 4.2 Matched Tracks Section
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                visible: searchField.text.trim().length > 0 && LibraryManager.searchTracks && LibraryManager.searchTracks.count > 0

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: qsTr("Tracks") + " (" + (LibraryManager.searchTracks ? LibraryManager.searchTracks.count : 0) + ")"
                        font.pixelSize: 15
                        font.bold: true
                        color: Theme.textPrimary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: LibraryManager.searchTracks
                        delegate: trackCapsuleDelegate
                    }
                }
            }

            // 4.3 Matched Albums Section (Card Grid)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                visible: searchField.text.trim().length > 0 && LibraryManager.searchAlbums && LibraryManager.searchAlbums.count() > 0

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: qsTr("Albums") + " (" + (LibraryManager.searchAlbums ? LibraryManager.searchAlbums.count() : 0) + ")"
                        font.pixelSize: 15
                        font.bold: true
                        color: Theme.textPrimary
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 14

                    Repeater {
                        model: LibraryManager.searchAlbums
                        delegate: albumCardDelegate
                    }
                }
            }

            // 4.4 Matched Artists Section (Card Grid with Round Avatars)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                visible: searchField.text.trim().length > 0 && LibraryManager.searchArtists && LibraryManager.searchArtists.count() > 0

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: qsTr("Artists") + " (" + (LibraryManager.searchArtists ? LibraryManager.searchArtists.count() : 0) + ")"
                        font.pixelSize: 15
                        font.bold: true
                        color: Theme.textPrimary
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 14

                    Repeater {
                        model: LibraryManager.searchArtists
                        delegate: artistCardDelegate
                    }
                }
            }

            Item { height: 16 }
        }
    }

    // ------------------------------------------------------------------------
    // Delegates
    // ------------------------------------------------------------------------

    // A. Track Capsule Delegate (56px high, M3 style)
    Component {
        id: trackCapsuleDelegate

        Rectangle {
            id: trackCard
            Layout.fillWidth: true
            implicitWidth: contentCol.width
            height: 56
            radius: 14
            readonly property bool isCurrent: AudioEngine.currentTrack === model.path
            color: isCurrent
                   ? Theme.surfaceContainerHighest
                   : (cardMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainerLow)
            border.width: isCurrent ? 1.5 : (cardMouse.containsMouse ? 1 : 0)
            border.color: isCurrent ? Theme.primary : (cardMouse.containsMouse ? Theme.outlineVariant : "transparent")

            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 16
                spacing: 12

                // Sequence / Play Status
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
                }

                // Cover (40x40)
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

                // Title & Subtitle
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

                // Format & Duration
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
                        text: searchRoot.formatDuration(model.durationMs)
                        font.pixelSize: 12
                        font.family: "monospace"
                        color: Theme.textMuted
                    }
                }
            }

            MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onDoubleClicked: {
                    var trimmed = searchField.text.trim();
                    if (trimmed.length > 0) ConfigManager.addSearchHistory(trimmed);
                    LibraryManager.playTrack(model.path);
                }
                onClicked: {
                    var trimmed = searchField.text.trim();
                    if (trimmed.length > 0) ConfigManager.addSearchHistory(trimmed);
                    LibraryManager.playTrack(model.path);
                }
            }
        }
    }

    // B. Album Card Delegate (Square Cover, Left-aligned text)
    Component {
        id: albumCardDelegate

        Rectangle {
            width: 160
            height: 226
            radius: 18
            color: albMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainerLow
            border.width: albMouse.containsMouse ? 1 : 0
            border.color: Theme.outlineVariant

            Behavior on color { ColorAnimation { duration: 150 } }

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                // Cover Image
                Rectangle {
                    width: parent.width
                    height: width
                    radius: 14
                    color: Theme.surfaceContainer
                    clip: true

                    RoundedImage {
                        anchors.fill: parent
                        radius: 14
                        source: model.coverUrl || ""
                        fallbackIcon: "qrc:/assets/icons/album.svg"
                    }

                    // Track Count Badge
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.margins: 6
                        radius: 4
                        color: "#B3000000"
                        implicitWidth: albCountText.implicitWidth + 8
                        implicitHeight: 18

                        Text {
                            id: albCountText
                            anchors.centerIn: parent
                            text: searchRoot.formatCount(model.trackCount)
                            font.pixelSize: 9
                            font.bold: true
                            color: "#FFFFFF"
                        }
                    }

                    // Quick Play Button
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 6
                        width: 32
                        height: 32
                        radius: 16
                        color: Theme.primary
                        visible: albMouse.containsMouse

                        SvgIcon {
                            anchors.centerIn: parent
                            width: 13
                            height: 13
                            source: "qrc:/assets/icons/play.svg"
                            color: Theme.colorOnPrimary
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var trimmed = searchField.text.trim();
                                if (trimmed.length > 0) ConfigManager.addSearchHistory(trimmed);
                                LibraryManager.playAlbum(model.name, model.artist);
                            }
                        }
                    }
                }

                // Album Title
                Text {
                    width: parent.width
                    text: model.name
                    font.pixelSize: 12
                    font.bold: true
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                }

                // Artist
                Text {
                    width: parent.width
                    text: model.artist
                    font.pixelSize: 11
                    color: Theme.textMuted
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: albMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var trimmed = searchField.text.trim();
                    if (trimmed.length > 0) ConfigManager.addSearchHistory(trimmed);
                    searchRoot.navigateToAlbum(model.name, model.artist, model.coverUrl);
                }
            }
        }
    }

    // C. Artist Card Delegate (Circular Avatar, Centered text)
    Component {
        id: artistCardDelegate

        Rectangle {
            width: 160
            height: 210
            radius: 18
            color: artMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainerLow
            border.width: artMouse.containsMouse ? 1 : 0
            border.color: Theme.outlineVariant

            Behavior on color { ColorAnimation { duration: 150 } }

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                // Circular Avatar
                Rectangle {
                    width: 130
                    height: 130
                    radius: 65
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Theme.surfaceContainer
                    clip: true

                    RoundedImage {
                        anchors.fill: parent
                        radius: parent.radius
                        source: model.coverUrl || ""
                        fallbackIcon: "qrc:/assets/icons/artist.svg"
                    }
                }

                // Artist Name
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: model.name
                    font.pixelSize: 12
                    font.bold: true
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                }

                // Track Count
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: searchRoot.formatCount(model.trackCount)
                    font.pixelSize: 11
                    color: Theme.textMuted
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: artMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var trimmed = searchField.text.trim();
                    if (trimmed.length > 0) ConfigManager.addSearchHistory(trimmed);
                    searchRoot.navigateToArtist(model.name, model.coverUrl);
                }
            }
        }
    }
}
