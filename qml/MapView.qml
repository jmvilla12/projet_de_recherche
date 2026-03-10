import QtQuick
import QtQuick.Controls
import QtLocation
import QtPositioning

Item {
    id: root

    property bool drawingMode: false
    property bool drawingRestrictions: false
    property var vertices: []
    property var restrictionVertices: []

    // Emitted when the user finishes drawing a valid polygon (>= 3 points)
    signal areaFinished(var coordinates)

    // Backing models for vertex markers
    property alias vertexModel: vertexModel
    property alias restrictionModel: restrictionModel
    property real calculatedArea: 0
    property real restrictionArea: 0
    property real netArea: Math.max(0, calculatedArea - restrictionArea)

    ListModel { id: vertexModel }
    ListModel { id: restrictionModel }

    function updatePolygonPaths() {
        // Main polygon (green)
        if (vertices.length >= 3) {
            if (restrictionVertices.length >= 3) {
                // Bridge technique: Combine paths to create a hole
                // Main path (P1, P2... Pn, P1) -> Restriction path (R1, R2... Rn, R1) -> Return to P1
                var combinedPath = [];
                for (var i = 0; i < vertices.length; i++) combinedPath.push(vertices[i]);
                combinedPath.push(vertices[0]); 
                for (var j = 0; j < restrictionVertices.length; j++) combinedPath.push(restrictionVertices[j]);
                combinedPath.push(restrictionVertices[0]);
                combinedPath.push(vertices[0]);
                drawnArea.path = combinedPath;
            } else {
                drawnArea.path = vertices;
            }
        } else {
            drawnArea.path = [];
        }
        
        // Restriction polygon (orange) - always show it for clarity
        //restrictionPolygon.path = restrictionVertices; It's commented to avoid the filling :)
    }

    function removeMainPoint(index) {
        var temp = vertices;
        temp.splice(index, 1);
        vertices = temp;
        vertexModel.remove(index);
        calculatedArea = calculatePolygonArea(vertices);
        updatePolygonPaths();
    }

    function removeRestrictionPoint(index) {
        var temp = restrictionVertices;
        temp.splice(index, 1);
        restrictionVertices = temp;
        restrictionModel.remove(index);
        restrictionArea = calculatePolygonArea(restrictionVertices);
        updatePolygonPaths();
    }

    function calculatePolygonArea(coords) {
        if (coords.length < 3) return 0;
        
        var area = 0;
        var R = 6378137; // Earth's radius in meters
        
        for (var i = 0; i < coords.length; i++) {
            var p1 = coords[i];
            var p2 = coords[(i + 1) % coords.length];
            
            // Convert to radians
            var lat1 = p1.latitude * Math.PI / 180;
            var lon1 = p1.longitude * Math.PI / 180;
            var lat2 = p2.latitude * Math.PI / 180;
            var lon2 = p2.longitude * Math.PI / 180;
            
            area += (lon2 - lon1) * (2 + Math.sin(lat1) + Math.sin(lat2));
        }
        
        area = Math.abs(area * R * R / 2.0);
        return area;
    }

    Map {
        id: map
        anchors.fill: parent

        plugin: Plugin {
            name: "osm"
            // Disable provider repository so Qt doesn't fetch API-key providers
            PluginParameter { name: "osm.mapping.providersrepository.disabled"; value: "true" }
        }

        // Default center: Lille, France
        center: QtPositioning.coordinate(50.62925, 3.057256)
        zoomLevel: 14

        // Force StreetMap type (OSM, no API key) once supported types are loaded
        onSupportedMapTypesChanged: {
            for (var i = 0; i < supportedMapTypes.length; i++) {
                if (supportedMapTypes[i].style === MapType.StreetMap) {
                    activeMapType = supportedMapTypes[i]
                    break
                }
            }
        }

        // Drawn area polygon (Green)
        MapPolygon {
            id: drawnArea
            color: Qt.rgba(0.18, 0.55, 0.34, 0.25)
            border.color: "#2e7d32"
            border.width: 2
        }

        // Restriction area polygon (Orange)
        MapPolygon {
            id: restrictionPolygon
            color: Qt.rgba(1.0, 0.55, 0.0, 0.2) // Lighter for "hole" feel
            border.color: "#ef6c00"
            border.width: 1
        }

        // Main vertex markers (Green)
        MapItemView {
            model: vertexModel
            delegate: MapQuickItem {
                coordinate: QtPositioning.coordinate(lat, lng)
                anchorPoint.x: dot.width / 2
                anchorPoint.y: dot.height / 2
                sourceItem: Rectangle {
                    id: dot
                    width: 12
                    height: 12
                    radius: 7
                    color: "#2e7d32"
                    border.color: "white"
                    border.width: 2
                }
            }
        }

        // Restriction vertex markers (Orange)
        MapItemView {
            model: restrictionModel
            delegate: MapQuickItem {
                coordinate: QtPositioning.coordinate(lat, lng)
                anchorPoint.x: rdot.width / 2
                anchorPoint.y: rdot.height / 2
                sourceItem: Rectangle {
                    id: rdot
                    width: 12
                    height: 12
                    radius: 7
                    color: "#ef6c00"
                    border.color: "white"
                    border.width: 2
                }
            }
        }

        // TapHandler inside Map
        TapHandler {
            id: mapTap
            enabled: root.drawingMode || root.drawingRestrictions
            onTapped: (eventPoint) => {
                var coord = map.toCoordinate(Qt.point(eventPoint.position.x, eventPoint.position.y))
                if (root.drawingRestrictions) {
                    root.restrictionVertices = root.restrictionVertices.concat([coord])
                    restrictionModel.append({ "lat": coord.latitude, "lng": coord.longitude })
                    root.restrictionArea = calculatePolygonArea(root.restrictionVertices)
                } else {
                    root.vertices = root.vertices.concat([coord])
                    vertexModel.append({ "lat": coord.latitude, "lng": coord.longitude })
                    root.calculatedArea = calculatePolygonArea(root.vertices)
                }
                updatePolygonPaths();
            }
        }

        // Standard zoom with mouse wheel
        WheelHandler {
            id: wheelHandler
            target: map
            onWheel: (event) => {
                if (event.angleDelta.y > 0)
                    map.zoomLevel = Math.min(map.zoomLevel + 0.2, map.maximumZoomLevel)
                else
                    map.zoomLevel = Math.max(map.zoomLevel - 0.2, map.minimumZoomLevel)
            }
        }
    }

    // Zoom buttons (scroll wheel also works natively)
    Column {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16
        spacing: 4

        Button {
            width: 36
            height: 36
            text: "+"
            onClicked: map.zoomLevel = Math.min(map.zoomLevel + 1, map.maximumZoomLevel)
        }
        Button {
            width: 36
            height: 36
            text: "−"
            onClicked: map.zoomLevel = Math.max(map.zoomLevel - 1, map.minimumZoomLevel)
        }
    }

    // Drawing controls (bottom-left)
    Column {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 16
        spacing: 12

        // Error feedback
        Rectangle {
            visible: errorLabel.text.length > 0
            color: "#ccb71c1c"
            radius: 4
            width: errorLabel.implicitWidth + 16
            height: errorLabel.implicitHeight + 10

            Label {
                id: errorLabel
                anchors.centerIn: parent
                text: ""
                color: "white"
                font.pixelSize: 12
            }
        }

        Row {
            spacing: 12

            Button {
                id: drawBtn
                text: root.drawingMode ? "Terminar Área" : "Dibujar Área"
                highlighted: root.drawingMode
                font.bold: true
                font.pixelSize: 13
                enabled: !root.drawingRestrictions
                
                contentItem: Label {
                    text: drawBtn.text
                    font: drawBtn.font
                    color: drawBtn.enabled ? "white" : "#9e9e9e"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    implicitWidth: 120
                    implicitHeight: 40
                    radius: 8
                    color: root.drawingMode ? "#1e88e5" : (drawBtn.hovered ? "#43a047" : (drawBtn.enabled ? "#2e7d32" : "#e0e0e0"))
                    
                    layer.enabled: true
                    layer.effect: Qt.createQmlObject("import Qt5Compat.GraphicalEffects; DropShadow { blur: 8; color: '#40000000'; verticalOffset: 2 }", parent)
                }

                onClicked: {
                    if (root.drawingMode) {
                        if (root.vertices.length < 3) {
                            errorLabel.text = "Se necesitan al menos 3 puntos"
                            return
                        }
                        errorLabel.text = ""
                        root.drawingMode = false
                    } else {
                        errorLabel.text = ""
                        root.vertices = []
                        root.restrictionVertices = []
                        vertexModel.clear()
                        restrictionModel.clear()
                        root.drawingMode = true
                        root.drawingRestrictions = false
                        root.calculatedArea = 0
                        root.restrictionArea = 0
                    }
                }
            }

            Button {
                id: restrictionBtn
                visible: root.drawingMode || root.drawingRestrictions || root.restrictionVertices.length > 0
                text: root.drawingRestrictions ? "Terminar Limitantes" : "Dibujar Limitantes"
                highlighted: root.drawingRestrictions
                font.bold: true
                font.pixelSize: 13
                
                contentItem: Label {
                    text: restrictionBtn.text
                    font: restrictionBtn.font
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    implicitWidth: 140
                    implicitHeight: 40
                    radius: 8
                    color: root.drawingRestrictions ? "#ef6c00" : (restrictionBtn.hovered ? "#ffa726" : "#fb8c00")
                    
                    layer.enabled: true
                    layer.effect: Qt.createQmlObject("import Qt5Compat.GraphicalEffects; DropShadow { blur: 8; color: '#40000000'; verticalOffset: 2 }", parent)
                }

                onClicked: {
                    if (root.drawingRestrictions) {
                        if (root.restrictionVertices.length < 3 && root.restrictionVertices.length > 0) {
                            errorLabel.text = "Se necesitan al menos 3 puntos para la restricción"
                            return
                        }
                        errorLabel.text = ""
                        root.drawingRestrictions = false
                    } else {
                        errorLabel.text = ""
                        root.drawingRestrictions = true
                        root.drawingMode = false
                    }
                }
            }

            // Clears polygon or cancels drawing in progress
            Button {
                id: clearBtn
                text: (root.drawingMode || root.drawingRestrictions) ? "Cancelar" : "Limpiar"
                enabled: root.vertices.length > 0 || root.drawingMode || root.drawingRestrictions
                font.bold: true
                font.pixelSize: 13

                contentItem: Label {
                    text: clearBtn.text
                    font: clearBtn.font
                    color: clearBtn.enabled ? "#d32f2f" : "#9e9e9e"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    implicitWidth: 100
                    implicitHeight: 40
                    radius: 8
                    color: "white"
                    border.color: clearBtn.enabled ? "#d32f2f" : "#e0e0e0"
                    border.width: 1.5
                    opacity: clearBtn.pressed ? 0.7 : 1.0
                }

                onClicked: {
                    errorLabel.text = ""
                    root.vertices = []
                    root.restrictionVertices = []
                    vertexModel.clear()
                    restrictionModel.clear()
                    root.drawingMode = false
                    root.drawingRestrictions = false
                    root.calculatedArea = 0
                    root.restrictionArea = 0
                    updatePolygonPaths()
                }
            }
        }
    }

    // Drawing mode indicator
    Rectangle {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 12
        visible: root.drawingMode || root.drawingRestrictions
        color: root.drawingRestrictions ? "#ddfb8c00" : "#dd1565a8"
        radius: 6
        width: hint.implicitWidth + 24
        height: hint.implicitHeight + statusLabel.implicitHeight + 20

        Column {
            anchors.centerIn: parent
            spacing: 2

            Label {
                id: hint
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.drawingRestrictions ? "Dibujando Zona de Restricción" : "Dibujando Área de Cobertura"
                color: "white"
                font.pixelSize: 13
            }

            Label {
                id: statusLabel
                anchors.horizontalCenter: parent.horizontalCenter
                text: (root.drawingRestrictions ? root.restrictionVertices.length : root.vertices.length) + " puntos"
                color: "#ccffffff"
                font.pixelSize: 12
            }
        }
    }
}
