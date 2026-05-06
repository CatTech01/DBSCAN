#ifndef CLUSTERANALYZER_H
#define CLUSTERANALYZER_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class ClusterAnalyzer : public QObject
{
    Q_OBJECT

public:
    explicit ClusterAnalyzer(QObject *parent = nullptr);

    Q_INVOKABLE QVariantMap clusterInfo(const QVariantList &points,
                                        int clusterId,
                                        const QString &unit,
                                        double pixelsPerCentimeter) const;
};

#endif
