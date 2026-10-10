#include "AudioEngine.h"
#include "AudioEngineWorker.h"
#include "../library/LibraryManager.h"
#include "../model/LyricModel.h"

#include <QDebug>
#include <QFileInfo>
#include <QDir>
#include <QRandomGenerator>
#include <QSettings>
#include <cmath>

// ============================================================================
// AudioEngineWorker Implementation (Native Worker Thread)
// ============================================================================

AudioEngineWorker::AudioEngineWorker(QObject *parent)
    : QObject(parent)
{
}

AudioEngineWorker::~AudioEngineWorker()
{
    shutdown();
}

void AudioEngineWorker::initialize()
{
    qDebug() << "[AudioEngineWorker] Initializing on native thread:" << QThread::currentThread();
    bool ok = initAudioOutput();
    m_initialized = ok;

    m_tickTimer = new QTimer(this);
    m_tickTimer->setInterval(100);
    connect(m_tickTimer, &QTimer::timeout, this, &AudioEngineWorker::onTick);

    emit initialized(ok);
}

bool AudioEngineWorker::initAudioOutput()
{
    // Initialize standard BASS output (-1 = default device)
    BASS_SetConfig(BASS_CONFIG_DEV_DEFAULT, 1);
    if (!BASS_Init(-1, 44100, 0, nullptr, nullptr)) {
        int err = BASS_ErrorGetCode();
        if (err != BASS_ERROR_ALREADY) {
            emit errorOccurred(QString("BASS_Init failed with error code: %1").arg(err));
            return false;
        }
    }

    // Load FLAC plugin
#if defined(_WIN32)
    m_flacPlugin = BASS_PluginLoad("bassflac.dll", 0);
#elif defined(__APPLE__)
    m_flacPlugin = BASS_PluginLoad("libbassflac.dylib", 0);
#else
    m_flacPlugin = BASS_PluginLoad("libbassflac.so", 0);
#endif
    if (!m_flacPlugin) {
        qWarning() << "[AudioEngineWorker] BASS_PluginLoad flac plugin returned 0. Built-in formats only.";
    }

#if defined(_WIN32)
    // Since we use standard BASS output, it handles shared mode via WASAPI natively on Windows
    qDebug() << "[AudioEngineWorker] BASS initialized successfully in Windows WASAPI Shared Mode.";
#else
    qDebug() << "[AudioEngineWorker] BASS initialized successfully with platform audio output.";
#endif

    // Detect actual default audio output device
    BASS_DEVICEINFO devInfo;
    QString selectedName;
    for (int d = 1; BASS_GetDeviceInfo(d, &devInfo); ++d) {
        if ((devInfo.flags & BASS_DEVICE_DEFAULT) && (devInfo.flags & BASS_DEVICE_ENABLED)) {
            QString name = QString::fromUtf8(devInfo.name);
            if (name != "Default") {
                selectedName = name;
                break;
            }
        }
    }
    if (selectedName.isEmpty()) {
        for (int d = 1; BASS_GetDeviceInfo(d, &devInfo); ++d) {
            if ((devInfo.flags & BASS_DEVICE_DEFAULTCOM) && (devInfo.flags & BASS_DEVICE_ENABLED)) {
                selectedName = QString::fromUtf8(devInfo.name);
                break;
            }
        }
    }
    if (!selectedName.isEmpty()) {
        qDebug() << "[AudioEngineWorker] Default Audio Device detected:" << selectedName;
        emit deviceDetected(selectedName);
    }
    
    emit exclusiveStatusChanged(m_isExclusive);
    return true;
}

void AudioEngineWorker::shutdown()
{
    stop();

    if (m_tickTimer) {
        m_tickTimer->stop();
    }

    if (m_flacPlugin) {
        BASS_PluginFree(m_flacPlugin);
        m_flacPlugin = 0;
    }

    BASS_Free();
    m_initialized = false;
    qDebug() << "[AudioEngineWorker] Audio engine shutdown complete.";
}

void AudioEngineWorker::freeCurrentStream()
{
    if (m_decodeStream) {
        if (m_eqDsp) {
            BASS_ChannelRemoveDSP(m_decodeStream, m_eqDsp);
            m_eqDsp = 0;
        }
        BASS_StreamFree(m_decodeStream);
        m_decodeStream = 0;
    }
}

void AudioEngineWorker::play(const QString &filePath)
{
    if (filePath.isEmpty()) return;

    m_currentPath = filePath;

    // Cleanly stop and free any existing audio session
    freeCurrentStream();

    // Create decode stream
    DWORD flags = BASS_SAMPLE_FLOAT;
#if defined(Q_OS_WIN)
    m_decodeStream = BASS_StreamCreateFile(FALSE, filePath.toStdWString().c_str(), 0, 0, flags | BASS_UNICODE);
#else
    m_decodeStream = BASS_StreamCreateFile(FALSE, filePath.toUtf8().constData(), 0, 0, flags);
#endif

    if (!m_decodeStream) {
        int err = BASS_ErrorGetCode();
        QString msg = QString("Failed to open audio file: %1 (BASS Error %2)").arg(filePath).arg(err);
        qWarning() << "[AudioEngineWorker]" << msg;
        emit errorOccurred(msg);
        emit stateChanged(0);
        return;
    }

    // Get channel properties
    BASS_CHANNELINFO chInfo;
    BASS_ChannelGetInfo(m_decodeStream, &chInfo);

    // Get duration
    QWORD lenBytes = BASS_ChannelGetLength(m_decodeStream, BASS_POS_BYTE);
    double lenSeconds = BASS_ChannelBytes2Seconds(m_decodeStream, lenBytes);
    m_currentDurationMs = static_cast<qint64>(std::max(0.0, lenSeconds * 1000.0));
    emit durationUpdated(m_currentDurationMs);

    int sampleRate = chInfo.freq;
    int channels = chInfo.chans;
    int bitDepth = chInfo.origres > 0 ? chInfo.origres : ((chInfo.flags & BASS_SAMPLE_FLOAT) ? 24 : 16);
    qint64 fileSize = QFileInfo(filePath).size();
    int bitrate = (lenSeconds > 0) ? static_cast<int>((fileSize * 8) / (lenSeconds * 1000.0)) : 0;

    QString encoderTool;

    // Check stream Vorbis and APE tags for embedded lyrics and encoder tool
    const char *oggTags = (const char *)BASS_ChannelGetTags(m_decodeStream, BASS_TAG_OGG);
    if (oggTags) {
        while (*oggTags) {
            QString comment = QString::fromUtf8(oggTags);
            int eq = comment.indexOf('=');
            if (eq > 0) {
                QString key = comment.left(eq).trimmed().toUpper();
                if (key == "LYRICS" || key == "UNSYNCEDLYRICS" || key == "SYNCED LYRICS" || key == "LYRIC" || key == "UNSYNCED LYRICS") {
                    QString val = comment.mid(eq + 1).trimmed();
                    if (!val.isEmpty()) {
                        emit embeddedLyricsFound(val);
                    }
                } else if (encoderTool.isEmpty() && (key == "ENCODER" || key == "TOOL" || key == "ENCODEDBY" || key == "ENCODER_TOOL" || key == "WRITING APP")) {
                    encoderTool = comment.mid(eq + 1).trimmed();
                }
            }
            oggTags += strlen(oggTags) + 1;
        }
    }

    const char *apeTags = (const char *)BASS_ChannelGetTags(m_decodeStream, BASS_TAG_APE);
    if (apeTags) {
        while (*apeTags) {
            QString comment = QString::fromUtf8(apeTags);
            int eq = comment.indexOf('=');
            if (eq > 0) {
                QString key = comment.left(eq).trimmed().toUpper();
                if (key == "LYRICS" || key == "UNSYNCEDLYRICS" || key == "SYNCED LYRICS" || key == "LYRIC") {
                    QString val = comment.mid(eq + 1).trimmed();
                    if (!val.isEmpty()) {
                        emit embeddedLyricsFound(val);
                    }
                } else if (encoderTool.isEmpty() && (key == "ENCODER" || key == "TOOL" || key == "ENCODEDBY")) {
                    encoderTool = comment.mid(eq + 1).trimmed();
                }
            }
            apeTags += strlen(apeTags) + 1;
        }
    }

    // Apply stream volume
    BASS_ChannelSetAttribute(m_decodeStream, BASS_ATTRIB_VOL, m_volume);

    m_eosTriggered = false;

    // Set BASS_SYNC_END callback for immediate EOS notification
    BASS_ChannelSetSync(m_decodeStream, BASS_SYNC_END | BASS_SYNC_ONETIME, 0, [](HSYNC, DWORD, DWORD, void *user) {
        auto *worker = static_cast<AudioEngineWorker*>(user);
        QMetaObject::invokeMethod(worker, "onEosDetected", Qt::QueuedConnection);
    }, this);

    // Initialize and attach Equalizer Biquad DSP
    m_currentSampleRate = static_cast<float>(sampleRate);
    m_currentChannels = channels;
    recalculateEqFilters();
    m_eqDsp = BASS_ChannelSetDSP(m_decodeStream, equalizerDspCallback, this, 0);

    // Play using standard BASS channel
    if (!BASS_ChannelPlay(m_decodeStream, FALSE)) {
        int err = BASS_ErrorGetCode();
        QString msg = QString("BASS_ChannelPlay failed with error code: %1").arg(err);
        qWarning() << "[AudioEngineWorker]" << msg;
        emit errorOccurred(msg);
        freeCurrentStream();
        emit stateChanged(0);
        return;
    }

    // Query real device latency from BASS
    BASS_INFO info;
    int latencyMs = 0;
    if (BASS_GetInfo(&info)) {
        latencyMs = info.latency;
    }
    emit streamInfoUpdated(sampleRate, channels, bitDepth, bitrate, latencyMs, encoderTool);

    // Refresh current output device name
    BASS_DEVICEINFO activeDevInfo;
    for (int d = 1; BASS_GetDeviceInfo(d, &activeDevInfo); ++d) {
        if ((activeDevInfo.flags & BASS_DEVICE_DEFAULT) && (activeDevInfo.flags & BASS_DEVICE_ENABLED)) {
            QString name = QString::fromUtf8(activeDevInfo.name);
            if (name != "Default") {
                emit deviceDetected(name);
                break;
            }
        }
    }

    if (m_tickTimer) {
        m_tickTimer->start();
    }
    emit stateChanged(1); // Playing
}

void AudioEngineWorker::onEosDetected()
{
    if (m_eosTriggered) return;
    m_eosTriggered = true;
    if (m_tickTimer) {
        m_tickTimer->stop();
    }
    emit trackEnded();
}

void AudioEngineWorker::pause()
{
    if (m_decodeStream) BASS_ChannelPause(m_decodeStream);
    if (m_tickTimer) {
        m_tickTimer->stop();
    }
    emit stateChanged(2); // Paused
}

void AudioEngineWorker::resume()
{
    if (m_decodeStream) {
        BASS_ChannelPlay(m_decodeStream, FALSE);
        if (m_tickTimer) {
            m_tickTimer->start();
        }
        emit stateChanged(1); // Playing
    }
}

void AudioEngineWorker::stop()
{
    if (m_tickTimer) {
        m_tickTimer->stop();
    }
    freeCurrentStream();
    emit stateChanged(0); // Stopped
}

void AudioEngineWorker::seek(qint64 positionMs)
{
    if (!m_decodeStream) return;

    if (positionMs < m_currentDurationMs) {
        m_eosTriggered = false;
    }

    double posSec = static_cast<double>(positionMs) / 1000.0;
    QWORD posBytes = BASS_ChannelSeconds2Bytes(m_decodeStream, posSec);
    BASS_ChannelSetPosition(m_decodeStream, posBytes, BASS_POS_BYTE);
    emit positionUpdated(positionMs);
}

void AudioEngineWorker::setVolume(float volume)
{
    m_volume = std::clamp(volume, 0.0f, 1.0f);
    if (m_decodeStream) {
        BASS_ChannelSetAttribute(m_decodeStream, BASS_ATTRIB_VOL, m_volume);
    }
}

void AudioEngineWorker::setExclusive(bool exclusive)
{
    m_isExclusive = exclusive;
    emit exclusiveStatusChanged(m_isExclusive);
}

void AudioEngineWorker::onTick()
{
    if (!m_decodeStream) return;

    QWORD posBytes = BASS_ChannelGetPosition(m_decodeStream, BASS_POS_BYTE);
    double posSec = BASS_ChannelBytes2Seconds(m_decodeStream, posBytes);
    qint64 posMs = static_cast<qint64>(std::max(0.0, posSec * 1000.0));
    emit positionUpdated(posMs);

    // Check if reached end of stream
    DWORD act = BASS_ChannelIsActive(m_decodeStream);
    if ((m_currentDurationMs > 0 && posMs >= m_currentDurationMs) || act == BASS_ACTIVE_STOPPED) {
        onEosDetected();
    }
}

void CALLBACK AudioEngineWorker::equalizerDspCallback(HDSP handle, DWORD channel, void *buffer, DWORD length, void *user)
{
    Q_UNUSED(handle);
    Q_UNUSED(channel);
    auto *worker = static_cast<AudioEngineWorker*>(user);
    if (!worker || !buffer || length == 0) return;
    worker->processEqDsp(static_cast<float*>(buffer), length / sizeof(float));
}

void AudioEngineWorker::processEqDsp(float *data, size_t sampleCount)
{
    if (!data || sampleCount == 0) return;

    EqFilterCoeffs activeCoeffs[10];
    float preamp;
    bool eqActive;
    int channels = m_currentChannels > 0 ? m_currentChannels : 2;

    {
        std::lock_guard<std::mutex> lock(m_eqMutex);
        eqActive = m_eqEnabled;
        preamp = m_eqPreampLinear;
        std::memcpy(activeCoeffs, m_eqCoeffs, sizeof(activeCoeffs));
    }

    if (!eqActive) return;

    for (size_t i = 0; i < sampleCount; ++i) {
        int ch = static_cast<int>(i % channels);
        int idx = (ch < 2) ? ch : 0;
        float s = data[i] * preamp;

        for (int b = 0; b < 10; ++b) {
            const EqFilterCoeffs &c = activeCoeffs[b];
            EqFilterState &st = m_filterState[b];
            float out = c.b0 * s + c.b1 * st.x1[idx] + c.b2 * st.x2[idx] - c.a1 * st.y1[idx] - c.a2 * st.y2[idx];

            // Anti-NaN / Infinity driver lockup protection
            if (std::isnan(out) || std::isinf(out)) {
                out = 0.0f;
                st.reset();
            }

            st.x2[idx] = st.x1[idx];
            st.x1[idx] = s;
            st.y2[idx] = st.y1[idx];
            st.y1[idx] = out;
            s = out;
        }
        data[i] = std::clamp(s, -1.0f, 1.0f);
    }
}

void AudioEngineWorker::recalculateEqFilters()
{
    static const float EQ_FREQS[10] = {
        31.25f, 62.5f, 125.0f, 250.0f, 500.0f, 1000.0f, 2000.0f, 4000.0f, 8000.0f, 16000.0f
    };

    float sr = (m_currentSampleRate > 0.0f) ? m_currentSampleRate : 44100.0f;
    EqFilterCoeffs newCoeffs[10];
    for (int i = 0; i < 10; ++i) {
        newCoeffs[i] = EqFilterCoeffs::calculate(sr, EQ_FREQS[i], m_eqBands[i]);
    }
    float newPreamp = std::pow(10.0f, std::clamp(m_eqPreampDb, -12.0f, 12.0f) / 20.0f);

    {
        std::lock_guard<std::mutex> lock(m_eqMutex);
        std::memcpy(m_eqCoeffs, newCoeffs, sizeof(newCoeffs));
        m_eqPreampLinear = newPreamp;
    }
}

void AudioEngineWorker::setEqEnabled(bool enabled)
{
    {
        std::lock_guard<std::mutex> lock(m_eqMutex);
        m_eqEnabled = enabled;
    }
    if (!enabled) {
        for (int i = 0; i < 10; ++i) {
            m_filterState[i].reset();
        }
    }
}

void AudioEngineWorker::setEqPreamp(float preampDb)
{
    float newPreamp = std::pow(10.0f, std::clamp(preampDb, -12.0f, 12.0f) / 20.0f);
    std::lock_guard<std::mutex> lock(m_eqMutex);
    m_eqPreampDb = preampDb;
    m_eqPreampLinear = newPreamp;
}

void AudioEngineWorker::setEqBands(const QList<float> &bands)
{
    for (int i = 0; i < 10 && i < bands.size(); ++i) {
        m_eqBands[i] = bands[i];
    }
    recalculateEqFilters();
}

void AudioEngineWorker::setEqBand(int index, float gainDb)
{
    if (index >= 0 && index < 10) {
        m_eqBands[index] = gainDb;
        static const float EQ_FREQS[10] = {
            31.25f, 62.5f, 125.0f, 250.0f, 500.0f, 1000.0f, 2000.0f, 4000.0f, 8000.0f, 16000.0f
        };
        float sr = (m_currentSampleRate > 0.0f) ? m_currentSampleRate : 44100.0f;
        EqFilterCoeffs newC = EqFilterCoeffs::calculate(sr, EQ_FREQS[index], gainDb);
        std::lock_guard<std::mutex> lock(m_eqMutex);
        m_eqCoeffs[index] = newC;
    }
}

// ============================================================================
// AudioEngine Singleton Facade Implementation (Main Thread)
// ============================================================================

AudioEngine *AudioEngine::s_instance = nullptr;

AudioEngine* AudioEngine::instance()
{
    if (!s_instance) {
        s_instance = new AudioEngine();
    }
    return s_instance;
}

AudioEngine::AudioEngine(QObject *parent)
    : QObject(parent)
{
    m_lyricsModel = new LyricModel(this);
    m_queueModel = new TrackModel(this);
    m_playedModel = new TrackModel(this);
    m_nextModel = new TrackModel(this);
    m_worker = new AudioEngineWorker();
    m_worker->moveToThread(&m_workerThread);

    // Connect lifecycle signals
    connect(&m_workerThread, &QThread::started, m_worker, &AudioEngineWorker::initialize);
    connect(&m_workerThread, &QThread::finished, m_worker, &QObject::deleteLater);

    // Connect control requests from facade to worker (Queued across threads)
    connect(this, &AudioEngine::requestPlay, m_worker, &AudioEngineWorker::play, Qt::QueuedConnection);
    connect(this, &AudioEngine::requestPause, m_worker, &AudioEngineWorker::pause, Qt::QueuedConnection);
    connect(this, &AudioEngine::requestResume, m_worker, &AudioEngineWorker::resume, Qt::QueuedConnection);
    connect(this, &AudioEngine::requestStop, m_worker, &AudioEngineWorker::stop, Qt::QueuedConnection);
    connect(this, &AudioEngine::requestSeek, m_worker, &AudioEngineWorker::seek, Qt::QueuedConnection);
    connect(this, &AudioEngine::requestSetVolume, m_worker, &AudioEngineWorker::setVolume, Qt::QueuedConnection);
    connect(this, &AudioEngine::requestSetExclusive, m_worker, &AudioEngineWorker::setExclusive, Qt::QueuedConnection);
    connect(this, &AudioEngine::requestShutdown, m_worker, &AudioEngineWorker::shutdown, Qt::BlockingQueuedConnection);

    // Connect embedded lyrics found in audio stream
    connect(m_worker, &AudioEngineWorker::embeddedLyricsFound, this, [this](const QString &lrc) {
        if (m_lyricsModel && !m_lyricsModel->hasLyrics()) {
            m_lyricsModel->loadLrcContent(lrc);
        }
    }, Qt::QueuedConnection);

    // Connect feedback signals from worker to facade
    connect(m_worker, &AudioEngineWorker::stateChanged, this, [this](int state) {
        auto newState = static_cast<PlaybackState>(state);
        if (m_playbackState != newState) {
            m_playbackState = newState;
            emit playbackStateChanged(m_playbackState);
        }
    }, Qt::QueuedConnection);

    connect(m_worker, &AudioEngineWorker::positionUpdated, this, [this](qint64 pos) {
        if (m_positionMs != pos) {
            m_positionMs = pos;
            emit positionChanged(m_positionMs);
        }
        if (m_lyricsModel) {
            m_lyricsModel->updatePosition(pos);
        }
    }, Qt::QueuedConnection);

    connect(m_worker, &AudioEngineWorker::durationUpdated, this, [this](qint64 dur) {
        if (m_durationMs != dur) {
            m_durationMs = dur;
            emit durationChanged(m_durationMs);
        }
    }, Qt::QueuedConnection);

    connect(m_worker, &AudioEngineWorker::deviceDetected, this, [this](const QString &name) {
        if (m_deviceName != name) {
            m_deviceName = name;
            emit deviceChanged(m_deviceName);
        }
    }, Qt::QueuedConnection);

    connect(m_worker, &AudioEngineWorker::exclusiveStatusChanged, this, [this](bool excl) {
        if (m_isExclusive != excl) {
            m_isExclusive = excl;
            emit exclusiveModeChanged(m_isExclusive);
        }
    }, Qt::QueuedConnection);

    connect(m_worker, &AudioEngineWorker::streamInfoUpdated, this, [this](int sampleRate, int channels, int bitDepth, int bitrate, int latencyMs, const QString &tool) {
        if (sampleRate > 0) m_currentSampleRate = sampleRate;
        if (channels > 0) m_currentChannels = channels;
        if (bitDepth > 0) m_currentBitDepth = bitDepth;
        if (bitrate > 0) m_currentBitrate = bitrate;
        if (latencyMs >= 0) m_currentLatencyMs = latencyMs;
        if (!tool.isEmpty()) {
            m_currentTool = tool;
        }
        emit currentMetadataChanged();
    }, Qt::QueuedConnection);

    connect(m_worker, &AudioEngineWorker::trackEnded, this, &AudioEngine::handleTrackEnded, Qt::QueuedConnection);

    connect(m_worker, &AudioEngineWorker::errorOccurred, this, &AudioEngine::errorOccurred, Qt::QueuedConnection);

    // Keep sub-queue models (playedModel & nextModel) always in sync whenever currentIndex changes
    connect(this, &AudioEngine::currentIndexChanged, this, [this](int) {
        updateSubQueueModels();
    });

    // Connect Equalizer signals
    connect(this, &AudioEngine::requestSetEqEnabled, m_worker, &AudioEngineWorker::setEqEnabled, Qt::QueuedConnection);
    connect(this, &AudioEngine::requestSetEqPreamp, m_worker, &AudioEngineWorker::setEqPreamp, Qt::QueuedConnection);
    connect(this, &AudioEngine::requestSetEqBands, m_worker, &AudioEngineWorker::setEqBands, Qt::QueuedConnection);
    connect(this, &AudioEngine::requestSetEqBand, m_worker, &AudioEngineWorker::setEqBand, Qt::QueuedConnection);

    // Initialize 10 EQ bands and load persisted settings
    m_eqBands.reserve(10);
    for (int i = 0; i < 10; ++i) {
        m_eqBands.append(0.0f);
    }
    loadEqSettings();

    // Start native worker thread with TimeCriticalPriority per AGENTS.md
    m_workerThread.start(QThread::TimeCriticalPriority);
}

AudioEngine::~AudioEngine()
{
    if (m_workerThread.isRunning()) {
        emit requestShutdown();
        m_workerThread.quit();
        m_workerThread.wait();
    }
}

void AudioEngine::play(const QString &filePath)
{
    if (filePath.isEmpty()) return;

    m_currentTrack = filePath;
    emit trackChanged(m_currentTrack);

    // Sync playlist and current index
    int idx = m_playlist.indexOf(filePath);
    if (idx >= 0) {
        bool changed = (m_currentIndex != idx);
        m_currentIndex = idx;
        if (changed) {
            emit currentIndexChanged(m_currentIndex);
        }
        updateSubQueueModels();
    } else {
        m_playlist.append(filePath);
        m_currentIndex = m_playlist.size() - 1;
        emit playlistChanged();
        emit currentIndexChanged(m_currentIndex);
        if (m_queueModel) {
            TrackItem it = LibraryManager::instance()->getTrackMetadata(filePath);
            m_queueModel->addTrack(it);
            emit queueChanged();
        }
        updateSubQueueModels();
    }

    TrackItem item = LibraryManager::instance()->getTrackMetadata(filePath);
    m_currentTitle = item.title.trimmed().isEmpty() ? QFileInfo(filePath).completeBaseName() : item.title;
    m_currentArtist = item.artist.trimmed().isEmpty() ? "Unknown Artist" : item.artist;
    m_currentAlbum = item.album.trimmed().isEmpty() ? "Unknown Album" : item.album;
    m_currentCoverUrl = item.coverUrl;
    m_hasCover = item.hasCover && !item.coverUrl.isEmpty();
    m_currentFormat = item.format.isEmpty() ? QFileInfo(filePath).suffix().toUpper() : item.format;
    QString fmtUpper = m_currentFormat.toUpper();
    if (fmtUpper == "FLAC" || fmtUpper == "ALAC" || fmtUpper == "WAV" || fmtUpper == "APE" || fmtUpper == "AIFF") {
        m_currentEncoding = "Lossless";
    } else if (fmtUpper == "MP3" || fmtUpper == "AAC" || fmtUpper == "OGG" || fmtUpper == "OPUS" || fmtUpper == "M4A") {
        m_currentEncoding = "Lossy";
    } else {
        m_currentEncoding = "Lossless";
    }
    emit currentMetadataChanged();

    if (m_lyricsModel) {
        m_lyricsModel->loadLyrics(filePath);
    }

    emit requestPlay(filePath);
}

void AudioEngine::pause()
{
    emit requestPause();
}

void AudioEngine::resume()
{
    if (m_durationMs > 0 && m_positionMs >= m_durationMs) {
        seek(0);
        if (!m_currentTrack.isEmpty()) {
            play(m_currentTrack);
            return;
        }
    } else if (m_playbackState == PlaybackState::Stopped && !m_currentTrack.isEmpty()) {
        play(m_currentTrack);
        return;
    }
    emit requestResume();
}

void AudioEngine::stop()
{
    if (m_lyricsModel) {
        m_lyricsModel->updatePosition(0);
    }
    // Technical metadata (sample rate, channels, bitrate, etc.) remains cached for current track
    emit requestStop();
}

void AudioEngine::seek(qint64 positionMs)
{
    if (m_lyricsModel) {
        m_lyricsModel->updatePosition(positionMs);
    }
    emit requestSeek(positionMs);
}

void AudioEngine::setVolume(float volume)
{
    if (m_volume != volume) {
        m_volume = volume;
        emit volumeChanged(m_volume);
        emit requestSetVolume(m_volume);
    }
}

void AudioEngine::setExclusiveMode(bool exclusive)
{
    if (m_isExclusive != exclusive) {
        m_isExclusive = exclusive;
        emit exclusiveModeChanged(m_isExclusive);
        emit requestSetExclusive(m_isExclusive);
    }
}

void AudioEngine::setPlayMode(AudioEngine::PlayMode mode)
{
    if (m_playMode != mode) {
        m_playMode = mode;
        emit playModeChanged(m_playMode);
    }
}

bool AudioEngine::hasMoreTracksInSequential() const
{
    if (m_playlist.isEmpty()) return false;
    return (m_currentIndex >= 0 && m_currentIndex + 1 < m_playlist.size());
}

void AudioEngine::handleTrackEnded()
{
    emit trackEnded();
    qDebug() << "[AudioEngine] Track finished playing, current playMode:" << static_cast<int>(m_playMode);
    switch (m_playMode) {
    case PlayMode::RepeatOne:
        seek(0);
        play(m_currentTrack);
        break;
    case PlayMode::Shuffle:
    case PlayMode::RepeatAll:
        playNext();
        break;
    case PlayMode::Sequential:
        if (hasMoreTracksInSequential()) {
            playNext();
        } else {
            // Reached the end of playlist in sequential mode
            m_positionMs = m_durationMs;
            emit positionChanged(m_positionMs);
            m_playbackState = PlaybackState::Stopped;
            emit playbackStateChanged(m_playbackState);
            emit requestStop();
        }
        break;
    }
}

void AudioEngine::playNext()
{
    if (m_playlist.isEmpty()) {
        if (!m_currentTrack.isEmpty()) {
            seek(0);
            play(m_currentTrack);
        }
        return;
    }

    if (m_playlist.size() == 1) {
        if (m_playMode == PlayMode::Sequential) {
            m_positionMs = m_durationMs;
            emit positionChanged(m_positionMs);
            m_playbackState = PlaybackState::Stopped;
            emit playbackStateChanged(m_playbackState);
            emit requestStop();
        } else {
            seek(0);
            play(m_currentTrack);
        }
        return;
    }

    int nextIndex = 0;
    if (m_playMode == PlayMode::Shuffle) {
        if (m_playlist.size() > 1) {
            do {
                nextIndex = QRandomGenerator::global()->bounded(m_playlist.size());
            } while (nextIndex == m_currentIndex);
        } else {
            nextIndex = 0;
        }
    } else if (m_playMode == PlayMode::RepeatOne) {
        nextIndex = (m_currentIndex >= 0 && m_currentIndex < m_playlist.size()) ? m_currentIndex : 0;
    } else if (m_playMode == PlayMode::Sequential) {
        if (m_currentIndex + 1 < m_playlist.size()) {
            nextIndex = m_currentIndex + 1;
        } else {
            m_positionMs = m_durationMs;
            emit positionChanged(m_positionMs);
            m_playbackState = PlaybackState::Stopped;
            emit playbackStateChanged(m_playbackState);
            emit requestStop();
            return;
        }
    } else {
        nextIndex = (m_currentIndex + 1) % m_playlist.size();
    }

    m_currentIndex = nextIndex;
    emit currentIndexChanged(m_currentIndex);
    updateSubQueueModels();
    play(m_playlist.at(m_currentIndex));
}

void AudioEngine::playPrevious()
{
    // If playing for more than 3 seconds, seek back to the beginning
    if (m_positionMs > 3000) {
        seek(0);
        return;
    }

    if (m_playlist.isEmpty()) {
        if (!m_currentTrack.isEmpty()) {
            seek(0);
        }
        return;
    }

    if (m_playlist.size() == 1) {
        seek(0);
        play(m_currentTrack);
        return;
    }

    int prevIndex = 0;
    if (m_playMode == PlayMode::Shuffle) {
        if (m_playlist.size() > 1) {
            do {
                prevIndex = QRandomGenerator::global()->bounded(m_playlist.size());
            } while (prevIndex == m_currentIndex);
        } else {
            prevIndex = 0;
        }
    } else {
        prevIndex = (m_currentIndex - 1 + m_playlist.size()) % m_playlist.size();
    }

    m_currentIndex = prevIndex;
    emit currentIndexChanged(m_currentIndex);
    updateSubQueueModels();
    play(m_playlist.at(m_currentIndex));
}

void AudioEngine::setPlaylist(const QStringList &tracks, int startIndex)
{
    m_playlist = tracks;
    m_currentIndex = (startIndex >= 0 && startIndex < tracks.size()) ? startIndex : (tracks.isEmpty() ? -1 : 0);

    QList<TrackItem> items;
    items.reserve(tracks.size());
    for (const QString &path : tracks) {
        items.append(LibraryManager::instance()->getTrackMetadata(path));
    }
    m_queueModel->setTracks(items);
    updateSubQueueModels();

    emit playlistChanged();
    emit currentIndexChanged(m_currentIndex);
    emit queueChanged();
}

void AudioEngine::addToPlaylist(const QString &filePath)
{
    if (filePath.isEmpty()) return;
    if (!m_playlist.contains(filePath)) {
        m_playlist.append(filePath);
        TrackItem meta = LibraryManager::instance()->getTrackMetadata(filePath);
        m_queueModel->addTrack(meta);
        updateSubQueueModels();
        emit playlistChanged();
        emit queueChanged();
    }
}

void AudioEngine::insertTracksNext(const QStringList &tracks)
{
    if (tracks.isEmpty()) return;
    if (m_playlist.isEmpty()) {
        setPlaylist(tracks, 0);
        return;
    }
    int insertPos = (m_currentIndex >= 0 && m_currentIndex < m_playlist.size())
                    ? (m_currentIndex + 1)
                    : m_playlist.size();
    for (int i = 0; i < tracks.size(); ++i) {
        m_playlist.insert(insertPos + i, tracks[i]);
    }

    QList<TrackItem> items;
    items.reserve(m_playlist.size());
    for (const QString &p : m_playlist) {
        items.append(LibraryManager::instance()->getTrackMetadata(p));
    }
    m_queueModel->setTracks(items);
    updateSubQueueModels();
    emit playlistChanged();
    emit queueChanged();
}

void AudioEngine::clearQueue(bool keepCurrent)
{
    if (keepCurrent && !m_currentTrack.isEmpty()) {
        QString current = m_currentTrack;
        m_playlist.clear();
        m_playlist.append(current);
        m_currentIndex = 0;

        TrackItem currentItem = LibraryManager::instance()->getTrackMetadata(current);
        m_queueModel->setTracks({ currentItem });
    } else {
        m_playlist.clear();
        m_queueModel->clear();
        m_currentIndex = -1;
        m_currentTrack.clear();
        stop();
    }

    updateSubQueueModels();
    emit playlistChanged();
    emit currentIndexChanged(m_currentIndex);
    emit queueChanged();
}

void AudioEngine::removeFromQueue(int index)
{
    if (index < 0 || index >= m_playlist.size()) return;

    bool isCurrent = (index == m_currentIndex);
    m_playlist.removeAt(index);
    m_queueModel->removeTrack(index);

    if (m_playlist.isEmpty()) {
        m_currentIndex = -1;
        updateSubQueueModels();
        emit currentIndexChanged(-1);
        emit playlistChanged();
        emit queueChanged();
        stop();
        return;
    }

    if (isCurrent) {
        if (m_currentIndex >= m_playlist.size()) {
            m_currentIndex = 0;
        }
        updateSubQueueModels();
        emit currentIndexChanged(m_currentIndex);
        emit playlistChanged();
        emit queueChanged();
        play(m_playlist.at(m_currentIndex));
    } else {
        if (m_currentIndex > index) {
            m_currentIndex--;
        }
        updateSubQueueModels();
        emit currentIndexChanged(m_currentIndex);
        emit playlistChanged();
        emit queueChanged();
    }
}

void AudioEngine::moveQueueItem(int from, int to)
{
    if (from < 0 || from >= m_playlist.size() || to < 0 || to >= m_playlist.size() || from == to) return;
    m_playlist.move(from, to);
    m_queueModel->moveTrack(from, to);

    if (m_currentIndex == from) {
        m_currentIndex = to;
    } else if (from < m_currentIndex && to >= m_currentIndex) {
        m_currentIndex--;
    } else if (from > m_currentIndex && to <= m_currentIndex) {
        m_currentIndex++;
    }

    updateSubQueueModels();
    emit playlistChanged();
    emit currentIndexChanged(m_currentIndex);
    emit queueChanged();
}

void AudioEngine::shuffleQueue()
{
    if (m_playlist.size() <= 1) return;

    QString currentPath;
    if (m_currentIndex >= 0 && m_currentIndex < m_playlist.size()) {
        currentPath = m_playlist.at(m_currentIndex);
    }

    QList<TrackItem> items = m_queueModel->tracks();
    for (int i = m_playlist.size() - 1; i > 0; --i) {
        int j = QRandomGenerator::global()->bounded(i + 1);
        m_playlist.swapItemsAt(i, j);
        items.swapItemsAt(i, j);
    }
    m_queueModel->setTracks(items);

    if (!currentPath.isEmpty()) {
        m_currentIndex = m_playlist.indexOf(currentPath);
    }
    updateSubQueueModels();
    emit playlistChanged();
    emit currentIndexChanged(m_currentIndex);
    emit queueChanged();
}

void AudioEngine::playQueueIndex(int index)
{
    if (index < 0 || index >= m_playlist.size()) return;
    m_currentIndex = index;
    emit currentIndexChanged(m_currentIndex);
    updateSubQueueModels();
    play(m_playlist.at(m_currentIndex));
}

void AudioEngine::updateSubQueueModels()
{
    if (!m_queueModel || !m_playedModel || !m_nextModel) return;
    const QList<TrackItem> &all = m_queueModel->tracks();
    int cur = m_currentIndex;

    QList<TrackItem> played;
    QList<TrackItem> nexts;

    if (cur > 0 && cur <= all.size()) {
        played = all.mid(0, cur);
    }
    if (cur >= 0 && cur + 1 < all.size()) {
        nexts = all.mid(cur + 1);
    } else if (cur < 0) {
        nexts = all;
    }

    m_playedModel->setTracks(played);
    m_nextModel->setTracks(nexts);
}

// ============================================================================
// Equalizer Facade Implementation
// ============================================================================

static const QMap<QString, QList<float>> S_EQ_PRESETS = {
    { QStringLiteral("Flat"),       {0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f} },
    { QStringLiteral("Rock"),       {4.5f, 3.0f, 1.5f, 0.0f, -1.0f, -0.5f, 1.0f, 2.5f, 3.5f, 4.0f} },
    { QStringLiteral("Pop"),        {-1.5f, -0.5f, 1.0f, 3.0f, 4.5f, 3.5f, 1.5f, 0.5f, -0.5f, -1.0f} },
    { QStringLiteral("Classical"),  {4.0f, 3.0f, 2.5f, 2.0f, -1.0f, -1.0f, 0.0f, 2.0f, 3.0f, 3.5f} },
    { QStringLiteral("Bass Boost"), {6.0f, 5.0f, 4.0f, 2.5f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f} },
    { QStringLiteral("Vocal"),      {-2.0f, -1.5f, -1.0f, 1.5f, 4.0f, 4.5f, 3.0f, 1.5f, 0.0f, -1.0f} },
    { QStringLiteral("Electronic"), {4.5f, 4.0f, 1.0f, 0.0f, -2.0f, 2.0f, 1.0f, 2.0f, 4.0f, 4.5f} },
    { QStringLiteral("Jazz"),       {3.5f, 2.5f, 1.0f, 1.5f, -1.5f, -1.5f, 0.0f, 1.5f, 2.5f, 3.0f} }
};

QStringList AudioEngine::eqPresetNames() const
{
    return { QStringLiteral("Flat"), QStringLiteral("Rock"), QStringLiteral("Pop"),
             QStringLiteral("Classical"), QStringLiteral("Bass Boost"), QStringLiteral("Vocal"),
             QStringLiteral("Electronic"), QStringLiteral("Jazz") };
}

void AudioEngine::setEqEnabled(bool enabled)
{
    if (m_eqEnabled == enabled) return;
    m_eqEnabled = enabled;
    emit eqEnabledChanged(m_eqEnabled);
    emit requestSetEqEnabled(m_eqEnabled);
    saveEqSettings();
}

void AudioEngine::setEqPreamp(float preampDb)
{
    float val = std::clamp(preampDb, -12.0f, 12.0f);
    if (std::abs(m_eqPreamp - val) < 0.01f) return;
    m_eqPreamp = val;
    emit eqPreampChanged(m_eqPreamp);
    emit requestSetEqPreamp(m_eqPreamp);
    saveEqSettings();
}

void AudioEngine::setEqBand(int index, float gainDb)
{
    if (index < 0 || index >= 10 || index >= m_eqBands.size()) return;
    float val = std::clamp(gainDb, -12.0f, 12.0f);
    if (std::abs(m_eqBands[index] - val) < 0.01f) return;

    m_eqBands[index] = val;
    emit eqBandsChanged();
    emit requestSetEqBand(index, val);

    // Check if current band gains still match active preset
    if (m_eqPreset != QStringLiteral("Custom")) {
        auto it = S_EQ_PRESETS.find(m_eqPreset);
        if (it != S_EQ_PRESETS.end()) {
            bool matches = true;
            for (int i = 0; i < 10; ++i) {
                if (std::abs(m_eqBands[i] - it.value()[i]) >= 0.05f) {
                    matches = false;
                    break;
                }
            }
            if (!matches) {
                m_eqPreset = QStringLiteral("Custom");
                emit eqPresetChanged(m_eqPreset);
            }
        }
    }
    saveEqSettings();
}

void AudioEngine::applyEqPreset(const QString &presetName)
{
    auto it = S_EQ_PRESETS.find(presetName);
    if (it == S_EQ_PRESETS.end()) return;

    m_eqPreset = presetName;
    const auto &presetValues = it.value();
    for (int i = 0; i < 10 && i < presetValues.size(); ++i) {
        m_eqBands[i] = presetValues[i];
    }

    emit eqPresetChanged(m_eqPreset);
    emit eqBandsChanged();
    emit requestSetEqBands(m_eqBands);
    saveEqSettings();
}

void AudioEngine::resetEq()
{
    // Reset gains and preamp to Flat; DO NOT disable or change m_eqEnabled!
    m_eqPreamp = 0.0f;
    m_eqPreset = QStringLiteral("Flat");
    for (int i = 0; i < 10; ++i) {
        m_eqBands[i] = 0.0f;
    }

    emit eqPreampChanged(m_eqPreamp);
    emit eqPresetChanged(m_eqPreset);
    emit eqBandsChanged();

    emit requestSetEqPreamp(0.0f);
    emit requestSetEqBands(m_eqBands);

    saveEqSettings();
}

void AudioEngine::loadEqSettings()
{
    QSettings settings("rhxPlayer", "0rhxPlayer");
    settings.beginGroup("Equalizer");
    m_eqEnabled = settings.value("enabled", false).toBool();
    m_eqPreamp = settings.value("preamp", 0.0f).toFloat();
    m_eqPreset = settings.value("preset", QStringLiteral("Flat")).toString();

    QVariant bandListVar = settings.value("bands");
    if (bandListVar.isValid()) {
        QList<QVariant> list = bandListVar.toList();
        for (int i = 0; i < 10 && i < list.size(); ++i) {
            m_eqBands[i] = list[i].toFloat();
        }
    } else {
        auto it = S_EQ_PRESETS.find(m_eqPreset);
        if (it != S_EQ_PRESETS.end()) {
            for (int i = 0; i < 10; ++i) {
                m_eqBands[i] = it.value()[i];
            }
        }
    }
    settings.endGroup();

    emit requestSetEqEnabled(m_eqEnabled);
    emit requestSetEqPreamp(m_eqPreamp);
    emit requestSetEqBands(m_eqBands);
}

void AudioEngine::saveEqSettings()
{
    QSettings settings("rhxPlayer", "0rhxPlayer");
    settings.beginGroup("Equalizer");
    settings.setValue("enabled", m_eqEnabled);
    settings.setValue("preamp", m_eqPreamp);
    settings.setValue("preset", m_eqPreset);

    QList<QVariant> list;
    list.reserve(10);
    for (int i = 0; i < 10; ++i) {
        list.append(m_eqBands[i]);
    }
    settings.setValue("bands", list);
    settings.endGroup();
}

