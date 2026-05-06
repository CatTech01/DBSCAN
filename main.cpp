#include "ClusterAnalyzer.h"
#include "DbscanAlgorithm.h"
#include "PointLoader.h"

#include <QGuiApplication>
#include <QQmlContext>
#include <QQmlApplicationEngine>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    ClusterAnalyzer clusterAnalyzer;
    DbscanAlgorithm dbscanAlgorithm;
    PointLoader pointLoader;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("clusterAnalyzer"), &clusterAnalyzer);
    engine.rootContext()->setContextProperty(QStringLiteral("dbscanAlgorithm"), &dbscanAlgorithm);
    engine.rootContext()->setContextProperty(QStringLiteral("pointLoader"), &pointLoader);
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("DBSCAN", "Main");

    return QCoreApplication::exec();
}
