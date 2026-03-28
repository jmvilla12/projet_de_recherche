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
                    text: mapView.drawingMode ? "Dessin de la mission..." :
                          (mapView.drawingRestrictions ? "Dessin de la zone de restriction..." : "Aucune zone sélectionnée")
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
                        parent: Overlay.overlay
                        width: 180; height: 50; radius: 4; color: "#333333"
                        // Position below the hover area
                        x: root.width - width - 16
                        y: 55

                        Column {
                            anchors.centerIn: parent
                            Text { text: "Créé par:"; color: "white"; font.pixelSize: 10; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                            Text { text: "Nombre de los Creadores"; color: "white"; font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter }
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
                        height: 150
                        color: "white"
                        radius: 12
                        border.color: "#edf2f7"
                        border.width: 1

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: "#08000000"
                            shadowBlur: 0.1
                            shadowVerticalOffset: 2
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 0

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Row {
                                    spacing: 8
                                    Image {
                                        source: "/qt/qml/projet_de_recherche/assets/icons/wifi_off.svg"
                                        sourceSize: Qt.size(16, 16)
                                        opacity: 0.7
                                    }
                                    Label {
                                        text: "Déconnecté"
                                        font.pixelSize: 14
                                        font.bold: false
                                        color: "#070B0F"
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                Button {
                                    id: connectBtn
                                    implicitWidth: 110
                                    implicitHeight: 30

                                    background: Rectangle {
                                        color: connectBtn.hovered ? "#e1e9f0" : "#f0f5f9"
                                        border.color: "#d1dce5"
                                        border.width: 1
                                        radius: 8
                                    }

                                    contentItem: Item {
                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 8
                                            Image {
                                                source: "/qt/qml/projet_de_recherche/assets/icons/wifi_off.svg"
                                                sourceSize: Qt.size(15, 15)
                                                opacity: 0.8
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                            Label {
                                                text: "Connecter"
                                                font.pixelSize: 13
                                                font.bold: true
                                                color: "#070B0F"
                                                anchors.verticalCenter: parent.verticalCenter
                                                font.letterSpacing: -0.2
                                            }
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }

                            Column {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignHCenter
                                spacing: 12

                                Image {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    source: "/qt/qml/projet_de_recherche/assets/icons/wifi_off.svg"
                                    sourceSize: Qt.size(32, 32)
                                    opacity: 0.1
                                }

                                Label {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Connectez votre drone pour consulter"
                                    font.pixelSize: 13
                                    color: "#5f6368"
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: "#dde1ec" }

                    // --- SECCIÓN MODO DE DIBUJO ---
                    Label {
                        text: "MODO DE DIBUJO"
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
                                    text: "Mision"
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
                                    text: "Restriccion"
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
                                text: "MISION DE VUELO"
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
                                    source: "/qt/qml/projet_de_recherche/assets/icons/sin_mision.png"
                                    sourceSize: Qt.size(48, 48)
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    opacity: 0.5
                                }
                                Label {
                                    text: "Sin mision"; font.pixelSize: 16; font.bold: true; color: "#4a5568"
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                                Label {
                                    text: "Crea una para empezar"; font.pixelSize: 13; color: "#94a3b8"
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
                                        text: "Mision Principal"
                                        font.pixelSize: 15; font.bold: true; color: "#070B0F"
                                    }
                                    Item { Layout.fillWidth: true }
                                    Rectangle {
                                        width: 80; height: 24; radius: 6; color: "#e8f0fe"
                                        Label {
                                            anchors.centerIn: parent
                                            text: "Planificando"; font.pixelSize: 11; color: "#4a5568"
                                        }
                                    }
                                }

                                Label {
                                    text: mapView.vertices.length + " vertices  -  0 waypoints"
                                    font.pixelSize: 13; color: "#5f6368"
                                }

                                Rectangle { width: parent.width; height: 1; color: "#edf2f7" }

                                Label {
                                    text: "Vertices del area (" + mapView.vertices.length + ")"
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
                                                implicitWidth: 24; implicitHeight: 24; flat: true
                                                contentItem: Label { text: "🗑"; color: "#a0aec0"; font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter }
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
                                        background: Rectangle { radius: 8; color: "#00a651" }
                                        contentItem: RowLayout {
                                            anchors.centerIn: parent; spacing: 8
                                            Label { text: "⚏"; color: "white"; font.pixelSize: 18 } // Placeholder icon
                                            Label { text: "Generar ruta"; color: "white"; font.bold: true; font.pixelSize: 15 }
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
                                                radius: 8; color: "white"; border.color: exportMisionBtn.enabled ? "#e2e8f0" : "#f1f5f9"
                                            }
                                            contentItem: RowLayout {
                                                anchors.centerIn: parent; spacing: 8
                                                Label { text: "↧"; color: exportMisionBtn.enabled ? "#4a5568" : "#94a3b8"; font.pixelSize: 18; font.bold: true }
                                                Label { text: "Exportar"; font.bold: true; color: exportMisionBtn.enabled ? "#4a5568" : "#94a3b8"; font.pixelSize: 15 }
                                            }
                                        }
                                        Button {
                                            implicitWidth: 44; implicitHeight: 44
                                            background: Rectangle { radius: 8; color: "#d32f2f" }
                                            contentItem: Label { text: "🗑"; color: "white"; font.pixelSize: 16; anchors.centerIn: parent }
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
                                text: "ZONAS DE RESTRICCION"
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
                                    Label { text: "Agregar"; color: "#1a2744"; font.pixelSize: 13; font.bold: true }
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
                                    source: "/qt/qml/projet_de_recherche/assets/icons/sin_restriccion.png"
                                    sourceSize: Qt.size(40, 40)
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    opacity: 0.5
                                }
                                Label {
                                    text: "Sin zonas de restriccion"; font.pixelSize: 15; font.bold: true; color: "#4a5568"
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
                                                                implicitWidth: 24; implicitHeight: 24; flat: true
                                                                contentItem: Label { text: "🗑"; color: "#5f6368"; font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter }
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
                                                width: parent.width; implicitHeight: 44
                                                background: Rectangle { radius: 8; color: "#d32f2f" }
                                                contentItem: RowLayout {
                                                    anchors.centerIn: parent; spacing: 8
                                                    Label { text: "🗑"; color: "white"; font.pixelSize: 16 }
                                                    Label { text: "Supprimer la zone"; color: "white"; font.bold: true; font.pixelSize: 14 }
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
                            text: "ESTADISTICAS"
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

                            // Area
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 84
                                color: "#f8fafd"; radius: 12; border.color: "#e2e8f0"; border.width: 1
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Row {
                                        spacing: 6; anchors.horizontalCenter: parent.horizontalCenter
                                        Label { text: "⚑"; color: "#5f6368"; font.pixelSize: 13 }
                                        Label { text: "Area"; color: "#5f6368"; font.pixelSize: 11; font.bold: true; font.capitalization: Font.AllUppercase }
                                    }
                                    Label {
                                        text: {
                                            var a = mapView.netArea;
                                            return a >= 1000000 ? (a/1000000).toFixed(2) + " km²" : (a > 0 ? a.toFixed(2) + " m²" : "0 m²")
                                        }
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        font.pixelSize: 16; font.bold: true; color: "#1a2744"
                                        font.family: "Geist Sans"
                                    }
                                }
                            }

                            // Perimetro
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 84
                                color: "#f8fafd"; radius: 12; border.color: "#e2e8f0"; border.width: 1
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Row {
                                        spacing: 6; anchors.horizontalCenter: parent.horizontalCenter
                                        Label { text: "📏"; color: "#5f6368"; font.pixelSize: 13 }
                                        Label { text: "Perimetro"; color: "#5f6368"; font.pixelSize: 11; font.bold: true; font.capitalization: Font.AllUppercase }
                                    }
                                    Label {
                                        text: {
                                            var p = mapView.calculatedPerimeter;
                                            return p > 1000 ? (p/1000).toFixed(2) + " km" : p.toFixed(2) + " m"
                                        }
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        font.pixelSize: 16; font.bold: true; color: "#1a2744"
                                        font.family: "Geist Sans"
                                    }
                                }
                            }

                            // Distancia de vuelo
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 84
                                color: "#f8fafd"; radius: 12; border.color: "#e2e8f0"; border.width: 1
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Row {
                                        spacing: 6; anchors.horizontalCenter: parent.horizontalCenter
                                        Label { text: "☍"; color: "#5f6368"; font.pixelSize: 13 }
                                        Label { text: "Distancia"; color: "#5f6368"; font.pixelSize: 11; font.bold: true; font.capitalization: Font.AllUppercase }
                                    }
                                    Label {
                                        text: "0 m"
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        font.pixelSize: 16; font.bold: true; color: "#1a2744"
                                        font.family: "Geist Sans"
                                    }
                                }
                            }

                            // Tiempo estimado
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 84
                                color: "#f8fafd"; radius: 12; border.color: "#e2e8f0"; border.width: 1
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Row {
                                        spacing: 6; anchors.horizontalCenter: parent.horizontalCenter
                                        Label { text: "⏱"; color: "#5f6368"; font.pixelSize: 13 }
                                        Label { text: "Tiempo Est."; color: "#5f6368"; font.pixelSize: 11; font.bold: true; font.capitalization: Font.AllUppercase }
                                    }
                                    Label {
                                        text: "0 min"
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        font.pixelSize: 16; font.bold: true; color: "#1a2744"
                                        font.family: "Geist Sans"
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
