#ifndef PATHFINDING_H
#define PATHFINDING_H

#include <QVariant>
#include <QVariantList>
#include <QVariantMap>
#include <QPainterPath>
#include <QPolygonF>
#include <QString>
#include <QList>
#include <QGeoCoordinate>

class Pathfinding : public QObject {
    Q_OBJECT
  public:
    explicit Pathfinding(QObject* parent = nullptr);

    // Receive mission and restriction data
    Q_INVOKABLE void setMissionData(const QVariantList& missionPoints, const QVariantList& restrictionZones);

    // Run all algorithms, compare, and emit the best path
    Q_INVOKABLE void calculateBestRoute();

signals:
    void pathCalculated(const QVariantList& path, double distance, double time, const QString& bestAlgorithm);

private:
    QVariantList m_missionPoints;
    QVariantList m_restrictionZones;

    // Geographic to Cartesian Projection helpers
    struct GeoCoord { double lat; double lng; };
    struct Point2D { double x; double y; };

    // Equirectangular projection
    Point2D geoToLocal(const GeoCoord& ref, const GeoCoord& point) const;
    GeoCoord localToGeo(const GeoCoord& ref, const Point2D& point) const;

    // Helper functions
    QPainterPath buildPathFromVariantList(const QVariantList& list, const GeoCoord& referenceCoord) const;
    QList<QPolygonF> extractPolygons(const QPainterPath& path) const;
    
    double calculateDistance(const QList<GeoCoord>& path) const;
    double calculateTime(double distance, int pointsCount) const;

    // Internal Algorithm implementations
    QList<GeoCoord> computeGrid(const QPainterPath& operableArea, const QPainterPath& restrictions, double angle, const GeoCoord& refCoord) const;
    QList<GeoCoord> computeSubdivision(const QPainterPath& operableArea, const QPainterPath& restrictions, const GeoCoord& refCoord) const;

};

#endif // PATHFINDING_H
