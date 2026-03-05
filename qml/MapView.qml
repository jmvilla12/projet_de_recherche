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

    Map {
        id: map
        anchors.fill: parent

        plugin: Plugin { name: "osm" }

        // Default center: Lake Neuchâtel
        center: QtPositioning.coordinate(46.99, 6.93)
        zoomLevel: 13

        MapPolygon {
            id: drawnArea
            color: Qt.rgba(0.18, 0.55, 0.34, 0.25)
            border.color: "#2e7d32"
            border.width: 2
        }
    }

    // Intercepts taps only (not drags), so map pan/zoom still works
    TapHandler {
        enabled: root.drawingMode
        onTapped: (eventPoint) => {
            var coord = map.toCoordinate(Qt.point(eventPoint.position.x, eventPoint.position.y))
            var updated = root.vertices.concat([coord])
            root.vertices = updated
            drawnArea.path = updated
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
