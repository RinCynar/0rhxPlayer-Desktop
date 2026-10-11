#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlProperty>
#include <QFontDatabase>
#include <QFont>
#include <QIcon>
#include <QDir>
#include <QFileInfo>
#include <QDebug>

#include <QFile>
#include <QTextStream>
#include <QSystemTrayIcon>
#include <QMenu>
#include <QAction>
#include <QTranslator>
#include <QPointer>
#include <QTimer>
#include "core/PathManager.h"
#include "audio/AudioEngine.h"
#include "ui/SvgIcon.h"
#include "ui/RoundedImage.h"
#include "library/LibraryManager.h"
#include "config/ConfigManager.h"
#include "model/TrackModel.h"
#include "model/AlbumModel.h"
#include "model/LyricModel.h"

#include <QQuickWindow>

#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <dwmapi.h>
#include <uxtheme.h>
#include <QAbstractNativeEventFilter>

#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif

#ifndef DWMWCP_ROUND
enum DWM_WINDOW_CORNER_PREFERENCE {
    DWMWCP_DEFAULT = 0,
    DWMWCP_DONOTROUND = 1,
    DWMWCP_ROUND = 2,
    DWMWCP_ROUNDSMALL = 3
};
#endif

class FramelessNativeFilter : public QAbstractNativeEventFilter {
public:
    explicit FramelessNativeFilter(HWND hwnd) : m_hwnd(hwnd) {}

    bool nativeEventFilter(const QByteArray &eventType, void *message, qintptr *result) override {
        if (eventType.startsWith("windows_")) {
            MSG *msg = static_cast<MSG*>(message);
            if (msg->hwnd == m_hwnd && msg->message == WM_NCCALCSIZE) {
                if (msg->wParam == TRUE) {
                    *result = 0;
                    return true;
                }
            }
        }
        return false;
    }
private:
    HWND m_hwnd;
};
#endif

void customLogHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    Q_UNUSED(type);
    Q_UNUSED(context);
    static QFile logFile;
    if (!logFile.isOpen()) {
        QString logPath = PathManager::instance()->appLogFile();
        QFileInfo fi(logPath);
        QDir().mkpath(fi.dir().absolutePath());
        logFile.setFileName(logPath);
        logFile.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text);
    }
    if (logFile.isOpen()) {
        QTextStream out(&logFile);
        out << msg << "\n";
        out.flush();
    }
    fprintf(stderr, "%s\n", qPrintable(msg));
    fflush(stderr);
}

int main(int argc, char *argv[])
{
    // High DPI scaling is enabled by default in Qt 6
    QApplication app(argc, argv);
    PathManager::instance()->ensureDirsExist();
    qInstallMessageHandler(customLogHandler);

    app.setApplicationName("0rhxPlayer");
    app.setOrganizationName("0rhx");
    app.setApplicationVersion("1.1.0");
    app.setWindowIcon(QIcon(":/assets/icons/icon.svg"));

    // ------------------------------------------------------------------------
    // Step 2: Load Noto Sans CJK SC / JP fonts and set as default font
    // ------------------------------------------------------------------------
    const QString appDir = QCoreApplication::applicationDirPath();
    const QStringList fontFiles = {
        "NotoSansSC-Regular.ttf",
        "NotoSansSC-Bold.ttf",
        "NotoSansJP-Regular.ttf",
        "NotoSansJP-Bold.ttf"
    };

    QString loadedPrimaryFamily;
    for (const QString &file : fontFiles) {
        QString candidate = appDir + "/assets/fonts/" + file;
        if (!QFileInfo::exists(candidate)) {
            candidate = QDir::currentPath() + "/assets/fonts/" + file;
        }

        if (QFileInfo::exists(candidate)) {
            int id = QFontDatabase::addApplicationFont(candidate);
            if (id != -1) {
                const QStringList families = QFontDatabase::applicationFontFamilies(id);
                qDebug() << "[Font] Successfully registered font:" << candidate << "families:" << families;
                if (loadedPrimaryFamily.isEmpty() && !families.isEmpty()) {
                    loadedPrimaryFamily = families.first();
                }
            } else {
                qWarning() << "[Font] Failed to register font:" << candidate;
            }
        } else {
            qWarning() << "[Font] Font file not found at:" << candidate;
        }
    }

    QFont appFont(loadedPrimaryFamily.isEmpty() ? "Noto Sans SC" : loadedPrimaryFamily);
    appFont.setFamilies({ "Noto Sans SC", "Noto Sans JP", "Noto Sans CJK SC", "Noto Sans", "Segoe UI", "sans-serif" });
    appFont.setPixelSize(14);
    QGuiApplication::setFont(appFont);
    qDebug() << "[Font] Application default font set to:" << appFont.families();

    // ------------------------------------------------------------------------
    // Step 5: Register native AudioEngine & LibraryManager singletons to QML
    qmlRegisterSingletonInstance("rhx.core", 1, 0, "PathManager", PathManager::instance());
    qmlRegisterSingletonInstance("rhx.audio", 1, 0, "AudioEngine", AudioEngine::instance());
    qmlRegisterSingletonInstance("rhx.library", 1, 0, "LibraryManager", LibraryManager::instance());
    qmlRegisterSingletonInstance("rhx.config", 1, 0, "ConfigManager", ConfigManager::instance());
    qmlRegisterType<SvgIcon>("rhx.ui", 1, 0, "SvgIcon");
    qmlRegisterType<RoundedImage>("rhx.ui", 1, 0, "RoundedImage");
    qmlRegisterType<TrackModel>("rhx.model", 1, 0, "TrackModel");
    qmlRegisterType<AlbumModel>("rhx.model", 1, 0, "AlbumModel");
    qmlRegisterType<LyricModel>("rhx.model", 1, 0, "LyricModel");
    qmlRegisterSingletonType(QUrl(QStringLiteral("qrc:/src/qml/Theme.qml")), "rhx.theme", 1, 0, "Theme");
    qmlRegisterSingletonType(QUrl(QStringLiteral("qrc:/src/qml/I18n.qml")), "rhx.i18n", 1, 0, "I18n");

    // ------------------------------------------------------------------------
    // System Tray Management & Application Lifecycle
    // ------------------------------------------------------------------------
    QApplication::setQuitOnLastWindowClosed(!ConfigManager::instance()->systemTray());
    QObject::connect(ConfigManager::instance(), &ConfigManager::systemTrayChanged, []() {
        QApplication::setQuitOnLastWindowClosed(!ConfigManager::instance()->systemTray());
    });

    QSystemTrayIcon *trayIcon = new QSystemTrayIcon(QIcon(":/assets/icons/icon.svg"), &app);
    trayIcon->setToolTip("0rhxPlayer");

    QMenu *trayMenu = new QMenu();
    QAction *restoreAction = trayMenu->addAction(QCoreApplication::translate("TrayMenu", "Show Main Window"));
    trayMenu->addSeparator();
    QAction *playPauseAction = trayMenu->addAction(QCoreApplication::translate("TrayMenu", "Play / Pause"));
    QAction *nextAction = trayMenu->addAction(QCoreApplication::translate("TrayMenu", "Next Track"));
    QAction *prevAction = trayMenu->addAction(QCoreApplication::translate("TrayMenu", "Previous Track"));
    trayMenu->addSeparator();
    QAction *quitAction = trayMenu->addAction(QCoreApplication::translate("TrayMenu", "Exit"));
    trayIcon->setContextMenu(trayMenu);

    auto updateTrayTexts = [restoreAction, playPauseAction, nextAction, prevAction, quitAction]() {
        restoreAction->setText(QCoreApplication::translate("TrayMenu", "Show Main Window"));
        playPauseAction->setText(QCoreApplication::translate("TrayMenu", "Play / Pause"));
        nextAction->setText(QCoreApplication::translate("TrayMenu", "Next Track"));
        prevAction->setText(QCoreApplication::translate("TrayMenu", "Previous Track"));
        quitAction->setText(QCoreApplication::translate("TrayMenu", "Exit"));
    };

    QObject::connect(playPauseAction, &QAction::triggered, []() {
        if (AudioEngine::instance()->playbackState() == AudioEngine::PlaybackState::Playing) {
            AudioEngine::instance()->pause();
        } else {
            AudioEngine::instance()->resume();
        }
    });
    QObject::connect(nextAction, &QAction::triggered, []() {
        AudioEngine::instance()->playNext();
    });
    QObject::connect(prevAction, &QAction::triggered, []() {
        AudioEngine::instance()->playPrevious();
    });
    QObject::connect(quitAction, &QAction::triggered, [&app]() {
        QApplication::quit();
    });

    auto updateTrayVisibility = [trayIcon]() {
        if (ConfigManager::instance()->systemTray()) {
            trayIcon->show();
        } else {
            trayIcon->hide();
        }
    };
    updateTrayVisibility();
    QObject::connect(ConfigManager::instance(), &ConfigManager::systemTrayChanged, updateTrayVisibility);

    // ------------------------------------------------------------------------
    // Step 1: Launch QML Application Engine
    // ------------------------------------------------------------------------
    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.rootContext()->setContextProperty("PathManager", PathManager::instance());

    // ------------------------------------------------------------------------
    // Multi-language Application & Qt Translator with Dynamic Hot Retranslation
    // ------------------------------------------------------------------------
    static QTranslator s_appTranslator;
    static QTranslator s_qtTranslator;

    auto updateAppTranslation = [&app, &engine, updateTrayTexts](const QString &langConfig) {
        QString effectiveLang = (langConfig == "system")
            ? ConfigManager::instance()->effectiveLanguage()
            : langConfig;

        app.removeTranslator(&s_appTranslator);
        app.removeTranslator(&s_qtTranslator);

        QString qmApp;
        QString qmQt;
        if (effectiveLang == "zh") {
            qmApp = "0rhxplayer_zh_CN.qm";
            qmQt = "qt_zh_CN.qm";
        } else if (effectiveLang == "ja") {
            qmApp = "0rhxplayer_ja_JP.qm";
            qmQt = "qt_ja.qm";
        } else {
            qmApp = "";
            qmQt = "qt_en.qm";
        }

        if (!qmApp.isEmpty()) {
            if (s_appTranslator.load(":/translations/" + qmApp) ||
                s_appTranslator.load(QCoreApplication::applicationDirPath() + "/translations/" + qmApp) ||
                s_appTranslator.load(QDir::currentPath() + "/translations/" + qmApp)) {
                app.installTranslator(&s_appTranslator);
                qDebug() << "[I18n] Successfully installed application translator:" << qmApp << "(effective:" << effectiveLang << "config:" << langConfig << ")";
            } else {
                qWarning() << "[I18n] Failed to load application translator:" << qmApp;
            }
        } else {
            qDebug() << "[I18n] Switched to English (built-in source strings). (effective:" << effectiveLang << "config:" << langConfig << ")";
        }

        if (!qmQt.isEmpty()) {
            if (s_qtTranslator.load(QCoreApplication::applicationDirPath() + "/translations/" + qmQt) ||
                s_qtTranslator.load(QDir::currentPath() + "/translations/" + qmQt)) {
                app.installTranslator(&s_qtTranslator);
            }
        }

        updateTrayTexts();
        engine.retranslate();
    };

    updateAppTranslation(ConfigManager::instance()->language());
    QObject::connect(ConfigManager::instance(), &ConfigManager::languageChanged, [updateAppTranslation]() {
        updateAppTranslation(ConfigManager::instance()->language());
    });

    // Sync initial configuration states
    AudioEngine::instance()->setExclusiveMode(ConfigManager::instance()->audioDriver() == "WASAPI Exclusive");

    engine.load(QUrl(QStringLiteral("qrc:/src/qml/Main.qml")));

    if (!ConfigManager::instance()->scannedFolders().isEmpty()) {
        QTimer::singleShot(100, []() {
            LibraryManager::instance()->scanFolders(ConfigManager::instance()->scannedFolders());
        });
    }

    QPointer<QQuickWindow> mainWindow = nullptr;
    if (!engine.rootObjects().isEmpty()) {
        mainWindow = qobject_cast<QQuickWindow*>(engine.rootObjects().first());
    }

    if (mainWindow && app.arguments().contains("--tab-settings")) {
        mainWindow->setProperty("currentTab", "settings");
    }

    if (mainWindow && app.arguments().contains("--tab-library")) {
        mainWindow->setProperty("currentTab", "library");
    }

    if (mainWindow && app.arguments().contains("--tab-search")) {
        mainWindow->setProperty("currentTab", "search");
    }

    if (mainWindow && app.arguments().contains("--tab-queue")) {
        mainWindow->setProperty("currentTab", "queue");
    }

    if (app.arguments().contains("--demo-library")) {
        TrackItem t1;
        t1.path = "C:/Music/Alpha.flac";
        t1.title = "7 Days to Know";
        t1.artist = "thom";
        t1.album = "7 Days to Know";
        t1.durationMs = 208000;
        t1.format = "FLAC";
        t1.bitrateKbps = 940;
        t1.fileSizeBytes = 25000000;

        TrackItem t2;
        t2.path = "C:/Music/Beta.mp3";
        t2.title = "Sayonara Hatsukoi (feat. Megurine Luka)";
        t2.artist = "crafTUNER/巡音ルカ";
        t2.album = "Azuressence";
        t2.durationMs = 203000;
        t2.format = "MP3";
        t2.bitrateKbps = 320;
        t2.fileSizeBytes = 8100000;

        TrackItem t3;
        t3.path = "C:/Music/Gamma.flac";
        t3.title = "Shelter";
        t3.artist = "Porter Robinson & Madeon";
        t3.album = "Shelter";
        t3.durationMs = 218000;
        t3.format = "FLAC";
        t3.bitrateKbps = 1010;
        t3.fileSizeBytes = 28000000;

        TrackItem t4;
        t4.path = "C:/Music/Delta.flac";
        t4.title = "World.Execute (Me);";
        t4.artist = "Mili";
        t4.album = "Miracle Milk";
        t4.durationMs = 211000;
        t4.format = "FLAC";
        t4.bitrateKbps = 980;
        TrackItem t5;
        t5.path = "C:/Music/Epsilon.flac";
        t5.title = "Ghost City Tokyo";
        t5.artist = "Ayase";
        t5.album = "Ghost City Tokyo";
        t5.durationMs = 195000;
        t5.format = "FLAC";
        t5.bitrateKbps = 950;
        t5.fileSizeBytes = 24000000;

        TrackItem t6;
        t6.path = "C:/Music/Zeta.flac";
        t6.title = "Yoru ni Kakeru";
        t6.artist = "YOASOBI";
        t6.album = "THE BOOK";
        t6.durationMs = 261000;
        t6.format = "FLAC";
        t6.bitrateKbps = 1020;
        t6.fileSizeBytes = 32000000;

        TrackItem t7;
        t7.path = "C:/Music/Eta.flac";
        t7.title = "Tracing A Dream";
        t7.artist = "YOASOBI";
        t7.album = "THE BOOK";
        t7.durationMs = 242000;
        t7.format = "FLAC";
        t7.bitrateKbps = 990;
        t7.fileSizeBytes = 29000000;

        TrackItem t8;
        t8.path = "C:/Music/Theta.flac";
        t8.title = "Tabun";
        t8.artist = "YOASOBI";
        t8.album = "THE BOOK";
        t8.durationMs = 258000;
        t8.format = "FLAC";
        t8.bitrateKbps = 960;
        t8.fileSizeBytes = 30000000;

        LibraryManager::instance()->setLibraryTracks({t1, t2, t3, t4, t5, t6, t7, t8});
    }

    if (mainWindow && app.arguments().contains("--demo-artist")) {
        QObject *libView = mainWindow->findChild<QObject*>("libraryView");
        if (libView) {
            libView->setProperty("currentTab", "artists");
            LibraryManager::instance()->filterTracksByArtist("thom");
            QVariantMap group;
            group["type"] = "artist";
            group["name"] = "thom";
            group["subTitle"] = "1 Track";
            group["coverUrl"] = "";
            libView->setProperty("selectedGroup", group);
        }
    }

    if (mainWindow && app.arguments().contains("--demo-folders")) {
        QObject *libView = mainWindow->findChild<QObject*>("libraryView");
        if (libView) {
            libView->setProperty("currentTab", "folders");
            libView->setProperty("viewMode", "grid");
        }
    }

    if (mainWindow && app.arguments().contains("--demo-artists-tab")) {
        QObject *libView = mainWindow->findChild<QObject*>("libraryView");
        if (libView) {
            libView->setProperty("currentTab", "artists");
            libView->setProperty("viewMode", "grid");
        }
    }

    if (mainWindow && app.arguments().contains("--demo-albums")) {
        QObject *libView = mainWindow->findChild<QObject*>("libraryView");
        if (libView) {
            libView->setProperty("currentTab", "albums");
            libView->setProperty("viewMode", "list");
        }
    }

    if (mainWindow && app.arguments().contains("--demo-albums-grid")) {
        QObject *libView = mainWindow->findChild<QObject*>("libraryView");
        if (libView) {
            libView->setProperty("currentTab", "albums");
            libView->setProperty("viewMode", "grid");
        }
    }

    if (mainWindow && app.arguments().contains("--demo-grid")) {
        QObject *libView = mainWindow->findChild<QObject*>("libraryView");
        if (libView) {
            libView->setProperty("viewMode", "grid");
        }
    }

    if (mainWindow && app.arguments().contains("--demo-queue")) {
        mainWindow->setProperty("currentTab", "queue");
        TrackItem t1;
        t1.path = "C:/Music/Alpha.flac";
        t1.title = "7 Days to Know";
        t1.artist = "thom";
        t1.album = "7 Days to Know";
        t1.durationMs = 208000;
        t1.format = "FLAC";

        TrackItem t2;
        t2.path = "C:/Music/Beta.mp3";
        t2.title = "Sayonara Hatsukoi (feat. Megurine Luka)";
        t2.artist = "crafTUNER/巡音ルカ";
        t2.album = "Azuressence";
        t2.durationMs = 203000;
        t2.format = "MP3";

        TrackItem t3;
        t3.path = "C:/Music/Gamma.flac";
        t3.title = "Shelter";
        t3.artist = "Porter Robinson & Madeon";
        t3.album = "Shelter";
        t3.durationMs = 218000;
        t3.format = "FLAC";

        TrackItem t4;
        t4.path = "C:/Music/Delta.flac";
        t4.title = "World.Execute (Me);";
        t4.artist = "Mili";
        t4.album = "Miracle Milk";
        t4.durationMs = 211000;
        t4.format = "FLAC";

        TrackItem t5;
        t5.path = "C:/Music/Epsilon.flac";
        t5.title = "Ghost City Tokyo";
        t5.artist = "Ayase";
        t5.album = "Ghost City Tokyo";
        t5.durationMs = 195000;
        t5.format = "FLAC";

        LibraryManager::instance()->setLibraryTracks({t1, t2, t3, t4, t5});
        AudioEngine::instance()->setPlaylist({t1.path, t2.path, t3.path, t4.path, t5.path}, 1);
    }

    if (mainWindow && app.arguments().contains("--demo-nav-dialog")) {
        QObject *dialog = mainWindow->findChild<QObject*>("navCustomDialog");
        if (dialog) {
            dialog->setProperty("isOpen", true);
        }
    }

    if (mainWindow && app.arguments().contains("--demo-nowplaying")) {
        mainWindow->setProperty("isNowPlayingOpen", true);
    }

    if (mainWindow && app.arguments().contains("--demo-search")) {
        mainWindow->setProperty("currentTab", "search");
    }

    if (mainWindow && app.arguments().contains("--demo-settings")) {
        mainWindow->setProperty("currentTab", "settings");
    }

    if (mainWindow && app.arguments().contains("--demo-playlist")) {
        mainWindow->setProperty("currentTab", "playlist");
    }

    if (app.arguments().contains("--test-library")) {
        qInfo() << "=== Testing LibraryManager & LibraryView Integration ===";
        bool pass = true;

        QObject *libView = mainWindow ? mainWindow->findChild<QObject*>("libraryView") : nullptr;
        qInfo() << "[Test] libraryView object found:" << (libView != nullptr);
        if (!libView) pass = false;

        LibraryManager *libMgr = LibraryManager::instance();
        qInfo() << "[Test] allTracks model:" << (libMgr->allTracks() != nullptr);
        qInfo() << "[Test] allAlbums model:" << (libMgr->allAlbums() != nullptr);
        qInfo() << "[Test] allArtists model:" << (libMgr->allArtists() != nullptr);
        qInfo() << "[Test] allFolders model:" << (libMgr->allFolders() != nullptr);
        qInfo() << "[Test] filteredTracks model:" << (libMgr->filteredTracks() != nullptr);

        if (!libMgr->allTracks() || !libMgr->allAlbums() || !libMgr->allArtists() ||
            !libMgr->allFolders() || !libMgr->filteredTracks()) {
            pass = false;
        }

        TrackItem t1;
        t1.path = "C:/Music/artist_a/album_1/01.flac";
        t1.title = "Zeta Song";
        t1.artist = "Artist Beta / Artist Gamma";
        t1.album = "Album Omega";
        t1.durationMs = 180000;
        t1.format = "FLAC";
        t1.bitrateKbps = 900;
        t1.fileSizeBytes = 25000000;
        t1.dateAdded = 1000;
        t1.dateModified = 3000;

        TrackItem t2;
        t2.path = "C:/Music/artist_b/album_2/02.mp3";
        t2.title = "Alpha Song";
        t2.artist = "Artist Alpha";
        t2.album = "Album Alpha";
        t2.durationMs = 240000;
        t2.format = "MP3";
        t2.bitrateKbps = 320;
        t2.fileSizeBytes = 8000000;
        t2.dateAdded = 2000;
        t2.dateModified = 1000;

        TrackItem t3;
        t3.path = "C:/Music/artist_a/album_1/03.flac";
        t3.title = "Beta Song";
        t3.artist = "Artist Beta";
        t3.album = "Album Omega";
        t3.durationMs = 120000;
        t3.format = "FLAC";
        t3.bitrateKbps = 1411;
        t3.fileSizeBytes = 40000000;
        t3.dateAdded = 3000;
        t3.dateModified = 2000;

        libMgr->setLibraryTracks({t1, t2, t3});
        qInfo() << "[Test] Track count:" << libMgr->allTracks()->rowCount();
        qInfo() << "[Test] Album count:" << libMgr->allAlbums()->rowCount();
        qInfo() << "[Test] Artist count:" << libMgr->allArtists()->rowCount();
        qInfo() << "[Test] Folder count:" << libMgr->allFolders()->rowCount();

        if (libMgr->allAlbums()->rowCount() != 2) {
            qWarning() << "[Test] Expected 2 albums, got:" << libMgr->allAlbums()->rowCount();
            pass = false;
        }

        if (libMgr->allArtists()->rowCount() != 3) {
            qWarning() << "[Test] Expected 3 artists, got:" << libMgr->allArtists()->rowCount();
            pass = false;
        }

        libMgr->sortTracks("title_asc");
        QString firstTitle = libMgr->allTracks()->tracks().first().title;
        qInfo() << "[Test] Sort tracks by title ASC first:" << firstTitle;
        if (firstTitle != "Alpha Song") pass = false;

        // Test Bitrate sorting
        libMgr->sortTracks("bitrate_desc");
        qInfo() << "[Test] Sort tracks by bitrate DESC first:" << libMgr->allTracks()->tracks().first().title
                << "bitrate:" << libMgr->allTracks()->tracks().first().bitrateKbps;
        if (libMgr->allTracks()->tracks().first().title != "Beta Song") pass = false;

        libMgr->sortTracks("bitrate_asc");
        qInfo() << "[Test] Sort tracks by bitrate ASC first:" << libMgr->allTracks()->tracks().first().title
                << "bitrate:" << libMgr->allTracks()->tracks().first().bitrateKbps;
        if (libMgr->allTracks()->tracks().first().title != "Alpha Song") pass = false;

        // Test File Size sorting
        libMgr->sortTracks("size_desc");
        qInfo() << "[Test] Sort tracks by size DESC first:" << libMgr->allTracks()->tracks().first().title
                << "size:" << libMgr->allTracks()->tracks().first().fileSizeBytes;
        if (libMgr->allTracks()->tracks().first().title != "Beta Song") pass = false;

        libMgr->sortTracks("size_asc");
        qInfo() << "[Test] Sort tracks by size ASC first:" << libMgr->allTracks()->tracks().first().title
                << "size:" << libMgr->allTracks()->tracks().first().fileSizeBytes;
        if (libMgr->allTracks()->tracks().first().title != "Alpha Song") pass = false;

        // Test Date Added sorting
        libMgr->sortTracks("date_added_desc");
        qInfo() << "[Test] Sort tracks by date added DESC first:" << libMgr->allTracks()->tracks().first().title;
        if (libMgr->allTracks()->tracks().first().title != "Beta Song") pass = false;

        libMgr->sortTracks("date_added_asc");
        qInfo() << "[Test] Sort tracks by date added ASC first:" << libMgr->allTracks()->tracks().first().title;
        if (libMgr->allTracks()->tracks().first().title != "Zeta Song") pass = false;

        // Test Date Modified sorting
        libMgr->sortTracks("date_modified_desc");
        qInfo() << "[Test] Sort tracks by date modified DESC first:" << libMgr->allTracks()->tracks().first().title;
        if (libMgr->allTracks()->tracks().first().title != "Zeta Song") pass = false;

        libMgr->sortTracks("date_modified_asc");
        qInfo() << "[Test] Sort tracks by date modified ASC first:" << libMgr->allTracks()->tracks().first().title;
        if (libMgr->allTracks()->tracks().first().title != "Alpha Song") pass = false;

        // Test ViewMode persistence
        ConfigManager::instance()->setLibraryViewMode("grid");
        qInfo() << "[Test] ConfigManager viewMode set to grid:" << (ConfigManager::instance()->libraryViewMode() == "grid");
        if (ConfigManager::instance()->libraryViewMode() != "grid") pass = false;
        ConfigManager::instance()->setLibraryViewMode("list");
        if (ConfigManager::instance()->libraryViewMode() != "list") pass = false;

        // Test Per-Tab ViewMode persistence and tab helpers (CCCC defaults)
        ConfigManager *cfg = ConfigManager::instance();
        cfg->setTracksViewMode("compact");
        cfg->setAlbumsViewMode("compact");
        cfg->setArtistsViewMode("compact");
        cfg->setFoldersViewMode("compact");
        qInfo() << "[Test] Tracks view mode:" << cfg->tracksViewMode();
        qInfo() << "[Test] Albums view mode:" << cfg->albumsViewMode();
        qInfo() << "[Test] Artists view mode:" << cfg->artistsViewMode();
        qInfo() << "[Test] Folders view mode:" << cfg->foldersViewMode();
        if (cfg->tracksViewMode() != "compact" || cfg->albumsViewMode() != "compact" ||
            cfg->artistsViewMode() != "compact" || cfg->foldersViewMode() != "compact") {
            qWarning() << "[Test] Per-tab view mode defaults CCCC check failed";
            pass = false;
        }

        cfg->setViewModeForTab("tracks", "card");
        cfg->setViewModeForTab("folders", "compact");
        if (cfg->viewModeForTab("tracks") != "card" || cfg->viewModeForTab("folders") != "compact") {
            qWarning() << "[Test] setViewModeForTab helper check failed";
            pass = false;
        }
        cfg->setViewModeForTab("tracks", "compact");
        cfg->setViewModeForTab("folders", "compact");

        libMgr->filterTracksByAlbum("Album Omega");
        qInfo() << "[Test] Filtered tracks by Album Omega count:" << libMgr->filteredTracks()->rowCount();
        if (libMgr->filteredTracks()->rowCount() != 2) pass = false;

        libMgr->filterTracksByArtist("Artist Alpha");
        qInfo() << "[Test] Filtered tracks by Artist Alpha count:" << libMgr->filteredTracks()->rowCount();
        if (libMgr->filteredTracks()->rowCount() != 1) pass = false;

        // Verify artistAlbums populated for Artist Beta
        libMgr->filterTracksByArtist("Artist Beta");
        qInfo() << "[Test] Filtered tracks for Artist Beta count:" << libMgr->filteredTracks()->rowCount();
        qInfo() << "[Test] Artist Beta albums count:" << (libMgr->artistAlbums() ? libMgr->artistAlbums()->rowCount() : -1);
        if (!libMgr->artistAlbums() || libMgr->artistAlbums()->rowCount() != 1) pass = false;
        if (libMgr->artistAlbums() && libMgr->artistAlbums()->albums().first().name != "Album Omega") pass = false;

        QStringList paths = libMgr->getTrackPaths(libMgr->filteredTracks());
        qInfo() << "[Test] Track paths count for Artist Beta:" << paths.size();
        if (paths.size() != 2) pass = false;

        // Test Cache Persistence (Cold Start Instant Hydration)
        libMgr->saveLibraryCache();
        int countBeforeClear = libMgr->trackCount();
        libMgr->clearLibrary();
        if (libMgr->trackCount() != 0) {
            qWarning() << "[Test] clearLibrary failed to reset track count";
            pass = false;
        }
        libMgr->setLibraryTracks({t1, t2, t3});
        libMgr->saveLibraryCache();
        libMgr->loadLibraryCache();
        qInfo() << "[Test] Cache reloaded track count:" << libMgr->trackCount();
        if (libMgr->trackCount() != countBeforeClear) {
            qWarning() << "[Test] Cache reload failed to restore tracks";
            pass = false;
        }

        updateAppTranslation("zh");
        QString zhTracks = QCoreApplication::translate("LibraryView", "Tracks");
        QString zhTitles = QCoreApplication::translate("LibraryView", "Titles");
        QString zhAlbums = QCoreApplication::translate("LibraryView", "Albums");
        QString zhPlayAll = QCoreApplication::translate("LibraryView", "Play All");
        qInfo() << "[Test] Chinese Tracks:" << zhTracks << "Titles:" << zhTitles << "Albums:" << zhAlbums << "Play All:" << zhPlayAll;
        if (zhTracks != QString::fromUtf8("单曲") || zhTitles != QString::fromUtf8("单曲") || zhAlbums != QString::fromUtf8("专辑") || zhPlayAll != QString::fromUtf8("播放全部")) {
            pass = false;
        }

        updateAppTranslation("ja");
        QString jaTracks = QCoreApplication::translate("LibraryView", "Tracks");
        QString jaTitles = QCoreApplication::translate("LibraryView", "Titles");
        QString jaAlbums = QCoreApplication::translate("LibraryView", "Albums");
        QString jaPlayAll = QCoreApplication::translate("LibraryView", "Play All");
        qInfo() << "[Test] Japanese Tracks:" << jaTracks << "Titles:" << jaTitles << "Albums:" << jaAlbums << "Play All:" << jaPlayAll;
        if (jaTracks != QString::fromUtf8("曲") || jaTitles != QString::fromUtf8("曲") || jaAlbums != QString::fromUtf8("アルバム") || jaPlayAll != QString::fromUtf8("すべて再生")) {
            pass = false;
        }

        updateAppTranslation(ConfigManager::instance()->language());

        // Test Details View Drill-Down, Scroll-to-Top and Ghost ScrollBar Elimination
        if (libView) {
            if (mainWindow) {
                mainWindow->setProperty("currentTab", "library");
            }
            QCoreApplication::processEvents();

            libView->setProperty("currentTab", "artists");
            libMgr->filterTracksByArtist("Artist Beta");
            QVariantMap group;
            group["type"] = "artist";
            group["name"] = "Artist Beta";
            group["subTitle"] = "2 Tracks";
            group["coverUrl"] = "";
            libView->setProperty("selectedGroup", group);
            QCoreApplication::processEvents();

            QObject *detailsContainer = libView->findChild<QObject*>("detailsContainer");
            QObject *rootTabsContainer = libView->findChild<QObject*>("rootTabsContainer");
            if (detailsContainer) {
                bool dVis = detailsContainer->property("visible").toBool();
                qInfo() << "[Test] detailsContainer visible:" << dVis;
                if (!dVis) pass = false;
            }
            if (rootTabsContainer) {
                bool rVis = rootTabsContainer->property("visible").toBool();
                qInfo() << "[Test] rootTabsContainer hidden when in details:" << (!rVis);
                if (rVis) pass = false;
            }

            // Inspect all visible ScrollBar controls under libraryView
            int visibleScrollBars = 0;
            const auto allChildren = libView->findChildren<QQuickItem*>();
            for (auto *item : allChildren) {
                if (item && QString(item->metaObject()->className()).contains("ScrollBar")) {
                    if (item->isVisible() && item->opacity() > 0.05 && item->width() > 0 && item->height() > 0) {
                        visibleScrollBars++;
                        qInfo() << "[Test] Found visible ScrollBar:" << item << "geometry:" << item->x() << item->y() << item->width() << item->height();
                    }
                }
            }
            qInfo() << "[Test] Visible ScrollBar count in details view (must be <= 1):" << visibleScrollBars;
            if (visibleScrollBars > 1) {
                qWarning() << "[Test] Duplicate ghost scrollbars detected!";
                pass = false;
            }

            // Reset back to root view
            libView->setProperty("selectedGroup", QVariant());
            QCoreApplication::processEvents();
            if (rootTabsContainer) {
                bool rVis = rootTabsContainer->property("visible").toBool();
                qInfo() << "[Test] rootTabsContainer restored visible:" << rVis;
                if (!rVis) pass = false;
            }
        }

        qInfo() << "=== Library Integration Test Result:" << (pass ? "PASSED" : "FAILED") << "===";
        QTimer::singleShot(100, &app, [pass]() {
            QCoreApplication::exit(pass ? 0 : 1);
        });
    }

    if (app.arguments().contains("--test-search")) {
        qInfo() << "=== Testing SearchView & Multi-Dimensional Search Integration ===";
        bool pass = true;

        if (mainWindow) {
            mainWindow->setProperty("currentTab", "search");
        }
        QCoreApplication::processEvents();

        QObject *searchView = mainWindow ? mainWindow->findChild<QObject*>("searchView") : nullptr;
        qInfo() << "[Test] searchView object found:" << (searchView != nullptr);
        if (!searchView) pass = false;

        LibraryManager *libMgr = LibraryManager::instance();
        ConfigManager *cfg = ConfigManager::instance();

        // Populate test tracks
        TrackItem t1;
        t1.path = "C:/Music/test_a/01.flac";
        t1.title = "Zeta Song";
        t1.artist = "Artist Beta";
        t1.album = "Album Omega";
        t1.durationMs = 180000;
        t1.format = "FLAC";

        TrackItem t2;
        t2.path = "C:/Music/test_b/02.mp3";
        t2.title = "Alpha Song";
        t2.artist = "Artist Alpha";
        t2.album = "Album Alpha";
        t2.durationMs = 240000;
        t2.format = "MP3";

        TrackItem t3;
        t3.path = "C:/Music/test_c/03.flac";
        t3.title = "Beta Melody";
        t3.artist = "Artist Beta";
        t3.album = "Album Omega";
        t3.durationMs = 120000;
        t3.format = "FLAC";

        libMgr->setLibraryTracks({t1, t2, t3});
        QCoreApplication::processEvents();

        // Test 1: Search "Zeta" (only matches t1 title)
        libMgr->search("Zeta");
        QCoreApplication::processEvents();
        qInfo() << "[Test] Search 'Zeta' matched tracks count:" << libMgr->searchTracks()->rowCount();
        qInfo() << "[Test] Search 'Zeta' total matches:" << libMgr->searchTotalMatches();
        if (libMgr->searchTracks()->rowCount() != 1 || libMgr->searchTotalMatches() != 1) {
            qWarning() << "[Test] Search 'Zeta' failed";
            pass = false;
        }

        // Test 2: Search "Alpha" (matches t2 track, Album Alpha, Artist Alpha)
        libMgr->search("Alpha");
        QCoreApplication::processEvents();
        qInfo() << "[Test] Search 'Alpha' tracks:" << libMgr->searchTracks()->rowCount()
                << "albums:" << libMgr->searchAlbums()->rowCount()
                << "artists:" << libMgr->searchArtists()->rowCount()
                << "total:" << libMgr->searchTotalMatches();
        if (libMgr->searchTracks()->rowCount() != 1 ||
            libMgr->searchAlbums()->rowCount() != 1 ||
            libMgr->searchArtists()->rowCount() != 1 ||
            libMgr->searchTotalMatches() != 3) {
            qWarning() << "[Test] Search 'Alpha' multi-dimensional matching failed";
            pass = false;
        }

        // Test 3: Search "Omega" (matches t1 and t3 tracks, Album Omega)
        libMgr->search("Omega");
        QCoreApplication::processEvents();
        qInfo() << "[Test] Search 'Omega' tracks:" << libMgr->searchTracks()->rowCount()
                << "albums:" << libMgr->searchAlbums()->rowCount();
        if (libMgr->searchTracks()->rowCount() != 2 || libMgr->searchAlbums()->rowCount() != 1) {
            qWarning() << "[Test] Search 'Omega' failed";
            pass = false;
        }

        // Test 4: Search "Nonexistent"
        libMgr->search("Nonexistentxyz");
        QCoreApplication::processEvents();
        qInfo() << "[Test] Search 'Nonexistentxyz' total matches (must be 0):" << libMgr->searchTotalMatches();
        if (libMgr->searchTotalMatches() != 0) {
            qWarning() << "[Test] Zero match test failed";
            pass = false;
        }

        // Test 5: Clear Search
        libMgr->clearSearch();
        QCoreApplication::processEvents();
        qInfo() << "[Test] Clear search total matches (must be 0):" << libMgr->searchTotalMatches();
        if (libMgr->searchTotalMatches() != 0 || libMgr->isSearching()) {
            qWarning() << "[Test] Clear search failed";
            pass = false;
        }

        // Test 6: Search History Persistence
        cfg->clearSearchHistory();
        if (!cfg->searchHistory().isEmpty()) {
            qWarning() << "[Test] clearSearchHistory failed";
            pass = false;
        }
        cfg->addSearchHistory("Keyword 1");
        cfg->addSearchHistory("Keyword 2");
        qInfo() << "[Test] Search history count:" << cfg->searchHistory().size()
                << "latest:" << (cfg->searchHistory().isEmpty() ? "" : cfg->searchHistory().first());
        if (cfg->searchHistory().size() != 2 || cfg->searchHistory().first() != "Keyword 2") {
            qWarning() << "[Test] addSearchHistory failed";
            pass = false;
        }
        cfg->removeSearchHistory("Keyword 1");
        if (cfg->searchHistory().size() != 1 || cfg->searchHistory().contains("Keyword 1")) {
            qWarning() << "[Test] removeSearchHistory failed";
            pass = false;
        }
        cfg->clearSearchHistory();

        // Test 7: Translations
        updateAppTranslation("zh");
        QString zhSearch = QCoreApplication::translate("SearchView", "Search");
        QString zhNoRes = QCoreApplication::translate("SearchView", "No Results");
        QString zhHist = QCoreApplication::translate("SearchView", "Search History");
        qInfo() << "[Test] Chinese Search:" << zhSearch << "No Results:" << zhNoRes << "History:" << zhHist;
        if (zhSearch != QString::fromUtf8("搜索") || zhNoRes != QString::fromUtf8("无匹配结果") || zhHist != QString::fromUtf8("搜索历史")) {
            qWarning() << "[Test] Chinese search translations mismatch";
            pass = false;
        }

        updateAppTranslation("ja");
        QString jaSearch = QCoreApplication::translate("SearchView", "Search");
        QString jaNoRes = QCoreApplication::translate("SearchView", "No Results");
        QString jaHist = QCoreApplication::translate("SearchView", "Search History");
        qInfo() << "[Test] Japanese Search:" << jaSearch << "No Results:" << jaNoRes << "History:" << jaHist;
        if (jaSearch != QString::fromUtf8("検索") || jaNoRes != QString::fromUtf8("検索結果なし") || jaHist != QString::fromUtf8("検索履歴")) {
            qWarning() << "[Test] Japanese search translations mismatch";
            pass = false;
        }
        updateAppTranslation(ConfigManager::instance()->language());

        qInfo() << "=== Search Integration Test Result:" << (pass ? "PASSED" : "FAILED") << "===";
        QTimer::singleShot(100, &app, [pass]() {
            QCoreApplication::exit(pass ? 0 : 1);
        });
    }

    if (app.arguments().contains("--test-tray")) {
        qDebug() << "=== Testing Tray Menu & System Language Dynamic Localization ===";
        QObject *langCombo = mainWindow ? mainWindow->findChild<QObject*>("langComboBox") : nullptr;
        qDebug() << "[Test] langComboBox found:" << (langCombo != nullptr);

        auto logModel = [langCombo](const QString &step) {
            if (!langCombo) return;
            QVariant val = langCombo->property("model");
            QVariantList list = val.toList();
            for (int i = 0; i < list.size(); ++i) {
                QVariantMap m = list[i].toMap();
                qDebug().noquote() << QString("[%1] Item %2 -> value: '%3', label: '%4'")
                    .arg(step).arg(i).arg(m.value("value").toString()).arg(m.value("label").toString());
            }
        };

        // 1. Test "system"
        ConfigManager::instance()->setLanguage("system");
        qDebug() << "[Test] System config language:" << ConfigManager::instance()->language()
                 << "effective:" << ConfigManager::instance()->effectiveLanguage()
                 << "restoreAction:" << restoreAction->text();
        if (langCombo) {
            qDebug().noquote() << "[Test] QML langComboBox currentValue:" << langCombo->property("currentValue").toString()
                               << "displayText:" << langCombo->property("displayText").toString();
            logModel("System");
        }

        // 2. Test "en"
        ConfigManager::instance()->setLanguage("en");
        qDebug() << "[Test] English restoreAction:" << restoreAction->text();
        qDebug() << "[Test] English playPauseAction:" << playPauseAction->text();
        qDebug() << "[Test] English quitAction:" << quitAction->text();
        if (langCombo) {
            qDebug().noquote() << "[Test] QML English langComboBox currentValue:" << langCombo->property("currentValue").toString()
                               << "displayText:" << langCombo->property("displayText").toString();
            logModel("English");
        }

        // 3. Test "zh"
        ConfigManager::instance()->setLanguage("zh");
        qDebug().noquote() << "[Test] Chinese restoreAction:" << restoreAction->text();
        qDebug().noquote() << "[Test] Chinese playPauseAction:" << playPauseAction->text();
        qDebug().noquote() << "[Test] Chinese quitAction:" << quitAction->text();
        if (langCombo) {
            qDebug().noquote() << "[Test] QML Chinese langComboBox currentValue:" << langCombo->property("currentValue").toString()
                               << "displayText:" << langCombo->property("displayText").toString();
            logModel("Chinese");
        }

        // 4. Test "ja"
        ConfigManager::instance()->setLanguage("ja");
        qDebug().noquote() << "[Test] Japanese restoreAction:" << restoreAction->text();
        qDebug().noquote() << "[Test] Japanese playPauseAction:" << playPauseAction->text();
        qDebug().noquote() << "[Test] Japanese quitAction:" << quitAction->text();
        if (langCombo) {
            qDebug().noquote() << "[Test] QML Japanese langComboBox currentValue:" << langCombo->property("currentValue").toString()
                               << "displayText:" << langCombo->property("displayText").toString();
            logModel("Japanese");
        }

        // 5. Switch back to system
        ConfigManager::instance()->setLanguage("system");
        qDebug() << "[Test] Reverted to system, language:" << ConfigManager::instance()->language()
                 << "effective:" << ConfigManager::instance()->effectiveLanguage()
                 << "restoreAction:" << restoreAction->text();
        if (langCombo) {
            qDebug().noquote() << "[Test] QML Reverted langComboBox currentValue:" << langCombo->property("currentValue").toString()
                               << "displayText:" << langCombo->property("displayText").toString();
            logModel("RevertedSystem");
        }

        bool pass = (ConfigManager::instance()->language() == "system" &&
                     !ConfigManager::instance()->effectiveLanguage().isEmpty() &&
                     !restoreAction->text().isEmpty());

        // Assert Chinese translation
        ConfigManager::instance()->setLanguage("zh");
        if (langCombo) {
            QVariantList list = langCombo->property("model").toList();
            QString zhLabel = list[0].toMap().value("label").toString();
            bool zhOk = (zhLabel == QString::fromUtf8("跟随系统")) && (restoreAction->text() == QString::fromUtf8("显示主界面"));
            qDebug() << "[Assert] Chinese 'System' -> '跟随系统':" << zhOk << "actual:" << zhLabel;
            pass = pass && zhOk;
        }

        // Assert English translation
        ConfigManager::instance()->setLanguage("en");
        if (langCombo) {
            QVariantList list = langCombo->property("model").toList();
            QString enLabel = list[0].toMap().value("label").toString();
            bool enOk = (enLabel == "System") && (restoreAction->text() == "Show Main Window");
            qDebug() << "[Assert] English 'System' -> 'System':" << enOk << "actual:" << enLabel;
            pass = pass && enOk;
        }

        // Assert Japanese translation
        ConfigManager::instance()->setLanguage("ja");
        if (langCombo) {
            QVariantList list = langCombo->property("model").toList();
            QString jaLabel = list[0].toMap().value("label").toString();
            bool jaOk = (jaLabel == QString::fromUtf8("システム")) && (restoreAction->text() == QString::fromUtf8("メイン画面を表示"));
            qDebug() << "[Assert] Japanese 'System' -> 'システム':" << jaOk << "actual:" << jaLabel;
            pass = pass && jaOk;
        }

        // Switch back to system and verify
        ConfigManager::instance()->setLanguage("system");
        if (langCombo) {
            pass = pass && (langCombo->property("currentValue").toString() == "system");
        }
        qDebug() << "=== Tray Menu & I18n Localization Test Result:" << (pass ? "PASSED" : "FAILED") << "===";
        QTimer::singleShot(100, &app, &QCoreApplication::quit);
    }

    if (app.arguments().contains("--test-occlusion")) {
        qDebug() << "=== Testing Architecture-level Occlusion Culling & Throttling ===";
        QTimer::singleShot(250, [&app, mainWindow]() {
            QObject *container = mainWindow ? mainWindow->findChild<QObject*>("viewContainer") : nullptr;
            QObject *stack = mainWindow ? mainWindow->findChild<QObject*>("mainStackLayout") : nullptr;
            QObject *np = mainWindow ? mainWindow->findChild<QObject*>("nowPlayingView") : nullptr;
            QObject *navRail = mainWindow ? mainWindow->findChild<QObject*>("navRail") : nullptr;
            qDebug() << "[Test] viewContainer found:" << (container != nullptr);
            qDebug() << "[Test] mainStackLayout found:" << (stack != nullptr);
            qDebug() << "[Test] nowPlayingView found:" << (np != nullptr);
            qDebug() << "[Test] navRail found:" << (navRail != nullptr);

            if (!container || !stack || !np || !navRail) {
                QTimer::singleShot(50, [&app]() { QCoreApplication::exit(1); });
                return;
            }

            // Check z-index of nowPlayingView
            qreal npZ = np->property("z").toReal();
            qDebug() << "[Test] nowPlayingView z-index (must be 100):" << npZ;

            // 1. Initial State: NowPlaying is closed
            mainWindow->setProperty("isNowPlayingOpen", false);
            bool collapsed = np->property("isFullyCollapsed").toBool();
            bool expanded = np->property("isFullyExpanded").toBool();
            bool containerVisible = container->property("visible").toBool();
            bool containerEnabled = container->property("enabled").toBool();
            bool isLayerActive = container->property("isLayerEnabled").isValid() && container->property("isLayerEnabled").toBool();
            bool railCollapsed = navRail->property("collapsed").toBool();
            qreal initW = container->property("width").toReal();
            qreal initH = container->property("height").toReal();
            qDebug() << "[Test] Initial State - collapsed:" << collapsed << "expanded:" << expanded
                     << "containerVisible:" << containerVisible << "containerEnabled:" << containerEnabled
                     << "isLayerActive (Zero-FBO check):" << isLayerActive << "railCollapsed:" << railCollapsed
                     << "geometry:" << initW << "x" << initH;

            if (!containerVisible || !containerEnabled || expanded || !collapsed || npZ < 100 || railCollapsed || isLayerActive) {
                qWarning() << "[Test] Initial state failed!";
                QTimer::singleShot(50, [&app]() { QCoreApplication::exit(1); });
                return;
            }

            // 2. Open NowPlaying: starts expanding (Zero-FBO Overlay mode)
            bool autoCollapseConfig = ConfigManager::instance()->autoCollapseRail();
            mainWindow->setProperty("isNowPlayingOpen", true);
            bool animating = np->property("isAnimating").toBool();
            bool layerActiveDuringAnim = container->property("isLayerEnabled").isValid() && container->property("isLayerEnabled").toBool();
            bool containerEnabledDuringAnim = container->property("enabled").toBool();
            qreal animW = container->property("width").toReal();
            qreal animH = container->property("height").toReal();
            qDebug() << "[Test] Expanding State - animating:" << animating
                     << "layerActive (must be false in Zero-FBO):" << layerActiveDuringAnim
                     << "containerEnabled (must be false):" << containerEnabledDuringAnim
                     << "geometry:" << animW << "x" << animH;

            // 3. Wait for 380ms animation to finish (700ms margin), then test fully expanded culling and auto-collapsed rail
            QTimer::singleShot(700, [&app, mainWindow, container, stack, np, navRail, initW, initH, autoCollapseConfig, containerEnabledDuringAnim, layerActiveDuringAnim]() {
                bool passTimer = true;
                if (containerEnabledDuringAnim || layerActiveDuringAnim) passTimer = false;

                bool expanded = np->property("isFullyExpanded").toBool();
                bool isOpen = np->property("isOpen").toBool();
                bool isAnim = np->property("isAnimating").toBool();
                qreal currentY = np->property("y").toReal();
                qreal currentH = np->property("height").toReal();
                bool containerVisible = container->property("visible").toBool();
                bool isLayerActive = container->property("isLayerEnabled").isValid() && container->property("isLayerEnabled").toBool();
                bool railCollapsed = navRail->property("collapsed").toBool();
                qreal expW = container->property("width").toReal();
                qreal expH = container->property("height").toReal();
                qreal expectedExpW = autoCollapseConfig ? (initW + 148.0) : initW;
                qDebug() << "[Test] Fully Expanded State - isFullyExpanded:" << expanded
                         << "isOpen:" << isOpen << "isAnimating:" << isAnim
                         << "y:" << currentY << "height:" << currentH
                         << "containerVisible (should be false):" << containerVisible
                         << "isLayerActive (should be false):" << isLayerActive
                         << "railCollapsed (should match config):" << railCollapsed
                         << "geometry:" << expW << "x" << expH << "expected width:" << expectedExpW;

                if (!expanded || containerVisible || isLayerActive || expW != expectedExpW || expH != initH) {
                    passTimer = false;
                }
                if (autoCollapseConfig && !railCollapsed) {
                    qWarning() << "[Test] Navigation rail did not auto-collapse!";
                    passTimer = false;
                }

                // 4. Start collapsing: in frame 0, container must immediately become visible
                mainWindow->setProperty("isNowPlayingOpen", false);
                bool closingExpanded = np->property("isFullyExpanded").toBool();
                bool closingVisible = container->property("visible").toBool();
                bool closingLayer = container->property("isLayerEnabled").isValid() && container->property("isLayerEnabled").toBool();
                qreal closingW = container->property("width").toReal();
                qreal closingH = container->property("height").toReal();
                qDebug() << "[Test] Start Collapsing Frame 0 - isFullyExpanded:" << closingExpanded
                         << "containerVisible (must be true):" << closingVisible
                         << "closingLayer (Zero-FBO must be false):" << closingLayer
                         << "geometry:" << closingW << "x" << closingH;
                if (closingExpanded || !closingVisible || closingLayer || closingH != initH) {
                    passTimer = false;
                }

                // 5. Wait for collapse animation to finish, verify restored to interactive and rail restored
                QTimer::singleShot(700, [&app, container, np, navRail, initW, initH, passTimer]() {
                    bool finalPass = passTimer;
                    bool finalCollapsed = np->property("isFullyCollapsed").toBool();
                    bool finalVisible = container->property("visible").toBool();
                    bool finalEnabled = container->property("enabled").toBool();
                    bool finalLayer = container->property("isLayerEnabled").isValid() && container->property("isLayerEnabled").toBool();
                    bool railCollapsed = navRail->property("collapsed").toBool();
                    qreal finalW = container->property("width").toReal();
                    qreal finalH = container->property("height").toReal();
                    qDebug() << "[Test] Fully Collapsed State - isFullyCollapsed:" << finalCollapsed
                             << "containerVisible:" << finalVisible << "containerEnabled:" << finalEnabled
                             << "isLayerActive (must be false):" << finalLayer
                             << "railCollapsed (must be restored to false):" << railCollapsed
                             << "geometry:" << finalW << "x" << finalH;
                    if (!finalCollapsed || !finalVisible || !finalEnabled || finalLayer || finalW != initW || finalH != initH) {
                        finalPass = false;
                    }
                    if (railCollapsed) {
                        qWarning() << "[Test] Navigation rail did not restore to expanded!";
                        finalPass = false;
                    }

                    qDebug() << "=== Occlusion Culling, Motion & Rail Linkage Test Result:" << (finalPass ? "PASSED" : "FAILED") << "===";
                    QCoreApplication::exit(finalPass ? 0 : 1);
                });
            });
        });
    }

    if (app.arguments().contains("--test-phase6")) {
        qInfo() << "=== Testing Phase 6.3: Strict Header Alignment & Cleanse ===";
        bool pass = true;

        if (mainWindow) {
            mainWindow->setProperty("currentTab", "search");
        }
        QCoreApplication::processEvents();

        QObject *searchView = mainWindow ? mainWindow->findChild<QObject*>("searchView") : nullptr;
        QObject *searchField = searchView ? searchView->findChild<QObject*>("searchField") : nullptr;
        QObject *searchFlickable = searchView ? searchView->findChild<QObject*>("searchFlickable") : nullptr;
        QObject *searchHeaderCol = searchView ? searchView->findChild<QObject*>("searchHeaderCol") : nullptr;
        QObject *heroBrandArea = searchView ? searchView->findChild<QObject*>("heroBrandArea") : nullptr;

        qInfo() << "[Test] searchView found:" << (searchView != nullptr)
                << "searchField found:" << (searchField != nullptr)
                << "searchFlickable found:" << (searchFlickable != nullptr)
                << "searchHeaderCol found:" << (searchHeaderCol != nullptr)
                << "heroBrandArea absent (must be true):" << (heroBrandArea == nullptr);

        if (!searchView || !searchField || !searchFlickable || !searchHeaderCol || heroBrandArea != nullptr) {
            pass = false;
        } else {
            // 1. Verify SearchView Header Position (x: 32, y: 64)
            qreal sHeaderX = searchHeaderCol->property("x").toReal();
            qreal sHeaderY = searchHeaderCol->property("y").toReal();
            qInfo() << "[Test] SearchView Header - x:" << sHeaderX << "y:" << sHeaderY;
            if (sHeaderX != 32.0 || sHeaderY != 64.0) {
                qWarning() << "[Test] SearchView Header must be at x=32, y=64!";
                pass = false;
            }

            // 2. Verify Search Bar positions
            bool initialHasQuery = searchView->property("hasQuery").toBool();
            qreal topAnchorY = searchView->property("topAnchorY").toReal();
            qreal centerAnchorY = searchView->property("centerAnchorY").toReal();
            qInfo() << "[Test] Empty State - hasQuery (must be false):" << initialHasQuery
                    << "topAnchorY:" << topAnchorY
                    << "centerAnchorY:" << centerAnchorY;

            if (initialHasQuery) pass = false;
            if (topAnchorY != 144.0 || centerAnchorY <= topAnchorY) {
                qWarning() << "[Test] topAnchorY should be 144 and centerAnchorY > topAnchorY!";
                pass = false;
            }

            // 3. Type search text -> hasQuery becomes true
            searchField->setProperty("text", "TestSong");
            QCoreApplication::processEvents();

            bool activeHasQuery = searchView->property("hasQuery").toBool();
            qInfo() << "[Test] Active State - hasQuery (must be true):" << activeHasQuery;
            if (!activeHasQuery) pass = false;

            // 4. Clear text -> hasQuery becomes false, contentY resets
            searchField->setProperty("text", "");
            QCoreApplication::processEvents();

            bool clearedHasQuery = searchView->property("hasQuery").toBool();
            qreal flickY = searchFlickable->property("contentY").toReal();
            qInfo() << "[Test] Cleared State - hasQuery (must be false):" << clearedHasQuery
                    << "searchFlickable contentY:" << flickY;
            if (clearedHasQuery || flickY != 0.0) pass = false;
        }

        // 5. Verify SettingsView Header Position (x: 32, y: 64) and no redundant back button
        if (mainWindow) {
            mainWindow->setProperty("currentTab", "settings");
        }
        QCoreApplication::processEvents();
        QObject *settingsView = mainWindow ? mainWindow->findChild<QObject*>("settingsView") : nullptr;
        QObject *settingsMainCol = settingsView ? settingsView->findChild<QObject*>("settingsMainCol") : nullptr;
        qInfo() << "[Test] settingsView found:" << (settingsView != nullptr)
                << "settingsMainCol found:" << (settingsMainCol != nullptr);
        if (!settingsView || !settingsMainCol) {
            pass = false;
        } else {
            qreal setHeaderX = settingsMainCol->property("x").toReal();
            qreal setHeaderY = settingsMainCol->property("y").toReal();
            qInfo() << "[Test] SettingsView Header - x:" << setHeaderX << "y:" << setHeaderY;
            if (setHeaderX != 32.0 || setHeaderY != 64.0) {
                qWarning() << "[Test] SettingsView Header must be at x=32, y=64!";
                pass = false;
            }

            qreal setWidth = settingsMainCol->property("width").toReal();
            qInfo() << "[Test] SettingsView mainCol width:" << setWidth;
            // When window width is 980, available width is 980, with 32px margins width is 916px (previously clamped to 800)
            if (setWidth <= 800.0 && mainWindow && mainWindow->property("width").toReal() >= 960.0) {
                qWarning() << "[Test] SettingsView width should not be clamped to 800px!";
                pass = false;
            }

            bool hasBackButton = false;
            const auto children = settingsView->findChildren<QQuickItem*>();
            for (auto *c : children) {
                if (c && c->property("text").toString() == "<") {
                    hasBackButton = true;
                    break;
                }
            }
            qInfo() << "[Test] settingsView has redundant back button:" << hasBackButton;
            if (hasBackButton) pass = false;

            // Verify SettingsView uses M3ScrollBar matching NowPlaying capsule spec (width: 10, thumb width: 4, rightMargin: 6, radius: 2)
            auto setScrollBars = settingsView->findChildren<QQuickItem*>("m3ScrollBar");
            qInfo() << "[Test] settingsView M3ScrollBar found:" << (!setScrollBars.isEmpty());
            if (setScrollBars.isEmpty()) pass = false;
            else {
                QQuickItem *sb = setScrollBars.first();
                qreal barW = sb->property("width").toReal();
                qreal rMargin = QQmlProperty(sb, "anchors.rightMargin").read().toReal();
                QQuickItem *ci = sb->property("contentItem").value<QQuickItem*>();
                auto mapped = sb->mapToItem(nullptr, QPointF(0, 0));
                qreal ciW = ci ? ci->property("width").toReal() : -1.0;
                qreal ciR = ci ? ci->property("radius").toReal() : -1.0;
                qInfo() << "[Test] settingsView M3ScrollBar width:" << barW
                        << "anchors.rightMargin (must be 6):" << rMargin
                        << "thumb width (must be 4):" << ciW
                        << "thumb radius (must be 2):" << ciR
                        << "mapped:" << mapped;
                if (rMargin != 6.0) {
                    qWarning() << "[Test] anchors.rightMargin must be 6.0, got:" << rMargin;
                    pass = false;
                }
                if (barW != 10.0 || ciW != 4.0 || ciR != 2.0) {
                    qWarning() << "[Test] M3ScrollBar width/thumb specs mismatch";
                    pass = false;
                }
            }
        }

        // 6. Verify LibraryView Header Position (y: 64, leftMargin: 32) & M3ScrollBar
        if (mainWindow) {
            mainWindow->setProperty("currentTab", "library");
        }
        QCoreApplication::processEvents();
        QObject *libView = mainWindow ? mainWindow->findChild<QObject*>("libraryView") : nullptr;
        QObject *libMask = libView ? libView->findChild<QObject*>("libraryTitleBarMask") : nullptr;
        QObject *libCol = libView ? libView->findChild<QObject*>("libraryMainContentCol") : nullptr;
        qInfo() << "[Test] libraryView found:" << (libView != nullptr)
                << "libMask found:" << (libMask != nullptr)
                << "libCol found:" << (libCol != nullptr);
        if (!libView || !libMask || !libCol) {
            pass = false;
        } else {
            qreal maskH = libMask->property("height").toReal();
            qreal colY = libCol->property("y").toReal();
            qInfo() << "[Test] libMask height:" << maskH << "libCol y position:" << colY;
            if (maskH != 48.0 || colY != 64.0) {
                qWarning() << "[Test] Library header position should be at y=64!";
                pass = false;
            }

            auto libScrollBars = libView->findChildren<QQuickItem*>("m3ScrollBar");
            qInfo() << "[Test] libraryView M3ScrollBar instances found:" << libScrollBars.size();
            if (libScrollBars.isEmpty()) pass = false;
            else {
                qreal rMargin = QQmlProperty(libScrollBars.first(), "anchors.rightMargin").read().toReal();
                qInfo() << "[Test] libraryView M3ScrollBar anchors.rightMargin:" << rMargin;
                if (rMargin != 6.0) pass = false;
            }
        }

        // 7. Verify SearchView M3ScrollBar
        if (searchView) {
            auto searchScrollBars = searchView->findChildren<QQuickItem*>("m3ScrollBar");
            qInfo() << "[Test] searchView M3ScrollBar instances found:" << searchScrollBars.size();
            if (searchScrollBars.isEmpty()) pass = false;
            else {
                qreal rMargin = QQmlProperty(searchScrollBars.first(), "anchors.rightMargin").read().toReal();
                qInfo() << "[Test] searchView M3ScrollBar anchors.rightMargin:" << rMargin;
                if (rMargin != 6.0) pass = false;
            }
        }

        // 8. Verify HomeView is mounted and healthy
        if (mainWindow) {
            mainWindow->setProperty("currentTab", "home");
        }
        QCoreApplication::processEvents();
        QObject *homeView = mainWindow ? mainWindow->findChild<QObject*>("homeView") : nullptr;
        qInfo() << "[Test] homeView found:" << (homeView != nullptr);
        if (!homeView) pass = false;
        else {
            auto homeScrollBars = homeView->findChildren<QQuickItem*>("m3ScrollBar");
            qInfo() << "[Test] homeView M3ScrollBar found:" << (!homeScrollBars.isEmpty());
            if (homeScrollBars.isEmpty()) pass = false;
            else {
                qreal rMargin = QQmlProperty(homeScrollBars.first(), "anchors.rightMargin").read().toReal();
                qInfo() << "[Test] homeView M3ScrollBar anchors.rightMargin:" << rMargin;
                if (rMargin != 6.0) pass = false;
            }
        }

        // 9. Verify NowPlaying Lyrics Hitbox Strict Bounding
        if (mainWindow) {
            AudioEngine::instance()->lyrics()->loadLrcContent("[00:01.00]Yeah\n[00:04.00]Testing Strict Lyric Hitbox\n");
            AudioEngine::instance()->lyrics()->updatePosition(1500);
            mainWindow->setProperty("isNowPlayingOpen", true);

            // Allow animation and layout passes to settle and trigger render/polish
            for (int i = 0; i < 15; ++i) {
                QCoreApplication::processEvents();
                QThread::msleep(25);
            }
            mainWindow->grabWindow();
            QCoreApplication::processEvents();

            QQuickItem *npView = mainWindow->findChild<QQuickItem*>("nowPlayingView");
            QQuickItem *lv = mainWindow->findChild<QQuickItem*>("lyricsListView");
            qInfo() << "[Test] nowPlayingView found:" << (npView != nullptr)
                    << "lyricsListView found:" << (lv != nullptr);
            if (lv) {
                QQuickItem *ci = lv->property("contentItem").value<QQuickItem*>();
                qInfo() << "[Test] lyricsListView count:" << lv->property("count").toInt()
                        << "height:" << lv->height()
                        << "visible:" << lv->isVisible()
                        << "contentItem children count:" << (ci ? ci->childItems().size() : -1);
            QQuickItem *lyricDelegate = nullptr;
            QQuickItem *textWrapper = nullptr;
            QQuickItem *mouseArea = nullptr;

            if (ci) {
                for (auto *c : ci->childItems()) {
                    if (c->objectName() == "lyricLineDelegate") {
                        lyricDelegate = c;
                        textWrapper = c->findChild<QQuickItem*>("lyricTextWrapper");
                        mouseArea = c->findChild<QQuickItem*>("lyricMouseArea");
                        break;
                    }
                }
            }

            qInfo() << "[Test] lyricLineDelegate found:" << (lyricDelegate != nullptr)
                    << "lyricTextWrapper found:" << (textWrapper != nullptr)
                    << "lyricMouseArea found:" << (mouseArea != nullptr);

            if (!lyricDelegate || !textWrapper || !mouseArea) {
                qWarning() << "[Test] Lyrics delegate components missing";
                pass = false;
            } else {
                qreal delW = lyricDelegate->width();
                qreal wrapW = textWrapper->width();
                qreal mouseW = mouseArea->width();
                qInfo() << "[Test] delegate width:" << delW
                        << "wrapper width:" << wrapW
                        << "mouseArea width:" << mouseW;

                // MouseArea must be strictly bounded to textWrapper + 16 (8px margins on each side)
                if (qAbs(mouseW - (wrapW + 16.0)) > 2.0) {
                    qWarning() << "[Test] MouseArea width should be wrapper width + 16!";
                    pass = false;
                }
                // For short text, mouseArea must NOT cover the whole delegate line
                if (mouseW >= (delW - 50.0)) {
                    qWarning() << "[Test] MouseArea width is not restricted to text!";
                    pass = false;
                }
            }
            }
            mainWindow->setProperty("isNowPlayingOpen", false);
            QCoreApplication::processEvents();
        }

        qInfo() << "=== Phase 6.6 Integration Test Result:" << (pass ? "PASSED" : "FAILED") << "===";
        QTimer::singleShot(100, &app, [pass]() {
            QCoreApplication::exit(pass ? 0 : 1);
        });
    }

    if (app.arguments().contains("--test-queue") || app.arguments().contains("--test-phase7")) {
        qInfo() << "=== Testing Phase 7: Queue View Parity & Dynamic Operations ===";
        bool pass = true;

        if (mainWindow) {
            mainWindow->setProperty("currentTab", "queue");
        }
        QCoreApplication::processEvents();

        QObject *queueView = mainWindow ? mainWindow->findChild<QObject*>("queueView") : nullptr;
        qInfo() << "[Test] queueView found:" << (queueView != nullptr);
        if (!queueView) {
            pass = false;
        } else {
            // 1. Verify Header Alignment & Baseline Coordinates (y=64, mask height=48)
            QObject *titleMask = queueView->findChild<QObject*>("queueTitleBarMask");
            QObject *mainList = queueView->findChild<QObject*>("queueListView");
            QObject *heroBanner = queueView->findChild<QObject*>("queueHeroBanner");
            QObject *segContainer = queueView->findChild<QObject*>("queueSegmentedContainer");
            qInfo() << "[Test] queueTitleBarMask found:" << (titleMask != nullptr)
                    << "queueListView found:" << (mainList != nullptr)
                    << "queueHeroBanner found:" << (heroBanner != nullptr)
                    << "queueSegmentedContainer found:" << (segContainer != nullptr);
            if (!titleMask || !mainList || !heroBanner || !segContainer) {
                pass = false;
            } else {
                qreal maskH = titleMask->property("height").toReal();
                qreal listY = mainList->property("y").toReal();
                qreal bannerRadius = heroBanner->property("radius").toReal();
                qInfo() << "[Test] titleMask height:" << maskH << "queueListView y:" << listY << "bannerRadius:" << bannerRadius;
                if (maskH != 48.0 || listY != 64.0 || bannerRadius != 20.0) {
                    qWarning() << "[Test] Queue header baseline coordinate or banner radius mismatch! Expected maskH=48, listY=64, radius=20";
                    pass = false;
                }
            }

            // 2. Verify M3ScrollBar on Queue List has 6px safe floating right margin
            auto scrollBars = queueView->findChildren<QQuickItem*>("m3ScrollBar");
            qInfo() << "[Test] QueueView M3ScrollBar instances found:" << scrollBars.size();
            if (scrollBars.isEmpty()) {
                pass = false;
            } else {
                qreal rMargin = QQmlProperty(scrollBars.first(), "anchors.rightMargin").read().toReal();
                qInfo() << "[Test] QueueView M3ScrollBar rightMargin:" << rMargin;
                if (rMargin != 6.0) {
                    qWarning() << "[Test] Expected M3ScrollBar anchors.rightMargin == 6.0, got:" << rMargin;
                    pass = false;
                }
            }

            // 3. Test Empty State
            AudioEngine::instance()->clearQueue(false);
            QCoreApplication::processEvents();
            int emptyTotal = queueView->property("totalQueueCount").toInt();
            int emptyCur = queueView->property("currentListCount").toInt();
            QQuickItem *emptyGuide = queueView->findChild<QQuickItem*>("queueEmptyState");
            QQuickItem *queueList = queueView->findChild<QQuickItem*>("queueListView");
            qInfo() << "[Test] Empty queue totalCount:" << emptyTotal
                    << "currentListCount:" << emptyCur
                    << "emptyGuide found:" << (emptyGuide != nullptr)
                    << "emptyGuide visible:" << (emptyGuide ? emptyGuide->isVisible() : false);
            if (emptyTotal != 0 || emptyCur != 0 || !emptyGuide || !emptyGuide->isVisible()) {
                qWarning() << "[Test] Queue empty state verification failed!";
                pass = false;
            }

            // 4. Test Populated State & Dynamic Progression across playNext()
            TrackItem t1;
            t1.path = "C:/Music/test_queue_1.flac";
            t1.title = "Queue Track One";
            t1.artist = "Artist A";
            t1.album = "Album Alpha";
            t1.durationMs = 180000;
            t1.format = "FLAC";

            TrackItem t2;
            t2.path = "C:/Music/test_queue_2.mp3";
            t2.title = "Queue Track Two";
            t2.artist = "Artist B";
            t2.album = "Album Beta";
            t2.durationMs = 210000;
            t2.format = "MP3";

            TrackItem t3;
            t3.path = "C:/Music/test_queue_3.wav";
            t3.title = "Queue Track Three";
            t3.artist = "Artist C";
            t3.album = "Album Gamma";
            t3.durationMs = 120000;
            t3.format = "WAV";

            LibraryManager::instance()->setLibraryTracks({t1, t2, t3});
            AudioEngine::instance()->setPlaylist({t1.path, t2.path, t3.path}, 0);
            QCoreApplication::processEvents();

            int populatedTotal = queueView->property("totalQueueCount").toInt();
            int currentIdx = AudioEngine::instance()->currentIndex();
            int playedCount = AudioEngine::instance()->playedModel()->rowCount();
            int nextCount = AudioEngine::instance()->nextModel()->rowCount();
            QString nextFirst0 = nextCount > 0 ? AudioEngine::instance()->nextModel()->tracks().first().title : "";
            qInfo() << "[Test] Initially at index 0: totalCount:" << populatedTotal
                    << "currentIndex:" << currentIdx
                    << "playedModel count:" << playedCount
                    << "nextModel count:" << nextCount
                    << "nextModel first track:" << nextFirst0;

            if (populatedTotal != 3 || currentIdx != 0 || playedCount != 0 || nextCount != 2 ||
                nextFirst0 != "Queue Track Two") {
                qWarning() << "[Test] Initial queue slicing verification failed!";
                pass = false;
            }

            // Step 4b: Trigger playNext() -> Must dynamically transition to Track Two (index 1)
            // PlayedModel becomes [Track One]
            // NextModel becomes [Track Three] (Track Two must NOT remain in NextModel!)
            AudioEngine::instance()->playNext();
            QCoreApplication::processEvents();

            currentIdx = AudioEngine::instance()->currentIndex();
            playedCount = AudioEngine::instance()->playedModel()->rowCount();
            nextCount = AudioEngine::instance()->nextModel()->rowCount();
            QString playedFirst1 = playedCount > 0 ? AudioEngine::instance()->playedModel()->tracks().first().title : "";
            QString nextFirst1 = nextCount > 0 ? AudioEngine::instance()->nextModel()->tracks().first().title : "";
            qInfo() << "[Test] After playNext(): currentIndex:" << currentIdx
                    << "playedModel count:" << playedCount << "playedFirst:" << playedFirst1
                    << "nextModel count:" << nextCount << "nextFirst:" << nextFirst1;

            if (currentIdx != 1 || playedCount != 1 || nextCount != 1 ||
                playedFirst1 != "Queue Track One" || nextFirst1 != "Queue Track Three") {
                qWarning() << "[Test] Dynamic queue progression on playNext() failed! nextFirst must be Track Three, got:" << nextFirst1;
                pass = false;
            }

            // Test Segmented Filter Toggle
            queueView->setProperty("subTab", "played");
            QCoreApplication::processEvents();
            int playedListCount = queueView->property("currentListCount").toInt();
            qInfo() << "[Test] subTab 'played' currentListCount:" << playedListCount;
            if (playedListCount != 1) {
                qWarning() << "[Test] Played tab currentListCount should be 1!";
                pass = false;
            }

            queueView->setProperty("subTab", "nexts");
            QCoreApplication::processEvents();
            int nextListCount = queueView->property("currentListCount").toInt();
            qInfo() << "[Test] subTab 'nexts' currentListCount:" << nextListCount;
            if (nextListCount != 1) {
                qWarning() << "[Test] Nexts tab currentListCount should be 1!";
                pass = false;
            }

            // 5. Test Physical clearQueue(true) - keeping only current track
            AudioEngine::instance()->clearQueue(true);
            QCoreApplication::processEvents();

            int clearedTotal = queueView->property("totalQueueCount").toInt();
            int clearedPlayed = AudioEngine::instance()->playedModel()->rowCount();
            int clearedNext = AudioEngine::instance()->nextModel()->rowCount();
            qInfo() << "[Test] After clearQueue(true) - totalCount:" << clearedTotal
                    << "playedCount:" << clearedPlayed
                    << "nextCount:" << clearedNext
                    << "currentTrack:" << AudioEngine::instance()->currentTrack();

            if (clearedTotal != 1 || clearedPlayed != 0 || clearedNext != 0) {
                qWarning() << "[Test] clearQueue(true) failed! Expected totalCount=1, played=0, next=0";
                pass = false;
            }

            // Verify playNext() on single-track queue does NOT revive previous tracks or whole library
            AudioEngine::instance()->playNext();
            QCoreApplication::processEvents();
            int afterNextTotal = queueView->property("totalQueueCount").toInt();
            qInfo() << "[Test] After playNext on single-track queue - totalCount:" << afterNextTotal;
            if (afterNextTotal != 1) {
                qWarning() << "[Test] playNext revived old tracks or library! totalCount became:" << afterNextTotal;
                pass = false;
            }

            // 6. Test Full clearQueue(false)
            AudioEngine::instance()->clearQueue(false);
            QCoreApplication::processEvents();
            int fullyClearedTotal = queueView->property("totalQueueCount").toInt();
            qInfo() << "[Test] After clearQueue(false) - totalCount:" << fullyClearedTotal
                    << "emptyGuide visible:" << emptyGuide->isVisible();
            if (fullyClearedTotal != 0 || !emptyGuide->isVisible()) {
                qWarning() << "[Test] clearQueue(false) full clear failed!";
                pass = false;
            }

            // 9. Test Translations
            updateAppTranslation("zh");
            QString zhQueue = QCoreApplication::translate("QueueView", "Playback Queue");
            QString zhEmpty = QCoreApplication::translate("QueueView", "Queue is empty");
            QString zhNoPlayed = QCoreApplication::translate("QueueView", "No played tracks");
            QString zhPlayed = QCoreApplication::translate("QueueView", "Played");
            QString zhNexts = QCoreApplication::translate("QueueView", "Nexts");
            qInfo() << "[Test] Chinese - Queue:" << zhQueue << "Empty:" << zhEmpty << "NoPlayed:" << zhNoPlayed
                    << "Played:" << zhPlayed << "Nexts:" << zhNexts;
            if (zhQueue != QString::fromUtf8("播放队列") ||
                zhEmpty != QString::fromUtf8("队列中暂无曲目") ||
                zhNoPlayed != QString::fromUtf8("暂无已播放曲目") ||
                zhPlayed != QString::fromUtf8("已播放") ||
                zhNexts != QString::fromUtf8("即将播放")) {
                qWarning() << "[Test] Chinese QueueView translation mismatch!";
                pass = false;
            }

            updateAppTranslation("ja");
            QString jaQueue = QCoreApplication::translate("QueueView", "Playback Queue");
            QString jaEmpty = QCoreApplication::translate("QueueView", "Queue is empty");
            QString jaNoPlayed = QCoreApplication::translate("QueueView", "No played tracks");
            QString jaPlayed = QCoreApplication::translate("QueueView", "Played");
            QString jaNexts = QCoreApplication::translate("QueueView", "Nexts");
            qInfo() << "[Test] Japanese - Queue:" << jaQueue << "Empty:" << jaEmpty << "NoPlayed:" << jaNoPlayed
                    << "Played:" << jaPlayed << "Nexts:" << jaNexts;
            if (jaQueue != QString::fromUtf8("再生キュー") ||
                jaEmpty != QString::fromUtf8("キューは空です") ||
                jaNoPlayed != QString::fromUtf8("再生履歴はありません") ||
                jaPlayed != QString::fromUtf8("再生済み") ||
                jaNexts != QString::fromUtf8("次再生")) {
                qWarning() << "[Test] Japanese QueueView translation mismatch!";
                pass = false;
            }

            updateAppTranslation(ConfigManager::instance()->language());
        }

        qInfo() << "=== Phase 7 Queue Integration Test Result:" << (pass ? "PASSED" : "FAILED") << "===";
        QTimer::singleShot(100, &app, [pass]() {
            QCoreApplication::exit(pass ? 0 : 1);
        });
    }

    if (app.arguments().contains("--test-phase8") || app.arguments().contains("--test-playlist") || app.arguments().contains("--test-eq")) {
        qInfo() << "=== Testing Phase 8: SearchView i18n, PlaylistsView & EqualizerView Parity ===";
        bool pass = true;

        if (mainWindow) {
            // 1. Verify SearchView i18n translations
            updateAppTranslation("zh");
            QString zhSearchSub = QCoreApplication::translate("SearchView", "Search tracks, artists, and albums");
            qInfo() << "[Test] Chinese SearchView subtitle:" << zhSearchSub;
            if (zhSearchSub != QString::fromUtf8("搜索歌曲、歌手或专辑")) {
                qWarning() << "[Test] Chinese SearchView subtitle translation mismatch!" << zhSearchSub;
                pass = false;
            }

            updateAppTranslation("ja");
            QString jaSearchSub = QCoreApplication::translate("SearchView", "Search tracks, artists, and albums");
            qInfo() << "[Test] Japanese SearchView subtitle:" << jaSearchSub;
            if (jaSearchSub != QString::fromUtf8("トラック、アーティスト、アルバムを検索")) {
                qWarning() << "[Test] Japanese SearchView subtitle translation mismatch!" << jaSearchSub;
                pass = false;
            }
            updateAppTranslation(ConfigManager::instance()->language());

            // 2. Verify PlaylistsView mounting and features
            mainWindow->setProperty("currentTab", "playlist");
            QCoreApplication::processEvents();

            QObject *plView = mainWindow->findChild<QObject*>("playlistsView");
            qInfo() << "[Test] playlistsView object found:" << (plView != nullptr);
            if (!plView) {
                qWarning() << "[Test] playlistsView QML component missing!";
                pass = false;
            }

            auto *libMgr = LibraryManager::instance();

            // Test Favorites
            int initialFavs = libMgr->favoriteCount();
            QString testTrack = "C:/rhx_test_track_favorites.flac";
            libMgr->toggleFavorite(testTrack);
            if (!libMgr->isFavorite(testTrack) || libMgr->favoriteCount() != initialFavs + 1) {
                qWarning() << "[Test] toggleFavorite add failed!";
                pass = false;
            }

            libMgr->selectPlaylist("__favorites__");
            if (!libMgr->currentPlaylistIsFavorites()) {
                qWarning() << "[Test] currentPlaylistIsFavorites failed!";
                pass = false;
            }

            libMgr->toggleFavorite(testTrack);
            if (libMgr->isFavorite(testTrack) || libMgr->favoriteCount() != initialFavs) {
                qWarning() << "[Test] toggleFavorite remove failed!";
                pass = false;
            }

            // Test Custom Playlist lifecycle (create, rename, add track, remove track, delete)
            int initialPlCount = libMgr->playlistCount();
            libMgr->createPlaylist("Rock Classics 1980s");
            int afterCreateCount = libMgr->playlistCount();
            if (afterCreateCount != initialPlCount + 1) {
                qWarning() << "[Test] createPlaylist failed! count:" << afterCreateCount;
                pass = false;
            }

            // Find created playlist ID
            QString createdId;
            const auto &pls = libMgr->playlistsModel()->playlists();
            for (const auto &p : pls) {
                if (p.name == "Rock Classics 1980s") {
                    createdId = p.id;
                    break;
                }
            }

            if (createdId.isEmpty()) {
                qWarning() << "[Test] Could not find created playlist!";
                pass = false;
            } else {
                // Rename
                libMgr->renamePlaylist(createdId, "Hard Rock Anthems");
                PlaylistItem renamedItem = libMgr->playlistsModel()->findPlaylist(createdId);
                if (renamedItem.name != "Hard Rock Anthems") {
                    qWarning() << "[Test] renamePlaylist failed! Name:" << renamedItem.name;
                    pass = false;
                }

                // Add track
                QString sampleSong = "C:/rhx_sample_song.flac";
                libMgr->addTrackToPlaylist(createdId, sampleSong);
                libMgr->selectPlaylist(createdId);
                if (libMgr->currentPlaylistName() != "Hard Rock Anthems") {
                    qWarning() << "[Test] selectPlaylist failed! Current name:" << libMgr->currentPlaylistName();
                    pass = false;
                }
                if (libMgr->playlistTracksModel()->count() != 1) {
                    qWarning() << "[Test] addTrackToPlaylist failed! Track count:" << libMgr->playlistTracksModel()->count();
                    pass = false;
                }

                // Remove track
                libMgr->removeTrackFromPlaylist(createdId, sampleSong);
                if (libMgr->playlistTracksModel()->count() != 0) {
                    qWarning() << "[Test] removeTrackFromPlaylist failed! Track count:" << libMgr->playlistTracksModel()->count();
                    pass = false;
                }

                // Delete playlist
                libMgr->deletePlaylist(createdId);
                if (libMgr->playlistCount() != initialPlCount) {
                    qWarning() << "[Test] deletePlaylist failed! Count:" << libMgr->playlistCount();
                    pass = false;
                }
            }

            // 3. Verify EqualizerView mounting and AudioEngine EQ
            mainWindow->setProperty("currentTab", "eq");
            QCoreApplication::processEvents();

            QObject *eqView = mainWindow->findChild<QObject*>("equalizerView");
            qInfo() << "[Test] equalizerView object found:" << (eqView != nullptr);
            if (!eqView) {
                qWarning() << "[Test] equalizerView QML component missing!";
                pass = false;
            }

            auto *audioEng = AudioEngine::instance();

            // Test EQ Enabled
            audioEng->setEqEnabled(true);
            if (!audioEng->eqEnabled()) {
                qWarning() << "[Test] setEqEnabled(true) failed!";
                pass = false;
            }

            // Test Preamp
            audioEng->setEqPreamp(4.5f);
            if (std::abs(audioEng->eqPreamp() - 4.5f) > 0.05f) {
                qWarning() << "[Test] setEqPreamp(4.5) failed! Value:" << audioEng->eqPreamp();
                pass = false;
            }

            // Test Preset Apply (Rock)
            audioEng->applyEqPreset("Rock");
            if (audioEng->eqPreset() != "Rock") {
                qWarning() << "[Test] applyEqPreset(Rock) failed! Preset:" << audioEng->eqPreset();
                pass = false;
            }
            if (audioEng->eqBands().size() != 10 || std::abs(audioEng->eqBands()[0] - 4.5f) > 0.05f || std::abs(audioEng->eqBands()[9] - 4.0f) > 0.05f) {
                qWarning() << "[Test] Rock preset bands mismatch! 31Hz:" << audioEng->eqBands()[0] << "16kHz:" << audioEng->eqBands()[9];
                pass = false;
            }

            // Test Custom Band Modification
            audioEng->setEqBand(0, -6.0f);
            if (audioEng->eqPreset() != "Custom") {
                qWarning() << "[Test] Modifying band did not switch to Custom preset! Got:" << audioEng->eqPreset();
                pass = false;
            }
            if (std::abs(audioEng->eqBands()[0] - (-6.0f)) > 0.05f) {
                qWarning() << "[Test] setEqBand failed! Band 0:" << audioEng->eqBands()[0];
                pass = false;
            }

            // Test Reset (Phase 9 requirement: Reset only zeroes 10 bands without turning off EQ)
            audioEng->setEqEnabled(true);
            audioEng->resetEq();
            if (!audioEng->eqEnabled()) {
                qWarning() << "[Test] resetEq should NOT disable EQ!";
                pass = false;
            }
            if (std::abs(audioEng->eqPreamp()) > 0.05f) {
                qWarning() << "[Test] resetEq did not reset preamp!";
                pass = false;
            }
            if (audioEng->eqPreset() != "Flat") {
                qWarning() << "[Test] resetEq did not set preset to Flat! Got:" << audioEng->eqPreset();
                pass = false;
            }
            for (int b = 0; b < 10; ++b) {
                if (std::abs(audioEng->eqBands()[b]) > 0.05f) {
                    qWarning() << "[Test] resetEq band" << b << "not zero:" << audioEng->eqBands()[b];
                    pass = false;
                }
            }

            // 4. Test PlaylistsView and EqualizerView i18n
            updateAppTranslation("zh");
            QString zhPlTitle = QCoreApplication::translate("PlaylistsView", "Create Playlist");
            QString zhEqTitle = QCoreApplication::translate("EqualizerView", "Equalizer");
            qInfo() << "[Test] Chinese - PlTitle:" << zhPlTitle << "EqTitle:" << zhEqTitle;
            if (zhPlTitle != QString::fromUtf8("新建歌单") || zhEqTitle != QString::fromUtf8("均衡器")) {
                qWarning() << "[Test] Chinese Playlists/EQ translations mismatch!";
                pass = false;
            }

            updateAppTranslation("ja");
            QString jaPlTitle = QCoreApplication::translate("PlaylistsView", "Create Playlist");
            QString jaEqTitle = QCoreApplication::translate("EqualizerView", "Equalizer");
            qInfo() << "[Test] Japanese - PlTitle:" << jaPlTitle << "EqTitle:" << jaEqTitle;
            if (jaPlTitle != QString::fromUtf8("プレイリストを作成") || jaEqTitle != QString::fromUtf8("イコライザー")) {
                qWarning() << "[Test] Japanese Playlists/EQ translations mismatch!";
                pass = false;
            }
            updateAppTranslation(ConfigManager::instance()->language());
        }

        qInfo() << "=== Phase 8 Playlists & Equalizer Parity Test Result:" << (pass ? "PASSED" : "FAILED") << "===";
        QTimer::singleShot(100, &app, [pass]() {
            QCoreApplication::exit(pass ? 0 : 1);
        });
    }

    if (app.arguments().contains("--test-phase9")) {
        qInfo() << "=== Testing Phase 9: Desktop Core, Native Integration, Multi-Selection & EQ Concurrency ===";
        bool pass = true;

        auto *audioEng = AudioEngine::instance();
        auto *libMgr = LibraryManager::instance();

        // 1. Verify EQ Reset State Machine (bands reset to Flat, eqEnabled remains true)
        audioEng->setEqEnabled(true);
        audioEng->setEqBand(2, 6.0f);
        audioEng->setEqPreamp(3.0f);
        audioEng->resetEq();
        if (!audioEng->eqEnabled()) {
            qWarning() << "[Test-Phase9] EQ was unexpectedly disabled after resetEq()!";
            pass = false;
        }
        if (audioEng->eqPreset() != "Flat" || std::abs(audioEng->eqPreamp()) > 0.01f || std::abs(audioEng->eqBands()[2]) > 0.01f) {
            qWarning() << "[Test-Phase9] EQ gains were not zeroed after resetEq()!";
            pass = false;
        }

        // 2. High-Frequency EQ Concurrency Guard (Test rapid parameter changes without crash)
        for (int step = 0; step < 50; ++step) {
            float val = (step % 2 == 0) ? 6.0f : -6.0f;
            audioEng->setEqBand(step % 10, val);
            audioEng->setEqPreamp(val * 0.5f);
        }
        audioEng->resetEq();
        qInfo() << "[Test-Phase9] High-frequency EQ adjustment completed cleanly without deadlock.";

        // 3. AudioEngine insertTracksNext
        QStringList queueInsertTest = { "C:/rhx_test_track_1.mp3", "C:/rhx_test_track_2.mp3" };
        audioEng->insertTracksNext(queueInsertTest);
        qInfo() << "[Test-Phase9] insertTracksNext executed without errors.";

        // 4. LibraryManager Desktop Batch Methods
        // Batch Favorites
        QStringList favBatch = { "C:/fav_track_a.flac", "C:/fav_track_b.flac" };
        libMgr->toggleFavorites(favBatch);
        if (!libMgr->isFavorite("C:/fav_track_a.flac") || !libMgr->isFavorite("C:/fav_track_b.flac")) {
            qWarning() << "[Test-Phase9] Batch toggleFavorites add failed!";
            pass = false;
        }
        libMgr->toggleFavorites(favBatch); // toggle back
        if (libMgr->isFavorite("C:/fav_track_a.flac") || libMgr->isFavorite("C:/fav_track_b.flac")) {
            qWarning() << "[Test-Phase9] Batch toggleFavorites remove failed!";
            pass = false;
        }

        // Batch Add to Playlist & Batch Remove from Playlist (Phase 9.1)
        libMgr->createPlaylist("Phase 9 Batch Playlist");
        QString batchPlId;
        for (const auto &p : libMgr->playlistsModel()->playlists()) {
            if (p.name == "Phase 9 Batch Playlist") {
                batchPlId = p.id;
                break;
            }
        }
        if (batchPlId.isEmpty()) {
            qWarning() << "[Test-Phase9] Failed to create Phase 9 Batch Playlist!";
            pass = false;
        } else {
            libMgr->addTracksToPlaylist(batchPlId, { "C:/test_pl_1.mp3", "C:/test_pl_2.mp3" });
            libMgr->selectPlaylist(batchPlId);
            if (libMgr->playlistTracksModel()->count() < 2) {
                qWarning() << "[Test-Phase9] addTracksToPlaylist batch failed! count:" << libMgr->playlistTracksModel()->count();
                pass = false;
            }

            // Test Phase 9.1: Playlist Sorting
            libMgr->sortPlaylistTracks("title_asc");
            qInfo() << "[Test-Phase9] sortPlaylistTracks executed successfully.";

            // Test Phase 9.1: Batch Remove from Playlist
            libMgr->removeTracksFromPlaylist(batchPlId, { "C:/test_pl_1.mp3", "C:/test_pl_2.mp3" });
            libMgr->selectPlaylist(batchPlId);
            if (libMgr->playlistTracksModel()->count() != 0) {
                qWarning() << "[Test-Phase9] removeTracksFromPlaylist batch failed! count:" << libMgr->playlistTracksModel()->count();
                pass = false;
            } else {
                qInfo() << "[Test-Phase9] removeTracksFromPlaylist verified: 0 tracks remain.";
            }

            libMgr->deletePlaylist(batchPlId);
        }

        // Test Phase 9.1: Brand Vector Icon Validity
        QSvgRenderer brandSvg(QStringLiteral(":/assets/icons/app_icon.svg"));
        if (!brandSvg.isValid()) {
            qWarning() << "[Test-Phase9] app_icon.svg failed to load into QSvgRenderer!";
            pass = false;
        } else {
            qInfo() << "[Test-Phase9] app_icon.svg loaded successfully. Default size:" << brandSvg.defaultSize();
        }

        // TrackModel Range Selection API
        TrackModel testModel;
        TrackItem ti1; ti1.path = "track_1.mp3";
        TrackItem ti2; ti2.path = "track_2.mp3";
        TrackItem ti3; ti3.path = "track_3.mp3";
        testModel.addTrack(ti1);
        testModel.addTrack(ti2);
        testModel.addTrack(ti3);
        QStringList range = testModel.getPathsInRange(0, 2);
        if (range.size() != 3 || range[0] != "track_1.mp3" || range[2] != "track_3.mp3") {
            qWarning() << "[Test-Phase9] TrackModel getPathsInRange failed!" << range;
            pass = false;
        }
        if (testModel.pathAt(1) != "track_2.mp3") {
            qWarning() << "[Test-Phase9] TrackModel pathAt failed!" << testModel.pathAt(1);
            pass = false;
        }

        // Track Details Metadata Map
        QVariantMap details = libMgr->getTrackDetails("C:/rhx_test_track_1.mp3");
        if (!details.contains("title") || !details.contains("durationStr") || !details.contains("fileSizeStr")) {
            qWarning() << "[Test-Phase9] getTrackDetails missing expected fields!" << details;
            pass = false;
        }

        // 5. Verify UI Dialogs and Components in QML Root
        if (mainWindow) {
            QObject *trackDlg = mainWindow->findChild<QObject*>("trackInfoDialog");
            QObject *plDlg = mainWindow->findChild<QObject*>("playlistSelectDialog");
            QObject *ctxMenu = mainWindow->findChild<QObject*>("m3ContextMenu");
            QObject *splash = mainWindow->findChild<QObject*>("splashScreen");

            qInfo() << "[Test-Phase9] trackInfoDialog found:" << (trackDlg != nullptr);
            qInfo() << "[Test-Phase9] playlistSelectDialog found:" << (plDlg != nullptr);
            qInfo() << "[Test-Phase9] m3ContextMenu found:" << (ctxMenu != nullptr);
            qInfo() << "[Test-Phase9] splashScreen found:" << (splash != nullptr);

            if (!trackDlg || !plDlg || !ctxMenu || !splash) {
                qWarning() << "[Test-Phase9] One or more required QML modal/dialog components missing!";
                pass = false;
            }

            // Test Context Menu show & close methods
            if (ctxMenu) {
                QMetaObject::invokeMethod(ctxMenu, "show",
                    Q_ARG(QVariant, 100),
                    Q_ARG(QVariant, 100),
                    Q_ARG(QVariant, QStringList{"C:/rhx_test_track_1.mp3"}),
                    Q_ARG(QVariant, "Test Title"),
                    Q_ARG(QVariant, "Test Artist"),
                    Q_ARG(QVariant, "library"));
                QMetaObject::invokeMethod(ctxMenu, "close");
            }

            // Test Playlist Select Dialog open & close
            if (plDlg) {
                QMetaObject::invokeMethod(plDlg, "openForTracks",
                    Q_ARG(QVariant, QStringList{"C:/rhx_test_track_1.mp3"}));
                QMetaObject::invokeMethod(plDlg, "close");
            }

            // Test Track Info Dialog show & close
            if (trackDlg) {
                QMetaObject::invokeMethod(trackDlg, "showTrack",
                    Q_ARG(QVariant, "C:/rhx_test_track_1.mp3"));
                QMetaObject::invokeMethod(trackDlg, "close");
            }

            // Test Dynamic Seed Color Changing & Automatic QSettings Persistence (No Save button needed)
            ConfigManager::instance()->setSeedColor("#DE3730");
            QSettings testSettings(PathManager::instance()->configFile(), QSettings::IniFormat);
            if (ConfigManager::instance()->seedColor().toUpper() != "#DE3730" ||
                testSettings.value("Appearance/SeedColor").toString().toUpper() != "#DE3730") {
                qWarning() << "[Test-Phase9] Dynamic seed color change or auto-save failed!";
                pass = false;
            }
            ConfigManager::instance()->setSeedColor("#39C5BB"); // restore Miku Teal
            if (testSettings.value("Appearance/SeedColor").toString().toUpper() != "#39C5BB") {
                qWarning() << "[Test-Phase9] Reset seed color auto-save failed!";
                pass = false;
            }
            qInfo() << "[Test-Phase9.7] Live seed color change and immediate QSettings auto-save verified.";

            // Phase 10.1 Automated Assertions: PathManager Directory Topology & Portable Mode Isolation
            auto *pm = PathManager::instance();
            if (pm->configDir().isEmpty() || pm->dataDir().isEmpty() || pm->cacheDir().isEmpty()) {
                qWarning() << "[Test-Phase10.1] Standard directories are empty!";
                pass = false;
            }
            if (!pm->configFile().endsWith("/config.ini")) {
                qWarning() << "[Test-Phase10.1] configFile does not end with config.ini! Actual:" << pm->configFile();
                pass = false;
            }
            if (!pm->libraryCacheFile().endsWith("/library_cache.json")) {
                qWarning() << "[Test-Phase10.1] libraryCacheFile does not end with library_cache.json!";
                pass = false;
            }
            if (!pm->playlistsFile().endsWith("/playlists.json")) {
                qWarning() << "[Test-Phase10.1] playlistsFile does not end with playlists.json!";
                pass = false;
            }
            if (!pm->favoritesFile().endsWith("/favorites.json")) {
                qWarning() << "[Test-Phase10.1] favoritesFile does not end with favorites.json!";
                pass = false;
            }

            // Verify directories exist on disk
            pm->ensureDirsExist();
            if (!QDir(pm->configDir()).exists() || !QDir(pm->dataDir()).exists() || !QDir(pm->cacheDir()).exists()) {
                qWarning() << "[Test-Phase10.1] ensureDirsExist failed to create directories!";
                pass = false;
            }

            // Verify Portable Mode simulation
            bool originalPortable = pm->isPortable();
            QString originalConfigDir = pm->configDir();
            pm->setPortableMode(true);
            if (!pm->isPortable()) {
                qWarning() << "[Test-Phase10.1] Failed to toggle portable mode!";
                pass = false;
            }
            if (!pm->configDir().contains("portable")) {
                qWarning() << "[Test-Phase10.1] Portable configDir does not contain 'portable'!";
                pass = false;
            }
            pm->setPortableMode(originalPortable);
            if (pm->configDir() != originalConfigDir) {
                qWarning() << "[Test-Phase10.1] Failed to restore standard paths!";
                pass = false;
            }

            // Verify Avatar Local Copy & Reset
            {
                QString dummyAvatar = QDir::tempPath() + "/0rhx_dummy_avatar.png";
                QFile dummyFile(dummyAvatar);
                if (dummyFile.open(QIODevice::WriteOnly)) {
                    dummyFile.write("DUMMY_AVATAR_IMAGE");
                    dummyFile.close();
                    ConfigManager::instance()->setAvatar(dummyAvatar);
                    QString setAv = ConfigManager::instance()->avatar();
                    if (setAv.isEmpty() || !setAv.contains("user_avatar")) {
                        qWarning() << "[Test-Phase10.1] setAvatar did not copy avatar to avatarsDir! Current:" << setAv;
                        pass = false;
                    }
                    ConfigManager::instance()->resetAvatar();
                    if (!ConfigManager::instance()->avatar().isEmpty()) {
                        qWarning() << "[Test-Phase10.1] resetAvatar failed to clear avatar!";
                        pass = false;
                    }
                    QFile::remove(dummyAvatar);
                }
            }
            qInfo() << "[Test-Phase10.1] PathManager topology, portable mode isolation & avatar persistence verified.";

            // Phase 9.8 Automated Assertions: Symmetrical Palette Padding & Bottom Inset
            QObject *palPopup = mainWindow->findChild<QObject*>("palettePopup");
            if (!palPopup) {
                qWarning() << "[Test-Phase9.8] palettePopup not found in QML hierarchy!";
                pass = false;
            } else {
                qreal pPad = palPopup->property("padding").toReal();
                qreal pTopPad = palPopup->property("topPadding").toReal();
                qreal pBottomPad = palPopup->property("bottomPadding").toReal();
                qreal pLeftPad = palPopup->property("leftPadding").toReal();
                qreal pRightPad = palPopup->property("rightPadding").toReal();
                qreal pWidth = palPopup->property("width").toReal();
                qInfo() << "[Test-Phase9.8] palettePopup geometry verified - padding:" << pPad
                        << "topPadding:" << pTopPad << "bottomPadding:" << pBottomPad
                        << "leftPadding:" << pLeftPad << "rightPadding:" << pRightPad
                        << "width:" << pWidth;
                if (pPad != 16.0 || pTopPad != 16.0 || pBottomPad != 16.0 ||
                    pLeftPad != 16.0 || pRightPad != 16.0) {
                    qWarning() << "[Test-Phase9.8] palettePopup does not have symmetrical 16px padding!";
                    pass = false;
                }
            }

            // Phase 10 Automated Assertions: Application Version 1.1.0
            if (QCoreApplication::applicationVersion() != "1.1.0") {
                qWarning() << "[Test-Phase10] Application version is not 1.1.0! Current:" << QCoreApplication::applicationVersion();
                pass = false;
            } else {
                qInfo() << "[Test-Phase10] Application version verified:" << QCoreApplication::applicationVersion();
            }

            // Phase 9.4 Automated Assertions:
            // 1. Inline playlist creation with returned ID
            QString inlinePlId = libMgr->createPlaylist("Phase 9.4 Inline Test PL");
            if (inlinePlId.isEmpty()) {
                qWarning() << "[Test-Phase9.4] createPlaylist failed to return valid ID!";
                pass = false;
            }
            // 2. createPlaylistWithTracks
            QString inlinePlId2 = libMgr->createPlaylistWithTracks("Phase 9.4 Auto Add PL", QStringList{"C:/auto_add_1.mp3", "C:/auto_add_2.mp3"});
            if (inlinePlId2.isEmpty()) {
                qWarning() << "[Test-Phase9.4] createPlaylistWithTracks failed to return valid ID!";
                pass = false;
            }
            PlaylistItem foundPl = libMgr->playlistsModel()->findPlaylist(inlinePlId2);
            if (foundPl.trackPaths.size() != 2) {
                qWarning() << "[Test-Phase9.4] createPlaylistWithTracks did not add tracks properly!" << foundPl.trackPaths;
                pass = false;
            }
            libMgr->deletePlaylist(inlinePlId);
            libMgr->deletePlaylist(inlinePlId2);

            // 3. Path normalization for isFavorite / toggleFavorite
            libMgr->toggleFavorite("C:/music/track_test.mp3");
            if (!libMgr->isFavorite("c:\\music\\track_test.mp3")) {
                qWarning() << "[Test-Phase9.4] isFavorite failed case/slash-insensitive check!";
                pass = false;
            }
            libMgr->toggleFavorite("c:\\music\\track_test.mp3");
            if (libMgr->isFavorite("C:/music/track_test.mp3")) {
                qWarning() << "[Test-Phase9.4] toggleFavorite failed to remove on different slash/case!";
                pass = false;
            }

            // 4. Verify new SVGs: heart_outline.svg and playlist_add.svg
            QSvgRenderer heartOutSvg(QStringLiteral(":/assets/icons/heart_outline.svg"));
            QSvgRenderer plAddSvg(QStringLiteral(":/assets/icons/playlist_add.svg"));
            if (!heartOutSvg.isValid() || !plAddSvg.isValid()) {
                qWarning() << "[Test-Phase9.4] heart_outline.svg or playlist_add.svg failed to load into QSvgRenderer!";
                pass = false;
            }
        }

        qInfo() << "=== Phase 9 Live Automation Test Result:" << (pass ? "PASSED" : "FAILED") << "===";
        QTimer::singleShot(100, &app, [pass]() {
            QCoreApplication::exit(pass ? 0 : 1);
        });
    }

    if (app.arguments().contains("--screenshot")) {
        int delay = app.arguments().contains("--screenshot-splash") ? 500 : 2500;
        QTimer::singleShot(delay, [mainWindow, &app]() {
            if (mainWindow) {
                if (!app.arguments().contains("--screenshot-splash")) {
                    QObject *splash = mainWindow->findChild<QObject*>("splashScreen");
                    if (splash) {
                        splash->setProperty("visible", false);
                        splash->setProperty("opacity", 0.0);
                    }
                }
                if (app.arguments().contains("--demo-favorites")) {
                    mainWindow->setProperty("currentTab", "playlist");
                    QObject *plView = mainWindow->findChild<QObject*>("playlistsView");
                    if (plView) {
                        plView->setProperty("selectedPlaylistId", "__favorites__");
                        LibraryManager::instance()->selectPlaylist("__favorites__");
                    }
                }
                QImage img = mainWindow->grabWindow();
                QString outPath = QDir::currentPath() + "/build/screenshot_actual.png";
                bool ok = img.save(outPath);
                if (!ok) {
                    outPath = QCoreApplication::applicationDirPath() + "/screenshot_actual.png";
                    img.save(outPath);
                }
                qInfo() << "[Screenshot] Successfully grabbed window to:" << outPath << "size:" << img.size();
            }
            QCoreApplication::exit(0);
        });
    }

    auto restoreWindow = [mainWindow]() {
        if (!mainWindow) return;
        if (mainWindow->visibility() == QWindow::Minimized || !mainWindow->isVisible()) {
            mainWindow->showNormal();
        }
        mainWindow->raise();
        mainWindow->requestActivate();
    };

    QObject::connect(restoreAction, &QAction::triggered, restoreWindow);
    QObject::connect(trayIcon, &QSystemTrayIcon::activated, [restoreWindow](QSystemTrayIcon::ActivationReason reason) {
        if (reason == QSystemTrayIcon::DoubleClick || reason == QSystemTrayIcon::Trigger) {
            restoreWindow();
        }
    });

#if defined(_WIN32)
    qDebug() << "[DWM] Root objects count:" << engine.rootObjects().size();
    if (!engine.rootObjects().isEmpty()) {
        QObject *rootObj = engine.rootObjects().first();
        qDebug() << "[DWM] Root object class:" << rootObj->metaObject()->className();
        if (auto *qquickWin = qobject_cast<QQuickWindow*>(rootObj)) {
            HWND hwnd = reinterpret_cast<HWND>(qquickWin->winId());
            qDebug() << "[DWM] hwnd:" << hwnd;
            if (hwnd) {
                // Install native event filter to handle WM_NCCALCSIZE and remove default chrome
                app.installNativeEventFilter(new FramelessNativeFilter(hwnd));

                // 1. Enable Native Animation Styles, Taskbar Toggle & System Menu
                LONG_PTR style = GetWindowLongPtr(hwnd, GWL_STYLE);
                SetWindowLongPtr(hwnd, GWL_STYLE, style | WS_CAPTION | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU);
                SetWindowPos(hwnd, nullptr, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED);

                // 2. Windows 11 Native Rounded Corners (DWMWCP_ROUND = 2)
                DWORD cornerPreference = DWMWCP_ROUND;
                HRESULT hrCorner = DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &cornerPreference, sizeof(cornerPreference));
                qDebug() << "[DWM] Window corner preference result:" << hrCorner;

                // 3. Native Drop Shadow for Frameless Window (1px bottom margin)
                MARGINS margins = { 0, 0, 1, 0 };
                HRESULT hrShadow = DwmExtendFrameIntoClientArea(hwnd, &margins);
                qDebug() << "[DWM] Drop shadow margin result:" << hrShadow;

                // 4. Dynamic DWM margin and corner adjustment on maximize/restore to prevent white leak
                QObject::connect(qquickWin, &QQuickWindow::visibilityChanged, [hwnd](QWindow::Visibility visibility) {
                    if (visibility == QWindow::Maximized || visibility == QWindow::FullScreen) {
                        MARGINS maxMargins = { 0, 0, 0, 0 };
                        DwmExtendFrameIntoClientArea(hwnd, &maxMargins);
                        DWORD cp = DWMWCP_DONOTROUND;
                        DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &cp, sizeof(cp));
                    } else {
                        MARGINS normMargins = { 0, 0, 1, 0 };
                        DwmExtendFrameIntoClientArea(hwnd, &normMargins);
                        DWORD cp = DWMWCP_ROUND;
                        DwmSetWindowAttribute(hwnd, DWMWA_WINDOW_CORNER_PREFERENCE, &cp, sizeof(cp));
                    }
                });
            }
        } else {
            qWarning() << "[DWM] Root object is not a QQuickWindow!";
        }
    }
#else
    // On Linux (X11 / Wayland), Qt handles frameless window management via Qt::FramelessWindowHint in Main.qml
    // Native window dragging and resizing are delegated to startSystemMove() / startSystemResize() in CustomTitleBar & WindowResizeHandler.
    qDebug() << "[Viewport] Non-Windows platform detected (" << app.platformName() << "). Using standard Qt frameless viewport.";
    if (!engine.rootObjects().isEmpty()) {
        QObject *rootObj = engine.rootObjects().first();
        if (auto *qquickWin = qobject_cast<QQuickWindow*>(rootObj)) {
            qDebug() << "[Viewport] Root window initialized successfully.";
        }
    }
#endif

    return app.exec();
}
