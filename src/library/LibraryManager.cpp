#include "LibraryManager.h"
#include "LibraryScanWorker.h"
#include "../audio/AudioEngine.h"
#include "../config/ConfigManager.h"
#include <QFileDialog>
#include <QDirIterator>
#include <QFileInfo>
#include <QRandomGenerator>
#include <QMap>
#include <QRegularExpression>
#include <QCoreApplication>
#include <QStandardPaths>
#include <QCryptographicHash>
#include <QFile>
#include <QUrl>
#include <QSaveFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUuid>
#include <QDateTime>
#include <QProcess>
#include <QDesktopServices>
#include <cstdint>
#include <cstring>
#include <algorithm>
#include <atomic>
#include "bass.h"

LibraryManager* LibraryManager::instance()
{
    static LibraryManager s_instance;
    return &s_instance;
}

LibraryManager::LibraryManager(QObject *parent)
    : QObject(parent)
    , m_recommendedTracksModel(new TrackModel(this))
    , m_recommendedAlbumsModel(new AlbumModel(this))
    , m_allTracksModel(new TrackModel(this))
    , m_allAlbumsModel(new AlbumModel(this))
    , m_allArtistsModel(new AlbumModel(this))
    , m_allFoldersModel(new AlbumModel(this))
    , m_filteredTracksModel(new TrackModel(this))
    , m_artistAlbumsModel(new AlbumModel(this))
    , m_searchTracksModel(new TrackModel(this))
    , m_searchAlbumsModel(new AlbumModel(this))
    , m_searchArtistsModel(new AlbumModel(this))
    , m_playlistsModel(new PlaylistModel(this))
    , m_playlistTracksModel(new TrackModel(this))
{
    qRegisterMetaType<TrackItem>("TrackItem");
    qRegisterMetaType<QList<TrackItem>>("QList<TrackItem>");
    qRegisterMetaType<PlaylistItem>("PlaylistItem");
    qRegisterMetaType<QList<PlaylistItem>>("QList<PlaylistItem>");

    loadLibraryCache();
    loadFavorites();
    loadPlaylists();
}

LibraryManager::~LibraryManager()
{
    cancelScan();
    if (m_scanThread) {
        if (m_scanThread->isRunning()) {
            m_scanThread->quit();
            m_scanThread->wait(3000);
        }
    }
}

void LibraryManager::openFolderDialog()
{
    QString dir = QFileDialog::getExistingDirectory(
        nullptr,
        QString::fromUtf8("选择音乐文件夹"),
        QString(),
        QFileDialog::ShowDirsOnly | QFileDialog::DontResolveSymlinks
    );

    if (!dir.isEmpty()) {
        ConfigManager::instance()->addScannedFolder(dir);
    }
}

void LibraryManager::scanFolder(const QString &folderPath)
{
    if (folderPath.isEmpty()) return;
    scanFolders(QStringList() << folderPath);
}

static QString decodeId3Text(const QByteArray &data)
{
    if (data.size() <= 1) return QString();
    unsigned char enc = static_cast<unsigned char>(data[0]);
    QByteArray content = data.mid(1);

    if (enc == 0) {
        // ISO-8859-1 or local 8-bit text
        while (!content.isEmpty() && content.endsWith('\0')) content.chop(1);
        if (content.isEmpty()) return QString();
        QString s = QString::fromUtf8(content);
        if (!s.contains(QChar::ReplacementCharacter)) {
            return s.trimmed();
        }
        return QString::fromLatin1(content).trimmed();
    } else if (enc == 1) {
        // UTF-16 with BOM
        while (content.size() >= 2 && content[content.size() - 1] == '\0' && content[content.size() - 2] == '\0') content.chop(2);
        if (content.size() < 2) return QString();

        uint8_t b0 = static_cast<uint8_t>(content[0]);
        uint8_t b1 = static_cast<uint8_t>(content[1]);
        if (b0 == 0xFF && b1 == 0xFE) {
            // UTF-16LE
            int charCount = (content.size() - 2) / 2;
            const char16_t *chars = reinterpret_cast<const char16_t*>(content.constData() + 2);
            return QString::fromUtf16(chars, charCount).trimmed();
        } else if (b0 == 0xFE && b1 == 0xFF) {
            // UTF-16BE: swap bytes
            QByteArray swapped = content.mid(2);
            for (int i = 0; i + 1 < swapped.size(); i += 2) {
                std::swap(swapped[i], swapped[i+1]);
            }
            int charCount = swapped.size() / 2;
            const char16_t *chars = reinterpret_cast<const char16_t*>(swapped.constData());
            return QString::fromUtf16(chars, charCount).trimmed();
        } else {
            // No BOM, assume UTF-16LE
            int charCount = content.size() / 2;
            const char16_t *chars = reinterpret_cast<const char16_t*>(content.constData());
            return QString::fromUtf16(chars, charCount).trimmed();
        }
    } else if (enc == 2) {
        // UTF-16BE without BOM
        while (content.size() >= 2 && content[content.size() - 1] == '\0' && content[content.size() - 2] == '\0') content.chop(2);
        if (content.size() < 2) return QString();
        QByteArray swapped = content;
        for (int i = 0; i + 1 < swapped.size(); i += 2) {
            std::swap(swapped[i], swapped[i+1]);
        }
        int charCount = swapped.size() / 2;
        const char16_t *chars = reinterpret_cast<const char16_t*>(swapped.constData());
        return QString::fromUtf16(chars, charCount).trimmed();
    } else if (enc == 3) {
        // UTF-8
        while (!content.isEmpty() && content.endsWith('\0')) content.chop(1);
        return QString::fromUtf8(content).trimmed();
    }
    return QString::fromUtf8(content).trimmed();
}

static void parseId3v2_2Tags(const QByteArray &tagData,
                             QString &title, QString &artist, QString &album, QString &albumArtist,
                             QByteArray &coverData, bool &isCoverPng)
{
    int pos = 0;
    while (pos + 6 <= tagData.size()) {
        QByteArray frameId = tagData.mid(pos, 3);
        if (frameId[0] == 0) break;
        int frameSize = (static_cast<uint8_t>(tagData[pos + 3]) << 16)
                      | (static_cast<uint8_t>(tagData[pos + 4]) << 8)
                      | static_cast<uint8_t>(tagData[pos + 5]);
        if (frameSize <= 0 || pos + 6 + frameSize > tagData.size()) break;
        QByteArray frameContent = tagData.mid(pos + 6, frameSize);
        if (frameId == "TT2" && title.isEmpty()) {
            title = decodeId3Text(frameContent);
        } else if (frameId == "TP1" && artist.isEmpty()) {
            artist = decodeId3Text(frameContent);
        } else if (frameId == "TAL" && album.isEmpty()) {
            album = decodeId3Text(frameContent);
        } else if (frameId == "TP2" && albumArtist.isEmpty()) {
            albumArtist = decodeId3Text(frameContent);
        } else if (frameId == "PIC" && coverData.isEmpty()) {
            int jpgPos = frameContent.indexOf("\xFF\xD8\xFF");
            int pngPos = frameContent.indexOf("\x89PNG");
            int imgStart = -1;
            if (jpgPos >= 0 && (pngPos < 0 || jpgPos < pngPos)) {
                imgStart = jpgPos;
                isCoverPng = false;
            } else if (pngPos >= 0) {
                imgStart = pngPos;
                isCoverPng = true;
            }
            if (imgStart >= 0) {
                coverData = frameContent.mid(imgStart);
            }
        }
        pos += 6 + frameSize;
    }
}

static void parseId3v2Tags(const QByteArray &tagData, int version,
                           QString &title, QString &artist, QString &album, QString &albumArtist,
                           QByteArray &coverData, bool &isCoverPng)
{
    int pos = 0;
    while (pos + 10 <= tagData.size()) {
        QByteArray frameId = tagData.mid(pos, 4);
        if (frameId[0] == 0) break; // padding reached

        int frameSize = 0;
        if (version == 4) {
            // syncsafe integer in ID3v2.4
            frameSize = ((static_cast<uint8_t>(tagData[pos + 4]) & 0x7F) << 21)
                      | ((static_cast<uint8_t>(tagData[pos + 5]) & 0x7F) << 14)
                      | ((static_cast<uint8_t>(tagData[pos + 6]) & 0x7F) << 7)
                      | (static_cast<uint8_t>(tagData[pos + 7]) & 0x7F);
        } else {
            // standard 32-bit big-endian integer in ID3v2.3
            frameSize = (static_cast<uint8_t>(tagData[pos + 4]) << 24)
                      | (static_cast<uint8_t>(tagData[pos + 5]) << 16)
                      | (static_cast<uint8_t>(tagData[pos + 6]) << 8)
                      | static_cast<uint8_t>(tagData[pos + 7]);
        }

        if (frameSize <= 0 || pos + 10 + frameSize > tagData.size()) break;

        QByteArray frameContent = tagData.mid(pos + 10, frameSize);
        if (frameId == "TIT2" && title.isEmpty()) {
            title = decodeId3Text(frameContent);
        } else if (frameId == "TPE1" && artist.isEmpty()) {
            artist = decodeId3Text(frameContent);
        } else if (frameId == "TALB" && album.isEmpty()) {
            album = decodeId3Text(frameContent);
        } else if (frameId == "TPE2" && albumArtist.isEmpty()) {
            albumArtist = decodeId3Text(frameContent);
        } else if (frameId == "APIC" && coverData.isEmpty()) {
            int jpgPos = frameContent.indexOf("\xFF\xD8\xFF");
            int pngPos = frameContent.indexOf("\x89PNG");
            int imgStart = -1;
            if (jpgPos >= 0 && (pngPos < 0 || jpgPos < pngPos)) {
                imgStart = jpgPos;
                isCoverPng = false;
            } else if (pngPos >= 0) {
                imgStart = pngPos;
                isCoverPng = true;
            }
            if (imgStart >= 0) {
                coverData = frameContent.mid(imgStart);
            }
        }

        pos += 10 + frameSize;
    }
}

static void parseVorbisComments(const QByteArray &commentData,
                                QString &title, QString &artist, QString &album, QString &albumArtist)
{
    if (commentData.size() < 8) return;
    int pos = 0;

    // Vendor string length (32-bit little endian)
    uint32_t vendorLen = static_cast<uint8_t>(commentData[pos])
                       | (static_cast<uint8_t>(commentData[pos+1]) << 8)
                       | (static_cast<uint8_t>(commentData[pos+2]) << 16)
                       | (static_cast<uint8_t>(commentData[pos+3]) << 24);
    pos += 4 + vendorLen;
    if (pos + 4 > commentData.size()) return;

    // User comment count (32-bit little endian)
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
            QString val = comment.mid(eq + 1).trimmed();
            if (key == "TITLE" && title.isEmpty()) {
                title = val;
            } else if (key == "ARTIST" && artist.isEmpty()) {
                artist = val;
            } else if (key == "ALBUM" && album.isEmpty()) {
                album = val;
            } else if ((key == "ALBUMARTIST" || key == "ALBUM ARTIST") && albumArtist.isEmpty()) {
                albumArtist = val;
            }
        }
    }
}

static void extractTagsAndCoverDirect(const QString &audioPath,
                                      QString &title, QString &artist, QString &album, QString &albumArtist,
                                      QString &coverUrl)
{
    QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/covers";
    QDir().mkpath(cacheDir);

    QByteArray hash = QCryptographicHash::hash(audioPath.toUtf8(), QCryptographicHash::Md5).toHex();
    QString cachedJpg = cacheDir + "/" + hash + ".jpg";
    QString cachedPng = cacheDir + "/" + hash + ".png";

    if (QFile::exists(cachedJpg)) coverUrl = QUrl::fromLocalFile(cachedJpg).toString();
    else if (QFile::exists(cachedPng)) coverUrl = QUrl::fromLocalFile(cachedPng).toString();

    QFile file(audioPath);
    if (!file.open(QIODevice::ReadOnly)) return;

    QByteArray header = file.read(10);
    if (header.size() < 4) return;

    // 1. Check ID3v2 (MP3, etc.)
    if (header.size() >= 10 && header.startsWith("ID3")) {
        int version = static_cast<uint8_t>(header[3]);
        int tagSize = ((static_cast<uint8_t>(header[6]) & 0x7F) << 21)
                    | ((static_cast<uint8_t>(header[7]) & 0x7F) << 14)
                    | ((static_cast<uint8_t>(header[8]) & 0x7F) << 7)
                    | (static_cast<uint8_t>(header[9]) & 0x7F);

        if (tagSize > 0 && tagSize < 30 * 1024 * 1024) {
            QByteArray tagData = file.read(tagSize);
            QByteArray coverData;
            bool isCoverPng = false;

            if (version == 2) {
                parseId3v2_2Tags(tagData, title, artist, album, albumArtist, coverData, isCoverPng);
            } else {
                parseId3v2Tags(tagData, version, title, artist, album, albumArtist, coverData, isCoverPng);
            }

            if (coverUrl.isEmpty() && !coverData.isEmpty()) {
                QString outPath = isCoverPng ? cachedPng : cachedJpg;
                QFile outFile(outPath);
                if (outFile.open(QIODevice::WriteOnly)) {
                    outFile.write(coverData);
                    outFile.close();
                    coverUrl = QUrl::fromLocalFile(outPath).toString();
                }
            }
        }
    }

    // 2. Check FLAC (starts with "fLaC")
    if (header.startsWith("fLaC")) {
        file.seek(4);
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
                parseVorbisComments(commentData, title, artist, album, albumArtist);
            } else if (blockType == 6) { // PICTURE block
                QByteArray picBlock = file.read(blockLength);
                if (coverUrl.isEmpty() && picBlock.size() >= 32) {
                    int mimeLen = (static_cast<uint8_t>(picBlock[4]) << 24)
                                | (static_cast<uint8_t>(picBlock[5]) << 16)
                                | (static_cast<uint8_t>(picBlock[6]) << 8)
                                | static_cast<uint8_t>(picBlock[7]);
                    int offset = 8 + mimeLen;
                    if (offset + 4 <= picBlock.size()) {
                        int descLen = (static_cast<uint8_t>(picBlock[offset]) << 24)
                                    | (static_cast<uint8_t>(picBlock[offset + 1]) << 16)
                                    | (static_cast<uint8_t>(picBlock[offset + 2]) << 8)
                                    | static_cast<uint8_t>(picBlock[offset + 3]);
                        offset += 4 + descLen + 16;
                        if (offset + 4 <= picBlock.size()) {
                            int dataLen = (static_cast<uint8_t>(picBlock[offset]) << 24)
                                        | (static_cast<uint8_t>(picBlock[offset + 1]) << 16)
                                        | (static_cast<uint8_t>(picBlock[offset + 2]) << 8)
                                        | static_cast<uint8_t>(picBlock[offset + 3]);
                            offset += 4;
                            if (offset + dataLen <= picBlock.size()) {
                                QByteArray imgData = picBlock.mid(offset, dataLen);
                                bool isPng = imgData.startsWith("\x89PNG");
                                QString outPath = isPng ? cachedPng : cachedJpg;
                                QFile outFile(outPath);
                                if (outFile.open(QIODevice::WriteOnly)) {
                                    outFile.write(imgData);
                                    outFile.close();
                                    coverUrl = QUrl::fromLocalFile(outPath).toString();
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
}

static void extractTagsFromBass(HSTREAM probeStream,
                                QString &title, QString &artist, QString &album, QString &albumArtist)
{
    if (probeStream == 0) return;

    // 1. OGG / FLAC Vorbis comments
    const char *oggTags = BASS_ChannelGetTags(probeStream, BASS_TAG_OGG);
    if (oggTags) {
        while (*oggTags) {
            QString line = QString::fromUtf8(oggTags);
            int eq = line.indexOf('=');
            if (eq > 0) {
                QString key = line.left(eq).trimmed().toUpper();
                QString val = line.mid(eq + 1).trimmed();
                if (key == "TITLE" && title.isEmpty()) title = val;
                else if (key == "ARTIST" && artist.isEmpty()) artist = val;
                else if (key == "ALBUM" && album.isEmpty()) album = val;
                else if ((key == "ALBUMARTIST" || key == "ALBUM ARTIST") && albumArtist.isEmpty()) albumArtist = val;
            }
            oggTags += strlen(oggTags) + 1;
        }
    }

    // 2. APE tags
    const char *apeTags = BASS_ChannelGetTags(probeStream, BASS_TAG_APE);
    if (apeTags) {
        while (*apeTags) {
            QString line = QString::fromUtf8(apeTags);
            int eq = line.indexOf('=');
            if (eq > 0) {
                QString key = line.left(eq).trimmed().toUpper();
                QString val = line.mid(eq + 1).trimmed();
                if (key == "TITLE" && title.isEmpty()) title = val;
                else if (key == "ARTIST" && artist.isEmpty()) artist = val;
                else if (key == "ALBUM" && album.isEmpty()) album = val;
                else if ((key == "ALBUMARTIST" || key == "ALBUM ARTIST") && albumArtist.isEmpty()) albumArtist = val;
            }
            apeTags += strlen(apeTags) + 1;
        }
    }

    // 3. MP4 / iTunes tags
    const char *mp4Tags = BASS_ChannelGetTags(probeStream, BASS_TAG_MP4);
    if (mp4Tags) {
        while (*mp4Tags) {
            QString line = QString::fromUtf8(mp4Tags);
            int eq = line.indexOf('=');
            if (eq > 0) {
                QString key = line.left(eq).trimmed().toUpper();
                QString val = line.mid(eq + 1).trimmed();
                if ((key == "©NAM" || key == "TITLE" || key == "NAME") && title.isEmpty()) title = val;
                else if ((key == "©ART" || key == "ARTIST") && artist.isEmpty()) artist = val;
                else if ((key == "©ALB" || key == "ALBUM") && album.isEmpty()) album = val;
                else if ((key == "AART" || key == "ALBUMARTIST" || key == "ALBUM ARTIST") && albumArtist.isEmpty()) albumArtist = val;
            }
            mp4Tags += strlen(mp4Tags) + 1;
        }
    }

    // 4. ID3v1 tags
    const TAG_ID3 *id3v1 = reinterpret_cast<const TAG_ID3*>(BASS_ChannelGetTags(probeStream, BASS_TAG_ID3));
    if (id3v1) {
        if (title.isEmpty()) title = QString::fromLatin1(id3v1->title, sizeof(id3v1->title)).trimmed();
        if (artist.isEmpty()) artist = QString::fromLatin1(id3v1->artist, sizeof(id3v1->artist)).trimmed();
        if (album.isEmpty()) album = QString::fromLatin1(id3v1->album, sizeof(id3v1->album)).trimmed();
    }
}

void LibraryManager::parseMetadata(TrackItem &item)
{
    parseMetadataItem(item);
}

void LibraryManager::parseMetadataItem(TrackItem &item)
{
    QString title;
    QString artist;
    QString album;
    QString albumArtist;
    QString coverUrl;

    // 1. Direct file parsing (ID3v2 & FLAC)
    extractTagsAndCoverDirect(item.path, title, artist, album, albumArtist, coverUrl);

    // 2. Probe using BASS for duration and additional container tags
    QFileInfo fi(item.path);
    item.fileSizeBytes = fi.size();
    item.dateModified = fi.lastModified().toMSecsSinceEpoch();
    if (item.dateAdded <= 0) {
        item.dateAdded = QDateTime::currentMSecsSinceEpoch();
    }

    HSTREAM probeStream = BASS_StreamCreateFile(FALSE, item.path.toStdWString().c_str(), 0, 0, BASS_STREAM_DECODE | BASS_UNICODE);
    if (probeStream != 0) {
        QWORD bytes = BASS_ChannelGetLength(probeStream, BASS_POS_BYTE);
        double seconds = BASS_ChannelBytes2Seconds(probeStream, bytes);
        if (seconds > 0) {
            item.durationMs = static_cast<qint64>(seconds * 1000.0);
        }

        float bassBitrate = 0.0f;
        if (BASS_ChannelGetAttribute(probeStream, BASS_ATTRIB_BITRATE, &bassBitrate) && bassBitrate > 0) {
            item.bitrateKbps = static_cast<int>(bassBitrate);
        }

        extractTagsFromBass(probeStream, title, artist, album, albumArtist);

        BASS_StreamFree(probeStream);
    }

    if (item.bitrateKbps <= 0 && item.durationMs > 0 && item.fileSizeBytes > 0) {
        item.bitrateKbps = static_cast<int>((item.fileSizeBytes * 8.0) / item.durationMs);
    }

    // 3. Fallbacks for Title and Artist from filename
    QString baseName = fi.completeBaseName();

    if (title.isEmpty() || artist.isEmpty()) {
        QString cleanedName = baseName;
        if (cleanedName.length() > 3 && cleanedName[0].isDigit() && cleanedName[1].isDigit()) {
            if (cleanedName[2] == '-' || cleanedName[2] == '.' || cleanedName[2] == ' ') {
                cleanedName = cleanedName.mid(3).trimmed();
                if (cleanedName.startsWith('-')) cleanedName = cleanedName.mid(1).trimmed();
            }
        }

        if (cleanedName.contains(" - ")) {
            QStringList parts = cleanedName.split(" - ");
            if (artist.isEmpty()) artist = parts.value(0).trimmed();
            if (title.isEmpty()) title = parts.value(1).trimmed();
        } else {
            if (title.isEmpty()) title = cleanedName;
        }
    }

    if (title.isEmpty()) title = baseName;
    if (artist.isEmpty()) artist = QString::fromUtf8("未知艺术家");

    // 4. Strict Album Fallback
    // When album tag is present and non-empty, use it.
    // When empty, MUST fall back to "未知专辑" - NEVER use parent directory name!
    if (album.trimmed().isEmpty()) {
        album = QString::fromUtf8("未知专辑");
    } else {
        album = album.trimmed();
    }

    item.title = title;
    item.artist = artist;
    item.artists = splitArtists(artist);
    item.album = album;
    item.albumArtist = albumArtist;

    // 5. Cover image resolution
    if (!coverUrl.isEmpty()) {
        item.hasCover = true;
        item.coverUrl = coverUrl;
    } else {
        // Search track directory for folder artwork
        QDir dir = fi.dir();
        QStringList imgFilters = {"cover.jpg", "cover.png", "cover.jpeg", "folder.jpg", "folder.png", "front.jpg", "front.png", "album.jpg", "album.png"};
        QFileInfoList imgFiles = dir.entryInfoList(imgFilters, QDir::Files | QDir::Readable);
        if (!imgFiles.isEmpty()) {
            item.hasCover = true;
            item.coverUrl = QUrl::fromLocalFile(imgFiles.first().absoluteFilePath()).toString();
        } else {
            item.hasCover = false;
            item.coverUrl.clear();
        }
    }
}

void LibraryScanWorker::doScan()
{
    QStringList nameFilters;
    nameFilters << "*.mp3" << "*.flac" << "*.wav" << "*.m4a" << "*.ogg" << "*.ape" << "*.wv" << "*.wma" << "*.aac";

    QList<TrackItem> allFound;
    QList<TrackItem> batch;

    for (const QString &folderPath : m_folderPaths) {
        if (m_stopRequested.load(std::memory_order_relaxed)) break;
        if (folderPath.trimmed().isEmpty()) continue;

        QDirIterator it(folderPath, nameFilters, QDir::Files | QDir::Readable, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            if (m_stopRequested.load(std::memory_order_relaxed)) break;
            QString filePath = it.next();
            QFileInfo fi(filePath);

            TrackItem item;
            item.path = QDir::toNativeSeparators(filePath);
            item.format = fi.suffix().toUpper();

            LibraryManager::parseMetadataItem(item);
            allFound.append(item);
            batch.append(item);

            if (batch.size() >= 30) {
                emit batchDiscovered(batch, allFound.size());
                batch.clear();
            }
        }
    }

    if (!batch.isEmpty() && !m_stopRequested.load(std::memory_order_relaxed)) {
        emit batchDiscovered(batch, allFound.size());
        batch.clear();
    }

    if (!m_stopRequested.load(std::memory_order_relaxed)) {
        emit scanFinished(allFound);
    }
}

void LibraryManager::scanFolders(const QStringList &folderPaths)
{
    if (folderPaths.isEmpty()) return;

    if (m_scanWorker) {
        m_scanWorker->requestStop();
    }
    if (m_scanThread) {
        m_scanThread->quit();
        m_scanThread->wait(300);
    }

    m_isScanning = true;
    m_scannedCount = 0;
    emit isScanningChanged();
    emit scannedCountChanged();

    QThread *thread = new QThread(this);
    LibraryScanWorker *worker = new LibraryScanWorker(folderPaths);
    worker->moveToThread(thread);

    m_scanThread = thread;
    m_scanWorker = worker;

    connect(thread, &QThread::started, worker, &LibraryScanWorker::doScan);
    connect(worker, &LibraryScanWorker::batchDiscovered, this, &LibraryManager::onScanBatchReady, Qt::QueuedConnection);
    connect(worker, &LibraryScanWorker::scanFinished, this, &LibraryManager::onScanFinished, Qt::QueuedConnection);
    connect(worker, &LibraryScanWorker::scanFinished, thread, &QThread::quit);
    connect(thread, &QThread::finished, worker, &QObject::deleteLater);
    connect(thread, &QThread::finished, thread, &QObject::deleteLater);
    connect(thread, &QThread::destroyed, this, [this]() {
        m_scanThread = nullptr;
        m_scanWorker = nullptr;
    });

    thread->start(QThread::LowPriority);
}

void LibraryManager::cancelScan()
{
    if (m_scanWorker) {
        m_scanWorker->requestStop();
    }
    m_isScanning = false;
    emit isScanningChanged();
}

void LibraryManager::onScanBatchReady(const QList<TrackItem> &batch, int totalScanned)
{
    m_scannedCount = totalScanned;
    emit scannedCountChanged();

    if (m_allTracks.isEmpty()) {
        m_allTracks.append(batch);
        emit trackCountChanged();
        rebuildLibraryModels();
    }
}

void LibraryManager::onScanFinished(const QList<TrackItem> &allTracks)
{
    m_allTracks = allTracks;
    emit trackCountChanged();

    saveLibraryCache();
    rebuildLibraryModels();
    generateRecommendations();
    refreshPlaylistCovers();

    m_isScanning = false;
    emit isScanningChanged();
}

void LibraryManager::loadLibraryCache()
{
    QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QString cachePath = cacheDir + "/library_cache.json";
    QFile file(cachePath);
    if (!file.open(QIODevice::ReadOnly)) return;

    QByteArray data = file.readAll();
    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) return;

    QJsonArray arr = doc.object().value("tracks").toArray();
    if (arr.isEmpty()) return;

    m_allTracks.clear();
    m_allTracks.reserve(arr.size());

    for (const auto &val : arr) {
        QJsonObject obj = val.toObject();
        TrackItem item;
        item.path = obj.value("path").toString();
        item.title = obj.value("title").toString();
        item.artist = obj.value("artist").toString();
        item.album = obj.value("album").toString();
        item.albumArtist = obj.value("albumArtist").toString();
        item.durationMs = obj.value("durationMs").toVariant().toLongLong();
        item.format = obj.value("format").toString();
        item.bitrateKbps = obj.value("bitrateKbps").toInt();
        item.fileSizeBytes = obj.value("fileSizeBytes").toVariant().toLongLong();
        item.dateAdded = obj.value("dateAdded").toVariant().toLongLong();
        item.dateModified = obj.value("dateModified").toVariant().toLongLong();
        if (item.dateModified <= 0 && !item.path.isEmpty()) {
            QFileInfo fi(item.path);
            if (fi.exists()) item.dateModified = fi.lastModified().toMSecsSinceEpoch();
        }
        if (item.dateAdded <= 0) {
            item.dateAdded = item.dateModified > 0 ? item.dateModified : QDateTime::currentMSecsSinceEpoch();
        }
        item.hasCover = obj.value("hasCover").toBool();
        item.coverUrl = obj.value("coverUrl").toString();
        item.artists = splitArtists(item.artist);
        m_allTracks.append(item);
    }

    emit trackCountChanged();
    rebuildLibraryModels();
    generateRecommendations();
    refreshPlaylistCovers();
}

void LibraryManager::saveLibraryCache()
{
    QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(cacheDir);
    QString cachePath = cacheDir + "/library_cache.json";

    QJsonArray arr;
    for (const auto &item : m_allTracks) {
        QJsonObject obj;
        obj["path"] = item.path;
        obj["title"] = item.title;
        obj["artist"] = item.artist;
        obj["album"] = item.album;
        obj["albumArtist"] = item.albumArtist;
        obj["durationMs"] = item.durationMs;
        obj["format"] = item.format;
        obj["bitrateKbps"] = item.bitrateKbps;
        obj["fileSizeBytes"] = item.fileSizeBytes;
        obj["dateAdded"] = item.dateAdded;
        obj["dateModified"] = item.dateModified;
        obj["hasCover"] = item.hasCover;
        obj["coverUrl"] = item.coverUrl;
        arr.append(obj);
    }

    QJsonObject root;
    root["version"] = 1;
    root["tracks"] = arr;
    QJsonDocument doc(root);

    QSaveFile saveFile(cachePath);
    if (saveFile.open(QIODevice::WriteOnly)) {
        saveFile.write(doc.toJson(QJsonDocument::Compact));
        saveFile.commit();
    }
}

void LibraryManager::refreshRecommendations()
{
    generateRecommendations();
}

void LibraryManager::generateRecommendations()
{
    if (m_allTracks.isEmpty()) {
        m_recommendedTracksModel->clear();
        m_recommendedAlbumsModel->clear();
        emit recommendedTracksChanged();
        emit recommendedAlbumsChanged();
        return;
    }

    // 1. Sample 4 random tracks
    QList<TrackItem> trackPool = m_allTracks;
    for (int i = trackPool.size() - 1; i > 0; --i) {
        int j = QRandomGenerator::global()->bounded(i + 1);
        trackPool.swapItemsAt(i, j);
    }
    int trackSampleCount = qMin(4, static_cast<int>(trackPool.size()));
    m_recommendedTracksModel->setTracks(trackPool.mid(0, trackSampleCount));

    // 2. Group by album: key is (album_name, album_artist/artist)
    QMap<QString, AlbumItem> albumMap;
    for (const auto &track : m_allTracks) {
        QString albName = track.album.trimmed();
        if (albName.isEmpty()) {
            albName = QString::fromUtf8("未知专辑");
        }
        QString artName = track.artist.trimmed();
        if (artName.isEmpty()) {
            artName = QString::fromUtf8("未知艺术家");
        }

        // Unique aggregation key: album_name
        QString groupKey = albName.toLower();

        if (!albumMap.contains(groupKey)) {
            AlbumItem album;
            album.name = albName;
            album.artist = artName;
            album.coverUrl = track.coverUrl;
            album.trackCount = 1;
            album.tracks.append(track);
            albumMap.insert(groupKey, album);
        } else {
            albumMap[groupKey].trackCount++;
            albumMap[groupKey].tracks.append(track);
            if (albumMap[groupKey].coverUrl.isEmpty() && !track.coverUrl.isEmpty()) {
                albumMap[groupKey].coverUrl = track.coverUrl;
            }
        }
    }

    QList<AlbumItem> albumPool = albumMap.values();
    for (int i = albumPool.size() - 1; i > 0; --i) {
        int j = QRandomGenerator::global()->bounded(i + 1);
        albumPool.swapItemsAt(i, j);
    }
    int albumSampleCount = qMin(11, static_cast<int>(albumPool.size()));
    m_recommendedAlbumsModel->setAlbums(albumPool.mid(0, albumSampleCount));

    emit recommendedTracksChanged();
    emit recommendedAlbumsChanged();
}

void LibraryManager::playRecommendedTrack(int index)
{
    TrackItem item = m_recommendedTracksModel->trackAt(index);
    if (!item.path.isEmpty()) {
        QStringList paths;
        for (const auto &t : m_recommendedTracksModel->tracks()) {
            paths.append(t.path);
        }
        AudioEngine::instance()->setPlaylist(paths, index);
        AudioEngine::instance()->play(item.path);
        emit trackPlaybackRequested(item.path, item.title, item.artist);
    }
}

void LibraryManager::playRecommendedAlbum(int index)
{
    AlbumItem album = m_recommendedAlbumsModel->albumAt(index);
    if (!album.tracks.isEmpty()) {
        QStringList paths;
        for (const auto &t : album.tracks) {
            paths.append(t.path);
        }
        AudioEngine::instance()->setPlaylist(paths, 0);
        AudioEngine::instance()->play(album.tracks.first().path);
        emit trackPlaybackRequested(album.tracks.first().path, album.tracks.first().title, album.tracks.first().artist);
    }
}

QStringList LibraryManager::allTrackPaths() const
{
    QStringList paths;
    paths.reserve(m_allTracks.size());
    for (const auto &t : m_allTracks) {
        paths.append(t.path);
    }
    return paths;
}

void LibraryManager::clearLibrary()
{
    cancelScan();
    m_allTracks.clear();
    emit trackCountChanged();

    QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QFile::remove(cacheDir + "/library_cache.json");

    rebuildLibraryModels();
    generateRecommendations();
}

void LibraryManager::setLibraryTracks(const QList<TrackItem> &tracks)
{
    m_allTracks = tracks;
    emit trackCountChanged();
    rebuildLibraryModels();
    generateRecommendations();
}

TrackItem LibraryManager::getTrackMetadata(const QString &filePath)
{
    if (filePath.isEmpty()) return TrackItem();

    QString native = QDir::toNativeSeparators(filePath);
    for (const auto &item : m_allTracks) {
        if (QString::compare(item.path, native, Qt::CaseInsensitive) == 0 ||
            QString::compare(item.path, filePath, Qt::CaseInsensitive) == 0) {
            return item;
        }
    }

    // If not in currently scanned tracks, parse directly
    TrackItem item;
    item.path = native;
    item.format = QFileInfo(filePath).suffix().toUpper();
    parseMetadata(item);
    return item;
}

QStringList LibraryManager::splitArtists(const QString &artistStr)
{
    if (artistStr.trimmed().isEmpty()) {
        return { QString::fromUtf8("未知艺术家") };
    }
    QString seps = ConfigManager::instance()->artistSeparators().trimmed();
    if (seps.isEmpty()) seps = "/";

    QString pattern = "[";
    for (const QChar &ch : seps) {
        if (ch == '\\' || ch == '[' || ch == ']' || ch == '-' || ch == '^') {
            pattern += '\\';
        }
        pattern += ch;
    }
    pattern += "]";

    QRegularExpression re(pattern);
    QStringList parts = artistStr.split(re, Qt::SkipEmptyParts);
    QStringList result;
    for (const QString &p : parts) {
        QString trimmed = p.trimmed();
        if (!trimmed.isEmpty()) {
            result.append(trimmed);
        }
    }
    if (result.isEmpty()) {
        result.append(artistStr.trimmed());
    }
    return result;
}

void LibraryManager::rebuildLibraryModels()
{
    // 1. All Tracks
    m_allTracksModel->setTracks(m_allTracks);
    emit allTracksChanged();

    // 2. All Albums
    QMap<QString, AlbumItem> albumMap;
    for (const auto &track : m_allTracks) {
        QString albName = track.album.trimmed();
        if (albName.isEmpty()) albName = QString::fromUtf8("未知专辑");
        QString artName = track.artist.trimmed();
        if (artName.isEmpty()) artName = QString::fromUtf8("未知艺术家");
        QString groupKey = albName.toLower();

        if (!albumMap.contains(groupKey)) {
            AlbumItem album;
            album.name = albName;
            album.artist = artName;
            album.coverUrl = track.coverUrl;
            album.trackCount = 1;
            album.tracks.append(track);
            albumMap.insert(groupKey, album);
        } else {
            albumMap[groupKey].trackCount++;
            albumMap[groupKey].tracks.append(track);
            if (albumMap[groupKey].coverUrl.isEmpty() && !track.coverUrl.isEmpty()) {
                albumMap[groupKey].coverUrl = track.coverUrl;
            }
        }
    }
    QList<AlbumItem> albums = albumMap.values();
    std::sort(albums.begin(), albums.end(), [](const AlbumItem &a, const AlbumItem &b) {
        return QString::localeAwareCompare(a.name, b.name) < 0;
    });
    m_allAlbumsModel->setAlbums(albums);
    emit allAlbumsChanged();

    // 3. All Artists (split multi-artists)
    QMap<QString, AlbumItem> artistMap;
    for (const auto &track : m_allTracks) {
        QStringList arts = splitArtists(track.artist);
        for (const auto &art : arts) {
            QString clean = art.trimmed();
            if (clean.isEmpty()) clean = QString::fromUtf8("未知艺术家");
            QString key = clean.toLower();
            if (!artistMap.contains(key)) {
                AlbumItem item;
                item.name = clean;
                item.artist = "";
                item.coverUrl = track.coverUrl;
                item.trackCount = 1;
                item.tracks.append(track);
                artistMap.insert(key, item);
            } else {
                artistMap[key].trackCount++;
                artistMap[key].tracks.append(track);
                if (artistMap[key].coverUrl.isEmpty() && !track.coverUrl.isEmpty()) {
                    artistMap[key].coverUrl = track.coverUrl;
                }
            }
        }
    }
    QList<AlbumItem> artists = artistMap.values();
    std::sort(artists.begin(), artists.end(), [](const AlbumItem &a, const AlbumItem &b) {
        return QString::localeAwareCompare(a.name, b.name) < 0;
    });
    m_allArtistsModel->setAlbums(artists);
    emit allArtistsChanged();

    // 4. All Folders
    QMap<QString, AlbumItem> folderMap;
    const QStringList &scanned = ConfigManager::instance()->scannedFolders();
    for (const QString &sf : scanned) {
        QString native = QDir::toNativeSeparators(sf.trimmed());
        if (native.isEmpty()) continue;
        QFileInfo fi(native);
        AlbumItem item;
        item.name = fi.fileName().isEmpty() ? native : fi.fileName();
        item.path = native;
        item.artist = native;
        item.trackCount = 0;
        folderMap.insert(native.toLower(), item);
    }
    for (const auto &track : m_allTracks) {
        QFileInfo fi(track.path);
        QString dirPath = QDir::toNativeSeparators(fi.absolutePath());
        QString dirKey = dirPath.toLower();
        if (!folderMap.contains(dirKey)) {
            AlbumItem item;
            item.name = fi.dir().dirName();
            if (item.name.isEmpty()) item.name = dirPath;
            item.path = dirPath;
            item.artist = dirPath;
            item.coverUrl = track.coverUrl;
            item.trackCount = 1;
            item.tracks.append(track);
            folderMap.insert(dirKey, item);
        } else {
            folderMap[dirKey].trackCount++;
            folderMap[dirKey].tracks.append(track);
            if (folderMap[dirKey].coverUrl.isEmpty() && !track.coverUrl.isEmpty()) {
                folderMap[dirKey].coverUrl = track.coverUrl;
            }
        }
    }
    QList<AlbumItem> folders = folderMap.values();
    std::sort(folders.begin(), folders.end(), [](const AlbumItem &a, const AlbumItem &b) {
        return QString::localeAwareCompare(a.name, b.name) < 0;
    });
    m_allFoldersModel->setAlbums(folders);
    emit allFoldersChanged();

    if (!m_searchKeyword.isEmpty()) {
        search(m_searchKeyword);
    }
}

void LibraryManager::filterTracksByAlbum(const QString &albumName, const QString &artist)
{
    Q_UNUSED(artist);
    QList<TrackItem> filtered;
    QString targetAlb = albumName.trimmed();
    for (const auto &t : m_allTracks) {
        QString alb = t.album.trimmed();
        if (alb.isEmpty()) alb = QString::fromUtf8("未知专辑");
        if (QString::compare(alb, targetAlb, Qt::CaseInsensitive) == 0) {
            filtered.append(t);
        }
    }
    m_filteredTracksModel->setTracks(filtered);
    emit filteredTracksChanged();
}

void LibraryManager::filterTracksByArtist(const QString &artistName)
{
    QList<TrackItem> filtered;
    QString target = artistName.trimmed();
    for (const auto &t : m_allTracks) {
        QStringList arts = splitArtists(t.artist);
        bool match = false;
        for (const auto &a : arts) {
            if (QString::compare(a.trimmed(), target, Qt::CaseInsensitive) == 0) {
                match = true;
                break;
            }
        }
        if (match) filtered.append(t);
    }
    m_filteredTracksModel->setTracks(filtered);
    emit filteredTracksChanged();

    // Aggregate albums by this artist (matching React LibraryPage.tsx artistDetailAlbums)
    QMap<QString, AlbumItem> albumMap;
    for (const auto &t : filtered) {
        QString alb = t.album.trimmed();
        if (alb.isEmpty()) alb = QString::fromUtf8("未知专辑");
        QString key = alb.toLower();
        if (!albumMap.contains(key)) {
            AlbumItem item;
            item.name = alb;
            item.artist = target;
            item.coverUrl = t.coverUrl;
            item.trackCount = 1;
            item.tracks.append(t);
            albumMap.insert(key, item);
        } else {
            albumMap[key].trackCount++;
            albumMap[key].tracks.append(t);
            if (albumMap[key].coverUrl.isEmpty() && !t.coverUrl.isEmpty()) {
                albumMap[key].coverUrl = t.coverUrl;
            }
        }
    }
    QList<AlbumItem> albums = albumMap.values();
    std::sort(albums.begin(), albums.end(), [](const AlbumItem &a, const AlbumItem &b) {
        return QString::localeAwareCompare(a.name, b.name) < 0;
    });
    m_artistAlbumsModel->setAlbums(albums);
    emit artistAlbumsChanged();
}

void LibraryManager::filterTracksByFolder(const QString &folderPath)
{
    QList<TrackItem> filtered;
    QString cleanFolder = QDir::toNativeSeparators(folderPath.trimmed());
    for (const auto &t : m_allTracks) {
        QString tNative = QDir::toNativeSeparators(t.path);
        if (tNative.startsWith(cleanFolder, Qt::CaseInsensitive)) {
            filtered.append(t);
        }
    }
    m_filteredTracksModel->setTracks(filtered);
    emit filteredTracksChanged();
}

void LibraryManager::search(const QString &keyword)
{
    m_searchKeyword = keyword;
    emit searchKeywordChanged();

    QString q = keyword.trimmed();
    if (q.isEmpty()) {
        m_searchTracksModel->clear();
        m_searchAlbumsModel->clear();
        m_searchArtistsModel->clear();
        m_isSearching = false;
        emit isSearchingChanged();
        emit searchResultChanged();
        return;
    }

    m_isSearching = true;
    emit isSearchingChanged();

    // 1. Matched Tracks (Title, Artist, Album, Artists)
    QList<TrackItem> matchedTracks;
    for (const auto &track : m_allTracks) {
        bool match = false;
        if (track.title.contains(q, Qt::CaseInsensitive) ||
            track.artist.contains(q, Qt::CaseInsensitive) ||
            track.album.contains(q, Qt::CaseInsensitive)) {
            match = true;
        } else {
            for (const auto &art : track.artists) {
                if (art.contains(q, Qt::CaseInsensitive)) {
                    match = true;
                    break;
                }
            }
        }
        if (match) {
            matchedTracks.append(track);
        }
    }
    m_searchTracksModel->setTracks(matchedTracks);

    // 2. Matched Albums (Album name, Album artist)
    QList<AlbumItem> matchedAlbums;
    if (m_allAlbumsModel) {
        for (const auto &album : m_allAlbumsModel->albums()) {
            if (album.name.contains(q, Qt::CaseInsensitive) ||
                album.artist.contains(q, Qt::CaseInsensitive)) {
                matchedAlbums.append(album);
            }
        }
    }
    m_searchAlbumsModel->setAlbums(matchedAlbums);

    // 3. Matched Artists (Artist name)
    QList<AlbumItem> matchedArtists;
    if (m_allArtistsModel) {
        for (const auto &artist : m_allArtistsModel->albums()) {
            if (artist.name.contains(q, Qt::CaseInsensitive)) {
                matchedArtists.append(artist);
            }
        }
    }
    m_searchArtistsModel->setAlbums(matchedArtists);

    emit searchResultChanged();
}

void LibraryManager::clearSearch()
{
    search(QString());
}

int LibraryManager::searchTotalMatches() const
{
    int count = 0;
    if (m_searchTracksModel) count += m_searchTracksModel->rowCount();
    if (m_searchAlbumsModel) count += m_searchAlbumsModel->rowCount();
    if (m_searchArtistsModel) count += m_searchArtistsModel->rowCount();
    return count;
}

static void sortTrackItems(QList<TrackItem> &list, const QString &sortKey)
{
    if (sortKey == "title_asc") {
        std::sort(list.begin(), list.end(), [](const TrackItem &a, const TrackItem &b) {
            return QString::localeAwareCompare(a.title, b.title) < 0;
        });
    } else if (sortKey == "title_desc") {
        std::sort(list.begin(), list.end(), [](const TrackItem &a, const TrackItem &b) {
            return QString::localeAwareCompare(a.title, b.title) > 0;
        });
    } else if (sortKey == "artist_asc") {
        std::sort(list.begin(), list.end(), [](const TrackItem &a, const TrackItem &b) {
            return QString::localeAwareCompare(a.artist, b.artist) < 0;
        });
    } else if (sortKey == "artist_desc") {
        std::sort(list.begin(), list.end(), [](const TrackItem &a, const TrackItem &b) {
            return QString::localeAwareCompare(a.artist, b.artist) > 0;
        });
    } else if (sortKey == "album_asc") {
        std::sort(list.begin(), list.end(), [](const TrackItem &a, const TrackItem &b) {
            return QString::localeAwareCompare(a.album, b.album) < 0;
        });
    } else if (sortKey == "album_desc") {
        std::sort(list.begin(), list.end(), [](const TrackItem &a, const TrackItem &b) {
            return QString::localeAwareCompare(a.album, b.album) > 0;
        });
    } else if (sortKey == "duration_asc") {
        std::sort(list.begin(), list.end(), [](const TrackItem &a, const TrackItem &b) {
            return a.durationMs < b.durationMs;
        });
    } else if (sortKey == "duration_desc") {
        std::sort(list.begin(), list.end(), [](const TrackItem &a, const TrackItem &b) {
            return a.durationMs > b.durationMs;
        });
    } else if (sortKey == "bitrate_desc") {
        std::sort(list.begin(), list.end(), [](const TrackItem &a, const TrackItem &b) {
            return a.bitrateKbps > b.bitrateKbps;
        });
    } else if (sortKey == "bitrate_asc") {
        std::sort(list.begin(), list.end(), [](const TrackItem &a, const TrackItem &b) {
            return a.bitrateKbps < b.bitrateKbps;
        });
    } else if (sortKey == "size_desc") {
        std::sort(list.begin(), list.end(), [](const TrackItem &a, const TrackItem &b) {
            return a.fileSizeBytes > b.fileSizeBytes;
        });
    } else if (sortKey == "size_asc") {
        std::sort(list.begin(), list.end(), [](const TrackItem &a, const TrackItem &b) {
            return a.fileSizeBytes < b.fileSizeBytes;
        });
    } else if (sortKey == "date_added_desc") {
        std::sort(list.begin(), list.end(), [](const TrackItem &a, const TrackItem &b) {
            return a.dateAdded > b.dateAdded;
        });
    } else if (sortKey == "date_added_asc") {
        std::sort(list.begin(), list.end(), [](const TrackItem &a, const TrackItem &b) {
            return a.dateAdded < b.dateAdded;
        });
    } else if (sortKey == "date_modified_desc") {
        std::sort(list.begin(), list.end(), [](const TrackItem &a, const TrackItem &b) {
            return a.dateModified > b.dateModified;
        });
    } else if (sortKey == "date_modified_asc") {
        std::sort(list.begin(), list.end(), [](const TrackItem &a, const TrackItem &b) {
            return a.dateModified < b.dateModified;
        });
    }
}

void LibraryManager::sortTracks(const QString &sortKey)
{
    QList<TrackItem> list = m_allTracksModel->tracks();
    sortTrackItems(list, sortKey);
    m_allTracksModel->setTracks(list);

    QList<TrackItem> fList = m_filteredTracksModel->tracks();
    if (!fList.isEmpty()) {
        sortTrackItems(fList, sortKey);
        m_filteredTracksModel->setTracks(fList);
    }
}

void LibraryManager::sortAlbums(const QString &sortKey)
{
    QList<AlbumItem> list = m_allAlbumsModel->albums();
    if (sortKey == "album_asc") {
        std::sort(list.begin(), list.end(), [](const AlbumItem &a, const AlbumItem &b) {
            return QString::localeAwareCompare(a.name, b.name) < 0;
        });
    } else if (sortKey == "album_desc") {
        std::sort(list.begin(), list.end(), [](const AlbumItem &a, const AlbumItem &b) {
            return QString::localeAwareCompare(a.name, b.name) > 0;
        });
    } else if (sortKey == "artist_asc") {
        std::sort(list.begin(), list.end(), [](const AlbumItem &a, const AlbumItem &b) {
            return QString::localeAwareCompare(a.artist, b.artist) < 0;
        });
    } else if (sortKey == "artist_desc") {
        std::sort(list.begin(), list.end(), [](const AlbumItem &a, const AlbumItem &b) {
            return QString::localeAwareCompare(a.artist, b.artist) > 0;
        });
    } else if (sortKey == "track_count_desc") {
        std::sort(list.begin(), list.end(), [](const AlbumItem &a, const AlbumItem &b) {
            return a.trackCount > b.trackCount;
        });
    } else if (sortKey == "track_count_asc") {
        std::sort(list.begin(), list.end(), [](const AlbumItem &a, const AlbumItem &b) {
            return a.trackCount < b.trackCount;
        });
    }
    m_allAlbumsModel->setAlbums(list);
}

void LibraryManager::sortArtists(const QString &sortKey)
{
    QList<AlbumItem> list = m_allArtistsModel->albums();
    if (sortKey == "artist_asc") {
        std::sort(list.begin(), list.end(), [](const AlbumItem &a, const AlbumItem &b) {
            return QString::localeAwareCompare(a.name, b.name) < 0;
        });
    } else if (sortKey == "artist_desc") {
        std::sort(list.begin(), list.end(), [](const AlbumItem &a, const AlbumItem &b) {
            return QString::localeAwareCompare(a.name, b.name) > 0;
        });
    } else if (sortKey == "track_count_desc") {
        std::sort(list.begin(), list.end(), [](const AlbumItem &a, const AlbumItem &b) {
            return a.trackCount > b.trackCount;
        });
    } else if (sortKey == "track_count_asc") {
        std::sort(list.begin(), list.end(), [](const AlbumItem &a, const AlbumItem &b) {
            return a.trackCount < b.trackCount;
        });
    }
    m_allArtistsModel->setAlbums(list);
}

void LibraryManager::sortFolders(const QString &sortKey)
{
    QList<AlbumItem> list = m_allFoldersModel->albums();
    if (sortKey == "folder_asc") {
        std::sort(list.begin(), list.end(), [](const AlbumItem &a, const AlbumItem &b) {
            return QString::localeAwareCompare(a.name, b.name) < 0;
        });
    } else if (sortKey == "folder_desc") {
        std::sort(list.begin(), list.end(), [](const AlbumItem &a, const AlbumItem &b) {
            return QString::localeAwareCompare(a.name, b.name) > 0;
        });
    } else if (sortKey == "track_count_desc") {
        std::sort(list.begin(), list.end(), [](const AlbumItem &a, const AlbumItem &b) {
            return a.trackCount > b.trackCount;
        });
    } else if (sortKey == "track_count_asc") {
        std::sort(list.begin(), list.end(), [](const AlbumItem &a, const AlbumItem &b) {
            return a.trackCount < b.trackCount;
        });
    }
    m_allFoldersModel->setAlbums(list);
}

void LibraryManager::sortPlaylistTracks(const QString &sortKey)
{
    if (!m_playlistTracksModel) return;
    QList<TrackItem> list = m_playlistTracksModel->tracks();
    sortTrackItems(list, sortKey);
    m_playlistTracksModel->setTracks(list);
    emit playlistTracksChanged();

    // Persist sorted order into the underlying playlist
    if (m_currentPlaylistId == QStringLiteral("__favorites__")) {
        QStringList paths;
        paths.reserve(list.size());
        for (const auto &t : list) paths.append(QDir::cleanPath(t.path));
        m_favorites = paths;
        saveFavorites();
    } else if (!m_currentPlaylistId.isEmpty() && m_playlistsModel) {
        PlaylistItem item = m_playlistsModel->findPlaylist(m_currentPlaylistId);
        if (!item.id.isEmpty()) {
            QStringList paths;
            paths.reserve(list.size());
            for (const auto &t : list) paths.append(QDir::cleanPath(t.path));
            item.trackPaths = paths;
            m_playlistsModel->updatePlaylist(item);
            savePlaylists();
        }
    }
}

void LibraryManager::playTrack(const QString &filePath, const QStringList &queuePaths)
{
    QStringList playlist = queuePaths;
    if (playlist.isEmpty()) {
        playlist = allTrackPaths();
    }
    int startIndex = 0;
    for (int i = 0; i < playlist.size(); ++i) {
        if (QString::compare(playlist[i], filePath, Qt::CaseInsensitive) == 0) {
            startIndex = i;
            break;
        }
    }
    AudioEngine::instance()->setPlaylist(playlist, startIndex);
    AudioEngine::instance()->play(filePath);
    TrackItem meta = getTrackMetadata(filePath);
    emit trackPlaybackRequested(filePath, meta.title, meta.artist);
}

void LibraryManager::playAlbum(const QString &albumName, const QString &artist)
{
    filterTracksByAlbum(albumName, artist);
    if (m_filteredTracksModel->rowCount() > 0) {
        QStringList paths;
        for (const auto &t : m_filteredTracksModel->tracks()) {
            paths.append(t.path);
        }
        playTrack(paths.first(), paths);
    }
}

void LibraryManager::playArtist(const QString &artistName)
{
    filterTracksByArtist(artistName);
    if (m_filteredTracksModel->rowCount() > 0) {
        QStringList paths;
        for (const auto &t : m_filteredTracksModel->tracks()) {
            paths.append(t.path);
        }
        playTrack(paths.first(), paths);
    }
}

void LibraryManager::playFolder(const QString &folderPath)
{
    filterTracksByFolder(folderPath);
    if (m_filteredTracksModel->rowCount() > 0) {
        QStringList paths;
        for (const auto &t : m_filteredTracksModel->tracks()) {
            paths.append(t.path);
        }
        playTrack(paths.first(), paths);
    }
}

QStringList LibraryManager::getTrackPaths(TrackModel *model) const
{
    QStringList paths;
    TrackModel *target = model ? model : m_allTracksModel;
    for (const auto &t : target->tracks()) {
        paths.append(t.path);
    }
    return paths;
}

TrackModel* LibraryManager::queueModel() const
{
    return AudioEngine::instance()->queueModel();
}

TrackModel* LibraryManager::playedModel() const
{
    return AudioEngine::instance()->playedModel();
}

TrackModel* LibraryManager::nextModel() const
{
    return AudioEngine::instance()->nextModel();
}

void LibraryManager::clearQueue(bool keepCurrent)
{
    AudioEngine::instance()->clearQueue(keepCurrent);
}

void LibraryManager::removeFromQueue(int index)
{
    AudioEngine::instance()->removeFromQueue(index);
}

void LibraryManager::moveQueueItem(int from, int to)
{
    AudioEngine::instance()->moveQueueItem(from, to);
}

void LibraryManager::shuffleQueue()
{
    AudioEngine::instance()->shuffleQueue();
}

void LibraryManager::playQueueIndex(int index)
{
    AudioEngine::instance()->playQueueIndex(index);
}

// ============================================================================
// Playlists & Favorites Implementation
// ============================================================================

QString LibraryManager::createPlaylist(const QString &name)
{
    QString trimmed = name.trimmed();
    if (trimmed.isEmpty()) return QString();

    PlaylistItem item;
    item.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    item.name = trimmed;
    item.createdAt = QDateTime::currentMSecsSinceEpoch();
    item.trackCount = 0;

    m_playlistsModel->addPlaylist(item);
    emit playlistsChanged();
    savePlaylists();
    return item.id;
}

QString LibraryManager::createPlaylistWithTracks(const QString &name, const QStringList &trackPaths)
{
    QString plId = createPlaylist(name);
    if (!plId.isEmpty() && !trackPaths.isEmpty()) {
        addTracksToPlaylist(plId, trackPaths);
    }
    return plId;
}

void LibraryManager::deletePlaylist(const QString &id)
{
    if (id.isEmpty()) return;
    m_playlistsModel->removePlaylist(id);
    if (m_currentPlaylistId == id) {
        clearSelectedPlaylist();
    }
    emit playlistsChanged();
    savePlaylists();
}

void LibraryManager::renamePlaylist(const QString &id, const QString &newName)
{
    QString trimmed = newName.trimmed();
    if (trimmed.isEmpty()) return;

    PlaylistItem item = m_playlistsModel->findPlaylist(id);
    if (item.id.isEmpty()) return;

    item.name = trimmed;
    m_playlistsModel->updatePlaylist(item);
    if (m_currentPlaylistId == id) {
        m_currentPlaylistName = trimmed;
        emit currentPlaylistChanged();
    }
    emit playlistsChanged();
    savePlaylists();
}

void LibraryManager::addTrackToPlaylist(const QString &playlistId, const QString &trackPath)
{
    if (playlistId.isEmpty() || trackPath.isEmpty()) return;

    if (playlistId == QStringLiteral("__favorites__")) {
        if (!m_favorites.contains(trackPath)) {
            m_favorites.append(trackPath);
            emit favoritesChanged();
            saveFavorites();
            if (m_currentPlaylistId == QStringLiteral("__favorites__")) {
                selectPlaylist(QStringLiteral("__favorites__"));
            }
        }
        return;
    }

    PlaylistItem item = m_playlistsModel->findPlaylist(playlistId);
    if (item.id.isEmpty()) return;

    if (!item.trackPaths.contains(trackPath)) {
        item.trackPaths.append(trackPath);
        item.trackCount = item.trackPaths.size();
        if (item.coverUrl.isEmpty()) {
            TrackItem tr = getTrackMetadata(trackPath);
            item.coverUrl = tr.coverUrl;
        }
        m_playlistsModel->updatePlaylist(item);
        if (m_currentPlaylistId == playlistId) {
            selectPlaylist(playlistId);
        }
        emit playlistsChanged();
        savePlaylists();
    }
}

void LibraryManager::removeTrackFromPlaylist(const QString &playlistId, const QString &trackPath)
{
    removeTracksFromPlaylist(playlistId, QStringList{trackPath});
}

void LibraryManager::removeTracksFromPlaylist(const QString &playlistId, const QStringList &trackPaths)
{
    if (playlistId.isEmpty() || trackPaths.isEmpty()) return;

    if (playlistId == QStringLiteral("__favorites__")) {
        bool changed = false;
        for (const QString &tp : trackPaths) {
            QString clean = QDir::cleanPath(tp);
            for (int i = m_favorites.size() - 1; i >= 0; --i) {
                if (QString::compare(QDir::cleanPath(m_favorites[i]), clean, Qt::CaseInsensitive) == 0) {
                    m_favorites.removeAt(i);
                    changed = true;
                }
            }
        }
        if (changed) {
            emit favoritesChanged();
            saveFavorites();
            if (m_currentPlaylistId == QStringLiteral("__favorites__")) {
                selectPlaylist(QStringLiteral("__favorites__"));
            }
        }
        return;
    }

    PlaylistItem item = m_playlistsModel->findPlaylist(playlistId);
    if (item.id.isEmpty()) return;

    bool changed = false;
    for (const QString &tp : trackPaths) {
        QString clean = QDir::cleanPath(tp);
        for (int i = item.trackPaths.size() - 1; i >= 0; --i) {
            if (QString::compare(QDir::cleanPath(item.trackPaths[i]), clean, Qt::CaseInsensitive) == 0) {
                item.trackPaths.removeAt(i);
                changed = true;
            }
        }
    }

    if (changed) {
        item.trackCount = item.trackPaths.size();
        if (item.trackPaths.isEmpty()) {
            item.coverUrl.clear();
        } else {
            TrackItem first = getTrackMetadata(item.trackPaths.first());
            item.coverUrl = first.coverUrl;
        }
        m_playlistsModel->updatePlaylist(item);
        if (m_currentPlaylistId == playlistId) {
            selectPlaylist(playlistId);
        }
        emit playlistsChanged();
        savePlaylists();
    }
}

void LibraryManager::selectPlaylist(const QString &id)
{
    if (id.isEmpty()) {
        clearSelectedPlaylist();
        return;
    }

    m_currentPlaylistId = id;
    QList<TrackItem> tracks;

    if (id == QStringLiteral("__favorites__")) {
        m_currentPlaylistName = tr("Favorites");
        m_currentPlaylistIsFavorites = true;
        for (const QString &path : m_favorites) {
            TrackItem tr = getTrackMetadata(path);
            if (!tr.path.isEmpty()) {
                tracks.append(tr);
            }
        }
        m_currentPlaylistCoverUrl = tracks.isEmpty() ? QString() : tracks.first().coverUrl;
    } else {
        m_currentPlaylistIsFavorites = false;
        PlaylistItem item = m_playlistsModel->findPlaylist(id);
        m_currentPlaylistName = item.name;
        for (const QString &path : item.trackPaths) {
            TrackItem tr = getTrackMetadata(path);
            if (!tr.path.isEmpty()) {
                tracks.append(tr);
            }
        }
        m_currentPlaylistCoverUrl = tracks.isEmpty() ? QString() : tracks.first().coverUrl;
    }

    m_playlistTracksModel->setTracks(tracks);
    emit playlistTracksChanged();
    emit currentPlaylistChanged();
}

void LibraryManager::clearSelectedPlaylist()
{
    m_currentPlaylistId.clear();
    m_currentPlaylistName.clear();
    m_currentPlaylistCoverUrl.clear();
    m_currentPlaylistIsFavorites = false;
    m_playlistTracksModel->clear();
    emit playlistTracksChanged();
    emit currentPlaylistChanged();
}

void LibraryManager::playPlaylist(const QString &id, bool shuffle)
{
    QStringList paths;
    if (id == QStringLiteral("__favorites__")) {
        paths = m_favorites;
    } else {
        PlaylistItem item = m_playlistsModel->findPlaylist(id);
        paths = item.trackPaths;
    }

    if (paths.isEmpty()) return;

    if (shuffle && paths.size() > 1) {
        for (int i = paths.size() - 1; i > 0; --i) {
            int j = QRandomGenerator::global()->bounded(i + 1);
            paths.swapItemsAt(i, j);
        }
    }

    AudioEngine::instance()->setPlaylist(paths, 0);
    AudioEngine::instance()->play(paths.first());
}

void LibraryManager::toggleFavorite(const QString &trackPath)
{
    if (trackPath.isEmpty()) return;
    QString clean = QDir::cleanPath(trackPath);
    bool found = false;
    for (int i = m_favorites.size() - 1; i >= 0; --i) {
        if (QString::compare(QDir::cleanPath(m_favorites[i]), clean, Qt::CaseInsensitive) == 0) {
            m_favorites.removeAt(i);
            found = true;
        }
    }
    if (!found) {
        m_favorites.append(clean);
    }
    emit favoritesChanged();
    saveFavorites();

    if (m_currentPlaylistId == QStringLiteral("__favorites__")) {
        selectPlaylist(QStringLiteral("__favorites__"));
    }
}

bool LibraryManager::isFavorite(const QString &trackPath) const
{
    if (trackPath.isEmpty()) return false;
    QString clean = QDir::cleanPath(trackPath);
    for (const QString &fav : m_favorites) {
        if (QString::compare(QDir::cleanPath(fav), clean, Qt::CaseInsensitive) == 0) {
            return true;
        }
    }
    return false;
}

void LibraryManager::loadFavorites()
{
    QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QFile file(cacheDir + "/favorites.json");
    if (!file.open(QIODevice::ReadOnly)) return;

    QByteArray data = file.readAll();
    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isArray()) return;

    m_favorites.clear();
    QJsonArray arr = doc.array();
    for (const auto &val : arr) {
        m_favorites.append(val.toString());
    }
    emit favoritesChanged();
}

void LibraryManager::saveFavorites()
{
    QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(cacheDir);
    QFile file(cacheDir + "/favorites.json");
    if (!file.open(QIODevice::WriteOnly)) return;

    QJsonArray arr;
    for (const QString &path : m_favorites) {
        arr.append(path);
    }
    QJsonDocument doc(arr);
    file.write(doc.toJson(QJsonDocument::Compact));
}

void LibraryManager::loadPlaylists()
{
    QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QFile file(cacheDir + "/playlists.json");
    if (!file.open(QIODevice::ReadOnly)) return;

    QByteArray data = file.readAll();
    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isArray()) return;

    QList<PlaylistItem> list;
    QJsonArray arr = doc.array();
    bool sanitized = false;
    for (const auto &val : arr) {
        QJsonObject obj = val.toObject();
        PlaylistItem item;
        item.id = obj.value("id").toString();
        item.name = obj.value("name").toString();
        item.description = obj.value("description").toString();
        item.createdAt = obj.value("createdAt").toVariant().toLongLong();
        QJsonArray tracksArr = obj.value("trackPaths").toArray();
        for (const auto &tVal : tracksArr) {
            item.trackPaths.append(tVal.toString());
        }
        item.trackCount = item.trackPaths.size();
        if (item.name.startsWith(QStringLiteral("Phase ")) || item.name.contains(QStringLiteral("Test PL"))) {
            sanitized = true;
            continue;
        }
        list.append(item);
    }
    m_playlistsModel->setPlaylists(list);
    refreshPlaylistCovers();
    emit playlistsChanged();
    if (sanitized) {
        savePlaylists();
    }
}

void LibraryManager::savePlaylists()
{
    QString cacheDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(cacheDir);
    QFile file(cacheDir + "/playlists.json");
    if (!file.open(QIODevice::WriteOnly)) return;

    QJsonArray arr;
    for (const auto &item : m_playlistsModel->playlists()) {
        QJsonObject obj;
        obj["id"] = item.id;
        obj["name"] = item.name;
        obj["description"] = item.description;
        obj["createdAt"] = item.createdAt;
        QJsonArray tracksArr;
        for (const QString &p : item.trackPaths) {
            tracksArr.append(p);
        }
        obj["trackPaths"] = tracksArr;
        arr.append(obj);
    }
    QJsonDocument doc(arr);
    file.write(doc.toJson(QJsonDocument::Compact));
}

void LibraryManager::refreshPlaylistCovers()
{
    QList<PlaylistItem> items = m_playlistsModel->playlists();
    bool changed = false;
    for (int i = 0; i < items.size(); ++i) {
        if (!items[i].trackPaths.isEmpty()) {
            TrackItem first = getTrackMetadata(items[i].trackPaths.first());
            if (items[i].coverUrl != first.coverUrl) {
                items[i].coverUrl = first.coverUrl;
                changed = true;
            }
        }
    }
    if (changed) {
        m_playlistsModel->setPlaylists(items);
    }
}

void LibraryManager::insertTracksToQueue(const QStringList &trackPaths)
{
    AudioEngine::instance()->insertTracksNext(trackPaths);
}

void LibraryManager::addTracksToPlaylist(const QString &playlistId, const QStringList &trackPaths)
{
    if (playlistId.isEmpty() || trackPaths.isEmpty()) return;
    if (playlistId == QStringLiteral("__favorites__")) {
        for (const QString &p : trackPaths) {
            if (!m_favorites.contains(p)) {
                m_favorites.append(p);
            }
        }
        emit favoritesChanged();
        saveFavorites();
        if (m_currentPlaylistId == QStringLiteral("__favorites__")) {
            selectPlaylist(QStringLiteral("__favorites__"));
        }
        return;
    }

    PlaylistItem item = m_playlistsModel->findPlaylist(playlistId);
    if (item.id.isEmpty()) return;

    bool changed = false;
    for (const QString &trackPath : trackPaths) {
        QString clean = QDir::cleanPath(trackPath);
        bool found = false;
        for (const QString &existing : item.trackPaths) {
            if (QString::compare(QDir::cleanPath(existing), clean, Qt::CaseInsensitive) == 0) {
                found = true;
                break;
            }
        }
        if (!found) {
            item.trackPaths.append(clean);
            changed = true;
        }
    }
    if (changed) {
        item.trackCount = item.trackPaths.size();
        if (item.coverUrl.isEmpty() && !item.trackPaths.isEmpty()) {
            TrackItem first = getTrackMetadata(item.trackPaths.first());
            item.coverUrl = first.coverUrl;
        }
        m_playlistsModel->updatePlaylist(item);
        if (m_currentPlaylistId == playlistId) {
            selectPlaylist(playlistId);
        }
        emit playlistsChanged();
        savePlaylists();
    }
}

void LibraryManager::toggleFavorites(const QStringList &trackPaths)
{
    if (trackPaths.isEmpty()) return;
    bool allFav = true;
    for (const QString &p : trackPaths) {
        if (!m_favorites.contains(p)) {
            allFav = false;
            break;
        }
    }
    if (allFav) {
        for (const QString &p : trackPaths) {
            m_favorites.removeAll(p);
        }
    } else {
        for (const QString &p : trackPaths) {
            if (!m_favorites.contains(p)) {
                m_favorites.append(p);
            }
        }
    }
    emit favoritesChanged();
    saveFavorites();
    if (m_currentPlaylistId == QStringLiteral("__favorites__")) {
        selectPlaylist(QStringLiteral("__favorites__"));
    }
}

void LibraryManager::showInExplorer(const QString &trackPath)
{
    if (trackPath.isEmpty()) return;
    QFileInfo fi(trackPath);
    if (!fi.exists()) return;
#ifdef Q_OS_WIN
    QString nativePath = QDir::toNativeSeparators(fi.absoluteFilePath());
    QProcess::startDetached("explorer.exe", QStringList() << "/select," << nativePath);
#else
    QDesktopServices::openUrl(QUrl::fromLocalFile(fi.absolutePath()));
#endif
}

QVariantMap LibraryManager::getTrackDetails(const QString &trackPath)
{
    QVariantMap map;
    TrackItem item = getTrackMetadata(trackPath);
    map["title"] = item.title;
    map["artist"] = item.artist;
    map["album"] = item.album;
    map["durationMs"] = item.durationMs;
    map["format"] = item.format.isEmpty() ? QStringLiteral("UNKNOWN") : item.format.toUpper();
    map["bitrateKbps"] = item.bitrateKbps;
    map["fileSizeBytes"] = item.fileSizeBytes;
    map["path"] = item.path;

    qint64 totalSec = item.durationMs / 1000;
    map["durationStr"] = QString("%1:%2").arg(totalSec / 60).arg(totalSec % 60, 2, 10, QChar('0'));
    double mb = static_cast<double>(item.fileSizeBytes) / (1024.0 * 1024.0);
    map["fileSizeStr"] = QString("%1 MB").arg(QString::number(mb, 'f', 2));
    map["bitrateStr"] = item.bitrateKbps > 0 ? QString("%1 kbps").arg(item.bitrateKbps) : QStringLiteral("—");

    return map;
}

void LibraryManager::removeTracksFromLibrary(const QStringList &trackPaths)
{
    if (trackPaths.isEmpty()) return;
    QSet<QString> toRemove(trackPaths.begin(), trackPaths.end());

    QList<TrackItem> remaining;
    remaining.reserve(m_allTracks.size());
    for (const TrackItem &t : m_allTracks) {
        if (!toRemove.contains(t.path)) {
            remaining.append(t);
        }
    }
    m_allTracks = remaining;
    emit trackCountChanged();
    rebuildLibraryModels();
    saveLibraryCache();
}




