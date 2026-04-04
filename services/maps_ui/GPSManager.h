#ifndef GPSMANAGER_H
#define GPSMANAGER_H

#include <QObject>
#include <QGeoPositionInfoSource>
#include <QGeoCoordinate>
#include <QtQml/qqmlregistration.h>

class GPSManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(double latitude READ latitude NOTIFY latitudeChanged)
    Q_PROPERTY(double longitude READ longitude NOTIFY longitudeChanged)
    Q_PROPERTY(bool isValid READ isValid NOTIFY validChanged)
    QML_ELEMENT

public:
    explicit GPSManager(QObject *parent = nullptr);
    ~GPSManager();

    double latitude() const { return m_latitude; }
    double longitude() const { return m_longitude; }
    bool isValid() const { return m_isValid; }

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();

signals:
    void latitudeChanged();
    void longitudeChanged();
    void validChanged();
    void positionChanged();

private slots:
    void updatePosition(const QGeoPositionInfo &info);

private:
    QGeoPositionInfoSource *m_source;
    double m_latitude = 0.0;
    double m_longitude = 0.0;
    bool m_isValid = false;
};

#endif // GPSMANAGER_H
