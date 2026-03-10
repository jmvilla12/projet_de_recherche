#ifndef AREACONTROLLER_H
#define AREACONTROLLER_H

#include <QObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

class AreaController : public QObject {
    Q_OBJECT
  public:
    explicit AreaController(QObject* parent = nullptr);

    Q_INVOKABLE double calculateArea(const QVariantList& vertices);

  signals:
};

#endif // AREACONTROLLER_H
