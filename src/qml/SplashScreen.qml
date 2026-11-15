import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import rhx.ui 1.0
import rhx.theme 1.0
import rhx.library 1.0
import "components"

Rectangle {
    id: splashRoot
    anchors.fill: parent
    z: 20000
    color: Theme.surface
    visible: opacity > 0.0

    readonly property bool isReady: !LibraryManager.isScanning

    onIsReadyChanged: {
        checkAndFadeOut();
    }

    Component.onCompleted: {
        checkAndFadeOut();
    }

    function checkAndFadeOut() {
        if (isReady && splashRoot.visible && !fadeOutAnim.running) {
            fadeOutAnim.start();
        }
    }

    NumberAnimation {
        id: fadeOutAnim
        target: splashRoot
        property: "opacity"
        to: 0.0
        duration: 180
        easing.type: Easing.OutQuad
        onFinished: {
            splashRoot.visible = false;
        }
    }

    // Material 3 Expressive centered loader and branding
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 24

        // Material 3 Expressive (M3e) Morphing & Rotating Loader
        M3eMorphingLoader {
            Layout.alignment: Qt.AlignHCenter
            size: 76
            color: Theme.primary
            iconColor: Theme.colorOnPrimary
            iconSource: "qrc:/assets/icons/app_icon.svg"
            running: splashRoot.visible && (typeof window !== "undefined" ? window.isForegroundActive : true)
        }

        // Minimalist Pure Brand Title
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "0rhxPlayer"
            font.pixelSize: 24
            font.bold: true
            font.letterSpacing: 0.5
            color: Theme.textPrimary
        }
    }
}
