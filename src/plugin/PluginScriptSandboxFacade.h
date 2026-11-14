#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QJSValue>

class PluginManager;
class QJSEngine;

class PluginScriptSandboxFacade : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString pluginId READ pluginId CONSTANT)

public:
    explicit PluginScriptSandboxFacade(const QString &pluginId, PluginManager *manager, QObject *parent = nullptr);
    ~PluginScriptSandboxFacade() override = default;

    QString pluginId() const { return m_pluginId; }

    // Intercepted process execution APIs (requires 'system:process:execute')
    Q_INVOKABLE bool runProcess(const QString &program, const QVariant &arguments = QVariant(), const QString &workingDir = QString());
    Q_INVOKABLE QString startAsyncTask(const QString &program, const QVariant &arguments = QVariant(), const QString &workingDir = QString(), const QVariantMap &meta = QVariantMap());

    // Intercepted media library mutation APIs (requires 'library:write')
    Q_INVOKABLE QString createPlaylist(const QString &name, const QStringList &trackPaths = QStringList());
    Q_INVOKABLE bool deletePlaylist(const QString &playlistId);
    Q_INVOKABLE bool renamePlaylist(const QString &playlistId, const QString &newName);
    Q_INVOKABLE bool addTracksToPlaylist(const QString &playlistId, const QStringList &trackPaths);
    Q_INVOKABLE bool removeTracksFromPlaylist(const QString &playlistId, const QStringList &trackPaths);
    Q_INVOKABLE void rescanLibrary();
    Q_INVOKABLE void setFavorite(const QString &trackPath, bool favorite);
    Q_INVOKABLE void toggleFavorite(const QString &trackPath);

    // Intercepted audio playback mutation APIs (requires 'audio:control')
    Q_INVOKABLE void play(const QString &filePath = QString());
    Q_INVOKABLE void pause();
    Q_INVOKABLE void resume();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void seek(qint64 positionMs);
    Q_INVOKABLE void setVolume(float volume);
    Q_INVOKABLE void setPlayMode(int mode);
    Q_INVOKABLE void playNext();
    Q_INVOKABLE void playPrevious();
    Q_INVOKABLE void setQueue(const QStringList &trackPaths, int startIndex = 0);
    Q_INVOKABLE void addToQueue(const QString &filePath);
    Q_INVOKABLE void insertTracksNext(const QStringList &trackPaths);
    Q_INVOKABLE void clearQueue(bool keepCurrent = true);
    Q_INVOKABLE void removeFromQueue(int index);
    Q_INVOKABLE void moveQueueItem(int from, int to);
    Q_INVOKABLE void shuffleQueue();

    // Intercepted lyrics mutation APIs (requires 'lyrics:write')
    Q_INVOKABLE bool loadLrcContent(const QString &lrcContent);
    Q_INVOKABLE void clearLyrics();

    // Safe read-only APIs forwarded to Host
    Q_INVOKABLE QString getAppVersion() const;
    Q_INVOKABLE QString getAppLanguage() const;
    Q_INVOKABLE QString getThemeMode() const;
    Q_INVOKABLE QString getSeedColor() const;
    Q_INVOKABLE QString getPluginDataDir() const;
    Q_INVOKABLE bool isWindowActive() const;
    Q_INVOKABLE float getVolume() const;
    Q_INVOKABLE int getPlaybackState() const;
    Q_INVOKABLE qint64 getPositionMs() const;
    Q_INVOKABLE qint64 getDurationMs() const;
    Q_INVOKABLE QString getCurrentTrack() const;
    Q_INVOKABLE QVariantMap getCurrentMetadata() const;
    Q_INVOKABLE int getPlayMode() const;
    Q_INVOKABLE QVariantList getQueue() const;
    Q_INVOKABLE int getQueueCount() const;
    Q_INVOKABLE int getCurrentQueueIndex() const;

    Q_INVOKABLE int getLibraryTrackCount() const;
    Q_INVOKABLE QStringList getAllTrackPaths() const;
    Q_INVOKABLE QVariantList getAllTracks(int limit = -1, int offset = 0) const;
    Q_INVOKABLE QVariantMap getTrackDetails(const QString &filePath) const;
    Q_INVOKABLE QVariantList getAllAlbums() const;
    Q_INVOKABLE QVariantList getAllArtists() const;
    Q_INVOKABLE QVariantList getAlbumTracks(const QString &albumName, const QString &artist = QString()) const;
    Q_INVOKABLE QVariantList getArtistTracks(const QString &artistName) const;
    Q_INVOKABLE QVariantMap searchLibrary(const QString &keyword) const;
    Q_INVOKABLE bool isScanningLibrary() const;
    Q_INVOKABLE bool isFavorite(const QString &trackPath) const;
    Q_INVOKABLE int getFavoriteCount() const;
    Q_INVOKABLE QStringList getFavoriteTracks() const;
    Q_INVOKABLE QVariantList getAllPlaylists() const;
    Q_INVOKABLE QVariantList getPlaylistTracks(const QString &playlistId) const;

    Q_INVOKABLE bool hasLyrics() const;
    Q_INVOKABLE bool hasLyricTranslation() const;
    Q_INVOKABLE int getLyricCount() const;
    Q_INVOKABLE int getCurrentLyricIndex() const;
    Q_INVOKABLE QVariantList getAllLyrics() const;
    Q_INVOKABLE QVariantMap getLyricLine(int index) const;

    // Phase 22: Full Hook Pipeline Integration APIs
    Q_INVOKABLE QVariantList fetchLyricsCandidates(const QString &title, const QString &artist, qint64 durationMs = 0);
    Q_INVOKABLE bool applyLyricCandidate(const QVariantMap &candidate);
    Q_INVOKABLE QVariantMap fetchMetadataCandidates(const QString &filePath, const QVariantMap &currentMeta = QVariantMap());
    Q_INVOKABLE bool applyTrackMetadata(const QString &filePath, const QVariantMap &tags);
    Q_INVOKABLE QVariantList searchMediaSource(const QString &query);
    Q_INVOKABLE QString resolveMediaStream(const QString &pluginId, const QString &mediaId, const QVariantMap &extraParams = QVariantMap());
    Q_INVOKABLE bool playPluginMedia(const QString &pluginId, const QString &mediaId, const QVariantMap &trackMeta = QVariantMap());

    // View slot & Toast APIs
    Q_INVOKABLE void showToast(const QString &message);
    Q_INVOKABLE void notifyViewChanged();

    // Plugin-scoped State Store APIs
    Q_INVOKABLE QVariant getPluginState(const QString &key, const QVariant &defaultValue = QVariant()) const;
    Q_INVOKABLE void setPluginState(const QString &key, const QVariant &value);
    Q_INVOKABLE QVariantMap getAllPluginState() const;
    Q_INVOKABLE void registerPluginObject(const QJSValue &object);
    Q_INVOKABLE QVariantList getPluginQueue(const QString &pluginId = QString()) const;
    Q_INVOKABLE void clearPluginQueue(const QString &pluginId = QString());

private:
    bool verifyPermission(const QString &requiredPermission, const QString &actionName);

    QString m_pluginId;
    PluginManager *m_manager = nullptr;
};
