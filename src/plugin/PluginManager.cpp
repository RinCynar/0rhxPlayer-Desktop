#include "PluginManager.h"
#include "../core/PathManager.h"
#include "../config/ConfigManager.h"

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
#include <QRegularExpression>
#include <QUrl>
#include <QDebug>

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
    refreshInstalledPlugins();
}

QStringList PluginManager::categories() const
{
    return { "All", "NetService", "Lyrics", "Metadata", "Test", "Utility", "Installed" };
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

    syncMarketInstalledState();
    emit pluginsChanged();
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
    } else {
        removeSidebarItemForPlugin(pluginId);
    }

    syncMarketInstalledState();
    emit pluginsChanged();
    emit pluginStatusChanged(pluginId, enabled);
}

bool PluginManager::isPluginEnabled(const QString &pluginId) const
{
    return m_installed.contains(pluginId) && m_installed.value(pluginId).enabled;
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
    return !m_market.isEmpty();
}
