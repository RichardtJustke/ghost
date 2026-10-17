pragma Singleton
import QtQuick
import QtQml
import Quickshell
import Quickshell.Services.Pipewire

import "AudioCache.js" as AudioCache

Singleton {
    id: root

    function pipewireNodes() {
        try {
            const model = Pipewire.nodes;
            const list = model ? model.values : null;
            return list ? list : [];
        } catch (e) {
            return [];
        }
    }

    property var trackedNodes: []

    function refreshTrackedNodes() {
        const list = root.pipewireNodes();
        root.trackedNodes = list ? list : [];
    }

    Connections {
        target: Pipewire.nodes ?? null
        ignoreUnknownSignals: true
        function onValuesChanged() {
            root.refreshTrackedNodes();
        }
    }

    Component.onCompleted: {
        root.refreshTrackedNodes();
        root.refreshActiveStream();
    }

    PwObjectTracker {
        objects: root.trackedNodes
    }

    function isGhostStream(node) {
        if (!node || !node.properties) return false;
        let p = node.properties;
        let appId = p["application.id"] || "";
        let appName = p["application.name"] || "";
        if (appId === "ghost-sfx" || appId === "ghost" || appId === "org.ghost.sfx") return true;
        if (appName === "ghost-sfx" || appName === "ghost") return true;
        let mediaFile = p["media.filename"] || p["media.name"] || "";
        if (mediaFile.indexOf("assets/sounds/") !== -1) return true;
        return false;
    }

    readonly property var outputs: {
        let arr = [];
        for (const n of root.pipewireNodes()) {
            if (!n.isStream && n.isSink && n.audio) arr.push(n);
        }
        return AudioCache.updateOutputs(arr);
    }

    readonly property var inputs: {
        let arr = [];
        for (const n of root.pipewireNodes()) {
            if (!n.isStream && !n.isSink && n.audio
                && n.properties?.["device.class"] !== "monitor"
                && !n.name?.endsWith(".monitor")) {
                arr.push(n);
            }
        }
        return AudioCache.updateInputs(arr);
    }

    readonly property var apps: {
        let arr = [];
        for (const n of root.pipewireNodes()) {
            if (n.isStream && n.audio
                && n.properties?.["application.id"] !== "org.PulseAudio.pavucontrol"
                && !isGhostStream(n)) {
                arr.push(n);
            }
        }
        return AudioCache.updateApps(arr);
    }

    function computeHasActiveStream(list) {
        try {
            for (const n of list ?? []) {
                if (!n || !n.audio) continue;
                let p = n.properties;
                if (!p || p["media.class"] !== "Stream/Output/Audio") continue;
                let corked = p["pulse.corked"];
                if (corked === "true" || corked === true) continue;
                if (n.audio.muted || (n.audio.volume !== undefined && n.audio.volume <= 0.001)) continue;
                return true;
            }
        } catch (e) {
        }
        return false;
    }

    property bool hasActiveStream: false

    function refreshActiveStream() {
        const active = root.computeHasActiveStream(root.apps) === true;
        if (root.hasActiveStream !== active) root.hasActiveStream = active;
    }

    onAppsChanged: root.refreshActiveStream()

    Instantiator {
        model: root.apps

        delegate: QtObject {
            id: streamWatch
            required property var modelData

            property Connections nodeConnections: Connections {
                target: streamWatch.modelData
                ignoreUnknownSignals: true
                function onPropertiesChanged() { root.refreshActiveStream(); }
            }

            property Connections audioConnections: Connections {
                target: streamWatch.modelData ? streamWatch.modelData.audio : null
                ignoreUnknownSignals: true
                function onMutedChanged() { root.refreshActiveStream(); }
                function onVolumesChanged() { root.refreshActiveStream(); }
            }
        }
    }

    readonly property PwNode defaultSink: Pipewire.defaultAudioSink
    readonly property PwNode defaultSource: Pipewire.defaultAudioSource

    function setDefaultOutput(node) {
        if (node) Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultInput(node) {
        if (node) Pipewire.preferredDefaultAudioSource = node;
    }

    readonly property string combinedSinkName: "ghost_combined"

    readonly property var bluetoothOutputs: root.outputs.filter(n => (n.name || "").startsWith("bluez_output"))

    readonly property PwNode combinedOutput: {
        for (const n of root.outputs) {
            if (n.name === root.combinedSinkName) return n;
        }
        return null;
    }

    // Plays the same audio on every connected Bluetooth output at once.
    function combineBluetoothOutputs(description) {
        const slaves = root.bluetoothOutputs.map(n => n.name);
        if (slaves.length < 2 || root.combinedOutput) return;
        const desc = (description || root.combinedSinkName).replace(/["']/g, "");
        Quickshell.execDetached(["sh", "-c",
            "pactl load-module module-combine-sink sink_name=\"$1\" slaves=\"$2\" \"$3\" && pactl set-default-sink \"$1\"",
            "sh", root.combinedSinkName, slaves.join(","), "sink_properties='device.description=\"" + desc + "\"'"]);
    }

    function uncombineOutputs() {
        Quickshell.execDetached(["sh", "-c",
            "pactl list short modules | awk -v n=\"sink_name=$1\" 'index($0, n) { print $1 }' | xargs -r -n1 pactl unload-module",
            "sh", root.combinedSinkName]);
    }

    function toggleMute(node) {
        if (node && node.audio) node.audio.muted = !node.audio.muted;
    }

    function setVolume(node, pct) {
        if (node && node.audio) node.audio.volume = Math.max(0, Math.min(1.5, pct / 100.0));
    }

    function getNodeName(node) {
        if (!node) return "";
        return node.properties?.["device.description"] || node.description || node.name || "Unknown Device";
    }

    function getNodeSubDesc(node) {
        if (!node) return "";
        if (node.isStream) {
            return node.properties?.["media.name"] || node.properties?.["window.title"] || node.properties?.["media.role"] || "Audio Stream";
        }
        return node.name || "Unknown";
    }

    function getNodeAppName(node) {
        if (!node) return "";
        return node.properties?.["application.name"] || node.properties?.["application.process.binary"] || node.description || "Unknown App";
    }
}
