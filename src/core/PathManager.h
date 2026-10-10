#pragma once

#include <QObject>
#include <QString>
#include <QDir>
#include <QFile>
#include <QSettings>
#include <memory>

class PathManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool isPortable READ isPortable CONSTANT)
    Q_PROPERTY(QString configDir READ configDir CONSTANT)
    Q_PROPERTY(QString dataDir READ dataDir CONSTANT)
    Q_PROPERTY(QString cacheDir READ cacheDir CONSTANT)
    Q_PROPERTY(QString logDir READ logDir CONSTANT)
    Q_PROPERTY(QString configFile READ configFile CONSTANT)

public:
    static PathManager *instance();

    explicit PathManager(QObject *parent = nullptr);
    ~PathManager() override = default;

    Q_INVOKABLE bool isPortable() const { return m_isPortable; }
    Q_INVOKABLE QString configDir() const { return m_configDir; }
    Q_INVOKABLE QString dataDir() const { return m_dataDir; }
    Q_INVOKABLE QString cacheDir() const { return m_cacheDir; }
    Q_INVOKABLE QString logDir() const { return m_logDir; }

    Q_INVOKABLE QString configFile() const { return m_configDir + "/config.ini"; }
    Q_INVOKABLE QString libraryCacheFile() const { return m_dataDir + "/library_cache.json"; }
    Q_INVOKABLE QString favoritesFile() const { return m_dataDir + "/favorites.json"; }
    Q_INVOKABLE QString playlistsFile() const { return m_dataDir + "/playlists.json"; }
    Q_INVOKABLE QString coversDir() const { return m_cacheDir + "/covers"; }
    Q_INVOKABLE QString avatarsDir() const { return m_dataDir + "/avatars"; }
    Q_INVOKABLE QString appLogFile() const { return m_logDir + "/app.log"; }

    Q_INVOKABLE void ensureDirsExist() const;

    // Helper to override portable mode or base dir (e.g. for testing)
    void setPortableMode(bool portable);
    void setCustomBaseDir(const QString &baseDir);

private:
    void resolvePaths();

    bool m_isPortable = false;
    QString m_customBaseDir;
    QString m_configDir;
    QString m_dataDir;
    QString m_cacheDir;
    QString m_logDir;
};
