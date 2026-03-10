#include "CoordinateExporter.h"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>

CoordinateExporter::CoordinateExporter(QObject* parent) : QObject(parent) {}

bool CoordinateExporter::exportToJson(const QVariantList& coordinates, const QString& fileName) {
    // TODO: Implement actual export logic to JSON
    return true;
}
