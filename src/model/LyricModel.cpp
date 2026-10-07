#include "LyricModel.h"

#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QRegularExpression>
#include <QDebug>
#include <cmath>
#include <algorithm>

#if defined(Q_OS_WIN)
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#endif

LyricModel::LyricModel(QObject *parent)
    : QAbstractListModel(parent)
{
}

int LyricModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) return 0;
    return m_lines.size();
}

QVariant LyricModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_lines.size()) {
        return QVariant();
    }

    const auto &item = m_lines[index.row()];
    switch (role) {
    case TimeMsRole:
        return item.timeMs;
    case TextRole:
        return item.text;
    case TransRole:
        return item.trans;
    case IsActiveRole:
        return (index.row() == m_activeIndex);
    default:
        return QVariant();
    }
}

QHash<int, QByteArray> LyricModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[TimeMsRole] = "timeMs";
    roles[TextRole] = "text";
    roles[TransRole] = "trans";
    roles[IsActiveRole] = "isActive";
    return roles;
}

qint64 LyricModel::getTimeMs(int index) const
{
    if (index >= 0 && index < m_lines.size()) {
        return m_lines[index].timeMs;
    }
    return 0;
}

void LyricModel::clear()
{
    if (m_lines.isEmpty()) {
        if (m_activeIndex != -1) {
            m_activeIndex = -1;
            emit activeIndexChanged(m_activeIndex);
        }
        return;
    }

    beginResetModel();
    m_lines.clear();
    m_activeIndex = -1;
    endResetModel();

    emit countChanged();
    emit hasLyricsChanged();
    if (m_hasTranslation) {
        m_hasTranslation = false;
        emit hasTranslationChanged();
    }
    emit activeIndexChanged(m_activeIndex);
}

static QString decodeId3v2Text(const QByteArray &data)
{
    if (data.size() <= 1) return QString();
    uint8_t enc = static_cast<uint8_t>(data[0]);
    QByteArray content = data.mid(1);

    if (enc == 0) {
        // ISO-8859-1 or GBK/local 8-bit text
        while (!content.isEmpty() && content.endsWith('\0')) content.chop(1);
        if (content.isEmpty()) return QString();
        QString s = QString::fromUtf8(content);
        if (!s.contains(QChar::ReplacementCharacter)) return s.trimmed();
        return QString::fromLatin1(content).trimmed();
    } else if (enc == 1) {
        // UTF-16 with BOM
        while (content.size() >= 2 && content[content.size() - 1] == '\0' && content[content.size() - 2] == '\0') content.chop(2);
        if (content.size() < 2) return QString();
        uint8_t b0 = static_cast<uint8_t>(content[0]);
        uint8_t b1 = static_cast<uint8_t>(content[1]);
        bool be = (b0 == 0xFE && b1 == 0xFF);
        int start = ( (b0 == 0xFF && b1 == 0xFE) || be ) ? 2 : 0;
        const ushort *src = reinterpret_cast<const ushort*>(content.constData() + start);
        int len = (content.size() - start) / 2;
        QString s;
        s.reserve(len);
        for (int i = 0; i < len; ++i) {
            ushort val = src[i];
            if (be) val = ((val >> 8) & 0xFF) | ((val << 8) & 0xFF00);
            if (val != 0) s.append(QChar(val));
        }
        return s.trimmed();
    } else if (enc == 2) {
        // UTF-16BE without BOM
        while (content.size() >= 2 && content[content.size() - 1] == '\0' && content[content.size() - 2] == '\0') content.chop(2);
        const ushort *src = reinterpret_cast<const ushort*>(content.constData());
        int len = content.size() / 2;
        QString s;
        s.reserve(len);
        for (int i = 0; i < len; ++i) {
            ushort val = src[i];
            val = ((val >> 8) & 0xFF) | ((val << 8) & 0xFF00);
            if (val != 0) s.append(QChar(val));
        }
        return s.trimmed();
    } else if (enc == 3) {
        // UTF-8
        while (!content.isEmpty() && content.endsWith('\0')) content.chop(1);
        return QString::fromUtf8(content).trimmed();
    }
    return QString();
}

static QString extractUsltLyrics(const QByteArray &content)
{
    if (content.size() <= 4) return QString();
    uint8_t enc = static_cast<uint8_t>(content[0]);
    int pos = 4; // skip enc (1 byte) + language (3 bytes)
    // Find null terminator for description
    if (enc == 0 || enc == 3) {
        while (pos < content.size() && content[pos] != '\0') pos++;
        if (pos < content.size()) pos++;
    } else {
        while (pos + 1 < content.size() && !(content[pos] == '\0' && content[pos + 1] == '\0')) pos += 2;
        if (pos + 1 < content.size()) pos += 2;
    }
    if (pos >= content.size()) return QString();

    QByteArray lyricData;
    lyricData.append(static_cast<char>(enc));
    lyricData.append(content.mid(pos));
    return decodeId3v2Text(lyricData);
}

QString LyricModel::extractEmbeddedLyrics(const QString &audioPath)
{
    QFile file(audioPath);
    if (!file.open(QIODevice::ReadOnly)) return QString();

    QByteArray header = file.read(10);
    if (header.size() < 4) return QString();

    QString lyrics;

    // 1. Check ID3v2 (MP3, WAV, FLAC with ID3 header)
    if (header.startsWith("ID3")) {
        int version = static_cast<uint8_t>(header[3]);
        int tagSize = ((static_cast<uint8_t>(header[6]) & 0x7F) << 21)
                    | ((static_cast<uint8_t>(header[7]) & 0x7F) << 14)
                    | ((static_cast<uint8_t>(header[8]) & 0x7F) << 7)
                    | (static_cast<uint8_t>(header[9]) & 0x7F);

        if (tagSize > 0 && tagSize < 30 * 1024 * 1024) {
            QByteArray tagData = file.read(tagSize);
            if (version == 2) {
                int pos = 0;
                while (pos + 6 <= tagData.size()) {
                    QByteArray frameId = tagData.mid(pos, 3);
                    if (frameId[0] == 0) break;
                    int frameSize = (static_cast<uint8_t>(tagData[pos + 3]) << 16)
                                  | (static_cast<uint8_t>(tagData[pos + 4]) << 8)
                                  | static_cast<uint8_t>(tagData[pos + 5]);
                    if (frameSize <= 0 || pos + 6 + frameSize > tagData.size()) break;
                    if (frameId == "ULT") {
                        lyrics = extractUsltLyrics(tagData.mid(pos + 6, frameSize));
                        if (!lyrics.isEmpty()) return lyrics;
                    }
                    pos += 6 + frameSize;
                }
            } else {
                int pos = 0;
                while (pos + 10 <= tagData.size()) {
                    QByteArray frameId = tagData.mid(pos, 4);
                    if (frameId[0] == 0) break;
                    int frameSize = 0;
                    if (version == 4) {
                        frameSize = ((static_cast<uint8_t>(tagData[pos + 4]) & 0x7F) << 21)
                                  | ((static_cast<uint8_t>(tagData[pos + 5]) & 0x7F) << 14)
                                  | ((static_cast<uint8_t>(tagData[pos + 6]) & 0x7F) << 7)
                                  | (static_cast<uint8_t>(tagData[pos + 7]) & 0x7F);
                    } else {
                        frameSize = (static_cast<uint8_t>(tagData[pos + 4]) << 24)
                                  | (static_cast<uint8_t>(tagData[pos + 5]) << 16)
                                  | (static_cast<uint8_t>(tagData[pos + 6]) << 8)
                                  | static_cast<uint8_t>(tagData[pos + 7]);
                    }
                    if (frameSize <= 0 || pos + 10 + frameSize > tagData.size()) break;

                    if (frameId == "USLT" || frameId == "SYLT") {
                        lyrics = extractUsltLyrics(tagData.mid(pos + 10, frameSize));
                        if (!lyrics.isEmpty()) return lyrics;
                    } else if (frameId == "TXXX") {
                        // TXXX uses text encoding, then description, then text
                        QByteArray txxxData = tagData.mid(pos + 10, frameSize);
                        if (txxxData.size() > 1) {
                            uint8_t enc = static_cast<uint8_t>(txxxData[0]);
                            int tpos = 1;
                            if (enc == 0 || enc == 3) {
                                while (tpos < txxxData.size() && txxxData[tpos] != '\0') tpos++;
                                if (tpos < txxxData.size()) tpos++;
                            } else {
                                while (tpos + 1 < txxxData.size() && !(txxxData[tpos] == '\0' && txxxData[tpos + 1] == '\0')) tpos += 2;
                                if (tpos + 1 < txxxData.size()) tpos += 2;
                            }
                            if (tpos < txxxData.size()) {
                                QByteArray descData;
                                descData.append(static_cast<char>(enc));
                                descData.append(txxxData.mid(1, tpos - 1));
                                QString desc = decodeId3v2Text(descData).toUpper();
                                if (desc == "LYRICS" || desc == "UNSYNCEDLYRICS") {
                                    QByteArray valData;
                                    valData.append(static_cast<char>(enc));
                                    valData.append(txxxData.mid(tpos));
                                    lyrics = decodeId3v2Text(valData);
                                    if (!lyrics.isEmpty()) return lyrics;
                                }
                            }
                        }
                    }
                    pos += 10 + frameSize;
                }
            }
        }
        
        // Advance header to next block after ID3 for FLAC check
        header = file.read(10);
        if (header.size() < 4) return QString();
    }

    // 2. FLAC files
    if (header.startsWith("fLaC")) {
        // file.pos() is currently at header start + 10. We need to seek to header start + 4
        file.seek(file.pos() - header.size() + 4);
        bool isLast = false;
        while (!isLast && !file.atEnd()) {
            QByteArray blockHeader = file.read(4);
            if (blockHeader.size() < 4) break;

            uint8_t b0 = static_cast<uint8_t>(blockHeader[0]);
            isLast = (b0 & 0x80) != 0;
            int blockType = b0 & 0x7F;
            int blockLength = (static_cast<uint8_t>(blockHeader[1]) << 16)
                            | (static_cast<uint8_t>(blockHeader[2]) << 8)
                            | static_cast<uint8_t>(blockHeader[3]);

            if (blockLength <= 0 || blockLength > 50 * 1024 * 1024) break;

            if (blockType == 4) { // VORBIS_COMMENT block
                QByteArray commentData = file.read(blockLength);
                if (commentData.size() >= 8) {
                    int pos = 0;
                    uint32_t vendorLen = static_cast<uint8_t>(commentData[pos])
                                       | (static_cast<uint8_t>(commentData[pos+1]) << 8)
                                       | (static_cast<uint8_t>(commentData[pos+2]) << 16)
                                       | (static_cast<uint8_t>(commentData[pos+3]) << 24);
                    pos += 4 + vendorLen;
                    if (pos + 4 <= commentData.size()) {
                        uint32_t count = static_cast<uint8_t>(commentData[pos])
                                       | (static_cast<uint8_t>(commentData[pos+1]) << 8)
                                       | (static_cast<uint8_t>(commentData[pos+2]) << 16)
                                       | (static_cast<uint8_t>(commentData[pos+3]) << 24);
                        pos += 4;
                        for (uint32_t i = 0; i < count && pos + 4 <= commentData.size(); ++i) {
                            uint32_t commentLen = static_cast<uint8_t>(commentData[pos])
                                                | (static_cast<uint8_t>(commentData[pos+1]) << 8)
                                                | (static_cast<uint8_t>(commentData[pos+2]) << 16)
                                                | (static_cast<uint8_t>(commentData[pos+3]) << 24);
                            pos += 4;
                            if (pos + commentLen > static_cast<uint32_t>(commentData.size())) break;

                            QString comment = QString::fromUtf8(commentData.mid(pos, commentLen));
                            pos += commentLen;

                            int eq = comment.indexOf('=');
                            if (eq > 0) {
                                QString key = comment.left(eq).trimmed().toUpper();
                                if (key == "LYRICS" || key == "UNSYNCEDLYRICS" || key == "SYNCED LYRICS" || key == "LYRIC" || key == "UNSYNCED LYRICS") {
                                    QString val = comment.mid(eq + 1).trimmed();
                                    if (!val.isEmpty()) return val;
                                }
                            }
                        }
                    }
                }
            } else {
                file.seek(file.pos() + blockLength);
            }
        }
    }

    return QString();
}
void LyricModel::loadLyrics(const QString &audioPath)
{
    clear();
    if (audioPath.isEmpty()) return;

    QFileInfo fi(audioPath);
    QString dir = fi.absolutePath();
    QString base = fi.completeBaseName();

    // 1. Try external .lrc files in same directory
    QStringList candidates;
    candidates << (base + ".lrc") << (base + ".LRC") << (base + ".Lrc")
               << (fi.fileName() + ".lrc") << (fi.fileName() + ".LRC");
    for (const QString &c : candidates) {
        QString p = dir + "/" + c;
        if (QFileInfo::exists(p)) {
            QString content = readFileWithEncoding(p);
            if (!content.isEmpty()) {
                parseLrcContent(content);
                if (!m_lines.isEmpty()) {
                    qDebug() << "[LyricModel] Successfully loaded external lyrics from:" << p << "lines:" << m_lines.size();
                    return;
                }
            }
        }
    }

    // 2. Try embedded tags in audio file (FLAC Vorbis, ID3v2 USLT/ULT)
    QString embedded = extractEmbeddedLyrics(audioPath);
    if (!embedded.isEmpty()) {
        parseLrcContent(embedded);
        if (!m_lines.isEmpty()) {
            qDebug() << "[LyricModel] Successfully loaded embedded lyrics from:" << audioPath << "lines:" << m_lines.size();
            return;
        }
    }

    qDebug() << "[LyricModel] No lyrics found (external or embedded) for:" << audioPath;
}

void LyricModel::loadLrcContent(const QString &content)
{
    if (content.trimmed().isEmpty()) return;
    clear();
    parseLrcContent(content);
}

void LyricModel::updatePosition(qint64 positionMs)
{
    if (m_lines.isEmpty()) {
        if (m_activeIndex != -1) {
            m_activeIndex = -1;
            emit activeIndexChanged(-1);
        }
        return;
    }

    int newIndex = -1;
    for (int i = 0; i < m_lines.size(); ++i) {
        if (positionMs >= m_lines[i].timeMs) {
            newIndex = i;
        } else {
            break;
        }
    }

    if (m_activeIndex != newIndex) {
        int oldIndex = m_activeIndex;
        m_activeIndex = newIndex;
        emit activeIndexChanged(m_activeIndex);

        if (oldIndex >= 0 && oldIndex < m_lines.size()) {
            QModelIndex idx = index(oldIndex, 0);
            emit dataChanged(idx, idx, {IsActiveRole});
        }
        if (newIndex >= 0 && newIndex < m_lines.size()) {
            QModelIndex idx = index(newIndex, 0);
            emit dataChanged(idx, idx, {IsActiveRole});
        }
    }
}

void LyricModel::parseLrcContent(const QString &content)
{
    struct RawItem {
        double timeSec;
        QString text;
    };
    QVector<RawItem> rawItems;

    const QStringList lines = content.split(QRegularExpression(QStringLiteral("[\r\n]+")), Qt::SkipEmptyParts);

    for (const QString &rawLine : lines) {
        QString line = rawLine.trimmed();
        if (line.isEmpty()) continue;

        QVector<double> timestamps;
        int textStart = 0;
        int i = 0;

        while (i < line.length()) {
            if (line[i] == QLatin1Char('[')) {
                int end = line.indexOf(QLatin1Char(']'), i + 1);
                if (end != -1) {
                    QString tag = line.mid(i + 1, end - i - 1);
                    double sec = 0.0;
                    if (parseTimestamp(tag, sec)) {
                        timestamps.append(sec);
                        i = end + 1;
                        textStart = i;
                        continue;
                    }
                }
            }
            break;
        }

        QString lyricText = line.mid(textStart).trimmed();

        if (!timestamps.isEmpty()) {
            for (double t : timestamps) {
                rawItems.append({t, lyricText});
            }
        } else if (!line.startsWith(QLatin1Char('['))) {
            rawItems.append({0.0, line});
        }
    }

    bool hasTimestamps = false;
    for (const auto &item : rawItems) {
        if (item.timeSec > 0.001) {
            hasTimestamps = true;
            break;
        }
    }

    QVector<LyricItem> result;
    if (!hasTimestamps) {
        for (const auto &item : rawItems) {
            if (!item.text.isEmpty()) {
                LyricItem li;
                li.timeMs = 0;
                li.text = item.text;
                li.trans = QString();
                result.append(li);
            }
        }
    } else {
        std::stable_sort(rawItems.begin(), rawItems.end(), [](const RawItem &a, const RawItem &b) {
            return a.timeSec < b.timeSec;
        });

        int i = 0;
        while (i < rawItems.size()) {
            double time = rawItems[i].timeSec;
            QString text = rawItems[i].text;
            QString trans;

            int j = i + 1;
            while (j < rawItems.size() && std::abs(rawItems[j].timeSec - time) < 0.05) {
                const QString &nextText = rawItems[j].text;
                if (trans.isEmpty() && isLikelyTranslation(nextText)) {
                    trans = nextText;
                    j++;
                    break;
                }
                break;
            }

            LyricItem item;
            item.timeMs = static_cast<qint64>(std::round(time * 1000.0));
            item.text = text;
            item.trans = trans;
            result.append(item);

            i = (j > i + 1) ? j : (i + 1);
        }
    }

    bool hasTrans = false;
    for (const auto &it : result) {
        if (!it.trans.isEmpty()) {
            hasTrans = true;
            break;
        }
    }

    beginResetModel();
    m_lines = result;
    m_activeIndex = -1;
    endResetModel();

    emit countChanged();
    emit hasLyricsChanged();
    if (m_hasTranslation != hasTrans) {
        m_hasTranslation = hasTrans;
        emit hasTranslationChanged();
    }
    emit activeIndexChanged(m_activeIndex);
}

bool LyricModel::parseTimestamp(const QString &tag, double &seconds)
{
    QStringList parts = tag.split(QLatin1Char(':'));
    if (parts.size() < 2) return false;

    bool ok = false;
    double mins = parts[0].toDouble(&ok);
    if (!ok) return false;

    double secs = 0.0;
    if (parts.size() == 2) {
        secs = parts[1].toDouble(&ok);
        if (!ok) return false;
    } else if (parts.size() == 3) {
        double s = parts[1].toDouble(&ok);
        if (!ok) return false;
        double f = parts[2].toDouble(&ok);
        if (!ok) return false;
        secs = s + f / 100.0;
    } else {
        return false;
    }

    seconds = mins * 60.0 + secs;
    return true;
}

bool LyricModel::isLikelyTranslation(const QString &str)
{
    for (const QChar &ch : str) {
        ushort u = ch.unicode();
        if (u >= 0x4E00 && u <= 0x9FFF) {
            return true;
        }
    }
    return false;
}

bool LyricModel::isLikelyRomaji(const QString &str)
{
    for (const QChar &ch : str) {
        if (ch.unicode() > 127) return false;
    }
    return true;
}

QString LyricModel::readFileWithEncoding(const QString &filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly)) {
        return QString();
    }

    QByteArray bytes = file.readAll();
    file.close();

    if (bytes.isEmpty()) return QString();

    // Check UTF-8 BOM
    if (bytes.startsWith("\xEF\xBB\xBF")) {
        bytes = bytes.mid(3);
        return QString::fromUtf8(bytes);
    }

    // Check if valid UTF-8
    QString utf8Str = QString::fromUtf8(bytes);
    if (!utf8Str.contains(QChar::ReplacementCharacter)) {
        return utf8Str;
    }

    // Fallback: GB18030 / System codepage
#if defined(Q_OS_WIN)
    int wlen = MultiByteToWideChar(54936, 0, bytes.constData(), bytes.size(), nullptr, 0);
    if (wlen > 0) {
        std::wstring wstr(wlen, 0);
        MultiByteToWideChar(54936, 0, bytes.constData(), bytes.size(), &wstr[0], wlen);
        return QString::fromStdWString(wstr);
    }
    wlen = MultiByteToWideChar(CP_ACP, 0, bytes.constData(), bytes.size(), nullptr, 0);
    if (wlen > 0) {
        std::wstring wstr(wlen, 0);
        MultiByteToWideChar(CP_ACP, 0, bytes.constData(), bytes.size(), &wstr[0], wlen);
        return QString::fromStdWString(wstr);
    }
#endif

    return QString::fromLocal8Bit(bytes);
}
