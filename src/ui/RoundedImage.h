#pragma once

#include <QQuickPaintedItem>
#include <QSvgRenderer>
#include <QImage>
#include <QUrl>
#include <QColor>
#include <atomic>

class RoundedImage : public QQuickPaintedItem {
    Q_OBJECT
    Q_PROPERTY(QUrl source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(qreal radius READ radius WRITE setRadius NOTIFY radiusChanged)
    Q_PROPERTY(QColor fallbackColor READ fallbackColor WRITE setFallbackColor NOTIFY fallbackColorChanged)
    Q_PROPERTY(QUrl fallbackIcon READ fallbackIcon WRITE setFallbackIcon NOTIFY fallbackIconChanged)
    Q_PROPERTY(QColor fallbackIconColor READ fallbackIconColor WRITE setFallbackIconColor NOTIFY fallbackIconColorChanged)
    Q_PROPERTY(int fallbackIconSize READ fallbackIconSize WRITE setFallbackIconSize NOTIFY fallbackIconSizeChanged)
    Q_PROPERTY(bool fullResolution READ fullResolution WRITE setFullResolution NOTIFY fullResolutionChanged)

public:
    explicit RoundedImage(QQuickItem *parent = nullptr);

    QUrl source() const { return m_source; }
    void setSource(const QUrl &source);

    bool fullResolution() const { return m_fullResolution; }
    void setFullResolution(bool full);

    qreal radius() const { return m_radius; }
    void setRadius(qreal r);

    QColor fallbackColor() const { return m_fallbackColor; }
    void setFallbackColor(const QColor &c);

    QUrl fallbackIcon() const { return m_fallbackIcon; }
    void setFallbackIcon(const QUrl &icon);

    QColor fallbackIconColor() const { return m_fallbackIconColor; }
    void setFallbackIconColor(const QColor &c);

    int fallbackIconSize() const { return m_fallbackIconSize; }
    void setFallbackIconSize(int s);

    void setImage(const QImage &img);
    quint64 requestId() const { return m_requestId.load(std::memory_order_relaxed); }

    void paint(QPainter *painter) override;

protected:
    void geometryChange(const QRectF &newGeometry, const QRectF &oldGeometry) override;

signals:
    void sourceChanged();
    void radiusChanged();
    void fallbackColorChanged();
    void fallbackIconChanged();
    void fallbackIconColorChanged();
    void fallbackIconSizeChanged();
    void fullResolutionChanged();

private:
    void reloadImage();
    void updateFallbackIcon();

    QUrl m_source;
    bool m_fullResolution{false};
    qreal m_radius{12.0};
    QColor m_fallbackColor{QColor("#2A2D2C")};
    QUrl m_fallbackIcon;
    QColor m_fallbackIconColor{QColor("#5FE3D9")};
    int m_fallbackIconSize{24};

    QImage m_image;
    bool m_imageLoaded{false};
    QSvgRenderer m_svgRenderer;
    bool m_svgValid{false};
    QImage m_cachedFallbackIcon;
    std::atomic<quint64> m_requestId{0};
};
