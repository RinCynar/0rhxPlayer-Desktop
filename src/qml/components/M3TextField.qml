import QtQuick
import rhx.theme 1.0
import rhx.ui 1.0

Item {
    id: fieldRoot
    implicitHeight: 40
    implicitWidth: 240

    property alias text: input.text
    property string placeholderText: ""
    property string leadingIcon: ""
    property string trailingIcon: ""
    property bool clearButtonVisible: true
    property bool readOnly: false
    property alias echoMode: input.echoMode

    signal accepted()
    signal textEdited()
    signal trailingIconClicked()

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 8
        color: input.activeFocus ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
        border.width: input.activeFocus ? 2 : 1
        border.color: input.activeFocus ? Theme.primary : Theme.outlineVariant

        Behavior on color {
            ColorAnimation { duration: Theme.motionDurationFast }
        }
        Behavior on border.color {
            ColorAnimation { duration: Theme.motionDurationFast }
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8

            SvgIcon {
                visible: fieldRoot.leadingIcon !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                source: fieldRoot.leadingIcon
                color: input.activeFocus ? Theme.primary : Theme.textMuted
            }

            TextInput {
                id: input
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - (fieldRoot.leadingIcon !== "" ? 24 : 0) - ((parent.showTrailing || parent.showClear) ? 24 : 0)
                font.pixelSize: 13
                color: Theme.textPrimary
                selectionColor: Theme.primary
                selectedTextColor: Theme.colorOnPrimary
                readOnly: fieldRoot.readOnly
                enabled: fieldRoot.enabled
                clip: true

                Text {
                    anchors.fill: parent
                    anchors.verticalCenter: parent.verticalCenter
                    text: fieldRoot.placeholderText
                    font.pixelSize: 13
                    color: Theme.textMuted
                    visible: !input.text && !input.inputMethodComposing
                }

                onAccepted: fieldRoot.accepted()
                onTextEdited: fieldRoot.textEdited()
            }

            readonly property bool showClear: fieldRoot.clearButtonVisible && input.text !== "" && !fieldRoot.readOnly
            readonly property bool showTrailing: fieldRoot.trailingIcon !== "" && !showClear

            Item {
                visible: parent.showClear || parent.showTrailing
                width: 18
                height: 18
                anchors.verticalCenter: parent.verticalCenter

                SvgIcon {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    source: parent.parent.showClear ? "qrc:/assets/icons/win_close.svg" : fieldRoot.trailingIcon
                    color: clearMouse.containsMouse ? Theme.primary : Theme.textMuted
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (parent.parent.showClear) {
                            input.text = "";
                            fieldRoot.textEdited();
                        } else {
                            fieldRoot.trailingIconClicked();
                        }
                    }
                }
            }
        }
    }
}
