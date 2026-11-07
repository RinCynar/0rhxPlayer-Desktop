#pragma once

#include <QObject>
#include <QTimer>
#include <QMap>
#include <QJSValue>
#include <QJSEngine>
#include <algorithm>

class JsTimerBridge : public QObject {
    Q_OBJECT
public:
    explicit JsTimerBridge(QJSEngine *engine, QObject *parent = nullptr)
        : QObject(parent), m_engine(engine) {}

    ~JsTimerBridge() override {
        for (QTimer *t : m_timers) {
            if (t) {
                t->stop();
            }
        }
        m_timers.clear();
        m_callbacks.clear();
    }

    Q_INVOKABLE int setTimeout(const QJSValue &callback, int delayMs = 0) {
        int id = ++m_nextId;
        QTimer *timer = new QTimer(this);
        timer->setSingleShot(true);
        connect(timer, &QTimer::timeout, this, [this, timer, id]() {
            if (m_callbacks.contains(id)) {
                QJSValue cb = m_callbacks.take(id);
                m_timers.remove(id);
                timer->deleteLater();
                if (cb.isCallable()) {
                    cb.call();
                }
            }
        });
        m_callbacks[id] = callback;
        m_timers[id] = timer;
        timer->start(std::max(0, delayMs));
        return id;
    }

    Q_INVOKABLE void clearTimeout(int id) {
        if (m_timers.contains(id)) {
            QTimer *t = m_timers.take(id);
            t->stop();
            t->deleteLater();
        }
        m_callbacks.remove(id);
    }

private:
    QJSEngine *m_engine = nullptr;
    int m_nextId = 0;
    QMap<int, QJSValue> m_callbacks;
    QMap<int, QTimer*> m_timers;
};
