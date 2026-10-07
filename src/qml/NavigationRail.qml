import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import rhx.ui 1.0
import rhx.config 1.0
import rhx.theme 1.0

Rectangle {
    id: root
    property string activeTab: "home"
    signal tabSelected(string tabId)
    signal editNavRequested()

    property bool isCollapsed: false
    property alias collapsed: root.isCollapsed

    width: isCollapsed ? 72 : 220
    color: Theme.surfaceContainerLow
    clip: true

    Behavior on width {
        NumberAnimation {
            duration: 260
            easing.type: root.isCollapsed ? Easing.OutCubic : Easing.OutBack
            easing.overshoot: 1.12
        }
    }

    // Intercept scroll wheel events to prevent bubbling to main view
    WheelHandler {
        onWheel: (event) => {
            event.accepted = true;
        }
    }

    // Right border separator (100% height, pure flat M3)
    Rectangle {
        width: 1
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: Theme.borderSubtle
    }

    // ------------------------------------------------------------------------
    // 1. Top Section: Header (展开态仅标题+折叠按钮，严禁添加左侧Logo) + 画笔按钮
    // ------------------------------------------------------------------------
    Item {
        id: topSection
        anchors.top: parent.top
        anchors.topMargin: 36
        anchors.left: parent.left
        anchors.right: parent.right
        height: topCol.implicitHeight

        Column {
            id: topCol
            anchors.fill: parent
            spacing: 8

            // Header Row (44px)
            Item {
                width: parent.width
                height: 44
                clip: true

                // 标题（展开态显示，折叠态平滑淡出）
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: "0rhxPlayer"
                    font.pixelSize: 18
                    font.bold: true
                    color: Theme.primary
                    visible: opacity > 0
                    opacity: root.isCollapsed ? 0 : 1

                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }
                }

                // 统一折叠切换控件 (28x28 圆形热区，展开态靠右留白 20px，折叠态在 72px 内绝对水平居中)
                Rectangle {
                    id: toggleBtn
                    width: 28
                    height: 28
                    radius: 14
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.isCollapsed ? Math.round((72 - width) / 2) : (parent.width - width - 20)

                    Behavior on x {
                        NumberAnimation {
                            duration: 260
                            easing.type: root.isCollapsed ? Easing.OutCubic : Easing.OutBack
                            easing.overshoot: 1.12
                        }
                    }

                    color: toggleMouse.pressed ? Theme.surfaceContainerHighest : (toggleMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent")
                    scale: toggleMouse.pressed ? 0.92 : 1.0

                    Behavior on scale {
                        NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                    }
                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }

                    SvgIcon {
                        id: chevronIcon
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        sourceSize: Qt.size(36, 36)
                        source: "qrc:/assets/icons/chevron_left.svg"
                        color: toggleMouse.containsMouse ? Theme.primary : Theme.iconNeutral
                        transformOrigin: Item.Center
                        rotation: root.isCollapsed ? 180 : 0

                        Behavior on rotation {
                            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                        }

                        scale: toggleMouse.pressed ? 0.86 : 1.0
                        Behavior on scale {
                            NumberAnimation {
                                duration: toggleMouse.pressed ? 90 : 260
                                easing.type: toggleMouse.pressed ? Easing.OutQuad : Easing.OutBack
                                easing.overshoot: 1.5
                            }
                        }
                    }

                    MouseArea {
                        id: toggleMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.isCollapsed = !root.isCollapsed
                    }
                }
            }

            // 画笔自定义按钮：展开态 180x36，折叠态 48x36，内部仅居中单笔图标，严禁文字
            Item {
                width: parent.width
                height: 36

                Rectangle {
                    anchors.centerIn: parent
                    width: root.isCollapsed ? 48 : 180
                    height: 36
                    radius: 18
                    color: penMouse.pressed ? Qt.darker(Theme.primary, 1.1) : (penMouse.containsMouse ? Qt.lighter(Theme.primary, 1.1) : Theme.primaryContainer)
                    scale: penMouse.pressed ? 0.96 : 1.0

                    Behavior on width {
                        NumberAnimation {
                            duration: 260
                            easing.type: root.isCollapsed ? Easing.OutCubic : Easing.OutBack
                            easing.overshoot: 1.12
                        }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                    }
                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }

                    SvgIcon {
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        sourceSize: Qt.size(48, 48)
                        source: "qrc:/assets/icons/pen.svg"
                        color: penMouse.pressed || penMouse.containsMouse ? Theme.colorOnPrimary : Theme.colorOnPrimaryContainer

                        // 核心：Material You 弹性回弹
                        transformOrigin: Item.Center
                        scale: penMouse.pressed ? 0.86 : 1.0

                        Behavior on scale {
                            NumberAnimation {
                                duration: penMouse.pressed ? 90 : 260
                                easing.type: penMouse.pressed ? Easing.OutQuad : Easing.OutBack
                                easing.overshoot: 1.5
                            }
                        }
                    }

                    MouseArea {
                        id: penMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.editNavRequested();
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------------
    // NavItem Component Definition (高度 48，Indicator 展开 180x40 vs 折叠 48x32)
    // ------------------------------------------------------------------------
    component NavItem : Item {
        id: navItem
        property string itemTabId: ""
        property string title: ""
        property string iconSource: ""

        readonly property bool isSelected: root.activeTab === itemTabId

        width: root.isCollapsed ? 72 : parent.width
        height: 48
        anchors.horizontalCenter: parent.horizontalCenter

        Behavior on width {
            NumberAnimation {
                duration: 260
                easing.type: root.isCollapsed ? Easing.OutCubic : Easing.OutBack
                easing.overshoot: 1.12
            }
        }

        // 高亮指示器 (展开态宽 180 高 40 圆角 20；折叠态宽 56 高 32 圆角 16)
        Rectangle {
            id: indicator
            anchors.centerIn: parent
            width: root.isCollapsed ? 56 : 180
            height: root.isCollapsed ? 32 : 40
            radius: root.isCollapsed ? 16 : 20

            Behavior on width {
                NumberAnimation {
                    duration: 260
                    easing.type: root.isCollapsed ? Easing.OutCubic : Easing.OutBack
                    easing.overshoot: 1.12
                }
            }
            Behavior on height {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
            Behavior on radius {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            color: navItem.isSelected ? Theme.primary : (navMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent")

            Behavior on color {
                ColorAnimation { duration: 100 }
            }

            // 胶囊按压轻量弹性 (Material You Touch Spring Feedback)
            scale: navMouse.pressed ? 0.96 : 1.0
            Behavior on scale {
                NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
            }

            // 内部图标与文字排版 (18x18 矢量图标，展开态左间距 16px、图文间距 14px；折叠态 56x32 胶囊内严格居中)
            SvgIcon {
                id: navItemIcon
                anchors.verticalCenter: parent.verticalCenter
                x: root.isCollapsed ? Math.round((parent.width - 18) / 2) : 16
                width: 18
                height: 18
                sourceSize: Qt.size(48, 48)
                source: navItem.iconSource
                color: navItem.isSelected ? Theme.colorOnPrimary : (navMouse.containsMouse ? Theme.textPrimary : Theme.iconNeutral)

                Behavior on x {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                // 核心：Material You 弹性回弹
                transformOrigin: Item.Center
                scale: navMouse.pressed ? 0.86 : 1.0

                Behavior on scale {
                    NumberAnimation {
                        duration: navMouse.pressed ? 90 : 260
                        easing.type: navMouse.pressed ? Easing.OutQuad : Easing.OutBack
                        easing.overshoot: 1.5
                    }
                }
            }

            Text {
                id: labelText
                anchors.left: navItemIcon.right
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                visible: opacity > 0
                opacity: root.isCollapsed ? 0 : 1

                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }

                text: navItem.title
                font.pixelSize: 14
                font.weight: navItem.isSelected ? Font.Bold : Font.Medium
                color: navItem.isSelected ? Theme.colorOnPrimary : (navMouse.containsMouse ? Theme.textPrimary : Theme.iconNeutral)
            }
        }

        MouseArea {
            id: navMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.tabSelected(navItem.itemTabId)
        }
    }

    // ------------------------------------------------------------------------
    // 2. Middle Navigation Items (6 核心项)
    // ------------------------------------------------------------------------
    Column {
        id: navCol
        anchors.top: topSection.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        Repeater {
            model: ConfigManager.visibleNavItems
            delegate: NavItem {
                itemTabId: modelData.id
                title: {
                    switch (modelData.id) {
                        case "home": return qsTr("Home");
                        case "library": return qsTr("Library");
                        case "search": return qsTr("Search");
                        case "queue": return qsTr("Queue");
                        case "playlist": return qsTr("Playlists");
                        case "favorites": return qsTr("Favorites");
                        case "eq": return qsTr("Equalizer");
                        default: return modelData.title;
                    }
                }
                iconSource: modelData.iconSource
            }
        }
    }

    // ------------------------------------------------------------------------
    // 3. Bottom Settings Button (严格固定左下角，自适应根折叠态)
    // ------------------------------------------------------------------------
    NavItem {
        id: settingsItem
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        anchors.horizontalCenter: parent.horizontalCenter
        itemTabId: "settings"
        title: qsTr("Settings")
        iconSource: "qrc:/assets/icons/gear.svg"
    }
}
