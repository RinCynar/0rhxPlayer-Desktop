#include "ConfigManager.h"
#include "../library/LibraryManager.h"
#include "../audio/AudioEngine.h"
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QFileDialog>
#include <QUrl>
#include <QDir>
#include <QLocale>
#include <QDebug>

ConfigManager *ConfigManager::instance()
{
    static ConfigManager s_instance;
    return &s_instance;
}

ConfigManager::ConfigManager(QObject *parent)
    : QObject(parent)
{
    loadSettings();
}

QVariantList ConfigManager::defaultNavItems() const
{
    QVariantList items;

    QVariantMap home;
    home["id"] = "home";
    home["title"] = "首页";
    home["iconSource"] = "qrc:/assets/icons/star.svg";
    home["visible"] = true;
    home["canHide"] = false;
    items.append(home);

    QVariantMap library;
    library["id"] = "library";
    library["title"] = "曲库";
    library["iconSource"] = "qrc:/assets/icons/library.svg";
    library["visible"] = true;
    library["canHide"] = true;
    items.append(library);

    QVariantMap search;
    search["id"] = "search";
    search["title"] = "搜索";
    search["iconSource"] = "qrc:/assets/icons/search.svg";
    search["visible"] = true;
    search["canHide"] = true;
    items.append(search);

    QVariantMap queue;
    queue["id"] = "queue";
    queue["title"] = "队列";
    queue["iconSource"] = "qrc:/assets/icons/list_ol.svg";
    queue["visible"] = true;
    queue["canHide"] = true;
    items.append(queue);

    QVariantMap playlist;
    playlist["id"] = "playlist";
    playlist["title"] = "歌单";
    playlist["iconSource"] = "qrc:/assets/icons/disc.svg";
    playlist["visible"] = true;
    playlist["canHide"] = true;
    items.append(playlist);

    QVariantMap eq;
    eq["id"] = "eq";
    eq["title"] = "均衡器";
    eq["iconSource"] = "qrc:/assets/icons/sliders.svg";
    eq["visible"] = true;
    eq["canHide"] = true;
    items.append(eq);

    return items;
}

void ConfigManager::loadSettings()
{
    QSettings settings;

    // Navigation items
    QByteArray rawJson = settings.value("Navigation/ItemsJson").toByteArray();
    if (rawJson.isEmpty()) {
        m_allNavItems = defaultNavItems();
    } else {
        QJsonDocument doc = QJsonDocument::fromJson(rawJson);
        if (!doc.isArray()) {
            m_allNavItems = defaultNavItems();
        } else {
            QJsonArray arr = doc.array();
            QVariantList loadedItems;
            QMap<QString, QVariantMap> defaultsMap;
            for (const auto &itemVal : defaultNavItems()) {
                QVariantMap m = itemVal.toMap();
                defaultsMap[m["id"].toString()] = m;
            }

            for (const auto &val : arr) {
                if (!val.isObject()) continue;
                QJsonObject obj = val.toObject();
                QString id = obj["id"].toString();
                if (defaultsMap.contains(id)) {
                    QVariantMap item = defaultsMap.take(id);
                    if (obj.contains("visible")) {
                        item["visible"] = (id == "home") ? true : obj["visible"].toBool();
                    }
                    loadedItems.append(item);
                }
            }

            // Append any default items that were not present in saved settings
            for (const auto &remainingItem : defaultsMap) {
                loadedItems.append(remainingItem);
            }

            m_allNavItems = loadedItems;
        }
    }

    // User Profile
    m_nickname = settings.value("User/Nickname", "RinCynar").toString();
    m_avatar = settings.value("User/Avatar", "").toString();

    // Appearance & Themes
    m_themeMode = settings.value("Appearance/ThemeMode", "system").toString();
    m_seedColor = settings.value("Appearance/SeedColor", "#39C5BB").toString();

    // Lyrics & UI
    m_lyricsAlign = settings.value("Lyrics/Align", "right").toString();
    if (m_lyricsAlign != "left" && m_lyricsAlign != "center" && m_lyricsAlign != "right") {
        m_lyricsAlign = "right";
    }
    m_lyricsFontSize = settings.value("Lyrics/FontSize", 30).toInt();
    if (m_lyricsFontSize < 14 || m_lyricsFontSize > 64) {
        m_lyricsFontSize = 30;
    }
    m_showTrans = settings.value("Lyrics/ShowTrans", true).toBool();
    m_autoCollapseRail = settings.value("Interface/AutoCollapseRail", true).toBool();

    // Audio Settings
    m_audioDriver = settings.value("Audio/Driver", "WASAPI Exclusive").toString();
    m_resampler = settings.value("Audio/Resampler", "SoX Resampler High Quality").toString();
    m_replayGain = settings.value("Audio/ReplayGain", "Track Mode (-18 LUFS)").toString();
    m_cueAutoScan = settings.value("Audio/CueAutoScan", true).toBool();
    m_systemTray = settings.value("Audio/SystemTray", true).toBool();

    // Library & Metadata
    m_scannedFolders = settings.value("Library/ScannedFolders").toStringList();
    m_artistSeparators = settings.value("Library/ArtistSeparators", "/").toString();
    m_libraryViewMode = settings.value("Library/ViewMode", "compact").toString();
    if (m_libraryViewMode != "list" && m_libraryViewMode != "card" && m_libraryViewMode != "compact") {
        m_libraryViewMode = "compact";
    }

    m_tracksViewMode = settings.value("Library/TracksViewMode", settings.value("Library/TitlesViewMode", "compact")).toString();
    if (m_tracksViewMode != "list" && m_tracksViewMode != "card" && m_tracksViewMode != "compact") {
        m_tracksViewMode = "compact";
    }

    m_albumsViewMode = settings.value("Library/AlbumsViewMode", "compact").toString();
    if (m_albumsViewMode != "list" && m_albumsViewMode != "card" && m_albumsViewMode != "compact") {
        m_albumsViewMode = "compact";
    }

    m_artistsViewMode = settings.value("Library/ArtistsViewMode", "compact").toString();
    if (m_artistsViewMode != "list" && m_artistsViewMode != "card" && m_artistsViewMode != "compact") {
        m_artistsViewMode = "compact";
    }

    m_foldersViewMode = settings.value("Library/FoldersViewMode", "compact").toString();
    if (m_foldersViewMode != "list" && m_foldersViewMode != "card" && m_foldersViewMode != "compact") {
        m_foldersViewMode = "compact";
    }

    // Search
    m_searchHistory = settings.value("Search/History").toStringList();

    // General
    m_language = settings.value("General/Language", "system").toString();
    if (m_language != "system" && m_language != "zh" && m_language != "en" && m_language != "ja") {
        m_language = "system";
    }
}

void ConfigManager::saveSettings()
{
    QSettings settings;
    QJsonArray arr;
    for (const auto &itemVal : m_allNavItems) {
        QVariantMap m = itemVal.toMap();
        QJsonObject obj;
        obj["id"] = m["id"].toString();
        obj["visible"] = m["visible"].toBool();
        arr.append(obj);
    }

    QJsonDocument doc(arr);
    settings.setValue("Navigation/ItemsJson", doc.toJson(QJsonDocument::Compact));
}

QVariantList ConfigManager::visibleNavItems() const
{
    QVariantList visible;
    for (const auto &item : m_allNavItems) {
        QVariantMap m = item.toMap();
        if (m.value("visible", true).toBool()) {
            visible.append(m);
        }
    }
    return visible;
}

void ConfigManager::saveNavItems(const QVariantList &items)
{
    m_allNavItems = items;
    saveSettings();
    emit navItemsChanged();
}

void ConfigManager::resetNavItems()
{
    m_allNavItems = defaultNavItems();
    saveSettings();
    emit navItemsChanged();
}

// User Profile
void ConfigManager::setNickname(const QString &nick)
{
    QString trimmed = nick.trimmed();
    if (trimmed.isEmpty()) trimmed = "RinCynar";
    if (m_nickname != trimmed) {
        m_nickname = trimmed;
        QSettings settings;
        settings.setValue("User/Nickname", m_nickname);
        emit nicknameChanged(m_nickname);
    }
}

void ConfigManager::setAvatar(const QString &avatarPath)
{
    if (m_avatar != avatarPath) {
        m_avatar = avatarPath;
        QSettings settings;
        settings.setValue("User/Avatar", m_avatar);
        emit avatarChanged(m_avatar);
    }
}

void ConfigManager::openSelectAvatarDialog()
{
    QString file = QFileDialog::getOpenFileName(
        nullptr,
        QString::fromUtf8("选择头像图片"),
        QString(),
        QString::fromUtf8("Images (*.png *.jpg *.jpeg *.webp *.bmp *.svg)")
    );
    if (!file.isEmpty()) {
        setAvatar(QUrl::fromLocalFile(file).toString());
    }
}

void ConfigManager::resetAvatar()
{
    setAvatar("");
}

// Appearance
void ConfigManager::setThemeMode(const QString &mode)
{
    QString m = mode.trimmed().toLower();
    if (m != "system" && m != "dark" && m != "light") {
        m = "system";
    }
    if (m_themeMode != m) {
        m_themeMode = m;
        QSettings settings;
        settings.setValue("Appearance/ThemeMode", m_themeMode);
        emit themeModeChanged(m_themeMode);
    }
}

void ConfigManager::setSeedColor(const QString &hex)
{
    QString clean = hex.trimmed();
    if (!clean.startsWith('#')) {
        clean.prepend('#');
    }
    if (m_seedColor.compare(clean, Qt::CaseInsensitive) != 0) {
        m_seedColor = clean;
        QSettings settings;
        settings.setValue("Appearance/SeedColor", m_seedColor);
        emit seedColorChanged(m_seedColor);
    }
}

// Lyrics & UI
void ConfigManager::setLyricsAlign(const QString &align)
{
    QString val = align.trimmed().toLower();
    if (val != "left" && val != "center" && val != "right") {
        val = "right";
    }
    if (m_lyricsAlign != val) {
        m_lyricsAlign = val;
        QSettings settings;
        settings.setValue("Lyrics/Align", m_lyricsAlign);
        emit lyricsAlignChanged(m_lyricsAlign);
    }
}

void ConfigManager::setLyricsFontSize(int size)
{
    if (size < 14) size = 14;
    if (size > 64) size = 64;
    if (m_lyricsFontSize != size) {
        m_lyricsFontSize = size;
        QSettings settings;
        settings.setValue("Lyrics/FontSize", m_lyricsFontSize);
        emit lyricsFontSizeChanged(m_lyricsFontSize);
    }
}

void ConfigManager::setShowTrans(bool show)
{
    if (m_showTrans != show) {
        m_showTrans = show;
        QSettings settings;
        settings.setValue("Lyrics/ShowTrans", m_showTrans);
        emit showTransChanged(m_showTrans);
    }
}

void ConfigManager::setAutoCollapseRail(bool collapse)
{
    if (m_autoCollapseRail != collapse) {
        m_autoCollapseRail = collapse;
        QSettings settings;
        settings.setValue("Interface/AutoCollapseRail", m_autoCollapseRail);
        emit autoCollapseRailChanged(m_autoCollapseRail);
    }
}

// Audio Settings
void ConfigManager::setAudioDriver(const QString &driver)
{
    if (m_audioDriver != driver) {
        m_audioDriver = driver;
        QSettings settings;
        settings.setValue("Audio/Driver", m_audioDriver);
        if (AudioEngine::instance()) {
            AudioEngine::instance()->setExclusiveMode(m_audioDriver == "WASAPI Exclusive");
        }
        emit audioDriverChanged(m_audioDriver);
    }
}

void ConfigManager::setResampler(const QString &resampler)
{
    if (m_resampler != resampler) {
        m_resampler = resampler;
        QSettings settings;
        settings.setValue("Audio/Resampler", m_resampler);
        emit resamplerChanged(m_resampler);
    }
}

void ConfigManager::setReplayGain(const QString &replayGain)
{
    if (m_replayGain != replayGain) {
        m_replayGain = replayGain;
        QSettings settings;
        settings.setValue("Audio/ReplayGain", m_replayGain);
        emit replayGainChanged(m_replayGain);
    }
}

void ConfigManager::setCueAutoScan(bool cue)
{
    if (m_cueAutoScan != cue) {
        m_cueAutoScan = cue;
        QSettings settings;
        settings.setValue("Audio/CueAutoScan", m_cueAutoScan);
        emit cueAutoScanChanged(m_cueAutoScan);
    }
}

void ConfigManager::setSystemTray(bool tray)
{
    if (m_systemTray != tray) {
        m_systemTray = tray;
        QSettings settings;
        settings.setValue("Audio/SystemTray", m_systemTray);
        emit systemTrayChanged(m_systemTray);
    }
}

// Library & Metadata
void ConfigManager::setArtistSeparators(const QString &separators)
{
    QString clean = separators.trimmed();
    if (clean.isEmpty()) clean = "/";
    if (m_artistSeparators != clean) {
        m_artistSeparators = clean;
        QSettings settings;
        settings.setValue("Library/ArtistSeparators", m_artistSeparators);
        emit artistSeparatorsChanged(m_artistSeparators);
        rescanLibrary();
    }
}

void ConfigManager::addScannedFolder(const QString &folderPath)
{
    QString clean = QDir::toNativeSeparators(folderPath.trimmed());
    if (clean.isEmpty()) return;
    if (!m_scannedFolders.contains(clean)) {
        m_scannedFolders.append(clean);
        QSettings settings;
        settings.setValue("Library/ScannedFolders", m_scannedFolders);
        emit scannedFoldersChanged(m_scannedFolders);
        rescanLibrary();
    }
}

void ConfigManager::removeScannedFolder(const QString &folderPath)
{
    QString trimmed = folderPath.trimmed();
    QString native = QDir::toNativeSeparators(trimmed);
    QString clean = QDir::fromNativeSeparators(trimmed);

    int removed = 0;
    for (int i = m_scannedFolders.size() - 1; i >= 0; --i) {
        QString f = m_scannedFolders.at(i);
        if (f == trimmed || f == native || f == clean ||
            QDir::toNativeSeparators(f) == native ||
            QString::compare(f, native, Qt::CaseInsensitive) == 0) {
            m_scannedFolders.removeAt(i);
            removed++;
        }
    }

    if (removed > 0) {
        QSettings settings;
        settings.setValue("Library/ScannedFolders", m_scannedFolders);
        emit scannedFoldersChanged(m_scannedFolders);
        rescanLibrary();
    }
}

void ConfigManager::openAddFolderDialog()
{
    QString dir = QFileDialog::getExistingDirectory(
        nullptr,
        QString::fromUtf8("选择音乐文件夹"),
        QString(),
        QFileDialog::ShowDirsOnly | QFileDialog::DontResolveSymlinks
    );
    if (!dir.isEmpty()) {
        addScannedFolder(dir);
    }
}

void ConfigManager::rescanLibrary()
{
    LibraryManager::instance()->scanFolders(m_scannedFolders);
}

void ConfigManager::setLibraryViewMode(const QString &mode)
{
    QString m = (mode == "grid") ? "grid" : "list";
    if (m_libraryViewMode != m) {
        m_libraryViewMode = m;
        QSettings settings;
        settings.setValue("Library/ViewMode", m_libraryViewMode);
        emit libraryViewModeChanged(m_libraryViewMode);
    }
}

void ConfigManager::setTracksViewMode(const QString &mode)
{
    QString m = (mode == "list" || mode == "card" || mode == "compact") ? mode : "compact";
    if (m_tracksViewMode != m) {
        m_tracksViewMode = m;
        QSettings settings;
        settings.setValue("Library/TracksViewMode", m_tracksViewMode);
        settings.setValue("Library/TitlesViewMode", m_tracksViewMode);
        emit tracksViewModeChanged(m_tracksViewMode);
        emit titlesViewModeChanged(m_tracksViewMode);
    }
}

void ConfigManager::setTitlesViewMode(const QString &mode)
{
    setTracksViewMode(mode);
}

void ConfigManager::setAlbumsViewMode(const QString &mode)
{
    QString m = (mode == "list" || mode == "card" || mode == "compact") ? mode : "compact";
    if (m_albumsViewMode != m) {
        m_albumsViewMode = m;
        QSettings settings;
        settings.setValue("Library/AlbumsViewMode", m_albumsViewMode);
        emit albumsViewModeChanged(m_albumsViewMode);
    }
}

void ConfigManager::setArtistsViewMode(const QString &mode)
{
    QString m = (mode == "list" || mode == "card" || mode == "compact") ? mode : "compact";
    if (m_artistsViewMode != m) {
        m_artistsViewMode = m;
        QSettings settings;
        settings.setValue("Library/ArtistsViewMode", m_artistsViewMode);
        emit artistsViewModeChanged(m_artistsViewMode);
    }
}

void ConfigManager::setFoldersViewMode(const QString &mode)
{
    QString m = (mode == "list" || mode == "card" || mode == "compact") ? mode : "compact";
    if (m_foldersViewMode != m) {
        m_foldersViewMode = m;
        QSettings settings;
        settings.setValue("Library/FoldersViewMode", m_foldersViewMode);
        emit foldersViewModeChanged(m_foldersViewMode);
    }
}

QString ConfigManager::viewModeForTab(const QString &tab) const
{
    if (tab == "tracks" || tab == "titles") return m_tracksViewMode;
    if (tab == "albums") return m_albumsViewMode;
    if (tab == "artists") return m_artistsViewMode;
    if (tab == "folders") return m_foldersViewMode;
    return "compact";
}

void ConfigManager::setViewModeForTab(const QString &tab, const QString &mode)
{
    if (tab == "tracks" || tab == "titles") setTracksViewMode(mode);
    else if (tab == "albums") setAlbumsViewMode(mode);
    else if (tab == "artists") setArtistsViewMode(mode);
    else if (tab == "folders") setFoldersViewMode(mode);
}

// General
QString ConfigManager::detectSystemLanguage()
{
    QLocale sys = QLocale::system();
    if (sys.language() == QLocale::Chinese || sys.name().startsWith("zh", Qt::CaseInsensitive)) {
        return "zh";
    } else if (sys.language() == QLocale::Japanese || sys.name().startsWith("ja", Qt::CaseInsensitive)) {
        return "ja";
    } else {
        return "en";
    }
}

QString ConfigManager::effectiveLanguage() const
{
    if (m_language == "system") {
        return detectSystemLanguage();
    }
    return m_language;
}

void ConfigManager::setLanguage(const QString &lang)
{
    QString l = lang.trimmed().toLower();
    if (l != "system" && l != "zh" && l != "en" && l != "ja") {
        l = "system";
    }
    if (m_language != l) {
        m_language = l;
        QSettings settings;
        settings.setValue("General/Language", m_language);
        emit languageChanged(m_language);
    }
}

void ConfigManager::addSearchHistory(const QString &query)
{
    QString trimmed = query.trimmed();
    if (trimmed.isEmpty()) return;

    m_searchHistory.removeAll(trimmed);
    m_searchHistory.prepend(trimmed);
    while (m_searchHistory.size() > 8) {
        m_searchHistory.removeLast();
    }

    QSettings settings;
    settings.setValue("Search/History", m_searchHistory);
    emit searchHistoryChanged();
}

void ConfigManager::removeSearchHistory(const QString &query)
{
    QString trimmed = query.trimmed();
    if (trimmed.isEmpty()) return;

    if (m_searchHistory.removeAll(trimmed) > 0) {
        QSettings settings;
        settings.setValue("Search/History", m_searchHistory);
        emit searchHistoryChanged();
    }
}

void ConfigManager::clearSearchHistory()
{
    if (!m_searchHistory.isEmpty()) {
        m_searchHistory.clear();
        QSettings settings;
        settings.remove("Search/History");
        emit searchHistoryChanged();
    }
}

