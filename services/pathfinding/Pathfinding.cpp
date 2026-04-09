#include "Pathfinding.h"
#include <QDebug>
#include <QtMath>
#include <QVariantMap>
#include <QString>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QFile>
#include <QUrl>
#include <QQueue>
#include <QHash>

const double SWEEP_WIDTH = 3; // Increased spacing for visibility during testing, can be reduced to 1.2 later
const double DRONE_SPEED = 5.0;
const double TURN_PENALTY = 2.0;

Pathfinding::Pathfinding(QObject* parent) : QObject(parent) {}

void Pathfinding::setMissionData(const QVariantList& missionPoints, const QVariantList& restrictionZones) {
    m_missionPoints = missionPoints;
    m_restrictionZones = restrictionZones;
    qDebug() << "[Pathfinding] Données reçues: " << missionPoints.size() << "points mission," << restrictionZones.size() << "zones restriction.";
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

// Helper to extract GeoCoord from various QVariant types
Pathfinding::GeoCoord Pathfinding::variantToGeo(const QVariant& item) const {
    if (item.canConvert<QGeoCoordinate>()) {
        QGeoCoordinate coord = item.value<QGeoCoordinate>();
        return {coord.latitude(), coord.longitude()};
    } else if (item.userType() == QMetaType::QVariantMap || item.canConvert<QVariantMap>()) {
        QVariantMap map = item.toMap();
        double lat = map.contains("latitude") ? map["latitude"].toDouble() : (map.contains("lat") ? map["lat"].toDouble() : 0.0);
        double lng = map.contains("longitude") ? map["longitude"].toDouble() : (map.contains("lng") ? map["lng"].toDouble() : 0.0);
        return {lat, lng};
    }
    return {0, 0};
}

// Convert JSON coords to QPainterPath in meters
QPainterPath Pathfinding::buildPathFromVariantList(const QVariantList& list, const GeoCoord& referenceCoord) const {
    QPainterPath path;
    path.setFillRule(Qt::WindingFill);
    
    if (list.isEmpty()) return path;

    QVariant first = list.at(0);
    bool isNested = false;
    if (first.canConvert<QVariantMap>()) {
        QVariantMap m = first.toMap();
        if (m.contains("points")) isNested = true;
    }

    if (isNested) {
        for (const QVariant& zoneVar : list) {
            QVariantList sublist = zoneVar.toMap()["points"].toList();
            if (sublist.isEmpty()) continue;
            
            QPainterPath subPolygon;
            for (int i = 0; i < sublist.size(); ++i) {
                GeoCoord geo = variantToGeo(sublist.at(i));
                Point2D local = geoToLocal(referenceCoord, geo);
                if (i == 0) subPolygon.moveTo(local.x, local.y);
                else subPolygon.lineTo(local.x, local.y);
            }
            subPolygon.closeSubpath();
            path.addPath(subPolygon);
        }
    } else {
        for (int i = 0; i < list.size(); ++i) {
            GeoCoord geo = variantToGeo(list.at(i));
            Point2D local = geoToLocal(referenceCoord, geo);
            if (i == 0) path.moveTo(local.x, local.y);
            else path.lineTo(local.x, local.y);
        }
        path.closeSubpath();
    }
    return path;
}

QList<QPolygonF> Pathfinding::buildRestrictionPolygons(const GeoCoord& ref) const {
    QList<QPolygonF> polys;
    for (const QVariant& zoneVar : m_restrictionZones) {
        QVariantMap zoneMap = zoneVar.toMap();
        QVariantList points = zoneMap["points"].toList();
        if (points.isEmpty()) continue;

        QPolygonF poly;
        for (const QVariant& pVar : points) {
            GeoCoord geo = variantToGeo(pVar);
            Point2D local = geoToLocal(ref, geo);
            poly << QPointF(local.x, local.y);
        }
        if (!poly.isEmpty()) polys << poly;
    }
    qDebug() << "[Pathfinding] Built" << polys.size() << "explicit restriction polygons.";
    return polys;
}

QList<QPainterPath> Pathfinding::subdivideSafeRegions(const QPainterPath& safeArea) const {
    QList<QPainterPath> regions;
    // toSubpathPolygons returns each individual closed sub-path as a separate polygon.
    // This includes both the outer boundary AND the holes (restriction zones).
    // We MUST filter out hole polygons to prevent scanning inside restriction areas.
    QList<QPolygonF> polys = safeArea.toSubpathPolygons();
    for (const QPolygonF& poly : polys) {
        if (poly.size() < 3) continue;

        // Compute centroid of this sub-polygon
        QPointF centroid(0.0, 0.0);
        for (const QPointF& pt : poly) centroid += pt;
        centroid /= poly.size();

        // Only keep polygons whose centroid lies INSIDE the safe area.
        // Hole polygons (restriction zones) will have their centroid OUTSIDE
        // the safe area (it falls inside the restriction, which was subtracted).
        if (safeArea.contains(centroid)) {
            QPainterPath p;
            p.setFillRule(Qt::WindingFill);
            p.addPolygon(poly);
            p.closeSubpath();
            regions.append(p);
        } else {
            qDebug() << "[SUBDIVISION] Polygone ignoré (zone de restriction détectée, centroide hors zone sûre)";
        }
    }
    qDebug() << "[SUBDIVISION] Régions sûres finales:" << regions.size();
    return regions;
}

double Pathfinding::calculateDistance(const QList<GeoCoord>& path) const {
    if (path.size() < 2) return 0.0;
    double dist = 0.0;
    for (int i = 0; i < path.size() - 1; ++i) {
        Point2D p1 = geoToLocal(path[i], path[i]);
        Point2D p2 = geoToLocal(path[i], path[i+1]);
        dist += qSqrt(qPow(p2.x - p1.x, 2) + qPow(p2.y - p1.y, 2));
    }
    return dist;
}

double Pathfinding::calculateTime(double distance, int pointsCount) const {
    int turns = qMax(0, pointsCount - 2);
    return (distance / DRONE_SPEED) + (turns * TURN_PENALTY);
}

// Algorithm: Explicit scanline grid that avoids restriction zones.
bool Pathfinding::isLineBlocked(const QPointF& p1, const QPointF& p2, const QPainterPath& restr) const {
    if (restr.isEmpty()) return false;
    
    // 1. Intersection check with restriction boundaries
    QList<QPolygonF> polys = restr.toSubpathPolygons();
    for (const QPolygonF& poly : polys) {
        for (int i = 0; i < poly.size(); ++i) {
            QPointF a = poly[i], b = poly[(i + 1) % poly.size()];
            double x1 = p1.x(), y1 = p1.y(), x2 = p2.x(), y2 = p2.y();
            double x3 = a.x(), y3 = a.y(), x4 = b.x(), y4 = b.y();
            double den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4);
            if (qAbs(den) < 1e-9) continue; 
            double t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / den;
            double u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / den;
            if (t > 0.001 && t < 0.999 && u > 0.001 && u < 0.999) return true;
        }
    }
    
    // 2. Sampling check (in case the line is entirely inside a hole)
    // Check 1/3 and 2/3 points for more robustness than just midpoint
    if (restr.contains((p1 * 2.0 + p2) / 3.0)) return true;
    if (restr.contains((p1 + p2 * 2.0) / 3.0)) return true;
    
    return restr.contains((p1 + p2) / 2.0);
}

QList<Pathfinding::Point2D> Pathfinding::findSafePath(const QPointF& p1, const QPointF& p2, const QPainterPath& restr, const QList<QPolygonF>& polys) const {
    QList<Point2D> waypoints;
    if (!isLineBlocked(p1, p2, restr)) return waypoints;
    
    // Use visibility graph inspired nodes
    QList<QPointF> nodes; nodes << p1 << p2;
    for (const QPolygonF& poly : polys) {
        if (poly.isEmpty()) continue;
        QPointF center(0, 0); for (const QPointF& p : poly) center += p; center /= poly.size();
        for (const QPointF& p : poly) {
            QPointF dir = (p - center); double len = qSqrt(dir.x()*dir.x() + dir.y()*dir.y());
            // Buffer nodes away from corners to avoid "scuffing" the restriction
            if (len > 0) nodes << (p + (dir / len) * 4.0); // Increased buffer from 2.0 to 4.0
        }
    }
    
    QHash<int, int> parent; QQueue<int> queue; queue.enqueue(0); parent[0] = -1;
    bool found = false;
    while (!queue.isEmpty() && !found) {
        int u = queue.dequeue();
        if (u == 1) { found = true; break; }
        for (int v = 0; v < nodes.size(); ++v) {
            if (u == v || parent.contains(v)) continue;
            if (!isLineBlocked(nodes[u], nodes[v], restr)) { parent[v] = u; queue.enqueue(v); }
        }
    }
    
    if (found) {
        int curr = parent[1];
        while (curr != 0 && curr != -1) { 
            waypoints.prepend({nodes[curr].x(), nodes[curr].y()}); 
            curr = parent[curr]; 
        }
        
        // Path Smoothing: Try to skip intermediate nodes if direct line is clear
        if (waypoints.size() > 1) {
            QList<Point2D> smoothed;
            QPointF currentStart = p1;
            for (int i = 0; i < waypoints.size(); ++i) {
                bool blocked = false;
                // If we can skip to i+1, do it
                if (i + 1 < waypoints.size()) {
                    if (!isLineBlocked(currentStart, QPointF(waypoints[i+1].x, waypoints[i+1].y), restr)) {
                        continue; // Skip waypoints[i]
                    }
                }
                // Also try to skip to end
                if (!isLineBlocked(currentStart, p2, restr)) {
                    waypoints.clear();
                    return waypoints;
                }
                smoothed.append(waypoints[i]);
                currentStart = QPointF(waypoints[i].x, waypoints[i].y);
            }
            waypoints = smoothed;
        }
    }
    return waypoints;
}

// Algorithm: Explicit scanline grid that avoids restriction zones.
QList<Pathfinding::GeoCoord> Pathfinding::computeGrid(const QPainterPath& operableArea, const QList<QPolygonF>& restrPolys, double angle, const GeoCoord& refCoord) const {
    QList<GeoCoord> finalPath;
    if (operableArea.isEmpty()) return finalPath;

    QTransform tfm;
    tfm.rotate(angle);
    QTransform inv = tfm.inverted();

    // 1. Calculate the actual Safe Area (Mission - Restrictions)
    QPainterPath unionRestr;
    unionRestr.setFillRule(Qt::WindingFill);
    for (const QPolygonF& rp : restrPolys) unionRestr.addPolygon(rp);
    
    QPainterPath safeArea = operableArea.subtracted(unionRestr).simplified();
    if (safeArea.isEmpty()) return finalPath;

    // 2. Rotate the entire safe area for scanning
    QPainterPath rotSafe = tfm.map(safeArea);
    QList<QPolygonF> safePolys = rotSafe.toSubpathPolygons();
    
    QRectF bounds = rotSafe.boundingRect();
    double y = bounds.top() + SWEEP_WIDTH / 2.0;
    bool leftToRight = true;

    QPointF lastPoint;
    bool hasLast = false;

    // We also need the unrotated restrictions for transit checks if we findSafePath in local space
    QPainterPath restrUnionLocal;
    for (const QPolygonF& rp : restrPolys) restrUnionLocal.addPolygon(rp);

    while (y <= bounds.bottom()) {
        // Find all intersections of this scanline with ALL safe sub-polygons
        QList<double> intersections;
        for (const QPolygonF& poly : safePolys) {
            for (int i = 0; i < poly.size(); ++i) {
                QPointF p1 = poly[i];
                QPointF p2 = poly[(i + 1) % poly.size()];
                if ((p1.y() <= y && p2.y() > y) || (p2.y() <= y && p1.y() > y)) {
                    double x = p1.x() + (y - p1.y()) * (p2.x() - p1.x()) / (p2.y() - p1.y());
                    intersections << x;
                }
            }
        }
        std::sort(intersections.begin(), intersections.end());

        // Each pair of intersections is a safe segment because they come from the subtracted safe area
        struct Seg { double x1, x2; };
        QList<Seg> rowSegments;
        for (int i = 0; i + 1 < intersections.size(); i += 2) {
            if (intersections[i + 1] - intersections[i] > 0.1) {
                rowSegments << Seg{intersections[i], intersections[i + 1]};
            }
        }

        if (!rowSegments.isEmpty()) {
            if (!leftToRight) std::reverse(rowSegments.begin(), rowSegments.end());
            
            for (const Seg& seg : rowSegments) {
                double xStart = leftToRight ? seg.x1 : seg.x2;
                double xEnd   = leftToRight ? seg.x2 : seg.x1;
                QPointF pA(xStart, y);
                QPointF pB(xEnd, y);

                if (hasLast) {
                    QPointF uLast = inv.map(lastPoint);
                    QPointF uA = inv.map(pA);
                    QList<Point2D> transit = findSafePath(uLast, uA, restrUnionLocal, restrPolys);
                    for (const Point2D& wp : transit) {
                        // Safety check: ensure coordinates are valid before adding
                        if (qAbs(wp.x) > 1e-6 || qAbs(wp.y) > 1e-6) {
                            finalPath << localToGeo(refCoord, wp);
                        }
                    }
                }

                QPointF urA = inv.map(pA);
                QPointF urB = inv.map(pB);
                finalPath << localToGeo(refCoord, {urA.x(), urA.y()});
                finalPath << localToGeo(refCoord, {urB.x(), urB.y()});
                
                lastPoint = pB;
                hasLast = true;
            }
            leftToRight = !leftToRight;
        }

        y += SWEEP_WIDTH;
    }

    return finalPath;
}

QList<Pathfinding::GeoCoord> Pathfinding::computeSubdivision(const QPainterPath& operableArea, const QList<QPolygonF>& restrPolys, const GeoCoord& refCoord) const {
    QList<GeoCoord> finalPath;
    if (operableArea.isEmpty()) return finalPath;

    // 1. Identify all critical X and Y bounds (Mission + Restrictions)
    QSet<double> xCuts, yCuts;
    QRectF mBounds = operableArea.boundingRect();
    xCuts << mBounds.left() << mBounds.right();
    yCuts << mBounds.top() << mBounds.bottom();

    for (const QPolygonF& rp : restrPolys) {
        QRectF rb = rp.boundingRect();
        // Only include cuts that are inside the mission area to avoid unnecessary complexity
        if (rb.left() > mBounds.left() && rb.left() < mBounds.right()) xCuts << rb.left();
        if (rb.right() > mBounds.left() && rb.right() < mBounds.right()) xCuts << rb.right();
        if (rb.top() > mBounds.top() && rb.top() < mBounds.bottom()) yCuts << rb.top();
        if (rb.bottom() > mBounds.top() && rb.bottom() < mBounds.bottom()) yCuts << rb.bottom();
    }

    QList<double> sortedX = xCuts.values(); std::sort(sortedX.begin(), sortedX.end());
    QList<double> sortedY = yCuts.values(); std::sort(sortedY.begin(), sortedY.end());

    // 2. Union of all restrictions for collision checking
    QPainterPath restrUnion;
    for (const QPolygonF& rp : restrPolys) restrUnion.addPolygon(rp);

    // 3. Process each atomic rectangle
    bool hasLast = false;
    QPointF lastPoint;
    bool leftToRight = true;

    for (int j = 0; j + 1 < sortedY.size(); ++j) {
        double y1 = sortedY[j], y2 = sortedY[j+1];
        QList<int> xIndices; 
        for (int i = 0; i + 1 < sortedX.size(); ++i) xIndices << i;
        if (!leftToRight) std::reverse(xIndices.begin(), xIndices.end());

        for (int i : xIndices) {
            double x1 = sortedX[i], x2 = sortedX[i+1];
            QRectF rect(x1, y1, x2 - x1, y2 - y1);
            QPointF center = rect.center();

            // A rectangle is safe if its center is inside mission area AND NOT inside any restriction
            // (Since it's built from BBox edges, this is a good approximation for subdivision)
            if (operableArea.contains(center) && !restrUnion.contains(center)) {
                // Generate a grid local to this rectangle
                QPainterPath rectPath; rectPath.addRect(rect);
                // We use computeGrid but for this specific local rectangle, with 0 degree sweep
                QList<GeoCoord> subGrid = computeGrid(rectPath, restrPolys, 0.0, refCoord);
                
                if (!subGrid.isEmpty()) {
                    // Connect to previous point if needed
                    if (hasLast) {
                        GeoCoord startGeo = subGrid.first();
                        Point2D startLocal = geoToLocal(refCoord, startGeo);
                        QList<Point2D> transit = findSafePath(lastPoint, QPointF(startLocal.x, startLocal.y), restrUnion, restrPolys);
                        for (const Point2D& wp : transit) finalPath << localToGeo(refCoord, wp);
                    }
                    
                    finalPath.append(subGrid);
                    GeoCoord endGeo = subGrid.last();
                    Point2D endLocal = geoToLocal(refCoord, endGeo);
                    lastPoint = QPointF(endLocal.x, endLocal.y);
                    hasLast = true;
                }
            }
        }
        leftToRight = !leftToRight;
    }

    qDebug() << "[SUBDIVISION] Generated subdivision path with" << finalPath.size() << "points.";
    return finalPath;
}

bool Pathfinding::savePathToJson(const QString& filePath) const {
    QString actualPath = filePath;
    if (actualPath.startsWith("file://")) actualPath = QUrl(filePath).toLocalFile();

    QJsonObject root;
    QJsonArray array;
    for (const QVariant& v : m_lastPath) {
        QVariantMap map = v.toMap();
        QJsonObject obj;
        obj["lat"] = map["latitude"].toDouble();
        obj["lon"] = map["longitude"].toDouble();
        obj["alt"] = 0.0;
        array.append(obj);
    }
    root["checkpoints"] = array;

    QJsonDocument doc(root);
    QFile file(actualPath);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(doc.toJson());
        file.close();
        qDebug() << "[JSON] Path exported to:" << actualPath;
        return true;
    }
    qDebug() << "[JSON] FAILED to export to:" << actualPath;
    return false;
}

#include <QTextStream>

bool Pathfinding::savePathToCsv(const QString& filePath) const {
    QString actualPath = filePath;
    if (actualPath.startsWith("file://")) actualPath = QUrl(filePath).toLocalFile();

    QFile file(actualPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qDebug() << "[CSV] FAILED to export to:" << actualPath;
        return false;
    }

    QTextStream out(&file);
    out << "Latitude,Longitude,Altitude\n";
    for (const QVariant& v : m_lastPath) {
        QVariantMap m = v.toMap();
        out << QString::number(m["latitude"].toDouble(), 'f', 8) << ","
            << QString::number(m["longitude"].toDouble(), 'f', 8) << ",0\n";
    }
    file.close();
    qDebug() << "[CSV] Path exported to:" << actualPath;
    return true;
}

#include <QPdfWriter>
#include <QPainter>
#include <QDateTime>

bool Pathfinding::generatePdfReport(const QString& filePath) const {
    QString actualPath = filePath;
    if (actualPath.startsWith("file://")) actualPath = QUrl(filePath).toLocalFile();

    QPdfWriter pdfWriter(actualPath);
    pdfWriter.setPageSize(QPageSize(QPageSize::A4));
    pdfWriter.setPageMargins(QMarginsF(20, 20, 20, 20)); // Page margins in mm
    pdfWriter.setTitle("Rapport de Mission de Vol");
    pdfWriter.setCreator("Projet de Recherche Drone");

    const int res = pdfWriter.resolution();
    const double resScale = res / 72.0; // Points to Dots conversion factor

    QPainter painter(&pdfWriter);
    if (!painter.isActive()) return false;

    // Use scaling to work in Points (1/72 inch)
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setRenderHint(QPainter::TextAntialiasing);
    
    int currentY = 50; // Points from top
    int marginX = 50;  // Points from left

    auto writeLine = [&](const QString& text, int size, bool bold = false, int xOffset = 0) {
        QFont font("Helvetica", size);
        font.setBold(bold);
        painter.setFont(font);
        
        QFontMetrics fm(font);
        int h = fm.height();
        
        // Final position in dots (since we scale the painter, we can just use points)
        // Wait, if we scale the painter, drawText(x, y) coordinates are in points too.
        painter.drawText(marginX + xOffset, currentY + fm.ascent(), text);
        currentY += h + 4; // Add a small leading (4 points)
    };

    painter.scale(resScale, resScale); // Now 1 unit = 1 point

    // Header Section
    writeLine("RAPPORT DE MISSION DE VOL", 24, true);
    writeLine("Généré le : " + QDateTime::currentDateTime().toString("dd/MM/yyyy HH:mm"), 11, false);
    
    currentY += 10;
    painter.setPen(QPen(Qt::black, 1.5));
    painter.drawLine(marginX, currentY, 540, currentY); // ~190mm wide in points
    currentY += 25;

    // Statistics Section
    writeLine("Statistiques de vol", 16, true);
    currentY += 5;
    writeLine("Distance totale   : " + QString::number(m_bestDistance, 'f', 2) + " m", 12, false, 15);
    writeLine("Temps estimé      : " + QString::number(m_bestTime, 'f', 2) + " s", 12, false, 15);
    writeLine("Algorithme utilisé : " + m_bestAlgorithm, 12, false, 15);
    writeLine("Points de passage : " + QString::number(m_lastPath.size()), 12, false, 15);
    currentY += 20;

    // Waypoints Section
    writeLine("Liste des points de passage (Checkpoints)", 16, true);
    currentY += 5;
    
    // We can fit two columns of waypoints if we want, but let's stick to one clear list first
    int i = 0;
    int maxPoints = qMin(m_lastPath.size(), 40);
    for (i = 0; i < maxPoints; ++i) {
        QVariantMap p = m_lastPath.at(i).toMap();
        QString line = QString("%1. Latitude: %2 | Longitude: %3")
                        .arg(i + 1, 2)
                        .arg(p["latitude"].toDouble(), 0, 'f', 7)
                        .arg(p["longitude"].toDouble(), 0, 'f', 7);
        writeLine(line, 9, false, 15);
        
        // Prevent overflow to next page for now (simple report)
        if (currentY > 750) break; 
    }
    
    if (m_lastPath.size() > i) {
        writeLine("... (et " + QString::number(m_lastPath.size() - i) + " autres points)", 9, false, 15);
    }

    painter.end();
    qDebug() << "[PDF] Rapport généré et organisé :" << actualPath;
    return true;
}

// Main execution
void Pathfinding::calculateBestRoute() {
    if (m_missionPoints.size() < 3) return;

    qDebug() << "=========================================";
    qDebug() << "🚀 PLANIFICATION PAR SUBDIVISION (SECURE)";
    qDebug() << "=========================================";

    GeoCoord refCoord = variantToGeo(m_missionPoints.at(0));
    
    QPainterPath operableArea = buildPathFromVariantList(m_missionPoints, refCoord);
    QList<QPolygonF> restrPolys = buildRestrictionPolygons(refCoord);

    struct Result { QString name; QList<GeoCoord> path; double dist; double time; };
    QList<Result> results;

    auto evaluate = [&](const QString& name, const QList<GeoCoord>& path) {
        double dist = calculateDistance(path);
        double time = calculateTime(dist, path.size());
        if (dist > 1.0) results.append({name, path, dist, time});
    };

    evaluate("Grille Horizontale", computeGrid(operableArea, restrPolys, 0.0, refCoord));
    evaluate("Grille Verticale",   computeGrid(operableArea, restrPolys, 90.0, refCoord));
    evaluate("Grille Diagonale",   computeGrid(operableArea, restrPolys, 45.0, refCoord));
    evaluate("Subdivision (Local)", computeSubdivision(operableArea, restrPolys, refCoord));
    
    if (results.isEmpty()) {
        qDebug() << "(!) Erreur : Aucun itinéraire n'a pu être généré.";
        return;
    }

    Result best = results.first();
    for (const Result& r : results) {
        // Optimization: shorter distance is better
        if (r.dist > 1.0 && (best.dist == 0 || r.dist < best.dist)) best = r;
    }

    m_bestDistance = best.dist;
    m_bestTime = best.time;
    m_bestAlgorithm = best.name;

    qDebug() << "=========================================";
    qDebug() << "ALGORITHME CHOISI :" << m_bestAlgorithm;
    qDebug() << "DISTANCE TOTALE   :" << QString::number(m_bestDistance, 'f', 2) << "m";
    qDebug() << "TEMPS ESTIMÉ      :" << QString::number(m_bestTime, 'f', 2) << "s";
    qDebug() << "NOMBRE DE POINTS  :" << best.path.size();
    qDebug() << "=========================================";

    m_lastPath.clear();
    for (const GeoCoord& point : best.path) {
        QVariantMap pm;
        pm["latitude"] = point.lat;
        pm["longitude"] = point.lng;
        m_lastPath.append(pm);
    }
    emit pathCalculated(m_lastPath, best.dist, best.time, best.name);
}
