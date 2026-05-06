#include "PointLoader.h"

#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QRegularExpression>
#include <QUrl>
#include <QXmlStreamReader>

PointLoader::PointLoader(QObject *parent)
    : QObject(parent)
{
}

QString PointLoader::errorString() const
{
    return m_errorString;
}

QVariantList PointLoader::loadPoints(const QUrl &fileUrl)
{
    setErrorString(QString());

    const QString filePath = fileUrl.isLocalFile() ? fileUrl.toLocalFile() : fileUrl.toString();
    const QFileInfo fileInfo(filePath);

    if (!fileInfo.exists() || !fileInfo.isFile()) {
        setErrorString(QStringLiteral("Файл не найден"));
        return {};
    }

    const QString suffix = fileInfo.suffix().toLower();

    if (suffix == QStringLiteral("xlsx"))
        return loadXlsx(filePath);

    if (suffix == QStringLiteral("xls")) {
        setErrorString(QStringLiteral("Формат .xls не поддерживается. Сохраните файл как .xlsx"));
        return {};
    }

    if (suffix == QStringLiteral("csv") || suffix == QStringLiteral("txt") || suffix == QStringLiteral("tsv"))
        return loadText(filePath);

    setErrorString(QStringLiteral("Используйте .xlsx, .csv, .tsv или .txt"));
    return {};
}

QVariantList PointLoader::loadText(const QString &filePath)
{
    QFile file(filePath);

    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        setErrorString(file.errorString());
        return {};
    }

    const QString content = QString::fromUtf8(file.readAll());
    const QRegularExpression numberExpression(QStringLiteral(R"([+-]?(?:\d+(?:[.,]\d*)?|[.,]\d+)(?:[eE][+-]?\d+)?)"));
    QRegularExpressionMatchIterator matches = numberExpression.globalMatch(content);
    QList<double> values;
    QVariantList points;

    while (matches.hasNext()) {
        QString rawValue = matches.next().captured(0);
        bool okX = false;
        const double value = rawValue.replace(',', '.').toDouble(&okX);

        if (okX)
            values.append(value);
    }

    for (qsizetype i = 0; i + 1 < values.size(); i += 2) {
        QVariantMap point;
        point.insert(QStringLiteral("x"), values[i]);
        point.insert(QStringLiteral("y"), values[i + 1]);
        points.append(point);
    }

    if (values.size() % 2 != 0)
        setErrorString(QStringLiteral("Последняя координата пропущена: для неё нет пары"));

    if (points.isEmpty())
        setErrorString(QStringLiteral("Пары координат не найдены"));

    return points;
}

QVariantList PointLoader::loadXlsx(const QString &filePath)
{
    QProcess unzip;
    unzip.start(QStringLiteral("/usr/bin/unzip"),
                {QStringLiteral("-p"), filePath, QStringLiteral("xl/worksheets/sheet1.xml")});

    if (!unzip.waitForFinished(5000)) {
        unzip.kill();
        setErrorString(QStringLiteral("Не удалось прочитать первый лист"));
        return {};
    }

    if (unzip.exitStatus() != QProcess::NormalExit || unzip.exitCode() != 0) {
        setErrorString(QStringLiteral("Не удалось открыть файл как книгу Excel .xlsx"));
        return {};
    }

    const QByteArray sheetXml = unzip.readAllStandardOutput();
    QXmlStreamReader xml(sheetXml);
    QVariantList points;
    int currentColumn = -1;
    double rowValues[2] = {0.0, 0.0};
    bool rowHasValue[2] = {false, false};

    while (!xml.atEnd()) {
        xml.readNext();

        if (xml.isStartElement() && xml.name() == QStringLiteral("row")) {
            rowHasValue[0] = false;
            rowHasValue[1] = false;
        } else if (xml.isEndElement() && xml.name() == QStringLiteral("row")) {
            if (rowHasValue[0] && rowHasValue[1]) {
                QVariantMap point;
                point.insert(QStringLiteral("x"), rowValues[0]);
                point.insert(QStringLiteral("y"), rowValues[1]);
                points.append(point);
            }
        } else if (xml.isStartElement() && xml.name() == QStringLiteral("c")) {
            const QString reference = xml.attributes().value(QStringLiteral("r")).toString();
            currentColumn = -1;

            if (!reference.isEmpty()) {
                const QChar column = reference.at(0).toUpper();

                if (column == QLatin1Char('A'))
                    currentColumn = 0;
                else if (column == QLatin1Char('B'))
                    currentColumn = 1;
            }
        } else if (xml.isStartElement() && xml.name() == QStringLiteral("v") && currentColumn >= 0 && currentColumn < 2) {
            const QString rawValue = xml.readElementText().trimmed();
            bool ok = false;
            const double value = rawValue.toDouble(&ok);

            if (ok) {
                rowValues[currentColumn] = value;
                rowHasValue[currentColumn] = true;
            }
        }
    }

    if (xml.hasError()) {
        setErrorString(QStringLiteral("Не удалось разобрать лист Excel"));
        return {};
    }

    if (points.isEmpty())
        setErrorString(QStringLiteral("В колонках A и B не найдены числовые точки"));

    return points;
}

void PointLoader::setErrorString(const QString &errorString)
{
    if (m_errorString == errorString)
        return;

    m_errorString = errorString;
    emit errorStringChanged();
}
