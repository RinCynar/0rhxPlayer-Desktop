import QtQuick
import QtQuick.Controls.Basic
import rhx.theme 1.0

ScrollBar {
    id: control
    objectName: "m3ScrollBar"
    policy: ScrollBar.AsNeeded
    visible: size < 1.0
    hoverEnabled: true

    // Standardized floating safe margin from window physical edge (6px per NowPlaying capsule spec)
    anchors.rightMargin: 6

    // Hit-test & layout width spans thumb width (4px) plus right safe margin (6px) = 10px
    width: 4 + anchors.rightMargin

    // Zero out base padding and assign rightPadding so QQuickScrollBar sizes thumb to exactly 4px
    padding: 0
    leftPadding: 0
    topPadding: 0
    bottomPadding: 0
    rightPadding: anchors.rightMargin

    readonly property bool isHoveredOrActive: control.hovered || control.pressed

    background: Item {
        implicitWidth: control.width
    }

    contentItem: Rectangle {
        id: thumb
        implicitWidth: 4
        radius: 2
        color: control.isHoveredOrActive ? Theme.primary : Theme.outlineVariant
        opacity: control.isHoveredOrActive ? 1.0 : 0.6

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
    }
}

