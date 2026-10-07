#include "PlaylistModel.h"

PlaylistModel::PlaylistModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int PlaylistModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return static_cast<int>(m_playlists.size());
}

QVariant PlaylistModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_playlists.size())
        return QVariant();

    const auto &item = m_playlists.at(index.row());
    switch (role) {
    case IdRole:
        return item.id;
    case NameRole:
        return item.name;
    case DescriptionRole:
        return item.description;
    case CoverUrlRole:
        return item.coverUrl;
    case TrackCountRole:
        return item.trackCount;
    case CreatedAtRole:
        return item.createdAt;
    case IsFavoritesRole:
        return item.isFavorites;
    case TrackPathsRole:
        return item.trackPaths;
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> PlaylistModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[IdRole] = "id";
    roles[NameRole] = "name";
    roles[DescriptionRole] = "description";
    roles[CoverUrlRole] = "coverUrl";
    roles[TrackCountRole] = "trackCount";
    roles[CreatedAtRole] = "createdAt";
    roles[IsFavoritesRole] = "isFavorites";
    roles[TrackPathsRole] = "trackPaths";
    return roles;
}

void PlaylistModel::setPlaylists(const QList<PlaylistItem> &items)
{
    beginResetModel();
    m_playlists = items;
    endResetModel();
}

void PlaylistModel::addPlaylist(const PlaylistItem &item)
{
    beginInsertRows(QModelIndex(), m_playlists.size(), m_playlists.size());
    m_playlists.append(item);
    endInsertRows();
}

void PlaylistModel::removePlaylist(const QString &id)
{
    for (int i = 0; i < m_playlists.size(); ++i) {
        if (m_playlists[i].id == id) {
            beginRemoveRows(QModelIndex(), i, i);
            m_playlists.removeAt(i);
            endRemoveRows();
            break;
        }
    }
}

void PlaylistModel::updatePlaylist(const PlaylistItem &item)
{
    for (int i = 0; i < m_playlists.size(); ++i) {
        if (m_playlists[i].id == item.id) {
            m_playlists[i] = item;
            QModelIndex idx = index(i, 0);
            emit dataChanged(idx, idx);
            break;
        }
    }
}

void PlaylistModel::clear()
{
    beginResetModel();
    m_playlists.clear();
    endResetModel();
}

PlaylistItem PlaylistModel::playlistAt(int index) const
{
    if (index >= 0 && index < m_playlists.size()) {
        return m_playlists.at(index);
    }
    return PlaylistItem();
}

PlaylistItem PlaylistModel::findPlaylist(const QString &id) const
{
    for (const auto &item : m_playlists) {
        if (item.id == id) return item;
    }
    return PlaylistItem();
}
