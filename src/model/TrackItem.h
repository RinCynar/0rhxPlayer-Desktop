#pragma once

#include <QString>
#include <QObject>

struct TrackItem {
    Q_GADGET
    Q_PROPERTY(QString path MEMBER path)
    Q_PROPERTY(QString title MEMBER title)
    Q_PROPERTY(QString artist MEMBER artist)
    Q_PROPERTY(QString album MEMBER album)
    Q_PROPERTY(QString albumArtist MEMBER albumArtist)
    Q_PROPERTY(qint64 durationMs MEMBER durationMs)
    Q_PROPERTY(bool hasCover MEMBER hasCover)
    Q_PROPERTY(QString coverUrl MEMBER coverUrl)
    Q_PROPERTY(QString format MEMBER format)
    Q_PROPERTY(QStringList artists MEMBER artists)
    Q_PROPERTY(qint64 fileSizeBytes MEMBER fileSizeBytes)
    Q_PROPERTY(int bitrateKbps MEMBER bitrateKbps)
    Q_PROPERTY(qint64 dateAdded MEMBER dateAdded)
    Q_PROPERTY(qint64 dateModified MEMBER dateModified)

public:
    QString path;
    QString title;
    QString artist;
    QStringList artists;
    QString album;
    QString albumArtist;
    qint64 durationMs{0};
    bool hasCover{false};
    QString coverUrl;
    QString format;
    qint64 fileSizeBytes{0};
    int bitrateKbps{0};
    qint64 dateAdded{0};
    qint64 dateModified{0};
};
Q_DECLARE_METATYPE(TrackItem)
