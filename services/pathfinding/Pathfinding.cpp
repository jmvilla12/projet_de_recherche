#include "Pathfinding.h"
#include <QDebug>
#include <QtMath>
#include <QVariantMap>
#include <QString>

const double SWEEP_WIDTH = 1.2; // Reduced for small area testing
const double DRONE_SPEED = 5.0;
const double TURN_PENALTY = 2.0;

Pathfinding::Pathfinding(QObject* parent) : QObject(parent) {}

void Pathfinding::setMissionData(const QVariantList& missionPoints, const QVariantList& restrictionZones) {
    m_missionPoints = missionPoints;
    m_restrictionZones = restrictionZones;
    qDebug() << "[Pathfinding] Received" << missionPoints.size() << "mission points and" << m_restrictionZones.size() << "restriction zones.";
}

// Coordinate Translation
Pathfinding::Point2D Pathfinding::geoToLocal(const GeoCoord& ref, const GeoCoord& point) const {
    double x = (point.lng - ref.lng) * qCos(qDegreesToRadians(ref.lat)) * 111320.0;
    double y = (point.lat - ref.lat) * 110574.0;
    return {x, y};
}

Pathfinding::GeoCoord Pathfinding::localToGeo(const GeoCoord& ref, const Point2D& point) const {
    double lng = ref.lng + point.x / (qCos(qDegreesToRadians(ref.lat)) * 111320.0);
    double lat = ref.lat + point.y / 110574.0;
    return {lat, lng};
}

// Convert JSON coords to QPainterPath in meters
QPainterPath Pathfinding::buildPathFromVariantList(const QVariantList& list, const GeoCoord& referenceCoord) const {
    QPainterPath path;
    if (list.isEmpty()) return path;

    for (int i = 0; i < list.size(); ++i) {
        QVariant item = list[i];
        GeoCoord geo = {0, 0};

        if (item.canConvert<QGeoCoordinate>()) {
            QGeoCoordinate coord = item.value<QGeoCoordinate>();
            geo = {coord.latitude(), coord.longitude()};
        } else {
            QVariantMap pointMap = item.value<QVariantMap>();
            // Check if the structure is nested (like restrictionZones)
            if (pointMap.contains("points")) {
                QVariantList sublist = pointMap["points"].toList();
                if(!sublist.isEmpty()) {
                    QPainterPath subPath = buildPathFromVariantList(sublist, referenceCoord);
                    path.addPath(subPath);
                }
                continue;
            }

            geo = {pointMap.contains("latitude") ? pointMap["latitude"].toDouble() : pointMap["lat"].toDouble(),
                   pointMap.contains("longitude") ? pointMap["longitude"].toDouble() : pointMap["lng"].toDouble()};
        }

        Point2D local = geoToLocal(referenceCoord, geo);
        
        if (i == 0) path.moveTo(local.x, local.y);
        else path.lineTo(local.x, local.y);
    }
    // Only close if it's a simple list of points
    if (!list.first().value<QVariantMap>().contains("points")) {
        path.closeSubpath();
    }
    return path;
}

double Pathfinding::calculateDistance(const QList<GeoCoord>& path) const {
    if (path.size() < 2) return 0.0;
    double dist = 0.0;
    for (int i = 0; i < path.size() - 1; ++i) {
        // approximate distance in meters
        Point2D p1 = geoToLocal(path[i], path[i]);
        Point2D p2 = geoToLocal(path[i], path[i+1]);
        dist += qSqrt(p2.x*p2.x + p2.y*p2.y);
    }
    return dist;
}

double Pathfinding::calculateTime(double distance, int pointsCount) const {
    int turns = qMax(0, pointsCount - 2);
    return (distance / DRONE_SPEED) + (turns * TURN_PENALTY);
}


// Algorithm 2: Sweep Grid (Horizontal/Vertical)
QList<Pathfinding::GeoCoord> Pathfinding::computeGrid(const QPainterPath& operableArea, const QPainterPath& restrictions, double angle, const GeoCoord& refCoord) const {
    QList<GeoCoord> resultPath;
    
    QPainterPath safeArea = operableArea.subtracted(restrictions);
    if (safeArea.isEmpty()) return resultPath;

    // Rotate area to easily do a simple horizontal sweep
    QTransform transform;
    transform.rotate(angle);
    QPainterPath rotatedArea = transform.map(safeArea);
    
    QRectF bounds = rotatedArea.boundingRect();
    QList<QPolygonF> polys = rotatedArea.toFillPolygons(); // Must use rotated polygons
    if (polys.isEmpty()) return resultPath;

    double y = bounds.top() + SWEEP_WIDTH / 2.0;
    bool leftToRight = true;
    QTransform unrotate = transform.inverted();

    while (y <= bounds.bottom()) {
        QList<double> xIntersections;
        
        // Manual line-polygon intersection for robustness
        for (const QPolygonF& poly : polys) {
            for (int i = 0; i < poly.size() - 1; ++i) {
                QPointF p1 = poly[i];
                QPointF p2 = poly[i+1];
                
                // Check if line y intersects segment p1-p2
                if ((p1.y() <= y && p2.y() > y) || (p2.y() <= y && p1.y() > y)) {
                    double x = p1.x() + (y - p1.y()) * (p2.x() - p1.x()) / (p2.y() - p1.y());
                    xIntersections.append(x);
                }
            }
        }
        
        std::sort(xIntersections.begin(), xIntersections.end());

        // Create segments from pairs of intersections
        for (int i = 0; i + 1 < xIntersections.size(); i += 2) {
            double x1 = xIntersections[i];
            double x2 = xIntersections[i+1];
            
            QPointF lp1(x1, y);
            QPointF lp2(x2, y);
            
            QPointF unrotatedP1 = unrotate.map(lp1);
            QPointF unrotatedP2 = unrotate.map(lp2);

            if (leftToRight) {
                resultPath.append(localToGeo(refCoord, {unrotatedP1.x(), unrotatedP1.y()}));
                resultPath.append(localToGeo(refCoord, {unrotatedP2.x(), unrotatedP2.y()}));
            } else {
                resultPath.append(localToGeo(refCoord, {unrotatedP2.x(), unrotatedP2.y()}));
                resultPath.append(localToGeo(refCoord, {unrotatedP1.x(), unrotatedP1.y()}));
            }
        }

        y += SWEEP_WIDTH;
        leftToRight = !leftToRight;
    }

    return resultPath;
}

// Pseudo versions for Subdiv for this prototype
QList<Pathfinding::GeoCoord> Pathfinding::computeSubdivision(const QPainterPath& operableArea, const QPainterPath& restrictions, const GeoCoord& refCoord) const {
    return computeGrid(operableArea, restrictions, 90.0, refCoord); // Fallback
}

// Main execution
void Pathfinding::calculateBestRoute() {
    if (m_missionPoints.size() < 3) return;

    qDebug() << "[Pathfinding] Running C++ translation algorithms...";

    // Coordinate Projection Stage
    qDebug() << "[1/5] Conversion des coordonnées GPS vers repère local...";
    
    QVariant firstVal = m_missionPoints.first();
    GeoCoord refCoord;
    if (firstVal.canConvert<QGeoCoordinate>()) {
        QGeoCoordinate c = firstVal.value<QGeoCoordinate>();
        refCoord = {c.latitude(), c.longitude()};
    } else {
        QVariantMap firstPt = firstVal.value<QVariantMap>();
        refCoord = {firstPt.contains("latitude") ? firstPt["latitude"].toDouble() : firstPt["lat"].toDouble(),
                    firstPt.contains("longitude") ? firstPt["longitude"].toDouble() : firstPt["lng"].toDouble()};
    }

    QPainterPath operableArea = buildPathFromVariantList(m_missionPoints, refCoord);
    QPainterPath restrictions = buildPathFromVariantList(m_restrictionZones, refCoord);
    qDebug() << "      Surface opérationnelle et zones d'exclusion prêtes.";

    // Algorithm Execution Stage
    qDebug() << "[2/5] Lancement des algorithmes de couverture...";
    struct Result { QString name; QList<GeoCoord> path; double dist; double time; };
    QList<Result> results;

    auto evaluate = [&](const QString& name, const QList<GeoCoord>& path) {
        qDebug() << "      Calcul terminé para :" << name << "(" << path.size() << "points )";
        double dist = calculateDistance(path);
        double time = calculateTime(dist, path.size());
        if (dist > 1.0) results.append({name, path, dist, time});
    };

    qDebug() << "      -> Calcul Grid Horizontal...";
    evaluate("Grille Horizontale", computeGrid(operableArea, restrictions, 0.0, refCoord));
    
    qDebug() << "      -> Calcul Grid Vertical...";
    evaluate("Grille Verticale", computeGrid(operableArea, restrictions, 90.0, refCoord));
    
    qDebug() << "      -> Calcul Grid Diagonal...";
    evaluate("Grille Diagonale", computeGrid(operableArea, restrictions, 45.0, refCoord));
    
    // Perimeter removed as per user request - not a valid coverage method

    // Decision Stage
    qDebug() << "[3/5] Évaluation de l'efficacité (Distance vs Temps)...";
    if (results.isEmpty()) {
        qDebug() << "(!) Erreur : Aucun itinéraire n'a pu être généré.";
        return;
    }

    // Find best (lowest time for now)
    Result best = results.first();
    for (const Result& r : results) {
        if (r.time < best.time) best = r;
    }

    qDebug() << "=========================================";
    qDebug() << "   RÉSULTAT DE LA PLANIFICATION (C++)   ";
    qDebug() << "=========================================";
    qDebug() << "ALGORITHME CHOISI :" << best.name;
    qDebug() << "DISTANCE TOTALE   :" << QString::number(best.dist, 'f', 2) << "m";
    qDebug() << "TEMPS ESTIMÉ      :" << QString::number(best.time, 'f', 2) << "s";
    qDebug() << "NOMBRE DE POINTS  :" << best.path.size();
    qDebug() << "=========================================";

    // Final Stage
    qDebug() << "[4/5] Préparation des points pour l'interface UI...";

    // Convert back to QVariantList format for the QML map
    QVariantList pathData;
    for (const GeoCoord& point : best.path) {
        // Needs to match the model of MapPolyline coordinate
        QVariantMap pm;
        pm["latitude"] = point.lat;
        pm["longitude"] = point.lng;
        pathData.append(pm);
    }

    qDebug() << "[5/5] Envoi des données au microservice Maps UI.";
    emit pathCalculated(pathData, best.dist, best.time, best.name);
}
