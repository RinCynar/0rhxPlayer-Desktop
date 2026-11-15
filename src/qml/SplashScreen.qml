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

    property bool minPeriodElapsed: false

    // 500ms golden animation cycle timer (allows one full M3e morphing cycle and ensures home hydration)
    Timer {
        id: minPeriodTimer
        interval: (typeof window !== "undefined" && window.isTestRun) ? 100 : 500
        running: true
        repeat: false
        onTriggered: {
            splashRoot.minPeriodElapsed = true;
            splashRoot.checkAndFadeOut();
        }
    }

    // Safety timeout to guarantee splash never blocks the UI indefinitely
    Timer {
        id: safetyTimeoutTimer
        interval: 2500
        running: true
        repeat: false
        onTriggered: {
            splashRoot.forceDismiss();
        }
    }

    // Strict readiness condition: true only when HomeView has hydrated its recommended tracks/albums
    readonly property bool isHomeReady: {
        if (typeof window !== "undefined") {
            if (window.isTestRun) return true;
            if (window.isHomeHydrated !== undefined) {
                return window.isHomeHydrated;
            }
        }
        if (typeof homeLoader !== "undefined" && homeLoader.item && typeof homeLoader.item.isContentHydrated !== "undefined") {
            return homeLoader.item.isContentHydrated;
        }
        return LibraryManager.isDataLoaded && !LibraryManager.isScanning;
    }

    readonly property bool canDismiss: minPeriodElapsed && isHomeReady

    onCanDismissChanged: {
        checkAndFadeOut();
    }

    Component.onCompleted: {
        checkAndFadeOut();
    }

    function checkAndFadeOut() {
        if (canDismiss && splashRoot.visible && !fadeOutAnim.running) {
            fadeOutAnim.start();
        }
    }

    function forceDismiss() {
        if (splashRoot.visible && !fadeOutAnim.running) {
            fadeOutAnim.start();
        }
    }

    NumberAnimation {
        id: fadeOutAnim
        target: splashRoot
        property: "opacity"
        to: 0.0
        duration: 200
        easing.type: Easing.OutQuad
        onFinished: {
            splashRoot.visible = false;
        }
    }

    // Material 3 Expressive centered branding and loader
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 16

        // 1. App Icon: 0rhxPlayer High-Definition Vector Brand Logo (72x72)
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

        // 2. App Name & Subtitle
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 4

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "0rhxPlayer"
                font.pixelSize: 26
                font.bold: true
                font.letterSpacing: 0.5
                color: Theme.textPrimary
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Native High-Fidelity Audio")
                font.pixelSize: 13
                color: Theme.textMuted
            }
        }

        Item { Layout.preferredHeight: 12 }

        // 3. Material 3 Expressive (M3e) Morphing & Rotating Loading Indicator (38x38)
        M3eMorphingLoader {
            Layout.alignment: Qt.AlignHCenter
            size: 38
            color: Theme.primary
            running: splashRoot.visible && (typeof window !== "undefined" ? window.isForegroundActive : true)
        }
    }
}
