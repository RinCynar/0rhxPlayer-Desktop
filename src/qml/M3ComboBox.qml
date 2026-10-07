import QtQuick
import QtQuick.Controls.Basic
import rhx.theme 1.0
import rhx.ui 1.0

Item {
    id: comboRoot
    implicitWidth: 240
    implicitHeight: 40

    property var model: []
    property var currentValue: ""
    property string displayText: {
        for (var i = 0; i < model.length; i++) {
            if (model[i].value === currentValue) {
                return model[i].label;
            }
        }
        return currentValue ? currentValue.toString() : "";
    }

    signal valueChanged(var newValue)

    function closePopup() {
        if (popup) {
            popup.close();
        }
    }

    Rectangle {
        id: triggerBox
        anchors.fill: parent
        radius: 12
        color: mouseArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer
        border.width: 1
        border.color: popup.opened ? Theme.primary : Theme.borderSubtle

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
        Behavior on border.color {
            ColorAnimation { duration: 150 }
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 12
            spacing: 8

            Text {
                width: parent.width - 24
                anchors.verticalCenter: parent.verticalCenter
                text: comboRoot.displayText
                font.pixelSize: 13
                font.bold: true
                color: Theme.textPrimary
                elide: Text.ElideRight
            }

            SvgIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                source: "qrc:/assets/icons/chevron_down.svg"
                color: popup.opened ? Theme.primary : Theme.iconNeutral
                rotation: popup.opened ? 180 : 0
                Behavior on rotation {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (popup.opened) popup.close();
                else popup.open();
            }
        }
    }

    Popup {
        id: popup
        y: comboRoot.height + 4
        width: Math.max(comboRoot.width, 240)
        padding: 6
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: 14
            color: Theme.surfaceContainerHigh
            border.width: 1
            border.color: Theme.outlineVariant
        }

        contentItem: ListView {
            implicitHeight: Math.min(contentHeight, 260)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: comboRoot.model

            delegate: Rectangle {
                id: itemDelegate
                width: ListView.view.width
                height: subText.text !== "" ? 44 : 36
                radius: 8
                color: itemMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                readonly property bool isSelected: modelData.value === comboRoot.currentValue

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Column {
                        width: parent.width - 24
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            text: modelData.label || ""
                            font.pixelSize: 13
                            font.bold: itemDelegate.isSelected
                            color: itemDelegate.isSelected ? Theme.primary : Theme.textPrimary
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Text {
                            id: subText
                            text: modelData.subLabel || ""
                            visible: text !== ""
                            font.pixelSize: 11
                            color: Theme.textMuted
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    SvgIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14
                        height: 14
                        visible: itemDelegate.isSelected
                        source: "qrc:/assets/icons/check.svg"
                        color: Theme.primary
                    }
                }

                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var val = modelData.value;
                        comboRoot.closePopup();
                        comboRoot.currentValue = val;
                        comboRoot.valueChanged(val);
                    }
                }
            }
        }
    }
}
