import QtQuick
import rhx.theme 1.0
import rhx.ui 1.0

Item {
    id: dialogRoot
    anchors.fill: parent
    visible: false
    z: 9999

    property string title: ""
    property string confirmText: "OK"
    property string cancelText: "Cancel"
    property bool showCancel: true
    property int dialogWidth: 440
    default property alias content: contentContainer.data

    signal accepted()
    signal rejected()
    signal closed()

    function open() {
        dialogRoot.visible = true;
    }

    function close() {
        dialogRoot.visible = false;
        dialogRoot.closed();
    }

    // Modal Dimmed Backdrop
    Rectangle {
        anchors.fill: parent
        color: "#99000000"
        opacity: dialogRoot.visible ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: Theme.motionDurationMedium }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                // Dimmed backdrop click closes dialog
                dialogRoot.close();
            }
        }
    }

    // Dialog Surface Card
    Rectangle {
        id: card
        width: Math.min(dialogRoot.dialogWidth, parent.width - 48)
        height: Math.min(dialogCol.implicitHeight + 48, parent.height - 64)
        anchors.centerIn: parent
        radius: 20
        color: Theme.surfaceContainerHigh
        border.width: 1
        border.color: Theme.outlineVariant

        scale: dialogRoot.visible ? 1.0 : 0.94
        opacity: dialogRoot.visible ? 1.0 : 0.0

        Behavior on scale {
            NumberAnimation { duration: Theme.motionDurationMedium; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: Theme.motionDurationFast }
        }

        MouseArea {
            anchors.fill: parent
            // Prevent clicks inside card from closing backdrop
            onClicked: {}
        }

        Column {
            id: dialogCol
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            Text {
                id: titleText
                text: dialogRoot.title
                font.pixelSize: 18
                font.weight: Font.DemiBold
                color: Theme.textPrimary
                visible: dialogRoot.title !== ""
                width: parent.width
                wrapMode: Text.WordWrap
            }

            Item {
                id: contentContainer
                width: parent.width
                height: card.height - 48 - (titleText.visible ? (titleText.implicitHeight + 16) : 0) - (buttonsRow.implicitHeight + 16)
                clip: true
            }

            Row {
                id: buttonsRow
                anchors.right: parent.right
                spacing: 12

                M3Button {
                    visible: dialogRoot.showCancel
                    text: dialogRoot.cancelText
                    variant: "text"
                    onClicked: {
                        dialogRoot.rejected();
                        dialogRoot.close();
                    }
                }

                M3Button {
                    text: dialogRoot.confirmText
                    variant: "filled"
                    onClicked: {
                        dialogRoot.accepted();
                        dialogRoot.close();
                    }
                }
            }
        }
    }
}
