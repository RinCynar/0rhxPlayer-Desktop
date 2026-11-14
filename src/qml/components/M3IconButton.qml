import QtQuick
import rhx.theme 1.0
import rhx.ui 1.0

Item {
    id: iconBtnRoot
    property int size: 36
    implicitWidth: size
    implicitHeight: size

    property string icon: ""
    property int iconSize: 18
    property string variant: "standard" // "standard", "filled", "tonal", "outlined"
    property bool checkable: false
    property bool checked: false
    property string tooltip: ""

    signal clicked()
    signal toggled(bool checked)

    activeFocusOnTab: enabled

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: width / 2
        color: {
            if (!iconBtnRoot.enabled) return "transparent";
            if (checkable && checked) return Theme.primary;
            if (variant === "filled") return Theme.primary;
            if (variant === "tonal") return Theme.secondaryContainer;
            if (variant === "outlined") return "transparent";
            return "transparent";
        }
        border.width: (variant === "outlined" && iconBtnRoot.enabled) ? 1 : (iconBtnRoot.activeFocus ? 2 : 0)
        border.color: iconBtnRoot.activeFocus ? Theme.primary : ((variant === "outlined" && iconBtnRoot.enabled) ? Theme.outline : "transparent")
        opacity: iconBtnRoot.enabled ? 1.0 : 0.4

        scale: (iconBtnRoot.enabled && mouseArea.pressed) ? 0.92 : 1.0

        Behavior on color {
            ColorAnimation { duration: Theme.motionDurationFast }
        }
        Behavior on scale {
            NumberAnimation { duration: Theme.motionDurationFast; easing.type: Easing.OutCubic }
        }

        // Hover / Pressed State Layer
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: (checkable && checked) ? "#FFFFFF" : Theme.textPrimary
            opacity: {
                if (!iconBtnRoot.enabled) return 0;
                if (mouseArea.pressed) return 0.16;
                if (mouseArea.containsMouse) return 0.08;
                return 0;
            }
            Behavior on opacity {
                NumberAnimation { duration: Theme.motionDurationFast }
            }
        }

        SvgIcon {
            id: svg
            anchors.centerIn: parent
            width: iconBtnRoot.iconSize
            height: iconBtnRoot.iconSize
            source: iconBtnRoot.icon
            color: {
                if (!iconBtnRoot.enabled) return Theme.textMuted;
                if (checkable && checked) return Theme.colorOnPrimary;
                if (variant === "filled") return Theme.colorOnPrimary;
                if (variant === "tonal") return Theme.colorOnSecondaryContainer;
                if (mouseArea.containsMouse) return Theme.textPrimary;
                return Theme.textSecondary;
            }
            Behavior on color {
                ColorAnimation { duration: Theme.motionDurationFast }
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        enabled: iconBtnRoot.enabled
        hoverEnabled: true
        cursorShape: iconBtnRoot.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (iconBtnRoot.checkable) {
                iconBtnRoot.checked = !iconBtnRoot.checked;
                iconBtnRoot.toggled(iconBtnRoot.checked);
            }
            iconBtnRoot.clicked();
        }
    }

    Keys.onReturnPressed: if (iconBtnRoot.enabled) mouseArea.clicked(null)
    Keys.onSpacePressed: if (iconBtnRoot.enabled) mouseArea.clicked(null)
}
