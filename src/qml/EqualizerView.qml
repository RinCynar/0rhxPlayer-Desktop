import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import rhx.ui 1.0
import rhx.theme 1.0
import rhx.audio 1.0

Item {
    id: root
    objectName: "equalizerView"

    readonly property var bandFrequencies: [
        { label: "31 Hz", freq: 31.25 },
        { label: "62 Hz", freq: 62.5 },
        { label: "125 Hz", freq: 125.0 },
        { label: "250 Hz", freq: 250.0 },
        { label: "500 Hz", freq: 500.0 },
        { label: "1 kHz", freq: 1000.0 },
        { label: "2 kHz", freq: 2000.0 },
        { label: "4 kHz", freq: 4000.0 },
        { label: "8 kHz", freq: 8000.0 },
        { label: "16 kHz", freq: 16000.0 }
    ]

    readonly property var presetNames: [
        "Flat", "Rock", "Pop", "Classical", "Bass Boost", "Vocal", "Electronic", "Jazz"
    ]

    function formatDb(val) {
        if (Math.abs(val) < 0.05) return "0.0 dB";
        return (val > 0 ? "+" : "") + Number(val).toFixed(1) + " dB";
    }

    // Solid Window-level Background (100% Flat M3)
    Rectangle {
        anchors.fill: parent
        color: Theme.surface
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
    // Standard Page Header: Title + Subtitle + Master Switch & Reset
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

        // Title Column
        ColumnLayout {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            RowLayout {
                spacing: 10

                SvgIcon {
                    width: 24
                    height: 24
                    source: "qrc:/assets/icons/sliders.svg"
                    color: Theme.primary
                }

                Text {
                    text: qsTr("Equalizer")
                    font.pixelSize: 28
                    font.bold: true
                    color: Theme.textPrimary
                }
            }

            Text {
                text: qsTr("10-Band Pro Graphic Equalizer with Biquad Filters & Gain Control")
                font.pixelSize: 13
                color: Theme.textMuted
            }
        }

        // Top Right: Reset Button + Master Switch
        RowLayout {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16

            // Reset Capsule Button
            Rectangle {
                height: 34
                radius: 17
                color: resetMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerLow
                border.width: 1
                border.color: Theme.borderSubtle
                implicitWidth: resetRow.implicitWidth + 22

                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    id: resetRow
                    anchors.centerIn: parent
                    spacing: 6

                    SvgIcon {
                        width: 13
                        height: 13
                        source: "qrc:/assets/icons/refresh.svg"
                        color: Theme.textPrimary
                    }

                    Text {
                        text: qsTr("Reset")
                        font.pixelSize: 12
                        font.bold: true
                        color: Theme.textPrimary
                    }
                }

                MouseArea {
                    id: resetMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AudioEngine.resetEq()
                }
            }

            // Master Switch & Label
            RowLayout {
                spacing: 10

                Text {
                    text: AudioEngine.eqEnabled ? qsTr("Enabled") : qsTr("Bypass")
                    font.pixelSize: 13
                    font.bold: true
                    color: AudioEngine.eqEnabled ? Theme.primary : Theme.textMuted
                }

                M3Switch {
                    id: masterSwitch
                    checked: AudioEngine.eqEnabled
                    onToggled: function(val) {
                        AudioEngine.setEqEnabled(val);
                    }
                }
            }
        }
    }

    // ========================================================================
    // Scrollable Equalizer Controls Area
    // ========================================================================
    Flickable {
        id: eqFlickable
        anchors.top: pageHeader.bottom
        anchors.topMargin: 20
        anchors.left: parent.left
        anchors.leftMargin: 32
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.bottom: parent.bottom
        contentWidth: width - 16
        contentHeight: eqContentCol.implicitHeight + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: M3ScrollBar {
            anchors.right: parent.right
            anchors.rightMargin: 6
        }

        ColumnLayout {
            id: eqContentCol
            width: eqFlickable.contentWidth
            spacing: 20

            // ----------------------------------------------------------------
            // 1. Sound Presets Card
            // ----------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                radius: 20
                color: Theme.surfaceContainerLow
                border.width: 1
                border.color: Theme.borderSubtle
                implicitHeight: presetCol.implicitHeight + 36

                ColumnLayout {
                    id: presetCol
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    Text {
                        text: qsTr("Sound Presets")
                        font.pixelSize: 11
                        font.bold: true
                        color: Theme.textMuted
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 10

                        Repeater {
                            model: root.presetNames

                            delegate: Rectangle {
                                id: presetChip
                                readonly property bool isActive: (AudioEngine.eqPreset === modelData)
                                height: 32
                                radius: 16
                                color: isActive ? Theme.primary : (chipMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer)
                                border.width: 1
                                border.color: isActive ? Theme.primary : Theme.borderSubtle
                                implicitWidth: chipText.implicitWidth + 24

                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    id: chipText
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.pixelSize: 12
                                    font.bold: presetChip.isActive
                                    color: presetChip.isActive ? Theme.onPrimary : Theme.textPrimary
                                }

                                MouseArea {
                                    id: chipMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        AudioEngine.applyEqPreset(modelData);
                                    }
                                }
                            }
                        }

                        // Custom Preset Indicator Chip
                        Rectangle {
                            visible: AudioEngine.eqPreset === "Custom"
                            height: 32
                            radius: 16
                            color: Theme.primary
                            implicitWidth: customChipText.implicitWidth + 24

                            Text {
                                id: customChipText
                                anchors.centerIn: parent
                                text: qsTr("Custom")
                                font.pixelSize: 12
                                font.bold: true
                                color: Theme.onPrimary
                            }
                        }
                    }
                }
            }

            // ----------------------------------------------------------------
            // 2. Preamp & 10-Band Sliders Card (Disabled & dimmed if bypass)
            // ----------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                radius: 20
                color: Theme.surfaceContainerLow
                border.width: 1
                border.color: Theme.borderSubtle
                implicitHeight: slidersMainCol.implicitHeight + 40
                opacity: AudioEngine.eqEnabled ? 1.0 : 0.5
                enabled: AudioEngine.eqEnabled

                Behavior on opacity { NumberAnimation { duration: 200 } }

                ColumnLayout {
                    id: slidersMainCol
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 24

                    // A. Preamp Horizontal Slider Box
                    Rectangle {
                        Layout.fillWidth: true
                        height: 68
                        radius: 16
                        color: Theme.surfaceContainer
                        border.width: 1
                        border.color: Theme.borderSubtle

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 16

                            // Preamp Icon + Info
                            RowLayout {
                                spacing: 12
                                Layout.preferredWidth: 320

                                Rectangle {
                                    width: 38
                                    height: 38
                                    radius: 12
                                    color: Theme.primary

                                    SvgIcon {
                                        anchors.centerIn: parent
                                        width: 18
                                        height: 18
                                        source: "qrc:/assets/icons/sliders.svg"
                                        color: Theme.onPrimary
                                    }
                                }

                                ColumnLayout {
                                    spacing: 2

                                    Text {
                                        text: qsTr("Preamp")
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: Theme.textPrimary
                                    }

                                    Text {
                                        text: qsTr("Boost or attenuate master input to prevent clipping (Double-click to reset)")
                                        font.pixelSize: 11
                                        color: Theme.textMuted
                                        elide: Text.ElideRight
                                        Layout.maximumWidth: 260
                                    }
                                }
                            }

                            // Horizontal Slider Area
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 12

                                Text {
                                    text: "-12 dB"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: Theme.textMuted
                                }

                                // Interactive Preamp Slider Track
                                Item {
                                    id: preampSliderTrack
                                    Layout.fillWidth: true
                                    height: 28

                                    // Track Background
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: parent.width
                                        height: 6
                                        radius: 3
                                        color: Theme.surfaceContainerHighest

                                        // Center 0dB Notch
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 2
                                            height: 12
                                            radius: 1
                                            color: Theme.outline
                                        }

                                        // Active Bidirectional Fill from Center
                                        Rectangle {
                                            readonly property real centerPos: parent.width * 0.5
                                            readonly property real currentRatio: (Math.max(-12.0, Math.min(12.0, AudioEngine.eqPreamp)) + 12.0) / 24.0
                                            readonly property real thumbPos: currentRatio * parent.width
                                            x: Math.min(centerPos, thumbPos)
                                            y: 0
                                            width: Math.abs(thumbPos - centerPos)
                                            height: parent.height
                                            radius: 3
                                            color: Theme.primary
                                        }
                                    }

                                    // Preamp Thumb Handle
                                    Rectangle {
                                        id: preampThumb
                                        readonly property real currentRatio: (Math.max(-12.0, Math.min(12.0, AudioEngine.eqPreamp)) + 12.0) / 24.0
                                        x: Math.max(0, Math.min(parent.width - width, currentRatio * parent.width - width * 0.5))
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 18
                                        height: 18
                                        radius: 9
                                        color: Theme.primary
                                        border.width: 2
                                        border.color: Theme.onPrimary
                                        scale: preampMouse.pressed ? 1.15 : (preampMouse.containsMouse ? 1.08 : 1.0)

                                        Behavior on scale { NumberAnimation { duration: 100 } }
                                    }

                                    MouseArea {
                                        id: preampMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        function updateValue(mouseX) {
                                            var ratio = Math.max(0.0, Math.min(1.0, mouseX / width));
                                            var val = (ratio * 24.0) - 12.0;
                                            val = Math.round(val * 10) / 10;
                                            AudioEngine.setEqPreamp(val);
                                        }

                                        onPositionChanged: function(mouse) {
                                            if (pressed) updateValue(mouse.x);
                                        }
                                        onPressed: function(mouse) {
                                            updateValue(mouse.x);
                                        }
                                        onDoubleClicked: {
                                            AudioEngine.setEqPreamp(0.0);
                                        }
                                    }
                                }

                                Text {
                                    text: "+12 dB"
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: Theme.textMuted
                                }

                                // Preamp Value Badge (Double click to reset)
                                Rectangle {
                                    Layout.preferredWidth: 68
                                    Layout.preferredHeight: 30
                                    radius: 8
                                    color: Theme.surfaceContainerHighest
                                    border.width: 1
                                    border.color: Theme.borderSubtle

                                    Text {
                                        anchors.centerIn: parent
                                        text: root.formatDb(AudioEngine.eqPreamp)
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: (Math.abs(AudioEngine.eqPreamp) > 0.05) ? Theme.primary : Theme.textPrimary
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onDoubleClicked: AudioEngine.setEqPreamp(0.0)
                                    }
                                }
                            }
                        }
                    }

                    // B. 10 Vertical Sliders Grid
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: root.bandFrequencies

                            delegate: Rectangle {
                                id: bandCol
                                readonly property int bandIndex: index
                                readonly property real currentGain: (AudioEngine.eqBands && AudioEngine.eqBands.length > index)
                                                                    ? AudioEngine.eqBands[index] : 0.0

                                Layout.fillWidth: true
                                height: 290
                                radius: 16
                                color: vMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                                border.width: 1
                                border.color: Theme.borderSubtle

                                Behavior on color { ColorAnimation { duration: 120 } }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8

                                    // 1. Gain Value Badge (Top, double click resets to 0.0)
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 26
                                        radius: 6
                                        color: Theme.surfaceContainerHighest

                                        Text {
                                            anchors.centerIn: parent
                                            text: root.formatDb(bandCol.currentGain)
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: (Math.abs(bandCol.currentGain) > 0.05) ? Theme.primary : Theme.textPrimary
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onDoubleClicked: AudioEngine.setEqBand(bandCol.bandIndex, 0.0)
                                        }
                                    }

                                    // 2. Vertical Slider Track Area
                                    Item {
                                        id: vSliderArea
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        // Vertical Track Background
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 6
                                            height: parent.height - 18
                                            radius: 3
                                            color: Theme.surfaceContainerHighest

                                            // 0dB Center Horizontal Notch
                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 14
                                                height: 2
                                                radius: 1
                                                color: Theme.outline
                                            }

                                            // Active Bidirectional Fill
                                            Rectangle {
                                                readonly property real trackH: parent.height
                                                readonly property real centerY: trackH * 0.5
                                                // Gain: +12 is at y=0 (top), -12 is at y=trackH (bottom)
                                                readonly property real gainRatio: (12.0 - Math.max(-12.0, Math.min(12.0, bandCol.currentGain))) / 24.0
                                                readonly property real targetY: gainRatio * trackH

                                                x: 0
                                                y: Math.min(centerY, targetY)
                                                width: parent.width
                                                height: Math.abs(targetY - centerY)
                                                radius: 3
                                                color: Theme.primary
                                            }
                                        }

                                        // Thumb Handle
                                        Rectangle {
                                            id: vThumb
                                            readonly property real trackH: parent.height - 18
                                            readonly property real gainRatio: (12.0 - Math.max(-12.0, Math.min(12.0, bandCol.currentGain))) / 24.0
                                            y: 9 + Math.max(0, Math.min(trackH, gainRatio * trackH)) - (height * 0.5)
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            width: 18
                                            height: 18
                                            radius: 9
                                            color: Theme.primary
                                            border.width: 2
                                            border.color: Theme.onPrimary
                                            scale: vMouse.pressed ? 1.15 : (vMouse.containsMouse ? 1.08 : 1.0)

                                            Behavior on scale { NumberAnimation { duration: 100 } }
                                        }

                                        MouseArea {
                                            id: vMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor

                                            function updateGain(mouseY) {
                                                var trackH = height - 18;
                                                var relY = Math.max(0.0, Math.min(trackH, mouseY - 9));
                                                var ratio = relY / trackH; // 0.0 at top (+12), 1.0 at bottom (-12)
                                                var gain = 12.0 - (ratio * 24.0);
                                                gain = Math.round(gain * 10) / 10;
                                                AudioEngine.setEqBand(bandCol.bandIndex, gain);
                                            }

                                            onPositionChanged: function(mouse) {
                                                if (pressed) updateGain(mouse.y);
                                            }
                                            onPressed: function(mouse) {
                                                updateGain(mouse.y);
                                            }
                                            onDoubleClicked: {
                                                AudioEngine.setEqBand(bandCol.bandIndex, 0.0);
                                            }
                                        }
                                    }

                                    // 3. Frequency Label (Bottom)
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.label
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: (Math.abs(bandCol.currentGain) > 0.05) ? Theme.primary : Theme.textMuted
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
