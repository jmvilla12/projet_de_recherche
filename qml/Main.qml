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
        background: Rectangle { color: "#1a2744" }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16

            Label {
                text: "Coverage Path Planner"
                font.pixelSize: 15
                font.bold: true
                color: "#e8eaf6"
                leftPadding: 4
            }

            Item { Layout.fillWidth: true }

            Label {
                text: "v0.1"
                font.pixelSize: 11
                color: "#7986cb"
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

                Label {
                    text: "Mission Controls"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#1a2744"
                    Layout.topMargin: 4
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
                        visible: mapView.vertices.length === 0
                    }

                    ListView {
                        id: pointsList
                        anchors.fill: parent
                        clip: true
                        model: mapView.vertexModel
                        spacing: 8
                        visible: mapView.vertices.length > 0

                        delegate: Rectangle {
                            width: pointsList.width
                            height: 48
                            color: "white"
                            radius: 8
                            border.color: "#edf2f7"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                Rectangle {
                                    width: 24
                                    height: 24
                                    radius: 12
                                    color: "#ebf8ff"
                                    
                                    Label {
                                        anchors.centerIn: parent
                                        text: (index + 1)
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: "#3182ce"
                                    }
                                }

                                Column {
                                    Layout.fillWidth: true
                                    Label {
                                        text: "Punto #" + (index + 1)
                                        font.pixelSize: 12
                                        font.bold: true
                                        color: "#2d3748"
                                    }
                                    Label {
                                        text: model.lat.toFixed(6) + ", " + model.lng.toFixed(6)
                                        font.pixelSize: 11
                                        color: "#718096"
                                        font.family: "Monospace"
                                    }
                                }
                            }
                        }

                        footer: Item {
                            width: pointsList.width
                            height: 20
                        }
                    }
                }
            }
        }
    }
}
