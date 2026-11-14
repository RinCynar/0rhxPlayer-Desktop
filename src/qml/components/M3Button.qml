import QtQuick
import rhx.theme 1.0
import rhx.ui 1.0

Item {
    id: buttonRoot
    implicitHeight: 38
    implicitWidth: Math.max(72, contentRow.implicitWidth + (variant === "text" ? 20 : 32))

    property string text: ""
    property string icon: ""
    property int iconSize: 16
    property string variant: "filled" // "filled", "tonal", "outlined", "text"
    property real radius: height / 2

    signal clicked()

    activeFocusOnTab: enabled

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: buttonRoot.radius
        color: {
            if (!buttonRoot.enabled) return Theme.surfaceContainerHighest;
            if (variant === "filled") return Theme.primary;
            if (variant === "tonal") return Theme.secondaryContainer;
            if (variant === "outlined" || variant === "text") return "transparent";
            return Theme.primary;
        }
        border.width: (variant === "outlined" && buttonRoot.enabled) ? 1 : (buttonRoot.activeFocus ? 2 : 0)
        border.color: buttonRoot.activeFocus ? Theme.primary : ((variant === "outlined" && buttonRoot.enabled) ? Theme.outline : "transparent")
        opacity: buttonRoot.enabled ? 1.0 : 0.42

        scale: (buttonRoot.enabled && mouseArea.pressed) ? 0.96 : 1.0

        Behavior on color {
            ColorAnimation { duration: Theme.motionDurationFast }
        }
        Behavior on scale {
            NumberAnimation { duration: Theme.motionDurationFast; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: Theme.motionDurationFast }
        }

        // Hover / Pressed State Layer
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: {
                if (variant === "filled") return "#FFFFFF";
                return Theme.primary;
            }
            opacity: {
                if (!buttonRoot.enabled) return 0;
                if (mouseArea.pressed) return 0.16;
                if (mouseArea.containsMouse) return 0.08;
                return 0;
            }
            Behavior on opacity {
                NumberAnimation { duration: Theme.motionDurationFast }
            }
        }

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: 8

            SvgIcon {
                id: btnIcon
                visible: buttonRoot.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: buttonRoot.iconSize
                height: buttonRoot.iconSize
                source: buttonRoot.icon
                color: contentColor()
            }

            Text {
                id: btnText
                visible: buttonRoot.text !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: buttonRoot.text
                font.pixelSize: 13
                font.weight: Font.Medium
                color: contentColor()
            }
        }
    }

    function contentColor() {
        if (!buttonRoot.enabled) return Theme.textMuted;
        if (variant === "filled") return Theme.colorOnPrimary;
        if (variant === "tonal") return Theme.colorOnSecondaryContainer;
        if (variant === "outlined" || variant === "text") return Theme.primary;
        return Theme.colorOnPrimary;
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: buttonRoot.enabled
        hoverEnabled: true
        cursorShape: buttonRoot.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: buttonRoot.clicked()
    }

    Keys.onReturnPressed: if (buttonRoot.enabled) buttonRoot.clicked()
    Keys.onSpacePressed: if (buttonRoot.enabled) buttonRoot.clicked()
}
