import QtQuick
import QtQuick.Controls
import QtLocation
import QtPositioning
import QtQuick.Effects

Item {
    id: root

    property bool drawingMode: false
    property bool drawingRestrictions: false
    property var vertices: []

    // Array of arrays - each element is a list of coordinates for one restriction zone
    property var restrictionZones: []
    // The points for the zone currently being drawn
    property var currentRestrictionPoints: []

    // Emitted when the user finishes drawing a valid polygon (>= 3 points)
    signal areaFinished(var coordinates)

    // Backing models for vertex markers
    property alias vertexModel: vertexModel
    property alias restrictionModel: restrictionModel

    property real calculatedArea: 0
    property real totalRestrictionArea: 0
    property real netArea: Math.max(0, calculatedArea - totalRestrictionArea)

    ListModel { id: vertexModel }

    // restrictionModel will store all points with a 'zoneIndex' to identify them
    ListModel { id: restrictionModel }

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
            // We need to find the local index. Since it's the last added points:
            // This is a bit tricky if we allow deleting from an active drawing.
            // Let's simplify: only allow deleting points from finalized zones or
            // the whole current zone.
            // For now, let's just find it by coordinate match or assume modelIndex logic
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

        WheelHandler {
            id: wheelHandler
            target: map
            onWheel: (event) => {
                if (event.angleDelta.y > 0) map.zoomLevel = Math.min(map.zoomLevel + 0.2, map.maximumZoomLevel)
                else map.zoomLevel = Math.max(map.zoomLevel - 0.2, map.minimumZoomLevel)
            }
        }
    }

    // Zoom buttons
    Column {
        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 16; spacing: 4
        Button { width: 36; height: 36; text: "+"; onClicked: map.zoomLevel = Math.min(map.zoomLevel + 1, map.maximumZoomLevel) }
        Button { width: 36; height: 36; text: "−"; onClicked: map.zoomLevel = Math.max(map.zoomLevel - 1, map.minimumZoomLevel) }
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
                text: root.drawingMode ? "Finaliser la zone de couverture" : "Dessiner les points de couverture"
                highlighted: root.drawingMode; font.bold: true; font.pixelSize: 13
                enabled: !root.drawingRestrictions
                background: Rectangle {
                    implicitWidth: 120; implicitHeight: 40; radius: 8
                    color: root.drawingMode ? "#1e88e5" : (drawBtn.hovered ? "#1976d2" : (drawBtn.enabled ? "#1565c0" : "#e0e0e0"))
                }
                onClicked: {
                    if (root.drawingMode) {
                        if (root.vertices.length < 3) { errorLabel.text = "Au moins 3 points sont nécessaires"; return }
                        errorLabel.text = ""; root.drawingMode = false
                    } else {
                        errorLabel.text = ""; root.vertices = []; root.restrictionZones = []; root.currentRestrictionPoints = []
                        vertexModel.clear(); restrictionModel.clear(); root.drawingMode = true; root.drawingRestrictions = false
                        root.calculatedArea = 0; root.totalRestrictionArea = 0
                    }
                }
            }

            Button {
                id: restrictionBtn
                visible: (root.vertices.length >= 3 && !root.drawingMode) || root.drawingRestrictions || root.restrictionZones.length > 0
                text: root.drawingRestrictions ? "Finaliser la zone de restriction" : "Dessiner les limites"
                highlighted: root.drawingRestrictions; font.bold: true; font.pixelSize: 13
                background: Rectangle {
                    implicitWidth: 140; implicitHeight: 40; radius: 8
                    color: root.drawingRestrictions ? "#d32f2f" : (restrictionBtn.hovered ? "#f44336" : "#e53935")
                }
                onClicked: {
                    if (root.drawingRestrictions) {
                        if (root.currentRestrictionPoints.length < 3 && root.currentRestrictionPoints.length > 0) {
                            errorLabel.text = "Au moins 3 points sont nécessaires"; return
                        }
                        root.finalizeCurrentRestriction()
                        errorLabel.text = ""; root.drawingRestrictions = false
                    } else {
                        errorLabel.text = ""; root.drawingRestrictions = true; root.drawingMode = false
                    }
                }
            }

            Button {
                id: clearBtn
                text: (root.drawingMode || root.drawingRestrictions) ? "Annuler" : "Tout effacer"
                enabled: root.vertices.length > 0 || root.drawingMode || root.drawingRestrictions
                font.bold: true; font.pixelSize: 13
                background: Rectangle {
                    implicitWidth: 100; implicitHeight: 40; radius: 8; color: "white"
                    border.color: clearBtn.enabled ? "#d32f2f" : "#e0e0e0"; border.width: 1.5
                }
                onClicked: {
                    errorLabel.text = ""; root.vertices = []; root.restrictionZones = []; root.currentRestrictionPoints = []
                    vertexModel.clear(); restrictionModel.clear(); root.drawingMode = false; root.drawingRestrictions = false
                    root.calculatedArea = 0; root.totalRestrictionArea = 0; updatePolygonPaths()
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

