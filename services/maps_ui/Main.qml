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
        implicitHeight: 50 // Un poco más de aire para que luzca mejor

        background: Rectangle {
            color: "#FFFFFF"
            // Opcional: una línea fina gris abajo para separar del mapa
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: "#D9DFE4"
            }
        }

        Item {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16

            // --- PARTE IZQUIERDA: LOGO Y TÍTULOS ---
            Row {
                id: headerContent
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Image {
                    id: logo
                    source: "/qt/qml/projet_de_recherche/assets/images/LogoIMT.png"
                    height: 40
                    fillMode: Image.PreserveAspectFit
                }

                Column {
                    spacing: -2
                    Label {
                        text: "Drone Path Planner"
                        color: "#000000"
                        font { family: "Geist Sans"; pixelSize: 18; weight: Font.DemiBold; letterSpacing: -0.5}
                    }
                    Label {
                        text: "Planificateur de couverture"
                        color: "#5f6368"
                        font { family: "Geist Sans"; pixelSize: 12; letterSpacing: -0.5 }
                    }
                }
            }

            // --- PARTE DERECHA: ESTADO E INFORMACIÓN ---
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 20

                // Indicador de Desconectado (estilo cápsula)
                Rectangle {
                    width: 130
                    height: 24
                    color: "#E6ECF1"
                    radius: 16
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        Image{
                            source: "/qt/qml/projet_de_recherche/assets/icons/wifi_off.svg"
                            sourceSize.width: 14
                            sourceSize.height: 14
                        }
                            // Icono simple o usa un Image
                        Text {
                            text: "Déconnecté"
                            color: "#51565A"
                            font { family: "Geist Sans"; pixelSize: 12; letterSpacing: -0.5}

                        }
                    }
                }

                // Texto de estado
                Label {
                    text: "Aucune zone sélectionnée"
                    color: "#5f6368"
                    anchors.verticalCenter: parent.verticalCenter
                    font { family: "Geist Sans"; pixelSize: 14; letterSpacing: -0.5}
                }

                // Icono de información con Hover
                Label {
                    text: "ⓘ"
                    font.pixelSize: 22
                    color: infoHover.hovered ? "#000000" : "#5f6368"
                    anchors.verticalCenter: parent.verticalCenter

                    HoverHandler { id: infoHover }

                    // Cuadrito (Tooltip) que aparece al pasar el ratón
                    Rectangle {
                        visible: infoHover.hovered
                        parent: Overlay.overlay // Para que aparezca sobre todo
                        x: infoHover.point.position.x - width/2
                        y: 65 // Debajo del toolbar
                        width: 180
                        height: 50
                        color: "#333333"
                        radius: 4

                        Column {
                            anchors.centerIn: parent
                            Text {
                                text: "Créé par:"
                                color: "white"; font.pixelSize: 10; font.bold: true
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Text {
                                text: "Nombre de los Creadores"
                                color: "white"; font.pixelSize: 12
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }
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
                color: "#D9DFE4"
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
                            text: "Planificateur"
                            font.pixelSize: 18
                            font.bold: true
                            color: "#1a2744"
                            font.letterSpacing: -0.2
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
                                    Label { Layout.fillWidth: true; text: model.lat.toFixed(5) + ", " + model.lng.toFixed(5); font.pixelSize: 11; color: "#4a5568"; font.family: "Geist Mono" }
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
                                    Label { Layout.fillWidth: true; text: model.lat.toFixed(5) + ", " + model.lng.toFixed(5); font.pixelSize: 11; color: "#4a5568"; font.family: "Geist Mono" }
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
                        text: mapView.isProcessing ? "Traitement..." : "Calculer la meilleure route"
                        enabled: mapView.vertices.length >= 3 && !mapView.drawingMode && !mapView.drawingRestrictions && !mapView.isProcessing

                        contentItem: Item {
                            anchors.fill: parent
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 10
                                BusyIndicator {
                                    visible: mapView.isProcessing
                                    running: mapView.isProcessing
                                    implicitWidth: 24; implicitHeight: 24
                                }
                                Label {
                                    text: exportBtn.text
                                    font.bold: true
                                    font.pixelSize: 14
                                    color: "white"
                                }
                            }
                        }

                        background: Rectangle {
                            radius: 12
                            color: mapView.isProcessing ? "#455a64" : "#1a237e"
                            opacity: exportBtn.enabled ? (exportBtn.pressed ? 0.8 : 1.0) : 0.5
                            layer.enabled: exportBtn.enabled
                            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#301a237e"; shadowBlur: 0.2; shadowVerticalOffset: 4 }

                            Behavior on color { ColorAnimation { duration: 300 } }
                        }
                        onClicked: mapView.startProcessing()
                    }
                }
            }
        }
    }
}
