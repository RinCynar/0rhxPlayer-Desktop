import QtQuick
import QtQuick.Layouts
import rhx.ui 1.0
import rhx.theme 1.0

Rectangle {
    id: itemRoot
    Layout.fillWidth: true
    Layout.preferredHeight: 40
    radius: 8

    property string text: ""
    property string secondaryText: ""
    property url iconSource: ""
    property bool isDestructive: false
    property bool bold: false
    readonly property bool containsMouse: mouseArea.containsMouse

    signal clicked()

    // Official ChromeOS / M3 State Layer: 8% onSurface capsule; errorContainer tone for destructive actions
    color: {
        if (!containsMouse) return "transparent";
        if (isDestructive) {
            return Qt.rgba(Theme.errorContainer.r, Theme.errorContainer.g, Theme.errorContainer.b, Theme.isDark ? 0.35 : 0.60);
        }
        return Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.08);
    }

    Behavior on color {
        ColorAnimation { duration: 100 }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 14

        SvgIcon {
            id: icon
            width: 18
            height: 18
            source: itemRoot.iconSource
            sourceSize: Qt.size(18, 18)
            color: itemRoot.isDestructive ? Theme.error : (itemRoot.containsMouse ? Theme.onSurface : Theme.onSurfaceVariant)
            visible: itemRoot.iconSource != ""
        }

        Text {
            id: label
            text: itemRoot.text
            font.pixelSize: 14
            font.weight: itemRoot.bold ? Font.Medium : Font.Normal
            color: itemRoot.isDestructive ? Theme.error : (itemRoot.containsMouse ? Theme.onSurface : Theme.onSurfaceVariant)
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        Text {
            id: subLabel
            text: itemRoot.secondaryText
            font.pixelSize: 12
            color: itemRoot.isDestructive ? Theme.error : Theme.onSurfaceVariant
            visible: itemRoot.secondaryText !== ""
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
