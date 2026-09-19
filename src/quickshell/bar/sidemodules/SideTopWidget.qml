import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../reusables"
import "../../"

Rectangle {
    id: sideTopRoot

    property var barWindow
    property bool isSolid: false
    property bool distinctPills: barWindow ? (barWindow.distinctPills !== undefined ? barWindow.distinctPills : false) : false
    property bool moduleActive: true
    property bool isGrouped: false
    property bool isCompact: isGrouped || (isSolid && distinctPills)
    property real targetY: 0
    property bool showLayout: barWindow ? Boolean(barWindow.isStartupReady) : true
    property alias helpButton: helpBtn

    property bool showLauncherBtn: {
        let dummy = barWindow ? barWindow.configRevision : 0;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar
            && Config.rawSettings.bar.launcherButton !== undefined)
            ? Config.rawSettings.bar.launcherButton : true;
    }

    y: targetY
    property real targetWidth: barWindow ? (isGrouped ? barWindow.barHeight - 8 : ((isSolid && distinctPills) ? barWindow.barHeight - 6 : barWindow.barHeight)) : (isGrouped ? 22 : ((isSolid && distinctPills) ? 24 : 30))
    property real targetHeight: showLauncherBtn ? Math.round(targetWidth * 1.9) : targetWidth
    Behavior on targetHeight { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    width: targetWidth
    height: targetHeight

    radius: ThemeBackend.borderRadius
    border.width: 0
    color: isGrouped ? "transparent" : (isSolid ? (distinctPills ? Qt.darker(ThemeBackend.surface0, 1.15) : "transparent") : ThemeBackend.base)
    clip: true

    opacity: (showLayout && moduleActive) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    enabled: moduleActive

    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Column {
        anchors.centerIn: parent
        spacing: barWindow ? barWindow.s(5) : 5

        IconButton {
            id: launcherBtn
            visible: sideTopRoot.showLauncherBtn
            width: barWindow ? barWindow.s(sideTopRoot.isCompact ? 28 : 30) : (sideTopRoot.isCompact ? 28 : 30)
            height: sideTopRoot.showLauncherBtn ? (barWindow ? barWindow.s(sideTopRoot.isCompact ? 28 : 30) : (sideTopRoot.isCompact ? 28 : 30)) : 0
            cornerRadius: Math.max(0, ThemeBackend.borderRadius - (barWindow ? barWindow.s(2) : 2))
            buttonIcon: (typeof SystemInfo !== "undefined" && SystemInfo.distroIcon) ? SystemInfo.distroIcon : ""
            iconOffsetX: -2
            iconFontSize: barWindow ? barWindow.s(sideTopRoot.isCompact ? 14 : 15) : (sideTopRoot.isCompact ? 14 : 15)
            accentColor: sideTopRoot.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
            textColor: isHoveredOrHighlighted ? ThemeBackend.text : (sideTopRoot.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
            onClicked: Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle launcher"])
        }

        IconButton {
            id: helpBtn
            width: barWindow ? barWindow.s(sideTopRoot.isCompact ? 28 : 30) : (sideTopRoot.isCompact ? 28 : 30)
            height: barWindow ? barWindow.s(sideTopRoot.isCompact ? 28 : 30) : (sideTopRoot.isCompact ? 28 : 30)
            cornerRadius: Math.max(0, ThemeBackend.borderRadius - (barWindow ? barWindow.s(2) : 2))
            buttonIcon: "󰒓"
            iconOffsetX: -2
            iconFontSize: barWindow ? barWindow.s(sideTopRoot.isCompact ? 14 : 15) : (sideTopRoot.isCompact ? 14 : 15)
            accentColor: sideTopRoot.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
            textColor: isHoveredOrHighlighted ? ThemeBackend.text : (sideTopRoot.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
            onClicked: Quickshell.execDetached(["bash", "-c", Caching.serpantinumDir + "/scripts/qs_manager.sh toggle guide"])
        }
    }
}
