#pragma once

#include <QObject>
#include <QString>
#include <QList>
#include <QTimer>
#include <cstdint>
#include <cmath>
#include <algorithm>

#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include "basswasapi.h"
#endif
#include "bass.h"
#include "bassflac.h"

#include <mutex>

struct EqFilterCoeffs {
    float b0 = 1.0f, b1 = 0.0f, b2 = 0.0f;
    float a1 = 0.0f, a2 = 0.0f;

    static EqFilterCoeffs calculate(float sampleRate, float freq, float gainDb, float q = 1.414f) {
        EqFilterCoeffs c;
        if (std::abs(gainDb) < 0.05f || sampleRate <= 0.0f) {
            c.b0 = 1.0f; c.b1 = 0.0f; c.b2 = 0.0f;
            c.a1 = 0.0f; c.a2 = 0.0f;
            return c;
        }
        float clampedGain = std::clamp(gainDb, -12.0f, 12.0f);
        float a = std::pow(10.0f, clampedGain / 40.0f);
        float w0 = 2.0f * 3.14159265358979323846f * freq / sampleRate;
        float alpha = std::sin(w0) / (2.0f * q);
        float cosW0 = std::cos(w0);

        float tb0 = 1.0f + alpha * a;
        float tb1 = -2.0f * cosW0;
        float tb2 = 1.0f - alpha * a;
        float ta0 = 1.0f + alpha / a;
        float ta1 = -2.0f * cosW0;
        float ta2 = 1.0f - alpha / a;

        c.b0 = tb0 / ta0;
        c.b1 = tb1 / ta0;
        c.b2 = tb2 / ta0;
        c.a1 = ta1 / ta0;
        c.a2 = ta2 / ta0;
        return c;
    }
};

struct EqFilterState {
    float x1[2] = {0.0f, 0.0f};
    float x2[2] = {0.0f, 0.0f};
    float y1[2] = {0.0f, 0.0f};
    float y2[2] = {0.0f, 0.0f};

    void reset() {
        x1[0] = x1[1] = x2[0] = x2[1] = 0.0f;
        y1[0] = y1[1] = y2[0] = y2[1] = 0.0f;
    }
};

class AudioEngineWorker : public QObject
{
    Q_OBJECT
public:
    explicit AudioEngineWorker(QObject *parent = nullptr);
    ~AudioEngineWorker() override;

    void processEqDsp(float *data, size_t sampleCount);

public slots:
    void initialize();
    void shutdown();
    void play(const QString &filePath);
    void pause();
    void resume();
    void stop();
    void seek(qint64 positionMs);
    void setVolume(float volume);
    void setExclusive(bool exclusive);

    // Equalizer slots
    void setEqEnabled(bool enabled);
    void setEqPreamp(float preampDb);
    void setEqBands(const QList<float> &bands);
    void setEqBand(int index, float gainDb);

signals:
    void stateChanged(int state); // 0=Stopped, 1=Playing, 2=Paused
    void positionUpdated(qint64 positionMs);
    void durationUpdated(qint64 durationMs);
    void deviceDetected(const QString &deviceName);
    void exclusiveStatusChanged(bool isExclusive);
    void errorOccurred(const QString &message);
    void initialized(bool success);
    void streamInfoUpdated(int sampleRate, int channels, int bitDepth, int bitrate, int latencyMs, const QString &tool = QString());
    void embeddedLyricsFound(const QString &lrcContent);
    void trackEnded();

public slots:
    void onEosDetected();

private slots:
    void onTick();

private:
    bool initAudioOutput();
    bool initBassAndWasapi() { return initAudioOutput(); }
    void freeCurrentStream();
    void recalculateEqFilters();

    static void CALLBACK equalizerDspCallback(HDSP handle, DWORD channel, void *buffer, DWORD length, void *user);

    HSTREAM m_decodeStream = 0;
    HPLUGIN m_flacPlugin = 0;
#if defined(_WIN32)
    int m_wasapiDevice = -1;
#endif
    bool m_isExclusive = false;
    bool m_initialized = false;
    float m_volume = 1.0f;
    QTimer *m_tickTimer = nullptr;
    qint64 m_currentDurationMs = 0;
    QString m_currentPath;
    bool m_eosTriggered = false;

    // Equalizer state with strict mutex protection
    mutable std::mutex m_eqMutex;
    bool m_eqEnabled = false;
    float m_eqPreampDb = 0.0f;
    float m_eqPreampLinear = 1.0f;
    float m_eqBands[10] = {0.0f};
    EqFilterCoeffs m_eqCoeffs[10];
    EqFilterState m_filterState[10];
    HDSP m_eqDsp = 0;
    float m_currentSampleRate = 44100.0f;
    int m_currentChannels = 2;
};
