#ifndef COORDINATEEXPORTER_H
#define COORDINATEEXPORTER_H

#include <QObject>
#include <QVariantList>

class CoordinateExporter : public QObject {
    Q_OBJECT
  public:
    explicit CoordinateExporter(QObject* parent = nullptr);

    // Placeholder for exporting coordinates to the drone
    Q_INVOKABLE bool exportToJson(const QVariantList& coordinates, const QString& fileName);

  signals:
};

#endif // COORDINATEEXPORTER_H
