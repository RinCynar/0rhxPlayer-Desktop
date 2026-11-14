#pragma once

#include <QAbstractListModel>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QDateTime>
#include <QProcess>
#include <QMap>
#include <QPointer>

struct PluginTaskItem {
    QString id;
    QString pluginId;
    QString title;
    QString sourcePath;
    QString targetPath;
    QString format;
    QString status = "pending"; // pending, running, completed, failed, canceled
    int progress = 0;           // 0 - 100
    QString errorMsg;
    QString logOutput;
    QString program;
    QStringList arguments;
    QString workingDir;
    qint64 totalDurationMs = 0;
};

class PluginTaskModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(QString pluginFilter READ pluginFilter WRITE setPluginFilter NOTIFY pluginFilterChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int activeCount READ activeCount NOTIFY activeCountChanged)

public:
    enum TaskRoles {
        IdRole = Qt::UserRole + 1,
        PluginIdRole,
        TitleRole,
        SourcePathRole,
        TargetPathRole,
        FormatRole,
        StatusRole,
        ProgressRole,
        ErrorMsgRole,
        LogOutputRole,
        CanRetryRole,
        CanCancelRole
    };
    Q_ENUM(TaskRoles)

    explicit PluginTaskModel(QObject *parent = nullptr);
    ~PluginTaskModel() override;

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    QString pluginFilter() const;
    void setPluginFilter(const QString &filter);

    int count() const;
    int activeCount() const;

    Q_INVOKABLE QString addTask(const QString &pluginId,
                                const QString &title,
                                const QString &sourcePath,
                                const QString &targetPath = QString(),
                                const QString &format = QString());
    Q_INVOKABLE void addTaskMap(const QVariantMap &taskMap);
    Q_INVOKABLE void startTask(const QString &taskId,
                               const QString &program = QString(),
                               const QStringList &arguments = QStringList(),
                               const QString &workingDir = QString());
    Q_INVOKABLE void startNextPendingTask(const QString &pluginId = QString());
    Q_INVOKABLE void startAllTasks(const QString &pluginId = QString());
    Q_INVOKABLE void cancelTask(const QString &taskId);
    Q_INVOKABLE void cancelAllTasks(const QString &pluginId = QString());
    Q_INVOKABLE void retryTask(const QString &taskId);
    Q_INVOKABLE void removeTask(const QString &taskId);
    Q_INVOKABLE void clearTasks(const QString &pluginId = QString());
    Q_INVOKABLE void updateTaskProgress(const QString &taskId, int progress, const QString &status = QString(), const QString &errorMsg = QString());
    Q_INVOKABLE QVariantMap getTask(const QString &taskId) const;
    Q_INVOKABLE QVariantList getTasks(const QString &pluginId = QString()) const;

signals:
    void pluginFilterChanged();
    void countChanged();
    void activeCountChanged();
    void taskAdded(const QString &taskId);
    void taskUpdated(const QString &taskId, const QString &status, int progress);
    void taskFinished(const QString &taskId, bool success, const QString &errorMsg);

private slots:
    void onProcessReadyReadStandardOutput(const QString &taskId);
    void onProcessReadyReadStandardError(const QString &taskId);
    void onProcessFinished(const QString &taskId, int exitCode, QProcess::ExitStatus exitStatus);
    void onProcessError(const QString &taskId, QProcess::ProcessError error);

private:
    int findTaskIndex(const QString &taskId) const;
    int findFilteredRow(const QString &taskId) const;
    void updateFilteredIndices();
    void setTaskStatus(const QString &taskId, const QString &status, int progress = -1, const QString &errorMsg = QString());
    void parseOutputForProgress(PluginTaskItem &task, const QString &text);

    QList<PluginTaskItem> m_tasks;
    QList<int> m_filteredIndices;
    QString m_pluginFilter;
    QMap<QString, QProcess*> m_runningProcesses;
};
