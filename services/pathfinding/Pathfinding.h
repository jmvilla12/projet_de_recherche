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
    virtual ~Pathfinding();

    Q_INVOKABLE void setMissionData(const QVariantList& missionPoints, const QVariantList& restrictionZones);
    Q_INVOKABLE void calculateBestRoute();
    Q_INVOKABLE bool savePathToJson(const QString& filePath) const;
    Q_INVOKABLE void runVrxSimulation();

signals:
    void pathCalculated(const QVariantList& path, double distance, double time, const QString& bestAlgorithm);

private:
    QVariantList m_missionPoints;
    QVariantList m_restrictionZones;
    QVariantList m_lastPath; // cached for export
    bool m_isSimInitialized = false;

    struct GeoCoord { double lat; double lng; };
    struct Point2D  { double x;   double y;   };

    Point2D  geoToLocal (const GeoCoord& ref, const GeoCoord& point) const;
    GeoCoord localToGeo (const GeoCoord& ref, const Point2D&  point) const;

    GeoCoord       variantToGeo          (const QVariant& item) const;
    QPainterPath   buildPathFromVariantList(const QVariantList& list, const GeoCoord& ref) const;
    // Directly parse restriction zones → QList<QPolygonF> in local (unrotated) metres
    QList<QPolygonF> buildRestrictionPolygons(const GeoCoord& ref) const;

    QList<QPainterPath> subdivideSafeRegions(const QPainterPath& safeArea) const;

    double calculateDistance(const QList<GeoCoord>& path) const;
    double calculateTime(double distance, int pointsCount)  const;

    // Safe transit between disconnected segments
    bool           isLineBlocked(const QPointF& p1, const QPointF& p2, const QPainterPath& restr) const;
    QList<Point2D> findSafePath (const QPointF& p1, const QPointF& p2, const QPainterPath& restr, const QList<QPolygonF>& polys) const;

    // Grid sweep that explicitly avoids restriction polygons
    QList<GeoCoord> computeGrid(const QPainterPath&    operableArea,
                                const QList<QPolygonF>& restrPolys,
                                double angle,
                                const GeoCoord& refCoord) const;
    QList<GeoCoord> computeSubdivision(const QPainterPath&    operableArea,
                                       const QList<QPolygonF>& restrPolys,
                                       const GeoCoord& refCoord) const;
};

#endif // PATHFINDING_H
