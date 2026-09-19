pragma Singleton
import QtQuick
import QtQuick.Window
import Quickshell
import "../../"

Item {
    id: root
    visible: false

    property string screenName: Screen.name
    property real currentWidth: 1920.0
    property real currentHeight: 1080.0

    property real uiScale: {
        var displayConf = Config.getSetting("display", null);
        if (displayConf && displayConf.monitors && displayConf.monitors[screenName] && displayConf.monitors[screenName].scale !== undefined) {
            return displayConf.monitors[screenName].scale;
        }
        var general = Config.getSetting("general", null);
        return (general && general.uiScale !== undefined) ? general.uiScale : 1.0;
    }

    property real baseScale: uiScale

    property int rev: 0
    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() { root.rev++; }
    }

    // Shell-only UI scale, independent from the compositor's own per-monitor scale
    // (display.monitors[<name>].scale, which actually resizes the physical output).
    // Per-monitor override: display.monitors[<name>].shellScale
    // Global fallback: general.shellScale. Defaults to 1.0 (no-op).
    function scaleFor(name) {
        let d = root.rev;
        let dc = Config.getSetting("display", null);
        if (dc && dc.monitors && name && dc.monitors[name] && dc.monitors[name].shellScale !== undefined) {
            let v = dc.monitors[name].shellScale;
            if (typeof v === "number" && v > 0.1) return v;
        }
        let g = Config.getSetting("general", null);
        if (g && g.shellScale !== undefined && typeof g.shellScale === "number" && g.shellScale > 0.1) return g.shellScale;
        return 1.0;
    }

    function s(val) {
        let f = scaleFor(root.screenName);
        return Math.round(val * (isNaN(f) ? 1.0 : f));
    }
}
