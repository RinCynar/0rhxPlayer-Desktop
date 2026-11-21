#pragma once

#include <QString>
#include <QObject>
#include <QVariant>

struct LyricWord {
    Q_GADGET
    Q_PROPERTY(QString text MEMBER text)
    Q_PROPERTY(qint64 startMs MEMBER startMs)
    Q_PROPERTY(qint64 endMs MEMBER endMs)

public:
    QString text;
    qint64 startMs{0};
    qint64 endMs{0};
};
Q_DECLARE_METATYPE(LyricWord)

struct LyricItem {
    Q_GADGET
    Q_PROPERTY(qint64 timeMs MEMBER timeMs)
    Q_PROPERTY(QString text MEMBER text)
    Q_PROPERTY(QString trans MEMBER trans)
    Q_PROPERTY(bool hasWords MEMBER hasWords)
    Q_PROPERTY(QVariantList words MEMBER words)

public:
    qint64 timeMs{0};
    QString text;
    QString trans;
    bool hasWords{false};
    QVariantList words;
};
Q_DECLARE_METATYPE(LyricItem)
