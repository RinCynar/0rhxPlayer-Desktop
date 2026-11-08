import QtQuick
import QtQuick.Layouts
import rhx.ui 1.0
import rhx.theme 1.0

Item {
    id: itemRoot
    Layout.fillWidth: true
    Layout.preferredHeight: 40

    property string text: ""
    property string secondaryText: ""
    property url iconSource: ""
    property bool isDestructive: false
    property bool bold: false
    property color iconColor: "transparent"
    property color hoverIconColor: "transparent"
    property color textColor: "transparent"
    property color hoverTextColor: "transparent"
    readonly property bool containsMouse: mouseArea.containsMouse

    signal clicked()

    // Full-rounded Pill Indicator (两头全圆药丸胶囊)
    Rectangle {
        id: pillIndicator
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        radius: height / 2
        color: {
            if (!itemRoot.containsMouse) return "transparent";
            if (itemRoot.isDestructive) return Theme.errorContainer;
            return Theme.secondaryContainer;
        }

        scale: mouseArea.pressed ? 0.98 : 1.0

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Behavior on scale {
            NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
        }
    }

    RowLayout {
        anchors.fill: pillIndicator
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 12

        SvgIcon {
            id: icon
            width: 18
            height: 18
            source: itemRoot.iconSource
            sourceSize: Qt.size(18, 18)
            color: {
                if (itemRoot.isDestructive) {
                    return itemRoot.containsMouse ? Theme.onErrorContainer : Theme.error;
                }
                if (itemRoot.containsMouse) {
                    if (itemRoot.hoverIconColor.a > 0) return itemRoot.hoverIconColor;
                    return Theme.onSecondaryContainer;
                }
                if (itemRoot.iconColor.a > 0) {
                    return itemRoot.iconColor;
                }
                return Theme.onSurfaceVariant;
            }
            visible: itemRoot.iconSource != ""

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }

        Text {
            id: label
            text: itemRoot.text
            font.pixelSize: 14
            font.weight: itemRoot.bold ? Font.Medium : Font.Normal
            color: {
                if (itemRoot.isDestructive) {
                    return itemRoot.containsMouse ? Theme.onErrorContainer : Theme.error;
                }
                if (itemRoot.containsMouse) {
                    if (itemRoot.hoverTextColor.a > 0) return itemRoot.hoverTextColor;
                    return Theme.onSecondaryContainer;
                }
                if (itemRoot.textColor.a > 0) {
                    return itemRoot.textColor;
                }
                return Theme.onSurface;
            }
            Layout.fillWidth: true
            elide: Text.ElideRight

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }

        Text {
            id: subLabel
            text: itemRoot.secondaryText
            font.pixelSize: 12
            color: {
                if (itemRoot.isDestructive) {
                    return itemRoot.containsMouse ? Theme.onErrorContainer : Theme.error;
                }
                if (itemRoot.containsMouse) {
                    return Theme.onSecondaryContainer;
                }
                return Theme.onSurfaceVariant;
            }
            visible: itemRoot.secondaryText !== ""

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: itemRoot.clicked()
    }
}
