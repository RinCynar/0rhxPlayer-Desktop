#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QStringList>
#include <QSettings>

class ConfigManager : public QObject {
    Q_OBJECT
    // Navigation
    Q_PROPERTY(QVariantList allNavItems READ allNavItems NOTIFY navItemsChanged)
    Q_PROPERTY(QVariantList visibleNavItems READ visibleNavItems NOTIFY navItemsChanged)

    // User Profile
    Q_PROPERTY(QString nickname READ nickname WRITE setNickname NOTIFY nicknameChanged)
    Q_PROPERTY(QString avatar READ avatar WRITE setAvatar NOTIFY avatarChanged)

    // Appearance & Themes
    Q_PROPERTY(QString themeMode READ themeMode WRITE setThemeMode NOTIFY themeModeChanged)
    Q_PROPERTY(QString seedColor READ seedColor WRITE setSeedColor NOTIFY seedColorChanged)

    // Lyrics & UI
    Q_PROPERTY(QString lyricsAlign READ lyricsAlign WRITE setLyricsAlign NOTIFY lyricsAlignChanged)
    Q_PROPERTY(int lyricsFontSize READ lyricsFontSize WRITE setLyricsFontSize NOTIFY lyricsFontSizeChanged)
    Q_PROPERTY(bool showTrans READ showTrans WRITE setShowTrans NOTIFY showTransChanged)
    Q_PROPERTY(bool autoCollapseRail READ autoCollapseRail WRITE setAutoCollapseRail NOTIFY autoCollapseRailChanged)

    // Audio Settings
    Q_PROPERTY(QString audioDriver READ audioDriver WRITE setAudioDriver NOTIFY audioDriverChanged)
    Q_PROPERTY(QString resampler READ resampler WRITE setResampler NOTIFY resamplerChanged)
    Q_PROPERTY(QString replayGain READ replayGain WRITE setReplayGain NOTIFY replayGainChanged)
    Q_PROPERTY(bool cueAutoScan READ cueAutoScan WRITE setCueAutoScan NOTIFY cueAutoScanChanged)
    Q_PROPERTY(bool systemTray READ systemTray WRITE setSystemTray NOTIFY systemTrayChanged)

    // Library & Metadata
    Q_PROPERTY(QStringList scannedFolders READ scannedFolders NOTIFY scannedFoldersChanged)
    Q_PROPERTY(QString artistSeparators READ artistSeparators WRITE setArtistSeparators NOTIFY artistSeparatorsChanged)
    Q_PROPERTY(QString libraryViewMode READ libraryViewMode WRITE setLibraryViewMode NOTIFY libraryViewModeChanged)
    Q_PROPERTY(QString tracksViewMode READ tracksViewMode WRITE setTracksViewMode NOTIFY tracksViewModeChanged)
    Q_PROPERTY(QString titlesViewMode READ titlesViewMode WRITE setTitlesViewMode NOTIFY titlesViewModeChanged)
    Q_PROPERTY(QString albumsViewMode READ albumsViewMode WRITE setAlbumsViewMode NOTIFY albumsViewModeChanged)
    Q_PROPERTY(QString artistsViewMode READ artistsViewMode WRITE setArtistsViewMode NOTIFY artistsViewModeChanged)
    Q_PROPERTY(QString foldersViewMode READ foldersViewMode WRITE setFoldersViewMode NOTIFY foldersViewModeChanged)
    Q_PROPERTY(QStringList searchHistory READ searchHistory NOTIFY searchHistoryChanged)

    // General
    Q_PROPERTY(QString language READ language WRITE setLanguage NOTIFY languageChanged)
    Q_PROPERTY(QString effectiveLanguage READ effectiveLanguage NOTIFY languageChanged)

public:
    static ConfigManager *instance();

    // Getters
    QVariantList allNavItems() const { return m_allNavItems; }
    QVariantList visibleNavItems() const;

    QString nickname() const { return m_nickname; }
    QString avatar() const { return m_avatar; }
    QString themeMode() const { return m_themeMode; }
    QString seedColor() const { return m_seedColor; }
    QString lyricsAlign() const { return m_lyricsAlign; }
    int lyricsFontSize() const { return m_lyricsFontSize; }
    bool showTrans() const { return m_showTrans; }
    bool autoCollapseRail() const { return m_autoCollapseRail; }
    QString audioDriver() const { return m_audioDriver; }
    QString resampler() const { return m_resampler; }
    QString replayGain() const { return m_replayGain; }
    bool cueAutoScan() const { return m_cueAutoScan; }
    bool systemTray() const { return m_systemTray; }
    QStringList scannedFolders() const { return m_scannedFolders; }
    QString artistSeparators() const { return m_artistSeparators; }
    QString libraryViewMode() const { return m_libraryViewMode; }
    QString tracksViewMode() const { return m_tracksViewMode; }
    QString titlesViewMode() const { return m_tracksViewMode; }
    QString albumsViewMode() const { return m_albumsViewMode; }
    QString artistsViewMode() const { return m_artistsViewMode; }
    QString foldersViewMode() const { return m_foldersViewMode; }
    QStringList searchHistory() const { return m_searchHistory; }
    QString language() const { return m_language; }
    QString effectiveLanguage() const;
    static QString detectSystemLanguage();

    // Invokables
    Q_INVOKABLE void saveNavItems(const QVariantList &items);
    Q_INVOKABLE void resetNavItems();

    Q_INVOKABLE void setNickname(const QString &nick);
    Q_INVOKABLE void setAvatar(const QString &avatarPath);
    Q_INVOKABLE void openSelectAvatarDialog();
    Q_INVOKABLE void resetAvatar();

    Q_INVOKABLE void setThemeMode(const QString &mode);
    Q_INVOKABLE void setSeedColor(const QString &hex);

    Q_INVOKABLE void setLyricsAlign(const QString &align);
    Q_INVOKABLE void setLyricsFontSize(int size);
    Q_INVOKABLE void setShowTrans(bool show);
    Q_INVOKABLE void setAutoCollapseRail(bool collapse);

    Q_INVOKABLE void setAudioDriver(const QString &driver);
    Q_INVOKABLE void setResampler(const QString &resampler);
    Q_INVOKABLE void setReplayGain(const QString &replayGain);
    Q_INVOKABLE void setCueAutoScan(bool cue);
    Q_INVOKABLE void setSystemTray(bool tray);

    Q_INVOKABLE void setArtistSeparators(const QString &separators);
    Q_INVOKABLE void addScannedFolder(const QString &folderPath);
    Q_INVOKABLE void removeScannedFolder(const QString &folderPath);
    Q_INVOKABLE void openAddFolderDialog();
    Q_INVOKABLE void rescanLibrary();
    Q_INVOKABLE void setLibraryViewMode(const QString &mode);
    Q_INVOKABLE void setTracksViewMode(const QString &mode);
    Q_INVOKABLE void setTitlesViewMode(const QString &mode);
    Q_INVOKABLE void setAlbumsViewMode(const QString &mode);
    Q_INVOKABLE void setArtistsViewMode(const QString &mode);
    Q_INVOKABLE void setFoldersViewMode(const QString &mode);
    Q_INVOKABLE QString viewModeForTab(const QString &tab) const;
    Q_INVOKABLE void setViewModeForTab(const QString &tab, const QString &mode);

    Q_INVOKABLE void setLanguage(const QString &lang);
    Q_INVOKABLE void addSearchHistory(const QString &query);
    Q_INVOKABLE void removeSearchHistory(const QString &query);
    Q_INVOKABLE void clearSearchHistory();

signals:
    void navItemsChanged();
    void nicknameChanged(const QString &nickname);
    void avatarChanged(const QString &avatar);
    void themeModeChanged(const QString &themeMode);
    void seedColorChanged(const QString &seedColor);
    void lyricsAlignChanged(const QString &align);
    void lyricsFontSizeChanged(int fontSize);
    void showTransChanged(bool showTrans);
    void autoCollapseRailChanged(bool autoCollapse);
    void audioDriverChanged(const QString &driver);
    void resamplerChanged(const QString &resampler);
    void replayGainChanged(const QString &replayGain);
    void cueAutoScanChanged(bool cueAutoScan);
    void systemTrayChanged(bool systemTray);
    void scannedFoldersChanged(const QStringList &folders);
    void artistSeparatorsChanged(const QString &separators);
    void libraryViewModeChanged(const QString &mode);
    void tracksViewModeChanged(const QString &mode);
    void titlesViewModeChanged(const QString &mode);
    void albumsViewModeChanged(const QString &mode);
    void artistsViewModeChanged(const QString &mode);
    void foldersViewModeChanged(const QString &mode);
    void searchHistoryChanged();
    void languageChanged(const QString &language);

private:
    explicit ConfigManager(QObject *parent = nullptr);
    void loadSettings();
    void saveSettings();
    QVariantList defaultNavItems() const;

    QVariantList m_allNavItems;
    QString m_nickname = "RinCynar";
    QString m_avatar = "";
    QString m_themeMode = "system";
    QString m_seedColor = "#39C5BB";
    QString m_lyricsAlign = "right";
    int m_lyricsFontSize = 30;
    bool m_showTrans = true;
    bool m_autoCollapseRail = true;
    QString m_audioDriver = "WASAPI Exclusive";
    QString m_resampler = "SoX Resampler High Quality";
    QString m_replayGain = "Track Mode (-18 LUFS)";
    bool m_cueAutoScan = true;
    bool m_systemTray = true;
    QStringList m_scannedFolders;
    QString m_artistSeparators = "/";
    QString m_libraryViewMode = "compact";
    QString m_tracksViewMode = "compact";
    QString m_albumsViewMode = "compact";
    QString m_artistsViewMode = "compact";
    QString m_foldersViewMode = "compact";
    QStringList m_searchHistory;
    QString m_language = "system";
};
