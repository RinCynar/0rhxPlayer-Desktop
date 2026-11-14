import QtQuick
import rhx.theme 1.0
import rhx.ui 1.0

Item {
    id: badgeRoot
    implicitHeight: 20
    implicitWidth: Math.max(20, badgeRow.implicitWidth + 12)

    property string text: ""
    property string icon: ""
    property string variant: "tonal" // "primary", "tonal", "error", "success", "outline"
    property real radius: height / 2

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: badgeRoot.radius
        color: {
            if (variant === "primary") return Theme.primaryContainer;
            if (variant === "error") return "#8C1D18";
            if (variant === "success") return "#1B4D3E";
            if (variant === "outline") return "transparent";
            return Theme.surfaceContainerHighest;
        }
        border.width: variant === "outline" ? 1 : 0
        border.color: variant === "outline" ? Theme.outlineVariant : "transparent"

        Row {
            id: badgeRow
            anchors.centerIn: parent
            spacing: 4

            SvgIcon {
                visible: badgeRoot.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: 10
                height: 10
                source: badgeRoot.icon
                color: contentColor()
            }

            Text {
                id: badgeText
                anchors.verticalCenter: parent.verticalCenter
                text: badgeRoot.text
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: contentColor()
            }
        }
    }

    function contentColor() {
        if (variant === "primary") return Theme.colorOnPrimaryContainer;
        if (variant === "error") return "#F9DEDC";
        if (variant === "success") return "#A8E6CF";
        if (variant === "outline") return Theme.textSecondary;
        return Theme.textSecondary;
    }
}
