#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>

#include "AreaController.h"

int main(int argc, char* argv[]) {
    QGuiApplication app(argc, argv);

    // Use Fusion style for consistent cross-platform button appearance
    QQuickStyle::setStyle("Fusion");

    qmlRegisterType<AreaController>("PDR.Logic", 1, 0, "AreaController");

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
        []() { QCoreApplication::exit(-1); }, Qt::QueuedConnection);
    engine.loadFromModule("projet_de_recherche", "Main");

    return app.exec();
}
