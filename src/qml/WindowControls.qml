import QtQuick
import QtQuick.Controls.Basic
import rhx.ui 1.0
import rhx.theme 1.0

Row {
    id: root
    height: 32
    spacing: 0

    // ------------------------------------------------------------------------
    // 1. Minimize Button
    // ------------------------------------------------------------------------
    Rectangle {
        id: minBtn
        width: 46
        height: 32
        color: minArea.pressed ? Theme.surfaceContainerHighest : (minArea.containsMouse ? Theme.surfaceContainerHigh : "transparent")

        SvgIcon {
            anchors.centerIn: parent
            width: 10
            height: 10
            source: "qrc:/assets/icons/win_minimize.svg"
            color: minArea.containsMouse ? Theme.textPrimary : Theme.iconNeutral
        }

        MouseArea {
            id: minArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.ArrowCursor
            onClicked: {
                window.showMinimized();
            }
        }
    }

    // ------------------------------------------------------------------------
    // 2. Maximize / Restore Button
    // ------------------------------------------------------------------------
    Rectangle {
        id: maxBtn
        width: 46
        height: 32
        color: maxArea.pressed ? Theme.surfaceContainerHighest : (maxArea.containsMouse ? Theme.surfaceContainerHigh : "transparent")

        SvgIcon {
            anchors.centerIn: parent
            width: 10
            height: 10
            source: window.visibility === Window.Maximized ? "qrc:/assets/icons/win_restore.svg" : "qrc:/assets/icons/win_maximize.svg"
            color: maxArea.containsMouse ? Theme.textPrimary : Theme.iconNeutral
        }

        MouseArea {
            id: maxArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.ArrowCursor
            onClicked: {
                window.toggleMaximize();
            }
        }
    }

    // ------------------------------------------------------------------------
    // 3. Close Button
    // ------------------------------------------------------------------------
    Rectangle {
        id: closeBtn
        width: 46
        height: 32
        color: closeArea.pressed ? "#C42B1C" : (closeArea.containsMouse ? "#E81123" : "transparent")

        SvgIcon {
            anchors.centerIn: parent
            width: 10
            height: 10
            source: "qrc:/assets/icons/win_close.svg"
            color: closeArea.containsMouse ? "#FFFFFF" : Theme.iconNeutral
        }

        MouseArea {
            id: closeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.ArrowCursor
            onClicked: {
                window.close();
            }
        }
    }
}
