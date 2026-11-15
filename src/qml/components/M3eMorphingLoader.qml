import QtQuick
import rhx.theme 1.0

Item {
    id: loaderRoot
    width: size
    height: size
    implicitWidth: size
    implicitHeight: size

    property int size: 38
    property color color: Theme.primary
    property bool running: true
    property bool reduceMotion: Theme.reduceMotion

    property int morphDuration: 550
    property real morphProgress: 0.0

    readonly property var shapes: [
        // 0: Clover (4-petal rounded flower)
        { "name": "Clover",     "b0": 0.72, "b4": 0.28,  "b8": 0.0,   "b12": 0.0 },
        // 1: Soft Burst (8-pointed rounded star)
        { "name": "Soft Burst", "b0": 0.80, "b4": 0.0,   "b8": 0.20,  "b12": 0.0 },
        // 2: Squircle (smooth superellipse rounded square)
        { "name": "Squircle",   "b0": 0.88, "b4": -0.12, "b8": 0.0,   "b12": 0.0 },
        // 3: Scalloped (12-petal medallion)
        { "name": "Scalloped",  "b0": 0.89, "b4": 0.0,   "b8": 0.0,   "b12": 0.11 }
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

    // Continuous slow ambient spin (360 degrees over 12 seconds)
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

    // 90-degree step pulse rotation with Easing.OutBack spring overshoot
    readonly property real pulseAngle: {
        if (loaderRoot.reduceMotion) return 0.0;
        var p = loaderRoot.morphProgress % 4.0;
        if (p < 0) p += 4.0;
        var idx = Math.floor(p);
        var frac = p - idx;

        // Active transition during first 72% of step interval
        var t = (frac < 0.72) ? (frac / 0.72) : 1.0;
        var s = 1.35; // OutBack tension coefficient
        var t1 = t - 1.0;
        var eased = (t < 1.0) ? (t1 * t1 * ((s + 1.0) * t1 + s) + 1.0) : 1.0;
        return idx * 90.0 + eased * 90.0;
    }

    // Elastic breathing scale
    scale: loaderRoot.reduceMotion
        ? 1.0
        : (1.0 + 0.045 * Math.sin(((loaderRoot.morphProgress % 1.0) < 0 ? 0 : (loaderRoot.morphProgress % 1.0)) * Math.PI))

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

        // Smooth cubic step interpolation between adjacent shape harmonics
        var t = rawFrac * rawFrac * (3.0 - 2.0 * rawFrac);

        var sFrom = shapes[idxFrom];
        var sTo = shapes[idxTo];

        canvas.b0 = (1.0 - t) * sFrom.b0 + t * sTo.b0;
        canvas.b4 = (1.0 - t) * sFrom.b4 + t * sTo.b4;
        canvas.b8 = (1.0 - t) * sFrom.b8 + t * sTo.b8;
        canvas.b12 = (1.0 - t) * sFrom.b12 + t * sTo.b12;
        canvas.requestPaint();
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true
        smooth: true
        renderTarget: Canvas.Image
        rotation: loaderRoot.pulseAngle + loaderRoot.slowRotation

        property real b0: 0.72
        property real b4: 0.28
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
            var R = Math.min(cx, cy) - 1.5;

            ctx.beginPath();
            // 144 sampling points for pixel-perfect antialiased smooth curves
            var steps = 144;
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
}
