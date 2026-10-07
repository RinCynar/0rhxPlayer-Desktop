#include "RoundedImage.h"
#include <QPainter>
#include <QPainterPath>
#include <QFile>
#include <QFileInfo>
#include <QCache>
#include <QMutex>
#include <QThreadPool>
#include <QRunnable>
#include <QImageReader>
#include <QPointer>
#include <QtMath>
#include <QGuiApplication>
#include <QScreen>
#include <QQuickWindow>

static QCache<QString, QImage> s_imageCache(2000);
static QMutex s_cacheMutex;

RoundedImage::RoundedImage(QQuickItem *parent)
    : QQuickPaintedItem(parent)
{
    setAntialiasing(true);
    setSmooth(true);
    setClip(true);
    setMipmap(true);
}

void RoundedImage::setSource(const QUrl &source)
{
    if (m_source == source) return;
    m_source = source;
    reloadImage();
    emit sourceChanged();
}

void RoundedImage::setImage(const QImage &img)
{
    m_image = img;
    m_imageLoaded = !img.isNull();
    update();
}

void RoundedImage::geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry)
{
    QQuickPaintedItem::geometryChange(newGeometry, oldGeometry);
    if (!m_source.isEmpty() && newGeometry.width() > 0 && newGeometry.height() > 0) {
        if (!m_imageLoaded || oldGeometry.width() <= 0 || oldGeometry.height() <= 0) {
            reloadImage();
        } else if (!m_fullResolution) {
            qreal dpr = window() ? window()->devicePixelRatio() : (qGuiApp && qGuiApp->primaryScreen() ? qGuiApp->primaryScreen()->devicePixelRatio() : 1.0);
            int oldPhys = qCeil(qMax(oldGeometry.width(), oldGeometry.height()) * dpr);
            int newPhys = qCeil(qMax(newGeometry.width(), newGeometry.height()) * dpr);
            if ((newPhys > 160 && oldPhys <= 160) || (newPhys > 384 && oldPhys <= 384)) {
                reloadImage();
            }
        }
    }
}

void RoundedImage::setFullResolution(bool full)
{
    if (m_fullResolution == full) return;
    m_fullResolution = full;
    reloadImage();
    emit fullResolutionChanged();
}

void RoundedImage::reloadImage()
{
    quint64 curReqId = ++m_requestId;
    m_image = QImage();
    m_imageLoaded = false;

    if (m_source.isEmpty()) {
        update();
        return;
    }

    QString localPath;
    if (m_source.isLocalFile()) {
        localPath = m_source.toLocalFile();
    } else if (m_source.scheme() == "qrc") {
        localPath = ":" + m_source.path();
    } else {
        QString s = m_source.toString();
        if (s.startsWith("qrc:/")) {
            localPath = ":" + s.mid(4);
        } else {
            localPath = s;
        }
    }

    if (localPath.isEmpty() || !QFile::exists(localPath)) {
        update();
        return;
    }

    int reqW = 0;
    int reqH = 0;
    QString cacheKey;
    if (m_fullResolution) {
        cacheKey = localPath + "|full";
    } else {
        qreal dpr = window() ? window()->devicePixelRatio() : (qGuiApp && qGuiApp->primaryScreen() ? qGuiApp->primaryScreen()->devicePixelRatio() : 1.0);
        int maxDim = qMax(int(width()), int(height()));
        int physicalDim = (maxDim > 0) ? qCeil(maxDim * dpr) : 512;
        int bucket = 512;
        if (physicalDim <= 160) {
            bucket = 256;
        } else if (physicalDim <= 384) {
            bucket = 512;
        } else {
            bucket = 1024;
        }
        reqW = bucket;
        reqH = bucket;
        cacheKey = localPath + "|" + QString::number(bucket);
    }

    {
        QMutexLocker locker(&s_cacheMutex);
        if (s_imageCache.contains(cacheKey)) {
            m_image = *s_imageCache.object(cacheKey);
            m_imageLoaded = !m_image.isNull();
            update();
            return;
        }
    }

    QUrl currentSource = m_source;
    QPointer<RoundedImage> weak(this);

    class ImageLoadTask : public QRunnable {
    public:
        ImageLoadTask(const QString &path, int w, int h, const QString &key, const QUrl &source, QPointer<RoundedImage> target, quint64 reqId)
            : m_path(path), m_w(w), m_h(h), m_key(key), m_source(source), m_target(target), m_reqId(reqId) {
            setAutoDelete(true);
        }

        void run() override {
            // Early cancellation check before IO
            if (!m_target || m_target->requestId() != m_reqId) return;

            // Check if another task decoded this key while in queue
            {
                QMutexLocker locker(&s_cacheMutex);
                if (s_imageCache.contains(m_key)) {
                    QImage cached = *s_imageCache.object(m_key);
                    if (!m_target || m_target->requestId() != m_reqId) return;
                    QPointer<RoundedImage> target = m_target;
                    QUrl src = m_source;
                    quint64 reqId = m_reqId;
                    QMetaObject::invokeMethod(target, [target, cached, src, reqId]() {
                        if (!target || target->requestId() != reqId) return;
                        if (target->source() == src) {
                            target->setImage(cached);
                        }
                    }, Qt::QueuedConnection);
                    return;
                }
            }

            if (!m_target || m_target->requestId() != m_reqId) return;

            QImageReader reader(m_path);
            reader.setAutoTransform(true);
            if (m_w > 0 && m_h > 0) {
                QSize orig = reader.size();
                // If original image is very large (> 2x target), pre-downscale to 2x target to save memory
                if (orig.isValid() && (orig.width() > m_w * 2 || orig.height() > m_h * 2)) {
                    QSize preScaled = orig.scaled(m_w * 2, m_h * 2, Qt::KeepAspectRatioByExpanding);
                    reader.setScaledSize(preScaled);
                }
            }

            if (!m_target || m_target->requestId() != m_reqId) return;

            QImage loaded = reader.read();

            // Perform high-quality smooth antialiasing transformation to target bucket size
            if (m_w > 0 && m_h > 0 && !loaded.isNull()) {
                if (loaded.width() > m_w || loaded.height() > m_h) {
                    loaded = loaded.scaled(m_w, m_h, Qt::KeepAspectRatioByExpanding, Qt::SmoothTransformation);
                }
            }

            if (!loaded.isNull()) {
                QMutexLocker locker(&s_cacheMutex);
                if (!s_imageCache.contains(m_key)) {
                    s_imageCache.insert(m_key, new QImage(loaded));
                }
            }

            if (!m_target || m_target->requestId() != m_reqId) return;

            QPointer<RoundedImage> target = m_target;
            QUrl src = m_source;
            quint64 reqId = m_reqId;

            QMetaObject::invokeMethod(target, [target, loaded, src, reqId]() {
                if (!target || target->requestId() != reqId) return;
                if (target->source() == src) {
                    target->setImage(loaded);
                }
            }, Qt::QueuedConnection);
        }

    private:
        QString m_path;
        int m_w;
        int m_h;
        QString m_key;
        QUrl m_source;
        QPointer<RoundedImage> m_target;
        quint64 m_reqId;
    };

    QThreadPool::globalInstance()->start(new ImageLoadTask(localPath, reqW, reqH, cacheKey, currentSource, weak, curReqId));
}

void RoundedImage::setRadius(qreal r)
{
    if (qFuzzyCompare(m_radius, r)) return;
    m_radius = r;
    update();
    emit radiusChanged();
}

void RoundedImage::setFallbackColor(const QColor &c)
{
    if (m_fallbackColor == c) return;
    m_fallbackColor = c;
    update();
    emit fallbackColorChanged();
}

void RoundedImage::setFallbackIcon(const QUrl &icon)
{
    if (m_fallbackIcon == icon) return;
    m_fallbackIcon = icon;

    QString path;
    if (m_fallbackIcon.scheme() == "qrc") {
        path = ":" + m_fallbackIcon.path();
    } else {
        QString s = m_fallbackIcon.toString();
        if (s.startsWith("qrc:/")) {
            path = ":" + s.mid(4);
        } else {
            path = s;
        }
    }

    m_svgValid = m_svgRenderer.load(path);
    updateFallbackIcon();
    update();
    emit fallbackIconChanged();
}

void RoundedImage::setFallbackIconColor(const QColor &c)
{
    if (m_fallbackIconColor == c) return;
    m_fallbackIconColor = c;
    updateFallbackIcon();
    update();
    emit fallbackIconColorChanged();
}

void RoundedImage::setFallbackIconSize(int s)
{
    if (m_fallbackIconSize == s) return;
    m_fallbackIconSize = s;
    updateFallbackIcon();
    update();
    emit fallbackIconSizeChanged();
}

void RoundedImage::updateFallbackIcon()
{
    m_cachedFallbackIcon = QImage();
    if (!m_svgValid) return;

    int iconSize = m_fallbackIconSize > 0 ? m_fallbackIconSize : 24;
    QImage iconImg(iconSize, iconSize, QImage::Format_ARGB32_Premultiplied);
    iconImg.fill(Qt::transparent);
    QPainter iconPainter(&iconImg);
    iconPainter.setRenderHint(QPainter::Antialiasing, true);
    m_svgRenderer.render(&iconPainter, QRectF(0, 0, iconSize, iconSize));
    iconPainter.setCompositionMode(QPainter::CompositionMode_SourceIn);
    iconPainter.fillRect(iconImg.rect(), m_fallbackIconColor);
    iconPainter.end();

    m_cachedFallbackIcon = iconImg;
}

void RoundedImage::paint(QPainter *painter)
{
    if (width() <= 0 || height() <= 0) return;

    painter->setRenderHint(QPainter::Antialiasing, true);
    painter->setRenderHint(QPainter::SmoothPixmapTransform, true);

    QRectF rect(0, 0, width(), height());
    QPainterPath clipPath;
    clipPath.addRoundedRect(rect, m_radius, m_radius);
    painter->setClipPath(clipPath);

    if (m_imageLoaded && !m_image.isNull()) {
        // Center crop (PreserveAspectCrop)
        qreal srcW = m_image.width();
        qreal srcH = m_image.height();
        qreal dstW = width();
        qreal dstH = height();

        qreal scale = qMax(dstW / srcW, dstH / srcH);
        qreal scaledW = srcW * scale;
        qreal scaledH = srcH * scale;

        QRectF targetRect((dstW - scaledW) / 2.0, (dstH - scaledH) / 2.0, scaledW, scaledH);
        painter->drawImage(targetRect, m_image);
    } else {
        // Draw solid background
        painter->fillRect(rect, m_fallbackColor);

        // Draw fallback SVG icon centered with fallbackIconColor
        if (!m_cachedFallbackIcon.isNull()) {
            QRectF iconRect((width() - m_cachedFallbackIcon.width()) / 2.0,
                            (height() - m_cachedFallbackIcon.height()) / 2.0,
                            m_cachedFallbackIcon.width(),
                            m_cachedFallbackIcon.height());
            painter->drawImage(iconRect, m_cachedFallbackIcon);
        }
    }
}
