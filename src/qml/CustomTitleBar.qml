import QtQuick
import QtQuick.Controls.Basic
import rhx.ui 1.0
import rhx.theme 1.0

Item {
    id: root
    height: 32
    z: 9999

    // ------------------------------------------------------------------------
    // 1. Window Drag Area & Double-Click Maximize / Restore (100% Transparent)
    // ------------------------------------------------------------------------
    MouseArea {
        id: dragArea
        anchors.left: parent.left
        anchors.right: windowControls.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        acceptedButtons: Qt.LeftButton

        onPressed: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                window.startSystemMove();
            }
        }

        onDoubleClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                window.toggleMaximize();
            }
        }
    }

    // ------------------------------------------------------------------------
    // 3. Right: Window Control Buttons (Minimize, Maximize / Restore, Close)
    // ------------------------------------------------------------------------
    WindowControls {
        id: windowControls
        anchors.right: parent.right
        anchors.top: parent.top
    }
}
