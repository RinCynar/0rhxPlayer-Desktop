import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import rhx.ui 1.0
import rhx.theme 1.0
import rhx.library 1.0

Item {
    id: dialogRoot
    anchors.fill: parent
    z: 15000
    visible: opacity > 0.0
    opacity: 0.0

    property var trackDetails: ({})

    function showTrack(path) {
        if (!path || path.length === 0) return;
        trackDetails = LibraryManager.getTrackDetails(path);
        dialogRoot.opacity = 1.0;
    }

    function close() {
        dialogRoot.opacity = 0.0;
    }

    Behavior on opacity {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    // Backdrop
    Rectangle {
        anchors.fill: parent
        color: "#99000000"

        MouseArea {
            anchors.fill: parent
            onClicked: dialogRoot.close()
        }
    }

    // Modal Card
    Rectangle {
        id: card
        width: Math.min(520, parent.width - 48)
        height: Math.min(540, parent.height - 48)
        anchors.centerIn: parent
        radius: 16
        color: Theme.surfaceContainer
        border.width: 1
        border.color: Theme.borderSubtle
        clip: true

        MouseArea {
            anchors.fill: parent
            // Prevent clicks from propagating to backdrop
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                SvgIcon {
                    width: 20
                    height: 20
                    source: "qrc:/assets/icons/info.svg"
                    color: Theme.primary
                }

                Text {
                    text: qsTr("Track Details")
                    font.pixelSize: 18
                    font.bold: true
                    color: Theme.textPrimary
                    Layout.fillWidth: true
                }

                // Close Button
                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: closeMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                    SvgIcon {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        source: "qrc:/assets/icons/win_close.svg"
                        color: Theme.textMuted
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dialogRoot.close()
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.borderSubtle
            }

            // Scrollable Content
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: infoCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: infoCol
                    width: parent.width
                    spacing: 12

                    // Title
                    ColumnLayout {
                        spacing: 2
                        Text { text: qsTr("Title"); font.pixelSize: 11; font.bold: true; color: Theme.textMuted }
                        Text { text: dialogRoot.trackDetails.title || "—"; font.pixelSize: 14; font.bold: true; color: Theme.textPrimary; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                    }

                    // Artist
                    ColumnLayout {
                        spacing: 2
                        Text { text: qsTr("Artist"); font.pixelSize: 11; font.bold: true; color: Theme.textMuted }
                        Text { text: dialogRoot.trackDetails.artist || "—"; font.pixelSize: 13; color: Theme.textPrimary; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                    }

                    // Album
                    ColumnLayout {
                        spacing: 2
                        Text { text: qsTr("Album"); font.pixelSize: 11; font.bold: true; color: Theme.textMuted }
                        Text { text: dialogRoot.trackDetails.album || "—"; font.pixelSize: 13; color: Theme.textPrimary; wrapMode: Text.WrapAnywhere; Layout.fillWidth: true }
                    }

                    // Metadata Grid: Year, Genre, Track Number, Duration
                    GridLayout {
                        columns: 2
                        rowSpacing: 10
                        columnSpacing: 20
                        Layout.fillWidth: true

                        ColumnLayout {
                            spacing: 2
                            Text { text: qsTr("Duration"); font.pixelSize: 11; font.bold: true; color: Theme.textMuted }
                            Text { text: dialogRoot.trackDetails.durationStr || "—"; font.pixelSize: 13; color: Theme.textPrimary }
                        }

                        ColumnLayout {
                            spacing: 2
                            Text { text: qsTr("Format"); font.pixelSize: 11; font.bold: true; color: Theme.textMuted }
                            Text { text: dialogRoot.trackDetails.format || "—"; font.pixelSize: 13; font.bold: true; color: Theme.primary }
                        }

                        ColumnLayout {
                            spacing: 2
                            Text { text: qsTr("Bitrate"); font.pixelSize: 11; font.bold: true; color: Theme.textMuted }
                            Text { text: dialogRoot.trackDetails.bitrateStr || "—"; font.pixelSize: 13; color: Theme.textPrimary }
                        }

                        ColumnLayout {
                            spacing: 2
                            Text { text: qsTr("File Size"); font.pixelSize: 11; font.bold: true; color: Theme.textMuted }
                            Text { text: dialogRoot.trackDetails.fileSizeStr || "—"; font.pixelSize: 13; color: Theme.textPrimary }
                        }

                        ColumnLayout {
                            spacing: 2
                            Text { text: qsTr("Year"); font.pixelSize: 11; font.bold: true; color: Theme.textMuted }
                            Text { text: dialogRoot.trackDetails.year || "—"; font.pixelSize: 13; color: Theme.textPrimary }
                        }

                        ColumnLayout {
                            spacing: 2
                            Text { text: qsTr("Genre"); font.pixelSize: 11; font.bold: true; color: Theme.textMuted }
                            Text { text: dialogRoot.trackDetails.genre || "—"; font.pixelSize: 13; color: Theme.textPrimary }
                        }
                    }

                    // File Path Location
                    ColumnLayout {
                        spacing: 4
                        Layout.fillWidth: true
                        Text { text: qsTr("Location"); font.pixelSize: 11; font.bold: true; color: Theme.textMuted }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: pathTxt.implicitHeight + 16
                            radius: 8
                            color: Theme.surfaceContainerHighest
                            border.width: 1
                            border.color: Theme.borderSubtle

                            TextEdit {
                                id: pathTxt
                                anchors.fill: parent
                                anchors.margins: 8
                                readOnly: true
                                selectByMouse: true
                                text: dialogRoot.trackDetails.path || ""
                                font.pixelSize: 11
                                font.family: "monospace"
                                color: Theme.textSecondary
                                wrapMode: Text.WrapAnywhere
                            }
                        }
                    }
                }
            }

            // Footer Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                // Open in Explorer Button
                Rectangle {
                    height: 36
                    radius: 18
                    color: openExpMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                    border.width: 1
                    border.color: Theme.borderSubtle
                    implicitWidth: openExpRow.implicitWidth + 24

                    RowLayout {
                        id: openExpRow
                        anchors.centerIn: parent
                        spacing: 6

                        SvgIcon {
                            width: 14
                            height: 14
                            source: "qrc:/assets/icons/folder_open.svg"
                            color: Theme.textPrimary
                        }

                        Text {
                            text: qsTr("Show in Explorer")
                            font.pixelSize: 12
                            font.bold: true
                            color: Theme.textPrimary
                        }
                    }

                    MouseArea {
                        id: openExpMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            LibraryManager.showInExplorer(dialogRoot.trackDetails.path);
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // OK / Close Button
                Rectangle {
                    height: 36
                    radius: 18
                    color: Theme.primary
                    implicitWidth: 80

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Close")
                        font.pixelSize: 12
                        font.bold: true
                        color: Theme.colorOnPrimary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dialogRoot.close()
                    }
                }
            }
        }
    }
}
