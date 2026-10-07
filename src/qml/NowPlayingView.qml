import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import rhx.audio 1.0
import rhx.ui 1.0
import rhx.config 1.0
import rhx.theme 1.0

Item {
    id: root
    clip: false

    property bool isOpen: false
    property bool showTrans: true
    readonly property bool isAnimating: yAnim.running
    readonly property bool isFullyExpanded: isOpen && !yAnim.running
    readonly property bool isFullyCollapsed: !isOpen && !yAnim.running
    readonly property real slideProgress: height > 0 ? (1.0 - Math.max(0, Math.min(height, y)) / height) : (isOpen ? 1.0 : 0.0)
    readonly property bool hasLyrics: AudioEngine.lyrics.hasLyrics && AudioEngine.lyrics.count > 0
    signal closeRequested()

    readonly property int effectiveLyricsFontSize: (typeof ConfigManager !== "undefined" && ConfigManager && ConfigManager.lyricsFontSize > 0) ? ConfigManager.lyricsFontSize : 30

    // ------------------------------------------------------------------------
    // Dynamic Audio Specs Formatters (Strictly dynamic data, fallback to "—")
    // ------------------------------------------------------------------------
    function getSampleRateDisplay() {
        if (AudioEngine.currentSampleRate <= 0) return "";
        return (AudioEngine.currentSampleRate / 1000.0).toFixed(1) + " kHz";
    }

    function getChannelsDisplay() {
        if (AudioEngine.currentChannels <= 0) return "";
        if (AudioEngine.currentChannels === 1) return "Mono (1.0)";
        if (AudioEngine.currentChannels === 2) return "Stereo (2.0)";
        if (AudioEngine.currentChannels === 6) return "5.1 Surround";
        if (AudioEngine.currentChannels === 8) return "7.1 Surround";
        return AudioEngine.currentChannels.toString();
    }

    function getBitDepthDisplay() {
        if (AudioEngine.currentBitDepth <= 0) return "";
        return AudioEngine.currentBitDepth + "-bit";
    }

    function getBitrateDisplay() {
        if (AudioEngine.currentBitrate <= 0) return "";
        return AudioEngine.currentBitrate + " kbps";
    }

    function getCodecDisplay() {
        return AudioEngine.currentFormat.length > 0 ? AudioEngine.currentFormat.toUpperCase() : "";
    }

    function getEncodingDisplay() {
        return AudioEngine.currentEncoding.length > 0 ? AudioEngine.currentEncoding : "";
    }

    function getToolDisplay() {
        return AudioEngine.currentTool.length > 0 ? AudioEngine.currentTool : "";
    }

    // Physical vertical translation (sliding from bottom edge to y: 0)
    y: isOpen ? 0 : height
    visible: isOpen || yAnim.running

    Behavior on y {
        NumberAnimation {
            id: yAnim
            duration: root.isOpen ? 380 : 320
            easing.type: root.isOpen ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: 1.12
        }
    }

    onIsOpenChanged: {
        if (isOpen && root.hasLyrics && AudioEngine.lyrics.activeIndex >= 0) {
            lyricsList.userInteracting = false;
            lyricsList.currentIndex = AudioEngine.lyrics.activeIndex;
        } else if (!isOpen) {
            scrollResumeTimer.stop();
        }
    }

    // 100% Solid Flat dark background (Strictly Flat M3: no blur, no gradient masks)
    // Extended downwards (+120px) to prevent bottom reveal during OutBack overshoot bounce
    Rectangle {
        id: bgRect
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: parent.height + 120
        color: Theme.surface

        // Event barrier: Absorb all clicks and pointer interactions to prevent click-through to underlying views
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            onClicked: {}
            onWheel: function(wheel) { wheel.accepted = true; }
        }
    }

    // ========================================================================
    // Layout Mode A: With Lyrics Mode (Left: Cover + Specs, Right: Lyrics + Floating Scrollbar)
    // ========================================================================
    Item {
        id: withLyricsContainer
        anchors.fill: parent
        anchors.leftMargin: root.width < 900 ? 24 : 48
        anchors.rightMargin: root.width < 900 ? 24 : 48
        anchors.topMargin: root.height < 650 ? 16 : 36
        anchors.bottomMargin: root.height < 650 ? 16 : 36
        visible: root.hasLyrics

        RowLayout {
            anchors.fill: parent
            spacing: Math.max(32, Math.min(64, parent.width * 0.05))

            // ================================================================
            // Left Column: Large Dynamic Cover + Track Info + Specs Card
            // Guard minimum width (260px) and responsive degradation
            // ================================================================
            ColumnLayout {
                id: leftCol
                Layout.minimumWidth: 260
                Layout.preferredWidth: panelSize
                Layout.maximumWidth: panelSize
                Layout.fillWidth: false
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                spacing: isCompactHeight ? 8 : 12

                property real maxCoverWidth: 340
                property bool isCompactHeight: root.height < 650
                property bool showSpecs: root.height >= 550

                property real panelSize: {
                    var h = withLyricsContainer.height;
                    var reserved = trackInfoCol.implicitHeight + (showSpecs ? (specsCard.implicitHeight + spacing) : 0) + spacing;
                    var byHeight = Math.max(260, h - reserved);
                    var byWidth = Math.max(260, root.width * 0.35);
                    return Math.max(260, Math.min(maxCoverWidth, Math.min(byWidth, byHeight)));
                }

                // 1. Dynamic square cover: width fills left panel completely (1:1 ratio)
                Item {
                    id: coverItem
                    width: leftCol.panelSize
                    height: leftCol.panelSize
                    Layout.preferredWidth: leftCol.panelSize
                    Layout.preferredHeight: leftCol.panelSize
                    Layout.alignment: Qt.AlignLeft

                    Rectangle {
                        anchors.fill: parent
                        radius: 20
                        color: Theme.surfaceContainerLow

                        RoundedImage {
                            anchors.fill: parent
                            radius: 20
                            fullResolution: true
                            source: (AudioEngine.hasCover && AudioEngine.currentCoverUrl.length > 0)
                                    ? AudioEngine.currentCoverUrl
                                    : ""
                            fallbackColor: Theme.surfaceContainer
                            fallbackIcon: "qrc:/assets/icons/music_note.svg"
                            fallbackIconColor: Theme.primary
                            fallbackIconSize: 56
                        }
                    }
                }

                // 2. Track Title & Artist & Album (Headline Typography Scale)
                ColumnLayout {
                    id: trackInfoCol
                    Layout.preferredWidth: leftCol.panelSize
                    Layout.maximumWidth: leftCol.panelSize
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignLeft
                    spacing: leftCol.isCompactHeight ? 4 : 6

                    Text {
                        Layout.fillWidth: true
                        text: AudioEngine.currentTitle.length > 0 ? AudioEngine.currentTitle : "0rhxPlayer"
                        font.pixelSize: leftCol.isCompactHeight ? 20 : 24
                        font.bold: true
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignLeft
                    }

                    Text {
                        Layout.fillWidth: true
                        text: AudioEngine.currentArtist.length > 0 ? AudioEngine.currentArtist : "—"
                        font.pixelSize: leftCol.isCompactHeight ? 14 : 16
                        font.weight: Font.DemiBold
                        color: Theme.primary
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignLeft
                    }

                    Text {
                        Layout.fillWidth: true
                        text: AudioEngine.currentAlbum.length > 0 ? AudioEngine.currentAlbum : "—"
                        font.pixelSize: leftCol.isCompactHeight ? 12 : 13
                        color: Theme.textMuted
                        opacity: 0.85
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignLeft
                    }
                }

                // 3. Audio Specs Card: dynamically collapsed when height < 550px
                Rectangle {
                    id: specsCard
                    visible: leftCol.showSpecs
                    Layout.preferredWidth: leftCol.panelSize
                    Layout.maximumWidth: leftCol.panelSize
                    Layout.fillWidth: true
                    Layout.preferredHeight: visible ? (specsLayout.implicitHeight + (leftCol.isCompactHeight ? 14 : 20)) : 0
                    Layout.alignment: Qt.AlignLeft
                    radius: 14
                    color: Theme.surfaceContainerLow
                    border.color: Theme.borderSubtle
                    border.width: 1
                    implicitHeight: visible ? (specsLayout.implicitHeight + (leftCol.isCompactHeight ? 14 : 20)) : 0

                    ColumnLayout {
                        id: specsLayout
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: leftCol.isCompactHeight ? 8 : 12
                        spacing: leftCol.isCompactHeight ? 3 : 5

                        // 1. Sample rate
                        RowLayout {
                            Layout.fillWidth: true
                            visible: srText.text.length > 0
                            spacing: 8
                            Text {
                                text: "Sample rate:"
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Theme.textMuted
                                Layout.minimumWidth: 85
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                id: srText
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignRight
                                text: root.getSampleRateDisplay()
                                font.pixelSize: 11
                                font.family: "Consolas, monospace"
                                font.bold: true
                                color: Theme.primary
                                elide: Text.ElideRight
                            }
                        }

                        // 2. Channels
                        RowLayout {
                            Layout.fillWidth: true
                            visible: chText.text.length > 0
                            spacing: 8
                            Text {
                                text: "Channels:"
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Theme.textMuted
                                Layout.minimumWidth: 85
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                id: chText
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignRight
                                text: root.getChannelsDisplay()
                                font.pixelSize: 11
                                font.family: "Consolas, monospace"
                                font.bold: true
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                            }
                        }

                        // 3. Bits per sample
                        RowLayout {
                            Layout.fillWidth: true
                            visible: bdText.text.length > 0
                            spacing: 8
                            Text {
                                text: "Bits per sample:"
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Theme.textMuted
                                Layout.minimumWidth: 85
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                id: bdText
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignRight
                                text: root.getBitDepthDisplay()
                                font.pixelSize: 11
                                font.family: "Consolas, monospace"
                                font.bold: true
                                color: Theme.tertiary
                                elide: Text.ElideRight
                            }
                        }

                        // 4. Bitrate
                        RowLayout {
                            Layout.fillWidth: true
                            visible: brText.text.length > 0
                            spacing: 8
                            Text {
                                text: "Bitrate:"
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Theme.textMuted
                                Layout.minimumWidth: 85
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                id: brText
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignRight
                                text: root.getBitrateDisplay()
                                font.pixelSize: 11
                                font.family: "Consolas, monospace"
                                font.bold: true
                                color: Theme.primary
                                elide: Text.ElideRight
                            }
                        }

                        // 5. Codec
                        RowLayout {
                            Layout.fillWidth: true
                            visible: codecText.text.length > 0
                            spacing: 8
                            Text {
                                text: "Codec:"
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Theme.textMuted
                                Layout.minimumWidth: 85
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                id: codecText
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignRight
                                text: root.getCodecDisplay()
                                font.pixelSize: 11
                                font.family: "Consolas, monospace"
                                font.bold: true
                                color: Theme.textPrimary
                                elide: Text.ElideRight
                            }
                        }

                        // 6. Encoding
                        RowLayout {
                            Layout.fillWidth: true
                            visible: encText.text.length > 0
                            spacing: 8
                            Text {
                                text: "Encoding:"
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Theme.textMuted
                                Layout.minimumWidth: 85
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                id: encText
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignRight
                                text: root.getEncodingDisplay()
                                font.pixelSize: 11
                                font.family: "Consolas, monospace"
                                font.bold: true
                                color: Theme.tertiary
                                elide: Text.ElideRight
                            }
                        }

                        // 7. Tool
                        RowLayout {
                            Layout.fillWidth: true
                            visible: toolText.text.length > 0
                            spacing: 8
                            Text {
                                text: "Tool:"
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: Theme.textMuted
                                Layout.minimumWidth: 85
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                id: toolText
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignRight
                                text: root.getToolDisplay()
                                font.pixelSize: 11
                                font.family: "Consolas, monospace"
                                font.bold: true
                                color: Theme.textSecondary
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            // ================================================================
            // Right Column: Lyrics Viewport & Conditional Progress Scrollbar
            // ================================================================
            Item {
                id: lyricsContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 280

                // Inactivity timer: restore auto-centering 3s after user scroll/flick
                Timer {
                    id: scrollResumeTimer
                    interval: 3000
                    repeat: false
                    onTriggered: {
                        lyricsList.userInteracting = false;
                        if (AudioEngine.lyrics.hasLyrics && AudioEngine.lyrics.activeIndex >= 0) {
                            lyricsList.currentIndex = AudioEngine.lyrics.activeIndex;
                        }
                    }
                }

                Connections {
                    target: AudioEngine.lyrics
                    function onActiveIndexChanged(idx) {
                        if (root.isOpen && !lyricsList.userInteracting && idx >= 0) {
                            lyricsList.currentIndex = idx;
                        }
                    }
                }

                // 1. Lyrics Viewport (when lyrics exist)
                ListView {
                    id: lyricsList
                    objectName: "lyricsListView"
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: scrollbarArea.visible ? scrollbarArea.left : parent.right
                    anchors.rightMargin: scrollbarArea.visible ? 16 : 0
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    visible: AudioEngine.lyrics.hasLyrics && AudioEngine.lyrics.count > 0

                    property bool userInteracting: false

                    model: AudioEngine.lyrics

                    // Centering highlight lock at 47%
                    preferredHighlightBegin: height * 0.47
                    preferredHighlightEnd: height * 0.47
                    highlightRangeMode: ListView.ApplyRange
                    highlightMoveDuration: 300

                    header: Item {
                        width: lyricsList.width
                        height: lyricsList.height * 0.47
                    }

                    footer: Item {
                        width: lyricsList.width
                        height: lyricsList.height * 0.53
                    }

                    onMovementStarted: {
                        userInteracting = true;
                        scrollResumeTimer.restart();
                    }

                    onMovementEnded: {
                        userInteracting = true;
                        scrollResumeTimer.restart();
                    }

                    delegate: Item {
                        id: lineDelegate
                        objectName: "lyricLineDelegate"
                        width: lyricsList.width
                        height: textWrapper.implicitHeight + 20

                        readonly property bool isActive: index === AudioEngine.lyrics.activeIndex
                        readonly property string alignSetting: (typeof ConfigManager !== "undefined" && ConfigManager && ConfigManager.lyricsAlign) ? ConfigManager.lyricsAlign : "right"
                        readonly property real maxContentWidth: Math.max(10, lineDelegate.width - 44)
                        readonly property real naturalTextWidth: Math.max(mainLyricText.implicitWidth, (transLyricText.visible ? transLyricText.implicitWidth : 0))
                        readonly property real boundedWidth: Math.min(maxContentWidth, Math.max(1, naturalTextWidth))

                        Column {
                            id: textWrapper
                            objectName: "lyricTextWrapper"
                            width: lineDelegate.boundedWidth
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: lineDelegate.alignSetting === "left" ? parent.left : undefined
                            anchors.leftMargin: 8
                            anchors.right: lineDelegate.alignSetting === "right" ? parent.right : undefined
                            anchors.rightMargin: 36
                            anchors.horizontalCenter: lineDelegate.alignSetting === "center" ? parent.horizontalCenter : undefined
                            spacing: 4

                            // Main lyric text line (Strictly AlignRight by default, matching React original)
                            Text {
                                id: mainLyricText
                                objectName: "mainLyricText"
                                width: textWrapper.width
                                text: model.text
                                font.pixelSize: lineDelegate.isActive ? root.effectiveLyricsFontSize : Math.max(13, Math.round(root.effectiveLyricsFontSize * 0.72))
                                font.bold: lineDelegate.isActive
                                color: lineDelegate.isActive ? Theme.textPrimary : Theme.textSecondary
                                opacity: lineDelegate.isActive ? 1.0 : (lineMouse.containsMouse ? 0.75 : 0.35)
                                wrapMode: Text.WordWrap
                                horizontalAlignment: {
                                    if (lineDelegate.alignSetting === "left") return Text.AlignLeft;
                                    if (lineDelegate.alignSetting === "center") return Text.AlignHCenter;
                                    return Text.AlignRight;
                                }

                                Behavior on font.pixelSize {
                                    NumberAnimation { duration: 200 }
                                }
                                Behavior on opacity {
                                    NumberAnimation { duration: 250 }
                                }
                                Behavior on color {
                                    ColorAnimation { duration: 200 }
                                }
                            }

                            // Translation line (when showTrans is enabled and trans exists)
                            Text {
                                id: transLyricText
                                objectName: "transLyricText"
                                width: textWrapper.width
                                visible: root.showTrans && model.trans.length > 0
                                text: model.trans
                                font.pixelSize: lineDelegate.isActive ? Math.max(12, Math.round(root.effectiveLyricsFontSize * 0.58)) : Math.max(10, Math.round(root.effectiveLyricsFontSize * 0.48))
                                font.bold: false
                                color: lineDelegate.isActive ? Theme.textSecondary : Theme.textMuted
                                opacity: lineDelegate.isActive ? 0.9 : (lineMouse.containsMouse ? 0.65 : 0.35)
                                wrapMode: Text.WordWrap
                                horizontalAlignment: {
                                    if (lineDelegate.alignSetting === "left") return Text.AlignLeft;
                                    if (lineDelegate.alignSetting === "center") return Text.AlignHCenter;
                                    return Text.AlignRight;
                                }

                                Behavior on opacity {
                                    NumberAnimation { duration: 250 }
                                }
                                Behavior on color {
                                    ColorAnimation { duration: 200 }
                                }
                            }
                        }

                        // Strict text hitbox: tightly constrained to textWrapper with 8px clicking padding
                        MouseArea {
                            id: lineMouse
                            objectName: "lyricMouseArea"
                            anchors.fill: textWrapper
                            anchors.margins: -8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                lyricsList.userInteracting = false;
                                scrollResumeTimer.stop();
                                AudioEngine.seek(model.timeMs);
                                lyricsList.currentIndex = index;
                            }
                        }
                    }
                }


                // ================================================================
                // 3. Floating Pill Scrollbar (1:1 matching React Material You)
                // STRICT CONDITIONAL VISIBILITY: Only visible when lyrics exist & active playback!
                // Floating safe margins: rightMargin 12px (pr-3), top/bottom 32px, full capsule pill
                // ================================================================
                Item {
                    id: scrollbarArea
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.topMargin: 32
                    anchors.bottomMargin: 32
                    anchors.rightMargin: 12
                    width: 24
                    visible: AudioEngine.lyrics.hasLyrics && AudioEngine.lyrics.count > 0 && AudioEngine.durationMs > 0

                    // Transparent track (1:1 matching ::-webkit-scrollbar-track { background: transparent; })
                    Rectangle {
                        id: scrollTrack
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 4
                        radius: 2
                        color: "transparent"

                        // Floating Pill Thumb (width: 4px, height: 48px, radius: 2px = 9999px full capsule)
                        Rectangle {
                            id: scrollThumb
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 4
                            height: 48
                            radius: 2
                            color: (scrollMouse.pressed || scrollMouse.containsMouse) ? Qt.lighter(Theme.primary, 1.1) : Theme.primary
                            opacity: (scrollMouse.pressed || scrollMouse.containsMouse) ? 1.0 : 0.8

                            // Dynamic vertical position strictly bound to AudioEngine playback progress
                            y: {
                                var maxRange = scrollTrack.height - height;
                                if (maxRange <= 0 || AudioEngine.durationMs <= 0) return 0;
                                var ratio = Math.max(0.0, Math.min(1.0, AudioEngine.positionMs / AudioEngine.durationMs));
                                return ratio * maxRange;
                            }

                            Behavior on y {
                                enabled: !scrollMouse.pressed
                                NumberAnimation { duration: 80 }
                            }
                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }
                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }
                        }
                    }

                    // Mouse interaction area for click & drag seeking
                    MouseArea {
                        id: scrollMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        function updateSeek(mouseY) {
                            if (AudioEngine.durationMs <= 0) return;
                            var maxRange = scrollTrack.height - scrollThumb.height;
                            if (maxRange <= 0) return;
                            var targetY = Math.max(0.0, Math.min(maxRange, mouseY - scrollThumb.height / 2));
                            var pct = targetY / maxRange;
                            var targetMs = Math.floor(pct * AudioEngine.durationMs);
                            AudioEngine.seek(targetMs);
                        }

                        onPressed: function(mouse) {
                            updateSeek(mouse.y);
                        }

                        onPositionChanged: function(mouse) {
                            if (pressed) {
                                updateSeek(mouse.y);
                            }
                        }
                    }
                }
            }
        }
    }

    // ========================================================================
    // Layout Mode B: No Lyrics Mode — Dual Card Global Centered Hi-Fi Studio Layout
    // ========================================================================
    RowLayout {
        id: noLyricsContainer
        anchors.centerIn: parent
        visible: !root.hasLyrics
        spacing: 36

        // 1. Left Card: Big Cover + Track Info
        Rectangle {
            id: noLyricsLeftCard
            width: 320
            Layout.preferredWidth: 320
            Layout.preferredHeight: noLyricsLeftCol.implicitHeight + 32
            Layout.alignment: Qt.AlignVCenter
            radius: 20
            color: Theme.surfaceContainerLow
            border.color: Theme.borderSubtle
            border.width: 1

            ColumnLayout {
                id: noLyricsLeftCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 16
                spacing: 14

                // Big Square Cover (fills card width minus margins: 320 - 32 = 288x288)
                Item {
                    Layout.preferredWidth: 288
                    Layout.preferredHeight: 288
                    Layout.alignment: Qt.AlignHCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        color: Theme.surfaceContainer

                        RoundedImage {
                            anchors.fill: parent
                            radius: 16
                            fullResolution: true
                            source: (AudioEngine.hasCover && AudioEngine.currentCoverUrl.length > 0)
                                    ? AudioEngine.currentCoverUrl
                                    : ""
                            fallbackColor: Theme.surfaceContainer
                            fallbackIcon: "qrc:/assets/icons/music_note.svg"
                            fallbackIconColor: Theme.primary
                            fallbackIconSize: 64
                        }
                    }
                }

                // Track Information Stack
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        Layout.fillWidth: true
                        text: AudioEngine.currentTitle.length > 0 ? AudioEngine.currentTitle : "0rhxPlayer"
                        font.pixelSize: 22
                        font.bold: true
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: AudioEngine.currentArtist.length > 0 ? AudioEngine.currentArtist : "—"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        color: Theme.primary
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: AudioEngine.currentAlbum.length > 0 ? AudioEngine.currentAlbum : "—"
                        font.pixelSize: 13
                        color: Theme.textMuted
                        opacity: 0.85
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // 2. Right Card: Audio Technical Parameters Card
        Rectangle {
            id: noLyricsRightCard
            width: 320
            Layout.preferredWidth: 320
            Layout.preferredHeight: noLyricsLeftCard.Layout.preferredHeight
            Layout.alignment: Qt.AlignVCenter
            radius: 20
            color: Theme.surfaceContainerLow
            border.color: Theme.borderSubtle
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    SvgIcon {
                        width: 18
                        height: 18
                        source: "qrc:/assets/icons/equalizer.svg"
                        color: Theme.primary
                    }

                    Text {
                        text: "TECHNICAL SPECIFICATIONS"
                        font.pixelSize: 12
                        font.bold: true
                        font.letterSpacing: 1.0
                        color: Theme.primary
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.borderSubtle
                }

                // 7 Dynamic Spec Rows
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // 1. Sample rate
                    RowLayout {
                        Layout.fillWidth: true
                        visible: nlSrText.text.length > 0
                        spacing: 8
                        Text {
                            text: "Sample rate:"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Theme.textMuted
                            Layout.minimumWidth: 90
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            id: nlSrText
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            text: root.getSampleRateDisplay()
                            font.pixelSize: 11
                            font.family: "Consolas, monospace"
                            font.bold: true
                            color: Theme.primary
                            elide: Text.ElideRight
                        }
                    }

                    // 2. Channels
                    RowLayout {
                        Layout.fillWidth: true
                        visible: nlChText.text.length > 0
                        spacing: 8
                        Text {
                            text: "Channels:"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Theme.textMuted
                            Layout.minimumWidth: 90
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            id: nlChText
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            text: root.getChannelsDisplay()
                            font.pixelSize: 11
                            font.family: "Consolas, monospace"
                            font.bold: true
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                        }
                    }

                    // 3. Bits per sample
                    RowLayout {
                        Layout.fillWidth: true
                        visible: nlBdText.text.length > 0
                        spacing: 8
                        Text {
                            text: "Bits per sample:"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Theme.textMuted
                            Layout.minimumWidth: 90
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            id: nlBdText
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            text: root.getBitDepthDisplay()
                            font.pixelSize: 11
                            font.family: "Consolas, monospace"
                            font.bold: true
                            color: Theme.tertiary
                            elide: Text.ElideRight
                        }
                    }

                    // 4. Bitrate
                    RowLayout {
                        Layout.fillWidth: true
                        visible: nlBrText.text.length > 0
                        spacing: 8
                        Text {
                            text: "Bitrate:"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Theme.textMuted
                            Layout.minimumWidth: 90
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            id: nlBrText
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            text: root.getBitrateDisplay()
                            font.pixelSize: 11
                            font.family: "Consolas, monospace"
                            font.bold: true
                            color: Theme.primary
                            elide: Text.ElideRight
                        }
                    }

                    // 5. Codec
                    RowLayout {
                        Layout.fillWidth: true
                        visible: nlCodecText.text.length > 0
                        spacing: 8
                        Text {
                            text: "Codec:"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Theme.textMuted
                            Layout.minimumWidth: 90
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            id: nlCodecText
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            text: root.getCodecDisplay()
                            font.pixelSize: 11
                            font.family: "Consolas, monospace"
                            font.bold: true
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                        }
                    }

                    // 6. Encoding
                    RowLayout {
                        Layout.fillWidth: true
                        visible: nlEncText.text.length > 0
                        spacing: 8
                        Text {
                            text: "Encoding:"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Theme.textMuted
                            Layout.minimumWidth: 90
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            id: nlEncText
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            text: root.getEncodingDisplay()
                            font.pixelSize: 11
                            font.family: "Consolas, monospace"
                            font.bold: true
                            color: Theme.tertiary
                            elide: Text.ElideRight
                        }
                    }

                    // 7. Tool
                    RowLayout {
                        Layout.fillWidth: true
                        visible: nlToolText.text.length > 0
                        spacing: 8
                        Text {
                            text: "Tool:"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            color: Theme.textMuted
                            Layout.minimumWidth: 90
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            id: nlToolText
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignRight
                            text: root.getToolDisplay()
                            font.pixelSize: 11
                            font.family: "Consolas, monospace"
                            font.bold: true
                            color: Theme.textSecondary
                            elide: Text.ElideRight
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                // Hi-Fi Engine Footer
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: "BASS ENGINE · DIRECT STREAM"
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1.2
                    color: Theme.textMuted
                }
            }
        }
    }
}
