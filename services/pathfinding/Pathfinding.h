#ifndef PATHFINDING_H
#define PATHFINDING_H

#include <QObject>
#include <QVariantList>

class Pathfinding : public QObject {
    Q_OBJECT
  public:
    explicit Pathfinding(QObject* parent = nullptr);

    // Placeholder for pathfinding logic
    Q_INVOKABLE QVariantList calculateBestRoute(const QVariantList& areaPoints);

  signals:
};

#endif // PATHFINDING_H
