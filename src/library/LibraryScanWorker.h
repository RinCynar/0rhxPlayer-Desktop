#pragma once

#include <QObject>
#include <QStringList>
#include <QList>
#include <atomic>
#include "../model/TrackItem.h"

class LibraryScanWorker : public QObject {
    Q_OBJECT
public:
    explicit LibraryScanWorker(const QStringList &folderPaths, QObject *parent = nullptr)
        : QObject(parent), m_folderPaths(folderPaths) {}

    void requestStop() {
        m_stopRequested.store(true, std::memory_order_relaxed);
    }

public slots:
    void doScan();

signals:
    void batchDiscovered(const QList<TrackItem> &batch, int totalScanned);
    void scanFinished(const QList<TrackItem> &allTracks);

private:
    QStringList m_folderPaths;
    std::atomic<bool> m_stopRequested{false};
};
