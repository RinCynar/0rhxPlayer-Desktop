#pragma once

#include <QAbstractListModel>
#include <QList>
#include "AlbumItem.h"

class AlbumModel : public QAbstractListModel {
    Q_OBJECT

public:
    enum AlbumRoles {
        NameRole = Qt::UserRole + 1,
        ArtistRole,
        CoverUrlRole,
        TrackCountRole,
        PathRole
    };

    explicit AlbumModel(QObject *parent = nullptr);

    Q_INVOKABLE int count() const { return rowCount(); }
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setAlbums(const QList<AlbumItem> &albums);
    void addAlbum(const AlbumItem &album);
    void clear();

    const QList<AlbumItem>& albums() const { return m_albums; }
    AlbumItem albumAt(int index) const;

private:
    QList<AlbumItem> m_albums;
};
