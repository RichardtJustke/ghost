import QtQuick
import "../"

// Battery ring with an earbud (or over-ear headphone) drawn inside. percent < 0 means "unknown" (empty ring).
Item {
    id: root

    property real percent: -1
    property color ringColor: ThemeBackend.green
    property color trackColor: ThemeBackend.surface0
    property real ringWidth: Math.max(4, width * 0.055)
    property bool mirrored: false
    // "bud" for earbuds, "headphone" for over-ear headphones (AirPods Max style).
    property string art: "bud"
    property real artOpacity: 1.0

    property color bodyColor: Qt.lighter(ThemeBackend.text, 1.08)
    property color shadeColor: Qt.darker(bodyColor, 1.12)
    property color tipColor: Qt.darker(bodyColor, 1.22)
    property color meshColor: ThemeBackend.overlay1

    property real shownPercent: Math.max(0, percent)
    Behavior on shownPercent { NumberAnimation { duration: 900; easing.type: Easing.OutQuint } }

    onShownPercentChanged: ring.requestPaint()
    onRingColorChanged: ring.requestPaint()
    onTrackColorChanged: ring.requestPaint()
    onBodyColorChanged: bud.requestPaint()
    onMirroredChanged: bud.requestPaint()
    onArtChanged: bud.requestPaint()

    Canvas {
        id: ring
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            let cx = width / 2, cy = height / 2;
            let r = Math.min(width, height) / 2 - root.ringWidth / 2;
            ctx.lineWidth = root.ringWidth;
            ctx.lineCap = "round";

            ctx.strokeStyle = root.trackColor;
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, Math.PI * 2);
            ctx.stroke();

            if (root.shownPercent <= 0) return;
            ctx.strokeStyle = root.ringColor;
            ctx.beginPath();
            ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.min(1, root.shownPercent / 100));
            ctx.stroke();
        }
    }

    Canvas {
        id: bud
        anchors.centerIn: parent
        width: parent.width * 0.62
        height: width
        opacity: root.artOpacity
        Behavior on opacity { NumberAnimation { duration: 300 } }
        onWidthChanged: requestPaint()
        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            let k = width / 60;
            ctx.save();
            if (root.mirrored) {
                ctx.translate(width, 0);
                ctx.scale(-1, 1);
            }
            ctx.scale(k, k);

            function oval(cx, cy, rx, ry, color) {
                ctx.fillStyle = color;
                ctx.beginPath();
                ctx.ellipse(cx - rx, cy - ry, rx * 2, ry * 2);
                ctx.fill();
            }

            function box(x, y, w, h, r, color) {
                ctx.fillStyle = color;
                ctx.beginPath();
                ctx.roundedRect(x, y, w, h, r, r);
                ctx.fill();
            }

            if (root.art === "headphone") {
                // Steel frame with the mesh canopy hanging just under it.
                ctx.lineCap = "round";
                ctx.strokeStyle = root.shadeColor;
                ctx.lineWidth = 2.4;
                ctx.beginPath();
                ctx.arc(30, 31, 20, Math.PI, Math.PI * 2);
                ctx.stroke();
                ctx.strokeStyle = root.meshColor;
                ctx.lineWidth = 4.2;
                ctx.beginPath();
                ctx.arc(30, 31, 16, Math.PI * 1.08, Math.PI * 1.92);
                ctx.stroke();

                // Ear cups, cushions facing inward, and the crown on the right cup.
                box(4, 27, 14, 24, 6, root.bodyColor);
                box(42, 27, 14, 24, 6, root.bodyColor);
                box(16, 30, 4, 18, 2, root.tipColor);
                box(40, 30, 4, 18, 2, root.tipColor);
                box(48, 23, 4, 5, 1.2, root.shadeColor);
            } else {
                oval(32, 32, 20, 17, root.bodyColor);
                oval(36, 30, 11, 9, root.shadeColor);
                oval(14, 26, 8, 7, root.tipColor);
                oval(13, 26, 3.2, 3.2, root.meshColor);
                oval(40, 38, 1.8, 1.8, root.meshColor);
            }
            ctx.restore();
        }
    }
}
