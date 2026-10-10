import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import rhx.config 1.0
import rhx.theme 1.0
import rhx.library 1.0
import rhx.audio 1.0
import rhx.ui 1.0

Item {
    id: settingsRoot
    objectName: "settingsRoot"
    clip: true

    signal navigateTab(string tabId)
    property string searchFilter: ""
    property bool colorPickerExpanded: false
    property real currentHue: 180.0

    function colorToHex(c) {
        var r = Math.round(c.r * 255).toString(16);
        var g = Math.round(c.g * 255).toString(16);
        var b = Math.round(c.b * 255).toString(16);
        if (r.length < 2) r = "0" + r;
        if (g.length < 2) g = "0" + g;
        if (b.length < 2) b = "0" + b;
        return ("#" + r + g + b).toUpperCase();
    }

    function matchesSearch(keywords) {
        if (!searchFilter || searchFilter.trim() === "") return true;
        var terms = searchFilter.toLowerCase().trim().split(/\s+/);
        for (var t = 0; t < terms.length; t++) {
            var term = terms[t];
            if (!term) continue;
            var matched = false;
            for (var i = 0; i < keywords.length; i++) {
                if (keywords[i] && keywords[i].toLowerCase().indexOf(term) !== -1) {
                    matched = true;
                    break;
                }
            }
            if (!matched) return false;
        }
        return true;
    }

    // Material 3 Graphical Theme Color Palette Popup (Task 4)
    Popup {
        id: palettePopup
        objectName: "palettePopup"
        parent: Overlay.overlay
        width: 320
        padding: 16
        topPadding: 16
        bottomPadding: 16
        leftPadding: 16
        rightPadding: 16
        readonly property real estimatedHeight: 236
        height: palettePopupCol.implicitHeight > 0 ? (palettePopupCol.implicitHeight + topPadding + bottomPadding) : estimatedHeight
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        dim: false

        Overlay.modal: Rectangle {
            color: "transparent"
        }

        onAboutToShow: {
            hexInput.text = ConfigManager.seedColor;
        }

        function openBelow(btn) {
            if (!Overlay.overlay) return;
            hexInput.text = ConfigManager.seedColor;

            var popW = width;
            var popH = height > 50 ? height : estimatedHeight;

            // Map button coordinates to global overlay
            var btnPt = btn.mapToItem(Overlay.overlay, 0, 0);

            // Horizontal positioning (align right edge to button, clamped within window margins)
            var targetX = btnPt.x + btn.width - popW;
            if (targetX < 16) targetX = 16;
            if (targetX + popW > Overlay.overlay.width - 16) {
                targetX = Overlay.overlay.width - popW - 16;
            }

            // Vertical boundaries:
            // Top: 48px titlebar + 8px margin = 56px
            // Bottom: 80px BottomPlayerBar + 12px breathing margin
            var minTopY = 56;
            var maxBottomY = Overlay.overlay.height - 80 - 12;

            var spaceBelow = maxBottomY - (btnPt.y + btn.height + 6);
            var spaceAbove = (btnPt.y - 6) - minTopY;

            var targetY;
            if (spaceBelow >= popH) {
                // Sufficient space below: open downwards
                targetY = btnPt.y + btn.height + 6;
            } else if (spaceAbove >= popH) {
                // Insufficient below, sufficient above: open upwards
                targetY = btnPt.y - popH - 6;
            } else {
                // Both tight: pick whichever side has more space
                if (spaceBelow >= spaceAbove) {
                    targetY = btnPt.y + btn.height + 6;
                } else {
                    targetY = btnPt.y - popH - 6;
                }
            }

            // Strict Clamping: ensure popup NEVER exceeds maxBottomY or goes above minTopY
            if (targetY + popH > maxBottomY) {
                targetY = maxBottomY - popH;
            }
            if (targetY < minTopY) {
                targetY = minTopY;
            }

            x = Math.round(targetX);
            y = Math.round(targetY);
            open();
        }

        background: Rectangle {
            radius: 16
            color: Theme.surfaceContainerHigh
            border.width: 1
            border.color: Theme.borderSubtle
        }

        contentItem: Item {
            implicitWidth: palettePopup.width - palettePopup.leftPadding - palettePopup.rightPadding
            implicitHeight: palettePopupCol.implicitHeight

            ColumnLayout {
                id: palettePopupCol
                anchors.fill: parent
                spacing: 8

                // Header Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    SvgIcon {
                        Layout.preferredWidth: 15
                        Layout.preferredHeight: 15
                        source: "qrc:/assets/icons/palette.svg"
                        color: Theme.primary
                    }

                    Text {
                        text: qsTr("Theme Palette")
                        font.pixelSize: 12
                        font.bold: true
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }

                    // Seed color badge
                    Rectangle {
                        height: 20
                        width: seedBadgeRow.implicitWidth + 10
                        radius: 10
                        color: Theme.surfaceContainerHighest
                        border.width: 1
                        border.color: Theme.borderSubtle

                        RowLayout {
                            id: seedBadgeRow
                            anchors.centerIn: parent
                            spacing: 4

                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: ConfigManager.seedColor
                            }

                            Text {
                                text: ConfigManager.seedColor.toUpperCase()
                                font.pixelSize: 9
                                font.family: "monospace"
                                font.bold: true
                                color: Theme.textPrimary
                            }
                        }
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.borderSubtle
                }

                // Preset Swatches Title
                Text {
                    text: qsTr("Material 3 Presets")
                    font.pixelSize: 10
                    font.bold: true
                    color: Theme.textMuted
                }

                // Presets Grid
                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: [
                            "#39C5BB", "#6750A4", "#00639B", "#9C4146",
                            "#4C662B", "#825500", "#7D5260", "#006874",
                            "#DE3730", "#F59E0B", "#10B981", "#3B82F6",
                            "#8B5CF6", "#EC4899", "#64748B", "#78716C"
                        ]

                        Rectangle {
                            width: 26
                            height: 26
                            radius: 13
                            color: modelData
                            scale: popSwMouse.pressed ? 0.90 : (popSwMouse.containsMouse ? 1.15 : (isSelected ? 1.08 : 1.0))
                            border.width: isSelected ? 2 : 1
                            border.color: isSelected ? Theme.textPrimary : "#30000000"

                            readonly property bool isSelected: ConfigManager.seedColor.toLowerCase() === modelData.toLowerCase()

                            Behavior on scale { NumberAnimation { duration: 100 } }

                            SvgIcon {
                                visible: parent.isSelected
                                anchors.centerIn: parent
                                width: 11
                                height: 11
                                source: "qrc:/assets/icons/check.svg"
                                color: "#FFFFFF"
                            }

                            MouseArea {
                                id: popSwMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ConfigManager.setSeedColor(modelData);
                                    hexInput.text = modelData;
                                }
                            }
                        }
                    }
                }

                // Continuous Hue Slider
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: qsTr("Spectrum Hue")
                        font.pixelSize: 10
                        font.bold: true
                        color: Theme.textMuted
                    }

                    Rectangle {
                        id: popHueBar
                        Layout.fillWidth: true
                        height: 14
                        radius: 7
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.00; color: "#FF0000" }
                            GradientStop { position: 0.17; color: "#FFFF00" }
                            GradientStop { position: 0.33; color: "#00FF00" }
                            GradientStop { position: 0.50; color: "#00FFFF" }
                            GradientStop { position: 0.67; color: "#0000FF" }
                            GradientStop { position: 0.83; color: "#FF00FF" }
                            GradientStop { position: 1.00; color: "#FF0000" }
                        }

                        Rectangle {
                            id: popHueThumb
                            width: 10
                            height: 18
                            radius: 5
                            anchors.verticalCenter: parent.verticalCenter
                            color: "#FFFFFF"
                            border.width: 1.5
                            border.color: "#303030"
                            x: Math.max(0, Math.min(popHueBar.width - width, (settingsRoot.currentHue / 360.0) * (popHueBar.width - width)))
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            function updateHue(mouseX) {
                                var norm = Math.max(0, Math.min(1.0, mouseX / popHueBar.width));
                                settingsRoot.currentHue = norm * 360.0;
                                var col = Qt.hsva(settingsRoot.currentHue / 360.0, 0.75, 0.85, 1.0);
                                var hex = settingsRoot.colorToHex(col);
                                ConfigManager.setSeedColor(hex);
                                hexInput.text = hex;
                            }
                            onPressed: (mouse) => updateHue(mouse.x)
                            onPositionChanged: (mouse) => {
                                if (pressed) updateHue(mouse.x);
                            }
                        }
                    }
                }

                // Custom Hex Input + Lightweight Reset Button Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        width: 22
                        height: 22
                        radius: 11
                        color: ConfigManager.seedColor
                        border.width: 1
                        border.color: Theme.borderSubtle
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 28
                        radius: 8
                        color: Theme.surfaceContainerHighest
                        border.width: 1
                        border.color: hexInput.activeFocus ? Theme.primary : Theme.borderSubtle

                        TextField {
                            id: hexInput
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            text: ConfigManager.seedColor
                            font.pixelSize: 11
                            font.family: "monospace"
                            font.bold: true
                            color: Theme.textPrimary
                            placeholderText: "#39C5BB"
                            background: null
                            selectByMouse: true
                            onTextEdited: {
                                var txt = text.trim();
                                if (/^#[0-9A-Fa-f]{6}$/.test(txt)) {
                                    ConfigManager.setSeedColor(txt);
                                }
                            }
                            onAccepted: {
                                var txt = text.trim();
                                if (/^#[0-9A-Fa-f]{6}$/.test(txt)) {
                                    ConfigManager.setSeedColor(txt);
                                }
                            }
                        }
                    }

                    // Lightweight Reset Button
                    Rectangle {
                        Layout.preferredWidth: resetBtnRow.implicitWidth + 16
                        Layout.preferredHeight: 28
                        radius: 8
                        color: resetBtnArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer
                        border.width: 1
                        border.color: Theme.borderSubtle

                        RowLayout {
                            id: resetBtnRow
                            anchors.centerIn: parent
                            spacing: 4

                            SvgIcon {
                                Layout.preferredWidth: 12
                                Layout.preferredHeight: 12
                                source: "qrc:/assets/icons/refresh.svg"
                                color: Theme.textSecondary
                            }

                            Text {
                                text: qsTr("Reset")
                                font.pixelSize: 10
                                font.bold: true
                                color: Theme.textSecondary
                            }
                        }

                        MouseArea {
                            id: resetBtnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                ConfigManager.setSeedColor("#39C5BB");
                                hexInput.text = "#39C5BB";
                            }
                        }
                    }
                }
            }
        }
    }

    // Solid Titlebar Mask & Safe Margin Zone (48px height, 100% Theme.surface)
    // Ensures scrolling content clips cleanly below the top window boundary
    Rectangle {
        id: titleBarMask
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 48
        color: Theme.surface
        z: 100
    }

    ScrollView {
        id: settingsScroll
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        background: Rectangle {
            color: Theme.surface
        }

        Component.onCompleted: {
            if (contentItem) {
                contentItem.boundsBehavior = Flickable.StopAtBounds;
            }
        }

        signal navigateTab(string tabId)
        onNavigateTab: (tabId) => settingsRoot.navigateTab(tabId)
        property alias searchFilter: settingsRoot.searchFilter
        function matchesSearch(keywords) { return settingsRoot.matchesSearch(keywords); }

        ScrollBar.vertical: M3ScrollBar {}

    Item {
        width: settingsScroll.availableWidth
        implicitHeight: mainCol.implicitHeight + 64 + 80

        ColumnLayout {
            id: mainCol
            objectName: "settingsMainCol"
            anchors.top: parent.top
            anchors.topMargin: 64
            anchors.left: parent.left
            anchors.leftMargin: 32
            anchors.right: parent.right
            anchors.rightMargin: 32
            spacing: 24

            // ================================================================
            // 1. Top Header: Title + Subtitle
            // ================================================================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: qsTr("Settings")
                    font.pixelSize: 28
                    font.bold: true
                    color: Theme.textPrimary
                }

                Text {
                    text: qsTr("Preferences, audio engine and personalization")
                    font.pixelSize: 13
                    color: Theme.textMuted
                }
            }

            // ================================================================
            // 2. M3 Pill Search Field
            // ================================================================
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                radius: 24
                color: Theme.surfaceContainerLow
                border.width: 1
                border.color: searchInput.activeFocus ? Theme.primary : Theme.borderSubtle

                Behavior on border.color {
                    ColorAnimation { duration: 150 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    SvgIcon {
                        width: 18
                        height: 18
                        source: "qrc:/assets/icons/search.svg"
                        color: searchInput.activeFocus ? Theme.primary : Theme.textMuted
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        font.pixelSize: 13
                        color: Theme.textPrimary
                        selectByMouse: true
                        onTextChanged: {
                            settingsScroll.searchFilter = text.toLowerCase().trim();
                        }

                        Text {
                            anchors.fill: parent
                            text: qsTr("Search settings...")
                            font.pixelSize: 13
                            color: Theme.textMuted
                            visible: !searchInput.text && !searchInput.activeFocus
                        }
                    }

                    Rectangle {
                        visible: searchInput.text !== ""
                        width: 24
                        height: 24
                        radius: 12
                        color: clearMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                        SvgIcon {
                            anchors.centerIn: parent
                            width: 12
                            height: 12
                            source: "qrc:/assets/icons/win_close.svg"
                            color: Theme.textMuted
                        }

                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = "";
                                settingsScroll.searchFilter = "";
                            }
                        }
                    }
                }
            }

            // ================================================================
            // 3. Profile Card (User Profile)
            // ================================================================
            Rectangle {
                visible: settingsScroll.matchesSearch(["profile", "user", "avatar", "nickname", "用户", "画像", "个人", "头像", "昵称"])
                Layout.fillWidth: true
                implicitHeight: profileCol.implicitHeight + 36
                radius: 16
                color: Theme.surfaceContainerLow
                border.width: 1
                border.color: Theme.borderSubtle

                ColumnLayout {
                    id: profileCol
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 16

                    RowLayout {
                        spacing: 8
                        SvgIcon {
                            width: 16
                            height: 16
                            source: "qrc:/assets/icons/user.svg"
                            color: Theme.primary
                        }
                        Text {
                            text: qsTr("User Profile")
                            font.pixelSize: 14
                            font.bold: true
                            color: Theme.primary
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 20

                        // Avatar circle with camera hover
                        Rectangle {
                            width: 64
                            height: 64
                            radius: 32
                            color: Theme.surfaceContainerHighest
                            clip: true

                            RoundedImage {
                                anchors.fill: parent
                                radius: 32
                                visible: ConfigManager.avatar !== ""
                                source: ConfigManager.avatar
                            }

                            SvgIcon {
                                anchors.centerIn: parent
                                width: 32
                                height: 32
                                visible: ConfigManager.avatar === ""
                                source: "qrc:/assets/icons/person.svg"
                                color: Theme.primary
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 32
                                color: Qt.rgba(0, 0, 0, 0.5)
                                opacity: avatarMouse.containsMouse ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                SvgIcon {
                                    anchors.centerIn: parent
                                    width: 20
                                    height: 20
                                    source: "qrc:/assets/icons/camera.svg"
                                    color: "#FFFFFF"
                                }
                            }

                            MouseArea {
                                id: avatarMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ConfigManager.openSelectAvatarDialog()
                            }
                        }

                        // Nickname + Actions
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            ColumnLayout {
                                spacing: 4
                                Text {
                                    text: qsTr("Nickname")
                                    font.pixelSize: 11
                                    color: Theme.textMuted
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 36
                                        radius: 10
                                        color: Theme.surfaceContainer
                                        border.width: 1
                                        border.color: nickInput.activeFocus ? Theme.primary : Theme.borderSubtle

                                        TextInput {
                                            id: nickInput
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            verticalAlignment: TextInput.AlignVCenter
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: Theme.textPrimary
                                            text: ConfigManager.nickname
                                            selectByMouse: true
                                            onAccepted: {
                                                ConfigManager.setNickname(text);
                                                nickInput.focus = false;
                                                toastBanner.show(qsTr("Settings saved"));
                                            }
                                            onEditingFinished: {
                                                ConfigManager.setNickname(text);
                                            }
                                        }
                                    }

                                    Rectangle {
                                        implicitWidth: 60
                                        implicitHeight: 36
                                        radius: 10
                                        color: nickSaveMouse.pressed ? Qt.darker(Theme.primary, 1.1) : (nickSaveMouse.containsMouse ? Qt.lighter(Theme.primary, 1.1) : Theme.primary)
                                        scale: nickSaveMouse.pressed ? 0.92 : 1.0

                                        Behavior on scale {
                                            NumberAnimation { duration: 100 }
                                        }
                                        Behavior on color {
                                            ColorAnimation { duration: 120 }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: qsTr("Save")
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: Theme.colorOnPrimary
                                        }

                                        MouseArea {
                                            id: nickSaveMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                ConfigManager.setNickname(nickInput.text);
                                                nickInput.focus = false;
                                                toastBanner.show(qsTr("Settings saved"));
                                            }
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                spacing: 12
                                Rectangle {
                                    implicitWidth: 124
                                    implicitHeight: 30
                                    radius: 15
                                    color: selectAvatarMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        SvgIcon {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 12
                                            height: 12
                                            source: "qrc:/assets/icons/camera.svg"
                                            color: Theme.primary
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: qsTr("Select Local Avatar")
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: Theme.primary
                                        }
                                    }

                                    MouseArea {
                                        id: selectAvatarMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: ConfigManager.openSelectAvatarDialog()
                                    }
                                }

                                Text {
                                    text: qsTr("Reset Default Avatar")
                                    font.pixelSize: 11
                                    color: resetAvatarMouse.containsMouse ? Theme.textPrimary : Theme.textMuted
                                    MouseArea {
                                        id: resetAvatarMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: ConfigManager.resetAvatar()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ================================================================
            // 4. Appearance & Themes Card (Appearance & Personalization)
            // ================================================================
            Rectangle {
                visible: settingsScroll.matchesSearch(["appearance", "theme", "dark", "light", "seed", "color", "lyrics", "sidebar", "rail", "外观", "显示", "主题", "深色", "浅色", "种子色", "颜色", "歌词", "侧边栏"])
                Layout.fillWidth: true
                implicitHeight: appearCol.implicitHeight + 36
                radius: 16
                color: Theme.surfaceContainerLow
                border.width: 1
                border.color: Theme.borderSubtle

                ColumnLayout {
                    id: appearCol
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 16

                    RowLayout {
                        spacing: 8
                        SvgIcon {
                            width: 16
                            height: 16
                            source: "qrc:/assets/icons/palette.svg"
                            color: Theme.primary
                        }
                        Text {
                            text: qsTr("Appearance & Personalization")
                            font.pixelSize: 14
                            font.bold: true
                            color: Theme.primary
                        }
                    }

                    // 1) Theme Mode (System / Dark / Light)
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: qsTr("Color Mode")
                                font.pixelSize: 13
                                font.bold: true
                                color: Theme.textPrimary
                            }
                            Text {
                                text: qsTr("Dark / Light / Follow system appearance")
                                font.pixelSize: 11
                                color: Theme.textMuted
                            }
                        }
                        Item { Layout.fillWidth: true }
                        M3SegmentedButton {
                            currentValue: ConfigManager.themeMode
                            Binding on currentValue { value: ConfigManager.themeMode }
                            model: [
                                { value: "system", label: qsTr("System"), icon: "qrc:/assets/icons/desktop.svg" },
                                { value: "dark", label: qsTr("Dark"), icon: "qrc:/assets/icons/moon.svg" },
                                { value: "light", label: qsTr("Light"), icon: "qrc:/assets/icons/sun.svg" }
                            ]
                            onValueSelected: function(val) {
                                ConfigManager.setThemeMode(val);
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.borderSubtle
                    }

                    // 2) M3 Seed Color Palette
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: qsTr("Dynamic Seed Color (Material You)")
                                font.pixelSize: 13
                                font.bold: true
                                color: Theme.textPrimary
                            }
                            Text {
                                text: qsTr("Recalculate global M3 palette dynamically based on seed color")
                                font.pixelSize: 11
                                color: Theme.textMuted
                            }
                        }

                        // Preset Colors Flow
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Repeater {
                                model: [
                                    { hex: "#39C5BB", name: "Miku Teal" },
                                    { hex: "#6750A4", name: "M3 Purple" },
                                    { hex: "#00639B", name: "Ocean Blue" },
                                    { hex: "#9C4146", name: "Crimson Red" },
                                    { hex: "#4C662B", name: "Forest Green" },
                                    { hex: "#825500", name: "Amber Gold" },
                                    { hex: "#7D5260", name: "Dusty Rose" },
                                    { hex: "#006874", name: "Deep Cyan" }
                                ]

                                Rectangle {
                                    id: seedDot
                                    readonly property bool isSelected: ConfigManager.seedColor.toLowerCase() === modelData.hex.toLowerCase()
                                    width: 32
                                    height: 32
                                    radius: 16
                                    color: modelData.hex
                                    border.width: isSelected ? 2 : 0
                                    border.color: Theme.textPrimary
                                    scale: isSelected ? 1.15 : (dotMouse.containsMouse ? 1.08 : 1.0)

                                    Behavior on scale {
                                        NumberAnimation { duration: 150; easing.type: Easing.OutBack }
                                    }

                                    SvgIcon {
                                        visible: seedDot.isSelected
                                        anchors.centerIn: parent
                                        width: 14
                                        height: 14
                                        source: "qrc:/assets/icons/check.svg"
                                        color: "#FFFFFF"
                                    }

                                    MouseArea {
                                        id: dotMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            ConfigManager.setSeedColor(modelData.hex);
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Custom Color Input Box
                            Rectangle {
                                implicitWidth: 104
                                implicitHeight: 34
                                radius: 17
                                color: Theme.surfaceContainer
                                border.width: 1
                                border.color: customHexInput.activeFocus ? Theme.primary : Theme.borderSubtle

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Rectangle {
                                        width: 16
                                        height: 16
                                        radius: 8
                                        color: ConfigManager.seedColor
                                    }

                                    TextInput {
                                        id: customHexInput
                                        text: ConfigManager.seedColor
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: Theme.textPrimary
                                        selectByMouse: true
                                        onEditingFinished: {
                                            ConfigManager.setSeedColor(text);
                                        }
                                    }
                                }
                            }

                            // Color Picker Toggle Button
                            Rectangle {
                                id: paletteBtn
                                implicitWidth: paletteBtnRow.implicitWidth + 20
                                implicitHeight: 34
                                radius: 17
                                color: palettePopup.visible ? Theme.primaryContainer : (pickerToggleMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer)
                                border.width: 1
                                border.color: palettePopup.visible ? Theme.primary : Theme.borderSubtle

                                RowLayout {
                                    id: paletteBtnRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    SvgIcon {
                                        width: 14
                                        height: 14
                                        source: "qrc:/assets/icons/palette.svg"
                                        color: palettePopup.visible ? Theme.primary : Theme.textPrimary
                                    }

                                    Text {
                                        text: qsTr("Palette")
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: palettePopup.visible ? Theme.primary : Theme.textPrimary
                                    }
                                }

                                MouseArea {
                                    id: pickerToggleMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (palettePopup.visible) {
                                            palettePopup.close();
                                        } else {
                                            palettePopup.openBelow(paletteBtn);
                                        }
                                    }
                                }
                            }
                        }

                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.borderSubtle
                    }

                    // 3) Lyrics Alignment
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: qsTr("Lyrics Alignment")
                                font.pixelSize: 13
                                font.bold: true
                                color: Theme.textPrimary
                            }
                            Text {
                                text: qsTr("Lyrics text alignment direction in viewport")
                                font.pixelSize: 11
                                color: Theme.textMuted
                            }
                        }
                        Item { Layout.fillWidth: true }
                        M3SegmentedButton {
                            currentValue: ConfigManager.lyricsAlign
                            model: [
                                { value: "left", label: qsTr("Left") },
                                { value: "center", label: qsTr("Center") },
                                { value: "right", label: qsTr("Right") }
                            ]
                            onValueSelected: function(val) {
                                ConfigManager.setLyricsAlign(val);
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.borderSubtle
                    }

                    // 4) Lyrics Font Size
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: qsTr("Lyrics Font Size")
                                font.pixelSize: 13
                                font.bold: true
                                color: Theme.textPrimary
                            }
                            Text {
                                text: qsTr("Base font size for active lyric line (14px ~ 64px)")
                                font.pixelSize: 11
                                color: Theme.textMuted
                            }
                        }
                        Item { Layout.fillWidth: true }
                        RowLayout {
                            spacing: 8

                            Rectangle {
                                implicitWidth: 72
                                implicitHeight: 34
                                radius: 10
                                color: Theme.surfaceContainer
                                border.width: 1
                                border.color: fontSizeInput.activeFocus ? Theme.primary : Theme.borderSubtle

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    TextInput {
                                        id: fontSizeInput
                                        text: ConfigManager.lyricsFontSize.toString()
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: Theme.textPrimary
                                        horizontalAlignment: TextInput.AlignRight
                                        validator: IntValidator { bottom: 14; top: 64 }
                                        selectByMouse: true

                                        function commitValue() {
                                            var val = parseInt(text);
                                            if (isNaN(val)) val = 28;
                                            if (val < 14) val = 14;
                                            if (val > 64) val = 64;
                                            text = val.toString();
                                            ConfigManager.setLyricsFontSize(val);
                                        }

                                        onAccepted: {
                                            commitValue();
                                            fontSizeInput.focus = false;
                                            toastBanner.show(qsTr("Settings saved"));
                                        }
                                        onEditingFinished: {
                                            commitValue();
                                        }
                                    }

                                    Text {
                                        text: "px"
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: Theme.primary
                                    }
                                }
                            }

                            Rectangle {
                                implicitWidth: 54
                                implicitHeight: 34
                                radius: 10
                                color: fontSaveMouse.pressed ? Qt.darker(Theme.primary, 1.1) : (fontSaveMouse.containsMouse ? Qt.lighter(Theme.primary, 1.1) : Theme.primary)
                                scale: fontSaveMouse.pressed ? 0.92 : 1.0

                                Behavior on scale {
                                    NumberAnimation { duration: 100 }
                                }
                                Behavior on color {
                                    ColorAnimation { duration: 120 }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: qsTr("Save")
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: Theme.colorOnPrimary
                                }

                                MouseArea {
                                    id: fontSaveMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        fontSizeInput.commitValue();
                                        fontSizeInput.focus = false;
                                        toastBanner.show(qsTr("Settings saved"));
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.borderSubtle
                    }

                    // 5) Show Translation Switch
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: qsTr("Show Bilingual Translation")
                                font.pixelSize: 13
                                font.bold: true
                                color: Theme.textPrimary
                            }
                            Text {
                                text: qsTr("Display translation below original lyrics if available")
                                font.pixelSize: 11
                                color: Theme.textMuted
                            }
                        }
                        Item { Layout.fillWidth: true }
                        M3Switch {
                            checked: ConfigManager.showTrans
                            onToggled: function(c) {
                                ConfigManager.setShowTrans(c);
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.borderSubtle
                    }

                    // 6) Auto collapse sidebar on NowPlaying
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: qsTr("Auto Collapse Rail on NowPlaying")
                                font.pixelSize: 13
                                font.bold: true
                                color: Theme.textPrimary
                            }
                            Text {
                                text: qsTr("Automatically collapse sidebar when expanding NowPlaying")
                                font.pixelSize: 11
                                color: Theme.textMuted
                            }
                        }
                        Item { Layout.fillWidth: true }
                        M3Switch {
                            checked: ConfigManager.autoCollapseRail
                            onToggled: function(c) {
                                ConfigManager.setAutoCollapseRail(c);
                            }
                        }
                    }
                }
            }

            // ================================================================
            // 5. Audio Engine & DSP Card (Audio Engine & Hardware Output)
            // ================================================================
            Rectangle {
                visible: settingsScroll.matchesSearch(["audio", "engine", "wasapi", "output", "resampler", "replaygain", "cue", "tray", "音频", "引擎", "输出", "重采样", "回放增益", "托盘"])
                Layout.fillWidth: true
                implicitHeight: audioEngineCol.implicitHeight + 36
                radius: 16
                color: Theme.surfaceContainerLow
                border.width: 1
                border.color: Theme.borderSubtle

                ColumnLayout {
                    id: audioEngineCol
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 16

                    RowLayout {
                        spacing: 8
                        SvgIcon {
                            width: 16
                            height: 16
                            source: "qrc:/assets/icons/sliders.svg"
                            color: Theme.primary
                        }
                        Text {
                            text: qsTr("Audio Engine & Hardware Output")
                            font.pixelSize: 14
                            font.bold: true
                            color: Theme.primary
                        }
                    }

                    // Driver / Output
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: qsTr("Audio Output Mode")
                                font.pixelSize: 13
                                font.bold: true
                                color: Theme.textPrimary
                            }
                            Text {
                                text: qsTr("Exclusive bit-perfect stream or system shared mix")
                                font.pixelSize: 11
                                color: Theme.textMuted
                            }
                        }
                        Item { Layout.fillWidth: true }
                        M3ComboBox {
                            currentValue: ConfigManager.audioDriver
                            model: [
                                { value: "WASAPI Exclusive", label: "WASAPI Exclusive", subLabel: qsTr("Exclusive bit-perfect low latency output") },
                                { value: "WASAPI Shared", label: "WASAPI Shared", subLabel: qsTr("System shared mixer output") },
                                { value: "DirectSound", label: "DirectSound", subLabel: qsTr("Standard compatibility mode") }
                            ]
                            onValueChanged: function(v) {
                                ConfigManager.setAudioDriver(v);
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.borderSubtle
                    }

                    // Resampler Algorithm
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: qsTr("Resampler Algorithm")
                                font.pixelSize: 13
                                font.bold: true
                                color: Theme.textPrimary
                            }
                            Text {
                                text: qsTr("High precision 64-bit DSP sample rate conversion")
                                font.pixelSize: 11
                                color: Theme.textMuted
                            }
                        }
                        Item { Layout.fillWidth: true }
                        M3ComboBox {
                            currentValue: ConfigManager.resampler
                            model: [
                                { value: "SoX Resampler High Quality", label: "SoX Resampler (HQ)", subLabel: qsTr("High quality 64-bit resampling") },
                                { value: "Speex DSP Resampler", label: "Speex DSP", subLabel: qsTr("Fast DSP resampling") },
                                { value: "Disabled", label: qsTr("Disabled (Bypass)"), subLabel: qsTr("Direct output without resampling") }
                            ]
                            onValueChanged: function(v) {
                                ConfigManager.setResampler(v);
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.borderSubtle
                    }

                    // ReplayGain
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: qsTr("ReplayGain Mode")
                                font.pixelSize: 13
                                font.bold: true
                                color: Theme.textPrimary
                            }
                            Text {
                                text: qsTr("Automatically balance perceived loudness across tracks and albums")
                                font.pixelSize: 11
                                color: Theme.textMuted
                            }
                        }
                        Item { Layout.fillWidth: true }
                        M3ComboBox {
                            currentValue: ConfigManager.replayGain
                            model: [
                                { value: "Track Mode (-18 LUFS)", label: "Track Mode (-18 LUFS)", subLabel: qsTr("Standardize loudness per track") },
                                { value: "Album Mode", label: "Album Mode", subLabel: qsTr("Balance dynamics per album") },
                                { value: "Disabled", label: qsTr("Disabled"), subLabel: qsTr("Preserve original dynamic range") }
                            ]
                            onValueChanged: function(v) {
                                ConfigManager.setReplayGain(v);
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.borderSubtle
                    }

                    // CUE Auto Scan
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: qsTr("Auto-parse CUE Sheets")
                                font.pixelSize: 13
                                font.bold: true
                                color: Theme.textPrimary
                            }
                            Text {
                                text: qsTr("Seamlessly load tracks metadata from disc image CUE files")
                                font.pixelSize: 11
                                color: Theme.textMuted
                            }
                        }
                        Item { Layout.fillWidth: true }
                        M3Switch {
                            checked: ConfigManager.cueAutoScan
                            onToggled: function(c) {
                                ConfigManager.setCueAutoScan(c);
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.borderSubtle
                    }

                    // System Tray
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: qsTr("System Tray Icon")
                                font.pixelSize: 13
                                font.bold: true
                                color: Theme.textPrimary
                            }
                            Text {
                                text: qsTr("Minimize to system tray notification area on taskbar")
                                font.pixelSize: 11
                                color: Theme.textMuted
                            }
                        }
                        Item { Layout.fillWidth: true }
                        M3Switch {
                            checked: ConfigManager.systemTray
                            onToggled: function(c) {
                                ConfigManager.setSystemTray(c);
                            }
                        }
                    }
                }
            }

            // ================================================================
            // 6. Music Library & Folders Card (Local Library & Metadata)
            // ================================================================
            Rectangle {
                visible: settingsScroll.matchesSearch(["library", "folder", "scan", "artist", "separator", "曲库", "文件夹", "扫描", "歌手", "分隔符"])
                Layout.fillWidth: true
                implicitHeight: libCol.implicitHeight + 36
                radius: 16
                color: Theme.surfaceContainerLow
                border.width: 1
                border.color: Theme.borderSubtle

                ColumnLayout {
                    id: libCol
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 16

                    RowLayout {
                        spacing: 8
                        SvgIcon {
                            width: 16
                            height: 16
                            source: "qrc:/assets/icons/folder.svg"
                            color: Theme.primary
                        }
                        Text {
                            text: qsTr("Local Library & Metadata")
                            font.pixelSize: 14
                            font.bold: true
                            color: Theme.primary
                        }
                    }

                    // Folders Toolbar
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: qsTr("Scanned Music Folders (%1)").arg(ConfigManager.scannedFolders.length)
                                font.pixelSize: 13
                                font.bold: true
                                color: Theme.textPrimary
                            }
                            Text {
                                text: qsTr("Manage directories scanned for audio files")
                                font.pixelSize: 11
                                color: Theme.textMuted
                            }
                        }

                        Item { Layout.fillWidth: true }

                        RowLayout {
                            spacing: 10

                            // Add folder button
                            Rectangle {
                                implicitWidth: 104
                                implicitHeight: 32
                                radius: 16
                                color: addFolderMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer
                                scale: addFolderMouse.pressed ? 0.94 : (addFolderMouse.containsMouse ? 1.04 : 1.0)

                                Behavior on scale {
                                    NumberAnimation { duration: 100 }
                                }
                                Behavior on color {
                                    ColorAnimation { duration: 120 }
                                }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    SvgIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 14
                                        height: 14
                                        source: "qrc:/assets/icons/folder_plus.svg"
                                        color: Theme.primary
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("Add Folder")
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: Theme.primary
                                    }
                                }

                                MouseArea {
                                    id: addFolderMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ConfigManager.openAddFolderDialog()
                                }
                            }

                            // Rescan button
                            Rectangle {
                                implicitWidth: 96
                                implicitHeight: 32
                                radius: 16
                                color: rescanMouse.containsMouse ? Theme.primaryContainer : Theme.surfaceContainer
                                scale: rescanMouse.pressed ? 0.94 : (rescanMouse.containsMouse ? 1.04 : 1.0)

                                Behavior on scale {
                                    NumberAnimation { duration: 100 }
                                }
                                Behavior on color {
                                    ColorAnimation { duration: 120 }
                                }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    SvgIcon {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 14
                                        height: 14
                                        source: "qrc:/assets/icons/refresh.svg"
                                        color: Theme.primary
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: qsTr("Rescan Now")
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: Theme.primary
                                    }
                                }

                                MouseArea {
                                    id: rescanMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ConfigManager.rescanLibrary()
                                }
                            }
                        }
                    }

                    // Scanned Folders List
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Repeater {
                            model: ConfigManager.scannedFolders

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                radius: 10
                                color: folderItemMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer

                                MouseArea {
                                    id: folderItemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    SvgIcon {
                                        width: 14
                                        height: 14
                                        source: "qrc:/assets/icons/folder_open.svg"
                                        color: Theme.primary
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData
                                        font.pixelSize: 12
                                        color: Theme.textPrimary
                                        elide: Text.ElideMiddle
                                    }

                                    Rectangle {
                                        z: 10
                                        width: 24
                                        height: 24
                                        radius: 12
                                        color: delMouse.containsMouse ? Qt.rgba(1, 0, 0, 0.2) : "transparent"

                                        SvgIcon {
                                            anchors.centerIn: parent
                                            width: 12
                                            height: 12
                                            source: "qrc:/assets/icons/trash.svg"
                                            color: delMouse.containsMouse ? "#FF6B6B" : Theme.textMuted
                                        }

                                        MouseArea {
                                            id: delMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                ConfigManager.removeScannedFolder(modelData);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            visible: ConfigManager.scannedFolders.length === 0
                            text: qsTr("No music folders added. Click \"Add Folder\" to import local audio.")
                            font.pixelSize: 12
                            color: Theme.textMuted
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 8
                            Layout.bottomMargin: 8
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.borderSubtle
                    }

                    // Artist Separators
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: qsTr("Artist Multiple Separators")
                                font.pixelSize: 13
                                font.bold: true
                                color: Theme.textPrimary
                            }
                            Text {
                                text: qsTr("Characters used to split multiple artists (e.g. / or ,)")
                                font.pixelSize: 11
                                color: Theme.textMuted
                            }
                        }
                        Item { Layout.fillWidth: true }
                        RowLayout {
                            spacing: 8

                            Rectangle {
                                implicitWidth: 72
                                implicitHeight: 34
                                radius: 10
                                color: Theme.surfaceContainer
                                border.width: 1
                                border.color: sepInput.activeFocus ? Theme.primary : Theme.borderSubtle

                                TextInput {
                                    id: sepInput
                                    anchors.fill: parent
                                    horizontalAlignment: TextInput.AlignHCenter
                                    verticalAlignment: TextInput.AlignVCenter
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: Theme.textPrimary
                                    text: ConfigManager.artistSeparators
                                    selectByMouse: true
                                    onAccepted: {
                                        ConfigManager.setArtistSeparators(text);
                                        sepInput.focus = false;
                                        toastBanner.show(qsTr("Settings saved"));
                                    }
                                    onEditingFinished: {
                                        ConfigManager.setArtistSeparators(text);
                                    }
                                }
                            }

                            Rectangle {
                                implicitWidth: 54
                                implicitHeight: 34
                                radius: 10
                                color: sepSaveMouse.pressed ? Qt.darker(Theme.primary, 1.1) : (sepSaveMouse.containsMouse ? Qt.lighter(Theme.primary, 1.1) : Theme.primary)
                                scale: sepSaveMouse.pressed ? 0.92 : 1.0

                                Behavior on scale {
                                    NumberAnimation { duration: 100 }
                                }
                                Behavior on color {
                                    ColorAnimation { duration: 120 }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: qsTr("Save")
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: Theme.colorOnPrimary
                                }

                                MouseArea {
                                    id: sepSaveMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        ConfigManager.setArtistSeparators(sepInput.text);
                                        sepInput.focus = false;
                                        toastBanner.show(qsTr("Settings saved"));
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ================================================================
            // 7. General & Language Card (General & Language)
            // ================================================================
            Rectangle {
                visible: settingsScroll.matchesSearch(["language", "general", "locale", "chinese", "english", "japanese", "语言", "常规", "中文"])
                Layout.fillWidth: true
                implicitHeight: genCol.implicitHeight + 36
                radius: 16
                color: Theme.surfaceContainerLow
                border.width: 1
                border.color: Theme.borderSubtle

                ColumnLayout {
                    id: genCol
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 16

                    RowLayout {
                        spacing: 8
                        SvgIcon {
                            width: 16
                            height: 16
                            source: "qrc:/assets/icons/globe.svg"
                            color: Theme.primary
                        }
                        Text {
                            text: qsTr("General & Language")
                            font.pixelSize: 14
                            font.bold: true
                            color: Theme.primary
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: qsTr("UI Language")
                                font.pixelSize: 13
                                font.bold: true
                                color: Theme.textPrimary
                            }
                            Text {
                                text: qsTr("Select interface language dictionary")
                                font.pixelSize: 11
                                color: Theme.textMuted
                            }
                        }
                        Item { Layout.fillWidth: true }
                        M3ComboBox {
                            id: langCombo
                            objectName: "langComboBox"
                            currentValue: ConfigManager.language
                            Binding on currentValue {
                                value: ConfigManager.language
                            }
                            model: [
                                { value: "system", label: qsTr("System") },
                                { value: "zh", label: "简体中文" },
                                { value: "en", label: "English" },
                                { value: "ja", label: "日本語" }
                            ]
                            onValueChanged: function(v) {
                                ConfigManager.setLanguage(v);
                            }
                        }
                    }
                }
            }

            // ================================================================
            // 8. About Card (About 0rhxPlayer)
            // ================================================================
            Rectangle {
                visible: settingsScroll.matchesSearch(["about", "version", "github", "developer", "license", "关于", "版本", "开发", "协议"])
                Layout.fillWidth: true
                implicitHeight: aboutCol.implicitHeight + 36
                radius: 16
                color: Theme.surfaceContainerLow
                border.width: 1
                border.color: Theme.borderSubtle

                ColumnLayout {
                    id: aboutCol
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 16

                    RowLayout {
                        spacing: 8
                        SvgIcon {
                            width: 16
                            height: 16
                            source: "qrc:/assets/icons/info.svg"
                            color: Theme.primary
                        }
                        Text {
                            text: qsTr("About 0rhxPlayer")
                            font.pixelSize: 14
                            font.bold: true
                            color: Theme.primary
                        }
                    }

                    // Banner
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16

                        Rectangle {
                            width: 48
                            height: 48
                            radius: 14
                            color: Theme.primaryContainer

                            SvgIcon {
                                anchors.centerIn: parent
                                width: 26
                                height: 26
                                source: "qrc:/assets/icons/disc.svg"
                                color: Theme.colorOnPrimaryContainer
                            }
                        }

                        ColumnLayout {
                            spacing: 3
                            RowLayout {
                                spacing: 8
                                Text {
                                    text: "0rhxPlayer"
                                    font.pixelSize: 16
                                    font.bold: true
                                    color: Theme.textPrimary
                                }
                                Rectangle {
                                    implicitWidth: 54
                                    implicitHeight: 20
                                    radius: 10
                                    color: Theme.primaryContainer
                                    Text {
                                        anchors.centerIn: parent
                                        text: "v1.1.0"
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: Theme.colorOnPrimaryContainer
                                    }
                                }
                            }
                            Text {
                                text: qsTr("Lightweight, minimalist, audiophile-grade native local music player")
                                font.pixelSize: 11
                                color: Theme.textMuted
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.borderSubtle
                    }

                    // Developer
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: qsTr("Developer")
                            font.pixelSize: 12
                            color: Theme.textMuted
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "RinCynar"
                            font.pixelSize: 12
                            font.bold: true
                            color: devMouse.containsMouse ? Theme.primary : Theme.textPrimary

                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }

                            MouseArea {
                                id: devMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Qt.openUrlExternally("https://rincynar.top")
                            }
                        }
                    }

                    // Website
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: qsTr("Official Website")
                            font.pixelSize: 12
                            color: Theme.textMuted
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "0rhxPlayer.rincynar.top"
                            font.pixelSize: 12
                            font.bold: true
                            color: webMouse.containsMouse ? Theme.primary : Theme.textPrimary
                            MouseArea {
                                id: webMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Qt.openUrlExternally("https://0rhxPlayer.rincynar.top")
                            }
                        }
                    }

                    // GitHub
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: qsTr("Source Code")
                            font.pixelSize: 12
                            color: Theme.textMuted
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "RinCynar/0rhxPlayer-Desktop"
                            font.pixelSize: 12
                            font.bold: true
                            color: gitMouse.containsMouse ? Theme.primary : Theme.textPrimary
                            MouseArea {
                                id: gitMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Qt.openUrlExternally("https://github.com/RinCynar/0rhxPlayer-Desktop")
                            }
                        }
                    }

                    // License
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: qsTr("License")
                            font.pixelSize: 12
                            color: Theme.textMuted
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "MIT License"
                            font.pixelSize: 12
                            font.bold: true
                            color: Theme.textPrimary
                        }
                    }
                }
            }

            Item { height: 24 }
        }
    }
    }

    // Floating Toast Notification
    Rectangle {
        id: toastBanner
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        z: 9999
        implicitHeight: 38
        implicitWidth: toastRow.implicitWidth + 32
        radius: 19
        color: Theme.colorOnSurface
        opacity: toastTimer.running ? 0.95 : 0.0
        scale: toastTimer.running ? 1.0 : 0.85
        visible: opacity > 0

        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        RowLayout {
            id: toastRow
            anchors.centerIn: parent
            spacing: 8
            SvgIcon {
                width: 16
                height: 16
                source: "qrc:/assets/icons/check.svg"
                color: Theme.surface
            }
            Text {
                id: toastText
                text: qsTr("Settings saved")
                font.pixelSize: 13
                font.bold: true
                color: Theme.surface
            }
        }

        Timer {
            id: toastTimer
            interval: 2000
            repeat: false
        }

        function show(msg) {
            toastText.text = msg || qsTr("Settings saved");
            toastTimer.restart();
        }
    }
}
