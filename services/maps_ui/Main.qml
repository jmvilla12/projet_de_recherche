import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root

    width: 1280
    height: 720
    minimumWidth: 900
    minimumHeight: 600
    visible: true
    title: "Coverage Path Planner"

    header: ToolBar {
        implicitHeight: 50
        background: Rectangle { color: "#000000" }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16

            Label {
                text: qsTr("Planificateur de trajectoire de couverture")
                color: "#e8eaf6"

                anchors.centerIn: parent

                font {
                    capitalization: Font.AllUppercase
                    family: "sans-serif"
                    pixelSize: 20
                    weight: Font.DemiBold
                    letterSpacing: 0.3
                }

                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            Label {
                text: "13-mars"
                font.pixelSize: 11
                color: "#e8eaf6"
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Central map area
        MapView {
            id: mapView
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        // Right panel — mission parameters and controls
        Rectangle {
            width: 300
            Layout.fillHeight: true
            color: "#f8f9fc"

            // Left border separator
            Rectangle {
                width: 1
                height: parent.height
                color: "#dde1ec"
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    
                    Label {
                        text: "Selected points"
                        font.pixelSize: 16
                        font.bold: true
                        color: "#1a2744"
                        Layout.topMargin: 4
                    }

                    Label {
                        visible: mapView.vertices.length >= 3
                        text: {
                            var area = mapView.netArea;
                            var formattedArea = "";
                            if (area > 1000000) {
                                formattedArea = (area / 1000000).toLocaleString(Qt.locale(), 'f', 2) + " km²";
                            } else {
                                formattedArea = area.toLocaleString(Qt.locale(), 'f', 2) + " m²";
                            }
                            return "Area: " + formattedArea;
                        }
                        font.pixelSize: 14
                        font.bold: true
                        color: "#2e7d32"
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#dde1ec"
                }

                Label {
                    text: "Selected Points"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#4a5568"
                    visible: mapView.vertices.length > 0
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Label {
                        anchors.centerIn: parent
                        text: "No points selected"
                        font.pixelSize: 13
                        color: "#a0aec0"
                        visible: mapView.vertices.length === 0 && mapView.restrictionVertices.length === 0
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 16
                        visible: mapView.vertices.length > 0 || mapView.restrictionVertices.length > 0

                        // Section Cobertura
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: mapView.vertices.length > 0

                            Label {
                                text: "Points de couverture"
                                font.pixelSize: 13
                                font.bold: true
                                color: "#2e7d32"
                            }

                            ListView {
                                id: mainPointsList
                                Layout.fillWidth: true
                                Layout.preferredHeight: contentHeight
                                Layout.maximumHeight: 250
                                clip: true
                                model: mapView.vertexModel
                                spacing: 6

                                delegate: Rectangle {
                                    width: mainPointsList.width
                                    height: 44
                                    color: "white"
                                    radius: 6
                                    border.color: "#edf2f7"
                                    border.width: 1

                                    HoverHandler { id: mainHover }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 10

                                        Rectangle {
                                            width: 20
                                            height: 20
                                            radius: 10
                                            color: "#e8f5e9"
                                            Label {
                                                anchors.centerIn: parent
                                                text: (index + 1)
                                                font.pixelSize: 10
                                                font.bold: true
                                                color: "#2e7d32"
                                            }
                                        }

                                        Column {
                                            Layout.fillWidth: true
                                            Label {
                                                text: model.lat.toFixed(5) + ", " + model.lng.toFixed(5)
                                                font.pixelSize: 11
                                                color: "#4a5568"
                                                font.family: "Monospace"
                                            }
                                        }

                                        Button {
                                            visible: mainHover.hovered
                                            Layout.preferredWidth: 24
                                            Layout.preferredHeight: 24
                                            flat: true
                                            padding: 0
                                            
                                            contentItem: Label {
                                                text: "✕"
                                                font.pixelSize: 14
                                                color: "#e53935"
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            onClicked: mapView.removeMainPoint(index)
                                        }
                                    }
                                }
                            }
                        }

                        // Section Restricciones
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: mapView.restrictionVertices.length > 0

                            Label {
                                text: "Points restreints"
                                font.pixelSize: 13
                                font.bold: true
                                color: "#ef6c00"
                            }

                            ListView {
                                id: restPointsList
                                Layout.fillWidth: true
                                Layout.preferredHeight: contentHeight
                                Layout.maximumHeight: 250
                                clip: true
                                model: mapView.restrictionModel
                                spacing: 6

                                section.property: "zoneIndex"
                                section.criteria: ViewSection.FullString
                                section.delegate: Item {
                                    width: restPointsList.width
                                    height: 24
                                    Label {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: (section == "-1") ? "Zone suivante (en cours de dessin)" : "Zone restreinte " + (parseInt(section) + 1)
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: (section == "-1") ? "#fb8c00" : "#ef6c00"
                                    }
                                }

                                delegate: Rectangle {
                                    width: restPointsList.width
                                    height: 40
                                    color: "white"
                                    radius: 6
                                    border.color: (model.zoneIndex == -1) ? "#fff3e0" : "#ffe0b2"
                                    border.width: 1

                                    HoverHandler { id: restHover }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 10

                                        Rectangle {
                                            width: 18
                                            height: 18
                                            radius: 9
                                            color: (model.zoneIndex == -1) ? "#fff3e0" : "#ffe0b2"
                                            Label {
                                                anchors.centerIn: parent
                                                text: (index + 1)
                                                font.pixelSize: 9
                                                font.bold: true
                                                color: "#ef6c00"
                                            }
                                        }

                                        Label {
                                            Layout.fillWidth: true
                                            text: model.lat.toFixed(5) + ", " + model.lng.toFixed(5)
                                            font.pixelSize: 11
                                            color: "#4a5568"
                                            font.family: "Monospace"
                                        }

                                        Button {
                                            visible: restHover.hovered
                                            Layout.preferredWidth: 24
                                            Layout.preferredHeight: 24
                                            flat: true
                                            padding: 0
                                            
                                            contentItem: Label {
                                                text: "✕"
                                                font.pixelSize: 14
                                                color: "#e53935"
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            onClicked: mapView.removeRestrictionPoint(index)
                                        }
                                    }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        Button {
                            id: exportBtn
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            text: "Export"
                            font.bold: true
                            font.pixelSize: 14
                            
                            contentItem: Label {
                                text: exportBtn.text
                                font: exportBtn.font
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                radius: 8
                                color: "#1a237e" // Deep Indigo
                                opacity: exportBtn.pressed ? 0.8 : 1.0
                            }

                            onClicked: {
                                // Placeholder for export functionality
                                console.log("Bouton d’export cliqué – Pas d’action pour le moment")
                            }
                        }
                    }
                }
            }
        }
    }
}
