#include "PluginTaskModel.h"
#include <QFileInfo>
#include <QDir>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QDebug>

PluginTaskModel::PluginTaskModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

PluginTaskModel::~PluginTaskModel()
{
    cancelAllTasks();
}

int PluginTaskModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_filteredIndices.size();
}

QVariant PluginTaskModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_filteredIndices.size()) {
        return QVariant();
    }

    int realIdx = m_filteredIndices.at(index.row());
    if (realIdx < 0 || realIdx >= m_tasks.size()) {
        return QVariant();
    }

    const auto &item = m_tasks.at(realIdx);
    switch (role) {
    case IdRole:
        return item.id;
    case PluginIdRole:
        return item.pluginId;
    case TitleRole:
        return item.title;
    case SourcePathRole:
        return item.sourcePath;
    case TargetPathRole:
        return item.targetPath;
    case FormatRole:
        return item.format;
    case StatusRole:
        return item.status;
    case ProgressRole:
        return item.progress;
    case ErrorMsgRole:
        return item.errorMsg;
    case LogOutputRole:
        return item.logOutput;
    case CanRetryRole:
        return (item.status == "failed" || item.status == "canceled");
    case CanCancelRole:
        return (item.status == "running" || item.status == "pending");
    default:
        break;
    }
    return QVariant();
}

QHash<int, QByteArray> PluginTaskModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[IdRole] = "id";
    roles[PluginIdRole] = "pluginId";
    roles[TitleRole] = "title";
    roles[SourcePathRole] = "sourcePath";
    roles[TargetPathRole] = "targetPath";
    roles[FormatRole] = "format";
    roles[StatusRole] = "status";
    roles[ProgressRole] = "progress";
    roles[ErrorMsgRole] = "errorMsg";
    roles[LogOutputRole] = "logOutput";
    roles[CanRetryRole] = "canRetry";
    roles[CanCancelRole] = "canCancel";
    return roles;
}

QString PluginTaskModel::pluginFilter() const
{
    return m_pluginFilter;
}

void PluginTaskModel::setPluginFilter(const QString &filter)
{
    if (m_pluginFilter == filter) return;
    beginResetModel();
    m_pluginFilter = filter;
    updateFilteredIndices();
    endResetModel();
    emit pluginFilterChanged();
    emit countChanged();
    emit activeCountChanged();
}

int PluginTaskModel::count() const
{
    return m_filteredIndices.size();
}

int PluginTaskModel::activeCount() const
{
    int active = 0;
    for (int idx : m_filteredIndices) {
        if (idx >= 0 && idx < m_tasks.size()) {
            const auto &st = m_tasks.at(idx).status;
            if (st == "running" || st == "pending") {
                active++;
            }
        }
    }
    return active;
}

int PluginTaskModel::findTaskIndex(const QString &taskId) const
{
    for (int i = 0; i < m_tasks.size(); ++i) {
        if (m_tasks.at(i).id == taskId) {
            return i;
        }
    }
    return -1;
}

int PluginTaskModel::findFilteredRow(const QString &taskId) const
{
    for (int r = 0; r < m_filteredIndices.size(); ++r) {
        int idx = m_filteredIndices.at(r);
        if (idx >= 0 && idx < m_tasks.size() && m_tasks.at(idx).id == taskId) {
            return r;
        }
    }
    return -1;
}

void PluginTaskModel::updateFilteredIndices()
{
    m_filteredIndices.clear();
    for (int i = 0; i < m_tasks.size(); ++i) {
        if (m_pluginFilter.isEmpty() || m_tasks.at(i).pluginId == m_pluginFilter) {
            m_filteredIndices.append(i);
        }
    }
}

QString PluginTaskModel::addTask(const QString &pluginId,
                                 const QString &title,
                                 const QString &sourcePath,
                                 const QString &targetPath,
                                 const QString &format)
{
    PluginTaskItem item;
    item.id = "task_" + QString::number(QDateTime::currentMSecsSinceEpoch()) + "_" + QString::number(m_tasks.size() + 1);
    item.pluginId = pluginId;
    item.title = title.isEmpty() ? QFileInfo(sourcePath).fileName() : title;
    item.sourcePath = sourcePath;
    item.targetPath = targetPath;
    item.format = format;
    item.status = "pending";
    item.progress = 0;

    bool matchesFilter = (m_pluginFilter.isEmpty() || item.pluginId == m_pluginFilter);
    if (matchesFilter) {
        int newRow = m_filteredIndices.size();
        beginInsertRows(QModelIndex(), newRow, newRow);
        m_tasks.append(item);
        m_filteredIndices.append(m_tasks.size() - 1);
        endInsertRows();
    } else {
        m_tasks.append(item);
    }

    emit countChanged();
    emit activeCountChanged();
    emit taskAdded(item.id);
    return item.id;
}

void PluginTaskModel::addTaskMap(const QVariantMap &taskMap)
{
    QString pid = taskMap.value("pluginId").toString();
    QString title = taskMap.value("title").toString();
    QString src = taskMap.value("sourcePath").toString();
    if (src.isEmpty()) src = taskMap.value("filePath").toString();
    if (src.isEmpty()) src = taskMap.value("path").toString();
    QString tgt = taskMap.value("targetPath").toString();
    QString fmt = taskMap.value("format").toString();

    QString tid = addTask(pid, title, src, tgt, fmt);
    int realIdx = findTaskIndex(tid);
    if (realIdx >= 0) {
        if (taskMap.contains("program")) m_tasks[realIdx].program = taskMap.value("program").toString();
        if (taskMap.contains("arguments")) m_tasks[realIdx].arguments = taskMap.value("arguments").toStringList();
        if (taskMap.contains("workingDir")) m_tasks[realIdx].workingDir = taskMap.value("workingDir").toString();
    }
}

void PluginTaskModel::setTaskStatus(const QString &taskId, const QString &status, int progress, const QString &errorMsg)
{
    int realIdx = findTaskIndex(taskId);
    if (realIdx < 0) return;

    m_tasks[realIdx].status = status;
    if (progress >= 0) {
        m_tasks[realIdx].progress = progress;
    }
    if (!errorMsg.isEmpty()) {
        m_tasks[realIdx].errorMsg = errorMsg;
    }

    int row = findFilteredRow(taskId);
    if (row >= 0) {
        QModelIndex idx = index(row, 0);
        emit dataChanged(idx, idx, {StatusRole, ProgressRole, ErrorMsgRole, CanRetryRole, CanCancelRole});
    }

    emit activeCountChanged();
    emit taskUpdated(taskId, status, m_tasks[realIdx].progress);
    if (status == "completed" || status == "failed" || status == "canceled") {
        emit taskFinished(taskId, (status == "completed"), m_tasks[realIdx].errorMsg);
    }
}

void PluginTaskModel::startTask(const QString &taskId,
                                const QString &program,
                                const QStringList &arguments,
                                const QString &workingDir)
{
    int realIdx = findTaskIndex(taskId);
    if (realIdx < 0) return;

    if (m_runningProcesses.contains(taskId)) {
        return; // Already running
    }

    auto &item = m_tasks[realIdx];
    if (!program.isEmpty()) item.program = program;
    if (!arguments.isEmpty()) item.arguments = arguments;
    if (!workingDir.isEmpty()) item.workingDir = workingDir;

    if (item.program.isEmpty()) {
        setTaskStatus(taskId, "failed", -1, "No executable program specified");
        return;
    }

    // Auto-create destination directory if output argument is present
    for (int i = 0; i < item.arguments.size(); ++i) {
        if (item.arguments[i] == "-y" && i + 1 < item.arguments.size()) {
            QFileInfo outFi(item.arguments[i + 1]);
            QDir().mkpath(outFi.absolutePath());
        }
    }

    QString exePath = QStandardPaths::findExecutable(item.program);
    if (exePath.isEmpty()) {
        exePath = item.program;
    }

    QProcess *proc = new QProcess(this);
    if (!item.workingDir.isEmpty()) {
        proc->setWorkingDirectory(item.workingDir);
    }
    m_runningProcesses[taskId] = proc;
    setTaskStatus(taskId, "running", 0);

    connect(proc, &QProcess::readyReadStandardOutput, this, [this, taskId]() {
        onProcessReadyReadStandardOutput(taskId);
    });
    connect(proc, &QProcess::readyReadStandardError, this, [this, taskId]() {
        onProcessReadyReadStandardError(taskId);
    });
    connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this,
            [this, taskId](int exitCode, QProcess::ExitStatus exitStatus) {
        onProcessFinished(taskId, exitCode, exitStatus);
    });
    connect(proc, &QProcess::errorOccurred, this, [this, taskId](QProcess::ProcessError error) {
        onProcessError(taskId, error);
    });

    qInfo() << "[PluginTaskModel] Starting async task:" << taskId << exePath << item.arguments;
    proc->start(exePath, item.arguments);
}

void PluginTaskModel::onProcessReadyReadStandardOutput(const QString &taskId)
{
    int realIdx = findTaskIndex(taskId);
    if (realIdx < 0 || !m_runningProcesses.contains(taskId)) return;

    QProcess *proc = m_runningProcesses.value(taskId);
    QString out = QString::fromUtf8(proc->readAllStandardOutput());
    m_tasks[realIdx].logOutput += out;
}

void PluginTaskModel::onProcessReadyReadStandardError(const QString &taskId)
{
    int realIdx = findTaskIndex(taskId);
    if (realIdx < 0 || !m_runningProcesses.contains(taskId)) return;

    QProcess *proc = m_runningProcesses.value(taskId);
    QString err = QString::fromUtf8(proc->readAllStandardError());
    m_tasks[realIdx].logOutput += err;
    parseOutputForProgress(m_tasks[realIdx], err);

    int row = findFilteredRow(taskId);
    if (row >= 0) {
        QModelIndex idx = index(row, 0);
        emit dataChanged(idx, idx, {ProgressRole, LogOutputRole});
    }
}

void PluginTaskModel::parseOutputForProgress(PluginTaskItem &task, const QString &text)
{
    // 1. Parse Duration: 00:03:45.12
    if (task.totalDurationMs <= 0) {
        static QRegularExpression reDur("Duration:\\s*(\\d+):(\\d+):(\\d+\\.?\\d*)");
        auto match = reDur.match(text);
        if (match.hasMatch()) {
            qint64 h = match.captured(1).toLongLong();
            qint64 m = match.captured(2).toLongLong();
            double s = match.captured(3).toDouble();
            task.totalDurationMs = static_cast<qint64>((h * 3600 + m * 60 + s) * 1000.0);
        }
    }

    // 2. Parse time=00:01:23.45
    static QRegularExpression reTime("time=\\s*(\\d+):(\\d+):(\\d+\\.?\\d*)");
    auto matchTime = reTime.match(text);
    if (matchTime.hasMatch() && task.totalDurationMs > 0) {
        qint64 h = matchTime.captured(1).toLongLong();
        qint64 m = matchTime.captured(2).toLongLong();
        double s = matchTime.captured(3).toDouble();
        qint64 curMs = static_cast<qint64>((h * 3600 + m * 60 + s) * 1000.0);
        int pct = static_cast<int>((curMs * 100) / task.totalDurationMs);
        task.progress = qBound(0, pct, 99);
    }

    // 3. Parse explicit progress percentage if provided, e.g. "progress: 45%"
    static QRegularExpression rePct("progress[:=]\\s*(\\d+)%?");
    auto matchPct = rePct.match(text);
    if (matchPct.hasMatch()) {
        task.progress = qBound(0, matchPct.captured(1).toInt(), 99);
    }
}

void PluginTaskModel::onProcessFinished(const QString &taskId, int exitCode, QProcess::ExitStatus exitStatus)
{
    if (m_runningProcesses.contains(taskId)) {
        QProcess *proc = m_runningProcesses.take(taskId);
        proc->deleteLater();
    }

    if (exitStatus == QProcess::NormalExit && exitCode == 0) {
        qInfo() << "[PluginTaskModel] Task completed successfully:" << taskId;
        setTaskStatus(taskId, "completed", 100);
    } else {
        qWarning() << "[PluginTaskModel] Task failed:" << taskId << "exit code:" << exitCode;
        setTaskStatus(taskId, "failed", -1, QString("Process exited with code %1").arg(exitCode));
    }

    // Sequentially advance queue
    startNextPendingTask();
}

void PluginTaskModel::onProcessError(const QString &taskId, QProcess::ProcessError error)
{
    Q_UNUSED(error);
    if (m_runningProcesses.contains(taskId)) {
        QProcess *proc = m_runningProcesses.take(taskId);
        QString errStr = proc->errorString();
        proc->deleteLater();
        qWarning() << "[PluginTaskModel] Process error on task:" << taskId << errStr;
        setTaskStatus(taskId, "failed", -1, errStr);
    }

    startNextPendingTask();
}

void PluginTaskModel::startNextPendingTask(const QString &pluginId)
{
    QString filterPid = pluginId.isEmpty() ? m_pluginFilter : pluginId;
    for (int i = 0; i < m_tasks.size(); ++i) {
        const auto &task = m_tasks.at(i);
        if (task.status == "pending") {
            if (filterPid.isEmpty() || task.pluginId == filterPid) {
                if (!task.program.isEmpty()) {
                    startTask(task.id);
                    return;
                }
            }
        }
    }
}

void PluginTaskModel::startAllTasks(const QString &pluginId)
{
    startNextPendingTask(pluginId);
}

void PluginTaskModel::cancelTask(const QString &taskId)
{
    if (m_runningProcesses.contains(taskId)) {
        QProcess *proc = m_runningProcesses.take(taskId);
        proc->kill();
        proc->deleteLater();
    }
    setTaskStatus(taskId, "canceled");
}

void PluginTaskModel::cancelAllTasks(const QString &pluginId)
{
    QString filterPid = pluginId.isEmpty() ? m_pluginFilter : pluginId;
    for (int i = 0; i < m_tasks.size(); ++i) {
        const auto &task = m_tasks.at(i);
        if (filterPid.isEmpty() || task.pluginId == filterPid) {
            if (task.status == "running" || task.status == "pending") {
                cancelTask(task.id);
            }
        }
    }
}

void PluginTaskModel::retryTask(const QString &taskId)
{
    int realIdx = findTaskIndex(taskId);
    if (realIdx < 0) return;

    setTaskStatus(taskId, "pending", 0, "");
    if (!m_tasks[realIdx].program.isEmpty()) {
        startTask(taskId);
    }
}

void PluginTaskModel::removeTask(const QString &taskId)
{
    cancelTask(taskId);

    int row = findFilteredRow(taskId);
    int realIdx = findTaskIndex(taskId);
    if (realIdx < 0) return;

    if (row >= 0) {
        beginRemoveRows(QModelIndex(), row, row);
        m_tasks.removeAt(realIdx);
        updateFilteredIndices();
        endRemoveRows();
    } else {
        m_tasks.removeAt(realIdx);
        updateFilteredIndices();
    }

    emit countChanged();
    emit activeCountChanged();
}

void PluginTaskModel::updateTaskProgress(const QString &taskId, int progress, const QString &status, const QString &errorMsg)
{
    int realIdx = findTaskIndex(taskId);
    if (realIdx < 0) return;

    m_tasks[realIdx].progress = qBound(0, progress, 100);
    if (!status.isEmpty()) {
        m_tasks[realIdx].status = status;
    }
    if (!errorMsg.isEmpty()) {
        m_tasks[realIdx].errorMsg = errorMsg;
    }

    int row = findFilteredRow(taskId);
    if (row >= 0) {
        emit dataChanged(index(row, 0), index(row, 0), {ProgressRole, StatusRole, ErrorMsgRole});
    }
    emit activeCountChanged();
}

void PluginTaskModel::clearTasks(const QString &pluginId)
{
    cancelAllTasks(pluginId);

    QString filterPid = pluginId.isEmpty() ? m_pluginFilter : pluginId;
    beginResetModel();
    if (filterPid.isEmpty()) {
        m_tasks.clear();
    } else {
        for (int i = m_tasks.size() - 1; i >= 0; --i) {
            if (m_tasks.at(i).pluginId == filterPid) {
                m_tasks.removeAt(i);
            }
        }
    }
    updateFilteredIndices();
    endResetModel();

    emit countChanged();
    emit activeCountChanged();
}

QVariantMap PluginTaskModel::getTask(const QString &taskId) const
{
    int realIdx = findTaskIndex(taskId);
    if (realIdx < 0) return QVariantMap();

    const auto &item = m_tasks.at(realIdx);
    QVariantMap map;
    map["id"] = item.id;
    map["pluginId"] = item.pluginId;
    map["title"] = item.title;
    map["sourcePath"] = item.sourcePath;
    map["targetPath"] = item.targetPath;
    map["format"] = item.format;
    map["status"] = item.status;
    map["progress"] = item.progress;
    map["errorMsg"] = item.errorMsg;
    map["logOutput"] = item.logOutput;
    return map;
}

QVariantList PluginTaskModel::getTasks(const QString &pluginId) const
{
    QVariantList list;
    QString filterPid = pluginId.isEmpty() ? m_pluginFilter : pluginId;
    for (const auto &item : m_tasks) {
        if (filterPid.isEmpty() || item.pluginId == filterPid) {
            QVariantMap map;
            map["id"] = item.id;
            map["pluginId"] = item.pluginId;
            map["title"] = item.title;
            map["sourcePath"] = item.sourcePath;
            map["targetPath"] = item.targetPath;
            map["format"] = item.format;
            map["status"] = item.status;
            map["progress"] = item.progress;
            map["errorMsg"] = item.errorMsg;
            list.append(map);
        }
    }
    return list;
}
