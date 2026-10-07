#pragma once

#include <QQuickPaintedItem>
#include <QSvgRenderer>
#include <QColor>
#include <QUrl>
#include <QImage>

class SvgIcon : public QQuickPaintedItem {
    Q_OBJECT
    Q_PROPERTY(QUrl source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)
    Q_PROPERTY(QSize sourceSize READ sourceSize WRITE setSourceSize NOTIFY sourceSizeChanged)

public:
    explicit SvgIcon(QQuickItem *parent = nullptr);

    QUrl source() const { return m_source; }
    void setSource(const QUrl &source);

    QColor color() const { return m_color; }
    void setColor(const QColor &color);

    QSize sourceSize() const { return m_sourceSize; }
    void setSourceSize(const QSize &size);

    void paint(QPainter *painter) override;

signals:
    void sourceChanged();
    void colorChanged();
    void sourceSizeChanged();

private:
    void updateCache();

    QUrl m_source;
    QColor m_color{Qt::white};
    QSize m_sourceSize;
    QSvgRenderer m_renderer;
    bool m_validRenderer{false};
    QImage m_cachedImage;
    QSize m_cachedSize;
    QColor m_cachedColor;
};
