import QtQuick
import QtQuick.Controls
import QtLocation
import QtPositioning
import QtQuick.Effects

Item {
    id: root
    //booleanos para los eventos :)
    property bool drawingMode: false
    property bool drawingRestrictions: false
    property var vertices: []

    // arreglo de arreglos con las zonas de restriccion
    property var restrictionZones: []
    // puntos de la zona actual
    property var currentRestrictionPoints: []

    // area acabada y luego se guarda
    signal areaFinished(var coordinates)

    // marcadores vertex
    property alias vertexModel: vertexModel
    property alias restrictionModel: restrictionModel

    property real calculatedArea: 0
    property real totalRestrictionArea: 0
    property real netArea: Math.max(0, calculatedArea - totalRestrictionArea)

    ListModel { id: vertexModel }

    // restrictionModel will store all points with a 'zoneIndex' to identify them
    ListModel { id: restrictionModel }

    // Models for results
    ListModel { id: internalPointsModel }
    ListModel { id: subdivisionsModel }

    property bool isProcessing: false
    property int processingStage: 0 // 0: Idle, 1: Points, 2: Subdividing, 3: Done // we still have to work on this :ssss

    property bool dragModeEnabled: false

    // muestra el poligono y los puntos // hay que trabajar en esto masss. // NOT YETTTT
    function updatePolygonPaths() {
        // Main polygon (green)
        if (vertices.length >= 3) {
            // Bridge technique for visual subtraction
            var combinedPath = [];

            // Add main outer boundary
            for (var i = 0; i < vertices.length; i++) combinedPath.push(vertices[i]);
            combinedPath.push(vertices[0]);

            // Add holes for each FINALIZED restriction zone
            for (var z = 0; z < restrictionZones.length; z++) {
                var zone = restrictionZones[z];
                if (zone.length >= 3) {
                    for (var k = 0; k < zone.length; k++) combinedPath.push(zone[k]);
                    combinedPath.push(zone[0]);
                    combinedPath.push(vertices[0]); // Return to main start point after each bridge
                }
            }

            // Add hole for CURRENT DRAWING restriction zone if it has >= 3 points
            if (currentRestrictionPoints.length >= 3) {
                for (var m = 0; m < currentRestrictionPoints.length; m++) combinedPath.push(currentRestrictionPoints[m]);
                currentRestrictionPoints[0] ? combinedPath.push(currentRestrictionPoints[0]) : null;
                combinedPath.push(vertices[0]);
            }

            drawnArea.path = combinedPath;
        } else {
            drawnArea.path = [];
        }

        // Update the visual selection (just for orange points visibility handled by MapItemView)
    }

    function finalizeCurrentRestriction() {
        if (currentRestrictionPoints.length >= 3) {
            var zones = restrictionZones;
            zones.push(currentRestrictionPoints);
            restrictionZones = zones;
            currentRestrictionPoints = [];
            recalculateTotalRestrictionArea();
            updatePolygonPaths();
        }
    }

    function recalculateTotalRestrictionArea() {
        var total = 0;
        for (var i = 0; i < restrictionZones.length; i++) {
            total += calculatePolygonArea(restrictionZones[i]);
        }
        // Add current drawing too
        total += calculatePolygonArea(currentRestrictionPoints);
        totalRestrictionArea = total;
    }

    function removeMainPoint(index) {
        var temp = vertices;
        temp.splice(index, 1);
        vertices = temp;
        vertexModel.remove(index);
        calculatedArea = calculatePolygonArea(vertices);
        updatePolygonPaths();
    }

    function removeRestrictionPoint(modelIndex) {
        // Find which zone and local index this point belongs to
        var point = restrictionModel.get(modelIndex);
        var zIdx = point.zoneIndex;

        if (zIdx === -1) { // Current drawing zone
            var current = currentRestrictionPoints;
        } else {
            var zone = restrictionZones[zIdx];
            // Find which point it is in that zone (scanning by lat/lng)
            for (var pIdx = 0; pIdx < zone.length; pIdx++) {
                if (Math.abs(zone[pIdx].latitude - point.lat) < 0.000001 &&
                    Math.abs(zone[pIdx].longitude - point.lng) < 0.000001) {
                    zone.splice(pIdx, 1);
                    break;
                }
            }

            if (zone.length < 3) {
                restrictionZones.splice(zIdx, 1);
            } else {
                restrictionZones[zIdx] = zone;
            }

            // Re-sync restrictionZones to trigger changes
            var zones = restrictionZones;
            restrictionZones = zones;
        }

        // Rebuild model and recalculate
        rebuildRestrictionModel();
        recalculateTotalRestrictionArea();
        updatePolygonPaths();
    }

    function rebuildRestrictionModel() {
        restrictionModel.clear();
        for (var z = 0; z < restrictionZones.length; z++) {
            var zone = restrictionZones[z];
            for (var p = 0; p < zone.length; p++) {
                restrictionModel.append({
                    "lat": zone[p].latitude,
                    "lng": zone[p].longitude,
                    "zoneIndex": z
                });
            }
        }
        // Add current drawing points
        for (var c = 0; c < currentRestrictionPoints.length; c++) {
            restrictionModel.append({
                "lat": currentRestrictionPoints[c].latitude,
                "lng": currentRestrictionPoints[c].longitude,
                "zoneIndex": -1
            });
        }
    }

    function pan(dx, dy) {
        map.pan(dx, dy)
    }

    function resetDrawingState() {
        errorLabel.text = ""
        root.vertices = []
        root.restrictionZones = []
        root.currentRestrictionPoints = []
        vertexModel.clear()
        restrictionModel.clear()
        root.drawingMode = true
        root.drawingRestrictions = false
        root.calculatedArea = 0
        root.totalRestrictionArea = 0
        updatePolygonPaths()
    }

    function isPointInPolygon(point, polygon) {
        var x = point.latitude, y = point.longitude;
        var inside = false;
        for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
            var xi = polygon[i].latitude, yi = polygon[i].longitude;
            var xj = polygon[j].latitude, yj = polygon[j].longitude;
            var intersect = ((yi > y) !== (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi);
            if (intersect) inside = !inside;
        }
        return inside;
    }

    function generateInternalPoints() {
        internalPointsModel.clear();
        if (vertices.length < 3) return;

        // Get bounds
        var minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
        for (var i = 0; i < vertices.length; i++) {
            minLat = Math.min(minLat, vertices[i].latitude);
            maxLat = Math.max(maxLat, vertices[i].latitude);
            minLng = Math.min(minLng, vertices[i].longitude);
            maxLng = Math.max(maxLng, vertices[i].longitude);
        }

        // Generate grid (approx 20x20 points)
        var latStep = (maxLat - minLat) / 15;
        var lngStep = (maxLng - minLng) / 15;

        for (var lat = minLat + latStep/2; lat < maxLat; lat += latStep) {
            for (var lng = minLng + lngStep/2; lng < maxLng; lng += lngStep) {
                var p = QtPositioning.coordinate(lat, lng);
                if (isPointInPolygon(p, vertices)) {
                    // Check if inside any restriction
                    var restricted = false;
                    for (var z = 0; z < restrictionZones.length; z++) {
                        if (isPointInPolygon(p, restrictionZones[z])) {
                            restricted = true;
                            break;
                        }
                    }
                    if (!restricted) {
                        internalPointsModel.append({"lat": lat, "lng": lng});
                    }
                }
            }
        }
    }

    function calculatePolygonArea(coords) {
        if (coords.length < 3) return 0;

        var area = 0;
        var R = 6378137; // Earth's radius in meters

        for (var i = 0; i < coords.length; i++) {
            var p1 = coords[i];
            var p2 = coords[(i + 1) % coords.length];

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
            PluginParameter { name: "osm.mapping.providersrepository.disabled"; value: "true" }
        }

        center: QtPositioning.coordinate(50.62925, 3.057256)
        zoomLevel: 14

        onSupportedMapTypesChanged: {
            for (var i = 0; i < supportedMapTypes.length; i++) {
                if (supportedMapTypes[i].style === MapType.StreetMap) {
                    activeMapType = supportedMapTypes[i]
                    break
                }
            }
        }

        // Map interaction fix: TapHandler with gesturePolicy
        TapHandler {
            id: mapTap
            enabled: root.drawingMode || root.drawingRestrictions
            // This policy ensures it only triggers on a discrete tap,
            // allowing the Map to handle multi-touch or drag gestures.
            gesturePolicy: TapHandler.WithinBounds
            onTapped: (eventPoint) => {
                var coord = map.toCoordinate(Qt.point(eventPoint.position.x, eventPoint.position.y))
                if (root.drawingRestrictions) {
                    root.currentRestrictionPoints = root.currentRestrictionPoints.concat([coord])
                    recalculateTotalRestrictionArea();
                } else {
                    root.vertices = root.vertices.concat([coord])
                    vertexModel.append({ "lat": coord.latitude, "lng": coord.longitude })
                    root.calculatedArea = calculatePolygonArea(root.vertices)
                }
                rebuildRestrictionModel();
                updatePolygonPaths();
            }
        }

        // Drawn area polygon (Blue)
        MapPolygon {
            id: drawnArea
            color: Qt.rgba(0.098, 0.463, 0.824, 0.25) // Blue #1976d2 with opacity
            border.color: "#1976d2"
            border.width: 2
        }

        // Vertex markers
        MapItemView {
            model: vertexModel
            delegate: MapQuickItem {
                coordinate: QtPositioning.coordinate(lat, lng)
                anchorPoint.x: 6; anchorPoint.y: 6
                sourceItem: Rectangle { width: 12; height: 12; radius: 6; color: "#1976d2"; border.color: "white"; border.width: 2 }
            }
        }

        MapItemView {
            model: restrictionModel
            delegate: MapQuickItem {
                coordinate: QtPositioning.coordinate(lat, lng)
                anchorPoint.x: 6; anchorPoint.y: 6
                sourceItem: Rectangle { width: 12; height: 12; radius: 6; color: "#d32f2f"; border.color: "white"; border.width: 2 }
            }
        }

        // DragHandler for precise manual panning when enabled
        DragHandler {
            id: dragHandler
            enabled: root.dragModeEnabled
            target: null
            onCentroidChanged: {
                if (dragHandler.active) {
                    var delta = dragHandler.translation
                    map.pan(-delta.x, -delta.y)
                }
            }
        }

        WheelHandler {
            id: wheelHandler
            target: map
            onWheel: (event) => {
                if (event.angleDelta.y > 0) map.zoomLevel = Math.min(map.zoomLevel + 0.2, map.maximumZoomLevel)
                else map.zoomLevel = Math.max(map.zoomLevel - 0.2, map.minimumZoomLevel)
            }
        }

        // Subdivisions (Rectangles)
        MapItemView {
            model: subdivisionsModel
            delegate: MapPolygon {
                path: [
                    QtPositioning.coordinate(model.lat1, model.lng1),
                    QtPositioning.coordinate(model.lat1, model.lng2),
                    QtPositioning.coordinate(model.lat2, model.lng2),
                    QtPositioning.coordinate(model.lat2, model.lng1)
                ]
                color: Qt.rgba(0.1, 0.4, 0.9, 0.1)
                border.color: "#1a237e"
                border.width: 1
            }
        }

        // Internal Points (Small dots)
        MapItemView {
            model: internalPointsModel
            delegate: MapQuickItem {
                coordinate: QtPositioning.coordinate(lat, lng)
                anchorPoint.x: 2; anchorPoint.y: 2
                sourceItem: Rectangle { width: 4; height: 4; radius: 2; color: "#4caf50"; opacity: 0.6 }
            }
        }
    }

    Timer {
        id: processTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (root.processingStage === 1) {
                root.generateInternalPoints();
                root.processingStage = 2;
                processTimer.interval = 1500;
                processTimer.start();
            } else if (root.processingStage === 2) {
                // REFINED subdivision logic: check all 4 corners
                subdivisionsModel.clear();
                if (internalPointsModel.count > 0) {
                    var offset = 0.00045; // Slightly smaller than points spacing to fit
                    for (var i = 0; i < internalPointsModel.count; i += 3) {
                        var p = internalPointsModel.get(i);
                        
                        var corners = [
                            QtPositioning.coordinate(p.lat - offset, p.lng - offset),
                            QtPositioning.coordinate(p.lat - offset, p.lng + offset),
                            QtPositioning.coordinate(p.lat + offset, p.lng + offset),
                            QtPositioning.coordinate(p.lat + offset, p.lng - offset)
                        ];

                        var valid = true;
                        // All corners must be in main polygon
                        for (var c = 0; c < 4; c++) {
                            if (!isPointInPolygon(corners[c], vertices)) {
                                valid = false; break;
                            }
                            // And NOT in any restriction
                            for (var z = 0; z < restrictionZones.length; z++) {
                                if (isPointInPolygon(corners[c], restrictionZones[z])) {
                                    valid = false; break;
                                }
                            }
                            if (!valid) break;
                        }

                        if (valid) {
                            subdivisionsModel.append({
                                "lat1": p.lat - offset, "lng1": p.lng - offset,
                                "lat2": p.lat + offset, "lng2": p.lng + offset
                            });
                        }
                    }
                }
                root.processingStage = 3;
                root.isProcessing = false;
            }
        }
    }

    function startProcessing() {
        isProcessing = true;
        processingStage = 1;
        internalPointsModel.clear();
        subdivisionsModel.clear();
        processTimer.interval = 800;
        processTimer.start();
    }

    // Navigation buttons (Up, Down, Left, Right)
    Column {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        spacing: 8

        // Cross-shaped layout for navigation
        Item {
            width: 100
            height: 100

            // UP
            Button {
                id: upBtn
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: 32; height: 32
                text: "▲"
                onClicked: root.pan(0, -50)
                font.pixelSize: 14
                background: Rectangle { 
                    radius: 16
                    color: upBtn.pressed ? "#f0f0f0" : (upBtn.hovered ? "#f8f9fc" : "white")
                    border.color: "#dde1ec"
                    border.width: 1
                }
            }

            // LEFT
            Button {
                id: leftBtn
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                width: 32; height: 32
                text: "◀"
                onClicked: root.pan(-50, 0)
                font.pixelSize: 14
                background: Rectangle { 
                    radius: 16
                    color: leftBtn.pressed ? "#f0f0f0" : (leftBtn.hovered ? "#f8f9fc" : "white")
                    border.color: "#dde1ec"
                    border.width: 1
                }
            }

            // RIGHT
            Button {
                id: rightBtn
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                width: 32; height: 32
                text: "▶"
                onClicked: root.pan(50, 0)
                font.pixelSize: 14
                background: Rectangle { 
                    radius: 16
                    color: rightBtn.pressed ? "#f0f0f0" : (rightBtn.hovered ? "#f8f9fc" : "white")
                    border.color: "#dde1ec"
                    border.width: 1
                }
            }

            // DOWN
            Button {
                id: downBtn
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: 32; height: 32
                text: "▼"
                onClicked: root.pan(0, 50)
                font.pixelSize: 14
                background: Rectangle { 
                    radius: 16
                    color: downBtn.pressed ? "#f0f0f0" : (downBtn.hovered ? "#f8f9fc" : "white")
                    border.color: "#dde1ec"
                    border.width: 1
                }
            }
        }

        // Drag Mode Toggle
        Button {
            id: dragToggleBtn
            anchors.horizontalCenter: parent.horizontalCenter
            width: 32; height: 32
            checkable: true
            checked: root.dragModeEnabled
            onToggled: root.dragModeEnabled = checked
            
            contentItem: Label {
                text: root.dragModeEnabled ? "🖐" : "🖱"
                font.pixelSize: 16
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                color: dragToggleBtn.checked ? "#1a73e8" : "#455a64"
            }
            
            background: Rectangle { 
                radius: 16
                color: dragToggleBtn.checked ? "#e8f0fe" : (dragToggleBtn.pressed ? "#f0f0f0" : "white")
                border.color: dragToggleBtn.checked ? "#1a73e8" : "#dde1ec"
                border.width: 1.5
            }
        }

        // Zoom buttons
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            Button { 
                id: zoomInBtn
                width: 32; height: 32; text: "+"; 
                onClicked: map.zoomLevel = Math.min(map.zoomLevel + 1, map.maximumZoomLevel) 
                background: Rectangle { 
                    radius: 16
                    color: zoomInBtn.pressed ? "#f0f0f0" : (zoomInBtn.hovered ? "#f8f9fc" : "white")
                    border.color: "#dde1ec"
                }
            }
            Button { 
                id: zoomOutBtn
                width: 32; height: 32; text: "−"; 
                onClicked: map.zoomLevel = Math.max(map.zoomLevel - 1, map.minimumZoomLevel) 
                background: Rectangle { 
                    radius: 16
                    color: zoomOutBtn.pressed ? "#f0f0f0" : (zoomOutBtn.hovered ? "#f8f9fc" : "white")
                    border.color: "#dde1ec"
                }
            }
        }
    }

    // Drawing controls
    Column {
        anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 16; spacing: 12

        Rectangle {
            visible: errorLabel.text.length > 0
            color: "#ccb71c1c"; radius: 4; width: errorLabel.implicitWidth + 16; height: errorLabel.implicitHeight + 10
            Label { id: errorLabel; anchors.centerIn: parent; text: ""; color: "white"; font.pixelSize: 12 }
        }

        Row {
            spacing: 12
            Button {
                id: drawBtn
                text: root.drawingMode ? qsTr("Finaliser la zone de couverture") : qsTr("Dessiner les points de couverture")


                font {
                    family: "Geist Sans"
                    pixelSize: 13
                    bold: true
                }


                leftPadding: 16
                rightPadding: 16
                topPadding: 8
                bottomPadding: 8

                contentItem: Text {
                    text: drawBtn.text
                    font: drawBtn.font
                    color: drawBtn.enabled ? "white" : "#9e9e9e"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                background: Rectangle {
                    implicitWidth: 150
                    implicitHeight: 45
                    radius: 8
                    color: !drawBtn.enabled ? "#e0e0e0" :
                            (drawBtn.pressed ? "#0d47a1" :
                            (drawBtn.hovered ? "#1976d2" : (root.drawingMode ? "#1e88e5" : "#031144")))

                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                onClicked: {
                    if (root.drawingMode) {
                        if (root.vertices.length < 3) {
                            errorLabel.text = qsTr("Au moins 3 points sont nécessaires")
                            return
                        }
                        errorLabel.text = ""
                        root.drawingMode = false
                    } else {
                        resetDrawingState() // Encapsulado para mayor limpieza
                    }
                }
            }

            Button {
                id: restrictionBtn
                visible: (root.vertices.length >= 3 && !root.drawingMode) || root.drawingRestrictions || root.restrictionZones.length > 0
                text: root.drawingRestrictions ? qsTr("Finaliser la zone de restriction") : qsTr("Dessiner les limites")
                
                font {
                    family: "Geist Sans"
                    pixelSize: 13
                    bold: true
                }

                leftPadding: 16
                rightPadding: 16
                topPadding: 8
                bottomPadding: 8

                contentItem: Text {
                    text: restrictionBtn.text
                    font: restrictionBtn.font
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                background: Rectangle {
                    implicitWidth: 150
                    implicitHeight: 45
                    radius: 8
                    color: restrictionBtn.pressed ? "#b71c1c" :
                            (restrictionBtn.hovered ? "#f44336" : 
                            (root.drawingRestrictions ? "#d32f2f" : "#e53935"))

                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                onClicked: {
                    if (root.drawingRestrictions) {
                        if (root.currentRestrictionPoints.length < 3 && root.currentRestrictionPoints.length > 0) {
                            errorLabel.text = qsTr("Au moins 3 points sont nécessaires")
                            return
                        }
                        root.finalizeCurrentRestriction()
                        errorLabel.text = ""
                        root.drawingRestrictions = false
                    } else {
                        errorLabel.text = ""
                        root.drawingRestrictions = true
                        root.drawingMode = false
                    }
                }
            }

            Button {
                id: clearBtn
                text: (root.drawingMode || root.drawingRestrictions) ? qsTr("Annuler") : qsTr("Tout effacer")
                enabled: root.vertices.length > 0 || root.drawingMode || root.drawingRestrictions
                
                font {
                    family: "Geist Sans"
                    pixelSize: 13
                    bold: true
                }

                leftPadding: 16
                rightPadding: 16
                topPadding: 8
                bottomPadding: 8

                contentItem: Text {
                    text: clearBtn.text
                    font: clearBtn.font
                    color: clearBtn.enabled ? (clearBtn.hovered ? "#d32f2f" : "#455a64") : "#9e9e9e"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                background: Rectangle {
                    implicitWidth: 100
                    implicitHeight: 45
                    radius: 8
                    color: clearBtn.pressed ? "#eceff1" : "white"
                    border.color: clearBtn.enabled ? (clearBtn.hovered ? "#d32f2f" : "#dde1ec") : "#e0e0e0"
                    border.width: 1.5

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }

                onClicked: {
                    errorLabel.text = ""
                    root.vertices = []
                    root.restrictionZones = []
                    root.currentRestrictionPoints = []
                    vertexModel.clear()
                    restrictionModel.clear()
                    root.drawingMode = false
                    root.drawingRestrictions = false
                    root.calculatedArea = 0
                    root.totalRestrictionArea = 0
                    updatePolygonPaths()
                }
            }
        }
    }

    // Drawing mode indicator (Polished Glassmorphism)
    Rectangle {
        anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; anchors.topMargin: 20
        visible: root.drawingMode || root.drawingRestrictions
        
        color: root.drawingRestrictions ? Qt.rgba(0.827, 0.184, 0.184, 0.85) : Qt.rgba(0.098, 0.463, 0.824, 0.85)
        radius: 12
        width: Math.max(hint.implicitWidth, statusLabel.implicitWidth) + 40
        height: hint.implicitHeight + statusLabel.implicitHeight + 24
        
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#30000000"
            shadowBlur: 0.1
            shadowVerticalOffset: 3
        }

        Column {
            anchors.centerIn: parent; spacing: 4
            Label { 
                id: hint
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.drawingRestrictions ? "Dessin de la zone de restriction" : "Dessin de la zone de couverture"
                color: "white"
                font.pixelSize: 14
                font.bold: true
            }
            Label { 
                id: statusLabel
                anchors.horizontalCenter: parent.horizontalCenter
                text: (root.drawingRestrictions ? root.currentRestrictionPoints.length : root.vertices.length) + " points posés"
                color: "#f0f0f0"
                font.pixelSize: 12
            }
        }

        // Animated pulse effect for drawing
        Rectangle {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: 12
            width: 10; height: 10; radius: 5; color: "white"
            OpacityAnimator on opacity {
                from: 1.0; to: 0.2; duration: 800; loops: Animation.Infinite
            }
        }
    }
}

