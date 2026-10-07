#include "TrackModel.h"

TrackModel::TrackModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int TrackModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return static_cast<int>(m_tracks.size());
}

QVariant TrackModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_tracks.size()) {
        return QVariant();
    }

    const auto &track = m_tracks.at(index.row());
    switch (role) {
    case PathRole: return track.path;
    case TitleRole: return track.title;
    case ArtistRole: return track.artist;
    case AlbumRole: return track.album;
    case DurationMsRole: return track.durationMs;
    case HasCoverRole: return track.hasCover;
    case CoverUrlRole: return track.coverUrl;
    case FormatRole: return track.format;
    case ArtistsRole: return track.artists;
    case FileSizeBytesRole: return track.fileSizeBytes;
    case BitrateKbpsRole: return track.bitrateKbps;
    case DateAddedRole: return track.dateAdded;
    case DateModifiedRole: return track.dateModified;
    case Qt::DisplayRole: return track.title;
    default: return QVariant();
    }
}

QHash<int, QByteArray> TrackModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[PathRole] = "path";
    roles[TitleRole] = "title";
    roles[ArtistRole] = "artist";
    roles[AlbumRole] = "album";
    roles[DurationMsRole] = "durationMs";
    roles[HasCoverRole] = "hasCover";
    roles[CoverUrlRole] = "coverUrl";
    roles[FormatRole] = "format";
    roles[ArtistsRole] = "artists";
    roles[FileSizeBytesRole] = "fileSizeBytes";
    roles[BitrateKbpsRole] = "bitrateKbps";
    roles[DateAddedRole] = "dateAdded";
    roles[DateModifiedRole] = "dateModified";
    return roles;
}

void TrackModel::setTracks(const QList<TrackItem> &tracks)
{
    beginResetModel();
    m_tracks = tracks;
    endResetModel();
    emit countChanged();
    emit totalDurationChanged();
}

void TrackModel::addTrack(const TrackItem &track)
{
    beginInsertRows(QModelIndex(), m_tracks.size(), m_tracks.size());
    m_tracks.append(track);
    endInsertRows();
    emit countChanged();
    emit totalDurationChanged();
}

void TrackModel::removeTrack(int index)
{
    if (index < 0 || index >= m_tracks.size()) return;
    beginRemoveRows(QModelIndex(), index, index);
    m_tracks.removeAt(index);
    endRemoveRows();
    emit countChanged();
    emit totalDurationChanged();
}

void TrackModel::moveTrack(int from, int to)
{
    if (from < 0 || from >= m_tracks.size() || to < 0 || to >= m_tracks.size() || from == to) return;
    int destChild = (to > from) ? (to + 1) : to;
    if (!beginMoveRows(QModelIndex(), from, from, QModelIndex(), destChild)) return;
    m_tracks.move(from, to);
    endMoveRows();
}

void TrackModel::clear()
{
    beginResetModel();
    m_tracks.clear();
    endResetModel();
    emit countChanged();
    emit totalDurationChanged();
}

qint64 TrackModel::totalDurationMs() const
{
    qint64 total = 0;
    for (const auto &t : m_tracks) {
        total += t.durationMs;
    }
    return total;
}

int TrackModel::indexOfPath(const QString &path) const
{
    for (int i = 0; i < m_tracks.size(); ++i) {
        if (QString::compare(m_tracks[i].path, path, Qt::CaseInsensitive) == 0) {
            return i;
        }
    }
    return -1;
}

TrackItem TrackModel::trackAt(int index) const
{
    if (index >= 0 && index < m_tracks.size()) {
        return m_tracks.at(index);
    }
    return TrackItem();
}

QString TrackModel::pathAt(int index) const
{
    if (index >= 0 && index < m_tracks.size()) {
        return m_tracks.at(index).path;
    }
    return QString();
}

QStringList TrackModel::getPathsInRange(int fromIndex, int toIndex) const
{
    QStringList result;
    if (m_tracks.isEmpty()) return result;
    int start = qMax(0, qMin(fromIndex, toIndex));
    int end = qMin(static_cast<int>(m_tracks.size() - 1), qMax(fromIndex, toIndex));
    for (int i = start; i <= end; ++i) {
        result.append(m_tracks.at(i).path);
    }
    return result;
}

