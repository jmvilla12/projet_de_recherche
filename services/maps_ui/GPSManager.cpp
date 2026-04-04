#include "GPSManager.h"
#include <QGeoPositionInfoSource>
#include <QDebug>

GPSManager::GPSManager(QObject *parent) : QObject(parent), m_source(nullptr) {
    m_source = QGeoPositionInfoSource::createDefaultSource(this);
    if (m_source) {
        connect(m_source, &QGeoPositionInfoSource::positionUpdated, this, &GPSManager::updatePosition);
        m_source->setUpdateInterval(1000);
        qDebug() << "GPSManager: Created default source successfully.";
    } else {
        qDebug() << "GPSManager: Failed to create default position source.";
    }
}

GPSManager::~GPSManager() {
    if (m_source) m_source->stopUpdates();
}

void GPSManager::start() {
    if (m_source) {
        m_source->startUpdates();
        qDebug() << "GPSManager: Starting updates...";
    }
}

void GPSManager::stop() {
    if (m_source) m_source->stopUpdates();
}

void GPSManager::updatePosition(const QGeoPositionInfo &info) {
    if (info.isValid()) {
        QGeoCoordinate coord = info.coordinate();
        
        if (m_latitude != coord.latitude()) {
            m_latitude = coord.latitude();
            emit latitudeChanged();
        }
        if (m_longitude != coord.longitude()) {
            m_longitude = coord.longitude();
            emit longitudeChanged();
        }
        if (!m_isValid) {
            m_isValid = true;
            emit validChanged();
        }
        
        emit positionChanged();
        qDebug() << "GPSManager: Position updated:" << m_latitude << "," << m_longitude;
    }
}
