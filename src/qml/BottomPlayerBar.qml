import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import rhx.audio 1.0
import rhx.library 1.0
import rhx.ui 1.0
import rhx.theme 1.0

Rectangle {
    id: playerBar
    height: 80
    color: Theme.surfaceContainerLow

    property bool isNowPlayingOpen: false
    property bool showTrans: true
    signal toggleNowPlayingRequested()
    signal toggleShowTransRequested()
    signal queueRequested()
    signal addToPlaylistRequested(string trackPath)

    // Reactive favorite state tracking
    property int favVersion: 0
    Connections {
        target: LibraryManager
        function onFavoritesChanged() {
            playerBar.favVersion++;
        }
    }
    readonly property bool isCurrentFav: {
        playerBar.favVersion;
        return AudioEngine.currentTrack.length > 0 && LibraryManager.isFavorite(AudioEngine.currentTrack);
    }

    // 0: all, 1: one, 2: shuffle, 3: sequential
    property int playMode: AudioEngine.playMode

    // Top subtle border line
    Rectangle {
        width: parent.width
        height: 1
        anchors.top: parent.top
        color: Theme.borderSubtle
    }

    // ------------------------------------------------------------------------
    // Top Seek Progress Line (Dynamic 2px~3px, Theme.primary, Hidden in NowPlaying)
    // ------------------------------------------------------------------------
    Item {
        id: seekArea
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: seekMouse.containsMouse ? 3 : 2
        visible: opacity > 0.0
        opacity: playerBar.isNowPlayingOpen ? 0.0 : 1.0
        enabled: !playerBar.isNowPlayingOpen

        Behavior on height {
            NumberAnimation { duration: 120 }
        }

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.surfaceContainerHighest
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: AudioEngine.durationMs > 0
                   ? Math.min(parent.width, Math.max(0, (AudioEngine.positionMs / AudioEngine.durationMs) * parent.width))
                   : 0
            color: Theme.primary
        }

        MouseArea {
            id: seekMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: function(mouse) {
                if (AudioEngine.durationMs > 0) {
                    var pct = Math.max(0.0, Math.min(1.0, mouse.x / width));
                    var targetMs = Math.floor(pct * AudioEngine.durationMs);
                    AudioEngine.seek(targetMs);
                }
            }
        }
    }

    // ------------------------------------------------------------------------
    // Bottom Bar Controls Layout (1:1 原版紧凑排版)
    // ------------------------------------------------------------------------
    RowLayout {
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        spacing: 16

        // Left: Track Info & Cover / Collapse Button (48x48)
        Item {
            Layout.preferredWidth: playerBar.isNowPlayingOpen ? 48 : 310
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignVCenter
            clip: true

            Behavior on Layout.preferredWidth {
                NumberAnimation {
                    duration: 260
                    easing.type: playerBar.isNowPlayingOpen ? Easing.OutCubic : Easing.OutBack
                    easing.overshoot: 1.1
                }
            }

            RowLayout {
                anchors.fill: parent
                spacing: 14

                // Thumbnail / Chevron Button Container (48x48)
                Item {
                    id: thumbnailContainer
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    Layout.alignment: Qt.AlignVCenter

                    // When NowPlaying is expanded: 48x48 rounded capsule with chevron_down.svg
                    Rectangle {
                        id: chevronCapsule
                        anchors.fill: parent
                        radius: 12
                        color: thumbMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                        visible: playerBar.isNowPlayingOpen
                        opacity: playerBar.isNowPlayingOpen ? 1.0 : 0.0

                        Behavior on opacity {
                            NumberAnimation { duration: 180 }
                        }
                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }

                        SvgIcon {
                            anchors.centerIn: parent
                            width: 20
                            height: 20
                            source: "qrc:/assets/icons/chevron_down.svg"
                            color: thumbMouse.containsMouse ? Theme.primary : Theme.iconNeutral
                        }
                    }

                    // When NowPlaying is collapsed: 48x48 Rounded Cover with 8px radius
                    Item {
                        id: coverThumbnail
                        anchors.fill: parent
                        visible: !playerBar.isNowPlayingOpen
                        opacity: playerBar.isNowPlayingOpen ? 0.0 : 1.0

                        Behavior on opacity {
                            NumberAnimation { duration: 180 }
                        }

                        RoundedImage {
                            anchors.fill: parent
                            radius: 8
                            source: (AudioEngine.hasCover && AudioEngine.currentCoverUrl.length > 0)
                                    ? AudioEngine.currentCoverUrl
                                    : ""
                            fallbackColor: Theme.surfaceContainer
                            fallbackIcon: "qrc:/assets/icons/music_note.svg"
                            fallbackIconColor: Theme.primary
                            fallbackIconSize: 22
                            opacity: thumbMouse.containsMouse ? 0.85 : 1.0

                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }
                        }
                    }

                    MouseArea {
                        id: thumbMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            playerBar.toggleNowPlayingRequested();
                        }
                    }
                }

                // Track Title & Artist Text Block (Hidden in NowPlaying to eliminate duplicate clutter)
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: textColumn.implicitHeight
                    Layout.alignment: Qt.AlignVCenter
                    visible: opacity > 0.0
                    opacity: playerBar.isNowPlayingOpen ? 0.0 : 1.0

                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }

                    ColumnLayout {
                        id: textColumn
                        anchors.fill: parent
                        spacing: 3

                        Text {
                            Layout.fillWidth: true
                            text: AudioEngine.currentTitle.length > 0 ? AudioEngine.currentTitle : "0rhxPlayer"
                            font.pixelSize: 14
                            font.bold: true
                            color: textMouse.containsMouse ? Theme.primary : Theme.textPrimary
                            elide: Text.ElideRight

                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: AudioEngine.currentArtist.length > 0 ? AudioEngine.currentArtist : qsTr("Ready")
                            font.pixelSize: 12
                            color: Theme.textMuted
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        id: textMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            playerBar.toggleNowPlayingRequested();
                        }
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }

        // Right: Control Icons Sequence
        RowLayout {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            spacing: 10

            // 0. Translation Toggle (Only visible when NowPlaying is expanded AND track has translation)
            Rectangle {
                visible: playerBar.isNowPlayingOpen && AudioEngine.lyrics.hasTranslation
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignVCenter
                radius: 16
                color: playerBar.showTrans
                       ? Theme.primaryContainer
                       : (transMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent")
                scale: transMouse.pressed ? 0.95 : 1.0

                Behavior on scale {
                    NumberAnimation { duration: 100 }
                }
                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                Text {
                    anchors.centerIn: parent
                    text: "译"
                    font.pixelSize: 13
                    font.bold: true
                    color: playerBar.showTrans ? Theme.colorOnPrimaryContainer : (transMouse.containsMouse ? Theme.textPrimary : Theme.textMuted)
                }

                MouseArea {
                    id: transMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: playerBar.toggleShowTransRequested()
                }
            }

            // 1. Playback Mode Button (4-State: all -> one -> shuffle -> sequential)
            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                Layout.alignment: Qt.AlignVCenter
                radius: 18
                color: modeMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                scale: modeMouse.pressed ? 0.90 : (modeMouse.containsMouse ? 1.08 : 1.0)

                Behavior on scale {
                    NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                }
                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                SvgIcon {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: {
                        switch (playerBar.playMode) {
                            case 2: return "qrc:/assets/icons/shuffle.svg";
                            case 3: return "qrc:/assets/icons/arrow_right_long.svg";
                            default: return "qrc:/assets/icons/repeat.svg";
                        }
                    }
                    color: Theme.primary
                }

                // "1" badge for repeat-one mode, 1:1 matching React
                Rectangle {
                    visible: playerBar.playMode === 1
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: 2
                    anchors.rightMargin: 2
                    width: 12
                    height: 12
                    radius: 6
                    color: Theme.primary

                    Text {
                        anchors.centerIn: parent
                        text: "1"
                        font.pixelSize: 8
                        font.bold: true
                        color: Theme.colorOnPrimary
                    }
                }

                MouseArea {
                    id: modeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        AudioEngine.playMode = (AudioEngine.playMode + 1) % 4;
                    }
                }
            }

            // 1.5. Favorite Button (Task 2: Solid theme-color filled heart when in Favorites, outline when not)
            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                Layout.alignment: Qt.AlignVCenter
                radius: 18
                color: favMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                scale: favMouse.pressed ? 0.90 : (favMouse.containsMouse ? 1.08 : 1.0)
                opacity: AudioEngine.currentTrack.length > 0 ? 1.0 : 0.4
                enabled: AudioEngine.currentTrack.length > 0

                Behavior on scale {
                    NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                }
                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                SvgIcon {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: playerBar.isCurrentFav ? "qrc:/assets/icons/heart.svg" : "qrc:/assets/icons/heart_outline.svg"
                    color: playerBar.isCurrentFav ? Theme.primary : (favMouse.containsMouse ? Theme.primary : Theme.iconNeutral)
                }

                MouseArea {
                    id: favMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (AudioEngine.currentTrack.length > 0) {
                            LibraryManager.toggleFavorite(AudioEngine.currentTrack);
                        }
                    }
                }
            }

            // 1.6. Add to Playlist Button (Task 2: Standard playlist_add icon with + badge)
            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                Layout.alignment: Qt.AlignVCenter
                radius: 18
                color: plMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                scale: plMouse.pressed ? 0.90 : (plMouse.containsMouse ? 1.08 : 1.0)
                opacity: AudioEngine.currentTrack.length > 0 ? 1.0 : 0.4
                enabled: AudioEngine.currentTrack.length > 0

                Behavior on scale {
                    NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                }
                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                SvgIcon {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    source: "qrc:/assets/icons/playlist_add.svg"
                    color: plMouse.containsMouse ? Theme.primary : Theme.iconNeutral
                }

                MouseArea {
                    id: plMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (AudioEngine.currentTrack.length > 0) {
                            if (typeof playlistSelectDialog !== "undefined") {
                                playlistSelectDialog.openForTracks([AudioEngine.currentTrack]);
                            }
                            playerBar.addToPlaylistRequested(AudioEngine.currentTrack);
                        }
                    }
                }
            }

            // 2. Previous Track
            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                Layout.alignment: Qt.AlignVCenter
                radius: 18
                color: prevMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                scale: prevMouse.pressed ? 0.90 : (prevMouse.containsMouse ? 1.08 : 1.0)

                Behavior on scale {
                    NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                }
                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                SvgIcon {
                    anchors.centerIn: parent
                    width: 17
                    height: 17
                    source: "qrc:/assets/icons/backward_step.svg"
                    color: prevMouse.containsMouse ? Theme.textPrimary : Theme.iconNeutral
                }

                MouseArea {
                    id: prevMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AudioEngine.playPrevious()
                }
            }

            // 3. Play / Pause Main FAB Button (44x44 Theme.primary with Elastic Feedback)
            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                Layout.alignment: Qt.AlignVCenter
                radius: 22
                color: playMouse.containsMouse ? Qt.lighter(Theme.primary, 1.1) : Theme.primary
                scale: playMouse.pressed ? 0.95 : (playMouse.containsMouse ? 1.05 : 1.0)

                Behavior on scale {
                    NumberAnimation {
                        duration: playMouse.pressed ? 80 : 240
                        easing.type: playMouse.pressed ? Easing.OutQuad : Easing.OutBack
                        easing.overshoot: 1.25
                    }
                }

                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                SvgIcon {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: AudioEngine.playbackState === 1 ? 0 : 1
                    width: 18
                    height: 18
                    source: AudioEngine.playbackState === 1
                            ? "qrc:/assets/icons/pause.svg"
                            : "qrc:/assets/icons/play.svg"
                    color: Theme.colorOnPrimary
                }

                MouseArea {
                    id: playMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (AudioEngine.playbackState === 1) {
                            AudioEngine.pause();
                        } else {
                            if (AudioEngine.durationMs > 0 && AudioEngine.positionMs >= AudioEngine.durationMs) {
                                AudioEngine.seek(0);
                                AudioEngine.play(AudioEngine.currentTrack);
                            } else if (AudioEngine.playbackState === 0 && AudioEngine.currentTrack.length > 0) {
                                AudioEngine.play(AudioEngine.currentTrack);
                            } else {
                                AudioEngine.resume();
                            }
                        }
                    }
                }
            }

            // 4. Next Track
            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                Layout.alignment: Qt.AlignVCenter
                radius: 18
                color: nextMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                scale: nextMouse.pressed ? 0.90 : (nextMouse.containsMouse ? 1.08 : 1.0)

                Behavior on scale {
                    NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                }
                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                SvgIcon {
                    anchors.centerIn: parent
                    width: 17
                    height: 17
                    source: "qrc:/assets/icons/forward_step.svg"
                    color: nextMouse.containsMouse ? Theme.textPrimary : Theme.iconNeutral
                }

                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AudioEngine.playNext()
                }
            }

            // 5. Playback Queue Button
            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                Layout.alignment: Qt.AlignVCenter
                radius: 18
                color: queueMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                scale: queueMouse.pressed ? 0.90 : (queueMouse.containsMouse ? 1.08 : 1.0)

                Behavior on scale {
                    NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                }
                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                SvgIcon {
                    anchors.centerIn: parent
                    width: 17
                    height: 17
                    source: "qrc:/assets/icons/list_ol.svg"
                    color: queueMouse.containsMouse ? Theme.primary : Theme.iconNeutral
                }

                MouseArea {
                    id: queueMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: playerBar.queueRequested()
                }
            }
        }
    }
}
