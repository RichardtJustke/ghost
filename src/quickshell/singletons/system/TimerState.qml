pragma Singleton
import QtQuick
import "../../"

QtObject {
    id: root

    property bool isActive: false
    property string timeFormatted: ""
    property string icon: ""
    property string colorType: "mauve"

    // -1 = no pomodoro session loaded, 0 = focus, 1 = short break, 2 = long break
    property int pomoPhase: -1
    property bool pomoRunning: false

    property int _focusSoundHandle: -1

    readonly property var focusSoundFiles: ({
        rain: "ambient/rain.wav",
        lofi: "ambient/lofi.wav",
        "white-noise": "ambient/white-noise.wav"
    })

    function _stopFocusSound() {
        if (root._focusSoundHandle !== -1) {
            Sounds.stopSfx(root._focusSoundHandle);
            root._focusSoundHandle = -1;
        }
    }

    function _syncFocusSound() {
        let shouldPlay = root.pomoRunning && root.pomoPhase === 0 && Config.getSetting("wellbeing.focusSound.enabled", false);
        if (!shouldPlay) {
            root._stopFocusSound();
            return;
        }
        if (root._focusSoundHandle !== -1) return;
        let track = Config.getSetting("wellbeing.focusSound.track", "lofi");
        let file = root.focusSoundFiles[track] || root.focusSoundFiles["lofi"];
        root._focusSoundHandle = Sounds.playUntilStopped(file, 0.55, true);
    }

    // Called by the Wellbeing settings screen right after the user toggles
    // the feature or switches tracks, so the change takes effect immediately
    // instead of waiting for the next pomodoro phase/running transition.
    function refreshFocusSound() {
        root._stopFocusSound();
        root._syncFocusSound();
    }

    onPomoRunningChanged: root._syncFocusSound()
    onPomoPhaseChanged: root._syncFocusSound()
}
