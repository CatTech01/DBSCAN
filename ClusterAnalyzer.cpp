#include "ClusterAnalyzer.h"

#include <limits>
#include <QVector>
#include <QtMath>

namespace {
double coordinateValue(const QVariantMap &point,
                       const QString &axis,
                       const QString &unit,
                       double pixelsPerCentimeter)
{
    if (unit == QStringLiteral("пиксели"))
        return point.value(axis).toDouble();

    if (unit == QStringLiteral("см"))
        return point.value(axis).toDouble() / pixelsPerCentimeter;

    return point.value(axis == QStringLiteral("x")
                       ? QStringLiteral("dataX")
                       : QStringLiteral("dataY")).toDouble();
}
}

ClusterAnalyzer::ClusterAnalyzer(QObject *parent)
    : QObject(parent)
{
}

QVariantMap ClusterAnalyzer::clusterInfo(const QVariantList &points,
                                         int clusterId,
                                         const QString &unit,
                                         double pixelsPerCentimeter) const
{
    QVector<QVariantMap> clusterPoints;
    clusterPoints.reserve(points.size());

    for (const QVariant &value : points) {
        const QVariantMap point = value.toMap();

        if (point.value(QStringLiteral("cluster")).toInt() == clusterId)
            clusterPoints.append(point);
    }

    if (clusterPoints.isEmpty()) {
        return QVariantMap {
            {QStringLiteral("found"), false},
            {QStringLiteral("count"), 0}
        };
    }

    int centerIndex = 0;
    double bestDistanceSum = std::numeric_limits<double>::max();
    double diagonal = 0.0;
    int diagonalStartIndex = 0;
    int diagonalEndIndex = 0;
    QVector<double> distanceX;
    QVector<double> distanceY;

    distanceX.reserve(clusterPoints.size());
    distanceY.reserve(clusterPoints.size());

    for (const QVariantMap &point : clusterPoints) {
        distanceX.append(coordinateValue(point, QStringLiteral("x"), unit, pixelsPerCentimeter));
        distanceY.append(coordinateValue(point, QStringLiteral("y"), unit, pixelsPerCentimeter));
    }

    for (int i = 0; i < clusterPoints.size(); ++i) {
        double distanceSum = 0.0;

        for (int j = 0; j < clusterPoints.size(); ++j) {
            if (i == j)
                continue;

            const double dx = distanceX[i] - distanceX[j];
            const double dy = distanceY[i] - distanceY[j];
            const double distance = qSqrt(dx * dx + dy * dy);

            distanceSum += distance;

            if (j > i && distance > diagonal) {
                diagonal = distance;
                diagonalStartIndex = i;
                diagonalEndIndex = j;
            }
        }

        if (distanceSum < bestDistanceSum) {
            bestDistanceSum = distanceSum;
            centerIndex = i;
        }
    }

    const QVariantMap center = clusterPoints[centerIndex];
    const QVariantMap diagonalStart = clusterPoints[diagonalStartIndex];
    const QVariantMap diagonalEnd = clusterPoints[diagonalEndIndex];
    const double centerX = center.value(QStringLiteral("dataX")).toDouble();
    const double centerY = center.value(QStringLiteral("dataY")).toDouble();
    const double centerDistanceX = distanceX[centerIndex];
    const double centerDistanceY = distanceY[centerIndex];
    double minDistance = 0.0;
    double maxDistance = 0.0;
    int minDistanceIndex = centerIndex;
    int maxDistanceIndex = centerIndex;
    bool hasOtherPoint = false;

    for (int i = 0; i < clusterPoints.size(); ++i) {
        if (i == centerIndex)
            continue;

        const double dx = centerDistanceX - distanceX[i];
        const double dy = centerDistanceY - distanceY[i];
        const double distance = qSqrt(dx * dx + dy * dy);

        if (!hasOtherPoint) {
            minDistance = distance;
            maxDistance = distance;
            minDistanceIndex = i;
            maxDistanceIndex = i;
            hasOtherPoint = true;
        } else {
            if (distance < minDistance) {
                minDistance = distance;
                minDistanceIndex = i;
            }

            if (distance > maxDistance) {
                maxDistance = distance;
                maxDistanceIndex = i;
            }
        }
    }

    const QVariantMap minDistancePoint = clusterPoints[minDistanceIndex];
    const QVariantMap maxDistancePoint = clusterPoints[maxDistanceIndex];

    return QVariantMap {
        {QStringLiteral("found"), true},
        {QStringLiteral("count"), clusterPoints.size()},
        {QStringLiteral("centerX"), centerX},
        {QStringLiteral("centerY"), centerY},
        {QStringLiteral("distanceX"), centerDistanceX},
        {QStringLiteral("distanceY"), centerDistanceY},
        {QStringLiteral("screenX"), center.value(QStringLiteral("x")).toDouble()},
        {QStringLiteral("screenY"), center.value(QStringLiteral("y")).toDouble()},
        {QStringLiteral("minDistance"), minDistance},
        {QStringLiteral("maxDistance"), maxDistance},
        {QStringLiteral("minDistancePointX"), minDistancePoint.value(QStringLiteral("x")).toDouble()},
        {QStringLiteral("minDistancePointY"), minDistancePoint.value(QStringLiteral("y")).toDouble()},
        {QStringLiteral("maxDistancePointX"), maxDistancePoint.value(QStringLiteral("x")).toDouble()},
        {QStringLiteral("maxDistancePointY"), maxDistancePoint.value(QStringLiteral("y")).toDouble()},
        {QStringLiteral("diagonal"), diagonal},
        {QStringLiteral("diagonalStartX"), diagonalStart.value(QStringLiteral("x")).toDouble()},
        {QStringLiteral("diagonalStartY"), diagonalStart.value(QStringLiteral("y")).toDouble()},
        {QStringLiteral("diagonalEndX"), diagonalEnd.value(QStringLiteral("x")).toDouble()},
        {QStringLiteral("diagonalEndY"), diagonalEnd.value(QStringLiteral("y")).toDouble()},
        {QStringLiteral("distanceSum"), bestDistanceSum}
    };
}
