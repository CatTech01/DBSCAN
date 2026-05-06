#include "ClusterAnalyzer.h"

#include <limits>
#include <QVector>
#include <QtMath>

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

    for (int i = 0; i < clusterPoints.size(); ++i) {
        const double x = unit == QStringLiteral("пиксели")
                ? clusterPoints[i].value(QStringLiteral("x")).toDouble()
                : unit == QStringLiteral("см")
                    ? clusterPoints[i].value(QStringLiteral("x")).toDouble() / pixelsPerCentimeter
                    : clusterPoints[i].value(QStringLiteral("dataX")).toDouble();
        const double y = unit == QStringLiteral("пиксели")
                ? clusterPoints[i].value(QStringLiteral("y")).toDouble()
                : unit == QStringLiteral("см")
                    ? clusterPoints[i].value(QStringLiteral("y")).toDouble() / pixelsPerCentimeter
                    : clusterPoints[i].value(QStringLiteral("dataY")).toDouble();
        double distanceSum = 0.0;

        for (int j = 0; j < clusterPoints.size(); ++j) {
            if (i == j)
                continue;

            const double otherX = unit == QStringLiteral("пиксели")
                    ? clusterPoints[j].value(QStringLiteral("x")).toDouble()
                    : unit == QStringLiteral("см")
                        ? clusterPoints[j].value(QStringLiteral("x")).toDouble() / pixelsPerCentimeter
                        : clusterPoints[j].value(QStringLiteral("dataX")).toDouble();
            const double otherY = unit == QStringLiteral("пиксели")
                    ? clusterPoints[j].value(QStringLiteral("y")).toDouble()
                    : unit == QStringLiteral("см")
                        ? clusterPoints[j].value(QStringLiteral("y")).toDouble() / pixelsPerCentimeter
                        : clusterPoints[j].value(QStringLiteral("dataY")).toDouble();
            const double dx = x - otherX;
            const double dy = y - otherY;
            distanceSum += qSqrt(dx * dx + dy * dy);
        }

        if (distanceSum < bestDistanceSum) {
            bestDistanceSum = distanceSum;
            centerIndex = i;
        }
    }

    const QVariantMap center = clusterPoints[centerIndex];
    const double centerX = center.value(QStringLiteral("dataX")).toDouble();
    const double centerY = center.value(QStringLiteral("dataY")).toDouble();
    const double centerDistanceX = unit == QStringLiteral("пиксели")
            ? center.value(QStringLiteral("x")).toDouble()
            : unit == QStringLiteral("см")
                ? center.value(QStringLiteral("x")).toDouble() / pixelsPerCentimeter
                : centerX;
    const double centerDistanceY = unit == QStringLiteral("пиксели")
            ? center.value(QStringLiteral("y")).toDouble()
            : unit == QStringLiteral("см")
                ? center.value(QStringLiteral("y")).toDouble() / pixelsPerCentimeter
                : centerY;
    double minDistance = 0.0;
    double maxDistance = 0.0;
    bool hasOtherPoint = false;

    for (int i = 0; i < clusterPoints.size(); ++i) {
        if (i == centerIndex)
            continue;

        const double x = unit == QStringLiteral("пиксели")
                ? clusterPoints[i].value(QStringLiteral("x")).toDouble()
                : unit == QStringLiteral("см")
                    ? clusterPoints[i].value(QStringLiteral("x")).toDouble() / pixelsPerCentimeter
                    : clusterPoints[i].value(QStringLiteral("dataX")).toDouble();
        const double y = unit == QStringLiteral("пиксели")
                ? clusterPoints[i].value(QStringLiteral("y")).toDouble()
                : unit == QStringLiteral("см")
                    ? clusterPoints[i].value(QStringLiteral("y")).toDouble() / pixelsPerCentimeter
                    : clusterPoints[i].value(QStringLiteral("dataY")).toDouble();
        const double dx = centerDistanceX - x;
        const double dy = centerDistanceY - y;
        const double distance = qSqrt(dx * dx + dy * dy);

        if (!hasOtherPoint) {
            minDistance = distance;
            maxDistance = distance;
            hasOtherPoint = true;
        } else {
            minDistance = qMin(minDistance, distance);
            maxDistance = qMax(maxDistance, distance);
        }
    }

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
        {QStringLiteral("distanceSum"), bestDistanceSum}
    };
}
