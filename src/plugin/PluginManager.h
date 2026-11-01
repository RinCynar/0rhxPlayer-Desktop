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
    bool enabled = true;
    bool installed = false;
    QString localDir;
    QJsonObject sidebar;
    QJsonObject hooks;

    QVariantMap toMap() const;
    static PluginMetadata fromJson(const QJsonObject &obj);
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

signals:
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
