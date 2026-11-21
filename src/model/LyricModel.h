#pragma once

#include <QAbstractListModel>
#include <QVector>
#include "LyricItem.h"

class LyricModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int activeIndex READ activeIndex NOTIFY activeIndexChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(bool hasLyrics READ hasLyrics NOTIFY hasLyricsChanged)
    Q_PROPERTY(bool hasTranslation READ hasTranslation NOTIFY hasTranslationChanged)
    Q_PROPERTY(qint64 currentPositionMs READ currentPositionMs NOTIFY currentPositionMsChanged)

public:
    enum LyricRoles {
        TimeMsRole = Qt::UserRole + 1,
        TextRole,
        TransRole,
        IsActiveRole,
        HasWordsRole,
        WordsRole
    };
    Q_ENUM(LyricRoles)

    explicit LyricModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    int activeIndex() const { return m_activeIndex; }
    int count() const { return m_lines.size(); }
    bool hasLyrics() const { return !m_lines.isEmpty(); }
    bool hasTranslation() const { return m_hasTranslation; }
    qint64 currentPositionMs() const { return m_currentPositionMs; }

    Q_INVOKABLE void loadLyrics(const QString &audioPath);
    Q_INVOKABLE void loadLrcContent(const QString &content);
    Q_INVOKABLE void clear();
    Q_INVOKABLE void updatePosition(qint64 positionMs);
    Q_INVOKABLE qint64 getTimeMs(int index) const;
    Q_INVOKABLE bool hasWords(int index) const;
    Q_INVOKABLE QVariantList getWords(int index) const;

signals:
    void activeIndexChanged(int activeIndex);
    void countChanged();
    void hasLyricsChanged();
    void hasTranslationChanged();
    void currentPositionMsChanged(qint64 positionMs);

private:
    void parseLrcContent(const QString &content);
    static QString extractEmbeddedLyrics(const QString &audioPath);
    static QString readFileWithEncoding(const QString &filePath);
    static bool parseTimestamp(const QString &tag, double &seconds);
    static bool parseInlineTimestamp(const QString &tag, qint64 &timeMs);
    static QString stripInlineTags(const QString &str);
    static bool isLikelyTranslation(const QString &str);
    static bool isLikelyRomaji(const QString &str);

    QVector<LyricItem> m_lines;
    int m_activeIndex = -1;
    bool m_hasTranslation = false;
    qint64 m_currentPositionMs = 0;
};
