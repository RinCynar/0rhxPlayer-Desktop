#pragma once

#include <QString>
#include <QStringList>
#include <QObject>

struct PlaylistItem {
    Q_GADGET
    Q_PROPERTY(QString id MEMBER id)
    Q_PROPERTY(QString name MEMBER name)
    Q_PROPERTY(QString description MEMBER description)
    Q_PROPERTY(QString coverUrl MEMBER coverUrl)
    Q_PROPERTY(int trackCount MEMBER trackCount)
    Q_PROPERTY(qint64 createdAt MEMBER createdAt)
    Q_PROPERTY(bool isFavorites MEMBER isFavorites)

public:
    QString id;
    QString name;
    QString description;
    QString coverUrl;
    int trackCount{0};
    qint64 createdAt{0};
    bool isFavorites{false};
    QStringList trackPaths;
};
Q_DECLARE_METATYPE(PlaylistItem)
