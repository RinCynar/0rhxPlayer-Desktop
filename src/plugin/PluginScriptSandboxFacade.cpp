#include "PluginScriptSandboxFacade.h"
#include "PluginManager.h"
#include "../audio/AudioEngine.h"
#include "../library/LibraryManager.h"
#include <QJSEngine>
#include <QDebug>

PluginScriptSandboxFacade::PluginScriptSandboxFacade(const QString &pluginId, PluginManager *manager, QObject *parent)
    : QObject(parent)
    , m_pluginId(pluginId)
    , m_manager(manager)
{
}

bool PluginScriptSandboxFacade::verifyPermission(const QString &requiredPermission, const QString &actionName)
{
    if (!m_manager) return false;
    if (m_manager->hasPermission(m_pluginId, requiredPermission)) {
        return true;
    }

    QString msg = QString("SecurityError: Plugin '%1' denied permission '%2' for action '%3'")
                      .arg(m_pluginId, requiredPermission, actionName);
    m_manager->reportSecurityViolation(m_pluginId, requiredPermission, actionName);

    QJSEngine *engine = qjsEngine(this);
    if (engine) {
        engine->throwError(QJSValue::GenericError, msg);
    }
    return false;
}

bool PluginScriptSandboxFacade::runProcess(const QString &program, const QVariant &arguments, const QString &workingDir)
{
    if (!verifyPermission("system:process:execute", "runProcess (" + program + ")")) {
        return false;
    }
    return m_manager->runProcess(program, arguments, workingDir);
}

QString PluginScriptSandboxFacade::startAsyncTask(const QString &program, const QVariant &arguments, const QString &workingDir, const QVariantMap &meta)
{
    if (!verifyPermission("system:process:execute", "startAsyncTask (" + program + ")")) {
        return QString();
    }
    return m_manager->startAsyncTask(m_pluginId, program, arguments, workingDir, meta);
}

QString PluginScriptSandboxFacade::createPlaylist(const QString &name, const QStringList &trackPaths)
{
    if (!verifyPermission("library:write", "createPlaylist")) {
        return QString();
    }
    return m_manager->createPlaylist(name, trackPaths);
}

bool PluginScriptSandboxFacade::deletePlaylist(const QString &playlistId)
{
    if (!verifyPermission("library:write", "deletePlaylist")) {
        return false;
    }
    return m_manager->deletePlaylist(playlistId);
}

bool PluginScriptSandboxFacade::renamePlaylist(const QString &playlistId, const QString &newName)
{
    if (!verifyPermission("library:write", "renamePlaylist")) {
        return false;
    }
    return m_manager->renamePlaylist(playlistId, newName);
}

bool PluginScriptSandboxFacade::addTracksToPlaylist(const QString &playlistId, const QStringList &trackPaths)
{
    if (!verifyPermission("library:write", "addTracksToPlaylist")) {
        return false;
    }
    return m_manager->addTracksToPlaylist(playlistId, trackPaths);
}

bool PluginScriptSandboxFacade::removeTracksFromPlaylist(const QString &playlistId, const QStringList &trackPaths)
{
    if (!verifyPermission("library:write", "removeTracksFromPlaylist")) {
        return false;
    }
    return m_manager->removeTracksFromPlaylist(playlistId, trackPaths);
}

void PluginScriptSandboxFacade::rescanLibrary()
{
    if (!verifyPermission("library:write", "rescanLibrary")) {
        return;
    }
    m_manager->rescanLibrary();
}

void PluginScriptSandboxFacade::setFavorite(const QString &trackPath, bool favorite)
{
    if (!verifyPermission("library:write", "setFavorite")) {
        return;
    }
    m_manager->setFavorite(trackPath, favorite);
}

void PluginScriptSandboxFacade::toggleFavorite(const QString &trackPath)
{
    if (!verifyPermission("library:write", "toggleFavorite")) {
        return;
    }
    m_manager->toggleFavorite(trackPath);
}

void PluginScriptSandboxFacade::play(const QString &filePath)
{
    if (!verifyPermission("audio:control", "play")) {
        return;
    }
    m_manager->play(filePath);
}

void PluginScriptSandboxFacade::pause()
{
    if (!verifyPermission("audio:control", "pause")) {
        return;
    }
    m_manager->pause();
}

void PluginScriptSandboxFacade::resume()
{
    if (!verifyPermission("audio:control", "resume")) {
        return;
    }
    m_manager->resume();
}

void PluginScriptSandboxFacade::stop()
{
    if (!verifyPermission("audio:control", "stop")) {
        return;
    }
    m_manager->stop();
}

void PluginScriptSandboxFacade::seek(qint64 positionMs)
{
    if (!verifyPermission("audio:control", "seek")) {
        return;
    }
    m_manager->seek(positionMs);
}

void PluginScriptSandboxFacade::setVolume(float volume)
{
    if (!verifyPermission("audio:control", "setVolume")) {
        return;
    }
    m_manager->setVolume(volume);
}

void PluginScriptSandboxFacade::setPlayMode(int mode)
{
    if (!verifyPermission("audio:control", "setPlayMode")) {
        return;
    }
    m_manager->setPlayMode(mode);
}

void PluginScriptSandboxFacade::playNext()
{
    if (!verifyPermission("audio:control", "playNext")) {
        return;
    }
    m_manager->playNext();
}

void PluginScriptSandboxFacade::playPrevious()
{
    if (!verifyPermission("audio:control", "playPrevious")) {
        return;
    }
    m_manager->playPrevious();
}

void PluginScriptSandboxFacade::setQueue(const QStringList &trackPaths, int startIndex)
{
    if (!verifyPermission("audio:control", "setQueue")) {
        return;
    }
    m_manager->setQueue(trackPaths, startIndex);
}

void PluginScriptSandboxFacade::addToQueue(const QString &filePath)
{
    if (!verifyPermission("audio:control", "addToQueue")) {
        return;
    }
    m_manager->addToQueue(filePath);
}

void PluginScriptSandboxFacade::insertTracksNext(const QStringList &trackPaths)
{
    if (!verifyPermission("audio:control", "insertTracksNext")) {
        return;
    }
    m_manager->insertTracksNext(trackPaths);
}

void PluginScriptSandboxFacade::clearQueue(bool keepCurrent)
{
    if (!verifyPermission("audio:control", "clearQueue")) {
        return;
    }
    m_manager->clearQueue(keepCurrent);
}

void PluginScriptSandboxFacade::removeFromQueue(int index)
{
    if (!verifyPermission("audio:control", "removeFromQueue")) {
        return;
    }
    m_manager->removeFromQueue(index);
}

void PluginScriptSandboxFacade::moveQueueItem(int from, int to)
{
    if (!verifyPermission("audio:control", "moveQueueItem")) {
        return;
    }
    m_manager->moveQueueItem(from, to);
}

void PluginScriptSandboxFacade::shuffleQueue()
{
    if (!verifyPermission("audio:control", "shuffleQueue")) {
        return;
    }
    m_manager->shuffleQueue();
}

bool PluginScriptSandboxFacade::loadLrcContent(const QString &lrcContent)
{
    if (!verifyPermission("lyrics:write", "loadLrcContent")) {
        return false;
    }
    return m_manager->loadLrcContent(lrcContent);
}

void PluginScriptSandboxFacade::clearLyrics()
{
    if (!verifyPermission("lyrics:write", "clearLyrics")) {
        return;
    }
    m_manager->clearLyrics();
}

QString PluginScriptSandboxFacade::getAppVersion() const { return m_manager ? m_manager->getAppVersion() : QString(); }
QString PluginScriptSandboxFacade::getAppLanguage() const { return m_manager ? m_manager->getAppLanguage() : QString(); }
QString PluginScriptSandboxFacade::getThemeMode() const { return m_manager ? m_manager->getThemeMode() : QString(); }
QString PluginScriptSandboxFacade::getSeedColor() const { return m_manager ? m_manager->getSeedColor() : QString(); }
QString PluginScriptSandboxFacade::getPluginDataDir() const { return m_manager ? m_manager->getPluginDataDir(m_pluginId) : QString(); }
bool PluginScriptSandboxFacade::isWindowActive() const { return m_manager ? m_manager->isWindowActive() : false; }
float PluginScriptSandboxFacade::getVolume() const { return m_manager ? m_manager->getVolume() : 1.0f; }
int PluginScriptSandboxFacade::getPlaybackState() const { return m_manager ? m_manager->getPlaybackState() : 0; }
qint64 PluginScriptSandboxFacade::getPositionMs() const { return m_manager ? m_manager->getPositionMs() : 0; }
qint64 PluginScriptSandboxFacade::getDurationMs() const { return m_manager ? m_manager->getDurationMs() : 0; }
QString PluginScriptSandboxFacade::getCurrentTrack() const { return m_manager ? m_manager->getCurrentTrack() : QString(); }
QVariantMap PluginScriptSandboxFacade::getCurrentMetadata() const { return m_manager ? m_manager->getCurrentMetadata() : QVariantMap(); }
int PluginScriptSandboxFacade::getPlayMode() const { return m_manager ? m_manager->getPlayMode() : 0; }
QVariantList PluginScriptSandboxFacade::getQueue() const { return m_manager ? m_manager->getQueue() : QVariantList(); }
int PluginScriptSandboxFacade::getQueueCount() const { return m_manager ? m_manager->getQueueCount() : 0; }
int PluginScriptSandboxFacade::getCurrentQueueIndex() const { return m_manager ? m_manager->getCurrentQueueIndex() : 0; }

int PluginScriptSandboxFacade::getLibraryTrackCount() const { return m_manager ? m_manager->getLibraryTrackCount() : 0; }
QStringList PluginScriptSandboxFacade::getAllTrackPaths() const { return m_manager ? m_manager->getAllTrackPaths() : QStringList(); }
QVariantList PluginScriptSandboxFacade::getAllTracks(int limit, int offset) const { return m_manager ? m_manager->getAllTracks(limit, offset) : QVariantList(); }
QVariantMap PluginScriptSandboxFacade::getTrackDetails(const QString &filePath) const { return m_manager ? m_manager->getTrackDetails(filePath) : QVariantMap(); }
QVariantList PluginScriptSandboxFacade::getAllAlbums() const { return m_manager ? m_manager->getAllAlbums() : QVariantList(); }
QVariantList PluginScriptSandboxFacade::getAllArtists() const { return m_manager ? m_manager->getAllArtists() : QVariantList(); }
QVariantList PluginScriptSandboxFacade::getAlbumTracks(const QString &albumName, const QString &artist) const { return m_manager ? m_manager->getAlbumTracks(albumName, artist) : QVariantList(); }
QVariantList PluginScriptSandboxFacade::getArtistTracks(const QString &artistName) const { return m_manager ? m_manager->getArtistTracks(artistName) : QVariantList(); }
QVariantMap PluginScriptSandboxFacade::searchLibrary(const QString &keyword) const { return m_manager ? m_manager->searchLibrary(keyword) : QVariantMap(); }
bool PluginScriptSandboxFacade::isScanningLibrary() const { return m_manager ? m_manager->isScanningLibrary() : false; }
bool PluginScriptSandboxFacade::isFavorite(const QString &trackPath) const { return m_manager ? m_manager->isFavorite(trackPath) : false; }
int PluginScriptSandboxFacade::getFavoriteCount() const { return m_manager ? m_manager->getFavoriteCount() : 0; }
QStringList PluginScriptSandboxFacade::getFavoriteTracks() const { return m_manager ? m_manager->getFavoriteTracks() : QStringList(); }
QVariantList PluginScriptSandboxFacade::getAllPlaylists() const { return m_manager ? m_manager->getAllPlaylists() : QVariantList(); }
QVariantList PluginScriptSandboxFacade::getPlaylistTracks(const QString &playlistId) const { return m_manager ? m_manager->getPlaylistTracks(playlistId) : QVariantList(); }

bool PluginScriptSandboxFacade::hasLyrics() const { return m_manager ? m_manager->hasLyrics() : false; }
bool PluginScriptSandboxFacade::hasLyricTranslation() const { return m_manager ? m_manager->hasLyricTranslation() : false; }
int PluginScriptSandboxFacade::getLyricCount() const { return m_manager ? m_manager->getLyricCount() : 0; }
int PluginScriptSandboxFacade::getCurrentLyricIndex() const { return m_manager ? m_manager->getCurrentLyricIndex() : 0; }
QVariantList PluginScriptSandboxFacade::getAllLyrics() const { return m_manager ? m_manager->getAllLyrics() : QVariantList(); }
QVariantMap PluginScriptSandboxFacade::getLyricLine(int index) const { return m_manager ? m_manager->getLyricLine(index) : QVariantMap(); }

void PluginScriptSandboxFacade::showToast(const QString &message)
{
    if (m_manager) m_manager->showToast(message);
}

void PluginScriptSandboxFacade::notifyViewChanged()
{
    if (m_manager) m_manager->notifyViewChanged(m_pluginId);
}

QVariant PluginScriptSandboxFacade::getPluginState(const QString &key, const QVariant &defaultValue) const
{
    return m_manager ? m_manager->getPluginState(m_pluginId, key, defaultValue) : defaultValue;
}

void PluginScriptSandboxFacade::setPluginState(const QString &key, const QVariant &value)
{
    if (m_manager) m_manager->setPluginState(m_pluginId, key, value);
}

QVariantMap PluginScriptSandboxFacade::getAllPluginState() const
{
    return m_manager ? m_manager->getAllPluginState(m_pluginId) : QVariantMap();
}

void PluginScriptSandboxFacade::registerPluginObject(const QJSValue &object)
{
    if (m_manager) m_manager->registerPluginObject(m_pluginId, object);
}

QVariantList PluginScriptSandboxFacade::getPluginQueue(const QString &pluginId) const
{
    QString pid = pluginId.isEmpty() ? m_pluginId : pluginId;
    return m_manager ? m_manager->getPluginQueue(pid) : QVariantList();
}

void PluginScriptSandboxFacade::clearPluginQueue(const QString &pluginId)
{
    QString pid = pluginId.isEmpty() ? m_pluginId : pluginId;
    if (m_manager) m_manager->clearPluginQueue(pid);
}

QVariantList PluginScriptSandboxFacade::fetchLyricsCandidates(const QString &title, const QString &artist, qint64 durationMs)
{
    return m_manager ? m_manager->fetchLyricsCandidates(title, artist, durationMs) : QVariantList();
}

bool PluginScriptSandboxFacade::applyLyricCandidate(const QVariantMap &candidate)
{
    if (!verifyPermission("lyrics:write", "applyLyricCandidate")) {
        return false;
    }
    return m_manager ? m_manager->applyLyricCandidate(candidate) : false;
}

QVariantMap PluginScriptSandboxFacade::fetchMetadataCandidates(const QString &filePath, const QVariantMap &currentMeta)
{
    return m_manager ? m_manager->fetchMetadataCandidates(filePath, currentMeta) : QVariantMap();
}

bool PluginScriptSandboxFacade::applyTrackMetadata(const QString &filePath, const QVariantMap &tags)
{
    if (!verifyPermission("library:write", "applyTrackMetadata")) {
        return false;
    }
    return m_manager ? m_manager->applyTrackMetadata(filePath, tags) : false;
}

QVariantList PluginScriptSandboxFacade::searchMediaSource(const QString &query)
{
    return m_manager ? m_manager->searchMediaSource(query) : QVariantList();
}

QString PluginScriptSandboxFacade::resolveMediaStream(const QString &pluginId, const QString &mediaId, const QVariantMap &extraParams)
{
    return m_manager ? m_manager->resolveMediaStream(pluginId, mediaId, extraParams) : QString();
}

bool PluginScriptSandboxFacade::playPluginMedia(const QString &pluginId, const QString &mediaId, const QVariantMap &trackMeta)
{
    if (!verifyPermission("audio:control", "playPluginMedia")) {
        return false;
    }
    return m_manager ? m_manager->playPluginMedia(pluginId, mediaId, trackMeta) : false;
}
