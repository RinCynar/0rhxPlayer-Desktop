import QtQuick
import QtQuick.Layouts
import rhx.ui 1.0
import rhx.theme 1.0

Rectangle {
    id: itemRoot
    Layout.fillWidth: true
    Layout.preferredHeight: 36
    radius: 4

    property string text: ""
    property string secondaryText: ""
    property url iconSource: ""
    property bool isDestructive: false
    property bool bold: false
    readonly property bool containsMouse: mouseArea.containsMouse

    signal clicked()

    // Official M3 State Layer: 8% onSurface for standard items; errorContainer tone for destructive actions
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
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 12

        SvgIcon {
            id: icon
            width: 18
            height: 18
            source: itemRoot.iconSource
            sourceSize: Qt.size(18, 18)
            color: itemRoot.isDestructive ? Theme.error : Theme.onSurface
            visible: itemRoot.iconSource != ""
        }

        Text {
            id: label
            text: itemRoot.text
            font.pixelSize: 12
            font.bold: itemRoot.bold
            color: itemRoot.isDestructive ? Theme.error : Theme.onSurface
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        Text {
            id: subLabel
            text: itemRoot.secondaryText
            font.pixelSize: 11
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
