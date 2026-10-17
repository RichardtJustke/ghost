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

    // Scale for everything hosted by the master popup window (Main.qml).
    // Main keeps it in sync with the screen the popup opens on: it follows that
    // monitor's shellScale and shrinks further when the popups would not fit.
    property real popupScale: 1.0

    // Largest fixed-size popup (settings) in base px, used to fit small screens.
    readonly property real popupRefWidth: 1200
    readonly property real popupRefHeight: 750

    function popupScaleFor(name, screenW, screenH, extra) {
        let pref = scaleFor(name) * ((typeof extra === "number" && extra > 0) ? extra : 1.0);
        if (!(screenW > 0) || !(screenH > 0)) return pref;
        // Leave room for the bar (~52px) and a small margin around the popup
        let fit = Math.min((screenW * 0.94) / root.popupRefWidth, (screenH - 64) / root.popupRefHeight);
        return Math.max(0.5, Math.min(pref, fit));
    }

    function p(val) {
        return Math.round(val * root.popupScale);
    }

    // Scaler is a singleton, so it has no window/screen of its own: root.screenName
    // is not reliable per-caller. Any per-monitor window (bar, dock, widgets, ...)
    // MUST pass its own screen name so each monitor's shell scale stays independent.
    // Omitting screenName falls back to root.screenName for callers with no screen context.
    function s(val, screenName) {
        let f = scaleFor(screenName !== undefined && screenName !== null && screenName !== "" ? screenName : root.screenName);
        return Math.round(val * (isNaN(f) ? 1.0 : f));
    }
}
