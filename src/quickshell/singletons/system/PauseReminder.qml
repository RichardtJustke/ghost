pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../"

// Global "20-20-20" eye-break reminder: every 20 minutes of continuous
// active use (input activity, not screen-idle), nudge the user to look
// away for 20 seconds. Independent from Idle.qml's dim/lock/suspend
// pipeline -- this uses its own short idle-monitor purely to detect that
// the user stepped away and reset the accumulator, it never dims/locks
// anything itself.
Item {
    id: root

    readonly property int intervalSeconds: 20 * 60
    readonly property int microIdleTimeout: 8

    property bool enabled: Config.getSetting("wellbeing.pauseReminder.enabled", true)
    property int activeSeconds: 0
    readonly property int remainingSeconds: Math.max(0, root.intervalSeconds - root.activeSeconds)

    function setEnabled(value) {
        root.enabled = value === true;
        Config.setSetting("wellbeing.pauseReminder.enabled", root.enabled);
        if (!root.enabled) root.activeSeconds = 0;
    }

    Connections {
        target: Config
        function onSettingsLoaded() {
            root.enabled = Config.getSetting("wellbeing.pauseReminder.enabled", true);
        }
    }

    IdleMonitor {
        id: microIdle
        timeout: root.microIdleTimeout
        enabled: root.enabled
        onIsIdleChanged: if (isIdle) root.activeSeconds = 0
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.enabled && !microIdle.isIdle
        onTriggered: {
            root.activeSeconds += 1;
            if (root.activeSeconds >= root.intervalSeconds) {
                root.activeSeconds = 0;
                root.fireReminder();
            }
        }
    }

    function fireReminder() {
        Quickshell.execDetached([
            "notify-send",
            "-a", I18n.t("guide.wellbeing.settings.pause.notif_app_name"),
            "-i", "view-refresh",
            I18n.t("guide.wellbeing.settings.pause.notif_title"),
            I18n.t("guide.wellbeing.settings.pause.notif_body")
        ]);
    }
}
