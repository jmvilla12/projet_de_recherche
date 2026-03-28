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

    // Models for results
    ListModel { id: internalPointsModel }
    ListModel { id: subdivisionsModel }
    ListModel { id: dashModel }

    property bool isProcessing: false
    property int processingStage: 0 // 0: Idle, 1: Points, 2: Subdividing, 3: Done // we still have to work on this :ssss

    property bool dragModeEnabled: false

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

    function resetDrawingState() {
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
                        property bool isDragging: false
                        onPressed: isDragging = true
                        onReleased: isDragging = false
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
                        property bool isDragging: false
                        onPressed: isDragging = true
                        onReleased: isDragging = false
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
}
