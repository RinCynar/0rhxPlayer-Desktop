#pragma once

#include <QAbstractListModel>
#include <QList>
#include "PlaylistItem.h"

class PlaylistModel : public QAbstractListModel {
    Q_OBJECT

public:
    enum PlaylistRoles {
        IdRole = Qt::UserRole + 1,
        NameRole,
        DescriptionRole,
        CoverUrlRole,
        TrackCountRole,
        CreatedAtRole,
        IsFavoritesRole,
        TrackPathsRole
    };

    explicit PlaylistModel(QObject *parent = nullptr);

    Q_INVOKABLE int count() const { return rowCount(); }
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setPlaylists(const QList<PlaylistItem> &items);
    void addPlaylist(const PlaylistItem &item);
    void removePlaylist(const QString &id);
    void updatePlaylist(const PlaylistItem &item);
    void clear();

    const QList<PlaylistItem>& playlists() const { return m_playlists; }
    PlaylistItem playlistAt(int index) const;
    PlaylistItem findPlaylist(const QString &id) const;

private:
    QList<PlaylistItem> m_playlists;
};
