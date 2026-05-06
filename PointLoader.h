#ifndef POINTLOADER_H
#define POINTLOADER_H

#include <QObject>
#include <QVariantList>

class PointLoader : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorStringChanged)

public:
    explicit PointLoader(QObject *parent = nullptr);

    QString errorString() const;

    Q_INVOKABLE QVariantList loadPoints(const QUrl &fileUrl);

signals:
    void errorStringChanged();

private:
    QVariantList loadText(const QString &filePath);
    QVariantList loadXlsx(const QString &filePath);
    void setErrorString(const QString &errorString);

    QString m_errorString;
};

#endif
