#pragma once

#include <QString>
#include <QList>
#include <QObject>
#include "TrackItem.h"

struct AlbumItem {
    Q_GADGET
    Q_PROPERTY(QString name MEMBER name)
    Q_PROPERTY(QString artist MEMBER artist)
    Q_PROPERTY(QString coverUrl MEMBER coverUrl)
    Q_PROPERTY(int trackCount MEMBER trackCount)
    Q_PROPERTY(QString path MEMBER path)

public:
    QString name;
    QString artist;
    QString coverUrl;
    int trackCount{0};
    QString path;
    QList<TrackItem> tracks;
};
Q_DECLARE_METATYPE(AlbumItem)
