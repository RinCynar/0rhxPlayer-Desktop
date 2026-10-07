#include "AlbumModel.h"

AlbumModel::AlbumModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int AlbumModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return static_cast<int>(m_albums.size());
}

QVariant AlbumModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_albums.size()) {
        return QVariant();
    }

    const auto &album = m_albums.at(index.row());
    switch (role) {
    case NameRole: return album.name;
    case ArtistRole: return album.artist;
    case CoverUrlRole: return album.coverUrl;
    case TrackCountRole: return album.trackCount;
    case PathRole: return album.path;
    case Qt::DisplayRole: return album.name;
    default: return QVariant();
    }
}

QHash<int, QByteArray> AlbumModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[NameRole] = "name";
    roles[ArtistRole] = "artist";
    roles[CoverUrlRole] = "coverUrl";
    roles[TrackCountRole] = "trackCount";
    roles[PathRole] = "path";
    return roles;
}

void AlbumModel::setAlbums(const QList<AlbumItem> &albums)
{
    beginResetModel();
    m_albums = albums;
    endResetModel();
}

void AlbumModel::addAlbum(const AlbumItem &album)
{
    beginInsertRows(QModelIndex(), m_albums.size(), m_albums.size());
    m_albums.append(album);
    endInsertRows();
}

void AlbumModel::clear()
{
    beginResetModel();
    m_albums.clear();
    endResetModel();
}

AlbumItem AlbumModel::albumAt(int index) const
{
    if (index >= 0 && index < m_albums.size()) {
        return m_albums.at(index);
    }
    return AlbumItem();
}
