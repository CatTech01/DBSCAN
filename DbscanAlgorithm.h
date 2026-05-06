#ifndef DBSCANALGORITHM_H
#define DBSCANALGORITHM_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class DbscanAlgorithm : public QObject
{
    Q_OBJECT

public:
    explicit DbscanAlgorithm(QObject *parent = nullptr);

    Q_INVOKABLE QVariantList buildSteps(const QVariantList &points,
                                        double epsilon,
                                        int minPts,
                                        const QString &unit,
                                        double coordinateScaleX,
                                        double coordinateScaleY,
                                        double pixelsPerCentimeter) const;

    Q_INVOKABLE QVariantMap runImmediately(const QVariantList &points,
                                           double epsilon,
                                           int minPts,
                                           const QString &unit,
                                           double coordinateScaleX,
                                           double coordinateScaleY,
                                           double pixelsPerCentimeter) const;

private:
    struct Point
    {
        double x = 0.0;
        double y = 0.0;
        double dataX = 0.0;
        double dataY = 0.0;
        double distanceX = 0.0;
        double distanceY = 0.0;
        int cluster = 0;
        bool core = false;
        bool noise = false;
    };

    QVector<Point> readPoints(const QVariantList &points,
                              const QString &unit,
                              double coordinateScaleX,
                              double coordinateScaleY,
                              double pixelsPerCentimeter) const;
    QVariantMap pointToMap(const Point &point) const;
    QVariantList pointsToList(const QVector<Point> &points) const;
    QVariantList indexesToList(const QVector<int> &indexes) const;
    QString cellKey(int x, int y) const;
    QHash<QString, QVector<int>> buildSpatialIndex(const QVector<Point> &points, double cellSize) const;
    QVector<int> regionQuery(const QVector<Point> &points,
                             const QHash<QString, QVector<int>> &spatialIndex,
                             int pointIndex,
                             double epsilon,
                             double cellSize) const;
};

#endif
