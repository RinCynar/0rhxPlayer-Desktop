import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import rhx.plugin 1.0
import rhx.config 1.0
import rhx.theme 1.0
import rhx.audio 1.0
import rhx.ui 1.0

Item {
    id: root
    objectName: "pluginSchemaView"
    clip: true

    property string pluginId: ""
    property var schemaData: ({})

    onPluginIdChanged: {
        loadSchema();
    }

    function loadSchema() {
        if (!pluginId) return;
        var cleanId = pluginId;
        if (cleanId.indexOf("plugin:") === 0) {
            cleanId = cleanId.substring(7);
        }
        schemaData = PluginManager.getPluginViewSchema(cleanId);
    }

    Connections {
        target: PluginManager
        function onPluginsChanged() {
            root.loadSchema();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 20

        // Header with Back button
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Rectangle {
                width: 36
                height: 36
                radius: 18
                color: backMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                border.color: Theme.borderSubtle

                SvgIcon {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    source: "qrc:/assets/icons/chevron_left.svg"
                    color: Theme.textPrimary
                }

                MouseArea {
                    id: backMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (typeof window !== "undefined") {
                            window.currentTab = "plugins";
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: root.schemaData.title || qsTr("Extension View")
                    font.pixelSize: 24
                    font.bold: true
                    color: Theme.textPrimary
                }

                Text {
                    text: qsTr("Native Material 3 Schema Engine (Pure QML • 120 FPS)")
                    font.pixelSize: 12
                    color: Theme.textSecondary
                }
            }
        }

        // Content Scrollable Area
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: parent.width
                spacing: 16

                Repeater {
                    model: root.schemaData.sections || []
                    delegate: Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: sectionCard.implicitHeight

                        Rectangle {
                            id: sectionCard
                            width: parent.width
                            height: sectionContent.implicitHeight + 32
                            radius: 16
                            color: Theme.surfaceContainerLow
                            border.color: Theme.borderSubtle

                            ColumnLayout {
                                id: sectionContent
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: modelData.title || ""
                                        font.pixelSize: 16
                                        font.bold: true
                                        color: Theme.primary
                                    }
                                }

                                Text {
                                    text: modelData.subtitle || modelData.details || ""
                                    font.pixelSize: 13
                                    color: Theme.textSecondary
                                    wrapMode: Text.Wrap
                                    Layout.fillWidth: true
                                    visible: text.length > 0
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
