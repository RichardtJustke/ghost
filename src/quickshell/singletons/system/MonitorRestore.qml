pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../../"

// The display settings tab changes outputs through compositor IPC, which only
// lasts for the running session: a config reload, relogin or reconnect falls
// back to the compositor's own config. This re-applies the scale and position
// saved in display.monitors so they outlive that, without touching the user's
// compositor config files.
Item {
    id: root
    visible: false

    readonly property string compositor: {
        let de = (SystemInfo.desktopEnv || "").toLowerCase();
        if (de.indexOf("niri") !== -1) return "niri";
        if (de.indexOf("sway") !== -1) return "sway";
        if (de.indexOf("mango") !== -1) return "mango";
        return "hyprland";
    }

    function schedule() {
        // Mango has no scale or position IPC to restore through
        if (root.compositor !== "mango") restoreDebounce.restart();
    }

    function parseOutputs(text) {
        let data = JSON.parse(text.trim());
        let outputs = [];
        if (root.compositor === "niri") {
            for (let name of Object.keys(data)) {
                let lg = data[name].logical;
                if (lg) outputs.push({ name: name, scale: lg.scale, x: lg.x, y: lg.y });
            }
        } else if (root.compositor === "sway") {
            for (let o of data) {
                if (o.active !== false && o.rect) outputs.push({ name: o.name, scale: o.scale, x: o.rect.x, y: o.rect.y });
            }
        } else {
            for (let m of data) {
                if (m.disabled === true || (m.mirrorOf && m.mirrorOf !== "none")) continue;
                outputs.push({
                    name: m.name,
                    scale: m.scale,
                    x: m.x,
                    y: m.y,
                    mode: m.width + "x" + m.height + "@" + Number(m.refreshRate).toFixed(2)
                });
            }
        }
        return outputs;
    }

    function restoreOutput(live, saved) {
        let scale = typeof saved.scale === "number" && saved.scale > 0 ? saved.scale : live.scale;
        let x = typeof saved.posX === "number" ? saved.posX : live.x;
        let y = typeof saved.posY === "number" ? saved.posY : live.y;
        if (Math.abs(scale - live.scale) < 0.001 && x === live.x && y === live.y) return;

        if (root.compositor === "niri") {
            Quickshell.execDetached(["niri", "msg", "output", live.name, "scale", scale.toString()]);
            Quickshell.execDetached(["niri", "msg", "output", live.name, "position", "set", x.toString(), y.toString()]);
        } else if (root.compositor === "sway") {
            Quickshell.execDetached(["swaymsg", "output", live.name, "scale", scale.toString(), "position", x.toString(), y.toString()]);
        } else {
            let pos = x + "x" + y;
            let lua = 'hl.monitor({ output = "' + live.name + '", mode = "' + live.mode + '", position = "' + pos + '", scale = ' + scale + ' })';
            let keyword = [live.name, live.mode, pos, scale].join(",");
            // Same parser split as DisplayMainTab.hyprMonitorCmd
            Quickshell.execDetached(["bash", "-c", "hyprctl eval '" + lua + "' || hyprctl keyword monitor " + keyword]);
        }
    }

    Timer {
        id: restoreDebounce
        interval: 400
        onTriggered: {
            if (outputQuery.running) restart();
            else outputQuery.running = true;
        }
    }

    Process {
        id: outputQuery
        command: root.compositor === "niri" ? ["niri", "msg", "-j", "outputs"]
            : root.compositor === "sway" ? ["swaymsg", "-t", "get_outputs", "-r"]
            : ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let outputs;
                try {
                    outputs = root.parseOutputs(this.text);
                } catch (e) {
                    return;
                }
                let display = Config.getSetting("display", { "monitors": {} });
                let saved = (display && display.monitors) || {};
                for (let live of outputs) {
                    if (saved[live.name]) root.restoreOutput(live, saved[live.name]);
                }
            }
        }
    }

    Connections {
        target: Config
        function onDataReadyChanged() {
            if (Config.dataReady) root.schedule();
        }
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            root.schedule();
        }
    }

    Connections {
        target: Hyprland
        enabled: root.compositor === "hyprland"
        function onRawEvent(event) {
            if (event.name === "configreloaded") root.schedule();
        }
    }

    Component.onCompleted: {
        if (Config.dataReady) root.schedule();
    }
}
