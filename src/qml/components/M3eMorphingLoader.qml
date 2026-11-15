import QtQuick
import rhx.theme 1.0
import rhx.ui 1.0

Item {
    id: loaderRoot
    width: size
    height: size
    implicitWidth: size
    implicitHeight: size

    property int size: 72
    property color color: Theme.primary
    property color iconColor: Theme.colorOnPrimary
    property string iconSource: "qrc:/assets/icons/app_icon.svg"
    property int iconSize: Math.round(size * 0.38)
    property bool running: true
    property bool reduceMotion: Theme.reduceMotion

    property int morphDuration: 1000
    property real morphProgress: 0.0

    readonly property var shapes: [
        // 0: Clover (4-petal rounded flower)
        { "name": "Clover",     "b0": 0.75, "b4": 0.25,  "b8": 0.0,   "b12": 0.0 },
        // 1: Soft Burst (8-pointed rounded star)
        { "name": "Soft Burst", "b0": 0.81, "b4": 0.0,   "b8": 0.19,  "b12": 0.0 },
        // 2: Squircle (smooth superellipse)
        { "name": "Squircle",   "b0": 0.90, "b4": -0.10, "b8": 0.0,   "b12": 0.0 },
        // 3: Scalloped (12-petal medallion)
        { "name": "Scalloped",  "b0": 0.92, "b4": 0.0,   "b8": 0.0,   "b12": 0.08 }
    ]

    onMorphProgressChanged: {
        updateMorphGeometry();
    }

    onColorChanged: {
        if (canvas) canvas.requestPaint();
    }

    onReduceMotionChanged: {
        updateMorphGeometry();
    }

    NumberAnimation {
        id: morphAnim
        target: loaderRoot
        property: "morphProgress"
        from: 0.0
        to: 4.0
        duration: loaderRoot.morphDuration * 4
        loops: Animation.Infinite
        running: loaderRoot.running && !loaderRoot.reduceMotion
    }

    // Slow continuous 360-degree ambient spin
    property real slowRotation: 0.0
    NumberAnimation {
        id: spinAnim
        target: loaderRoot
        property: "slowRotation"
        from: 0.0
        to: 360.0
        duration: 12000
        loops: Animation.Infinite
        running: loaderRoot.running && !loaderRoot.reduceMotion
    }

    // 90-degree step pulse rotation during each shape morph
    readonly property real pulseAngle: {
        if (loaderRoot.reduceMotion) return 0.0;
        var p = loaderRoot.morphProgress % 4.0;
        if (p < 0) p += 4.0;
        var idx = Math.floor(p);
        var frac = p - idx;
        // Soft emphasized step transition
        var t = (frac < 0.85) ? (frac / 0.85) : 1.0;
        var eased = t * t * (3.0 - 2.0 * t);
        return idx * 90.0 + eased * 90.0;
    }

    // Elastic breathing scale
    scale: loaderRoot.reduceMotion
        ? 1.0
        : (1.0 + 0.045 * Math.sin((loaderRoot.morphProgress % 1.0) * Math.PI))

    function updateMorphGeometry() {
        if (!canvas) return;
        if (loaderRoot.reduceMotion) {
            canvas.b0 = 0.92;
            canvas.b4 = 0.0;
            canvas.b8 = 0.0;
            canvas.b12 = 0.0;
            canvas.requestPaint();
            return;
        }

        var p = loaderRoot.morphProgress % 4.0;
        if (p < 0) p += 4.0;
        var idxFrom = Math.floor(p);
        var idxTo = (idxFrom + 1) % 4;
        var rawFrac = p - idxFrom;

        // Smooth step interpolation
        var t = rawFrac * rawFrac * (3.0 - 2.0 * rawFrac);

        var sFrom = shapes[idxFrom];
        var sTo = shapes[idxTo];

        canvas.b0 = (1.0 - t) * sFrom.b0 + t * sTo.b0;
        canvas.b4 = (1.0 - t) * sFrom.b4 + t * sTo.b4;
        canvas.b8 = (1.0 - t) * sFrom.b8 + t * sTo.b8;
        canvas.b12 = (1.0 - t) * sFrom.b12 + t * sTo.b12;
        canvas.requestPaint();
    }

    // Morphing Vector Shell
    Item {
        id: morphShell
        anchors.fill: parent
        rotation: loaderRoot.pulseAngle + loaderRoot.slowRotation

        Canvas {
            id: canvas
            anchors.fill: parent
            antialiasing: true
            smooth: true
            renderTarget: Canvas.Image

            property real b0: 0.75
            property real b4: 0.25
            property real b8: 0.0
            property real b12: 0.0

            Component.onCompleted: {
                requestPaint();
            }

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                var cx = width / 2.0;
                var cy = height / 2.0;
                var R = Math.min(cx, cy) - 2.0;

                ctx.beginPath();
                var steps = 64;
                for (var i = 0; i <= steps; ++i) {
                    var theta = (i / steps) * 2.0 * Math.PI;
                    var cos4 = Math.cos(4.0 * theta);
                    var cos8 = Math.cos(8.0 * theta);
                    var cos12 = Math.cos(12.0 * theta);
                    var r = R * (b0 + b4 * cos4 + b8 * cos8 + b12 * cos12);
                    var x = cx + r * Math.cos(theta);
                    var y = cy + r * Math.sin(theta);
                    if (i === 0) {
                        ctx.moveTo(x, y);
                    } else {
                        ctx.lineTo(x, y);
                    }
                }
                ctx.closePath();
                ctx.fillStyle = loaderRoot.color;
                ctx.fill();
            }
        }

        // Center Vector Brand Logo (Counter-rotates to stay upright)
        SvgIcon {
            anchors.centerIn: parent
            width: loaderRoot.iconSize
            height: loaderRoot.iconSize
            source: loaderRoot.iconSource
            color: loaderRoot.iconColor
            visible: loaderRoot.iconSource !== ""
            rotation: -morphShell.rotation
        }
    }
}
