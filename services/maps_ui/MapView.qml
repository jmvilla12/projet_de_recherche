import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtLocation
import QtPositioning
import QtQuick.Effects
import PDR.Logic

Item {
    id: root
    //booleanos para los eventos :)
    property bool drawingMode: false
    property bool drawingRestrictions: false
    property var vertices: []
    property var userPosition: QtPositioning.coordinate(gpsManager.latitude, gpsManager.longitude)
    property bool isPositionValid: gpsManager.isValid
    property bool isRelocating: false
    property bool calculatingPath: false
    
    // Output from Pathfinding
    property var generatedPath: []
    property real generatedDistance: 0.0
    property real generatedTime: 0.0
    property string generatedAlgorithm: ""
    
    // Simulation properties
    property bool isSimulating: false
    property int simPointIndex: 0
    property real simInterpolation: 0.0
    property real simSpeed: 2.0

    onGeneratedPathChanged: {
        updateGeneratedPathVisuals();
    }

    function exportPathToJson(filePath) {
        return pathfindingService.savePathToJson(filePath);
    }

    function addVertexManually(lat, lng) {
        var coord = QtPositioning.coordinate(lat, lng);
        vertices = vertices.concat([coord]);
        vertexModel.append({ "lat": lat, "lng": lng });
        calculatedArea = calculatePolygonArea(vertices);
        calculatedPerimeter = calculatePerimeter(vertices);
        updatePolygonPaths();
    }

    function runSimulation() {
        pathfindingService.runVrxSimulation();
    }

    Timer {
        id: relocationTimer
        interval: 1500
        onTriggered: root.isRelocating = false
    }

    property bool waitingForFirstFix: false
    property bool isSearching: false

    Connections {
        target: gpsManager
        function onPositionChanged() {
            if (gpsManager.isValid) {
                console.log("Coordinate received: " + gpsManager.latitude + ", " + gpsManager.longitude);
                
                // If we were waiting for the first click to fix on user...
                if (root.waitingForFirstFix) {
                    map.center = QtPositioning.coordinate(gpsManager.latitude, gpsManager.longitude)
                    map.zoomLevel = 18
                    root.waitingForFirstFix = false
                    root.isSearching = false // End searching state
                    root.isRelocating = true // Start short anti-spam lock
                    relocationTimer.start()
                }
            }
        }
    }


    // arreglo de arreglos con las zonas de restriccion
    property var restrictionZones: []
    onRestrictionZonesChanged: {
        rebuildRestrictionModel();
        recalculateTotalRestrictionArea();
        updatePolygonPaths();
    }
    
    // puntos de la zona actual
    property var currentRestrictionPoints: []
    onCurrentRestrictionPointsChanged: {
        rebuildRestrictionModel();
        recalculateTotalRestrictionArea();
        updatePolygonPaths();
    }
    property string currentRestrictionName: "Nouvelle Zone"

    // area acabada y luego se guarda
    signal areaFinished(var coordinates)

    // marcadores vertex
    property alias vertexModel: vertexModel
    property alias restrictionModel: restrictionModel

    property real calculatedArea: 0
    property real totalRestrictionArea: 0
    property real netArea: Math.max(0, calculatedArea - totalRestrictionArea)
    property real calculatedPerimeter: 0

    ListModel { id: vertexModel }

    // restrictionModel will store all points with a 'zoneIndex' to identify them
    ListModel { id: restrictionModel }

    ListModel { id: dashModel }
    ListModel { id: internalPointsModel }
    ListModel { id: subdivisionsModel }

    property bool isDraggingPoint: false


    // muestra el poligono y los puntos
    function updatePolygonPaths() {
        // Main polygon (green)
        if (vertices.length >= 3) {
            var combinedPath = [];

            // Add main outer boundary
            for (var i = 0; i < vertices.length; i++) combinedPath.push(vertices[i]);
            combinedPath.push(vertices[0]);

            // Add holes for each FINALIZED restriction zone
            for (var z = 0; z < restrictionZones.length; z++) {
                var zone = restrictionZones[z];
                if (zone.points && zone.points.length >= 3) {
                    for (var k = 0; k < zone.points.length; k++) combinedPath.push(zone.points[k]);
                    combinedPath.push(zone.points[0]);
                    combinedPath.push(vertices[0]); // Return to main start point
                }
            }

            // Add hole for CURRENT DRAWING restriction zone
            if (currentRestrictionPoints.length >= 3) {
                for (var m = 0; m < currentRestrictionPoints.length; m++) combinedPath.push(currentRestrictionPoints[m]);
                combinedPath.push(currentRestrictionPoints[0]);
                combinedPath.push(vertices[0]);
            }

            drawnArea.path = combinedPath;
        } else {
            drawnArea.path = [];
        }
        updateDashedLines();
    }

    function updateDashedLines() {
        dashModel.clear();
        
        var addDashes = function(path, color) {
            if (path.length < 2) return;
            for (var i = 0; i < path.length - 1; i++) {
                var c1 = path[i];
                var c2 = path[i+1];
                
                // Calculate distance approx to determine number of dashes
                var dist = Math.sqrt(Math.pow(c2.latitude - c1.latitude, 2) + Math.pow(c2.longitude - c1.longitude, 2));
                // Even fewer segments for very large gaps (approx 1 dash per 50-60m)
                var segments = Math.max(2, Math.floor(dist * 6000)); 
                
                for (var s = 0; s < segments; s++) {
                    if (s % 2 === 0) {
                        var f1 = s / segments;
                        var f2 = Math.min(1.0, (s + 0.25) / segments); // 25% dash, 75% gap
                        dashModel.append({
                            "lat1": c1.latitude + (c2.latitude - c1.latitude) * f1,
                            "lng1": c1.longitude + (c2.longitude - c1.longitude) * f1,
                            "lat2": c1.latitude + (c2.latitude - c1.latitude) * f2,
                            "lng2": c1.longitude + (c2.longitude - c1.longitude) * f2,
                            "dashColor": color
                        });
                    }
                }
            }
        };

        if (vertices.length >= 2) {
            var mPath = [];
            for (var i = 0; i < vertices.length; i++) mPath.push(vertices[i]);
            if (vertices.length >= 3) mPath.push(vertices[0]);
            addDashes(mPath, "#00a651");
        }

        for (var z = 0; z < restrictionZones.length; z++) {
            var zone = restrictionZones[z];
            if (zone.points.length >= 2) {
                var zPath = [];
                for (var p = 0; p < zone.points.length; p++) zPath.push(zone.points[p]);
                if (zone.points.length >= 3) zPath.push(zone.points[0]);
                addDashes(zPath, "#e53935");
            }
        }

        if (currentRestrictionPoints.length >= 2) {
            var cPath = [];
            for (var cp = 0; cp < currentRestrictionPoints.length; cp++) cPath.push(currentRestrictionPoints[cp]);
            if (currentRestrictionPoints.length >= 3) cPath.push(currentRestrictionPoints[0]);
            addDashes(cPath, "#e53935");
        }
    }

    function finalizeCurrentRestriction() {
        if (currentRestrictionPoints.length >= 3) {
            var zones = restrictionZones;
            zones.push({
                points: currentRestrictionPoints,
                name: currentRestrictionName,
                reason: "Zone d'exclusion",
                color: "#e53935"
            });
            // Force property update by using a fresh array reference
            restrictionZones = zones.slice(); 
            currentRestrictionPoints = [];
            currentRestrictionName = "Nouvelle Zone";
            recalculateTotalRestrictionArea();
            rebuildRestrictionModel();
            updatePolygonPaths();
        }
    }

    function getTotalPointsBeforeZone(zoneIdx) {
        var count = 0;
        for (var i = 0; i < Math.min(zoneIdx, restrictionZones.length); i++) {
            count += restrictionZones[i].points.length;
        }
        return count;
    }

    function recalculateTotalRestrictionArea() {
        if (isDraggingPoint) return;
        var total = 0;
        for (var i = 0; i < restrictionZones.length; i++) {
            total += calculatePolygonArea(restrictionZones[i].points);
        }
        total += calculatePolygonArea(currentRestrictionPoints);
        totalRestrictionArea = total;
    }

    function removeMainPoint(index) {
        var temp = vertices;
        temp.splice(index, 1);
        vertices = temp;
        vertexModel.remove(index);
        calculatedArea = calculatePolygonArea(vertices);
        calculatedPerimeter = calculatePerimeter(vertices);
        updatePolygonPaths();
    }

    function removeRestrictionPoint(modelIndex) {
        var point = restrictionModel.get(modelIndex);
        var zIdx = point.zoneIndex;

        if (zIdx === -1) {
            var current = currentRestrictionPoints;
            for (var cIdx = 0; cIdx < current.length; cIdx++) {
                if (Math.abs(current[cIdx].latitude - point.lat) < 0.000001 &&
                    Math.abs(current[cIdx].longitude - point.lng) < 0.000001) {
                    current.splice(cIdx, 1);
                    break;
                }
            }
            currentRestrictionPoints = current;
        } else {
            var zone = restrictionZones[zIdx];
            for (var pIdx = 0; pIdx < zone.points.length; pIdx++) {
                if (Math.abs(zone.points[pIdx].latitude - point.lat) < 0.000001 &&
                    Math.abs(zone.points[pIdx].longitude - point.lng) < 0.000001) {
                    zone.points.splice(pIdx, 1);
                    break;
                }
            }

            if (zone.points.length < 3) {
                restrictionZones.splice(zIdx, 1);
            } else {
                restrictionZones[zIdx] = zone;
            }

            var zones = restrictionZones;
            restrictionZones = zones;
        }

        rebuildRestrictionModel();
        recalculateTotalRestrictionArea();
        updatePolygonPaths();
    }

    function rebuildRestrictionModel() {
        if (isDraggingPoint) return;
        restrictionModel.clear();
        for (var z = 0; z < restrictionZones.length; z++) {
            var zone = restrictionZones[z];
            for (var p = 0; p < zone.points.length; p++) {
                restrictionModel.append({
                    "lat": zone.points[p].latitude,
                    "lng": zone.points[p].longitude,
                    "zoneIndex": z,
                    "color": zone.color
                });
            }
        }
        for (var c = 0; c < currentRestrictionPoints.length; c++) {
            restrictionModel.append({
                "lat": currentRestrictionPoints[c].latitude,
                "lng": currentRestrictionPoints[c].longitude,
                "zoneIndex": -1,
                "color": "#e53935"
            });
        }
    }

    function syncPointsFromRestrictionModel() {
        var newCurr = [];
        var zns = restrictionZones;
        for (var zi = 0; zi < zns.length; zi++) zns[zi].points = [];
        
        for (var i = 0; i < restrictionModel.count; i++) {
            var m = restrictionModel.get(i);
            var c = QtPositioning.coordinate(m.lat, m.lng);
            if (m.zoneIndex === -1) newCurr.push(c);
            else zns[m.zoneIndex].points.push(c);
        }
        restrictionZones = zns;
        currentRestrictionPoints = newCurr;
        recalculateTotalRestrictionArea();
        updatePolygonPaths();
    }

    function pan(dx, dy) {
        map.pan(dx, dy)
    }

    function centerOnCurrentPosition() {
        if (!gpsManager.isValid) {
            console.log("Activating GPS search...");
            gpsManager.start();
            waitingForFirstFix = true;
            isSearching = true; // Stay disabled until fixed
        } else if (!isRelocating && !isSearching) {
            isRelocating = true
            relocationTimer.start()
            map.center = QtPositioning.coordinate(gpsManager.latitude, gpsManager.longitude);
            map.zoomLevel = 18;
            console.log("Manual re-center to: " + gpsManager.latitude + ", " + gpsManager.longitude);
        }
    }

    function resetDrawingState() {
        root.vertices = []
        root.restrictionZones = []
        root.currentRestrictionPoints = []
        root.generatedPath = []
        root.generatedDistance = 0
        root.generatedTime = 0
        root.generatedAlgorithm = ""
        vertexModel.clear()
        restrictionModel.clear()
        dashModel.clear()
        internalPointsModel.clear()
        subdivisionsModel.clear()
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

    function calculatePerimeter(coords) {
        if (coords.length < 2) return 0;
        var p = 0;
        for (var i = 0; i < coords.length; i++) {
            var c1 = coords[i];
            var c2 = coords[(i + 1) % coords.length];
            p += c1.distanceTo(c2);
        }
        return p;
    }

    Map {
        id: map
        anchors.fill: parent

        plugin: Plugin {
            name: "osm"
            PluginParameter { name: "osm.mapping.providersrepository.disabled"; value: "true" }
        }

        center: QtPositioning.coordinate(-33.724223, 150.679736)
        zoomLevel: 18

        // Robust Cross-Platform Interaction (Mouse + Touch)
        DragHandler {
            enabled: !root.drawingMode && !root.drawingRestrictions
            target: null
            onTranslationChanged: (delta) => {
                map.pan(-delta.x, -delta.y)
            }
        }

        PinchHandler {
            enabled: !root.drawingMode && !root.drawingRestrictions
            target: null
            onActiveChanged: if (active) {
                initialZoom = map.zoomLevel
            }
            onScaleChanged: {
                var delta = Math.log2(scale)
                map.zoomLevel = Math.min(Math.max(initialZoom + delta, map.minimumZoomLevel), map.maximumZoomLevel)
            }
            property real initialZoom: 16
        }

        WheelHandler {
            enabled: !root.drawingMode && !root.drawingRestrictions
            target: map
            onWheel: (event) => {
                if (event.angleDelta.y > 0) map.zoomLevel = Math.min(map.zoomLevel + 0.2, map.maximumZoomLevel)
                else map.zoomLevel = Math.max(map.zoomLevel - 0.2, map.minimumZoomLevel)
            }
        }

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
                    root.calculatedPerimeter = calculatePerimeter(root.vertices)
                }
                rebuildRestrictionModel();
                updatePolygonPaths();
            }
        }

        // Drawn area polygon (Green)
        MapPolygon {
            id: drawnArea
            color: Qt.rgba(0.0, 0.651, 0.318, 0.20) // Green #00a651 with lower opacity (0.20)
            border.width: 0 // We'll use dashed lines instead
        }

        // Dashed lines view
        MapItemView {
            model: dashModel
            delegate: MapPolyline {
                line.width: Math.max(1.5, 4.0 - (18 - map.zoomLevel) * 0.5)
                line.color: model.dashColor
                path: [
                    QtPositioning.coordinate(model.lat1, model.lng1),
                    QtPositioning.coordinate(model.lat2, model.lng2)
                ]
            }
        }

        // Vertex markers
        MapItemView {
            model: vertexModel
            delegate: MapQuickItem {
                coordinate: QtPositioning.coordinate(lat, lng)
                anchorPoint.x: 9; anchorPoint.y: 9
                
                sourceItem: Rectangle { 
                    width: 18; height: 18; radius: 9; color: "#00a651"; border.color: "white"; border.width: 1.5 
                    Label {
                        anchors.centerIn: parent
                        text: index + 1
                        font.pixelSize: 10; font.bold: true; color: "white"
                    }
                    
                    // Use MouseArea with explicit press tracking for robust dragging
                    MouseArea {
                        id: markerMA
                        anchors.fill: parent
                        onPressed: {
                            isDraggingPoint = true
                            markerMA.isDragging = true
                        }
                        onReleased: {
                            isDraggingPoint = false
                            markerMA.isDragging = false
                        }
                        property bool isDragging: false
                        onPositionChanged: (mouse) => {
                            if (isDragging) {
                                var mapPoint = markerMA.mapToItem(map, mouse.x, mouse.y);
                                var point = map.toCoordinate(mapPoint);
                                // Update real data
                                var tempV = root.vertices;
                                tempV[index] = point;
                                root.vertices = tempV;
                                // Update model for UI refresh
                                vertexModel.set(index, { "lat": point.latitude, "lng": point.longitude });
                                root.calculatedArea = calculatePolygonArea(root.vertices);
                                root.calculatedPerimeter = calculatePerimeter(root.vertices);
                                updatePolygonPaths();
                            }
                        }
                    }
                }
            }
        }

        MapItemView {
            model: restrictionModel
            delegate: MapQuickItem {
                coordinate: QtPositioning.coordinate(lat, lng)
                anchorPoint.x: 8; anchorPoint.y: 8
                sourceItem: Rectangle { 
                    width: 16; height: 16; radius: 8; color: model.color; border.color: "white"; border.width: 1.5 
                    Label {
                        anchors.centerIn: parent
                        text: index + 1
                        font.pixelSize: 9; font.bold: true; color: "white"
                    }
                    
                    MouseArea {
                        id: restrMA
                        anchors.fill: parent
                        onPressed: {
                            isDraggingPoint = true
                            restrMA.isDragging = true
                        }
                        onReleased: {
                            isDraggingPoint = false
                            restrMA.isDragging = false
                        }
                        property bool isDragging: false
                        onPositionChanged: (mouse) => {
                            if (isDragging) {
                                var mapPoint = restrMA.mapToItem(map, mouse.x, mouse.y);
                                var point = map.toCoordinate(mapPoint);
                                // Set real-time coordinates in model
                                restrictionModel.set(index, { "lat": point.latitude, "lng": point.longitude });
                                syncPointsFromRestrictionModel(); // Recalculate everything
                            }
                        }
                    }
                }
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

        // --- MARCUALADOR DE POSICION USUARIO ---
        MapQuickItem {
            id: userLocationMarker
            coordinate: root.userPosition
            visible: root.userPosition.isValid
            anchorPoint.x: 9; anchorPoint.y: 9
            z: 10 // Encima de los polígonos

            sourceItem: Rectangle {
                width: 18; height: 18; radius: 9
                color: "#1a73e8"
                border.color: "white"; border.width: 2.5
                
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true; shadowColor: "#401a73e8"; shadowBlur: 0.8; shadowVerticalOffset: 0
                }

                // Efecto de pulso suave
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width; height: parent.height; radius: parent.radius
                    color: "#1a73e8"; opacity: 0.3
                    scale: pulseAnim.scaleValue

                    SequentialAnimation on scale {
                        id: pulseAnim
                        property real scaleValue: scale
                        loops: Animation.Infinite; running: gpsManager.isValid
                        NumberAnimation { from: 1; to: 2.2; duration: 2000; easing.type: Easing.OutQuart }
                        NumberAnimation { from: 2.2; to: 1; duration: 0 }
                        PauseAnimation { duration: 500 }
                    }
                    
                    PropertyAnimation on opacity {
                        loops: Animation.Infinite; running: gpsManager.isValid
                        from: 0.4; to: 0; duration: 2000; easing.type: Easing.OutQuart
                    }
                }
            }
        }

        // Path generated by C++ — thin scan-line style, highly visible
        MapPolyline {
            id: finalPathLine
            line.width: 2.0
            line.color: "#000000" // Black for high contrast
            opacity: 0.85
            z: 19
        }

        // Start Marker (Green circle with "D"
        MapQuickItem {
            id: startMarker
            coordinate: QtPositioning.coordinate(0, 0)
            visible: root.generatedPath.length > 0
            anchorPoint.x: 13
            anchorPoint.y: 13
            z: 22
            sourceItem: Rectangle {
                width: 26; height: 26; radius: 13
                color: "#00C853"; border.color: "white"; border.width: 2.5
                layer.enabled: true
                Label {
                    anchors.centerIn: parent
                    text: "D"
                    color: "white"
                    font.bold: true
                    font.pixelSize: 12
                }
            }
        }

        // End Marker (Red cross)
        MapQuickItem {
            id: endMarker
            coordinate: QtPositioning.coordinate(0, 0)
            visible: root.generatedPath.length > 0
            anchorPoint.x: 13
            anchorPoint.y: 13
            z: 22
            sourceItem: Rectangle {
                width: 26; height: 26; radius: 13
                color: "#D50000"; border.color: "white"; border.width: 2.5
                layer.enabled: true
                Label {
                    anchors.centerIn: parent
                    text: "F"
                    color: "white"
                    font.bold: true
                    font.pixelSize: 12
                }
            }
        }

        // Simulation Marker (The "Bolita")
        MapQuickItem {
            id: simMarker
            coordinate: QtPositioning.coordinate(0, 0)
            visible: root.generatedPath.length > 0
            anchorPoint.x: 15
            anchorPoint.y: 15
            z: 30
            sourceItem: Item {
                width: 30; height: 30
                
                // Outer circle (Pulse effect)
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width; height: parent.height; radius: 15
                    color: "white"; opacity: 0.3
                    scale: root.isSimulating ? pulseAnimSim.scaleValue : 1.0

                    SequentialAnimation on scale {
                        id: pulseAnimSim
                        property real scaleValue: scale
                        loops: Animation.Infinite; running: root.isSimulating
                        NumberAnimation { from: 1; to: 1.5; duration: 1000; easing.type: Easing.OutQuart }
                        NumberAnimation { from: 1.5; to: 1; duration: 0 }
                    }
                }

                // Inner Bolita
                Rectangle {
                    anchors.centerIn: parent
                    width: 14; height: 14; radius: 7
                    color: "white"; border.color: "#333"; border.width: 2
                    
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true; shadowColor: "#40000000"; shadowBlur: 0.5
                    }

                    Image {
                        source: "/qt/qml/projet_de_recherche/assets/icons/drone_icon.svg"
                        anchors.fill: parent
                        anchors.margins: 2
                        sourceSize: Qt.size(10, 10)
                        visible: false // Use as source for colorization
                    }
                }
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
        // Automatically finalize if there's an active restriction being drawn
        if (currentRestrictionPoints.length >= 3) {
            finalizeCurrentRestriction();
        }

        // Send data to the C++ "Pathfinding Service" (Communication Layer)
        console.log("[JS] 🚀 DÉBUT DU CALCUL DE LA MEILLEURE ROUTE");
        console.log("[JS] - Points de mission: " + root.vertices.length);
        console.log("[JS] - Zones de restriction: " + root.restrictionZones.length);
        
        root.calculatingPath = true; // Start loading state
        pathfindingService.setMissionData(root.vertices, root.restrictionZones);
        pathfindingService.calculateBestRoute();
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
                    border.width: 1
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
                    border.width: 1
                }
            }
        }
    }

    // --- OVERLAY: SIMULATION CONTROLS ---
    Rectangle {
        id: simControls
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 16
        width: 260
        height: 110
        radius: 12
        color: Qt.rgba(1, 1, 1, 0.9)
        border.color: "#dde1ec"
        border.width: 1
        visible: root.generatedPath.length > 0
        z: 100

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowColor: "#20000000"; shadowBlur: 0.2; shadowVerticalOffset: 2
        }

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                width: parent.width
                spacing: 8
                
                Rectangle {
                    width: 32; height: 32; radius: 16; color: "#e6f4ea"
                    Image {
                        anchors.centerIn: parent
                        source: "/qt/qml/projet_de_recherche/assets/icons/drone_icon.svg"
                        sourceSize: Qt.size(16, 16)
                        layer.enabled: true
                        layer.effect: MultiEffect { colorization: 1.0; colorizationColor: "#00a651" }
                    }
                }

                Column {
                    spacing: 0
                    Label {
                        text: "Simulation de vol"
                        font.pixelSize: 13; font.bold: true; color: "#1a2744"
                    }
                    Label {
                        text: root.isSimulating ? "En cours..." : "Prêt pour le test"
                        font.pixelSize: 11; color: "#64748b"
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                Button {
                    id: closeSimBtn
                    width: 24; height: 24; flat: true
                    text: "×"
                    onClicked: {
                        root.isSimulating = false;
                        root.generatedPath = []; // Hide simulation by clearing path if temporary
                    }
                    contentItem: Text { text: "×"; font.pixelSize: 18; color: "#94a3b8"; horizontalAlignment: Text.AlignHCenter }
                    background: null
                }
            }

            RowLayout {
                width: parent.width
                spacing: 12

                Button {
                    id: playBtn
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    Layout.alignment: Qt.AlignVCenter
                    text: root.isSimulating ? "⏸" : "▶"
                    onClicked: root.isSimulating = !root.isSimulating
                    background: Rectangle {
                        radius: 18
                        color: root.isSimulating ? "#f8fafd" : "#00a651"
                        border.color: root.isSimulating ? "#dde1ec" : "#00a651"
                    }
                    contentItem: Text { 
                        text: root.isSimulating ? "⏸" : "▶"
                        color: root.isSimulating ? "#1a2744" : "white"
                        font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    id: stopBtn
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    Layout.alignment: Qt.AlignVCenter
                    text: "■"
                    onClicked: {
                        root.isSimulating = false
                        root.simPointIndex = 0
                        root.simInterpolation = 0.0
                        root.updateSimMarker()
                    }
                    background: Rectangle {
                        radius: 18
                        color: "white"; border.color: "#dde1ec"
                    }
                    contentItem: Text { 
                        text: "■"; color: "#e53935"; font.pixelSize: 14; 
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                }

                Column {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2
                    
                    Row {
                        width: parent.width
                        Label { text: "Vitesse: "; font.pixelSize: 10; color: "#64748b" }
                        Label { text: root.simSpeed.toFixed(1) + "x"; font.pixelSize: 10; font.bold: true; color: "#1a2744" }
                    }
                    
                    Slider {
                        id: speedSlider
                        width: parent.width
                        from: 0.5; to: 10.0
                        value: root.simSpeed
                        onValueChanged: root.simSpeed = value
                        
                        background: Rectangle {
                            x: speedSlider.leftPadding
                            y: speedSlider.topPadding + speedSlider.availableHeight / 2 - height / 2
                            implicitWidth: 200; implicitHeight: 4; width: speedSlider.availableWidth; height: implicitHeight
                            radius: 2; color: "#edf2f7"
                            Rectangle {
                                width: speedSlider.visualPosition * parent.width; height: parent.height
                                color: "#00a651"; radius: 2
                            }
                        }
                        handle: Rectangle {
                            x: speedSlider.leftPadding + speedSlider.visualPosition * (speedSlider.availableWidth - width)
                            y: speedSlider.topPadding + speedSlider.availableHeight / 2 - height / 2
                            implicitWidth: 14; implicitHeight: 14; radius: 7
                            color: "white"; border.color: "#00a651"; border.width: 2
                        }
                    }
                }
            }
        }
    }

    function updateGeneratedPathVisuals() {
        if (generatedPath.length === 0) {
            finalPathLine.path = [];
            return;
        }

        var pathCoords = [];
        for (var i = 0; i < generatedPath.length; i++) {
            pathCoords.push(QtPositioning.coordinate(generatedPath[i].latitude, generatedPath[i].longitude));
        }
        finalPathLine.path = pathCoords;

        if (pathCoords.length > 0) {
            startMarker.coordinate = pathCoords[0];
            endMarker.coordinate = pathCoords[pathCoords.length - 1];
            
            // Reset simulation when new path arrives
            root.isSimulating = false;
            root.simPointIndex = 0;
            root.simInterpolation = 0.0;
            updateSimMarker();
        }
        console.log("[JS] Itineraire affiche: " + pathCoords.length + " points.");
    }

    // Simulation logic
    Timer {
        id: simTimer
        interval: 33
        repeat: true
        running: root.isSimulating && root.generatedPath.length > 1
        onTriggered: {
            simInterpolation += 0.02 * root.simSpeed
            if (simInterpolation >= 1.0) {
                simInterpolation = 0.0
                simPointIndex++
                if (simPointIndex >= root.generatedPath.length - 1) {
                    root.isSimulating = false
                    simPointIndex = 0
                }
            }
            updateSimMarker()
        }
    }

    function updateSimMarker() {
        if (root.generatedPath.length < 2) return;
        var p1 = root.generatedPath[simPointIndex];
        var p2 = root.generatedPath[simPointIndex + 1];
        
        var lat = p1.latitude + (p2.latitude - p1.latitude) * simInterpolation;
        var lng = p1.longitude + (p2.longitude - p1.longitude) * simInterpolation;
        
        simMarker.coordinate = QtPositioning.coordinate(lat, lng);
    }

    // Pathfinding "Microservice" Connection
    PathfindingService {
        id: pathfindingService
        onPathCalculated: function(path, distance, time, bestAlgorithm) {
            console.log("[JS] Path received! Algo:", bestAlgorithm, "Dist:", distance, "Time:", time);
            console.log("-----------------------------------------");
            console.log("CHOIX OPTIMAL: " + bestAlgorithm);
            console.log("DISTANCE TOTALE: " + distance.toFixed(2) + " m");
            console.log("TEMPS ESTIMÉ: " + time.toFixed(2) + " s");
            console.log("-----------------------------------------");

            root.generatedPath = path;
            root.generatedDistance = distance;
            root.generatedTime = time;
            root.generatedAlgorithm = bestAlgorithm;
            root.calculatingPath = false; // End loading state
        }
    }
}
