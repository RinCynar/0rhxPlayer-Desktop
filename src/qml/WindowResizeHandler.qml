import QtQuick
import rhx.theme 1.0

Item {
    id: root
    anchors.fill: parent
    z: 10000

    readonly property int borderWidth: 6
    readonly property int cornerSize: 10
    readonly property bool isResizable: window.visibility !== Window.Maximized && window.visibility !== Window.FullScreen

    // 1px subtle window frame border (when windowed)
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 1
        border.color: Theme.borderSubtle
        radius: 8
        visible: root.isResizable
    }

    // ------------------------------------------------------------------------
    // 4 Edges
    // ------------------------------------------------------------------------
    // Top
    MouseArea {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.leftMargin: root.cornerSize
        anchors.right: parent.right
        anchors.rightMargin: root.cornerSize
        height: root.borderWidth
        enabled: root.isResizable
        cursorShape: Qt.SizeVerCursor
        onPressed: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                window.startSystemResize(Qt.TopEdge);
            }
        }
    }

    // Bottom
    MouseArea {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.leftMargin: root.cornerSize
        anchors.right: parent.right
        anchors.rightMargin: root.cornerSize
        height: root.borderWidth
        enabled: root.isResizable
        cursorShape: Qt.SizeVerCursor
        onPressed: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                window.startSystemResize(Qt.BottomEdge);
            }
        }
    }

    // Left
    MouseArea {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: root.cornerSize
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.cornerSize
        width: root.borderWidth
        enabled: root.isResizable
        cursorShape: Qt.SizeHorCursor
        onPressed: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                window.startSystemResize(Qt.LeftEdge);
            }
        }
    }

    // Right
    MouseArea {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: root.cornerSize
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.cornerSize
        width: root.borderWidth
        enabled: root.isResizable
        cursorShape: Qt.SizeHorCursor
        onPressed: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                window.startSystemResize(Qt.RightEdge);
            }
        }
    }

    // ------------------------------------------------------------------------
    // 4 Corners
    // ------------------------------------------------------------------------
    // Top-Left
    MouseArea {
        anchors.top: parent.top
        anchors.left: parent.left
        width: root.cornerSize
        height: root.cornerSize
        enabled: root.isResizable
        cursorShape: Qt.SizeFDiagCursor
        onPressed: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                window.startSystemResize(Qt.TopEdge | Qt.LeftEdge);
            }
        }
    }

    // Top-Right
    MouseArea {
        anchors.top: parent.top
        anchors.right: parent.right
        width: root.cornerSize
        height: root.cornerSize
        enabled: root.isResizable
        cursorShape: Qt.SizeBDiagCursor
        onPressed: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                window.startSystemResize(Qt.TopEdge | Qt.RightEdge);
            }
        }
    }

    // Bottom-Left
    MouseArea {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: root.cornerSize
        height: root.cornerSize
        enabled: root.isResizable
        cursorShape: Qt.SizeBDiagCursor
        onPressed: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                window.startSystemResize(Qt.BottomEdge | Qt.LeftEdge);
            }
        }
    }

    // Bottom-Right
    MouseArea {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: root.cornerSize
        height: root.cornerSize
        enabled: root.isResizable
        cursorShape: Qt.SizeFDiagCursor
        onPressed: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                window.startSystemResize(Qt.BottomEdge | Qt.RightEdge);
            }
        }
    }
}
