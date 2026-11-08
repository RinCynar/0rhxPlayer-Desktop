import QtQuick
import QtQuick.Layouts
import rhx.ui 1.0
import rhx.theme 1.0

Rectangle {
    id: itemRoot
    Layout.fillWidth: true
    Layout.preferredHeight: 34
    radius: 6

    property string text: ""
    property string secondaryText: ""
    property url iconSource: ""
    property bool isDestructive: false
    property bool bold: false
    readonly property bool containsMouse: mouseArea.containsMouse

    signal clicked()

    // M3 State Layer: 8% onSurface for standard items; errorContainer tone for destructive actions
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
        spacing: 10

        SvgIcon {
            id: icon
            width: 15
            height: 15
            source: itemRoot.iconSource
            sourceSize: Qt.size(15, 15)
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
