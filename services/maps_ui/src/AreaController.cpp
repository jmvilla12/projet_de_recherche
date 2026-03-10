#include "AreaController.h"

#include <QtMath>
#include <QtPositioning/QGeoCoordinate>

AreaController::AreaController(QObject* parent) : QObject(parent) {}

double AreaController::calculateArea(const QVariantList& vertices) {
    if (vertices.size() < 3)
        return 0.0;

    double area = 0.0;
    const double R = 6378137.0; // Earth's radius in meters

    for (int i = 0; i < vertices.size(); ++i) {
        QVariant v1 = vertices[i];
        QVariant v2 = vertices[(i + 1) % vertices.size()];

        // Check if v1 and v2 are actually coordinates
        // Assuming they are objects with latitude/longitude properties or QGeoCoordinate
        // In QML they are usually passed as objects

        double lat1 = 0, lon1 = 0, lat2 = 0, lon2 = 0;

        if (v1.canConvert<QGeoCoordinate>()) {
            QGeoCoordinate c1 = v1.value<QGeoCoordinate>();
            lat1 = qDegreesToRadians(c1.latitude());
            lon1 = qDegreesToRadians(c1.longitude());
        } else if (v1.type() == QVariant::Map) {
            QVariantMap m1 = v1.toMap();
            lat1 = qDegreesToRadians(m1["latitude"].toDouble());
            lon1 = qDegreesToRadians(m1["longitude"].toDouble());
        }

        if (v2.canConvert<QGeoCoordinate>()) {
            QGeoCoordinate c2 = v2.value<QGeoCoordinate>();
            lat2 = qDegreesToRadians(c2.latitude());
            lon2 = qDegreesToRadians(c2.longitude());
        } else if (v2.type() == QVariant::Map) {
            QVariantMap m2 = v2.toMap();
            lat2 = qDegreesToRadians(m2["latitude"].toDouble());
            lon2 = qDegreesToRadians(m2["longitude"].toDouble());
        }

        area += (lon2 - lon1) * (2 + qSin(lat1) + qSin(lat2));
    }

    return qAbs(area * R * R / 2.0);
}
