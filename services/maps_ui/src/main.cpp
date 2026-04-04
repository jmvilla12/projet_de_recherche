#include <QFont>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQuickStyle>

#include "AreaController.h"
#include "Pathfinding.h"

#include <QLocationPermission>
#include <QPermission>
#include <QDebug>
#include <QQmlEngine>
#include <QQmlContext>
#include "GPSManager.h"

int main(int argc, char* argv[]) {
    QGuiApplication app(argc, argv);

    GPSManager* gpsManager = new GPSManager(&app);

    // Request Location Permission (Required for macOS/iOS)
    QLocationPermission locationPermission;
    locationPermission.setAccuracy(QLocationPermission::Precise);
    locationPermission.setAvailability(QLocationPermission::WhenInUse);

    app.requestPermission(locationPermission, [](const QPermission &p) {
        if (p.status() == Qt::PermissionStatus::Granted) {
            qDebug() << "Location permission granted! Sensor will wait for manual toggle.";
        } else {
            qDebug() << "Location permission denied or undetermined. Status: " << static_cast<int>(p.status());
        }
    });

    // Register Geist Sans fonts
    QFontDatabase::addApplicationFont(
        ":/qt/qml/projet_de_recherche/assets/fonts/Geist-Regular.ttf");
    QFontDatabase::addApplicationFont(":/qt/qml/projet_de_recherche/assets/fonts/Geist-Medium.ttf");
    QFontDatabase::addApplicationFont(":/qt/qml/projet_de_recherche/assets/fonts/Geist-Bold.ttf");
    QFontDatabase::addApplicationFont(
        ":/qt/qml/projet_de_recherche/assets/fonts/Geist-SemiBold.ttf");
    QFontDatabase::addApplicationFont(":/qt/qml/projet_de_recherche/assets/fonts/Geist-Light.ttf");

    // Set Geist Sans as the default application font
    app.setFont(QFont("Geist Sans"));

    // Set application icon (standard cross-platform way)
    app.setWindowIcon(QIcon(":/qt/qml/projet_de_recherche/assets/images/LogoSinFondo.png"));

    // Use Fusion style for consistent cross-platform button appearance
    QQuickStyle::setStyle("Fusion");

    qmlRegisterType<AreaController>("PDR.Logic", 1, 0, "AreaController");
    qmlRegisterType<Pathfinding>("PDR.Logic", 1, 0, "PathfindingService");

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("gpsManager", gpsManager);
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
        []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);
    engine.loadFromModule("projet_de_recherche", "Main");

    return app.exec();
}
