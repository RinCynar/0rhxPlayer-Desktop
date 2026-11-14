import QtQuick
import rhx.theme 1.0
import rhx.ui 1.0

Item {
    id: chipRoot
    implicitHeight: 32
    implicitWidth: chipRow.implicitWidth + 24

    property string text: ""
    property string icon: ""
    property bool selected: false
    property bool selectable: true
    property bool closable: false
    property real radius: 8

    signal clicked()
    signal closed()

    activeFocusOnTab: enabled

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: chipRoot.radius
        color: {
            if (!chipRoot.enabled) return Theme.surfaceContainerLowest;
            if (selected) return Theme.secondaryContainer;
            if (mouseArea.containsMouse) return Theme.surfaceContainerHigh;
            return Theme.surfaceContainerLow;
        }
        border.width: chipRoot.activeFocus ? 2 : (selected ? 0 : 1)
        border.color: chipRoot.activeFocus ? Theme.primary : Theme.outlineVariant

        scale: (chipRoot.enabled && mouseArea.pressed) ? 0.96 : 1.0

        Behavior on color {
            ColorAnimation { duration: Theme.motionDurationFast }
        }
        Behavior on scale {
            NumberAnimation { duration: Theme.motionDurationFast; easing.type: Easing.OutCubic }
        }

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6

            SvgIcon {
                visible: chipRoot.selected || chipRoot.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                source: chipRoot.selected ? "qrc:/assets/icons/check.svg" : chipRoot.icon
                color: chipRoot.selected ? Theme.colorOnSecondaryContainer : Theme.textSecondary
            }

            Text {
                id: chipText
                anchors.verticalCenter: parent.verticalCenter
                text: chipRoot.text
                font.pixelSize: 12
                font.weight: chipRoot.selected ? Font.Medium : Font.Normal
                color: chipRoot.selected ? Theme.colorOnSecondaryContainer : (chipRoot.enabled ? Theme.textPrimary : Theme.textMuted)
            }

            Item {
                visible: chipRoot.closable
                width: 14
                height: 14
                anchors.verticalCenter: parent.verticalCenter

                SvgIcon {
                    anchors.centerIn: parent
                    width: 12
                    height: 12
                    source: "qrc:/assets/icons/win_close.svg"
                    color: closeArea.containsMouse ? Theme.primary : Theme.textMuted
                }

                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: chipRoot.closed()
                }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: chipRoot.enabled
        hoverEnabled: true
        cursorShape: chipRoot.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (chipRoot.selectable) {
                chipRoot.selected = !chipRoot.selected;
            }
            chipRoot.clicked();
        }
    }

    Keys.onReturnPressed: if (chipRoot.enabled) mouseArea.clicked(null)
    Keys.onSpacePressed: if (chipRoot.enabled) mouseArea.clicked(null)
}
