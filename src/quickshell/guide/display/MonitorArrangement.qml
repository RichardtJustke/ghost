import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../../"
import "../../reusables"

Rectangle {
    id: root

    required property var rootObj
    required property var monitorsList
    required property string compositor
    required property var positionResolver
    required property var arrangementOptions
    required property string currentArrangementValue

    signal positionDragged(string monName, real x, real y)
    signal applyRequested(string value)

    function s(v) {
        return rootObj ? rootObj.s(v) : v;
    }

    clip: true
    radius: ThemeBackend.borderRadius
    color: Qt.alpha(ThemeBackend.surface0, 0.4)
    border.color: Qt.alpha(ThemeBackend.surface1, 0.4)
    border.width: 1
    implicitHeight: bodyCol.implicitHeight + s(24)

    property var draftPositions: ({})
    property int draggingIndex: -1
    property bool identifyActive: false

    function seedDraft() {
        let np = {};
        for (let i = 0; i < root.monitorsList.length; i++) {
            let name = root.monitorsList[i].name;
            if (root.draggingIndex >= 0 && root.monitorsList[root.draggingIndex] && root.monitorsList[root.draggingIndex].name === name) continue;
            let p = root.positionResolver ? root.positionResolver(name) : { x: 0, y: 0 };
            np[name] = { x: p.x, y: p.y };
        }
        root.draftPositions = np;
    }

    Component.onCompleted: root.seedDraft()

    onMonitorsListChanged: {
        if (root.draggingIndex < 0) root.seedDraft();
    }

    readonly property var layoutMonitors: {
        let list = [];
        for (let i = 0; i < root.monitorsList.length; i++) {
            let m = root.monitorsList[i];
            let dims = m.dimensions ? m.dimensions.split("x") : ["1920", "1080"];
            let w = parseInt(dims[0]) || 1920;
            let h = parseInt(dims[1]) || 1080;
            let scale = m.scale ? m.scale : 1.0;
            let lw = w / scale;
            let lh = h / scale;
            let p = root.draftPositions[m.name];
            let px = p ? p.x : (m.x !== undefined ? m.x : 0);
            let py = p ? p.y : (m.y !== undefined ? m.y : 0);
            list.push({ name: m.name, index: i, lw: lw, lh: lh, x: px, y: py, active: m.active !== false });
        }
        return list;
    }

    readonly property real boundsMinX: layoutMonitors.length ? Math.min.apply(null, layoutMonitors.map(m => m.x)) : 0
    readonly property real boundsMinY: layoutMonitors.length ? Math.min.apply(null, layoutMonitors.map(m => m.y)) : 0
    readonly property real boundsMaxX: layoutMonitors.length ? Math.max.apply(null, layoutMonitors.map(m => m.x + m.lw)) : 1
    readonly property real boundsMaxY: layoutMonitors.length ? Math.max.apply(null, layoutMonitors.map(m => m.y + m.lh)) : 1
    readonly property real totalLogicalW: Math.max(1, boundsMaxX - boundsMinX)
    readonly property real totalLogicalH: Math.max(1, boundsMaxY - boundsMinY)

    property real frozenScale: 1.0
    property real frozenMinX: 0
    property real frozenMinY: 0
    property real frozenOffsetX: 0
    property real frozenOffsetY: 0

    function computeCanvasScale(availW, availH) {
        if (totalLogicalW <= 0 || totalLogicalH <= 0) return 0.05;
        return Math.min(availW / totalLogicalW, availH / totalLogicalH, 0.35);
    }

    readonly property real liveCanvasScale: computeCanvasScale(canvasFrame.width - s(20), canvasFrame.height - s(20))
    readonly property real activeCanvasScale: draggingIndex >= 0 ? frozenScale : liveCanvasScale
    readonly property real activeMinX: draggingIndex >= 0 ? frozenMinX : boundsMinX
    readonly property real activeMinY: draggingIndex >= 0 ? frozenMinY : boundsMinY
    readonly property real activeOffsetX: draggingIndex >= 0 ? frozenOffsetX : Math.max(0, (canvasFrame.width - totalLogicalW * liveCanvasScale) / 2)
    readonly property real activeOffsetY: draggingIndex >= 0 ? frozenOffsetY : Math.max(0, (canvasFrame.height - totalLogicalH * liveCanvasScale) / 2)

    function boxRectFor(m) {
        return {
            rx: root.activeOffsetX + (m.x - root.activeMinX) * root.activeCanvasScale,
            ry: root.activeOffsetY + (m.y - root.activeMinY) * root.activeCanvasScale,
            rw: m.lw * root.activeCanvasScale,
            rh: m.lh * root.activeCanvasScale
        };
    }

    ColumnLayout {
        id: bodyCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.s(12)
        spacing: root.s(10)

        RowLayout {
            Layout.fillWidth: true
            spacing: root.s(8)

            Text {
                text: I18n.t("guide.display.arrangement.title", "Disposição das telas")
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(14)
                font.bold: true
                color: ThemeBackend.text
            }

            Item { Layout.fillWidth: true }
        }

        Text {
            Layout.fillWidth: true
            text: I18n.t("guide.display.arrangement.desc", "Arraste os monitores para combinar com a posição física deles")
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(11)
            color: ThemeBackend.subtext0
            wrapMode: Text.WordWrap
        }

        Rectangle {
            id: canvasFrame
            Layout.fillWidth: true
            Layout.preferredHeight: root.s(150)
            radius: root.s(8)
            color: Qt.alpha(ThemeBackend.crust, 0.55)
            border.width: 1
            border.color: ThemeBackend.surface1
            clip: true

            Repeater {
                model: root.monitorsList
                delegate: Rectangle {
                    id: monBox
                    required property var modelData
                    required property int index

                    property var lm: (index >= 0 && index < root.layoutMonitors.length) ? root.layoutMonitors[index] : { lw: 100, lh: 100, x: 0, y: 0, active: true, index: index, name: modelData.name }
                    property var geo: root.boxRectFor(lm)
                    property bool isDragging: root.draggingIndex === index

                    x: geo.rx
                    y: geo.ry
                    width: Math.max(root.s(24), geo.rw)
                    height: Math.max(root.s(18), geo.rh)
                    z: isDragging ? 10 : 1
                    radius: root.s(4)
                    color: lm.active ? Qt.alpha(ThemeBackend.mauve, isDragging ? 0.55 : 0.32) : Qt.alpha(ThemeBackend.surface2, 0.4)
                    border.width: isDragging ? 2 : 1
                    border.color: isDragging ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.text, 0.25)

                    scale: isDragging ? 1.03 : 1.0
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuint } }
                    Behavior on x { enabled: !isDragging; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on y { enabled: !isDragging; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on width { enabled: !isDragging; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on height { enabled: !isDragging; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 0
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: (monBox.lm.index + 1).toString()
                            font.family: ThemeBackend.fontFamily
                            font.bold: true
                            font.pixelSize: Math.max(root.s(11), Math.min(root.s(20), monBox.height * 0.4))
                            color: "#ffffff"
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            visible: monBox.width > root.s(60)
                            text: modelData.name
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(9)
                            color: Qt.alpha("#ffffff", 0.85)
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true

                property real pressOffsetX: 0
                property real pressOffsetY: 0

                function hitTest(px, py) {
                    for (let i = root.layoutMonitors.length - 1; i >= 0; i--) {
                        let m = root.layoutMonitors[i];
                        let g = root.boxRectFor(m);
                        if (px >= g.rx && px <= g.rx + g.rw && py >= g.ry && py <= g.ry + g.rh) return i;
                    }
                    return -1;
                }

                cursorShape: root.draggingIndex >= 0 ? Qt.ClosedHandCursor : (hitTest(mouseX, mouseY) >= 0 ? Qt.OpenHandCursor : Qt.ArrowCursor)

                onPressed: mouse => {
                    let idx = hitTest(mouse.x, mouse.y);
                    if (idx < 0) return;
                    root.draggingIndex = idx;
                    root.frozenScale = root.liveCanvasScale;
                    root.frozenMinX = root.boundsMinX;
                    root.frozenMinY = root.boundsMinY;
                    root.frozenOffsetX = Math.max(0, (canvasFrame.width - root.totalLogicalW * root.frozenScale) / 2);
                    root.frozenOffsetY = Math.max(0, (canvasFrame.height - root.totalLogicalH * root.frozenScale) / 2);
                    let g = root.boxRectFor(root.layoutMonitors[idx]);
                    pressOffsetX = mouse.x - g.rx;
                    pressOffsetY = mouse.y - g.ry;
                }

                onPositionChanged: mouse => {
                    if (root.draggingIndex < 0) return;
                    let m = root.layoutMonitors[root.draggingIndex];
                    let rawRx = mouse.x - pressOffsetX;
                    let rawRy = mouse.y - pressOffsetY;
                    let rawLx = root.frozenMinX + (rawRx - root.frozenOffsetX) / root.frozenScale;
                    let rawLy = root.frozenMinY + (rawRy - root.frozenOffsetY) / root.frozenScale;

                    let threshold = root.s(28) / root.frozenScale;
                    let bestDx = threshold;
                    let bestDy = threshold;
                    let snapX = rawLx;
                    let snapY = rawLy;

                    for (let i = 0; i < root.layoutMonitors.length; i++) {
                        if (i === root.draggingIndex) continue;
                        let o = root.layoutMonitors[i];

                        let xCandidates = [o.x, o.x + o.lw, o.x - m.lw, o.x + o.lw - m.lw, o.x + o.lw / 2 - m.lw / 2];
                        for (let j = 0; j < xCandidates.length; j++) {
                            let diff = Math.abs(xCandidates[j] - rawLx);
                            if (diff < bestDx) { bestDx = diff; snapX = xCandidates[j]; }
                        }

                        let yCandidates = [o.y, o.y + o.lh, o.y - m.lh, o.y + o.lh - m.lh, o.y + o.lh / 2 - m.lh / 2];
                        for (let j = 0; j < yCandidates.length; j++) {
                            let diff = Math.abs(yCandidates[j] - rawLy);
                            if (diff < bestDy) { bestDy = diff; snapY = yCandidates[j]; }
                        }
                    }

                    let np = Object.assign({}, root.draftPositions);
                    np[m.name] = { x: Math.round(snapX), y: Math.round(snapY) };
                    root.draftPositions = np;
                }

                onReleased: {
                    if (root.draggingIndex < 0) return;
                    let m = root.layoutMonitors[root.draggingIndex];
                    let finalPos = root.draftPositions[m.name];
                    root.draggingIndex = -1;
                    if (finalPos) {
                        root.positionDragged(m.name, finalPos.x, finalPos.y);
                    }
                }

                onCanceled: {
                    root.draggingIndex = -1;
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: root.s(10)

            ClickButton {
                buttonText: I18n.t("guide.display.arrangement.identify", "Identificar")
                buttonIcon: "󰍹"
                textFontSize: root.s(12)
                iconFontSize: root.s(14)
                implicitHeight: root.s(32)
                accentColor: ThemeBackend.surface1
                textColor: ThemeBackend.text
                onClicked: {
                    root.identifyActive = true;
                    identifyTimer.restart();
                }
            }

            Item { Layout.fillWidth: true }

            Dropdown {
                id: modeDropdown
                implicitWidth: root.s(240)
                implicitHeight: root.s(32)
                fontPixelSize: root.s(12)
                options: root.arrangementOptions.map(o => o.label)
                currentIndex: {
                    let idx = root.arrangementOptions.findIndex(o => o.value === root.currentArrangementValue);
                    return idx >= 0 ? idx : (root.arrangementOptions.length > 1 ? 1 : 0);
                }
                accentColor: ThemeBackend.mauve
                baseColor: ThemeBackend.surface1
                dropdownColor: ThemeBackend.crust
                borderColor: ThemeBackend.surface2
                textColor: ThemeBackend.text
            }

            ClickButton {
                buttonText: I18n.t("guide.display.arrangement.apply", "Aplicar")
                textFontSize: root.s(12)
                implicitHeight: root.s(32)
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.crust
                onClicked: {
                    let opt = root.arrangementOptions[modeDropdown.currentIndex];
                    if (opt) root.applyRequested(opt.value);
                }
            }
        }
    }

    Timer {
        id: identifyTimer
        interval: 2200
        repeat: false
        onTriggered: root.identifyActive = false
    }

    Scope {
        Variants {
            model: Quickshell.screens

            PanelWindow {
                id: identifyWindow
                required property var modelData
                screen: modelData

                readonly property int monIndex: root.monitorsList.findIndex(m => m.name === modelData.name)

                visible: root.identifyActive && monIndex >= 0
                color: "transparent"

                anchors { top: true; bottom: true; left: true; right: true }

                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.exclusionMode: ExclusionMode.Ignore
                WlrLayershell.namespace: "ghost-monitor-identify"

                mask: Region {}

                Rectangle {
                    x: root.s(24)
                    y: root.s(24)
                    width: root.s(120)
                    height: root.s(120)
                    radius: root.s(16)
                    color: Qt.alpha(ThemeBackend.crust, 0.85)
                    border.width: 2
                    border.color: ThemeBackend.mauve

                    Text {
                        anchors.centerIn: parent
                        text: (identifyWindow.monIndex + 1).toString()
                        font.family: ThemeBackend.fontFamily
                        font.bold: true
                        font.pixelSize: root.s(56)
                        color: ThemeBackend.text
                    }
                }
            }
        }
    }
}
