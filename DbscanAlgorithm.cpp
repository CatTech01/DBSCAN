#include "DbscanAlgorithm.h"

#include <QHash>
#include <QSet>
#include <QtMath>

DbscanAlgorithm::DbscanAlgorithm(QObject *parent)
    : QObject(parent)
{
}

QVariantList DbscanAlgorithm::buildSteps(const QVariantList &points,
                                         double epsilon,
                                         int minPts,
                                         const QString &unit,
                                         double coordinateScaleX,
                                         double coordinateScaleY,
                                         double pixelsPerCentimeter) const
{
    const QVector<Point> sourcePoints = readPoints(points, unit, coordinateScaleX, coordinateScaleY, pixelsPerCentimeter);
    const double cellSize = qMax(epsilon, 0.000001);
    const QHash<QString, QVector<int>> spatialIndex = buildSpatialIndex(sourcePoints, cellSize);
    QVector<int> labels(sourcePoints.size(), 0);
    QVector<bool> visited(sourcePoints.size(), false);
    QVariantList steps;
    int clusterId = 0;

    for (int pointIndex = 0; pointIndex < sourcePoints.size(); ++pointIndex) {
        if (visited[pointIndex])
            continue;

        visited[pointIndex] = true;
        QVector<int> neighbors = regionQuery(sourcePoints, spatialIndex, pointIndex, epsilon, cellSize);
        steps.append(QVariantMap {
            {QStringLiteral("type"), QStringLiteral("inspect")},
            {QStringLiteral("index"), pointIndex},
            {QStringLiteral("neighbors"), indexesToList(neighbors)},
            {QStringLiteral("cluster"), clusterId}
        });

        if (neighbors.size() < minPts) {
            labels[pointIndex] = -1;
            steps.append(QVariantMap {
                {QStringLiteral("type"), QStringLiteral("noise")},
                {QStringLiteral("index"), pointIndex}
            });
            continue;
        }

        ++clusterId;
        labels[pointIndex] = clusterId;
        steps.append(QVariantMap {
            {QStringLiteral("type"), QStringLiteral("cluster")},
            {QStringLiteral("index"), pointIndex},
            {QStringLiteral("cluster"), clusterId},
            {QStringLiteral("core"), true}
        });

        QVector<int> seeds = neighbors;
        QSet<int> inSeeds;

        for (const int seed : seeds)
            inSeeds.insert(seed);

        for (int queueIndex = 0; queueIndex < seeds.size(); ++queueIndex) {
            const int neighborIndex = seeds[queueIndex];

            if (!visited[neighborIndex]) {
                visited[neighborIndex] = true;
                QVector<int> neighborNeighbors = regionQuery(sourcePoints, spatialIndex, neighborIndex, epsilon, cellSize);
                steps.append(QVariantMap {
                    {QStringLiteral("type"), QStringLiteral("inspect")},
                    {QStringLiteral("index"), neighborIndex},
                    {QStringLiteral("neighbors"), indexesToList(neighborNeighbors)},
                    {QStringLiteral("cluster"), clusterId}
                });

                if (neighborNeighbors.size() >= minPts) {
                    for (const int candidate : neighborNeighbors) {
                        if (!inSeeds.contains(candidate)) {
                            seeds.append(candidate);
                            inSeeds.insert(candidate);
                        }
                    }
                }
            }

            if (labels[neighborIndex] <= 0) {
                const bool isCore = regionQuery(sourcePoints, spatialIndex, neighborIndex, epsilon, cellSize).size() >= minPts;
                labels[neighborIndex] = clusterId;
                steps.append(QVariantMap {
                    {QStringLiteral("type"), QStringLiteral("cluster")},
                    {QStringLiteral("index"), neighborIndex},
                    {QStringLiteral("cluster"), clusterId},
                    {QStringLiteral("core"), isCore}
                });
            }
        }
    }

    steps.append(QVariantMap {
        {QStringLiteral("type"), QStringLiteral("finish")},
        {QStringLiteral("clusters"), clusterId}
    });
    return steps;
}

QVariantMap DbscanAlgorithm::runImmediately(const QVariantList &points,
                                            double epsilon,
                                            int minPts,
                                            const QString &unit,
                                            double coordinateScaleX,
                                            double coordinateScaleY,
                                            double pixelsPerCentimeter) const
{
    QVector<Point> resultPoints = readPoints(points, unit, coordinateScaleX, coordinateScaleY, pixelsPerCentimeter);
    const double cellSize = qMax(epsilon, 0.000001);
    const QHash<QString, QVector<int>> spatialIndex = buildSpatialIndex(resultPoints, cellSize);
    QVector<int> labels(resultPoints.size(), 0);
    QVector<bool> visited(resultPoints.size(), false);
    QVector<bool> isCorePoint(resultPoints.size(), false);
    int clusterId = 0;

    for (int pointIndex = 0; pointIndex < resultPoints.size(); ++pointIndex) {
        if (visited[pointIndex])
            continue;

        visited[pointIndex] = true;
        QVector<int> neighbors = regionQuery(resultPoints, spatialIndex, pointIndex, epsilon, cellSize);

        if (neighbors.size() < minPts) {
            labels[pointIndex] = -1;
            continue;
        }

        ++clusterId;
        labels[pointIndex] = clusterId;
        isCorePoint[pointIndex] = true;

        QVector<int> seeds = neighbors;
        QSet<int> inSeeds;

        for (const int seed : seeds)
            inSeeds.insert(seed);

        for (int queueIndex = 0; queueIndex < seeds.size(); ++queueIndex) {
            const int neighborIndex = seeds[queueIndex];

            if (!visited[neighborIndex]) {
                visited[neighborIndex] = true;
                QVector<int> neighborNeighbors = regionQuery(resultPoints, spatialIndex, neighborIndex, epsilon, cellSize);

                if (neighborNeighbors.size() >= minPts) {
                    isCorePoint[neighborIndex] = true;

                    for (const int candidate : neighborNeighbors) {
                        if (!inSeeds.contains(candidate)) {
                            seeds.append(candidate);
                            inSeeds.insert(candidate);
                        }
                    }
                }
            }

            if (labels[neighborIndex] <= 0)
                labels[neighborIndex] = clusterId;
        }
    }

    for (int i = 0; i < resultPoints.size(); ++i) {
        resultPoints[i].cluster = labels[i];
        resultPoints[i].noise = labels[i] == -1;
        resultPoints[i].core = isCorePoint[i];
    }

    return QVariantMap {
        {QStringLiteral("points"), pointsToList(resultPoints)},
        {QStringLiteral("clusters"), clusterId}
    };
}

QVector<DbscanAlgorithm::Point> DbscanAlgorithm::readPoints(const QVariantList &points,
                                                            const QString &unit,
                                                            double coordinateScaleX,
                                                            double coordinateScaleY,
                                                            double pixelsPerCentimeter) const
{
    QVector<Point> result;
    result.reserve(points.size());

    for (const QVariant &value : points) {
        const QVariantMap map = value.toMap();
        Point point;
        point.x = map.value(QStringLiteral("x")).toDouble();
        point.y = map.value(QStringLiteral("y")).toDouble();
        point.dataX = map.contains(QStringLiteral("dataX")) ? map.value(QStringLiteral("dataX")).toDouble() : point.x;
        point.dataY = map.contains(QStringLiteral("dataY")) ? map.value(QStringLiteral("dataY")).toDouble() : point.y;

        if (unit == QStringLiteral("единицы")) {
            point.distanceX = point.dataX;
            point.distanceY = point.dataY;
        } else if (unit == QStringLiteral("см")) {
            point.distanceX = point.x / pixelsPerCentimeter;
            point.distanceY = point.y / pixelsPerCentimeter;
        } else {
            point.distanceX = point.x;
            point.distanceY = point.y;
        }

        if (!map.contains(QStringLiteral("dataX")))
            point.dataX = point.x / qMax(coordinateScaleX, 1.0);

        if (!map.contains(QStringLiteral("dataY")))
            point.dataY = point.y / qMax(coordinateScaleY, 1.0);

        result.append(point);
    }

    return result;
}

QVariantMap DbscanAlgorithm::pointToMap(const Point &point) const
{
    return QVariantMap {
        {QStringLiteral("x"), point.x},
        {QStringLiteral("y"), point.y},
        {QStringLiteral("dataX"), point.dataX},
        {QStringLiteral("dataY"), point.dataY},
        {QStringLiteral("cluster"), point.cluster},
        {QStringLiteral("core"), point.core},
        {QStringLiteral("noise"), point.noise}
    };
}

QVariantList DbscanAlgorithm::pointsToList(const QVector<Point> &points) const
{
    QVariantList result;
    result.reserve(points.size());

    for (const Point &point : points)
        result.append(pointToMap(point));

    return result;
}

QVariantList DbscanAlgorithm::indexesToList(const QVector<int> &indexes) const
{
    QVariantList result;
    result.reserve(indexes.size());

    for (const int index : indexes)
        result.append(index);

    return result;
}

QString DbscanAlgorithm::cellKey(int x, int y) const
{
    return QString::number(x) + QLatin1Char(':') + QString::number(y);
}

QHash<QString, QVector<int>> DbscanAlgorithm::buildSpatialIndex(const QVector<Point> &points, double cellSize) const
{
    QHash<QString, QVector<int>> index;

    for (int i = 0; i < points.size(); ++i) {
        const int cellX = qFloor(points[i].distanceX / cellSize);
        const int cellY = qFloor(points[i].distanceY / cellSize);
        index[cellKey(cellX, cellY)].append(i);
    }

    return index;
}

QVector<int> DbscanAlgorithm::regionQuery(const QVector<Point> &points,
                                          const QHash<QString, QVector<int>> &spatialIndex,
                                          int pointIndex,
                                          double epsilon,
                                          double cellSize) const
{
    QVector<int> neighbors;
    const Point &point = points[pointIndex];
    const int cellX = qFloor(point.distanceX / cellSize);
    const int cellY = qFloor(point.distanceY / cellSize);
    const double epsilonSquared = epsilon * epsilon;

    for (int offsetX = -1; offsetX <= 1; ++offsetX) {
        for (int offsetY = -1; offsetY <= 1; ++offsetY) {
            const QVector<int> candidates = spatialIndex.value(cellKey(cellX + offsetX, cellY + offsetY));

            for (const int candidateIndex : candidates) {
                const Point &candidate = points[candidateIndex];
                const double dx = point.distanceX - candidate.distanceX;
                const double dy = point.distanceY - candidate.distanceY;

                if (dx * dx + dy * dy <= epsilonSquared)
                    neighbors.append(candidateIndex);
            }
        }
    }

    return neighbors;
}
