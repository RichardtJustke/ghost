import QtQuick
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: usbSoundRoot

    property bool enabled: Config.getSetting("general", {}).usbSound !== false

    Connections {
        target: Config
        function onSettingsLoaded() {
            usbSoundRoot.enabled = Config.getSetting("general", {}).usbSound !== false;
        }
    }

    onEnabledChanged: {
        watcher.running = false;
        if (enabled) watcher.running = true;
    }

    Component.onCompleted: {
        if (enabled) watcher.running = true;
    }

    Timer {
        id: addDebounce
        interval: 400
        repeat: false
        onTriggered: Sounds.playSfx("network/connect.wav")
    }

    Timer {
        id: removeDebounce
        interval: 400
        repeat: false
        onTriggered: Sounds.playSfx("network/disconnect.wav")
    }

    Process {
        id: watcher
        running: false
        command: ["bash", Caching.qsDir + "/watchers/usb_watch.sh"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let line = data.trim();
                if (line === "add") {
                    removeDebounce.stop();
                    addDebounce.restart();
                } else if (line === "remove") {
                    addDebounce.stop();
                    removeDebounce.restart();
                }
            }
        }
    }
}
