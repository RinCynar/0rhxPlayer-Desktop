#pragma once

#include <QString>
#include <QObject>

struct LyricItem {
    Q_GADGET
    Q_PROPERTY(qint64 timeMs MEMBER timeMs)
    Q_PROPERTY(QString text MEMBER text)
    Q_PROPERTY(QString trans MEMBER trans)

public:
    qint64 timeMs{0};
    QString text;
    QString trans;
};
Q_DECLARE_METATYPE(LyricItem)
