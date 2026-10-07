import QtQuick
import rhx.theme 1.0

Item {
    id: switchRoot
    implicitWidth: 52
    implicitHeight: 32

    property bool checked: false
    signal toggled(bool checked)

    Rectangle {
        id: track
        anchors.fill: parent
        radius: 16
        color: switchRoot.checked ? Theme.primary : Theme.surfaceContainerHighest
        border.width: switchRoot.checked ? 0 : 2
        border.color: switchRoot.checked ? "transparent" : Theme.outline

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
        Behavior on border.color {
            ColorAnimation { duration: 150 }
        }

        // Switch thumb handle
        Rectangle {
            id: thumb
            width: switchRoot.checked ? 24 : (mouseArea.pressed ? 20 : (mouseArea.containsMouse ? 18 : 16))
            height: width
            radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            x: switchRoot.checked ? (parent.width - width - 4) : 4
            color: switchRoot.checked ? Theme.colorOnPrimary : (mouseArea.containsMouse ? Theme.textPrimary : Theme.outline)

            Behavior on x {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
            Behavior on width {
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
            Behavior on color {
                ColorAnimation { duration: 150 }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            switchRoot.toggled(!switchRoot.checked);
        }
    }
}
