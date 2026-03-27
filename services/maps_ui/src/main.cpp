#include <QGuiApplication>
#include <QFontDatabase>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QFont>

#include "AreaController.h"

int main(int argc, char* argv[]) {
    QGuiApplication app(argc, argv);

    // Register Geist Sans fonts
    QFontDatabase::addApplicationFont(":/qt/qml/projet_de_recherche/assets/fonts/Geist-Regular.ttf");
    QFontDatabase::addApplicationFont(":/qt/qml/projet_de_recherche/assets/fonts/Geist-Medium.ttf");
    QFontDatabase::addApplicationFont(":/qt/qml/projet_de_recherche/assets/fonts/Geist-Bold.ttf");
    QFontDatabase::addApplicationFont(":/qt/qml/projet_de_recherche/assets/fonts/Geist-SemiBold.ttf");
    QFontDatabase::addApplicationFont(":/qt/qml/projet_de_recherche/assets/fonts/Geist-Light.ttf");

    // Set Geist Sans as the default application font
    app.setFont(QFont("Geist Sans"));

    // Set application icon (standard cross-platform way)
    app.setWindowIcon(QIcon(":/qt/qml/projet_de_recherche/assets/images/app_icon.png"));

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
