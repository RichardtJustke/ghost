import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../reusables"
import "../../../"

Item {
    id: root
    property var module: null
    property var widget: module

    readonly property bool isCompact: module ? module.isCompact : false
    readonly property var barWindow: module ? module.barWindow : null
    readonly property bool showLayout: barWindow ? Boolean(barWindow.isStartupReady) : true

    property alias helpButton: helpBtn

    property bool showLauncherBtn: {
        let dummy = barWindow ? barWindow.configRevision : 0;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar
            && Config.rawSettings.bar.launcherButton !== undefined)
            ? Config.rawSettings.bar.launcherButton : true;
    }

    property real targetHeight: (module && module.moduleActive) ? (btnColumn.height + (barWindow ? barWindow.s(isCompact ? 6 : 8) : (isCompact ? 6 : 8))) : 0

    implicitHeight: targetHeight
    implicitWidth: parent ? parent.width : 0

    Column {
        id: btnColumn
        anchors.centerIn: parent
        spacing: barWindow ? barWindow.s(5) : 5

        IconButton {
            id: launcherBtn
            visible: root.showLauncherBtn
            width: barWindow ? barWindow.s(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
            height: root.showLauncherBtn ? (barWindow ? barWindow.s(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)) : 0
            cornerRadius: Math.max(0, ThemeBackend.borderRadius - (barWindow ? barWindow.s(2) : 2))
            buttonIcon: (typeof SystemInfo !== "undefined" && SystemInfo.distroIcon) ? SystemInfo.distroIcon : ""
            iconOffsetX: -2
            iconFontSize: barWindow ? barWindow.s(root.isCompact ? 14 : 15) : (root.isCompact ? 14 : 15)
            accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
            textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
            onClicked: Quickshell.execDetached(["bash", "-c", Caching.ghostDir + "/scripts/qs_manager.sh toggle launcher"])
        }

        IconButton {
            id: helpBtn
            width: barWindow ? barWindow.s(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
            height: barWindow ? barWindow.s(root.isCompact ? 28 : 30) : (root.isCompact ? 28 : 30)
            cornerRadius: Math.max(0, ThemeBackend.borderRadius - (barWindow ? barWindow.s(2) : 2))
            buttonIcon: "󰒓"
            iconFontSize: barWindow ? barWindow.s(root.isCompact ? 14 : 15) : (root.isCompact ? 14 : 15)
            accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
            textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
            onClicked: Quickshell.execDetached(["bash", "-c", Caching.ghostDir + "/scripts/qs_manager.sh toggle guide"])
        }
    }
}
