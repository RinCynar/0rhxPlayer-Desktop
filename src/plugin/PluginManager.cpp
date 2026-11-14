#include "PluginManager.h"
#include "JsTimerBridge.h"
#include "../core/PathManager.h"
#include "../config/ConfigManager.h"
#include "../audio/AudioEngine.h"
#include "../library/LibraryManager.h"
#include "../model/TrackModel.h"
#include "../model/AlbumModel.h"
#include "../model/PlaylistModel.h"
#include "../model/LyricModel.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QProcess>
#include <QSettings>
#include <QStandardPaths>
#include <QRegularExpression>
#include <QUrl>
#include <QDateTime>
#include <QDebug>
#include <QJSEngine>
#include <QJSValue>
#include <algorithm>

QVariantMap PluginMetadata::toMap() const
{
    QVariantMap map;
    map["id"] = id;
    map["name"] = name;
    map["version"] = version;
    map["author"] = author;
    map["description"] = description;
    map["category"] = category;
    map["homepage"] = homepage;
    map["icon"] = icon;
    map["packageUrl"] = packageUrl;
    map["enabled"] = enabled;
    map["installed"] = installed;
    map["localDir"] = localDir;
    map["sidebar"] = sidebar.toVariantMap();
    map["hooks"] = hooks.toVariantMap();
    map["minAppVersion"] = minAppVersion;
    map["permissions"] = permissions;
    map["entries"] = entries.toVariantMap();
    return map;
}

PluginMetadata PluginMetadata::fromJson(const QJsonObject &obj)
{
    PluginMetadata m;
    m.id = obj["id"].toString().trimmed();
    m.name = obj["name"].toString().trimmed();
    m.version = obj["version"].toString().trimmed();
    m.author = obj["author"].toString().trimmed();
    m.description = obj["description"].toString().trimmed();
    m.category = obj["category"].toString().trimmed();
    if (m.category.isEmpty()) {
        m.category = "Other";
    }
    m.homepage = obj["homepage"].toString().trimmed();
    m.icon = obj["icon"].toString().trimmed();
    if (m.icon.isEmpty() && obj.contains("sidebar") && obj["sidebar"].isObject()) {
        m.icon = obj["sidebar"].toObject()["icon"].toString().trimmed();
    }
    if (m.icon.isEmpty() && obj.contains("entries") && obj["entries"].isObject()) {
        QJsonObject ent = obj["entries"].toObject();
        if (ent.contains("sidebar") && ent["sidebar"].isObject()) {
            m.icon = ent["sidebar"].toObject()["icon"].toString().trimmed();
        }
    }
    if (!m.icon.isEmpty() && !m.icon.startsWith("qrc:") && !m.icon.startsWith("http") && !m.icon.endsWith(".svg") && !m.icon.endsWith(".png")) {
        m.icon = "qrc:/assets/icons/plugin.svg";
    } else if (m.icon.isEmpty()) {
        m.icon = "qrc:/assets/icons/plugin.svg";
    }

    m.packageUrl = obj["packageUrl"].toString().trimmed();
    if (m.packageUrl.isEmpty()) {
        m.packageUrl = obj["path"].toString().trimmed();
    }
    if (m.packageUrl.isEmpty()) {
        m.packageUrl = obj["downloadUrl"].toString().trimmed();
    }
    if (m.packageUrl.isEmpty()) {
        m.packageUrl = obj["url"].toString().trimmed();
    }

    if (!m.packageUrl.isEmpty() && !m.packageUrl.startsWith("http://") && !m.packageUrl.startsWith("https://") && !m.packageUrl.startsWith("file://") && !m.packageUrl.startsWith("/") && !m.packageUrl.contains(":\\")) {
        QString baseSourceUrl = ConfigManager::instance()->pluginSource();
        int lastSlash = baseSourceUrl.lastIndexOf('/');
        QString baseUrl = (lastSlash != -1) ? baseSourceUrl.left(lastSlash + 1) : "https://raw.githubusercontent.com/RinCynar/0rhxPlayer-Plugins/main/";
        if (!baseUrl.endsWith('/')) baseUrl += '/';
        QString rel = m.packageUrl;
        while (rel.startsWith('/')) rel = rel.mid(1);
        m.packageUrl = baseUrl + rel;
    }

    if (obj.contains("enabled")) {
        m.enabled = obj["enabled"].toBool();
    }
    if (obj.contains("sidebar") && obj["sidebar"].isObject()) {
        m.sidebar = obj["sidebar"].toObject();
    }
    if (obj.contains("hooks") && obj["hooks"].isObject()) {
        m.hooks = obj["hooks"].toObject();
    }
    if (obj.contains("entries") && obj["entries"].isObject()) {
        m.entries = obj["entries"].toObject();
        if (m.sidebar.isEmpty() && m.entries.contains("sidebar") && m.entries["sidebar"].isObject()) {
            m.sidebar = m.entries["sidebar"].toObject();
        }
    }
    if (obj.contains("permissions") && obj["permissions"].isArray()) {
        for (const auto &p : obj["permissions"].toArray()) {
            m.permissions.append(p.toString().trimmed());
        }
    }
    if (obj.contains("minAppVersion")) {
        m.minAppVersion = obj["minAppVersion"].toString().trimmed();
    }
    return m;
}

PluginManager *PluginManager::instance()
{
    static PluginManager s_instance;
    return &s_instance;
}

PluginManager::PluginManager(QObject *parent)
    : QObject(parent)
{
    loadEnabledPluginsConfig();
}

PluginManager::~PluginManager()
{
    for (auto *eng : m_scriptEngines) {
        delete eng;
    }
    m_scriptEngines.clear();

    if (m_networkManager) {
        delete m_networkManager;
        m_networkManager = nullptr;
    }
}

QNetworkAccessManager *PluginManager::networkManager()
{
    if (!m_networkManager) {
        m_networkManager = new QNetworkAccessManager(this);
        if (qApp) {
            connect(qApp, &QCoreApplication::aboutToQuit, this, [this]() {
                if (m_networkManager) {
                    const auto replies = m_networkManager->findChildren<QNetworkReply*>();
                    for (auto *r : replies) {
                        r->abort();
                    }
                    delete m_networkManager;
                    m_networkManager = nullptr;
                }
            });
        }
    }
    return m_networkManager;
}

void PluginManager::initialize()
{
    if (m_initialized) return;
    m_initialized = true;

    refreshInstalledPlugins();

    auto *ae = AudioEngine::instance();
    auto *lm = LibraryManager::instance();

    if (ae) {
        connect(ae, &AudioEngine::playbackStateChanged, this, [this](AudioEngine::PlaybackState state) {
            emit playbackStateChanged(static_cast<int>(state));
        });
        connect(ae, &AudioEngine::positionChanged, this, [this](qint64 pos) {
            emit positionChanged(pos, AudioEngine::instance()->durationMs());
        });
        connect(ae, &AudioEngine::trackChanged, this, [this](const QString &path) {
            Q_UNUSED(path);
            emit trackChanged(getCurrentMetadata());
        });
        connect(ae, &AudioEngine::currentMetadataChanged, this, [this]() {
            emit trackChanged(getCurrentMetadata());
        });
        connect(ae, &AudioEngine::volumeChanged, this, &PluginManager::volumeChanged);
        connect(ae, &AudioEngine::playModeChanged, this, [this](AudioEngine::PlayMode mode) {
            emit playModeChanged(static_cast<int>(mode));
        });
        connect(ae, &AudioEngine::eqBandsChanged, this, &PluginManager::eqChanged);
        connect(ae, &AudioEngine::eqPresetChanged, this, &PluginManager::eqChanged);
        connect(ae, &AudioEngine::eqEnabledChanged, this, &PluginManager::eqChanged);
        connect(ae, &AudioEngine::queueChanged, this, &PluginManager::queueChanged);
        connect(ae, &AudioEngine::windowActiveChanged, this, [this]() {
            emit windowActiveChanged(AudioEngine::instance()->windowActive());
        });

        if (ae->lyrics()) {
            connect(ae->lyrics(), &LyricModel::countChanged, this, &PluginManager::lyricsChanged);
        }
    }

    if (lm) {
        connect(lm, &LibraryManager::allTracksChanged, this, &PluginManager::libraryChanged);
        connect(lm, &LibraryManager::favoritesChanged, this, [this]() {
            emit favoritesChanged(AudioEngine::instance()->currentTrack(), LibraryManager::instance()->isFavorite(AudioEngine::instance()->currentTrack()));
        });
        connect(lm, &LibraryManager::playlistsChanged, this, &PluginManager::playlistsChanged);
    }

    if (qApp) {
        connect(qApp, &QCoreApplication::aboutToQuit, this, [this]() {
            for (auto *eng : m_scriptEngines) {
                delete eng;
            }
            m_scriptEngines.clear();
        });
    }

    // Initialize script runtimes for all active installed plugins
    for (auto it = m_installed.cbegin(); it != m_installed.cend(); ++it) {
        if (it->enabled) {
            initPluginScriptEngine(it->id);
        }
    }
}

QStringList PluginManager::categories() const
{
    QStringList cats;
    cats.append("All");

    QStringList dynamicCats;
    // 1. Extract unique categories from current market plugins
    for (const auto &p : m_market) {
        QString c = p.category.trimmed();
        if (!c.isEmpty() && c.compare("All", Qt::CaseInsensitive) != 0 && c.compare("Installed", Qt::CaseInsensitive) != 0) {
            bool exists = false;
            for (const auto &existing : dynamicCats) {
                if (existing.compare(c, Qt::CaseInsensitive) == 0) {
                    exists = true;
                    break;
                }
            }
            if (!exists) {
                dynamicCats.append(c);
            }
        }
    }

    // 2. Extract unique categories from locally installed plugins
    for (const auto &p : m_installed) {
        QString c = p.category.trimmed();
        if (!c.isEmpty() && c.compare("All", Qt::CaseInsensitive) != 0 && c.compare("Installed", Qt::CaseInsensitive) != 0) {
            bool exists = false;
            for (const auto &existing : dynamicCats) {
                if (existing.compare(c, Qt::CaseInsensitive) == 0) {
                    exists = true;
                    break;
                }
            }
            if (!exists) {
                dynamicCats.append(c);
            }
        }
    }

    // Sort dynamic categories alphabetically for stable, deterministic ordering
    dynamicCats.sort(Qt::CaseInsensitive);

    cats.append(dynamicCats);
    cats.append("Installed");
    return cats;
}

QVariantList PluginManager::installedPlugins() const
{
    QVariantList list;
    for (const auto &meta : m_installed) {
        list.append(meta.toMap());
    }
    return list;
}

QVariantList PluginManager::marketPlugins() const
{
    QVariantList list;
    for (const auto &meta : m_market) {
        list.append(meta.toMap());
    }
    return list;
}

void PluginManager::refreshInstalledPlugins()
{
    m_installed.clear();
    QString pluginsDir = PathManager::instance()->pluginsDir();
    QDir dir(pluginsDir);
    if (!dir.exists()) {
        dir.mkpath(".");
    }

    const auto subDirs = dir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &sub : subDirs) {
        loadInstalledPluginFromDir(dir.filePath(sub));
    }

    syncMarketInstalledState();
    emit pluginsChanged();
    emit categoriesChanged();
}

void PluginManager::loadInstalledPluginFromDir(const QString &dirPath)
{
    QString manifestPath = dirPath + "/plugin.json";
    QFile file(manifestPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return;
    }

    QJsonParseError parseErr;
    QJsonDocument doc = QJsonDocument::fromJson(file.readAll(), &parseErr);
    file.close();

    if (parseErr.error != QJsonParseError::NoError || !doc.isObject()) {
        qWarning() << "[PluginManager] Failed to parse" << manifestPath << ":" << parseErr.errorString();
        return;
    }

    PluginMetadata meta = PluginMetadata::fromJson(doc.object());
    if (meta.id.isEmpty() || meta.name.isEmpty()) {
        qWarning() << "[PluginManager] Invalid plugin manifest in" << dirPath;
        return;
    }

    meta.installed = true;
    meta.localDir = dirPath;

    // Load persisted enabled state
    if (m_enabledConfig.contains(meta.id)) {
        meta.enabled = m_enabledConfig.value(meta.id);
    } else {
        m_enabledConfig[meta.id] = meta.enabled;
    }

    // Resolve icon path if relative
    if (!meta.icon.isEmpty() && !meta.icon.startsWith("qrc:") && !meta.icon.startsWith("http")) {
        QString localIcon = dirPath + "/" + meta.icon;
        if (QFile::exists(localIcon)) {
            meta.icon = QUrl::fromLocalFile(localIcon).toString();
        } else {
            meta.icon = "qrc:/assets/icons/plugin.svg";
        }
    } else if (meta.icon.isEmpty()) {
        meta.icon = "qrc:/assets/icons/plugin.svg";
    }

    m_installed[meta.id] = meta;

    // Register with ConfigManager sidebar if enabled
    if (meta.enabled && !meta.sidebar.isEmpty()) {
        updateSidebarItemForPlugin(meta);
    } else {
        removeSidebarItemForPlugin(meta.id);
    }
}

void PluginManager::updateSidebarItemForPlugin(const PluginMetadata &meta)
{
    if (meta.sidebar.isEmpty()) return;

    QString title = meta.sidebar["title"].toString(meta.name);
    QString icon = meta.sidebar["icon"].toString();
    if (icon.isEmpty()) {
        icon = meta.icon;
    } else if (!icon.startsWith("qrc:") && !icon.startsWith("http")) {
        QString localIcon = meta.localDir + "/" + icon;
        if (QFile::exists(localIcon)) {
            icon = QUrl::fromLocalFile(localIcon).toString();
        } else {
            icon = "qrc:/assets/icons/plugin.svg";
        }
    }
    QString route = meta.sidebar["route"].toString(meta.id);

    ConfigManager::instance()->registerPluginNavItem(meta.id, title, icon, route);
}

void PluginManager::removeSidebarItemForPlugin(const QString &pluginId)
{
    ConfigManager::instance()->unregisterPluginNavItem(pluginId);
}

void PluginManager::loadEnabledPluginsConfig()
{
    m_enabledConfig.clear();
    QSettings settings(PathManager::instance()->configFile(), QSettings::IniFormat);
    settings.beginGroup("Plugins_State");
    const QStringList keys = settings.childKeys();
    for (const QString &k : keys) {
        m_enabledConfig[k] = settings.value(k, true).toBool();
    }
    settings.endGroup();
}

void PluginManager::saveEnabledPluginsConfig()
{
    QSettings settings(PathManager::instance()->configFile(), QSettings::IniFormat);
    settings.beginGroup("Plugins_State");
    for (auto it = m_enabledConfig.cbegin(); it != m_enabledConfig.cend(); ++it) {
        settings.setValue(it.key(), it.value());
    }
    settings.endGroup();
}

void PluginManager::syncMarketInstalledState()
{
    for (int i = 0; i < m_market.size(); ++i) {
        if (m_installed.contains(m_market[i].id)) {
            m_market[i].installed = true;
            m_market[i].enabled = m_installed[m_market[i].id].enabled;
            m_market[i].localDir = m_installed[m_market[i].id].localDir;
        } else {
            m_market[i].installed = false;
        }
    }
    emit marketPluginsChanged();
}

bool PluginManager::extractArchive(const QString &archivePath, const QString &destDir)
{
    QDir().mkpath(destDir);
    QFileInfo fi(archivePath);

    if (fi.isDir()) {
        // Copy directory recursively
        QDir srcDir(archivePath);
        const auto entries = srcDir.entryInfoList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot | QDir::Hidden);
        for (const auto &e : entries) {
            QString target = destDir + "/" + e.fileName();
            if (e.isDir()) {
                if (!extractArchive(e.filePath(), target)) return false;
            } else {
                QFile::remove(target);
                if (!QFile::copy(e.filePath(), target)) return false;
            }
        }
        return true;
    }

    // Try tar -xf first
    QProcess tarProc;
    QStringList tarArgs;
    tarArgs << "-xf" << QDir::toNativeSeparators(archivePath) << "-C" << QDir::toNativeSeparators(destDir);
    tarProc.start("tar", tarArgs);
    if (tarProc.waitForFinished(10000) && tarProc.exitStatus() == QProcess::NormalExit && tarProc.exitCode() == 0) {
        return true;
    }

#if defined(Q_OS_WIN)
    // Fallback on Windows: PowerShell Expand-Archive
    QProcess psProc;
    QString cmd = QString("Expand-Archive -LiteralPath '%1' -DestinationPath '%2' -Force")
                      .arg(archivePath, destDir);
    psProc.start("powershell.exe", QStringList() << "-NoProfile" << "-ExecutionPolicy" << "Bypass" << "-Command" << cmd);
    if (psProc.waitForFinished(15000) && psProc.exitStatus() == QProcess::NormalExit && psProc.exitCode() == 0) {
        return true;
    }
#else
    // Fallback on Linux: unzip
    QProcess unzipProc;
    unzipProc.start("unzip", QStringList() << "-q" << "-o" << archivePath << "-d" << destDir);
    if (unzipProc.waitForFinished(10000) && unzipProc.exitStatus() == QProcess::NormalExit && unzipProc.exitCode() == 0) {
        return true;
    }
#endif

    qWarning() << "[PluginManager] Failed to extract archive:" << archivePath << "Output:" << tarProc.readAllStandardError();
    return false;
}

bool PluginManager::installPluginFrom0px(const QString &packagePath)
{
    if (!QFile::exists(packagePath)) {
        m_lastErrorMessage = tr("Plugin package not found: %1").arg(packagePath);
        emit errorOccurred(m_lastErrorMessage);
        return false;
    }

    QString stagingDir = PathManager::instance()->pluginsCacheDir() + "/temp_staging_" + QString::number(QDateTime::currentMSecsSinceEpoch());
    QDir(stagingDir).removeRecursively();

    if (!extractArchive(packagePath, stagingDir)) {
        m_lastErrorMessage = tr("Failed to extract plugin package: %1").arg(packagePath);
        emit errorOccurred(m_lastErrorMessage);
        QDir(stagingDir).removeRecursively();
        return false;
    }

    // Find plugin.json (either at root or one subfolder down)
    QString manifestPath = stagingDir + "/plugin.json";
    QString contentDir = stagingDir;

    if (!QFile::exists(manifestPath)) {
        QDir stDir(stagingDir);
        const auto subDirs = stDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QString &sub : subDirs) {
            QString candidate = stagingDir + "/" + sub + "/plugin.json";
            if (QFile::exists(candidate)) {
                manifestPath = candidate;
                contentDir = stagingDir + "/" + sub;
                break;
            }
        }
    }

    if (!QFile::exists(manifestPath)) {
        m_lastErrorMessage = tr("Invalid package: plugin.json not found.");
        emit errorOccurred(m_lastErrorMessage);
        QDir(stagingDir).removeRecursively();
        return false;
    }

    QFile file(manifestPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        m_lastErrorMessage = tr("Cannot read plugin.json.");
        emit errorOccurred(m_lastErrorMessage);
        QDir(stagingDir).removeRecursively();
        return false;
    }

    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();

    if (!doc.isObject()) {
        m_lastErrorMessage = tr("Invalid plugin.json format.");
        emit errorOccurred(m_lastErrorMessage);
        QDir(stagingDir).removeRecursively();
        return false;
    }

    PluginMetadata meta = PluginMetadata::fromJson(doc.object());
    if (meta.id.isEmpty() || meta.name.isEmpty()) {
        m_lastErrorMessage = tr("Missing required 'id' or 'name' in plugin.json.");
        emit errorOccurred(m_lastErrorMessage);
        QDir(stagingDir).removeRecursively();
        return false;
    }

    QString targetDir = PathManager::instance()->pluginsDir() + "/" + meta.id;
    QDir(targetDir).removeRecursively();

    if (!extractArchive(contentDir, targetDir)) {
        m_lastErrorMessage = tr("Failed to copy plugin into plugins directory.");
        emit errorOccurred(m_lastErrorMessage);
        QDir(stagingDir).removeRecursively();
        return false;
    }

    QDir(stagingDir).removeRecursively();

    // Reload plugin
    m_enabledConfig[meta.id] = true;
    saveEnabledPluginsConfig();
    loadInstalledPluginFromDir(targetDir);
    initPluginScriptEngine(meta.id);

    syncMarketInstalledState();
    emit pluginsChanged();
    emit categoriesChanged();
    emit pluginInstalled(meta.id);
    qInfo() << "[PluginManager] Successfully installed plugin:" << meta.id << "version:" << meta.version;
    return true;
}

void PluginManager::installPluginFromMarket(const QString &pluginId)
{
    int index = -1;
    for (int i = 0; i < m_market.size(); ++i) {
        if (m_market[i].id == pluginId) {
            index = i;
            break;
        }
    }

    if (index == -1) {
        emit installFinished(pluginId, false, tr("Plugin not found in market."));
        return;
    }

    PluginMetadata target = m_market[index];
    if (target.packageUrl.isEmpty()) {
        emit installFinished(pluginId, false, tr("No download package URL available."));
        return;
    }

    // Local file fallback
    if (!target.packageUrl.startsWith("http://") && !target.packageUrl.startsWith("https://")) {
        bool ok = installPluginFrom0px(target.packageUrl);
        emit installFinished(pluginId, ok, ok ? tr("Installed successfully.") : m_lastErrorMessage);
        return;
    }

    QUrl url(target.packageUrl);
    QNetworkRequest request(url);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);

    QNetworkReply *reply = networkManager()->get(request);

    connect(reply, &QNetworkReply::downloadProgress, this, [this, pluginId](qint64 received, qint64 total) {
        emit installProgress(pluginId, received, total);
    });

    connect(reply, &QNetworkReply::finished, this, [this, reply, pluginId]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            QString err = reply->errorString();
            emit errorOccurred(err);
            emit installFinished(pluginId, false, err);
            return;
        }

        QByteArray data = reply->readAll();
        QString tempPkg = PathManager::instance()->pluginsCacheDir() + "/" + pluginId + ".0px";
        QFile pkgFile(tempPkg);
        if (!pkgFile.open(QIODevice::WriteOnly)) {
            emit installFinished(pluginId, false, tr("Cannot write temporary package to disk."));
            return;
        }
        pkgFile.write(data);
        pkgFile.close();

        bool ok = installPluginFrom0px(tempPkg);
        emit installFinished(pluginId, ok, ok ? tr("Installed successfully.") : m_lastErrorMessage);
    });
}

bool PluginManager::uninstallPlugin(const QString &pluginId)
{
    if (!m_installed.contains(pluginId)) {
        return false;
    }

    unloadPluginScriptEngine(pluginId);
    m_pluginQueues.remove(pluginId);
    m_pluginViewData.remove(pluginId);

    QString dir = m_installed[pluginId].localDir;
    removeSidebarItemForPlugin(pluginId);

    if (!dir.isEmpty() && QDir(dir).exists()) {
        QDir(dir).removeRecursively();
    }

    m_installed.remove(pluginId);
    m_enabledConfig.remove(pluginId);
    saveEnabledPluginsConfig();

    syncMarketInstalledState();
    emit pluginsChanged();
    emit categoriesChanged();
    emit pluginUninstalled(pluginId);
    qInfo() << "[PluginManager] Uninstalled plugin:" << pluginId;
    return true;
}

void PluginManager::setPluginEnabled(const QString &pluginId, bool enabled)
{
    if (!m_installed.contains(pluginId)) {
        return;
    }

    m_installed[pluginId].enabled = enabled;
    m_enabledConfig[pluginId] = enabled;
    saveEnabledPluginsConfig();

    if (enabled) {
        updateSidebarItemForPlugin(m_installed[pluginId]);
        initPluginScriptEngine(pluginId);
    } else {
        removeSidebarItemForPlugin(pluginId);
        unloadPluginScriptEngine(pluginId);
    }

    syncMarketInstalledState();
    emit pluginsChanged();
    emit categoriesChanged();
    emit pluginStatusChanged(pluginId, enabled);
}

bool PluginManager::isPluginEnabled(const QString &pluginId) const
{
    return m_installed.contains(pluginId) && m_installed.value(pluginId).enabled;
}

bool PluginManager::isPluginInstalled(const QString &pluginId) const
{
    return m_installed.contains(pluginId);
}

QVariantMap PluginManager::getPluginInfo(const QString &pluginId) const
{
    if (m_installed.contains(pluginId)) {
        return m_installed[pluginId].toMap();
    }
    for (const auto &p : m_market) {
        if (p.id == pluginId) {
            return p.toMap();
        }
    }
    return QVariantMap();
}

QString PluginManager::getPluginAssetPath(const QString &pluginId, const QString &relPath) const
{
    if (!m_installed.contains(pluginId)) return QString();
    return m_installed[pluginId].localDir + "/" + relPath;
}

QVariantMap PluginManager::getPluginViewSchema(const QString &pluginId, const QString &schemaPath) const
{
    QVariantMap result;
    if (!m_installed.contains(pluginId)) {
        result["error"] = "Plugin not installed";
        return result;
    }

    const auto &meta = m_installed[pluginId];
    QString targetSchema = schemaPath;
    if (targetSchema.isEmpty() && meta.sidebar.contains("schema")) {
        targetSchema = meta.sidebar["schema"].toString();
    }

    if (!targetSchema.isEmpty()) {
        QString fullPath = meta.localDir + "/" + targetSchema;
        QFile file(fullPath);
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
            if (doc.isObject()) {
                return doc.object().toVariantMap();
            }
        }
    }

    // Default Material 3 Native Card Schema
    result["type"] = "page";
    result["title"] = meta.name;
    result["version"] = meta.version;
    result["author"] = meta.author;
    result["description"] = meta.description;
    result["category"] = meta.category;
    result["icon"] = meta.icon;

    QVariantList sections;
    QVariantMap banner;
    banner["type"] = "banner";
    banner["title"] = meta.name;
    banner["subtitle"] = meta.description;
    sections.append(banner);

    QVariantMap infoCard;
    infoCard["type"] = "card";
    infoCard["title"] = tr("Plugin Overview");
    infoCard["details"] = QString("%1 • %2 • %3").arg(meta.author, meta.version, meta.category);
    sections.append(infoCard);

    result["sections"] = sections;
    return result;
}

QVariantList PluginManager::executeSearchHook(const QString &query)
{
    QVariantList results;
    for (auto it = m_installed.cbegin(); it != m_installed.cend(); ++it) {
        if (!it->enabled) continue;
        if (!it->hooks.value("search").toBool()) continue;

        // Check if plugin has mock or static data file
        QString mockPath = it->localDir + "/mock_data/search_results.json";
        QFile file(mockPath);
        if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
            if (doc.isArray()) {
                const auto arr = doc.array();
                for (const auto &v : arr) {
                    if (v.isObject()) {
                        QJsonObject o = v.toObject();
                        QString title = o["title"].toString();
                        QString artist = o["artist"].toString();
                        if (query.isEmpty() || title.contains(query, Qt::CaseInsensitive) || artist.contains(query, Qt::CaseInsensitive)) {
                            QVariantMap item = o.toVariantMap();
                            item["sourcePlugin"] = it->name;
                            results.append(item);
                        }
                    }
                }
            }
        }
    }
    return results;
}

void PluginManager::fetchMarketIndex(const QString &customUrl)
{
    QString sourceUrl = customUrl.trimmed();
    if (sourceUrl.isEmpty()) {
        sourceUrl = ConfigManager::instance()->pluginSource();
    }
    if (sourceUrl.isEmpty()) {
        sourceUrl = "https://raw.githubusercontent.com/RinCynar/0rhxPlayer-Plugins/main/index.md";
    }

    m_isFetchingMarket = true;
    m_marketStatusMessage = tr("Fetching plugin marketplace index from %1...").arg(sourceUrl);
    emit fetchingMarketChanged(m_isFetchingMarket);
    emit marketStatusMessageChanged(m_marketStatusMessage);

    QUrl url(sourceUrl);
    QNetworkRequest request(url);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);

    QNetworkReply *reply = networkManager()->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply, sourceUrl]() {
        reply->deleteLater();
        m_isFetchingMarket = false;
        emit fetchingMarketChanged(m_isFetchingMarket);

        if (reply->error() != QNetworkReply::NoError) {
            m_lastErrorMessage = tr("Failed to fetch plugin index: %1").arg(reply->errorString());
            m_marketStatusMessage = m_lastErrorMessage;
            m_market.clear();
            emit marketPluginsChanged();
            emit categoriesChanged();
            emit marketStatusMessageChanged(m_marketStatusMessage);
            emit errorOccurred(m_lastErrorMessage);
            return;
        }

        m_lastErrorMessage.clear();
        QString content = QString::fromUtf8(reply->readAll());
        bool parsed = parseIndexMarkdown(content);
        if (parsed) {
            m_marketStatusMessage = tr("Loaded %1 plugins from %2").arg(m_market.size()).arg(sourceUrl);
        } else {
            m_lastErrorMessage = tr("No plugins found or index format invalid.");
            m_marketStatusMessage = m_lastErrorMessage;
        }
        emit marketStatusMessageChanged(m_marketStatusMessage);
    });
}

bool PluginManager::parseIndexMarkdown(const QString &content)
{
    m_market.clear();

    QString jsonContent;

    // 1. Try extracting ```json ... ``` fenced code block
    static QRegularExpression jsonBlockRegex(R"(```json\s*([\s\S]*?)\s*```)", QRegularExpression::CaseInsensitiveOption);
    auto match = jsonBlockRegex.match(content);
    if (match.hasMatch()) {
        jsonContent = match.captured(1).trimmed();
    }

    // 2. Try YAML Frontmatter: between first and second `---`
    if (jsonContent.isEmpty() && content.startsWith("---")) {
        int secondSep = content.indexOf("---", 3);
        if (secondSep > 3) {
            QString frontmatter = content.mid(3, secondSep - 3).trimmed();
            // Check if frontmatter itself contains json
            if (frontmatter.startsWith("{") || frontmatter.startsWith("[")) {
                jsonContent = frontmatter;
            } else {
                // Line-by-line YAML parser for list of objects
                // Format:
                // plugins:
                //   - id: ...
                //     name: ...
                QStringList lines = frontmatter.split(QRegularExpression(R"(\r?\n)"));
                QList<QMap<QString, QString>> yamlItems;
                QMap<QString, QString> currentItem;

                for (const QString &line : lines) {
                    QString trimmed = line.trimmed();
                    if (trimmed.isEmpty() || trimmed.startsWith("#") || trimmed == "plugins:") {
                        continue;
                    }

                    if (trimmed.startsWith("- ")) {
                        if (!currentItem.isEmpty()) {
                            yamlItems.append(currentItem);
                            currentItem.clear();
                        }
                        trimmed = trimmed.mid(2).trimmed();
                    }

                    int colonIdx = trimmed.indexOf(':');
                    if (colonIdx > 0) {
                        QString key = trimmed.left(colonIdx).trimmed();
                        QString val = trimmed.mid(colonIdx + 1).trimmed();
                        if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith('\'') && val.endsWith('\''))) {
                            val = val.mid(1, val.length() - 2);
                        }
                        currentItem[key] = val;
                    }
                }
                if (!currentItem.isEmpty()) {
                    yamlItems.append(currentItem);
                }

                if (!yamlItems.isEmpty()) {
                    for (const auto &item : yamlItems) {
                        PluginMetadata p;
                        p.id = item.value("id");
                        p.name = item.value("name");
                        p.version = item.value("version", "1.0.0");
                        p.author = item.value("author", "Community");
                        p.description = item.value("description");
                        p.category = item.value("category", "Other");
                        p.homepage = item.value("homepage");
                        p.icon = item.value("icon", "qrc:/assets/icons/plugin.svg");
                        p.packageUrl = item.value("packageUrl");
                        if (p.packageUrl.isEmpty()) p.packageUrl = item.value("path");
                        if (p.packageUrl.isEmpty()) p.packageUrl = item.value("downloadUrl");
                        if (p.packageUrl.isEmpty()) p.packageUrl = item.value("url");

                        if (!p.packageUrl.isEmpty() && !p.packageUrl.startsWith("http://") && !p.packageUrl.startsWith("https://") && !p.packageUrl.startsWith("file://") && !p.packageUrl.startsWith("/") && !p.packageUrl.contains(":\\")) {
                            QString baseSourceUrl = ConfigManager::instance()->pluginSource();
                            int lastSlash = baseSourceUrl.lastIndexOf('/');
                            QString baseUrl = (lastSlash != -1) ? baseSourceUrl.left(lastSlash + 1) : "https://raw.githubusercontent.com/RinCynar/0rhxPlayer-Plugins/main/";
                            if (!baseUrl.endsWith('/')) baseUrl += '/';
                            QString rel = p.packageUrl;
                            while (rel.startsWith('/')) rel = rel.mid(1);
                            p.packageUrl = baseUrl + rel;
                        }

                        if (!p.id.isEmpty() && !p.name.isEmpty()) {
                            m_market.append(p);
                        }
                    }
                }
            }
        }
    }

    // 3. Raw JSON array check
    if (jsonContent.isEmpty() && (content.trimmed().startsWith("[") || content.trimmed().startsWith("{"))) {
        jsonContent = content.trimmed();
    }

    if (!jsonContent.isEmpty()) {
        QJsonParseError err;
        QJsonDocument doc = QJsonDocument::fromJson(jsonContent.toUtf8(), &err);
        if (err.error == QJsonParseError::NoError) {
            QJsonArray arr;
            if (doc.isArray()) {
                arr = doc.array();
            } else if (doc.isObject() && doc.object().contains("plugins") && doc.object()["plugins"].isArray()) {
                arr = doc.object()["plugins"].toArray();
            }

            for (const auto &v : arr) {
                if (v.isObject()) {
                    PluginMetadata p = PluginMetadata::fromJson(v.toObject());
                    if (!p.id.isEmpty() && !p.name.isEmpty()) {
                        m_market.append(p);
                    }
                }
            }
        }
    }

    // If market list is still empty, populate standard default discovery entries
    if (m_market.isEmpty()) {
        PluginMetadata p1;
        p1.id = "com.rincynar.netease";
        p1.name = "Netease Cloud Music";
        p1.version = "1.0.2";
        p1.author = "RinCynar";
        p1.description = "Search, streaming and library synchronization for Netease Cloud Music";
        p1.category = "NetService";
        p1.icon = "qrc:/assets/icons/globe.svg";
        p1.packageUrl = "https://github.com/RinCynar/0rhxPlayer-Plugins/releases/download/v1.0.2/netease.0px";
        m_market.append(p1);

        PluginMetadata p2;
        p2.id = "com.rincynar.krclyrics";
        p2.name = "KRC Syllable Lyrics";
        p2.version = "1.1.0";
        p2.author = "0P Contributors";
        p2.description = "Ultra-low latency syllable-level karaoke synchronized lyrics provider";
        p2.category = "Lyrics";
        p2.icon = "qrc:/assets/icons/music.svg";
        p2.packageUrl = "https://github.com/RinCynar/0rhxPlayer-Plugins/releases/download/v1.1.0/krclyrics.0px";
        m_market.append(p2);

        PluginMetadata p3;
        p3.id = "com.rincynar.musicbrainz";
        p3.name = "MusicBrainz Scraper";
        p3.version = "1.0.0";
        p3.author = "MusicBrainz Team";
        p3.description = "Accurate online album cover art and release year metadata fetcher";
        p3.category = "Metadata";
        p3.icon = "qrc:/assets/icons/album.svg";
        p3.packageUrl = "https://github.com/RinCynar/0rhxPlayer-Plugins/releases/download/v1.0.0/musicbrainz.0px";
        m_market.append(p3);

        PluginMetadata p4;
        p4.id = "com.rincynar.testplugin";
        p4.name = "Echo Test Plugin";
        p4.version = "0.9.0";
        p4.author = "0P Core";
        p4.description = "Developer sample plugin verifying sidebar registration and search hooks";
        p4.category = "Test";
        p4.icon = "qrc:/assets/icons/pen.svg";
        p4.packageUrl = "https://github.com/RinCynar/0rhxPlayer-Plugins/releases/download/v0.9.0/testplugin.0px";
        m_market.append(p4);
    }

    syncMarketInstalledState();
    emit marketPluginsChanged();
    emit categoriesChanged();
    return !m_market.isEmpty();
}

// =========================================================================
// Category 1: Audio Playback & Transport Control
// =========================================================================
void PluginManager::play(const QString &filePath)
{
    if (filePath.isEmpty()) {
        AudioEngine::instance()->resume();
    } else {
        AudioEngine::instance()->play(filePath);
    }
}

void PluginManager::pause()
{
    AudioEngine::instance()->pause();
}

void PluginManager::resume()
{
    AudioEngine::instance()->resume();
}

void PluginManager::stop()
{
    AudioEngine::instance()->stop();
}

void PluginManager::seek(qint64 positionMs)
{
    AudioEngine::instance()->seek(positionMs);
}

void PluginManager::setVolume(float volume)
{
    AudioEngine::instance()->setVolume(std::clamp(volume, 0.0f, 1.0f));
}

float PluginManager::getVolume() const
{
    return AudioEngine::instance()->volume();
}

int PluginManager::getPlaybackState() const
{
    return static_cast<int>(AudioEngine::instance()->playbackState());
}

qint64 PluginManager::getPositionMs() const
{
    return AudioEngine::instance()->positionMs();
}

qint64 PluginManager::getDurationMs() const
{
    return AudioEngine::instance()->durationMs();
}

QString PluginManager::getCurrentTrack() const
{
    return AudioEngine::instance()->currentTrack();
}

QVariantMap PluginManager::getCurrentMetadata() const
{
    auto *ae = AudioEngine::instance();
    QVariantMap meta;
    meta["filePath"] = ae->currentTrack();
    meta["title"] = ae->currentTitle();
    meta["artist"] = ae->currentArtist();
    meta["album"] = ae->currentAlbum();
    meta["coverUrl"] = ae->currentCoverUrl();
    meta["hasCover"] = ae->hasCover();
    meta["format"] = ae->currentFormat();
    meta["bitrate"] = ae->currentBitrate();
    meta["sampleRate"] = ae->currentSampleRate();
    meta["channels"] = ae->currentChannels();
    meta["bitDepth"] = ae->currentBitDepth();
    meta["latencyMs"] = ae->currentLatencyMs();
    meta["encoding"] = ae->currentEncoding();
    meta["tool"] = ae->currentTool();
    meta["durationMs"] = ae->durationMs();
    meta["positionMs"] = ae->positionMs();
    return meta;
}

int PluginManager::getPlayMode() const
{
    return static_cast<int>(AudioEngine::instance()->playMode());
}

void PluginManager::setPlayMode(int mode)
{
    AudioEngine::instance()->setPlayMode(static_cast<AudioEngine::PlayMode>(mode));
}

void PluginManager::playNext()
{
    AudioEngine::instance()->playNext();
}

void PluginManager::playPrevious()
{
    AudioEngine::instance()->playPrevious();
}

// =========================================================================
// Category 2: Equalizer & DSP Control
// =========================================================================
void PluginManager::setEqEnabled(bool enabled)
{
    AudioEngine::instance()->setEqEnabled(enabled);
}

bool PluginManager::isEqEnabled() const
{
    return AudioEngine::instance()->eqEnabled();
}

void PluginManager::setEqPreamp(float preampDb)
{
    AudioEngine::instance()->setEqPreamp(preampDb);
}

float PluginManager::getEqPreamp() const
{
    return AudioEngine::instance()->eqPreamp();
}

void PluginManager::setEqBand(int index, float gainDb)
{
    AudioEngine::instance()->setEqBand(index, gainDb);
}

QVariantList PluginManager::getEqBands() const
{
    QVariantList list;
    const auto bands = AudioEngine::instance()->eqBands();
    for (float b : bands) {
        list.append(b);
    }
    return list;
}

void PluginManager::applyEqPreset(const QString &presetName)
{
    AudioEngine::instance()->applyEqPreset(presetName);
}

void PluginManager::resetEq()
{
    AudioEngine::instance()->resetEq();
}

QString PluginManager::getEqPreset() const
{
    return AudioEngine::instance()->eqPreset();
}

QStringList PluginManager::getEqPresetNames() const
{
    return AudioEngine::instance()->eqPresetNames();
}

// =========================================================================
// Category 3: Playback Queue
// =========================================================================
QVariantList PluginManager::getQueue() const
{
    QVariantList list;
    auto *ae = AudioEngine::instance();
    const QStringList pl = ae->playlist();
    auto *lm = LibraryManager::instance();
    for (int i = 0; i < pl.size(); ++i) {
        QVariantMap item = lm->getTrackDetails(pl[i]);
        item["index"] = i;
        item["filePath"] = pl[i];
        list.append(item);
    }
    return list;
}

int PluginManager::getQueueCount() const
{
    return AudioEngine::instance()->playlist().size();
}

int PluginManager::getCurrentQueueIndex() const
{
    return AudioEngine::instance()->currentIndex();
}

void PluginManager::playQueueIndex(int index)
{
    AudioEngine::instance()->playQueueIndex(index);
}

void PluginManager::setQueue(const QStringList &trackPaths, int startIndex)
{
    AudioEngine::instance()->setPlaylist(trackPaths, startIndex);
}

void PluginManager::addToQueue(const QString &filePath)
{
    AudioEngine::instance()->addToPlaylist(filePath);
}

void PluginManager::insertTracksNext(const QStringList &trackPaths)
{
    AudioEngine::instance()->insertTracksNext(trackPaths);
}

void PluginManager::clearQueue(bool keepCurrent)
{
    AudioEngine::instance()->clearQueue(keepCurrent);
}

void PluginManager::removeFromQueue(int index)
{
    AudioEngine::instance()->removeFromQueue(index);
}

void PluginManager::moveQueueItem(int from, int to)
{
    AudioEngine::instance()->moveQueueItem(from, to);
}

void PluginManager::shuffleQueue()
{
    AudioEngine::instance()->shuffleQueue();
}

// =========================================================================
// Category 4: Media Library & Search
// =========================================================================
int PluginManager::getLibraryTrackCount() const
{
    return LibraryManager::instance()->trackCount();
}

QStringList PluginManager::getAllTrackPaths() const
{
    return LibraryManager::instance()->allTrackPaths();
}

QVariantList PluginManager::getAllTracks(int limit, int offset) const
{
    QVariantList list;
    auto *lm = LibraryManager::instance();
    if (!lm->allTracks()) return list;
    const auto &tracks = lm->allTracks()->tracks();
    int start = std::max(0, offset);
    int end = (limit > 0) ? std::min(static_cast<int>(tracks.size()), start + limit) : static_cast<int>(tracks.size());
    for (int i = start; i < end; ++i) {
        const auto &t = tracks[i];
        QVariantMap m;
        m["filePath"] = t.path;
        m["title"] = t.title;
        m["artist"] = t.artist;
        m["album"] = t.album;
        m["durationMs"] = t.durationMs;
        m["coverUrl"] = t.coverUrl;
        m["format"] = t.format;
        m["bitrateKbps"] = t.bitrateKbps;
        list.append(m);
    }
    return list;
}

QVariantMap PluginManager::getTrackDetails(const QString &filePath) const
{
    return LibraryManager::instance()->getTrackDetails(filePath);
}

QVariantList PluginManager::getAllAlbums() const
{
    QVariantList list;
    auto *lm = LibraryManager::instance();
    if (!lm->allAlbums()) return list;
    const auto &albums = lm->allAlbums()->albums();
    for (const auto &a : albums) {
        QVariantMap m;
        m["name"] = a.name;
        m["artist"] = a.artist;
        m["coverUrl"] = a.coverUrl;
        m["trackCount"] = a.trackCount;
        m["path"] = a.path;
        list.append(m);
    }
    return list;
}

QVariantList PluginManager::getAllArtists() const
{
    QVariantList list;
    auto *lm = LibraryManager::instance();
    if (!lm->allArtists()) return list;
    const auto &artists = lm->allArtists()->albums();
    for (const auto &a : artists) {
        QVariantMap m;
        m["name"] = a.name;
        m["trackCount"] = a.trackCount;
        m["coverUrl"] = a.coverUrl;
        list.append(m);
    }
    return list;
}

QVariantList PluginManager::getAlbumTracks(const QString &albumName, const QString &artist) const
{
    QVariantList list;
    auto *lm = LibraryManager::instance();
    if (!lm->allTracks()) return list;
    const auto &tracks = lm->allTracks()->tracks();
    for (const auto &t : tracks) {
        if (t.album.compare(albumName, Qt::CaseInsensitive) == 0) {
            if (artist.isEmpty() || t.artist.contains(artist, Qt::CaseInsensitive)) {
                QVariantMap m;
                m["filePath"] = t.path;
                m["title"] = t.title;
                m["artist"] = t.artist;
                m["album"] = t.album;
                m["durationMs"] = t.durationMs;
                list.append(m);
            }
        }
    }
    return list;
}

QVariantList PluginManager::getArtistTracks(const QString &artistName) const
{
    QVariantList list;
    auto *lm = LibraryManager::instance();
    if (!lm->allTracks()) return list;
    const auto &tracks = lm->allTracks()->tracks();
    for (const auto &t : tracks) {
        if (t.artist.contains(artistName, Qt::CaseInsensitive)) {
            QVariantMap m;
            m["filePath"] = t.path;
            m["title"] = t.title;
            m["artist"] = t.artist;
            m["album"] = t.album;
            m["durationMs"] = t.durationMs;
            list.append(m);
        }
    }
    return list;
}

QVariantMap PluginManager::searchLibrary(const QString &keyword) const
{
    QVariantMap res;
    QVariantList trackList;
    auto *lm = LibraryManager::instance();
    if (!lm->allTracks()) return res;
    const auto &tracks = lm->allTracks()->tracks();
    for (const auto &t : tracks) {
        if (t.title.contains(keyword, Qt::CaseInsensitive) ||
            t.artist.contains(keyword, Qt::CaseInsensitive) ||
            t.album.contains(keyword, Qt::CaseInsensitive)) {
            QVariantMap m;
            m["filePath"] = t.path;
            m["title"] = t.title;
            m["artist"] = t.artist;
            m["album"] = t.album;
            m["durationMs"] = t.durationMs;
            trackList.append(m);
        }
    }
    res["tracks"] = trackList;
    res["totalMatches"] = trackList.size();
    return res;
}

void PluginManager::rescanLibrary()
{
    ConfigManager::instance()->rescanLibrary();
}

bool PluginManager::isScanningLibrary() const
{
    return LibraryManager::instance()->isScanning();
}

// =========================================================================
// Category 5: Playlists & User Favorites
// =========================================================================
bool PluginManager::isFavorite(const QString &trackPath) const
{
    return LibraryManager::instance()->isFavorite(trackPath);
}

void PluginManager::toggleFavorite(const QString &trackPath)
{
    LibraryManager::instance()->toggleFavorite(trackPath);
}

void PluginManager::setFavorite(const QString &trackPath, bool favorite)
{
    bool cur = LibraryManager::instance()->isFavorite(trackPath);
    if (cur != favorite) {
        LibraryManager::instance()->toggleFavorite(trackPath);
    }
}

int PluginManager::getFavoriteCount() const
{
    return LibraryManager::instance()->favoriteCount();
}

QStringList PluginManager::getFavoriteTracks() const
{
    QStringList favs;
    auto *lm = LibraryManager::instance();
    const QStringList all = lm->allTrackPaths();
    for (const QString &p : all) {
        if (lm->isFavorite(p)) {
            favs.append(p);
        }
    }
    return favs;
}

QVariantList PluginManager::getAllPlaylists() const
{
    QVariantList list;
    auto *lm = LibraryManager::instance();
    if (!lm->playlistsModel()) return list;
    const auto &pls = lm->playlistsModel()->playlists();
    for (const auto &p : pls) {
        QVariantMap m;
        m["id"] = p.id;
        m["name"] = p.name;
        m["description"] = p.description;
        m["coverUrl"] = p.coverUrl;
        m["trackCount"] = p.trackCount;
        m["isFavorites"] = p.isFavorites;
        m["trackPaths"] = p.trackPaths;
        list.append(m);
    }
    return list;
}

QVariantList PluginManager::getPlaylistTracks(const QString &playlistId) const
{
    QVariantList list;
    auto *lm = LibraryManager::instance();
    if (!lm->playlistsModel()) return list;
    const auto item = lm->playlistsModel()->findPlaylist(playlistId);
    for (const QString &p : item.trackPaths) {
        list.append(lm->getTrackDetails(p));
    }
    return list;
}

QString PluginManager::createPlaylist(const QString &name, const QStringList &trackPaths)
{
    auto *lm = LibraryManager::instance();
    if (trackPaths.isEmpty()) {
        return lm->createPlaylist(name);
    } else {
        return lm->createPlaylistWithTracks(name, trackPaths);
    }
}

bool PluginManager::deletePlaylist(const QString &playlistId)
{
    LibraryManager::instance()->deletePlaylist(playlistId);
    return true;
}

bool PluginManager::renamePlaylist(const QString &playlistId, const QString &newName)
{
    LibraryManager::instance()->renamePlaylist(playlistId, newName);
    return true;
}

bool PluginManager::addTracksToPlaylist(const QString &playlistId, const QStringList &trackPaths)
{
    LibraryManager::instance()->addTracksToPlaylist(playlistId, trackPaths);
    return true;
}

bool PluginManager::removeTracksFromPlaylist(const QString &playlistId, const QStringList &trackPaths)
{
    LibraryManager::instance()->removeTracksFromPlaylist(playlistId, trackPaths);
    return true;
}

void PluginManager::playPlaylist(const QString &playlistId, bool shuffle)
{
    LibraryManager::instance()->playPlaylist(playlistId, shuffle);
}

// =========================================================================
// Category 6: Synchronized Lyrics
// =========================================================================
bool PluginManager::hasLyrics() const
{
    auto *l = AudioEngine::instance()->lyrics();
    return l && l->hasLyrics();
}

bool PluginManager::hasLyricTranslation() const
{
    auto *l = AudioEngine::instance()->lyrics();
    return l && l->hasTranslation();
}

int PluginManager::getLyricCount() const
{
    auto *l = AudioEngine::instance()->lyrics();
    return l ? l->rowCount() : 0;
}

int PluginManager::getCurrentLyricIndex() const
{
    auto *l = AudioEngine::instance()->lyrics();
    return l ? l->activeIndex() : -1;
}

QVariantList PluginManager::getAllLyrics() const
{
    QVariantList list;
    auto *l = AudioEngine::instance()->lyrics();
    if (!l) return list;
    int count = l->rowCount();
    for (int i = 0; i < count; ++i) {
        QModelIndex idx = l->index(i, 0);
        QVariantMap m;
        m["index"] = i;
        m["timeMs"] = l->data(idx, LyricModel::TimeMsRole);
        m["text"] = l->data(idx, LyricModel::TextRole);
        m["translation"] = l->data(idx, LyricModel::TransRole);
        list.append(m);
    }
    return list;
}

QVariantMap PluginManager::getLyricLine(int index) const
{
    QVariantMap m;
    auto *l = AudioEngine::instance()->lyrics();
    if (!l || index < 0 || index >= l->rowCount()) return m;
    QModelIndex idx = l->index(index, 0);
    m["index"] = index;
    m["timeMs"] = l->data(idx, LyricModel::TimeMsRole);
    m["text"] = l->data(idx, LyricModel::TextRole);
    m["translation"] = l->data(idx, LyricModel::TransRole);
    return m;
}

bool PluginManager::loadLrcContent(const QString &lrcContent)
{
    auto *l = AudioEngine::instance()->lyrics();
    if (!l) return false;
    l->loadLrcContent(lrcContent);
    emit lyricsChanged();
    return true;
}

void PluginManager::clearLyrics()
{
    auto *l = AudioEngine::instance()->lyrics();
    if (l) {
        l->clear();
        emit lyricsChanged();
    }
}

// =========================================================================
// Category 7: Application Environment & State
// =========================================================================
QString PluginManager::getAppVersion() const
{
    return QCoreApplication::applicationVersion().isEmpty() ? QStringLiteral("1.2.1") : QCoreApplication::applicationVersion();
}

QString PluginManager::getAppLanguage() const
{
    return ConfigManager::instance()->effectiveLanguage();
}

QString PluginManager::getThemeMode() const
{
    return ConfigManager::instance()->themeMode();
}

QString PluginManager::getSeedColor() const
{
    return ConfigManager::instance()->seedColor();
}

QString PluginManager::getPluginDataDir(const QString &pluginId) const
{
    return PathManager::instance()->pluginDataDir(pluginId);
}

bool PluginManager::isWindowActive() const
{
    return AudioEngine::instance()->windowActive();
}

// =========================================================================
// Category 8: View Slot Injections & Actions
// =========================================================================
QVariantList PluginManager::getInjectedMenuItems(const QString &slotType, const QVariantMap &contextData) const
{
    Q_UNUSED(contextData);
    QVariantList items;
    for (auto it = m_installed.cbegin(); it != m_installed.cend(); ++it) {
        if (!it->enabled) continue;
        if (!it->entries.contains("contextMenu") || !it->entries["contextMenu"].isObject()) continue;

        QJsonObject ctxMenu = it->entries["contextMenu"].toObject();
        if (!ctxMenu.contains(slotType)) continue;

        QJsonValue val = ctxMenu[slotType];
        auto parseEntry = [&](const QJsonObject &obj) {
            if (obj.contains("enabled") && !obj["enabled"].toBool()) return;
            QVariantMap item;
            item["pluginId"] = it->id;
            item["pluginName"] = it->name;
            item["id"] = obj["id"].toString(obj["action"].toString());
            item["title"] = obj["title"].toString(it->name);
            QString icon = obj["icon"].toString();
            if (icon.isEmpty()) {
                item["icon"] = it->icon;
            } else if (!icon.startsWith("qrc:") && !icon.startsWith("http")) {
                item["icon"] = QUrl::fromLocalFile(it->localDir + "/" + icon).toString();
            } else {
                item["icon"] = icon;
            }
            item["slotType"] = slotType;
            items.append(item);
        };

        if (val.isArray()) {
            const auto arr = val.toArray();
            for (const auto &e : arr) {
                if (e.isObject()) parseEntry(e.toObject());
            }
        } else if (val.isObject()) {
            parseEntry(val.toObject());
        }
    }
    return items;
}

QVariantList PluginManager::getInjectedPlaybackControls() const
{
    QVariantList controls;
    for (auto it = m_installed.cbegin(); it != m_installed.cend(); ++it) {
        if (!it->enabled) continue;
        if (!it->entries.contains("playbackControl")) continue;

        QJsonValue val = it->entries["playbackControl"];
        auto parseControl = [&](const QJsonObject &obj) {
            if (obj.contains("enabled") && !obj["enabled"].toBool()) return;
            QVariantMap c;
            c["pluginId"] = it->id;
            c["pluginName"] = it->name;
            c["id"] = obj["id"].toString(obj["action"].toString());
            c["title"] = obj["title"].toString(obj["tooltip"].toString(it->name));
            QString icon = obj["icon"].toString();
            if (icon.isEmpty()) {
                c["icon"] = it->icon;
            } else if (!icon.startsWith("qrc:") && !icon.startsWith("http")) {
                c["icon"] = QUrl::fromLocalFile(it->localDir + "/" + icon).toString();
            } else {
                c["icon"] = icon;
            }
            controls.append(c);
        };

        if (val.isArray()) {
            for (const auto &e : val.toArray()) {
                if (e.isObject()) parseControl(e.toObject());
            }
        } else if (val.isObject()) {
            parseControl(val.toObject());
        }
    }
    return controls;
}

void PluginManager::triggerPluginAction(const QString &pluginId, const QString &actionId, const QString &slotType, const QVariantMap &payload)
{
    qInfo() << "[PluginManager] Action triggered for plugin:" << pluginId << "action:" << actionId << "slot:" << slotType;

    // Track addition to C++ queue
    if (actionId == "add_to_convert_queue" || actionId == "convert_track") {
        QString trackPath = payload.value("filePath").toString();
        if (trackPath.isEmpty()) trackPath = payload.value("path").toString();
        if (trackPath.isEmpty() && payload.contains("data")) {
            QVariantMap d = payload.value("data").toMap();
            trackPath = d.value("filePath").toString();
            if (trackPath.isEmpty()) trackPath = d.value("path").toString();
        }

        if (!trackPath.isEmpty()) {
            QVariantMap task;
            task["id"] = "task_" + QString::number(QDateTime::currentMSecsSinceEpoch());
            QString title = payload.value("title").toString();
            if (title.isEmpty()) title = QFileInfo(trackPath).fileName();
            task["title"] = title;
            task["artist"] = payload.value("artist").toString();
            task["sourcePath"] = trackPath;
            QString fmt = payload.value("format").toString();
            if (fmt.isEmpty()) fmt = "MP3";
            task["format"] = fmt.toUpper();
            task["status"] = "pending";
            task["progress"] = 0;
            m_pluginQueues[pluginId].append(task);
        }
    } else if (actionId == "clear_queue") {
        m_pluginQueues[pluginId].clear();
    }

    // Direct invocation on JS engine if onAction method exists
    if (m_scriptEngines.contains(pluginId)) {
        QJSEngine *engine = m_scriptEngines.value(pluginId);
        QJSValue targetObj = engine->globalObject().property("AudioConverterPlugin");
        if (!targetObj.isObject() || !targetObj.hasProperty("onAction")) {
            targetObj = engine->globalObject().property("Converter");
        }
        if (!targetObj.isObject() || !targetObj.hasProperty("onAction")) {
            targetObj = engine->globalObject().property("Gunmu");
        }
        if (!targetObj.isObject() || !targetObj.hasProperty("onAction")) {
            targetObj = engine->globalObject().property("Plugin");
        }
        if (targetObj.isObject() && targetObj.hasProperty("onAction") && targetObj.property("onAction").isCallable()) {
            QJSValueList args;
            args << engine->toScriptValue(actionId);
            args << engine->toScriptValue(slotType);
            args << engine->toScriptValue(payload);
            QJSValue res = targetObj.property("onAction").callWithInstance(targetObj, args);
            if (res.isError()) {
                qWarning() << "[PluginManager] Error calling onAction in" << pluginId << ":" << res.toString();
            }
        }
    }

    emit pluginActionTriggered(pluginId, actionId, slotType, payload);
    emit pluginViewUpdated(pluginId);
}

void PluginManager::initPluginScriptEngine(const QString &pluginId)
{
    if (!m_installed.contains(pluginId)) return;
    const auto &meta = m_installed[pluginId];
    if (!meta.enabled) return;

    QString scriptPath = meta.localDir + "/scripts/main.js";
    if (!QFile::exists(scriptPath)) return;

    unloadPluginScriptEngine(pluginId);

    QJSEngine *engine = new QJSEngine();
    engine->installExtensions(QJSEngine::ConsoleExtension);

    // Global object aliases
    QJSValue globalObj = engine->globalObject();
    globalObj.setProperty("window", globalObj);
    globalObj.setProperty("globalThis", globalObj);
    globalObj.setProperty("global", globalObj);

    // Expose Host Singletons with explicit C++ ownership
    auto exposeHostSingleton = [engine, &globalObj](const QString &name, QObject *obj) {
        if (!obj) return;
        QJSEngine::setObjectOwnership(obj, QJSEngine::CppOwnership);
        globalObj.setProperty(name, engine->newQObject(obj));
    };

    exposeHostSingleton("PluginManager", this);
    exposeHostSingleton("AudioEngine", AudioEngine::instance());
    exposeHostSingleton("LibraryManager", LibraryManager::instance());
    exposeHostSingleton("ConfigManager", ConfigManager::instance());
    exposeHostSingleton("PathManager", PathManager::instance());

    // Expose setTimeout / clearTimeout
    auto *timerBridge = new JsTimerBridge(engine, engine);
    globalObj.setProperty("_timerBridge", engine->newQObject(timerBridge));
    engine->evaluate(
        "function setTimeout(fn, delay) { return _timerBridge.setTimeout(fn, delay || 0); }\n"
        "function clearTimeout(id) { _timerBridge.clearTimeout(id); }\n"
    );

    // Expose toastBanner helper
    engine->evaluate(
        "var toastBanner = {\n"
        "    show: function(msg) { PluginManager.showToast(msg); }\n"
        "};\n"
        "window.toastBanner = toastBanner;\n"
    );

    // Load and evaluate scripts/main.js
    QFile file(scriptPath);
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QString code = QString::fromUtf8(file.readAll());
        file.close();

        QJSValue res = engine->evaluate(code, scriptPath);
        if (res.isError()) {
            qWarning() << "[PluginManager] Script evaluation error in" << pluginId
                       << "line" << res.property("lineNumber").toInt()
                       << ":" << res.toString();
        } else {
            qInfo() << "[PluginManager] Successfully loaded and running script for:" << pluginId;
        }
    }

    m_scriptEngines[pluginId] = engine;
}

void PluginManager::unloadPluginScriptEngine(const QString &pluginId)
{
    if (m_scriptEngines.contains(pluginId)) {
        QJSEngine *eng = m_scriptEngines.take(pluginId);
        QJSValue pluginObj = eng->globalObject().property("AudioConverterPlugin");
        if (!pluginObj.isObject()) {
            pluginObj = eng->globalObject().property("Converter");
        }
        if (!pluginObj.isObject()) {
            pluginObj = eng->globalObject().property("Plugin");
        }
        if (pluginObj.isObject() && pluginObj.hasProperty("onPluginUnload")) {
            QJSValue unloadFn = pluginObj.property("onPluginUnload");
            if (unloadFn.isCallable()) {
                unloadFn.callWithInstance(pluginObj);
            }
        }
        delete eng;
    }
}

QVariant PluginManager::callPluginMethod(const QString &pluginId, const QString &methodName, const QVariantList &args)
{
    if (!m_scriptEngines.contains(pluginId)) {
        return QVariant();
    }
    QJSEngine *engine = m_scriptEngines.value(pluginId);
    if (!engine) return QVariant();

    QJSValue targetObj = engine->globalObject().property("AudioConverterPlugin");
    if (!targetObj.isObject() || !targetObj.hasProperty(methodName)) {
        targetObj = engine->globalObject().property("Converter");
    }
    if (!targetObj.isObject() || !targetObj.hasProperty(methodName)) {
        targetObj = engine->globalObject();
    }

    if (targetObj.isObject() && targetObj.hasProperty(methodName)) {
        QJSValue fn = targetObj.property(methodName);
        if (fn.isCallable()) {
            QJSValueList jsArgs;
            for (const auto &arg : args) {
                jsArgs.append(engine->toScriptValue(arg));
            }
            QJSValue res = fn.callWithInstance(targetObj, jsArgs);
            if (res.isError()) {
                qWarning() << "[PluginManager] Error calling" << methodName << "on" << pluginId << ":" << res.toString();
                return QVariant();
            }
            return res.toVariant();
        }
    }
    return QVariant();
}

QVariantList PluginManager::getPluginQueue(const QString &pluginId) const
{
    if (m_scriptEngines.contains(pluginId)) {
        QJSEngine *engine = m_scriptEngines.value(pluginId);
        QJSValue targetObj = engine->globalObject().property("AudioConverterPlugin");
        if (!targetObj.isObject()) {
            targetObj = engine->globalObject().property("Converter");
        }
        if (targetObj.isObject()) {
            if (targetObj.hasProperty("getQueue") && targetObj.property("getQueue").isCallable()) {
                QJSValue res = targetObj.property("getQueue").callWithInstance(targetObj);
                if (res.isArray()) {
                    return res.toVariant().toList();
                }
            } else if (targetObj.hasProperty("queue") && targetObj.property("queue").isArray()) {
                return targetObj.property("queue").toVariant().toList();
            }
        }
    }

    return m_pluginQueues.value(pluginId);
}

void PluginManager::clearPluginQueue(const QString &pluginId)
{
    m_pluginQueues[pluginId].clear();
    triggerPluginAction(pluginId, "clear_queue", "workbench");
    emit pluginViewUpdated(pluginId);
}

void PluginManager::setPluginViewData(const QString &pluginId, const QString &key, const QVariant &value)
{
    m_pluginViewData[pluginId][key] = value;
    emit pluginViewUpdated(pluginId);
}

QVariant PluginManager::getPluginViewData(const QString &pluginId, const QString &key) const
{
    if (m_pluginViewData.contains(pluginId)) {
        return m_pluginViewData[pluginId].value(key);
    }
    return QVariant();
}

void PluginManager::notifyViewChanged(const QString &pluginId)
{
    emit pluginViewUpdated(pluginId);
}

void PluginManager::showToast(const QString &message)
{
    qInfo() << "[PluginManager Toast]" << message;
    emit toastRequested(message);
    for (auto it = m_scriptEngines.constBegin(); it != m_scriptEngines.constEnd(); ++it) {
        emit pluginViewUpdated(it.key());
    }
}

bool PluginManager::runProcess(const QString &program, const QVariant &arguments, const QString &workingDir)
{
    QStringList args;
    if (arguments.userType() == qMetaTypeId<QStringList>() || arguments.canConvert<QStringList>()) {
        args = arguments.toStringList();
    }
    if (args.isEmpty() && arguments.canConvert<QVariantList>()) {
        const auto list = arguments.toList();
        for (const auto &v : list) {
            args.append(v.toString());
        }
    }
    if (args.isEmpty() && arguments.userType() == qMetaTypeId<QJSValue>()) {
        QJSValue jsVal = arguments.value<QJSValue>();
        if (jsVal.isArray()) {
            int len = jsVal.property("length").toInt();
            for (int i = 0; i < len; ++i) {
                args.append(jsVal.property(i).toString());
            }
        }
    }

    qInfo() << "[PluginManager] Spawning process:" << program << args << "in" << workingDir;

    // Auto-create destination directory if output argument is present
    for (int i = 0; i < args.size(); ++i) {
        if (args[i] == "-y" && i + 1 < args.size()) {
            QFileInfo outFi(args[i + 1]);
            QDir().mkpath(outFi.absolutePath());
        }
    }

    QString exePath = QStandardPaths::findExecutable(program);
    if (exePath.isEmpty()) {
        exePath = program;
    }

    QProcess proc;
    if (!workingDir.isEmpty()) {
        proc.setWorkingDirectory(workingDir);
    }
    proc.start(exePath, args);
    if (!proc.waitForStarted(5000)) {
        qWarning() << "[PluginManager] Failed to start process:" << exePath << proc.errorString();
        showToast(tr("Failed to start %1: %2").arg(program, proc.errorString()));
        return false;
    }

    // Process events while waiting so UI does not freeze during conversion
    while (!proc.waitForFinished(100)) {
        if (proc.state() == QProcess::NotRunning) {
            break;
        }
        QCoreApplication::processEvents(QEventLoop::AllEvents, 50);
    }

    if (proc.exitStatus() != QProcess::NormalExit || proc.exitCode() != 0) {
        QString err = QString::fromUtf8(proc.readAllStandardError());
        qWarning() << "[PluginManager] Process failed with exit code:" << proc.exitCode() << err;
        showToast(tr("Transcoding failed (code %1)").arg(proc.exitCode()));
        return false;
    }

    qInfo() << "[PluginManager] Process successfully finished:" << program;
    return true;
}

QVariantMap PluginManager::executePluginHook(const QString &hookType, const QVariantMap &params)
{
    QVariantMap res;
    if (hookType == "search") {
        res["results"] = executeSearchHook(params.value("query").toString());
    }
    return res;
}

