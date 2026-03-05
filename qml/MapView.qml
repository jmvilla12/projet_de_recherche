import QtQuick
import QtQuick.Controls
import QtLocation
import QtPositioning

Item {
    id: root

    property bool drawingMode: false
    property var vertices: []

    // Emitted when the user finishes drawing a valid polygon (>= 3 points)
    signal areaFinished(var coordinates)

    // Backing model for vertex markers — kept in sync with vertices array
    ListModel { id: vertexModel }

    Map {
        id: map
        anchors.fill: parent

        plugin: Plugin {
            name: "osm"
            // Disable provider repository so Qt doesn't fetch API-key providers
            PluginParameter { name: "osm.mapping.providersrepository.disabled"; value: "true" }
        }

        // Default center: Lake Neuchâtel
        center: QtPositioning.coordinate(46.99, 6.93)
        zoomLevel: 13

        // Force StreetMap type (OSM, no API key) once supported types are loaded
        onSupportedMapTypesChanged: {
            for (var i = 0; i < supportedMapTypes.length; i++) {
                if (supportedMapTypes[i].style === MapType.StreetMap) {
                    activeMapType = supportedMapTypes[i]
                    break
                }
            }
        }

        // Drawn area polygon
        MapPolygon {
            id: drawnArea
            color: Qt.rgba(0.18, 0.55, 0.34, 0.25)
            border.color: "#2e7d32"
            border.width: 2
        }

        // Vertex markers — fixed pixel size using MapQuickItem
        MapItemView {
            model: vertexModel
            delegate: MapQuickItem {
                coordinate: QtPositioning.coordinate(lat, lng)
                anchorPoint.x: dot.width / 2
                anchorPoint.y: dot.height / 2
                sourceItem: Rectangle {
                    id: dot
                    width: 16
                    height: 16
                    radius: 8
                    color: "#2e7d32"
                    border.color: "white"
                    border.width: 2
                }
            }
        }

        // TapHandler inside Map so drag events reach Map's pan gesture recognizer
        TapHandler {
            enabled: root.drawingMode
            onTapped: (eventPoint) => {
                var coord = map.toCoordinate(Qt.point(eventPoint.position.x, eventPoint.position.y))
                root.vertices = root.vertices.concat([coord])
                drawnArea.path = root.vertices
                vertexModel.append({ "lat": coord.latitude, "lng": coord.longitude })
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
        spacing: 6

        // Error feedback — shown when finish is attempted with < 3 points
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
            spacing: 8

            Button {
                text: root.drawingMode ? "Finish Area" : "Draw Area"
                highlighted: root.drawingMode
                onClicked: {
                    if (root.drawingMode) {
                        if (root.vertices.length < 3) {
                            errorLabel.text = "Need at least 3 points to close a polygon"
                            return
                        }
                        errorLabel.text = ""
                        root.drawingMode = false
                        root.areaFinished(root.vertices)
                    } else {
                        errorLabel.text = ""
                        root.vertices = []
                        drawnArea.path = []
                        vertexModel.clear()
                        root.drawingMode = true
                    }
                }
            }

            // Clears polygon or cancels drawing in progress
            Button {
                text: root.drawingMode ? "Cancel" : "Clear"
                enabled: root.vertices.length > 0 || root.drawingMode
                onClicked: {
                    errorLabel.text = ""
                    root.vertices = []
                    drawnArea.path = []
                    vertexModel.clear()
                    root.drawingMode = false
                }
            }
        }
    }

    // Drawing mode indicator (top center banner)
    Rectangle {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 12
        visible: root.drawingMode
        color: "#dd1565a8"
        radius: 6
        width: hint.implicitWidth + 24
        height: hint.implicitHeight + statusLabel.implicitHeight + 20

        Column {
            anchors.centerIn: parent
            spacing: 2

            Label {
                id: hint
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Click to add points — press Finish Area when done"
                color: "white"
                font.pixelSize: 13
            }

            Label {
                id: statusLabel
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.vertices.length + " point" + (root.vertices.length === 1 ? "" : "s")
                color: "#ccffffff"
                font.pixelSize: 12
            }
        }
    }
}
