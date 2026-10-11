#include "PathManager.h"

#include <QCoreApplication>
#include <QStandardPaths>
#include <QFileInfo>
#include <QDebug>

PathManager *PathManager::instance()
{
    static PathManager s_instance;
    return &s_instance;
}

PathManager::PathManager(QObject *parent)
    : QObject(parent)
{
    resolvePaths();
}

void PathManager::setPortableMode(bool portable)
{
    m_isPortable = portable;
    m_customBaseDir.clear();
    resolvePaths();
}

void PathManager::setCustomBaseDir(const QString &baseDir)
{
    m_customBaseDir = baseDir;
    m_isPortable = true;
    resolvePaths();
}

void PathManager::resolvePaths()
{
    const QString appDir = QCoreApplication::applicationDirPath();

    // Check if customBaseDir was provided (e.g. in test suite)
    if (!m_customBaseDir.isEmpty()) {
        m_isPortable = true;
        m_configDir = QDir::cleanPath(m_customBaseDir + "/config");
        m_dataDir = QDir::cleanPath(m_customBaseDir + "/data");
        m_cacheDir = QDir::cleanPath(m_customBaseDir + "/cache");
        m_logDir = QDir::cleanPath(m_customBaseDir + "/logs");
        return;
    }

    // Determine portable mode if not explicitly set
    // Check command line arguments, portable.dat, or portable/ directory
    bool markerFileExists = QFile::exists(appDir + "/portable.dat");
    bool portableDirExists = QDir(appDir + "/portable").exists();
    bool argPortable = false;
    for (const QString &arg : QCoreApplication::arguments()) {
        if (arg == "--portable") {
            argPortable = true;
            break;
        }
    }

    if (m_isPortable || markerFileExists || portableDirExists || argPortable) {
        m_isPortable = true;
        const QString portableBase = appDir + "/portable";
        m_configDir = QDir::cleanPath(portableBase + "/config");
        m_dataDir = QDir::cleanPath(portableBase + "/data");
        m_cacheDir = QDir::cleanPath(portableBase + "/cache");
        m_logDir = QDir::cleanPath(portableBase + "/logs");
        qDebug() << "[PathManager] Portable Mode Active. Root:" << portableBase;
        return;
    }

    m_isPortable = false;

#if defined(Q_OS_WIN)
    // Windows Standard Known Folders:
    // Config: %APPDATA%/0rhxPlayer
    QString roaming = QString::fromLocal8Bit(qgetenv("APPDATA"));
    if (roaming.isEmpty()) {
        roaming = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
    }
    if (roaming.isEmpty()) {
        roaming = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    }
    m_configDir = QDir::cleanPath(QDir::fromNativeSeparators(roaming) + "/0rhxPlayer");

    // Data: %LOCALAPPDATA%/0rhxPlayer/data
    // Cache: %LOCALAPPDATA%/0rhxPlayer/cache
    // Logs: %LOCALAPPDATA%/0rhxPlayer/logs
    QString localApp = QString::fromLocal8Bit(qgetenv("LOCALAPPDATA"));
    if (localApp.isEmpty()) {
        localApp = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
    }
    if (localApp.isEmpty()) {
        localApp = roaming;
    }
    const QString localBase = QDir::cleanPath(QDir::fromNativeSeparators(localApp) + "/0rhxPlayer");
    m_dataDir = localBase + "/data";
    m_cacheDir = localBase + "/cache";
    m_logDir = localBase + "/logs";

#else
    // Linux XDG Base Directory Specification:
    // Config: $XDG_CONFIG_HOME/0rhxPlayer or ~/.config/0rhxPlayer
    QString xdgConfig = QString::fromLocal8Bit(qgetenv("XDG_CONFIG_HOME"));
    if (xdgConfig.isEmpty()) {
        xdgConfig = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
        if (xdgConfig.isEmpty()) {
            xdgConfig = QDir::homePath() + "/.config";
        }
    }
    m_configDir = QDir::cleanPath(xdgConfig + "/0rhxPlayer");

    // Data: $XDG_DATA_HOME/0rhxPlayer/data or ~/.local/share/0rhxPlayer/data
    QString xdgData = QString::fromLocal8Bit(qgetenv("XDG_DATA_HOME"));
    if (xdgData.isEmpty()) {
        xdgData = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
        if (xdgData.isEmpty()) {
            xdgData = QDir::homePath() + "/.local/share";
        }
    }
    m_dataDir = QDir::cleanPath(xdgData + "/0rhxPlayer/data");

    // Cache: $XDG_CACHE_HOME/0rhxPlayer or ~/.cache/0rhxPlayer
    QString xdgCache = QString::fromLocal8Bit(qgetenv("XDG_CACHE_HOME"));
    if (xdgCache.isEmpty()) {
        xdgCache = QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation);
        if (xdgCache.isEmpty()) {
            xdgCache = QDir::homePath() + "/.cache";
        }
    }
    m_cacheDir = QDir::cleanPath(xdgCache + "/0rhxPlayer");

    // Logs: $XDG_STATE_HOME/0rhxPlayer/logs or ~/.local/state/0rhxPlayer/logs or cache/logs
    QString xdgState = QString::fromLocal8Bit(qgetenv("XDG_STATE_HOME"));
    if (xdgState.isEmpty()) {
        m_logDir = m_cacheDir + "/logs";
    } else {
        m_logDir = QDir::cleanPath(xdgState + "/0rhxPlayer/logs");
    }
#endif

    qDebug() << "[PathManager] Standard Mode Active."
             << "Config:" << m_configDir
             << "Data:" << m_dataDir
             << "Cache:" << m_cacheDir
             << "Logs:" << m_logDir;
}

namespace {
bool copyDirRecursively(const QString &srcPath, const QString &dstPath)
{
    QDir srcDir(srcPath);
    if (!srcDir.exists()) return false;
    QDir().mkpath(dstPath);

    const auto entries = srcDir.entryInfoList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot | QDir::Hidden);
    for (const QFileInfo &entry : entries) {
        QString srcItem = entry.filePath();
        QString dstItem = dstPath + "/" + entry.fileName();
        if (entry.isDir()) {
            copyDirRecursively(srcItem, dstItem);
        } else {
            if (QFile::exists(dstItem)) {
                QFile::remove(dstItem);
            }
            QFile::copy(srcItem, dstItem);
        }
    }
    return true;
}
}

void PathManager::migrateLegacyDirs()
{
    if (m_isPortable) return;

#if defined(Q_OS_WIN)
    QString localApp = QString::fromLocal8Bit(qgetenv("LOCALAPPDATA"));
    if (localApp.isEmpty()) {
        localApp = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
    }
    QString roamingApp = QString::fromLocal8Bit(qgetenv("APPDATA"));
    if (roamingApp.isEmpty()) {
        roamingApp = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
    }

    auto migrateAndClean = [](const QString &oldDirStr, const QString &targetDirStr) {
        QDir oldDir(oldDirStr);
        if (!oldDir.exists()) return;

        QString nestedApp = oldDirStr + "/0rhxPlayer";
        if (QDir(nestedApp).exists()) {
            copyDirRecursively(nestedApp, targetDirStr);
            QDir(nestedApp).removeRecursively();
        }

        copyDirRecursively(oldDirStr, targetDirStr);
        oldDir.removeRecursively();
        qInfo() << "[PathManager] Legacy directory migrated and cleaned up:" << oldDirStr << "->" << targetDirStr;
    };

    if (!localApp.isEmpty()) {
        QString oldLocal = QDir::cleanPath(QDir::fromNativeSeparators(localApp) + "/0rhx");
        QString newLocal = QDir::cleanPath(QDir::fromNativeSeparators(localApp) + "/0rhxPlayer");
        migrateAndClean(oldLocal, newLocal);
    }

    if (!roamingApp.isEmpty()) {
        QString oldRoaming = QDir::cleanPath(QDir::fromNativeSeparators(roamingApp) + "/0rhx");
        QString newRoaming = QDir::cleanPath(QDir::fromNativeSeparators(roamingApp) + "/0rhxPlayer");
        migrateAndClean(oldRoaming, newRoaming);
    }
#else
    QString home = QDir::homePath();
    auto migrateLinux = [](const QString &oldDirStr, const QString &targetDirStr) {
        QDir oldDir(oldDirStr);
        if (!oldDir.exists()) return;
        copyDirRecursively(oldDirStr, targetDirStr);
        oldDir.removeRecursively();
        qInfo() << "[PathManager] Legacy directory migrated and cleaned up:" << oldDirStr << "->" << targetDirStr;
    };
    migrateLinux(home + "/.config/0rhx", home + "/.config/0rhxPlayer");
    migrateLinux(home + "/.local/share/0rhx", home + "/.local/share/0rhxPlayer");
    migrateLinux(home + "/.cache/0rhx", home + "/.cache/0rhxPlayer");
#endif
}

void PathManager::ensureDirsExist() const
{
    const_cast<PathManager*>(this)->migrateLegacyDirs();

    QDir().mkpath(m_configDir);
    QDir().mkpath(m_dataDir);
    QDir().mkpath(m_cacheDir);
    QDir().mkpath(m_logDir);
    QDir().mkpath(coversDir());
    QDir().mkpath(avatarsDir());
}
