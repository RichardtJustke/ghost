import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../"

// Opens the Bluetooth device popup when headphones connect.
// Only reacts to connection changes, so devices already connected at startup don't pop.
Item {
    id: root
    visible: false

    function isHeadphone(d) {
        let icon = (d && d.icon ? d.icon : "").toLowerCase();
        let name = (d ? (d.name || d.deviceName || "") : "").toLowerCase();
        return icon.indexOf("headset") !== -1 || icon.indexOf("headphone") !== -1 || name.indexOf("buds") !== -1 || name.indexOf("pods") !== -1;
    }

    Timer {
        id: openDelay
        // Give PipeWire and the earbuds a moment so the popup opens with real data.
        interval: 1500
        property string mac: ""
        onTriggered: Quickshell.execDetached(["bash", "-c", Caching.ghostDir + "/scripts/qs_manager.sh open btdevice auto:" + mac])
    }

    Repeater {
        model: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.devices : null
        Item {
            required property var modelData
            Connections {
                target: modelData
                ignoreUnknownSignals: true
                function onConnectedChanged() {
                    if (modelData.connected && root.isHeadphone(modelData)) {
                        openDelay.mac = (modelData.address || "").toUpperCase();
                        openDelay.restart();
                    } else if (!modelData.connected && openDelay.mac === (modelData.address || "").toUpperCase()) {
                        openDelay.stop();
                    }
                }
            }
        }
    }
}
