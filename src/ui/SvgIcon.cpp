#include "SvgIcon.h"
#include <QPainter>
#include <QFileInfo>

SvgIcon::SvgIcon(QQuickItem *parent)
    : QQuickPaintedItem(parent)
{
    setAntialiasing(true);
    setSmooth(true);
}

void SvgIcon::setSource(const QUrl &source)
{
    if (m_source == source) return;
    m_source = source;

    QString path;
    if (m_source.scheme() == "qrc") {
        path = ":" + m_source.path();
    } else if (m_source.isLocalFile()) {
        path = m_source.toLocalFile();
    } else {
        path = m_source.toString();
        if (path.startsWith("qrc:/")) {
            path = ":" + path.mid(4);
        }
    }

    m_validRenderer = m_renderer.load(path);
    m_cachedSize = QSize();
    update();
    emit sourceChanged();
}

void SvgIcon::setColor(const QColor &color)
{
    if (m_color == color) return;
    m_color = color;
    m_cachedColor = QColor();
    update();
    emit colorChanged();
}

#include <QQuickWindow>

void SvgIcon::setSourceSize(const QSize &size)
{
    if (m_sourceSize == size) return;
    m_sourceSize = size;
    m_cachedSize = QSize();
    update();
    emit sourceSizeChanged();
}

void SvgIcon::updateCache()
{
    if (width() <= 0 || height() <= 0 || !m_validRenderer) {
        m_cachedImage = QImage();
        return;
    }

    qreal dpr = window() ? window()->devicePixelRatio() : 1.0;
    if (dpr < 1.0) dpr = 1.0;

    int pixelW = qRound(width() * dpr);
    int pixelH = qRound(height() * dpr);

    int targetW = pixelW;
    int targetH = pixelH;

    if (m_sourceSize.isValid() && m_sourceSize.width() > 0 && m_sourceSize.height() > 0) {
        targetW = qMax(targetW, qRound(m_sourceSize.width() * dpr));
        targetH = qMax(targetH, qRound(m_sourceSize.height() * dpr));
    }

    if (m_cachedSize == QSize(pixelW, pixelH) && m_cachedColor == m_color && !m_cachedImage.isNull()) {
        return;
    }

    QImage renderImage(targetW, targetH, QImage::Format_ARGB32_Premultiplied);
    renderImage.fill(Qt::transparent);

    {
        QPainter p(&renderImage);
        p.setRenderHint(QPainter::Antialiasing, true);
        p.setRenderHint(QPainter::SmoothPixmapTransform, true);

        QRectF destRect(0, 0, targetW, targetH);
        QSizeF defSize = m_renderer.defaultSize();
        if (defSize.isValid() && defSize.width() > 0 && defSize.height() > 0) {
            qreal s = qMin(static_cast<qreal>(targetW) / defSize.width(), static_cast<qreal>(targetH) / defSize.height());
            qreal rw = defSize.width() * s;
            qreal rh = defSize.height() * s;
            destRect = QRectF((targetW - rw) / 2.0, (targetH - rh) / 2.0, rw, rh);
        }

        m_renderer.render(&p, destRect);
        QColor tintColor = m_color.isValid() ? m_color : QColor(Qt::white);
        p.setCompositionMode(QPainter::CompositionMode_SourceIn);
        p.fillRect(renderImage.rect(), tintColor);
    }

    if (targetW != pixelW || targetH != pixelH) {
        m_cachedImage = renderImage.scaled(pixelW, pixelH, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    } else {
        m_cachedImage = renderImage;
    }

    m_cachedImage.setDevicePixelRatio(dpr);
    m_cachedSize = QSize(pixelW, pixelH);
    m_cachedColor = m_color;
}

void SvgIcon::paint(QPainter *painter)
{
    if (!m_validRenderer || width() <= 0 || height() <= 0) return;

    updateCache();
    if (!m_cachedImage.isNull()) {
        painter->setRenderHint(QPainter::Antialiasing, true);
        painter->setRenderHint(QPainter::SmoothPixmapTransform, true);
        painter->drawImage(QRectF(0, 0, width(), height()), m_cachedImage);
    }
}
