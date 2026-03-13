import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

ApplicationWindow {
    id: root

    width: 1280
    height: 720
    minimumWidth: 900
    minimumHeight: 600
    visible: true
    title: "PDR"

    header: ToolBar {
        implicitHeight: 60

        background: Rectangle {
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#2c3e50" }
                GradientStop { position: 1.0; color: "#000000" }
            }
        }

        Item {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16

            Image {
                id: logo
                source: "/qt/qml/projet_de_recherche/LogoIMTInverso.png"
                height: parent.height * 0.6
                fillMode: Image.PreserveAspectFit
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
            }

            Label {
                text: qsTr("Planificateur de trajectoire de couverture")
                color: "#e8eaf6"
                anchors.centerIn: parent //centrao

                font {
                    capitalization: Font.AllUppercase
                    family: "Verdana"
                    pixelSize: 20
                    weight: Font.DemiBold
                    letterSpacing: 0.2
                }
            }

            Label {
                text: "13-mars"
                font.pixelSize: 11
                color: "#e8eaf6"
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // area de mapa central
        MapView {
            id: mapView
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        // Right panel lado derecho
        Rectangle {
            width: 300
            Layout.fillHeight: true
            color: "#f8f9fc"

            //Separador :D
            Rectangle {
                width: 1
                height: parent.height
                color: "#dde1ec"
            }

            ScrollView {
                anchors.fill: parent
                anchors.margins: 16
                contentWidth: parent.width - 32
                clip: true

                Column {
                    width: parent.width
                    spacing: 20

                    Column {
                        width: parent.width
                        spacing: 4
                        
                        Label {
                            text: "Points sélectionnés"
                            font.pixelSize: 18
                            font.bold: true
                            color: "#1a2744"
                        }

                        Label {
                            visible: mapView.vertices.length >= 3
                            text: {
                                var area = mapView.netArea;
                                if (area > 1000000) return "Surface : " + (area / 1000000).toLocaleString(Qt.locale(), 'f', 2) + " km²";
                                return "Surface : " + area.toLocaleString(Qt.locale(), 'f', 2) + " m²";
                            }
                            font.pixelSize: 14
                            font.bold: true
                            color: "#2e7d32"
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: "#dde1ec" }

                    Label {
                        text: "Aucun point sélectionné"
                        font.pixelSize: 13
                        color: "#a0aec0"
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width
                        visible: mapView.vertices.length === 0 && mapView.restrictionModel.count === 0
                    }

                    // Section Cobertura
                    Column {
                        width: parent.width; spacing: 8
                        visible: mapView.vertices.length > 0
                        Label { text: "Points de couverture"; font.pixelSize: 13; font.bold: true; color: "#2e7d32" }
                        Repeater {
                            model: mapView.vertexModel
                            delegate: Rectangle {
                                width: parent.width; height: 44; color: "white"; radius: 8; border.color: "#edf2f7" //
                                layer.enabled: true
                                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#08000000"; shadowBlur: 0.1; shadowVerticalOffset: 2 } //caja donde esta cada punto
                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 10; spacing: 10
                                    Rectangle { width: 20; height: 20; radius: 10; color: "#e8f5e9" // el circulo
                                        Label { anchors.centerIn: parent; text: index + 1; font.pixelSize: 10; font.bold: true; color: "#2e7d32" }
                                    }
                                    Label { Layout.fillWidth: true; text: model.lat.toFixed(5) + ", " + model.lng.toFixed(5); font.pixelSize: 11; color: "#4a5568"; font.family: "Monospace" }
                                    Button {
                                        flat: true
                                        padding: 0
                                        contentItem: Label { text: "✕"; color: "#e53935" }
                                        onClicked: mapView.removeMainPoint(index)
                                    }
                                }
                            }
                        }
                    }

                    // Section Restricciones
                    Column {
                        width: parent.width; spacing: 8
                        visible: mapView.restrictionModel.count > 0
                        Label { text: "Points restreints"; font.pixelSize: 13; font.bold: true; color: "#ef6c00" }
                        Repeater {
                            model: mapView.restrictionModel
                            delegate: Rectangle {
                                width: parent.width; height: 44; color: "white"; radius: 8; border.color: "#fff3e0"
                                layer.enabled: true
                                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#08000000"; shadowBlur: 0.1; shadowVerticalOffset: 2 }
                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 10; spacing: 10
                                    Rectangle { width: 18; height: 18; radius: 9; color: "#fff3e0"
                                        Label { anchors.centerIn: parent; text: index + 1; font.pixelSize: 9; font.bold: true; color: "#ef6c00" }
                                    }
                                    Label { Layout.fillWidth: true; text: model.lat.toFixed(5) + ", " + model.lng.toFixed(5); font.pixelSize: 11; color: "#4a5568"; font.family: "Monospace" }
                                    Button {
                                        flat: true
                                        padding: 0
                                        contentItem: Label { text: "✕"; color: "#e53935" }
                                        onClicked: mapView.removeRestrictionPoint(index)
                                    }
                                }
                            }
                        }
                    }

                    Item { width: parent.width; height: 20 } // Spacer

                    Button {
                        id: exportBtn
                        width: parent.width; height: 50
                        text: "Calculer la meilleure route"
                        enabled: mapView.vertices.length >= 3 && !mapView.drawingMode && !mapView.drawingRestrictions
                        contentItem: Label {
                            text: exportBtn.text
                            font.bold: true
                            font.pixelSize: 14
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            opacity: exportBtn.enabled ? 1.0 : 0.4
                        }
                        background: Rectangle {
                            radius: 12; color: "#1a237e"
                            opacity: exportBtn.enabled ? (exportBtn.pressed ? 0.8 : 1.0) : 0.5
                            layer.enabled: exportBtn.enabled
                            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#301a237e"; shadowBlur: 0.2; shadowVerticalOffset: 4 }
                        }
                        onClicked: console.log("Calculer cliqué")
                    }
                }
            }
        }
    }
}
