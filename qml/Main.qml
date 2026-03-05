import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root

    width: 1280
    height: 720
    minimumWidth: 900
    minimumHeight: 600
    visible: true
    title: "Coverage Path Planner"

    header: ToolBar {
        background: Rectangle { color: "#1a2744" }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16

            Label {
                text: "Coverage Path Planner"
                font.pixelSize: 15
                font.bold: true
                color: "#e8eaf6"
                leftPadding: 4
            }

            Item { Layout.fillWidth: true }

            Label {
                text: "v0.1"
                font.pixelSize: 11
                color: "#7986cb"
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Central map area
        MapView {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        // Right panel — mission parameters and controls
        Rectangle {
            width: 280
            Layout.fillHeight: true
            color: "#f8f9fc"

            // Left border separator
            Rectangle {
                width: 1
                height: parent.height
                color: "#dde1ec"
            }

            Column {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 16
                anchors.topMargin: 20
                spacing: 12

                Label {
                    text: "Mission Controls"
                    font.pixelSize: 14
                    font.bold: true
                    color: "#1a2744"
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#dde1ec"
                }

                Label {
                    text: "(placeholder)"
                    font.pixelSize: 13
                    color: "#9ea7c4"
                }
            }
        }
    }
}
