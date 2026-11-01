#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QJsonObject>
#include <QJsonArray>
#include <QMap>
#include <QPointer>

class QNetworkAccessManager;
class QNetworkReply;

struct PluginMetadata {
    QString id;
    QString name;
    QString version;
    QString author;
    QString description;
    QString category = "Other";
    QString homepage;
    QString icon;
    QString packageUrl;
    QString minAppVersion;
    QStringList permissions;
    bool enabled = true;
    bool installed = false;
    QString localDir;
    QJsonObject sidebar;
    QJsonObject hooks;
    QJsonObject entries;

    QVariantMap toMap() const;
    static PluginMetadata fromJson(const QJsonObject &obj);

    static bool isOfficialPluginId(const QString &id) {
        return id.startsWith("top.rincynar.");
    }
};

class PluginManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList installedPlugins READ installedPlugins NOTIFY pluginsChanged)
    Q_PROPERTY(QVariantList marketPlugins READ marketPlugins NOTIFY marketPluginsChanged)
    Q_PROPERTY(QStringList categories READ categories NOTIFY categoriesChanged)
    Q_PROPERTY(bool isFetchingMarket READ isFetchingMarket NOTIFY fetchingMarketChanged)
    Q_PROPERTY(QString marketStatusMessage READ marketStatusMessage NOTIFY marketStatusMessageChanged)
    Q_PROPERTY(QString lastErrorMessage READ lastErrorMessage NOTIFY errorOccurred)

public:
    static PluginManager *instance();

    explicit PluginManager(QObject *parent = nullptr);
    ~PluginManager() override;

    void initialize();

    QVariantList installedPlugins() const;
    QVariantList marketPlugins() const;
    QStringList categories() const;
    bool isFetchingMarket() const { return m_isFetchingMarket; }
    QString marketStatusMessage() const { return m_marketStatusMessage; }
    QString lastErrorMessage() const { return m_lastErrorMessage; }

    Q_INVOKABLE void refreshInstalledPlugins();
    Q_INVOKABLE void fetchMarketIndex(const QString &customUrl = QString());
    Q_INVOKABLE bool parseIndexMarkdown(const QString &content);

    Q_INVOKABLE bool installPluginFrom0px(const QString &packagePath);
    Q_INVOKABLE void installPluginFromMarket(const QString &pluginId);
    Q_INVOKABLE bool uninstallPlugin(const QString &pluginId);

    Q_INVOKABLE void setPluginEnabled(const QString &pluginId, bool enabled);
    Q_INVOKABLE bool isPluginEnabled(const QString &pluginId) const;

    Q_INVOKABLE QVariantMap getPluginInfo(const QString &pluginId) const;
    Q_INVOKABLE QVariantMap getPluginViewSchema(const QString &pluginId, const QString &schemaPath = QString()) const;
    Q_INVOKABLE QVariantList executeSearchHook(const QString &query);
    Q_INVOKABLE QString getPluginAssetPath(const QString &pluginId, const QString &relPath) const;

    // Helper for testing and zip extraction
    static bool extractArchive(const QString &archivePath, const QString &destDir);

    // =========================================================================
    // Category 1: Audio Playback & Transport Control
    // =========================================================================
    Q_INVOKABLE void play(const QString &filePath = QString());
    Q_INVOKABLE void pause();
    Q_INVOKABLE void resume();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void seek(qint64 positionMs);
    Q_INVOKABLE void setVolume(float volume);
    Q_INVOKABLE float getVolume() const;
    Q_INVOKABLE int getPlaybackState() const;
    Q_INVOKABLE qint64 getPositionMs() const;
    Q_INVOKABLE qint64 getDurationMs() const;
    Q_INVOKABLE QString getCurrentTrack() const;
    Q_INVOKABLE QVariantMap getCurrentMetadata() const;
    Q_INVOKABLE int getPlayMode() const;
    Q_INVOKABLE void setPlayMode(int mode);
    Q_INVOKABLE void playNext();
    Q_INVOKABLE void playPrevious();

    // =========================================================================
    // Category 2: Equalizer & DSP Control
    // =========================================================================
    Q_INVOKABLE void setEqEnabled(bool enabled);
    Q_INVOKABLE bool isEqEnabled() const;
    Q_INVOKABLE void setEqPreamp(float preampDb);
    Q_INVOKABLE float getEqPreamp() const;
    Q_INVOKABLE void setEqBand(int index, float gainDb);
    Q_INVOKABLE QVariantList getEqBands() const;
    Q_INVOKABLE void applyEqPreset(const QString &presetName);
    Q_INVOKABLE void resetEq();
    Q_INVOKABLE QString getEqPreset() const;
    Q_INVOKABLE QStringList getEqPresetNames() const;

    // =========================================================================
    // Category 3: Playback Queue
    // =========================================================================
    Q_INVOKABLE QVariantList getQueue() const;
    Q_INVOKABLE int getQueueCount() const;
    Q_INVOKABLE int getCurrentQueueIndex() const;
    Q_INVOKABLE void playQueueIndex(int index);
    Q_INVOKABLE void setQueue(const QStringList &trackPaths, int startIndex = 0);
    Q_INVOKABLE void addToQueue(const QString &filePath);
    Q_INVOKABLE void insertTracksNext(const QStringList &trackPaths);
    Q_INVOKABLE void clearQueue(bool keepCurrent = true);
    Q_INVOKABLE void removeFromQueue(int index);
    Q_INVOKABLE void moveQueueItem(int from, int to);
    Q_INVOKABLE void shuffleQueue();

    // =========================================================================
    // Category 4: Media Library & Search
    // =========================================================================
    Q_INVOKABLE int getLibraryTrackCount() const;
    Q_INVOKABLE QStringList getAllTrackPaths() const;
    Q_INVOKABLE QVariantList getAllTracks(int limit = -1, int offset = 0) const;
    Q_INVOKABLE QVariantMap getTrackDetails(const QString &filePath) const;
    Q_INVOKABLE QVariantList getAllAlbums() const;
    Q_INVOKABLE QVariantList getAllArtists() const;
    Q_INVOKABLE QVariantList getAlbumTracks(const QString &albumName, const QString &artist = QString()) const;
    Q_INVOKABLE QVariantList getArtistTracks(const QString &artistName) const;
    Q_INVOKABLE QVariantMap searchLibrary(const QString &keyword) const;
    Q_INVOKABLE void rescanLibrary();
    Q_INVOKABLE bool isScanningLibrary() const;

    // =========================================================================
    // Category 5: Playlists & User Favorites
    // =========================================================================
    Q_INVOKABLE bool isFavorite(const QString &trackPath) const;
    Q_INVOKABLE void toggleFavorite(const QString &trackPath);
    Q_INVOKABLE void setFavorite(const QString &trackPath, bool favorite);
    Q_INVOKABLE int getFavoriteCount() const;
    Q_INVOKABLE QStringList getFavoriteTracks() const;
    Q_INVOKABLE QVariantList getAllPlaylists() const;
    Q_INVOKABLE QVariantList getPlaylistTracks(const QString &playlistId) const;
    Q_INVOKABLE QString createPlaylist(const QString &name, const QStringList &trackPaths = QStringList());
    Q_INVOKABLE bool deletePlaylist(const QString &playlistId);
    Q_INVOKABLE bool renamePlaylist(const QString &playlistId, const QString &newName);
    Q_INVOKABLE bool addTracksToPlaylist(const QString &playlistId, const QStringList &trackPaths);
    Q_INVOKABLE bool removeTracksFromPlaylist(const QString &playlistId, const QStringList &trackPaths);
    Q_INVOKABLE void playPlaylist(const QString &playlistId, bool shuffle = false);

    // =========================================================================
    // Category 6: Synchronized Lyrics
    // =========================================================================
    Q_INVOKABLE bool hasLyrics() const;
    Q_INVOKABLE bool hasLyricTranslation() const;
    Q_INVOKABLE int getLyricCount() const;
    Q_INVOKABLE int getCurrentLyricIndex() const;
    Q_INVOKABLE QVariantList getAllLyrics() const;
    Q_INVOKABLE QVariantMap getLyricLine(int index) const;
    Q_INVOKABLE bool loadLrcContent(const QString &lrcContent);
    Q_INVOKABLE void clearLyrics();

    // =========================================================================
    // Category 7: Application Environment & State
    // =========================================================================
    Q_INVOKABLE QString getAppVersion() const;
    Q_INVOKABLE QString getAppLanguage() const;
    Q_INVOKABLE QString getThemeMode() const;
    Q_INVOKABLE QString getSeedColor() const;
    Q_INVOKABLE QString getPluginDataDir(const QString &pluginId) const;
    Q_INVOKABLE bool isWindowActive() const;

    // =========================================================================
    // Category 8: View Slot Injections & Actions
    // =========================================================================
    Q_INVOKABLE QVariantList getInjectedMenuItems(const QString &slotType, const QVariantMap &contextData = QVariantMap()) const;
    Q_INVOKABLE QVariantList getInjectedPlaybackControls() const;
    Q_INVOKABLE void triggerPluginAction(const QString &pluginId, const QString &actionId, const QString &slotType, const QVariantMap &payload = QVariantMap());
    Q_INVOKABLE QVariantMap executePluginHook(const QString &hookType, const QVariantMap &params = QVariantMap());

signals:
    // Lifecycle & Marketplace Signals
    void pluginsChanged();
    void marketPluginsChanged();
    void categoriesChanged();
    void fetchingMarketChanged(bool isFetching);
    void marketStatusMessageChanged(const QString &msg);
    void errorOccurred(const QString &error);
    void pluginInstalled(const QString &pluginId);
    void pluginUninstalled(const QString &pluginId);
    void pluginStatusChanged(const QString &pluginId, bool enabled);
    void installProgress(const QString &pluginId, qint64 received, qint64 total);
    void installFinished(const QString &pluginId, bool success, const QString &message);

    // =========================================================================
    // Category 9: Host Full Lifecycle Event Bus
    // =========================================================================
    void playbackStateChanged(int state);
    void positionChanged(qint64 positionMs, qint64 durationMs);
    void trackChanged(const QVariantMap &trackInfo);
    void volumeChanged(float volume);
    void playModeChanged(int mode);
    void eqChanged();
    void queueChanged();
    void libraryChanged();
    void favoritesChanged(const QString &trackPath, bool isFavorite);
    void playlistsChanged();
    void lyricsChanged();
    void windowActiveChanged(bool active);
    void pluginActionTriggered(const QString &pluginId, const QString &actionId, const QString &slotType, const QVariantMap &data);

private:
    void loadInstalledPluginFromDir(const QString &dirPath);
    void updateSidebarItemForPlugin(const PluginMetadata &meta);
    void removeSidebarItemForPlugin(const QString &pluginId);
    void syncMarketInstalledState();
    void saveEnabledPluginsConfig();
    void loadEnabledPluginsConfig();
    QNetworkAccessManager *networkManager();

    QNetworkAccessManager *m_networkManager = nullptr;
    QMap<QString, PluginMetadata> m_installed;
    QList<PluginMetadata> m_market;
    QMap<QString, bool> m_enabledConfig;

    bool m_isFetchingMarket = false;
    QString m_marketStatusMessage;
    QString m_lastErrorMessage;
};
