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
#include <QThread>
#include <QProcess>
#include <QtConcurrent>

const double SWEEP_WIDTH = 3; // Increased spacing for visibility during testing, can be reduced to 1.2 later
const double DRONE_SPEED = 5.0;
const double TURN_PENALTY = 2.0;

Pathfinding::Pathfinding(QObject* parent) : QObject(parent) {}
Pathfinding::~Pathfinding() {
    qDebug() << "[Pathfinding] Nettoyage des processus ROS2/Gazebo...";
    QProcess::execute("pkill -f \"ros2|vrx|gz\"");
}

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

// Static helper for launching gnome-terminals
static void launchCommand(const QString& cmd) {
    QStringList args;
    args << "--" << "bash" << "-c" << cmd + "; exec bash";
    QProcess::startDetached("gnome-terminal", args);
}

struct ScanSegment {
    int id;
    double x1, x2, y;
    bool visited;
    QList<int> neighbors;
};

// Algorithm: Graph-based Cellular Decomposition Grid Sweep
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

    // 3. Generate coverage segments
    QList<ScanSegment> segments;
    int idCounter = 0;

    // We also need the unrotated restrictions for transit checks if we findSafePath in local space
    QPainterPath restrUnionLocal;
    for (const QPolygonF& rp : restrPolys) restrUnionLocal.addPolygon(rp);

    while (y <= bounds.bottom()) {
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

        // Each pair of intersections is a safe segment
        for (int i = 0; i + 1 < intersections.size(); i += 2) {
            if (intersections[i + 1] - intersections[i] > 0.1) {
                segments.append({idCounter++, intersections[i], intersections[i + 1], y, false, {}});
            }
        }
        y += SWEEP_WIDTH;
    }

    if (segments.isEmpty()) return finalPath;

    // 4. Build Adjacency Graph (Topological Connectivity)
    for (int i = 0; i < segments.size(); ++i) {
        for (int j = i + 1; j < segments.size(); ++j) {
            double dy = qAbs(segments[i].y - segments[j].y);
            if (qAbs(dy - SWEEP_WIDTH) < 1e-3) {
                // If they overlap geometrically in X
                if (qMax(segments[i].x1, segments[j].x1) <= qMin(segments[i].x2, segments[j].x2) + 1e-3) {
                    segments[i].neighbors.append(j);
                    segments[j].neighbors.append(i);
                }
            }
        }
    }

    // 5. Intelligent Graph Traversal (DFS/Cellular Pattern)
    int currentId = 0;
    bool goLeftToRight = true;
    QPointF currentPos;
    bool hasPos = false;

    while (currentId != -1) {
        ScanSegment& seg = segments[currentId];
        seg.visited = true;

        double enterX = goLeftToRight ? seg.x1 : seg.x2;
        double exitX  = goLeftToRight ? seg.x2 : seg.x1;
        
        QPointF entryNode(enterX, seg.y);
        QPointF exitNode(exitX, seg.y);

        if (hasPos) {
            QPointF p1 = inv.map(currentPos);
            QPointF p2 = inv.map(entryNode);
            // If jump is > SWEEP_WIDTH or the transition is blocked by a restriction, use safe routing
            if (qAbs(currentPos.y() - seg.y) > SWEEP_WIDTH + 1e-3 || isLineBlocked(p1, p2, restrUnionLocal)) {
                QList<Point2D> transit = findSafePath(p1, p2, restrUnionLocal, restrPolys);
                for (const Point2D& wp : transit) {
                    if (qAbs(wp.x) > 1e-6 || qAbs(wp.y) > 1e-6) {
                        finalPath << localToGeo(refCoord, wp);
                    }
                }
            }
        }

        QPointF urA = inv.map(entryNode);
        QPointF urB = inv.map(exitNode);
        finalPath << localToGeo(refCoord, {urA.x(), urA.y()});
        finalPath << localToGeo(refCoord, {urB.x(), urB.y()});
        
        currentPos = exitNode;
        hasPos = true;

        // Determine next segment
        int nextId = -1;
        double minD = 1e9;

        // Priority 1: Topologically connected unvisited neighbors (sweeping the current cell)
        for (int nid : seg.neighbors) {
            if (!segments[nid].visited) {
                double d1 = qAbs(exitNode.x() - segments[nid].x1);
                double d2 = qAbs(exitNode.x() - segments[nid].x2);
                double d = qMin(d1, d2);
                if (d < minD) {
                    minD = d;
                    nextId = nid;
                    goLeftToRight = (d1 < d2); // Enter from the closest side
                }
            }
        }

        // Priority 2: Unvisited segment anywhere (jumping to a new cell/lobe)
        if (nextId == -1) {
            for (int i = 0; i < segments.size(); ++i) {
                if (!segments[i].visited) {
                    double d1 = qSqrt(qPow(exitNode.x() - segments[i].x1, 2) + qPow(exitNode.y() - segments[i].y, 2));
                    double d2 = qSqrt(qPow(exitNode.x() - segments[i].x2, 2) + qPow(exitNode.y() - segments[i].y, 2));
                    double d = qMin(d1, d2);
                    if (d < minD) {
                        minD = d;
                        nextId = i;
                        goLeftToRight = (d1 < d2);
                    }
                }
            }
        }

        currentId = nextId;
    }

    return finalPath;
}

QList<Pathfinding::GeoCoord> Pathfinding::computeSubdivision(const QPainterPath& operableArea, const QList<QPolygonF>& restrPolys, const GeoCoord& refCoord) const {
    // The upgraded computeGrid inherently performs advanced Cell Decomposition via 
    // adjacency graphs. Running it at 0 degrees corresponds perfectly to the optimal subdivision approach.
    return computeGrid(operableArea, restrPolys, 0.0, refCoord);
}

#include <QThread>
#include <QProcess>

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

void Pathfinding::runVrxSimulation() {
    if (m_isSimLaunching) return;

    QString savePath = "/home/javier/vrx_ws/src/gps_waypoints/checkpoints/sample_checkpoints1.json";
    qDebug() << "[SIM] Auto-sauvegarde vers :" << savePath;
    
    if (!savePathToJson(savePath)) {
        qDebug() << "[SIM] ERREUR : Impossible de sauvegarder les points de passage.";
        return;
    }

    QString baseEnv = "cd ~/vrx_ws && source /opt/ros/jazzy/setup.bash && source install/setup.bash && ";

    m_isSimLaunching = true;
    emit isSimLaunchingChanged();

    // Use QtConcurrent to launch simulation in background (prevents UI freeze)
    QtConcurrent::run([this, baseEnv, savePath]() {
        qDebug() << "[SIM] Lancement de la séquence ROS2 (arrière-plan)...";

        if (!m_isSimInitialized) {
            // 1) Iniciar mundo (Gazebo)
            launchCommand(baseEnv + "ros2 launch vrx_gz vrx_environment.launch.py world:=sydney_regatta");
            QThread::msleep(5000);

            // 2) Spawnear WAM-V
            launchCommand(baseEnv + "ros2 launch vrx_gz spawn.launch.py world:=sydney_regatta sim_mode:=full name:=wamv model:=wam-v");
            QThread::msleep(3000);
            
            m_isSimInitialized = true;
        }

        // 3) Publicar waypoint GPS desde JSON
        launchCommand(baseEnv + "ros2 run gps_waypoints gps_waypoint_node --ros-args -p checkpoints_file:=" + savePath);
        
        // 4) Convertir GPS -> ENU
        launchCommand(baseEnv + "ros2 run gps_waypoints gps_waypoint_converter");
        
        // 5) Controlador
        launchCommand(baseEnv + "ros2 run gps_waypoints gps_waypoint_controller --ros-args -p goal_topic:=/wamv/goal_pose -p state_source:=gps_imu -p gps_topic:=/wamv/sensors/gps/gps/fix -p imu_topic:=/wamv/sensors/imu/imu/data -p control_mode:=thrusters -p left_thrust_topic:=/wamv/thrusters/left/thrust -p right_thrust_topic:=/wamv/thrusters/right/thrust -p left_pos_topic:=/wamv/thrusters/left/pos -p right_pos_topic:=/wamv/thrusters/right/pos -p k_thrust_lin:=82.0 -p k_thrust_ang:=28.0 -p max_thrust:=235.0 -p heading_slowdown_rad:=0.9 -p heading_inplace_rad:=1.35 -p heading_deadband_rad:=0.2 -p turn_close_dist:=20.0 -p min_forward_thrust:=10.0 -p turn_to_forward_ratio:=0.55 -p turn_bias_thrust:=24.0");

        qDebug() << "[SIM] Séquence de lancement terminée.";
        
        m_isSimLaunching = false;
        emit isSimLaunchingChanged();
    });
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

    qDebug() << "=========================================";
    qDebug() << "ALGORITHME CHOISI :" << best.name;
    qDebug() << "DISTANCE TOTALE   :" << QString::number(best.dist, 'f', 2) << "m";
    qDebug() << "TEMPS ESTIMÉ      :" << QString::number(best.time, 'f', 2) << "s";
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
