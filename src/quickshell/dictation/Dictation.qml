import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"

// Voice dictation: records the microphone, sends it to dictation.sh and shows a
// small pill at the bottom of the screen while it works. Created on first use
// by Shell.qml and idle (no processes) between dictations.
PanelWindow {
    id: root

    // idle | recording | processing | done | error
    property string phase: "idle"
    property string mode: "type"
    property string message: ""
    property int elapsed: 0
    readonly property string audioFile: Caching.getRunDir("dictation") + "/dictation.wav"
    readonly property int maxSeconds: 300

    function s(v) { return (typeof Scaler !== "undefined") ? Scaler.s(v) : v; }

    function toggle(newMode) {
        if (root.phase === "recording") {
            root.stop();
        } else if (root.phase !== "processing") {
            root.start(newMode === "journal" ? "journal" : "type");
        }
    }

    function start(newMode) {
        root.mode = newMode;
        root.elapsed = 0;
        root.message = "";
        root.phase = "recording";
        hideTimer.stop();
        recorder.running = true;
        Sounds.playSfx("reusables/toggle/sfx.wav", 0.6);
    }

    function stop() {
        if (root.phase !== "recording") return;
        root.phase = "processing";
        // SIGINT lets pw-record finish the WAV header before exiting
        recorder.signal(2);
    }

    function cancel() {
        if (root.phase === "recording") {
            root.phase = "idle";
            recorder.signal(2);
        }
    }

    function finish(phase, msg) {
        root.phase = phase;
        root.message = msg;
        hideTimer.interval = phase === "error" ? 4000 : 2200;
        hideTimer.restart();
    }

    Process {
        id: recorder
        command: ["pw-record", "--rate", "16000", "--channels", "1", "--format", "s16", root.audioFile]
        onExited: (code, status) => {
            if (root.phase === "processing") {
                processor.running = true;
            } else if (root.phase === "recording") {
                root.finish("error", "Não consegui acessar o microfone");
            }
        }
    }

    Process {
        id: processor
        command: ["bash", Caching.ghostDir + "/scripts/dictation.sh", "process", root.audioFile, root.mode]
        stdout: StdioCollector { id: procOut }
        stderr: StdioCollector { id: procErr }
        onExited: (code, status) => {
            if (code === 0) {
                let t = procOut.text.trim();
                root.finish("done", root.mode === "journal" ? "Salvo no diário" : (t.length > 60 ? t.substring(0, 60) + "…" : t));
            } else {
                root.finish("error", procErr.text.trim().split("\n").pop() || "Falha no ditado");
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.phase === "recording"
        onTriggered: {
            root.elapsed++;
            if (root.elapsed >= root.maxSeconds) root.stop();
        }
    }

    Timer {
        id: hideTimer
        onTriggered: root.phase = "idle"
    }

    // ── Window ────────────────────────────────────────────────
    visible: root.phase !== "idle" || pill.opacity > 0.01
    WlrLayershell.namespace: "ghost-dictation"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    anchors.bottom: true
    margins.bottom: s(48)
    implicitWidth: pill.width + s(8)
    implicitHeight: pill.height + s(8)

    readonly property color accent: root.phase === "error" ? ThemeBackend.red
        : root.phase === "done" ? ThemeBackend.green
        : root.phase === "processing" ? ThemeBackend.yellow
        : ThemeBackend.red

    Rectangle {
        id: pill
        anchors.centerIn: parent
        height: s(40)
        width: row.implicitWidth + s(32)
        radius: height / 2
        color: ThemeBackend.base
        border.width: 1
        border.color: Qt.alpha(root.accent, 0.6)
        opacity: root.phase === "idle" ? 0 : 1
        scale: root.phase === "idle" ? 0.9 : 1
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
        Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: s(10)

            Rectangle {
                id: dot
                anchors.verticalCenter: parent.verticalCenter
                width: s(10); height: width; radius: width / 2
                color: root.accent
                SequentialAnimation on opacity {
                    running: root.phase === "recording" || root.phase === "processing"
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) dot.opacity = 1
                    NumberAnimation { to: 0.25; duration: 600 }
                    NumberAnimation { to: 1; duration: 600 }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: ThemeBackend.text
                font.family: ThemeBackend.fontFamily
                font.pixelSize: s(14)
                text: {
                    if (root.phase === "recording") {
                        let mm = Math.floor(root.elapsed / 60), ss = root.elapsed % 60;
                        return (root.mode === "journal" ? "Diário  " : "Ditando  ") + mm + ":" + (ss < 10 ? "0" : "") + ss;
                    }
                    if (root.phase === "processing") return root.mode === "journal" ? "Organizando…" : "Transcrevendo…";
                    return root.message;
                }
            }
        }
    }
}
