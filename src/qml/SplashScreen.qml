import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import rhx.ui 1.0
import rhx.theme 1.0
import rhx.library 1.0

Rectangle {
    id: splashRoot
    anchors.fill: parent
    z: 20000
    color: Theme.surface
    visible: opacity > 0.0

    property bool minDurationPassed: false
    property bool isReady: minDurationPassed && !LibraryManager.isScanning

    onIsReadyChanged: {
        if (isReady) {
            fadeOutAnim.start();
        }
    }

    Timer {
        id: minTimer
        interval: 1000
        running: true
        repeat: false
        onTriggered: {
            splashRoot.minDurationPassed = true;
        }
    }

    NumberAnimation {
        id: fadeOutAnim
        target: splashRoot
        property: "opacity"
        to: 0.0
        duration: 350
        easing.type: Easing.InOutCubic
        onFinished: {
            splashRoot.visible = false;
        }
    }

    // Android 12+ style centered branding
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 20

        // App Icon: 0rhxPlayer True Vector Brand Logo
        Item {
            Layout.alignment: Qt.AlignHCenter
            width: 72
            height: 72

            SvgIcon {
                anchors.fill: parent
                source: "qrc:/assets/icons/app_icon.svg"
                color: Theme.primary
            }
        }

        // App Name & Tagline
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "0rhxPlayer"
                font.pixelSize: 26
                font.bold: true
                color: Theme.textPrimary
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Native High-Fidelity Audio")
                font.pixelSize: 13
                color: Theme.textMuted
            }
        }

        Item { height: 16 }

        // M3 Loading Indicator (Minimal 3-dot wave)
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Repeater {
                model: 3

                Rectangle {
                    id: dot
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.primary
                    opacity: 0.3

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: splashRoot.visible
                        PauseAnimation { duration: index * 180 }
                        NumberAnimation { to: 1.0; duration: 350; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 0.3; duration: 350; easing.type: Easing.InOutQuad }
                        PauseAnimation { duration: (2 - index) * 180 }
                    }
                }
            }
        }
    }
}
