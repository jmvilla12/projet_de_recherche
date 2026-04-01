import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes

ApplicationWindow {
    id: root

    width: 1280
    height: 720
    minimumWidth: 900
    minimumHeight: 600
    visible: true
    title: "IMT - Drone Path Planner"

    // --- Estado ---
    property int connectionState: 0 // 0: Déconnecté, 1: En train de connecter, 2: Connecté
    Timer {
        id: connectionTimer
        interval: 2000
        repeat: false
        onTriggered: root.connectionState = 2
    }

    header: ToolBar {
        implicitHeight: 50

        background: Rectangle {
            color: "#FFFFFF"

            // Línea gris
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

                // Pill GPS (Only if Connected)
                Rectangle {
                    visible: root.connectionState === 2
                    width: gpsRow.width + 24
                    height: 28
                    color: "#e2e8f0"
                    radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    Row {
                        id: gpsRow
                        anchors.centerIn: parent
                        spacing: 8
                        Image {
                            source: "/qt/qml/projet_de_recherche/assets/icons/globe_icon.svg"
                            sourceSize: Qt.size(14, 14)
                            anchors.verticalCenter: parent.verticalCenter
                            layer.enabled: true
                            layer.effect: MultiEffect { colorization: 1.0; colorizationColor: "#00a651" }
                        }
                        Label {
                            text: "GPS Drone: 19.43365, -99.13587  0m"
                            color: "#4a5568"
                            font { family: "Geist Sans"; pixelSize: 13; letterSpacing: -0.2 }
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Pill Connection Status
                Rectangle {
                    width: connRow.width + 20
                    height: 28
                    color: root.connectionState === 2 ? "#e6f4ea" : (root.connectionState === 1 ? "#fff3e0" : "#E6ECF1")
                    radius: 14
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        id: connRow
                        anchors.centerIn: parent
                        spacing: 8
                        
                        Image {
                            source: root.connectionState === 2 ? "/qt/qml/projet_de_recherche/assets/icons/wifi_off.svg" : 
                                   (root.connectionState === 1 ? "/qt/qml/projet_de_recherche/assets/icons/circulo_dibujar.svg" : "/qt/qml/projet_de_recherche/assets/icons/wifi_off.svg")
                            sourceSize.width: 14
                            sourceSize.height: 14
                            anchors.verticalCenter: parent.verticalCenter
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                colorization: 1.0
                                colorizationColor: root.connectionState === 2 ? "#00a651" : (root.connectionState === 1 ? "#f59e0b" : "#51565A")
                            }
                            RotationAnimation on rotation {
                                loops: Animation.Infinite; from: 0; to: 360; duration: 1000; running: root.connectionState === 1
                            }
                        }

                        Text {
                            text: root.connectionState === 2 ? "Connecté" : (root.connectionState === 1 ? "Connexion en cours..." : "Déconnecté")
                            color: root.connectionState === 2 ? "#00a651" : (root.connectionState === 1 ? "#f59e0b" : "#51565A")
                            font { family: "Geist Sans"; pixelSize: 13; bold: root.connectionState === 2; letterSpacing: -0.2}
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Rectangle {
                            visible: root.connectionState === 2
                            width: 60; height: 18; color: "#cbd5e1"; radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                anchors.centerIn: parent; text: "Inactif"; color: "#4a5568"
                                font { family: "Geist Sans"; pixelSize: 10 }
                            }
                        }
                        
                        Row {
                            visible: root.connectionState === 2
                            spacing: 4
                            anchors.verticalCenter: parent.verticalCenter

                            Image {
                                source: "/qt/qml/projet_de_recherche/assets/icons/icon_battery.svg" // O la ruta correspondiente
                                width: 14
                                height: 14
                                sourceSize: Qt.size(14, 14)
                                anchors.verticalCenter: parent.verticalCenter

                                // Si quieres que el icono sea verde como el texto "85%"
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    colorization: 1.0
                                    colorizationColor: "#00a651"
                                }
                            }

                            Text {
                                text: "85%"
                                color: "#00a651"
                                font { family: "Geist Sans"; pixelSize: 13; bold: true }
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                // Texto de estado
                Label {
                    text: root.connectionState === 2 ? "Aucune mission active" : (mapView.drawingMode ? "Dessin de la mission..." : "Aucune zone sélectionnée")
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

                    // Cuadrito (Tooltip) hover
                    Rectangle {
                        visible: infoHover.hovered
                        parent: Overlay.overlay
                        width: 180; height: 50; radius: 4; color: "#333333"
                        x: root.width - width - 16
                        y: 55

                        Column {
                            anchors.centerIn: parent
                            Text { text: "Créé par:"; color: "white"; font.pixelSize: 10; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                            Text { text: "S.R + J.V + J.V"; color: "white"; font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter }
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        anchors.fill: parent

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


                    RowLayout {
                        width: parent.width
                        spacing: 12

                        Column {
                            Layout.fillWidth: true
                            spacing: 4



                            Label {
                                text: "Planificateur"
                                font.pixelSize: 18
                                font.bold: true
                                color: "#1a2744"
                                font.letterSpacing: -0.2


                            }


                        }

                        Button {
                            id: relocateBtn
                            implicitWidth: 28
                            implicitHeight: 28
                            flat: true

                            background: Rectangle {
                                color: relocateBtn.pressed ? "#e0e6ed" : (relocateBtn.hovered ? "#f0f4f8" : "white")
                                border.color: "#d1dce5"
                                border.width: 1
                                radius: 10
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    shadowEnabled: true
                                    shadowColor: "#15000000"
                                    shadowBlur: 0.1
                                    shadowVerticalOffset: 1
                                }
                            }

                            contentItem: Item {
                                Image {
                                    anchors.centerIn: parent
                                    source: "/qt/qml/projet_de_recherche/assets/icons/Location_Searching.svg"
                                    fillMode: Image.PreserveAspectFit
                                    sourceSize: Qt.size(16, 16)
                                    opacity: 0.8
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: droneStatusCard
                        width: parent.width
                        implicitHeight: mainStatusLayout.implicitHeight + 24
                        color: "white"
                        radius: 12
                        border.color: "#edf2f7"
                        border.width: 1

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true; shadowColor: "#08000000"; shadowBlur: 0.1; shadowVerticalOffset: 2
                        }

                        // Implementacion de visibilidad
                        ColumnLayout {
                            id: mainStatusLayout
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 16
                            spacing: 12

                            // 1. HEADER ROW (Shared)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Row {
                                    spacing: 6
                                    Image {
                                        source: root.connectionState === 2 ? "/qt/qml/projet_de_recherche/assets/icons/wifi_off.svg" : (root.connectionState === 1 ? "/qt/qml/projet_de_recherche/assets/icons/circulo_dibujar.svg" : "/qt/qml/projet_de_recherche/assets/icons/wifi_off.svg")
                                        sourceSize: Qt.size(16, 16)
                                        anchors.verticalCenter: parent.verticalCenter
                                        layer.enabled: true
                                        layer.effect: MultiEffect {
                                            colorization: 1.0
                                            colorizationColor: root.connectionState === 2 ? "#00a651" : (root.connectionState === 1 ? "#f59e0b" : "#070B0F")
                                        }
                                        RotationAnimation on rotation { loops: Animation.Infinite; from: 0; to: 360; duration: 1000; running: root.connectionState === 1 }
                                    }
                                    Label {
                                        text: root.connectionState === 2 ? "Connecté" : (root.connectionState === 1 ? "En cours..." : "Déconnecté")
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: "#070B0F"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Button {
                                    id: connectBtn
                                    implicitHeight: 32
                                    leftPadding: 10
                                    rightPadding: 10

                                    background: Rectangle {
                                        color: connectBtn.hovered ? "#e1e9f0" : (root.connectionState === 1 ? "#fafafa" : "#f8fafd")
                                        border.color: "#e2e8f0"
                                        border.width: 1
                                        radius: 8
                                    }

                                    contentItem: Row {
                                        spacing: 6
                                        Image {
                                            // CAMBIO AQUÍ: Si el estado es 2 (Conectado), muestra bola_off, si no, wifi_off
                                            source: root.connectionState === 2
                                                    ? "/qt/qml/projet_de_recherche/assets/icons/power_off_icon.svg"
                                                    : "/qt/qml/projet_de_recherche/assets/icons/wifi_off.svg"

                                            sourceSize: Qt.size(14, 14)
                                            opacity: root.connectionState === 1 ? 0.4 : 0.8
                                            anchors.verticalCenter: parent.verticalCenter
                                            layer.enabled: true
                                            layer.effect: MultiEffect {
                                                colorization: 1.0;
                                                colorizationColor: "#000000"
                                            }
                                        }

                                        Label {
                                            text: root.connectionState === 2 ? "Déconnecter" : "Connecter"
                                            font.pixelSize: 12
                                            color: root.connectionState === 1 ? "#a0aec0" : "#070B0F"
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    onClicked: {
                                        if (root.connectionState === 0) {
                                            root.connectionState = 1;
                                            connectionTimer.start();
                                        } else if (root.connectionState === 2) {
                                            root.connectionState = 0;
                                        }
                                    }
                                }
                            }

                            // 2. DISCONNECTED / CONNECTING CONTENT
                            Column {
                                Layout.fillWidth: true; Layout.alignment: Qt.AlignHCenter
                                spacing: 12
                                visible: root.connectionState !== 2

                                Item { width: 1; height: 10 }
                                Image {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    source: "/qt/qml/projet_de_recherche/assets/icons/wifi_off.svg"
                                    sourceSize: Qt.size(32, 32)
                                    opacity: 0.1
                                }
                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Connectez votre drone pour consulter"
                                    font.pixelSize: 13; color: "#5f6368"; horizontalAlignment: Text.AlignHCenter
                                }
                                Item { width: 1; height: 10 }
                            }

                            // 3. CONNECTED CONTENT
                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: root.connectionState === 2
                                spacing: 12

                                // Inactivo
                                Rectangle {
                                    Layout.fillWidth: true; height: 32; color: "#f1f5f9"; radius: 6; border.color: "#cbd5e1"; border.width: 1
                                    Label { anchors.centerIn: parent; text: "INACTIF"; color: "#64748b"; font.bold: true; font.pixelSize: 13 }
                                }

                                // Bateria & Senal
                                RowLayout {
                                    Layout.fillWidth: true; spacing: 12

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 75
                                        color: "#f8fafc"
                                        radius: 8

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 4

                                            // Contenedor horizontal para Icono + Texto
                                            Row {
                                                spacing: 6
                                                height: 16 // Fijamos la altura de la fila para que el centrado sea preciso

                                                Image {
                                                    source: "/qt/qml/projet_de_recherche/assets/icons/icon_battery.svg"
                                                    width: 16
                                                    height: 16
                                                    sourceSize.width: 16
                                                    sourceSize.height: 16
                                                    fillMode: Image.PreserveAspectFit
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                Label {
                                                    text: "Batterie"
                                                    color: "#64748b"
                                                    font.pixelSize: 13
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }

                                            // Porcentaje de batería
                                            Label {
                                                text: "84.97%"
                                                color: "#00a651"
                                                font.pixelSize: 20
                                                font.bold: true
                                                font.family: "Geist Mono"
                                            }
                                        }
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 75
                                        color: "#f8fafc"
                                        radius: 8

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 4

                                            Row {
                                                spacing: 6
                                                height: 16 // Altura de referencia para el alineado vertical

                                                Image {
                                                    source: "/qt/qml/projet_de_recherche/assets/icons/cell5_bar.svg"
                                                    width: 16
                                                    height: 16
                                                    sourceSize.width: 16
                                                    sourceSize.height: 16
                                                    fillMode: Image.PreserveAspectFit
                                                    // Centrado vertical corregido
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                Label {
                                                    text: "Signal"
                                                    color: "#64748b"
                                                    font.pixelSize: 13
                                                    // Centrado vertical corregido
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }
                                            }

                                            Label {
                                                text: "90.42"
                                                color: "#000000"
                                                font.pixelSize: 20
                                                font.bold: true
                                                font.family: "Geist Mono"
                                            }
                                        }
                                    }
                                }

                                // GPS Info
                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: gpsColLayout.implicitHeight + 32
                                    color: "#f8fafc"; border.color: "#e2e8f0"; border.width: 1; radius: 8
                                    
                                    ColumnLayout {
                                        id: gpsColLayout
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.margins: 16
                                        spacing: 16

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8 // Un poco más de espacio queda mejor en RowLayout

                                            // Icono principal (Búsqueda)
                                            Image {
                                                source: "/qt/qml/projet_de_recherche/assets/icons/location_icon.svg"
                                                sourceSize: Qt.size(16, 16)
                                                Layout.alignment: Qt.AlignVCenter
                                                layer.enabled: true
                                                        layer.effect: MultiEffect {
                                                            colorization: 1.0;
                                                            colorizationColor: "#64748b" // Mismo verde que el otro icono
                                                        }
                                            }

                                            Label {
                                                text: "GPS du drone"
                                                font.bold: true
                                                font.pixelSize: 14
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                            }

                                            // Nuevo Icono de Satélite sustituyendo al emoji
                                            Image {
                                                source: "/qt/qml/projet_de_recherche/assets/icons/satellite_icon.svg" // Asegúrate de que la ruta sea correcta
                                                width: 16
                                                height: 16
                                                sourceSize: Qt.size(16, 16)
                                                opacity: 0.6
                                                Layout.alignment: Qt.AlignVCenter
                                                // Si quieres que también sea verde, puedes copiar el layer.effect aquí
                                            }

                                            Label {
                                                text: "13 sats"
                                                color: "#64748b"
                                                font.pixelSize: 13
                                                Layout.alignment: Qt.AlignVCenter
                                            }
                                        }

                                        RowLayout {
                                            Layout.fillWidth: true
                                            Column {
                                                spacing: 4
                                                Label { text: "Lat:"; color: "#64748b"; font.family: "Geist Mono"; font.pixelSize: 14 }
                                                Label { text: "Lng:"; color: "#64748b"; font.family: "Geist Mono"; font.pixelSize: 14 }
                                            }
                                            Item { Layout.fillWidth: true }
                                            Column {
                                                spacing: 4
                                                Label { text: "19.43"; font.family: "Geist Mono"; font.pixelSize: 14; horizontalAlignment: Text.AlignRight }
                                                Label { text: "-99.13"; font.family: "Geist Mono"; font.pixelSize: 14; horizontalAlignment: Text.AlignRight }
                                            }
                                        }

                                        Label { Layout.alignment: Qt.AlignHCenter; text: "Précision: ±3.9m"; color: "#64748b"; font.pixelSize: 12 }
                                    }
                                }

                                Label { Layout.alignment: Qt.AlignHCenter; text: "Mis à jour : 23h56"; color: "#64748b"; font.pixelSize: 12 }
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: "#dde1ec" }

                    // --- SECCIÓN MODO DE DIBUJO ---
                    Label {
                        text: "MODE DESSIN"
                        font.pixelSize: 12
                        font.bold: true
                        font.capitalization: Font.AllUppercase
                        color: "#5f6368"
                        leftPadding: 4
                    }

                    RowLayout {
                        width: parent.width
                        Button {
                            id: misionBtn
                            Layout.fillWidth: true
                            Layout.preferredWidth: 100
                            implicitHeight: 44

                            // Propiedad para saber si está seleccionado
                            property bool active: mapView.drawingMode

                            background: Rectangle {
                                color: misionBtn.active ? "#00a651" : (misionBtn.pressed ? "#f0f4f8" : (misionBtn.hovered ? "#f8fafd" : "white"))
                                border.color: misionBtn.active ? "#00a651" : "#e2e8f0"
                                border.width: 1
                                radius: 10
                            }

                            contentItem: RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                Image {
                                    source: "/qt/qml/projet_de_recherche/assets/icons/circulo_dibujar.svg"
                                    sourceSize: Qt.size(18, 18)
                                    Layout.alignment: Qt.AlignVCenter
                                    layer.enabled: misionBtn.active
                                    layer.effect: MultiEffect {
                                        colorization: 1.0
                                        colorizationColor: "white"
                                    }
                                }
                                Label {
                                    text: "Mission"
                                    font.pixelSize: 15
                                    font.weight: Font.Medium
                                    color: misionBtn.active ? "white" : "#4a5568"
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                            onClicked: {
                                mapView.drawingMode = true
                                mapView.drawingRestrictions = false
                            }
                        }

                        Button {
                            id: restriccionBtn
                            Layout.fillWidth: true
                            Layout.preferredWidth: 100
                            implicitHeight: 44

                            property bool active: mapView.drawingRestrictions
                            enabled: mapView.vertices.length >= 3 || mapView.restrictionZones.length > 0

                            background: Rectangle {
                                color: restriccionBtn.active ? "#e53935" : (restriccionBtn.pressed ? "#f0f4f8" : (restriccionBtn.hovered ? "#f8fafd" : "white"))
                                border.color: restriccionBtn.active ? "#e53935" : "#e2e8f0"
                                border.width: 1
                                radius: 10
                                opacity: restriccionBtn.enabled ? 1.0 : 0.4
                            }

                            contentItem: RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                Image {
                                    source: "/qt/qml/projet_de_recherche/assets/icons/restric_icon.svg"
                                    sourceSize: Qt.size(18, 18)
                                    Layout.alignment: Qt.AlignVCenter
                                    opacity: restriccionBtn.enabled ? 1.0 : 0.4
                                    layer.enabled: restriccionBtn.active
                                    layer.effect: MultiEffect {
                                        colorization: 1.0
                                        colorizationColor: "white"
                                    }
                                }
                                Label {
                                    text: "Restriction"
                                    font.pixelSize: 15
                                    font.weight: Font.Medium
                                    color: restriccionBtn.active ? "white" : "#4a5568"
                                    verticalAlignment: Text.AlignVCenter
                                    opacity: restriccionBtn.enabled ? 1.0 : 0.4
                                }
                            }
                            onClicked: {
                                mapView.drawingMode = false
                                mapView.drawingRestrictions = true
                            }
                        }
                    }

                    // --- MISION DE VUELO SECTION ---
                    Column {
                        width: parent.width
                        spacing: 12

                        RowLayout {
                            width: parent.width
                            Label {
                                text: "Mission de vol"
                                font.pixelSize: 12; font.bold: true; font.capitalization: Font.AllUppercase; color: "#5f6368"
                                Layout.fillWidth: true
                            }
                        }

                        // Placeholder when NO vertices
                        Rectangle {
                            width: parent.width; height: 160; radius: 12; color: "transparent"
                            visible: mapView.vertices.length === 0
                            clip: true

                            Shape {
                                id: dashContainer
                                anchors.fill: parent
                                property real margin: 0.6
                                ShapePath {
                                        strokeColor: "#94a3b8"
                                        strokeWidth: 1.2
                                        fillColor: "transparent"
                                        strokeStyle: ShapePath.DashLine
                                        dashPattern: [4, 4]

                                        // Usamos dashContainer.margin para asegurar que lo encuentre
                                        startX: 12 + dashContainer.margin
                                        startY: dashContainer.margin

                                        PathLine {
                                            x: dashContainer.width - 12 - dashContainer.margin
                                            y: dashContainer.margin
                                        }
                                        PathArc {
                                            x: dashContainer.width - dashContainer.margin
                                            y: 12 + dashContainer.margin
                                            radiusX: 12; radiusY: 12
                                        }

                                        PathLine {
                                            x: dashContainer.width - dashContainer.margin
                                            y: dashContainer.height - 12 - dashContainer.margin
                                        }
                                        PathArc {
                                            x: dashContainer.width - 12 - dashContainer.margin
                                            y: dashContainer.height - dashContainer.margin
                                            radiusX: 12; radiusY: 12
                                        }

                                        PathLine {
                                            x: 12 + dashContainer.margin
                                            y: dashContainer.height - dashContainer.margin
                                        }
                                        PathArc {
                                            x: dashContainer.margin
                                            y: dashContainer.height - 12 - dashContainer.margin
                                            radiusX: 12; radiusY: 12
                                        }

                                        PathLine {
                                            x: dashContainer.margin
                                            y: 12 + dashContainer.margin
                                        }
                                        PathArc {
                                            x: 12 + dashContainer.margin
                                            y: dashContainer.margin
                                            radiusX: 12; radiusY: 12
                                        }
                                    }
                            }

                            Column {
                                anchors.centerIn: parent; spacing: 10
                                Image {
                                    source: "/qt/qml/projet_de_recherche/assets/icons/drone_icon.svg"
                                    sourceSize: Qt.size(48, 48)
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    opacity: 0.5
                                }
                                Label {
                                    text: "Sans mision"; font.pixelSize: 16; font.bold: true; color: "#4a5568"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Label {
                                    text: "Crée-en une pour commencer"; font.pixelSize: 13; color: "#94a3b8"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }

                        // Actual Mission Card
                        Rectangle {
                            width: parent.width
                            implicitHeight: cardContent.height + 32
                            radius: 12
                            color: "white"
                            border.color: "#00a651"
                            border.width: 1
                            visible: mapView.vertices.length > 0

                            Column {
                                id: cardContent
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 16
                                spacing: 16

                                RowLayout {
                                    width: parent.width
                                    spacing: 10
                                    Rectangle {
                                        width: 12; height: 12; radius: 6; color: "#00a651"
                                    }
                                    Label {
                                        text: "Mission Principale"
                                        font.pixelSize: 15; font.bold: true; color: "#070B0F"
                                    }
                                    Item { Layout.fillWidth: true }
                                    Rectangle {
                                        width: 80; height: 24; radius: 6; color: "#e8f0fe"
                                        Label {
                                            anchors.centerIn: parent
                                            text: "En cours..."; font.pixelSize: 11; color: "#4a5568"
                                        }
                                    }
                                }

                                Label {
                                    text: mapView.vertices.length + " Sommets  -  0 waypoints"
                                    font.pixelSize: 13; color: "#5f6368"
                                }

                                Rectangle { width: parent.width; height: 1; color: "#edf2f7" }

                                Label {
                                    text: "Sommets de la zone (" + mapView.vertices.length + ")"
                                    font.pixelSize: 13; font.bold: true; color: "#5f6368"
                                }

                                Repeater {
                                    model: mapView.vertexModel
                                    delegate: Rectangle {
                                        width: parent.width; height: 40; color: "#f8fafd"; radius: 8
                                        RowLayout {
                                            anchors.fill: parent; anchors.margins: 8; spacing: 10
                                            Rectangle {
                                                width: 20; height: 20; radius: 10; color: "#00a651"
                                                Label { anchors.centerIn: parent; text: index + 1; font.pixelSize: 10; font.bold: true; color: "white" }
                                            }
                                            Label { Layout.fillWidth: true; text: model.lat.toFixed(5) + ", " + model.lng.toFixed(5); font.pixelSize: 11; color: "#4a5568"; font.family: "Geist Mono" }
                                            Button {
                                                id: deleteBtn
                                                implicitWidth: 24
                                                implicitHeight: 24
                                                flat: true

                                                background: Rectangle {
                                                        color: deleteBtn.hovered ? "#f1f5f9" : "transparent" // Fondo sutil al hacer hover
                                                        radius: 6 // Ajusta este valor para redondear más o menos
                                                        border.color: deleteBtn.hovered ? "#e2e8f0" : "transparent"
                                                        border.width: 1
                                                    }

                                                contentItem: Image {
                                                    source: "/qt/qml/projet_de_recherche/assets/icons/delete_icon.svg" // O la ruta completa a tus assets
                                                    sourceSize: Qt.size(16, 16) // Un poco más pequeño que el botón para dejar margen
                                                    fillMode: Image.PreserveAspectFit
                                                    horizontalAlignment: Image.AlignHCenter
                                                    verticalAlignment: Image.AlignVCenter

                                                    // Aplicamos el color gris (#a0aec0) que tenía el texto original
                                                    layer.enabled: true
                                                    layer.effect: MultiEffect {
                                                        colorization: 1.0
                                                        colorizationColor: "#a0aec0"
                                                    }

                                                    // Opcional: que cambie a un gris más oscuro al pasar el ratón
                                                    opacity: deleteBtn.hovered ? 1.0 : 0.7
                                                }

                                                onClicked: mapView.removeMainPoint(index)
                                            }
                                        }
                                    }
                                }

                                Column {
                                    width: parent.width
                                    spacing: 8

                                    Button {
                                        id: generarRutaBtn
                                        width: parent.width
                                        implicitHeight: 44

                                        background: Rectangle {
                                            radius: 8
                                            color: generarRutaBtn.pressed ? "#008a44" : "#00a651" // Efecto de oscurecer al presionar
                                        }

                                        contentItem: RowLayout {
                                            spacing: 8

                                            Image {
                                                source: "/qt/qml/projet_de_recherche/assets/icons/grid_icon.svg" // Ajusta la ruta si es necesario
                                                Layout.preferredWidth: 18
                                                Layout.preferredHeight: 18
                                                sourceSize: Qt.size(18, 18)
                                                fillMode: Image.PreserveAspectFit
                                                Layout.alignment: Qt.AlignVCenter

                                                // Forzamos el icono a color blanco
                                                layer.enabled: true
                                                layer.effect: MultiEffect {
                                                    colorization: 1.0
                                                    colorizationColor: "#ffffff"
                                                }
                                            }

                                            Label {
                                                text: "Générer l'itinéraire"
                                                color: "white"
                                                font.bold: true
                                                font.pixelSize: 15
                                                Layout.alignment: Qt.AlignVCenter
                                            }
                                        }

                                        onClicked: {
                                            mapView.startProcessing()
                                            // Activar exportar al dar generar ruta (mock)
                                            exportMisionBtn.enabled = true
                                        }
                                    }

                                    RowLayout {
                                        width: parent.width
                                        spacing: 10
                                        Button {
                                            id: exportMisionBtn
                                            Layout.fillWidth: true
                                            implicitHeight: 44
                                            enabled: false // Se habilita con Generar ruta

                                            background: Rectangle {
                                                radius: 8
                                                color: "white"
                                                border.color: exportMisionBtn.enabled ? "#e2e8f0" : "#f1f5f9"
                                                border.width: 1
                                            }

                                            contentItem: RowLayout {
                                                spacing: 8

                                                Image {
                                                    source: "/qt/qml/projet_de_recherche/assets/icons/share_icon.svg"
                                                    Layout.preferredWidth: 18
                                                    Layout.preferredHeight: 18
                                                    sourceSize: Qt.size(18, 18)
                                                    fillMode: Image.PreserveAspectFit
                                                    Layout.alignment: Qt.AlignVCenter

                                                    layer.enabled: true
                                                    layer.effect: MultiEffect {
                                                        colorization: 1.0
                                                        // El icono cambia de color según si el botón está habilitado o no
                                                        colorizationColor: exportMisionBtn.enabled ? "#4a5568" : "#94a3b8"
                                                    }
                                                }

                                                Label {
                                                    text: "Exporter"
                                                    font.bold: true
                                                    font.pixelSize: 15
                                                    color: exportMisionBtn.enabled ? "#4a5568" : "#94a3b8"
                                                    Layout.alignment: Qt.AlignVCenter
                                                }
                                            }
                                        }
                                        Button {
                                            id: clearMissionBtn
                                            implicitWidth: 36
                                            implicitHeight: 36

                                            background: Rectangle {
                                                radius: 8
                                                color: clearMissionBtn.pressed ? "#b71c1c" : "#d32f2f" // Un rojo más oscuro al presionar
                                            }

                                            Button {
                                                implicitWidth: 44
                                                implicitHeight: 44

                                                background: Rectangle {
                                                    radius: 8
                                                    color: clearMissionBtn.pressed ? "#b71c1c" : "#d32f2f"
                                                }

                                                contentItem: Item {
                                                    // Este contenedor ocupa los 44x44 y nos permite centrar la imagen pequeña dentro
                                                    anchors.fill: parent

                                                    Image {
                                                        source: "/qt/qml/projet_de_recherche/assets/icons/delete_icon_white.svg"

                                                        // Fuerza el tamaño visual aquí (ajusta 16 a lo que prefieras)
                                                        width: 16
                                                        height: 16

                                                        // Renderiza el SVG a este tamaño exacto para que no se vea borroso
                                                        sourceSize: Qt.size(width, height)

                                                        fillMode: Image.PreserveAspectFit
                                                        anchors.centerIn: parent // Lo centra perfectamente en el botón

                                                        layer.enabled: true
                                                        layer.effect: MultiEffect {
                                                            colorization: 1.0
                                                            colorizationColor: "#ffffff"
                                                        }
                                                    }
                                                }
                                                onClicked: {
                                                    mapView.vertices = []
                                                    mapView.vertexModel.clear()
                                                    mapView.updatePolygonPaths()
                                                    exportMisionBtn.enabled = false
                                                }
                                            }

                                            onClicked: {
                                                mapView.vertices = []
                                                mapView.vertexModel.clear()
                                                mapView.updatePolygonPaths()
                                                exportMisionBtn.enabled = false
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // --- ZONAS DE RESTRICCION ---
                    Column {
                        width: parent.width
                        spacing: 12
                        visible: mapView.vertices.length >= 3 || mapView.restrictionZones.length > 0 || mapView.drawingRestrictions

                        RowLayout {
                            width: parent.width
                            Label {
                                text: "ZONES DE RESTRICTIONS"
                                font.pixelSize: 12
                                font.bold: true
                                font.capitalization: Font.AllUppercase
                                color: "#5f6368"
                                Layout.fillWidth: true
                            }
                            Button {
                                id: addRestrBtn
                                implicitWidth: 90; implicitHeight: 32; flat: true
                                background: Rectangle {
                                    radius: 6;
                                    color: addRestrBtn.pressed ? "#e2e8f0" : (addRestrBtn.hovered ? "#edf2f7" : "#f8fafd")
                                    border.color: "#e2e8f0"; border.width: 1
                                }
                                contentItem: RowLayout {
                                    anchors.centerIn: parent; spacing: 4
                                    Label { text: "+"; color: "#1a2744"; font.pixelSize: 16 }
                                    Label { text: "Ajouter"; color: "#1a2744"; font.pixelSize: 13; font.bold: true }
                                }
                                onClicked: {
                                    mapView.finalizeCurrentRestriction()
                                    mapView.drawingRestrictions = true
                                    mapView.drawingMode = false
                                }
                            }
                        }
                        // Placeholder when NO restriction zones and not drawing
                        Rectangle {
                            width: parent.width; height: 120; radius: 12; color: "transparent"
                            visible: mapView.restrictionZones.length === 0 && !mapView.drawingRestrictions
                            clip: true

                            Shape {
                                id: dashContainer2
                                anchors.fill: parent
                                property real margin: 0.8
                                ShapePath {
                                        strokeColor: "#94a3b8"
                                        strokeWidth: 1.2
                                        fillColor: "transparent"
                                        strokeStyle: ShapePath.DashLine
                                        dashPattern: [4, 4]

                                        // Usamos dashContainer.margin para asegurar que lo encuentre
                                        startX: 12 + dashContainer2.margin
                                        startY: dashContainer2.margin

                                        PathLine {
                                            x: dashContainer2.width - 12 - dashContainer2.margin
                                            y: dashContainer2.margin
                                        }
                                        PathArc {
                                            x: dashContainer2.width - dashContainer2.margin
                                            y: 12 + dashContainer2.margin
                                            radiusX: 12; radiusY: 12
                                        }

                                        PathLine {
                                            x: dashContainer2.width - dashContainer2.margin
                                            y: dashContainer2.height - 12 - dashContainer2.margin
                                        }
                                        PathArc {
                                            x: dashContainer2.width - 12 - dashContainer2.margin
                                            y: dashContainer2.height - dashContainer2.margin
                                            radiusX: 12; radiusY: 12
                                        }

                                        PathLine {
                                            x: 12 + dashContainer2.margin
                                            y: dashContainer2.height - dashContainer2.margin
                                        }
                                        PathArc {
                                            x: dashContainer2.margin
                                            y: dashContainer2.height - 12 - dashContainer2.margin
                                            radiusX: 12; radiusY: 12
                                        }

                                        PathLine {
                                            x: dashContainer2.margin
                                            y: 12 + dashContainer2.margin
                                        }
                                        PathArc {
                                            x: 12 + dashContainer2.margin
                                            y: dashContainer2.margin
                                            radiusX: 12; radiusY: 12
                                        }
                                    }
                            }

                            Column {
                                anchors.centerIn: parent; spacing: 10
                                Image {
                                    source: "/qt/qml/projet_de_recherche/assets/icons/lock_icon.svg"
                                    sourceSize: Qt.size(40, 40)
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    opacity: 0.5
                                }
                                Label {
                                    text: "Aucune zone de restriction"; font.pixelSize: 15; font.bold: true; color: "#4a5568"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }

                        Column {
                                width: parent.width
                                spacing: 12
                                visible: mapView.restrictionZones.length > 0 || mapView.drawingRestrictions
                             Repeater {
                                 id: zonesRepeater
                                 model: mapView.restrictionZones.length + (mapView.drawingRestrictions ? 1 : 0)
                                 delegate: Rectangle {
                                     id: zoneCard
                                     width: parent.width
                                     implicitHeight: zoneCardContent.height + 24
                                     radius: 12
                                     color: "white"
                                     border.color: zoneColor
                                     border.width: expanded ? 1 : 0

                                     layer.enabled: !expanded
                                     layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#10000000"; shadowBlur: 0.1; shadowVerticalOffset: 1 }

                                     property int zoneIndex: index
                                     property bool isCurrent: index === mapView.restrictionZones.length
                                     property var zoneData: isCurrent ? null : mapView.restrictionZones[index]
                                     property var pts: isCurrent ? mapView.currentRestrictionPoints : zoneData.points
                                     property bool expanded: true // Always show them for now
                                     property color zoneColor: "#e53935"

                                     // Stable property for point numbering
                                     property int pointOffset: isCurrent ? mapView.getTotalPointsBeforeZone(mapView.restrictionZones.length) : mapView.getTotalPointsBeforeZone(index)

                                    Column {
                                        id: zoneCardContent
                                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                                        anchors.margins: 12
                                        spacing: 16

                                        MouseArea {
                                            width: parent.width; height: 32
                                            onClicked: zoneCard.expanded = !zoneCard.expanded

                                            RowLayout {
                                                anchors.fill: parent; spacing: 10
                                                Rectangle { width: 12; height: 12; radius: 6; color: zoneColor }
                                                Label {
                                                    text: isCurrent ? (mapView.currentRestrictionName === "Nouvelle Zone" ? "Nouvelle Zone" : mapView.currentRestrictionName) : zoneData.name
                                                    font.pixelSize: 15; font.bold: true; color: "#070B0F"
                                                }
                                                Item { Layout.fillWidth: true }
                                                Rectangle {
                                                    width: 48; height: 24; radius: 6; color: zoneColor
                                                    Label { anchors.centerIn: parent; text: pts.length + " pts"; font.pixelSize: 11; font.bold: true; color: "white" }
                                                }
                                                Label { text: zoneCard.expanded ? "▲" : "▼"; font.pixelSize: 12; color: "#5f6368"; font.bold: true }
                                            }
                                        }

                                        Column {
                                            width: parent.width
                                            spacing: 16
                                            visible: zoneCard.expanded

                                            Rectangle { width: parent.width; height: 1; color: "#edf2f7" }

                                            Column {
                                                width: parent.width; spacing: 6
                                                Label { text: "Nom"; font.pixelSize: 12; color: "#5f6368" }
                                                TextField {
                                                    width: parent.width; text: isCurrent ? mapView.currentRestrictionName : zoneData.name
                                                    background: Rectangle { radius: 6; border.color: "#e2e8f0"; border.width: 1; color: "white" }
                                                    font.pixelSize: 13
                                                    onTextEdited: {
                                                        if (isCurrent) {
                                                            mapView.currentRestrictionName = text;
                                                        } else {
                                                            var zones = mapView.restrictionZones;
                                                            zones[index].name = text;
                                                            mapView.restrictionZones = zones.slice();
                                                        }
                                                    }
                                                }
                                            }

                                            Label { text: "Points (" + pts.length + ")"; font.pixelSize: 12; color: "#5f6368" }

                                            Column {
                                                width: parent.width; spacing: 4
                                                Repeater {
                                                    model: pts
                                                    delegate: Rectangle {
                                                        width: parent.width; height: 40; color: "#fef8f8"; radius: 6
                                                        RowLayout {
                                                            anchors.fill: parent; anchors.margins: 8; spacing: 8
                                                            Label {
                                                                text: (zoneCard.pointOffset + index + 1)
                                                                font.pixelSize: 11; font.bold: true; color: "#e53935"; width: 22; horizontalAlignment: Text.AlignHCenter
                                                            }
                                                            Label { Layout.fillWidth: true; text: modelData.latitude.toFixed(5) + ", " + modelData.longitude.toFixed(5); font.pixelSize: 11; color: "#4a5568"; font.family: "Geist Mono" }
                                                            Button {
                                                                implicitWidth: 24
                                                                implicitHeight: 24
                                                                flat: true

                                                                contentItem: Item {
                                                                    anchors.fill: parent

                                                                    Image {
                                                                        source: "/qt/qml/projet_de_recherche/assets/icons/delete_icon.svg" // O la ruta de tu icono
                                                                        width: 14
                                                                        height: 14
                                                                        sourceSize: Qt.size(width, height)
                                                                        fillMode: Image.PreserveAspectFit
                                                                        anchors.centerIn: parent

                                                                        layer.enabled: true
                                                                        layer.effect: MultiEffect {
                                                                            colorization: 1.0
                                                                            colorizationColor: "#5f6368" // El color gris oscuro original
                                                                        }
                                                                    }
                                                                }

                                                                onClicked: {
                                                                    var zIdx = zoneCard.zoneIndex;
                                                                    if (zoneCard.isCurrent) {
                                                                        var current = mapView.currentRestrictionPoints;
                                                                        current.splice(index, 1);
                                                                        mapView.currentRestrictionPoints = current.slice();
                                                                    } else {
                                                                        var zones = mapView.restrictionZones;
                                                                        if (zIdx < zones.length) {
                                                                            zones[zIdx].points.splice(index, 1);
                                                                            if (zones[zIdx].points.length < 3) {
                                                                                zones.splice(zIdx, 1);
                                                                            }
                                                                            mapView.restrictionZones = zones.slice();
                                                                        }
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }

                                            Button {
                                                id: deleteZoneBtn
                                                width: parent.width
                                                implicitHeight: 44

                                                background: Rectangle {
                                                    radius: 8
                                                    color: deleteZoneBtn.pressed ? "#b71c1c" : "#d32f2f"
                                                }

                                                contentItem: RowLayout {
                                                    spacing: 8
                                                    // Esto centra el contenido (icono + texto) dentro del botón

                                                    Image {
                                                        source: "/qt/qml/projet_de_recherche/assets/icons/delete_icon_white.svg"
                                                        // Tamaño pequeño para el icono
                                                        Layout.preferredWidth: 16
                                                        Layout.preferredHeight: 16
                                                        sourceSize: Qt.size(16, 16)
                                                        fillMode: Image.PreserveAspectFit

                                                        layer.enabled: true
                                                        layer.effect: MultiEffect {
                                                            colorization: 1.0
                                                            colorizationColor: "#ffffff"
                                                        }
                                                    }

                                                    Label {
                                                        text: "Supprimer la zone"
                                                        color: "white"
                                                        font.bold: true
                                                        font.pixelSize: 14
                                                        Layout.alignment: Qt.AlignVCenter
                                                    }
                                                }

                                                onClicked: {
                                                    var zIdx = zoneCard.zoneIndex;
                                                    if (zoneCard.isCurrent) {
                                                        mapView.currentRestrictionPoints = [];
                                                        mapView.drawingRestrictions = false;
                                                        mapView.drawingMode = true;
                                                    } else {
                                                        var allZ = mapView.restrictionZones;
                                                        if (zIdx < allZ.length) {
                                                            allZ.splice(zIdx, 1);
                                                            mapView.restrictionZones = allZ.slice();
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // --- ESTADISTICAS ---
                    Column {
                        width: parent.width
                        spacing: 12
                        visible: mapView.vertices.length > 0 || mapView.restrictionZones.length > 0

                        Label {
                            text: "STATISTIQUES"
                            font.pixelSize: 12
                            font.bold: true
                            font.capitalization: Font.AllUppercase
                            color: "#5f6368"
                        }

                        GridLayout {
                            width: parent.width
                            columns: 2
                            columnSpacing: 10
                            rowSpacing: 10

                            // --- AREA ---
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 84
                                color: "#f8fafd"; radius: 12; border.color: "#e2e8f0"; border.width: 1
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Row {
                                        spacing: 6; anchors.horizontalCenter: parent.horizontalCenter
                                        Image {
                                            source: "/qt/qml/projet_de_recherche/assets/icons/area_icon.svg"
                                            width: 14; height: 14
                                            sourceSize: Qt.size(14, 14)
                                            anchors.verticalCenter: parent.verticalCenter
                                            layer.enabled: true
                                            layer.effect: MultiEffect { colorization: 1.0; colorizationColor: "#5f6368" }
                                        }
                                        Label { text: "ZONE"; color: "#5f6368"; font.pixelSize: 11; font.bold: true; font.capitalization: Font.AllUppercase }
                                    }
                                    Label {
                                        text: {
                                            var a = mapView.netArea;
                                            return a >= 1000000 ? (a/1000000).toFixed(2) + " km²" : (a > 0 ? a.toFixed(2) + " m²" : "0 m²")
                                        }
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        font.pixelSize: 16; font.bold: true; color: "#1a2744"; font.family: "Geist Sans"
                                    }
                                }
                            }

                            // --- PERIMETRO ---
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 84
                                color: "#f8fafd"; radius: 12; border.color: "#e2e8f0"; border.width: 1
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Row {
                                        spacing: 6; anchors.horizontalCenter: parent.horizontalCenter
                                        Image {
                                            source: "/qt/qml/projet_de_recherche/assets/icons/ruler_icon.svg"
                                            width: 14; height: 14
                                            sourceSize: Qt.size(14, 14)
                                            anchors.verticalCenter: parent.verticalCenter
                                            layer.enabled: true
                                            layer.effect: MultiEffect { colorization: 1.0; colorizationColor: "#5f6368" }
                                        }
                                        Label { text: "Périmètre"; color: "#5f6368"; font.pixelSize: 11; font.bold: true; font.capitalization: Font.AllUppercase }
                                    }
                                    Label {
                                        text: {
                                            var p = mapView.calculatedPerimeter;
                                            return p > 1000 ? (p/1000).toFixed(2) + " km" : p.toFixed(2) + " m"
                                        }
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        font.pixelSize: 16; font.bold: true; color: "#1a2744"; font.family: "Geist Sans"
                                    }
                                }
                            }

                            // --- DISTANCIA DE VUELO ---
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 84
                                color: "#f8fafd"; radius: 12; border.color: "#e2e8f0"; border.width: 1
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Row {
                                        spacing: 6; anchors.horizontalCenter: parent.horizontalCenter
                                        Image {
                                            source: "/qt/qml/projet_de_recherche/assets/icons/path_icon.svg"
                                            width: 14; height: 14
                                            sourceSize: Qt.size(14, 14)
                                            anchors.verticalCenter: parent.verticalCenter
                                            layer.enabled: true
                                            layer.effect: MultiEffect { colorization: 1.0; colorizationColor: "#5f6368" }
                                        }
                                        Label { text: "Distance"; color: "#5f6368"; font.pixelSize: 11; font.bold: true; font.capitalization: Font.AllUppercase }
                                    }
                                    Label {
                                        text: "0 m"
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        font.pixelSize: 16; font.bold: true; color: "#1a2744"; font.family: "Geist Sans"
                                    }
                                }
                            }

                            // --- TIEMPO ESTIMADO ---
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 84
                                color: "#f8fafd"; radius: 12; border.color: "#e2e8f0"; border.width: 1
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Row {
                                        spacing: 6; anchors.horizontalCenter: parent.horizontalCenter
                                        Image {
                                            source: "/qt/qml/projet_de_recherche/assets/icons/time_icon.svg"
                                            width: 14; height: 14
                                            sourceSize: Qt.size(14, 14)
                                            anchors.verticalCenter: parent.verticalCenter
                                            layer.enabled: true
                                            layer.effect: MultiEffect { colorization: 1.0; colorizationColor: "#5f6368" }
                                        }
                                        Label { text: "Temps Est."; color: "#5f6368"; font.pixelSize: 11; font.bold: true; font.capitalization: Font.AllUppercase }
                                    }
                                    Label {
                                        text: "0 min"
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        font.pixelSize: 16; font.bold: true; color: "#1a2744"; font.family: "Geist Sans"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
