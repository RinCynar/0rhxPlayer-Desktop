#pragma once

#include <QObject>
#include <QList>
#include <QStringList>
#include <QPointer>
#include <QThread>
#include "../model/TrackModel.h"
#include "../model/AlbumModel.h"
#include "../model/PlaylistModel.h"
#include "../model/PlaylistItem.h"

class LibraryManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(int trackCount READ trackCount NOTIFY trackCountChanged)
    Q_PROPERTY(bool isScanning READ isScanning NOTIFY isScanningChanged)
    Q_PROPERTY(int scannedCount READ scannedCount NOTIFY scannedCountChanged)
    Q_PROPERTY(TrackModel* recommendedTracks READ recommendedTracks NOTIFY recommendedTracksChanged)
    Q_PROPERTY(AlbumModel* recommendedAlbums READ recommendedAlbums NOTIFY recommendedAlbumsChanged)
    Q_PROPERTY(TrackModel* allTracks READ allTracks NOTIFY allTracksChanged)
    Q_PROPERTY(AlbumModel* allAlbums READ allAlbums NOTIFY allAlbumsChanged)
    Q_PROPERTY(AlbumModel* allArtists READ allArtists NOTIFY allArtistsChanged)
    Q_PROPERTY(AlbumModel* allFolders READ allFolders NOTIFY allFoldersChanged)
    Q_PROPERTY(TrackModel* filteredTracks READ filteredTracks NOTIFY filteredTracksChanged)
    Q_PROPERTY(AlbumModel* artistAlbums READ artistAlbums NOTIFY artistAlbumsChanged)
    Q_PROPERTY(TrackModel* searchTracks READ searchTracks NOTIFY searchResultChanged)
    Q_PROPERTY(AlbumModel* searchAlbums READ searchAlbums NOTIFY searchResultChanged)
    Q_PROPERTY(AlbumModel* searchArtists READ searchArtists NOTIFY searchResultChanged)
    Q_PROPERTY(QString searchKeyword READ searchKeyword NOTIFY searchKeywordChanged)
    Q_PROPERTY(bool isSearching READ isSearching NOTIFY isSearchingChanged)
    Q_PROPERTY(int searchTotalMatches READ searchTotalMatches NOTIFY searchResultChanged)
    Q_PROPERTY(TrackModel* queueModel READ queueModel CONSTANT)
    Q_PROPERTY(TrackModel* playedModel READ playedModel CONSTANT)
    Q_PROPERTY(TrackModel* nextModel READ nextModel CONSTANT)
    Q_PROPERTY(PlaylistModel* playlists READ playlistsModel CONSTANT)
    Q_PROPERTY(TrackModel* playlistTracks READ playlistTracksModel NOTIFY playlistTracksChanged)
    Q_PROPERTY(int playlistCount READ playlistCount NOTIFY playlistsChanged)
    Q_PROPERTY(QString currentPlaylistId READ currentPlaylistId NOTIFY currentPlaylistChanged)
    Q_PROPERTY(QString currentPlaylistName READ currentPlaylistName NOTIFY currentPlaylistChanged)
    Q_PROPERTY(QString currentPlaylistCoverUrl READ currentPlaylistCoverUrl NOTIFY currentPlaylistChanged)
    Q_PROPERTY(bool currentPlaylistIsFavorites READ currentPlaylistIsFavorites NOTIFY currentPlaylistChanged)
    Q_PROPERTY(int favoriteCount READ favoriteCount NOTIFY favoritesChanged)

public:
    static LibraryManager* instance();

    int trackCount() const { return static_cast<int>(m_allTracks.size()); }
    bool isScanning() const { return m_isScanning; }
    int scannedCount() const { return m_scannedCount; }
    TrackModel* recommendedTracks() const { return m_recommendedTracksModel; }
    AlbumModel* recommendedAlbums() const { return m_recommendedAlbumsModel; }
    TrackModel* allTracks() const { return m_allTracksModel; }
    AlbumModel* allAlbums() const { return m_allAlbumsModel; }
    AlbumModel* allArtists() const { return m_allArtistsModel; }
    AlbumModel* allFolders() const { return m_allFoldersModel; }
    TrackModel* filteredTracks() const { return m_filteredTracksModel; }
    AlbumModel* artistAlbums() const { return m_artistAlbumsModel; }
    TrackModel* searchTracks() const { return m_searchTracksModel; }
    AlbumModel* searchAlbums() const { return m_searchAlbumsModel; }
    AlbumModel* searchArtists() const { return m_searchArtistsModel; }
    QString searchKeyword() const { return m_searchKeyword; }
    bool isSearching() const { return m_isSearching; }
    int searchTotalMatches() const;

    PlaylistModel* playlistsModel() const { return m_playlistsModel; }
    TrackModel* playlistTracksModel() const { return m_playlistTracksModel; }
    int playlistCount() const { return m_playlistsModel ? m_playlistsModel->count() : 0; }
    QString currentPlaylistId() const { return m_currentPlaylistId; }
    QString currentPlaylistName() const { return m_currentPlaylistName; }
    QString currentPlaylistCoverUrl() const { return m_currentPlaylistCoverUrl; }
    bool currentPlaylistIsFavorites() const { return m_currentPlaylistIsFavorites; }
    int favoriteCount() const { return m_favorites.size(); }

    Q_INVOKABLE void openFolderDialog();
    Q_INVOKABLE void scanFolder(const QString &folderPath);
    Q_INVOKABLE void scanFolders(const QStringList &folderPaths);
    Q_INVOKABLE void cancelScan();
    Q_INVOKABLE void refreshRecommendations();
    Q_INVOKABLE void playRecommendedTrack(int index);
    Q_INVOKABLE void playRecommendedAlbum(int index);
    Q_INVOKABLE void clearLibrary();
    Q_INVOKABLE void setLibraryTracks(const QList<TrackItem> &tracks);
    Q_INVOKABLE TrackItem getTrackMetadata(const QString &filePath);
    Q_INVOKABLE QStringList allTrackPaths() const;

    void loadLibraryCache();
    void saveLibraryCache();
    static void parseMetadataItem(TrackItem &item);
    Q_INVOKABLE static QStringList splitArtists(const QString &artistStr);

    // Library View & Drill-Down Filtering
    Q_INVOKABLE void filterTracksByAlbum(const QString &albumName, const QString &artist = QString());
    Q_INVOKABLE void filterTracksByArtist(const QString &artistName);
    Q_INVOKABLE void filterTracksByFolder(const QString &folderPath);

    // Search Methods
    Q_INVOKABLE void search(const QString &keyword);
    Q_INVOKABLE void clearSearch();

    // Sorting
    Q_INVOKABLE void sortTracks(const QString &sortKey);
    Q_INVOKABLE void sortAlbums(const QString &sortKey);
    Q_INVOKABLE void sortArtists(const QString &sortKey);
    Q_INVOKABLE void sortFolders(const QString &sortKey);
    Q_INVOKABLE void sortPlaylistTracks(const QString &sortKey);

    // Playback integration
    Q_INVOKABLE void playTrack(const QString &filePath, const QStringList &queuePaths = QStringList());
    Q_INVOKABLE void playAlbum(const QString &albumName, const QString &artist = QString());
    Q_INVOKABLE void playArtist(const QString &artistName);
    Q_INVOKABLE void playFolder(const QString &folderPath);
    Q_INVOKABLE QStringList getTrackPaths(TrackModel *model = nullptr) const;

    // Queue integration
    TrackModel* queueModel() const;
    TrackModel* playedModel() const;
    TrackModel* nextModel() const;
    Q_INVOKABLE void clearQueue(bool keepCurrent = true);
    Q_INVOKABLE void removeFromQueue(int index);
    Q_INVOKABLE void moveQueueItem(int from, int to);
    Q_INVOKABLE void shuffleQueue();
    Q_INVOKABLE void playQueueIndex(int index);

    // Playlist & Favorites integration
    Q_INVOKABLE QString createPlaylist(const QString &name);
    Q_INVOKABLE QString createPlaylistWithTracks(const QString &name, const QStringList &trackPaths);
    Q_INVOKABLE void deletePlaylist(const QString &id);
    Q_INVOKABLE void renamePlaylist(const QString &id, const QString &newName);
    Q_INVOKABLE void addTrackToPlaylist(const QString &playlistId, const QString &trackPath);
    Q_INVOKABLE void removeTrackFromPlaylist(const QString &playlistId, const QString &trackPath);
    Q_INVOKABLE void removeTracksFromPlaylist(const QString &playlistId, const QStringList &trackPaths);
    Q_INVOKABLE void selectPlaylist(const QString &id);
    Q_INVOKABLE void clearSelectedPlaylist();
    Q_INVOKABLE void playPlaylist(const QString &id, bool shuffle = false);
    Q_INVOKABLE void toggleFavorite(const QString &trackPath);
    Q_INVOKABLE bool isFavorite(const QString &trackPath) const;
    Q_INVOKABLE void toggleFavorites(const QStringList &trackPaths);
    Q_INVOKABLE void insertTracksToQueue(const QStringList &trackPaths);
    Q_INVOKABLE void addTracksToPlaylist(const QString &playlistId, const QStringList &trackPaths);
    Q_INVOKABLE void showInExplorer(const QString &trackPath);
    Q_INVOKABLE QVariantMap getTrackDetails(const QString &trackPath);
    Q_INVOKABLE void removeTracksFromLibrary(const QStringList &trackPaths);

signals:
    void trackCountChanged();
    void isScanningChanged();
    void scannedCountChanged();
    void recommendedTracksChanged();
    void recommendedAlbumsChanged();
    void allTracksChanged();
    void allAlbumsChanged();
    void allArtistsChanged();
    void allFoldersChanged();
    void filteredTracksChanged();
    void artistAlbumsChanged();
    void searchResultChanged();
    void searchKeywordChanged();
    void isSearchingChanged();
    void trackPlaybackRequested(const QString &path, const QString &title, const QString &artist);
    void playlistsChanged();
    void playlistTracksChanged();
    void currentPlaylistChanged();
    void favoritesChanged();

private slots:
    void onScanBatchReady(const QList<TrackItem> &batch, int totalScanned);
    void onScanFinished(const QList<TrackItem> &allTracks);

private:
    explicit LibraryManager(QObject *parent = nullptr);
    ~LibraryManager() override;

    void generateRecommendations();
    void rebuildLibraryModels();
    void parseMetadata(TrackItem &item);
    void loadPlaylists();
    void savePlaylists();
    void loadFavorites();
    void saveFavorites();
    void refreshPlaylistCovers();

    QList<TrackItem> m_allTracks;
    TrackModel *m_recommendedTracksModel{nullptr};
    AlbumModel *m_recommendedAlbumsModel{nullptr};
    TrackModel *m_allTracksModel{nullptr};
    AlbumModel *m_allAlbumsModel{nullptr};
    AlbumModel *m_allArtistsModel{nullptr};
    AlbumModel *m_allFoldersModel{nullptr};
    TrackModel *m_filteredTracksModel{nullptr};
    AlbumModel *m_artistAlbumsModel{nullptr};
    TrackModel *m_searchTracksModel{nullptr};
    AlbumModel *m_searchAlbumsModel{nullptr};
    AlbumModel *m_searchArtistsModel{nullptr};
    PlaylistModel *m_playlistsModel{nullptr};
    TrackModel *m_playlistTracksModel{nullptr};
    QStringList m_favorites;
    QString m_currentPlaylistId;
    QString m_currentPlaylistName;
    QString m_currentPlaylistCoverUrl;
    bool m_currentPlaylistIsFavorites{false};
    QString m_searchKeyword;
    bool m_isSearching{false};
    QPointer<QThread> m_scanThread;
    class LibraryScanWorker *m_scanWorker{nullptr};
    int m_scannedCount{0};
    bool m_isScanning{false};
};
