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

ScrollView {
    id: homeScroll
    contentWidth: availableWidth
    clip: true

    background: Rectangle {
        color: Theme.surface

        MouseArea {
            anchors.fill: parent
            onClicked: (mouse) => {
                if (!(mouse.modifiers & Qt.ControlModifier) && !(mouse.modifiers & Qt.ShiftModifier)) {
                    homeScroll.clearSelection();
                }
            }
        }
    }

    Component.onCompleted: {
        if (contentItem) {
            contentItem.boundsBehavior = Flickable.StopAtBounds;
        }
    }

    ScrollBar.vertical: M3ScrollBar {}

    signal navigateTab(string tabId)
    signal trackPlayRequested(string title, string artist)
    signal navigateToAlbum(string albumName, string artistName, string coverUrl, int trackCount)

    function getGreeting() {
        var hour = new Date().getHours();
        if (hour >= 5 && hour < 12) return qsTr("Good morning");
        if (hour >= 12 && hour < 18) return qsTr("Good afternoon");
        if (hour >= 18 && hour < 23) return qsTr("Good evening");
        return qsTr("Good night, have a nice rest");
    }

    property bool isRefreshing: false
    property var selectedTrackPaths: []

    function clearSelection() {
        selectedTrackPaths = [];
    }

    Item {
        width: homeScroll.availableWidth
        implicitHeight: contentCol.implicitHeight + 64

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: (mouse) => {
                if (!(mouse.modifiers & Qt.ControlModifier) && !(mouse.modifiers & Qt.ShiftModifier)) {
                    homeScroll.clearSelection();
                }
            }
        }

        ColumnLayout {
            id: contentCol
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width - 48, 1200)
            spacing: 32

            readonly property int trackCols: homeScroll.availableWidth < 700 ? 2 : 4
            readonly property real trackCardWidth: Math.floor((width - (trackCols - 1) * 16) / trackCols)

            readonly property int albumCols: {
                var cols = Math.floor((width + 16) / (150 + 16));
                return Math.max(2, Math.min(cols, 6));
            }
            readonly property real albumCardWidth: Math.floor((width - (albumCols - 1) * 16) / albumCols)

            Item { height: 16 }

            // ================================================================
            // 1. Welcome Header (迎宾栏：用户信息 + 纯矢量调色盘主题切换按钮)
            // ================================================================
            Item {
                Layout.fillWidth: true
                implicitHeight: 56

                // Left: Avatar + Nickname + Dynamic Greeting
                RowLayout {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 16

                    Rectangle {
                        width: 48
                        height: 48
                        radius: 24
                        color: Theme.surfaceContainerHigh
                        clip: true

                        RoundedImage {
                            anchors.fill: parent
                            radius: 24
                            visible: ConfigManager.avatar !== ""
                            source: ConfigManager.avatar
                        }

                        SvgIcon {
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            visible: ConfigManager.avatar === ""
                            source: "qrc:/assets/icons/person.svg"
                            color: Theme.primary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: homeScroll.navigateTab("settings")
                        }
                    }

                    ColumnLayout {
                        spacing: 4

                        Text {
                            text: ConfigManager.nickname
                            font.pixelSize: 18
                            font.bold: true
                            color: Theme.textPrimary
                        }

                        Text {
                            text: homeScroll.getGreeting()
                            font.pixelSize: 13
                            color: Theme.textMuted
                        }
                    }
                }

                // Right: M3 纯矢量主题切换按钮 (深浅色无缝双向切换)
                Rectangle {
                    id: themeBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 36
                    radius: 18
                    color: themeMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                    scale: themeMouse.pressed ? 0.92 : 1.0

                    Behavior on scale {
                        NumberAnimation { duration: 150; easing.type: Easing.OutBack }
                    }
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    SvgIcon {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        source: Theme.isDark ? "qrc:/assets/icons/sun.svg" : "qrc:/assets/icons/moon.svg"
                        color: themeMouse.containsMouse ? Theme.primary : Theme.iconNeutral
                    }

                    MouseArea {
                        id: themeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ConfigManager.setThemeMode(Theme.isDark ? "light" : "dark");
                        }
                    }
                }
            }

            // ================================================================
            // 2. Empty Library State (当本地曲库为 0 时：仅显示空库状态引导卡片)
            // ================================================================
            Rectangle {
                visible: LibraryManager.trackCount === 0
                Layout.fillWidth: true
                Layout.preferredHeight: 320
                radius: 24
                color: Theme.surfaceContainer

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 16

                    SvgIcon {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        source: "qrc:/assets/icons/music_note.svg"
                        color: Theme.primary
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("No local tracks found. Click to scan a folder.")
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        color: Theme.textPrimary
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Scan a local music folder to build your library")
                        font.pixelSize: 13
                        color: Theme.textMuted
                    }

                    Item { height: 4 }

                    Rectangle {
                        id: scanBtn
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredHeight: 44
                        Layout.preferredWidth: scanBtnRow.implicitWidth + 36
                        radius: 22
                        color: scanFolderMouse.pressed ? Qt.darker(Theme.primary, 1.1) : (scanFolderMouse.containsMouse ? Qt.lighter(Theme.primary, 1.1) : Theme.primary)
                        scale: scanFolderMouse.pressed ? 0.96 : (scanFolderMouse.containsMouse ? 1.02 : 1.0)

                        Behavior on scale {
                            NumberAnimation { duration: 120 }
                        }
                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        RowLayout {
                            id: scanBtnRow
                            anchors.centerIn: parent
                            spacing: 8

                            SvgIcon {
                                Layout.preferredWidth: 18
                                Layout.preferredHeight: 18
                                source: "qrc:/assets/icons/folder_open.svg"
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
                            id: scanFolderMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: LibraryManager.openFolderDialog()
                        }
                    }
                }
            }

            // ================================================================
            // 3. Featured Tracks (精选单曲推荐流：严格限制 4 项，64px 胶囊)
            // ================================================================
            ColumnLayout {
                visible: LibraryManager.trackCount > 0
                Layout.fillWidth: true
                spacing: 16

                // Section Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: qsTr("Discover Music")
                        font.pixelSize: 16
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    // Refresh Button
                    Rectangle {
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: refreshRow.implicitWidth + 20
                        radius: 14
                        color: refreshMouse.pressed ? Theme.surfaceContainerHighest : (refreshMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                        scale: refreshMouse.pressed ? 0.94 : 1.0

                        Behavior on scale {
                            NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
                        }
                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        RowLayout {
                            id: refreshRow
                            anchors.centerIn: parent
                            spacing: 6

                            SvgIcon {
                                Layout.preferredWidth: 12
                                Layout.preferredHeight: 12
                                source: "qrc:/assets/icons/refresh.svg"
                                color: Theme.primary
                                rotation: homeScroll.isRefreshing ? 360 : 0

                                Behavior on rotation {
                                    NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
                                }
                            }

                            Text {
                                text: qsTr("Daily Mix")
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: Theme.primary
                            }
                        }

                        MouseArea {
                            id: refreshMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                homeScroll.isRefreshing = true;
                                LibraryManager.refreshRecommendations();
                                refreshTimer.restart();
                            }
                        }

                        Timer {
                            id: refreshTimer
                            interval: 400
                            onTriggered: homeScroll.isRefreshing = false
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // View All Button
                    Rectangle {
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: showAllRow.implicitWidth + 20
                        radius: 14
                        color: showAllMouse.pressed ? Theme.surfaceContainerHighest : (showAllMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent")
                        scale: showAllMouse.pressed ? 0.94 : 1.0

                        Behavior on scale {
                            NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
                        }
                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        RowLayout {
                            id: showAllRow
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: qsTr("Show All")
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: Theme.primary
                            }

                            SvgIcon {
                                Layout.preferredWidth: 10
                                Layout.preferredHeight: 10
                                source: "qrc:/assets/icons/chevron_right.svg"
                                color: Theme.primary
                            }
                        }

                        MouseArea {
                            id: showAllMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: homeScroll.navigateTab("library")
                        }
                    }
                }

                // 4 Horizontal Capsule Cards
                Flow {
                    Layout.fillWidth: true
                    width: contentCol.width
                    spacing: 16

                    Repeater {
                        model: LibraryManager.recommendedTracks

                        Rectangle {
                            id: trackCard
                            width: contentCol.trackCardWidth
                            height: 64
                            radius: 32
                            readonly property bool isSelected: homeScroll.selectedTrackPaths.indexOf(model.path) !== -1
                            color: isSelected
                                   ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
                                   : (trackCardMouse.pressed ? Theme.surfaceContainerHighest : (trackCardMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer))
                            border.width: isSelected ? 1.5 : 0
                            border.color: isSelected ? Theme.primary : "transparent"
                            scale: trackCardMouse.pressed ? 0.98 : (trackCardMouse.containsMouse ? 1.015 : 1.0)

                            Behavior on scale {
                                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                            }
                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 16
                                anchors.topMargin: 8
                                anchors.bottomMargin: 8
                                spacing: 14

                                // Pure Circular Avatar Cover (48x48, radius: width / 2, concentric with capsule end)
                                RoundedImage {
                                    Layout.preferredWidth: 48
                                    Layout.preferredHeight: 48
                                    radius: width / 2
                                    source: (model.coverUrl && model.hasCover) ? model.coverUrl : ""
                                    fallbackColor: Theme.surfaceContainerHigh
                                    fallbackIcon: "qrc:/assets/icons/music.svg"
                                    fallbackIconColor: Theme.primary
                                    fallbackIconSize: 22

                                    // Play overlay on hover (pure circular mask)
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: width / 2
                                        color: "#50000000"
                                        visible: opacity > 0
                                        opacity: trackCardMouse.containsMouse ? 1.0 : 0.0

                                        Behavior on opacity {
                                            NumberAnimation { duration: 120 }
                                        }

                                        SvgIcon {
                                            anchors.centerIn: parent
                                            anchors.horizontalCenterOffset: 1
                                            width: 14
                                            height: 14
                                            source: "qrc:/assets/icons/play.svg"
                                            color: Theme.colorOnPrimary
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: LibraryManager.playRecommendedTrack(index)
                                    }
                                }

                                // Track Title & Artist (vertically centered)
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 3

                                    Text {
                                        Layout.fillWidth: true
                                        text: model.title
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: trackCardMouse.containsMouse ? Theme.primary : Theme.textPrimary
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: model.artist
                                        font.pixelSize: 11
                                        color: Theme.textMuted
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            MouseArea {
                                id: trackCardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        homeScroll.selectedTrackPaths = [model.path];
                                        var pos = trackCardMouse.mapToItem(null, mouse.x, mouse.y);
                                        if (typeof m3ContextMenu !== "undefined") {
                                            m3ContextMenu.show(pos.x, pos.y, [model.path], model.title, model.artist, "home");
                                        }
                                    } else {
                                        if (mouse.modifiers & Qt.ControlModifier) {
                                            var arr = homeScroll.selectedTrackPaths.slice();
                                            var idx = arr.indexOf(model.path);
                                            if (idx !== -1) arr.splice(idx, 1);
                                            else arr.push(model.path);
                                            homeScroll.selectedTrackPaths = arr;
                                        } else {
                                            homeScroll.clearSelection();
                                            LibraryManager.playRecommendedTrack(index);
                                        }
                                    }
                                }
                                onDoubleClicked: (mouse) => {
                                    if (mouse.button === Qt.LeftButton) {
                                        LibraryManager.playRecommendedTrack(index);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ================================================================
            // 4. Featured Albums (精选专辑推荐网格：严格最多 11 项，卡片宽 140~160px)
            // ================================================================
            ColumnLayout {
                visible: LibraryManager.trackCount > 0
                Layout.fillWidth: true
                spacing: 16

                // Section Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Text {
                        text: qsTr("Featured Albums")
                        font.pixelSize: 16
                        font.bold: true
                        color: Theme.textPrimary
                    }

                    Item { Layout.fillWidth: true }

                    // View All Button
                    Rectangle {
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: showAllAlbumsRow.implicitWidth + 20
                        radius: 14
                        color: showAllAlbumsMouse.pressed ? Theme.surfaceContainerHighest : (showAllAlbumsMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent")
                        scale: showAllAlbumsMouse.pressed ? 0.94 : 1.0

                        Behavior on scale {
                            NumberAnimation { duration: 100; easing.type: Easing.OutQuad }
                        }
                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        RowLayout {
                            id: showAllAlbumsRow
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: qsTr("Show All")
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: Theme.primary
                            }

                            SvgIcon {
                                Layout.preferredWidth: 10
                                Layout.preferredHeight: 10
                                source: "qrc:/assets/icons/chevron_right.svg"
                                color: Theme.primary
                            }
                        }

                        MouseArea {
                            id: showAllAlbumsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: homeScroll.navigateTab("library")
                        }
                    }
                }

                // Grid of Albums (Adaptive ~140px - 160px cards, max 11, no heavy gray tray)
                Flow {
                    id: albumFlow
                    Layout.fillWidth: true
                    width: contentCol.width
                    spacing: 16

                    Repeater {
                        model: LibraryManager.recommendedAlbums

                        Rectangle {
                            id: albumCard
                            width: contentCol.albumCardWidth
                            height: albumCol.implicitHeight + 28
                            radius: 24
                            color: albumCardMouse.pressed ? Theme.surfaceContainerHighest : (albumCardMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)
                            scale: albumCardMouse.pressed ? 0.98 : (albumCardMouse.containsMouse ? 1.02 : 1.0)
                            border.width: 1
                            border.color: Theme.borderSubtle

                            Behavior on scale {
                                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                            }
                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }

                            // Card-level click to navigate to album details
                            MouseArea {
                                id: albumCardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: (mouse) => {
                                    if (!(mouse.modifiers & Qt.ControlModifier) && !(mouse.modifiers & Qt.ShiftModifier)) {
                                        homeScroll.clearSelection();
                                        homeScroll.navigateToAlbum(model.name, model.artist, model.coverUrl, model.trackCount);
                                    }
                                }
                            }

                            ColumnLayout {
                                id: albumCol
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 10

                                // 1:1 Square Album Cover with Smooth Rounded Corners (r=16)
                                Rectangle {
                                    id: albumCoverWrap
                                    Layout.preferredWidth: albumCard.width - 28
                                    Layout.preferredHeight: albumCard.width - 28
                                    radius: 16
                                    color: Theme.surfaceContainerHigh
                                    clip: true

                                    RoundedImage {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        source: model.coverUrl ? model.coverUrl : ""
                                        fallbackColor: Theme.surfaceContainerHigh
                                        fallbackIcon: "qrc:/assets/icons/album.svg"
                                        fallbackIconColor: Theme.primary
                                        fallbackIconSize: 38
                                    }

                                    // Bottom-left translucent pill badge (曲目数胶囊，#B3000000)
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.margins: 8
                                        height: 20
                                        width: badgeText.implicitWidth + 14
                                        radius: 6
                                        color: "#B3000000"

                                        Text {
                                            id: badgeText
                                            anchors.centerIn: parent
                                            text: model.trackCount + " " + qsTr("Tracks")
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                            color: "#FFFFFF"
                                        }
                                    }

                                    // Hover Play Button Overlay (Full cover overlay with bottom-right 36x36 play button)
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 16
                                        color: "#30000000"
                                        visible: opacity > 0
                                        opacity: (albumCardMouse.containsMouse || playBtnMouse.containsMouse) ? 1.0 : 0.0

                                        Behavior on opacity {
                                            NumberAnimation { duration: 120 }
                                        }

                                        Rectangle {
                                            id: playBtnCircle
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            anchors.rightMargin: 8
                                            anchors.bottomMargin: 8
                                            width: 36
                                            height: 36
                                            radius: 18
                                            color: playBtnMouse.pressed ? Qt.darker(Theme.primary, 1.1) : Theme.primary
                                            scale: playBtnMouse.pressed ? 0.92 : (playBtnMouse.containsMouse ? 1.08 : 1.0)
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
                                                id: playBtnMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                preventStealing: true
                                                propagateComposedEvents: false
                                                onClicked: (mouse) => {
                                                    mouse.accepted = true;
                                                    LibraryManager.playRecommendedAlbum(index);
                                                }
                                            }
                                        }
                                    }
                                }

                                // Compact two-line text beneath cover (Left-aligned, bounded by 14px padding)
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    // Album Title (12px, bold, white, elide right)
                                    Text {
                                        Layout.fillWidth: true
                                        text: model.name
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: (albumCardMouse.containsMouse || playBtnMouse.containsMouse) ? Theme.primary : Theme.textPrimary
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
            }

            Item { height: 24 }
        }
    }
}
