import QtQuick
import rhx.theme 1.0
import rhx.ui 1.0

Rectangle {
    id: segRoot
    implicitHeight: 38
    implicitWidth: row.implicitWidth + 8
    radius: 19
    color: Theme.surfaceContainerHighest
    border.width: 1
    border.color: Theme.borderSubtle

    property var model: []
    property var currentValue: ""
    signal valueSelected(var val)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: segRoot.model

            Rectangle {
                id: segment
                readonly property bool isSelected: modelData.value === segRoot.currentValue
                implicitHeight: 32
                implicitWidth: Math.max(72, segContent.implicitWidth + 24)
                radius: 16
                color: isSelected ? Theme.primary : (segMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent")

                scale: segMouse.pressed ? 0.95 : 1.0

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
                Behavior on scale {
                    NumberAnimation { duration: 100 }
                }

                Row {
                    id: segContent
                    anchors.centerIn: parent
                    spacing: 6

                    SvgIcon {
                        visible: modelData.icon !== undefined && modelData.icon !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14
                        height: 14
                        source: modelData.icon || ""
                        color: segment.isSelected ? Theme.colorOnPrimary : (segMouse.containsMouse ? Theme.textPrimary : Theme.textMuted)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label || ""
                        font.pixelSize: 12
                        font.bold: segment.isSelected
                        color: segment.isSelected ? Theme.colorOnPrimary : (segMouse.containsMouse ? Theme.textPrimary : Theme.textMuted)
                    }
                }

                MouseArea {
                    id: segMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        segRoot.valueSelected(modelData.value);
                    }
                }
            }
        }
    }
}
