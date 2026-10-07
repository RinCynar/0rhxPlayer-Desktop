#pragma once

#include <QObject>
#include <QThread>
#include <QString>

#include "../model/LyricModel.h"
#include "../model/TrackModel.h"

class AudioEngineWorker;

class AudioEngine : public QObject
{
    Q_OBJECT
    Q_PROPERTY(PlaybackState playbackState READ playbackState NOTIFY playbackStateChanged)
    Q_PROPERTY(qint64 positionMs READ positionMs NOTIFY positionChanged)
    Q_PROPERTY(qint64 durationMs READ durationMs NOTIFY durationChanged)
    Q_PROPERTY(float volume READ volume WRITE setVolume NOTIFY volumeChanged)
    Q_PROPERTY(bool isExclusive READ isExclusive WRITE setExclusiveMode NOTIFY exclusiveModeChanged)
    Q_PROPERTY(QString deviceName READ deviceName NOTIFY deviceChanged)
    Q_PROPERTY(QString currentTrack READ currentTrack NOTIFY trackChanged)
    Q_PROPERTY(QString currentTitle READ currentTitle NOTIFY currentMetadataChanged)
    Q_PROPERTY(QString currentArtist READ currentArtist NOTIFY currentMetadataChanged)
    Q_PROPERTY(QString currentAlbum READ currentAlbum NOTIFY currentMetadataChanged)
    Q_PROPERTY(QString currentCoverUrl READ currentCoverUrl NOTIFY currentMetadataChanged)
    Q_PROPERTY(bool hasCover READ hasCover NOTIFY currentMetadataChanged)
    Q_PROPERTY(QString currentFormat READ currentFormat NOTIFY currentMetadataChanged)
    Q_PROPERTY(int currentBitrate READ currentBitrate NOTIFY currentMetadataChanged)
    Q_PROPERTY(int currentSampleRate READ currentSampleRate NOTIFY currentMetadataChanged)
    Q_PROPERTY(int currentChannels READ currentChannels NOTIFY currentMetadataChanged)
    Q_PROPERTY(int currentBitDepth READ currentBitDepth NOTIFY currentMetadataChanged)
    Q_PROPERTY(int currentLatencyMs READ currentLatencyMs NOTIFY currentMetadataChanged)
    Q_PROPERTY(QString currentEncoding READ currentEncoding NOTIFY currentMetadataChanged)
    Q_PROPERTY(QString currentTool READ currentTool NOTIFY currentMetadataChanged)
    Q_PROPERTY(LyricModel* lyrics READ lyrics CONSTANT)
    Q_PROPERTY(TrackModel* queueModel READ queueModel CONSTANT)
    Q_PROPERTY(TrackModel* playedModel READ playedModel CONSTANT)
    Q_PROPERTY(TrackModel* nextModel READ nextModel CONSTANT)
    Q_PROPERTY(PlayMode playMode READ playMode WRITE setPlayMode NOTIFY playModeChanged)
    Q_PROPERTY(QStringList playlist READ playlist NOTIFY playlistChanged)
    Q_PROPERTY(int currentIndex READ currentIndex NOTIFY currentIndexChanged)
    Q_PROPERTY(bool eqEnabled READ eqEnabled WRITE setEqEnabled NOTIFY eqEnabledChanged)
    Q_PROPERTY(float eqPreamp READ eqPreamp WRITE setEqPreamp NOTIFY eqPreampChanged)
    Q_PROPERTY(QList<float> eqBands READ eqBands NOTIFY eqBandsChanged)
    Q_PROPERTY(QString eqPreset READ eqPreset WRITE applyEqPreset NOTIFY eqPresetChanged)
    Q_PROPERTY(QStringList eqPresetNames READ eqPresetNames CONSTANT)

public:
    enum class PlaybackState {
        Stopped = 0,
        Playing = 1,
        Paused = 2
    };
    Q_ENUM(PlaybackState)

    enum class PlayMode {
        RepeatAll = 0,
        RepeatOne = 1,
        Shuffle = 2,
        Sequential = 3
    };
    Q_ENUM(PlayMode)

    static AudioEngine* instance();

    PlaybackState playbackState() const { return m_playbackState; }
    qint64 positionMs() const { return m_positionMs; }
    qint64 durationMs() const { return m_durationMs; }
    float volume() const { return m_volume; }
    bool isExclusive() const { return m_isExclusive; }
    QString deviceName() const { return m_deviceName; }
    QString currentTrack() const { return m_currentTrack; }
    QString currentTitle() const { return m_currentTitle; }
    QString currentArtist() const { return m_currentArtist; }
    QString currentAlbum() const { return m_currentAlbum; }
    QString currentCoverUrl() const { return m_currentCoverUrl; }
    bool hasCover() const { return m_hasCover; }
    QString currentFormat() const { return m_currentFormat; }
    int currentBitrate() const { return m_currentBitrate; }
    int currentSampleRate() const { return m_currentSampleRate; }
    int currentChannels() const { return m_currentChannels; }
    int currentBitDepth() const { return m_currentBitDepth; }
    int currentLatencyMs() const { return m_currentLatencyMs; }
    QString currentEncoding() const { return m_currentEncoding; }
    QString currentTool() const { return m_currentTool; }
    LyricModel* lyrics() const { return m_lyricsModel; }
    TrackModel* queueModel() const { return m_queueModel; }
    TrackModel* playedModel() const { return m_playedModel; }
    TrackModel* nextModel() const { return m_nextModel; }
    PlayMode playMode() const { return m_playMode; }
    QStringList playlist() const { return m_playlist; }
    int currentIndex() const { return m_currentIndex; }
    bool eqEnabled() const { return m_eqEnabled; }
    float eqPreamp() const { return m_eqPreamp; }
    QList<float> eqBands() const { return m_eqBands; }
    QString eqPreset() const { return m_eqPreset; }
    QStringList eqPresetNames() const;

public slots:
    void play(const QString &filePath);
    void pause();
    void resume();
    void stop();
    void seek(qint64 positionMs);
    void setVolume(float volume);
    void setExclusiveMode(bool exclusive);
    void setPlayMode(AudioEngine::PlayMode mode);
    void playNext();
    void playPrevious();
    void setPlaylist(const QStringList &tracks, int startIndex = 0);
    void addToPlaylist(const QString &filePath);
    void insertTracksNext(const QStringList &tracks);
    void clearQueue(bool keepCurrent = true);
    void removeFromQueue(int index);
    void moveQueueItem(int from, int to);
    void shuffleQueue();
    void playQueueIndex(int index);
    void handleTrackEnded();

    // Equalizer Invokables
    void setEqEnabled(bool enabled);
    void setEqPreamp(float preampDb);
    void setEqBand(int index, float gainDb);
    void applyEqPreset(const QString &presetName);
    void resetEq();

signals:
    void playbackStateChanged(AudioEngine::PlaybackState state);
    void positionChanged(qint64 positionMs);
    void durationChanged(qint64 durationMs);
    void volumeChanged(float volume);
    void exclusiveModeChanged(bool isExclusive);
    void deviceChanged(const QString &deviceName);
    void trackChanged(const QString &filePath);
    void currentMetadataChanged();
    void errorOccurred(const QString &errorMessage);
    void playModeChanged(AudioEngine::PlayMode mode);
    void playlistChanged();
    void currentIndexChanged(int index);
    void queueChanged();
    void trackEnded();
    void eqEnabledChanged(bool enabled);
    void eqPreampChanged(float preampDb);
    void eqBandsChanged();
    void eqPresetChanged(const QString &preset);

    // Internal signals dispatching to worker thread
    void requestPlay(const QString &filePath);
    void requestPause();
    void requestResume();
    void requestStop();
    void requestSeek(qint64 positionMs);
    void requestSetVolume(float volume);
    void requestSetExclusive(bool exclusive);
    void requestInitialize();
    void requestShutdown();
    void requestSetEqEnabled(bool enabled);
    void requestSetEqPreamp(float preampDb);
    void requestSetEqBands(const QList<float> &bands);
    void requestSetEqBand(int index, float gainDb);

private:
    explicit AudioEngine(QObject *parent = nullptr);
    ~AudioEngine() override;

    bool hasMoreTracksInSequential() const;

    static AudioEngine *s_instance;

    QThread m_workerThread;
    AudioEngineWorker *m_worker = nullptr;

    PlaybackState m_playbackState = PlaybackState::Stopped;
    PlayMode m_playMode = PlayMode::RepeatAll;
    QStringList m_playlist;
    int m_currentIndex = -1;

    qint64 m_positionMs = 0;
    qint64 m_durationMs = 0;
    float m_volume = 1.0f;
    bool m_isExclusive = false;
    QString m_deviceName;
    QString m_currentTrack;
    QString m_currentTitle;
    QString m_currentArtist;
    QString m_currentAlbum;
    QString m_currentCoverUrl;
    bool m_hasCover = false;
    QString m_currentFormat;
    int m_currentBitrate = 0;
    int m_currentSampleRate = 0;
    int m_currentChannels = 0;
    int m_currentBitDepth = 0;
    int m_currentLatencyMs = 0;
    QString m_currentEncoding;
    QString m_currentTool;
    LyricModel *m_lyricsModel = nullptr;
    TrackModel *m_queueModel = nullptr;
    TrackModel *m_playedModel = nullptr;
    TrackModel *m_nextModel = nullptr;

    bool m_eqEnabled = false;
    float m_eqPreamp = 0.0f;
    QList<float> m_eqBands;
    QString m_eqPreset = QStringLiteral("Flat");

    void loadEqSettings();
    void saveEqSettings();
    void updateSubQueueModels();
};
