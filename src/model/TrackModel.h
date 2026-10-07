#pragma once

#include <QAbstractListModel>
#include <QList>
#include "TrackItem.h"

class TrackModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(qint64 totalDurationMs READ totalDurationMs NOTIFY totalDurationChanged)

public:
    enum TrackRoles {
        PathRole = Qt::UserRole + 1,
        TitleRole,
        ArtistRole,
        AlbumRole,
        DurationMsRole,
        HasCoverRole,
        CoverUrlRole,
        FormatRole,
        ArtistsRole,
        FileSizeBytesRole,
        BitrateKbpsRole,
        DateAddedRole,
        DateModifiedRole
    };

    explicit TrackModel(QObject *parent = nullptr);

    int count() const { return rowCount(); }
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setTracks(const QList<TrackItem> &tracks);
    void addTrack(const TrackItem &track);
    Q_INVOKABLE void removeTrack(int index);
    Q_INVOKABLE void moveTrack(int from, int to);
    Q_INVOKABLE void clear();
    Q_INVOKABLE qint64 totalDurationMs() const;
    Q_INVOKABLE int indexOfPath(const QString &path) const;

    const QList<TrackItem>& tracks() const { return m_tracks; }
    Q_INVOKABLE TrackItem trackAt(int index) const;
    Q_INVOKABLE QString pathAt(int index) const;
    Q_INVOKABLE QStringList getPathsInRange(int fromIndex, int toIndex) const;

signals:
    void countChanged();
    void totalDurationChanged();

private:
    QList<TrackItem> m_tracks;
};
