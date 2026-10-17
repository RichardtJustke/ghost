import QtQuick
import Quickshell
import Quickshell.Io
import "widgets"

ShellRoot {
    readonly property bool performanceMode: !!(Config.getSetting("general", {}).performance)
    readonly property bool quickactionsEnabled: Config.getSetting("general", {}).quickactions !== false
    readonly property bool dockEnabled: Config.getSetting("dock", {}).enabled !== false

    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
        function onReloadFailed(errorString) { Quickshell.inhibitReloadPopup() }
    }

    LazyLoader {
        id: screenshotLoader
        ScreenshotOverlay {}
    }

    function ensureScreenshotOverlay() {
        if (!screenshotLoader.item) screenshotLoader.active = true;
        return screenshotLoader.item;
    }

    IpcHandler {
        target: "screenshotOverlay"

        function toggle(img: string, editMode: string, audioPrefs: string, cGeom: string, cGeomVideo: string, cMode: string, cBackend: string, targetMon: string): void {
            let overlay = ensureScreenshotOverlay();
            if (overlay) overlay.toggleOverlay(img, editMode, audioPrefs, cGeom, cGeomVideo, cMode, cBackend, targetMon);
        }

        function activate(img: string, editMode: string, audioPrefs: string, cGeom: string, cGeomVideo: string, cMode: string, cBackend: string, targetMon: string): void {
            let overlay = ensureScreenshotOverlay();
            if (overlay) overlay.activate(img, editMode, audioPrefs, cGeom, cGeomVideo, cMode, cBackend, targetMon);
        }

        function deactivate(): void {
            if (screenshotLoader.item) screenshotLoader.item.deactivate();
        }
    }

    Main {}
    Bar {}
    Lock {}
    WidgetRedactor {}

    // Launcher and Clipboard are created on first open and kept afterwards
    LazyLoader {
        id: launcherLoader
        active: false
        Launcher {}
    }
    Connections {
        target: LauncherController
        function onIsVisibleChanged() {
            if (LauncherController.isVisible) launcherLoader.active = true;
        }
    }

    LazyLoader {
        id: clipboardLoader
        active: false
        Clipboard {}
    }
    Connections {
        target: ClipboardController
        function onIsVisibleChanged() {
            if (ClipboardController.isVisible) clipboardLoader.active = true;
        }
    }

    Polkit {}
    PopoutManager {}
    UsbSound {}
    BtAutoPopup {}

    Loader {
        active: dockEnabled
        sourceComponent: Dock {}
    }

    Loader {
        active: !performanceMode
        sourceComponent: Idle {}
    }
    Variants {
        model: performanceMode ? [] : Quickshell.screens
        delegate: WidgetLoader {
            required property var modelData
            screen: modelData
            monitorName: modelData.name
        }
    }
    Loader {
        active: !performanceMode
        sourceComponent: WallpaperEngine {}
    }
    Loader {
        active: !performanceMode && quickactionsEnabled
        sourceComponent: Floating {}
    }

    Component.onCompleted: {
        FirstLaunch.checkFirstLaunch();
        SysNotif.checkBattery();
        Quickshell.execDetached(["bash", Caching.ghostDir + "/scripts/sddm_sync.sh"]);
        // Touch PauseReminder once so the singleton is instantiated at
        // startup and its background timer runs regardless of which
        // guide tab (if any) is open.
        PauseReminder.enabled;
    }
}
