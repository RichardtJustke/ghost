import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../reusables"
import "../../../"

Item {
    id: root
    property var module: null
    property var widget: module

    property string orientation: module ? module.orientation : "horizontal"
    readonly property bool isVertical: orientation === "vertical"

    readonly property bool isCompact: module ? module.isCompact : false
    readonly property var barWindow: module ? module.barWindow : null
    readonly property bool showLayout: barWindow ? Boolean(barWindow.isStartupReady) : true
    readonly property real barOpacity: ThemeBackend.elementOpacity

    property alias helpButton: helpButton

    property bool showLauncherBtn: {
        let dummy = barWindow ? barWindow.configRevision : 0;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar
            && Config.rawSettings.bar.launcherButton !== undefined)
            ? Config.rawSettings.bar.launcherButton : true;
    }

    readonly property real btnWidth: isVertical ? (barWindow ? barWindow.cs(isCompact ? 28 : 30) : (isCompact ? 28 : 30)) : (barWindow ? barWindow.cs(isCompact ? 30 : 32) : (isCompact ? 30 : 32))
    readonly property real btnHeight: barWindow ? barWindow.cs(isCompact ? 28 : 30) : (isCompact ? 28 : 30)

    property real targetLength: (module && module.moduleActive) ? ((isVertical ? btnGrid.height : btnGrid.width) + (barWindow ? barWindow.cs(isCompact ? 6 : 8) : (isCompact ? 6 : 8))) : 0

    implicitWidth: isVertical ? (parent ? parent.width : 0) : targetLength
    implicitHeight: isVertical ? targetLength : (parent ? parent.height : 0)

    Grid {
        id: btnGrid
        anchors.centerIn: root.isVertical ? parent : undefined
        anchors.verticalCenter: root.isVertical ? undefined : parent.verticalCenter
        anchors.left: root.isVertical ? undefined : parent.left
        anchors.leftMargin: root.isVertical ? 0 : (barWindow ? barWindow.cs(root.isCompact ? 3 : 4) : (root.isCompact ? 3 : 4))
        columns: root.isVertical ? 1 : 2
        spacing: barWindow ? barWindow.cs(root.isCompact ? 5 : 6) : (root.isCompact ? 5 : 6)

        opacity: (root.isVertical || root.showLayout) ? 1.0 : 0.0
        transform: Translate {
            y: (root.isVertical || root.showLayout) ? 0 : (barWindow ? barWindow.cs(15) : 15)
            Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } }
        }
        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

        IconButton {
            id: launcherButton
            visible: root.showLauncherBtn
            width: root.btnWidth
            height: root.btnHeight
            iconOffsetX: -2

            cornerRadius: Math.max(0, ThemeBackend.borderRadius - (barWindow ? barWindow.cs(2) : 2))
            buttonIcon: (typeof SystemInfo !== "undefined" && SystemInfo.distroIcon) ? SystemInfo.distroIcon : ""
            iconFontSize: barWindow ? barWindow.cs(root.isCompact ? 14 : 15) : (root.isCompact ? 14 : 15)
            accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
            bgOpacity: root.barOpacity
            textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)

            onClicked: Quickshell.execDetached(["bash", "-c", Caching.ghostDir + "/scripts/qs_manager.sh toggle launcher"])
        }

        IconButton {
            id: helpButton
            width: root.btnWidth
            height: root.btnHeight

            cornerRadius: Math.max(0, ThemeBackend.borderRadius - (barWindow ? barWindow.cs(2) : 2))
            buttonIcon: "󰒓"
            iconFontSize: barWindow ? barWindow.cs(root.isCompact ? 14 : 15) : (root.isCompact ? 14 : 15)
            accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
            bgOpacity: root.barOpacity
            textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)

            onClicked: Quickshell.execDetached(["bash", "-c", Caching.ghostDir + "/scripts/qs_manager.sh toggle guide"])
        }
    }
}
