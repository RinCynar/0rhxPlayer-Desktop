import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import rhx.ui 1.0
import rhx.config 1.0
import rhx.theme 1.0

Item {
    id: root
    anchors.fill: parent
    visible: opacity > 0
    opacity: 0
    z: 999

    property bool isOpen: false

    function getLocalizedTitle(id, fallback) {
        switch (id) {
            case "home": return qsTr("Home");
            case "library": return qsTr("Library");
            case "search": return qsTr("Search");
            case "queue": return qsTr("Queue");
            case "playlist": return qsTr("Playlists");
            case "favorites": return qsTr("Favorites");
            case "eq": return qsTr("Equalizer");
            default: return fallback;
        }
    }

    onIsOpenChanged: {
        if (isOpen) {
            loadModelFromConfig();
            root.opacity = 1;
        } else {
            root.opacity = 0;
        }
    }

    Behavior on opacity {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    // ------------------------------------------------------------------------
    // Local ListModel for temporary reordering and toggling
    // ------------------------------------------------------------------------
    ListModel {
        id: dialogModel
    }

    function loadModelFromConfig() {
        dialogModel.clear();
        var items = ConfigManager.allNavItems;
        for (var i = 0; i < items.length; ++i) {
            dialogModel.append({
                itemId: items[i].id,
                title: items[i].title,
                iconSource: items[i].iconSource,
                itemVisible: items[i].visible !== false,
                canHide: items[i].canHide !== false && items[i].id !== "home"
            });
        }
    }

    function saveAndClose() {
        var result = [];
        for (var i = 0; i < dialogModel.count; ++i) {
            var item = dialogModel.get(i);
            result.push({
                id: item.itemId,
                title: item.title,
                iconSource: item.iconSource,
                visible: item.itemVisible,
                canHide: item.canHide
            });
        }
        ConfigManager.saveNavItems(result);
        root.isOpen = false;
    }

    // ------------------------------------------------------------------------
    // Semi-transparent solid black mask (#99000000, 100% flat, no blur filter)
    // ------------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: "#99000000"

        MouseArea {
            anchors.fill: parent
            onClicked: root.isOpen = false
            onWheel: (wheel) => { wheel.accepted = true; }
        }
    }

    // ------------------------------------------------------------------------
    // Modal Card: 420px x 520px, radius 24px, pure dark gray #1E201F
    // ------------------------------------------------------------------------
    Rectangle {
        id: dialogCard
        width: 420
        height: 520
        radius: 24
        color: Theme.surfaceContainerLow
        border.color: Theme.borderSubtle
        border.width: 1
        anchors.centerIn: parent

        scale: root.isOpen ? 1.0 : 0.95
        Behavior on scale {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        // Prevent click from passing through card to mask
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            // ----------------------------------------------------------------
            // 1. Header Area (Strict Vertical Layout - No Overlap)
            // ----------------------------------------------------------------
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    SvgIcon {
                        width: 20
                        height: 20
                        sourceSize: Qt.size(40, 40)
                        source: "qrc:/assets/icons/pen.svg"
                        color: Theme.primary
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Customize Navigation")
                        font.pixelSize: 18
                        font.bold: true
                        color: Theme.textPrimary
                        elide: Text.ElideRight
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Drag up/down to sort, check to display")
                    font.pixelSize: 12
                    color: Theme.textMuted
                    elide: Text.ElideRight
                }
            }

            // Divider line
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.borderSubtle
            }

            // ----------------------------------------------------------------
            // 2. Drag & Drop Reorderable ListView
            // ----------------------------------------------------------------
            ListView {
                id: listView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                boundsMovement: Flickable.StopAtBounds
                spacing: 8
                model: dialogModel

                displaced: Transition {
                    NumberAnimation { properties: "y"; duration: 150; easing.type: Easing.OutQuad }
                }

                ScrollBar.vertical: M3ScrollBar {
                    id: vbar
                }

                delegate: Item {
                    id: delegateRoot
                    width: listView.width - (vbar.visible ? 8 : 0)
                    height: 48
                    z: dragMouse.drag.active ? 10 : 1

                    property int itemIndex: index
                    property bool isHeld: dragMouse.drag.active

                    Rectangle {
                        id: itemCapsule
                        width: parent.width
                        height: 48
                        radius: 24
                        color: model.itemVisible ? Theme.primaryContainer : Theme.surfaceContainer
                        border.color: delegateRoot.isHeld ? Theme.primary : "transparent"
                        border.width: delegateRoot.isHeld ? 1 : 0
                        scale: delegateRoot.isHeld ? 1.02 : 1.0

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

                        // Left: 6-dot drag indicator (Grip Area)
                        Item {
                            id: gripArea
                            width: 36
                            height: parent.height
                            anchors.left: parent.left
                            anchors.leftMargin: 6

                            SvgIcon {
                                anchors.centerIn: parent
                                width: 18
                                height: 18
                                sourceSize: Qt.size(36, 36)
                                source: "qrc:/assets/icons/drag_indicator.svg"
                                color: (dragMouse.containsMouse || delegateRoot.isHeld) ? Theme.colorOnSurface : Theme.outline
                            }

                            MouseArea {
                                id: dragMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                                drag.target: itemCapsule
                                drag.axis: Drag.YAxis

                                onReleased: {
                                    itemCapsule.y = 0;
                                }

                                onPositionChanged: {
                                    if (drag.active) {
                                        var step = delegateRoot.height + listView.spacing; // 56px
                                        var threshold = 28;

                                        if (itemCapsule.y > threshold && delegateRoot.itemIndex < dialogModel.count - 1) {
                                            dialogModel.move(delegateRoot.itemIndex, delegateRoot.itemIndex + 1, 1);
                                            itemCapsule.y -= step;
                                        } else if (itemCapsule.y < -threshold && delegateRoot.itemIndex > 0) {
                                            dialogModel.move(delegateRoot.itemIndex, delegateRoot.itemIndex - 1, 1);
                                            itemCapsule.y += step;
                                        }
                                    }
                                }
                            }
                        }

                        // Middle: Function Vector Icon & Title (Click to toggle visibility)
                        Item {
                            id: contentArea
                            anchors.left: gripArea.right
                            anchors.right: checkArea.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12

                                SvgIcon {
                                    width: 18
                                    height: 18
                                    sourceSize: Qt.size(48, 48)
                                    source: model.iconSource
                                    color: model.itemVisible ? Theme.primary : Theme.outline
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: root.getLocalizedTitle(model.itemId, model.title)
                                    font.pixelSize: 14
                                    font.weight: model.itemVisible ? Font.Bold : Font.Normal
                                    color: model.itemVisible ? Theme.colorOnPrimaryContainer : Theme.colorOnSurfaceVariant
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: model.canHide ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (model.canHide) {
                                        model.itemVisible = !model.itemVisible;
                                    }
                                }
                            }
                        }

                        // Right: M3 Checkbox
                        Item {
                            id: checkArea
                            width: 36
                            height: parent.height
                            anchors.right: parent.right
                            anchors.rightMargin: 12

                            Rectangle {
                                anchors.centerIn: parent
                                width: 20
                                height: 20
                                radius: 4
                                color: model.itemVisible ? Theme.primary : "transparent"
                                border.color: model.itemVisible ? Theme.primary : Theme.outline
                                border.width: model.itemVisible ? 0 : 1.5

                                SvgIcon {
                                    visible: model.itemVisible
                                    anchors.centerIn: parent
                                    width: 14
                                    height: 14
                                    sourceSize: Qt.size(28, 28)
                                    source: "qrc:/assets/icons/check.svg"
                                    color: Theme.colorOnPrimary
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: model.canHide ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (model.canHide) {
                                        model.itemVisible = !model.itemVisible;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Divider line
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.borderSubtle
            }

            // ----------------------------------------------------------------
            // 3. Footer Button Group (Cancel & Save)
            // ----------------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                spacing: 12

                Item { Layout.fillWidth: true }

                // Cancel button
                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 36
                    radius: 18
                    color: cancelMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Cancel")
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        color: cancelMouse.containsMouse ? Theme.colorOnSurface : Theme.colorOnSurfaceVariant
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.isOpen = false
                    }
                }

                // Save button: M3 Primary Capsule
                Rectangle {
                    Layout.preferredWidth: 108
                    Layout.preferredHeight: 36
                    radius: 18
                    color: saveMouse.pressed ? Qt.darker(Theme.primary, 1.1) : (saveMouse.containsMouse ? Qt.lighter(Theme.primary, 1.1) : Theme.primary)
                    scale: saveMouse.pressed ? 0.96 : 1.0

                    Behavior on scale { NumberAnimation { duration: 80 } }
                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Save Changes")
                        font.pixelSize: 14
                        font.bold: true
                        color: Theme.colorOnPrimary
                    }

                    MouseArea {
                        id: saveMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.saveAndClose()
                    }
                }
            }
        }
    }
}
