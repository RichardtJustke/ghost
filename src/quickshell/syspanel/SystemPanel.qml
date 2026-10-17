import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import "../"
import "../reusables"

Item {
    id: root
    visible: false
    focus: true
    enabled: visible

    function s(val) {
        return Scaler.p(val);
    }

    readonly property string barPosition: {
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.position !== undefined) {
            return Config.rawSettings.bar.position;
        }
        return "top";
    }

    readonly property bool isLeftAnchored: barPosition === "left"
    readonly property real slideDistance: root.s(48)
    readonly property real rowSlideDistance: root.s(36)

    readonly property bool isDesktop: UPower.displayDevice.ready ? !UPower.displayDevice.isLaptopBattery : SystemInfo.isDesktop

    readonly property real boxRadius: Math.min(ThemeBackend.borderRadius, root.s(20))
    readonly property real cardRadius: Math.min(ThemeBackend.borderRadius, root.s(14))
    readonly property real panelRadius: Math.min(ThemeBackend.borderRadius, root.s(22))
    readonly property color cardColor: ThemeBackend.faded(Qt.darker(ThemeBackend.surface0, 1.04))

    readonly property color briColor: Qt.lighter(ThemeBackend.mauve, 1.1)
    readonly property color volColor: Qt.lighter(ThemeBackend.sapphire, 1.5)
    readonly property color profileColor: Qt.lighter(ThemeBackend.blue, 1.55)
    readonly property int batCapacity: UPower.displayDevice.ready ? Math.round(UPower.displayDevice.percentage * 100) : 0

    readonly property bool isCharging: UPower.displayDevice.ready && (UPower.displayDevice.state === UPowerDeviceState.Charging || UPower.displayDevice.state === UPowerDeviceState.FullyCharged)

    readonly property string batStatus: {
        if (!UPower.displayDevice.ready) return "Unknown";
        switch (UPower.displayDevice.state) {
            case UPowerDeviceState.FullyCharged: return "Fully Charged";
            case UPowerDeviceState.Charging: return "Charging";
            case UPowerDeviceState.Discharging: return "Discharging";
            default: return "Unknown";
        }
    }

    readonly property int batHours: {
        if (!UPower.displayDevice.ready) return 0;
        let secs = isCharging ? UPower.displayDevice.timeToFull : UPower.displayDevice.timeToEmpty;
        return Math.floor(secs / 3600);
    }

    readonly property int batMins: {
        if (!UPower.displayDevice.ready) return 0;
        let secs = isCharging ? UPower.displayDevice.timeToFull : UPower.displayDevice.timeToEmpty;
        return Math.round((secs % 3600) / 60);
    }

    readonly property string batTimeLabel: {
        if (!UPower.displayDevice.ready || (batHours === 0 && batMins === 0) || batCapacity === 100) return "";
        if (UPower.displayDevice.state === UPowerDeviceState.Charging) return I18n.t("syspanel.battery.until_full");
        if (UPower.displayDevice.state === UPowerDeviceState.Discharging) return I18n.t("syspanel.battery.remaining");
        return "";
    }

    readonly property string powerProfile: {
        switch (PowerProfiles.profile) {
            case PowerProfile.Performance: return "performance";
            case PowerProfile.PowerSaver: return "power-saver";
            default: return "balanced";
        }
    }

    readonly property real sysVolume: Audio.defaultSink && Audio.defaultSink.audio ? Math.round(Audio.defaultSink.audio.volume * 100) : 0
    readonly property bool sysMuted: Audio.defaultSink && Audio.defaultSink.audio ? Audio.defaultSink.audio.muted : false

    property real sysBrightness: 0

    property bool wifiRadioEnabled: Networking.wifiEnabled
    property bool btRadioEnabled: Boolean(Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled)

    Connections {
        target: Bluetooth
        ignoreUnknownSignals: true
        function onDefaultAdapterChanged() {
            root.btRadioEnabled = Boolean(Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled);
        }
    }

    Connections {
        target: Bluetooth.defaultAdapter || null
        ignoreUnknownSignals: true
        function onEnabledChanged() {
            root.btRadioEnabled = Boolean(Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled);
        }
    }

    property bool isDraggingVol: false
    property bool isDraggingBri: false
    property bool usesDdcBrightness: false

    property bool btStateBeforeAirplane: false
    property bool wifiStateBeforeAirplane: true

    property bool canHibernate: false

    readonly property color batColorFlat: {
        if (!UPower.displayDevice.ready) return ThemeBackend.blue;
        if (isCharging) return ThemeBackend.green;
        if (batCapacity <= 20) return ThemeBackend.red;
        return ThemeBackend.blue;
    }

    property real animCapacity: 0
    Behavior on animCapacity {
        enabled: root.visible
        NumberAnimation { duration: 1200; easing.type: Easing.OutQuint }
    }

    onBatCapacityChanged: {
        if (root.visible) {
            animCapacity = batCapacity;
        }
    }

    onSysVolumeChanged: {
        if (root.visible && slidersBox.volumeSlider && !root.isDraggingVol && slidersBox.volumeSlider.value !== sysVolume) {
            slidersBox.volumeSlider.value = sysVolume;
        }
    }

    onSysBrightnessChanged: {
        if (root.visible && slidersBox.brightnessSlider && !root.isDraggingBri && slidersBox.brightnessSlider.value !== sysBrightness) {
            slidersBox.brightnessSlider.value = sysBrightness;
        }
    }

    Process {
        id: hibernateCheck
        running: false
        command: ["bash", Caching.ghostDir + "/scripts/system/can_hibernate.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text.trim();
                root.canHibernate = (out === "yes");
            }
        }
    }

    property real introContent: 0.0
    property real introTop: 0.0
    property real introSliders: 0.0
    property real introQuickActions: 0.0
    property real introNotifs: 0.0
    property real introActions: 0.0
    property real introCore: 0.0

    function resetAndPlayIntro() {
        introContent = 0.0;
        introTop = 0.0;
        introSliders = 0.0;
        introQuickActions = 0.0;
        introNotifs = 0.0;
        introActions = 0.0;
        introCore = 0.0;
        closeSequence.stop();
        startupSequence.restart();
    }

    onVisibleChanged: {
        NotificationManager.sysPanelOpen = visible;
        if (visible) {
            forceActiveFocus();
            resetAndPlayIntro();

            animCapacity = batCapacity;

            if (slidersBox.volumeSlider && !root.isDraggingVol) {
                slidersBox.volumeSlider.value = root.sysVolume;
            }

            if (slidersBox.brightnessSlider && !root.isDraggingBri) {
                slidersBox.brightnessSlider.value = root.sysBrightness;
            }

            if (quickActionsBox.nightLight) quickActionsBox.nightLight.updateState();
            if (quickActionsBox.coffee) quickActionsBox.coffee.updateState();

            briPollerTimer.interval = 150;
            briPollerTimer.restart();
        } else {
            briPollerTimer.stop();
            briPoller.running = false;
            startupSequence.stop();
            closeSequence.stop();
        }
    }

    Component.onCompleted: {
        hibernateCheck.running = true;
        if (visible) {
            NotificationManager.sysPanelOpen = true;
            if (quickActionsBox.nightLight) quickActionsBox.nightLight.updateState();
            if (quickActionsBox.coffee) quickActionsBox.coffee.updateState();
            resetAndPlayIntro();
            forceActiveFocus();
            briPollerTimer.interval = 150;
            briPollerTimer.restart();
            animCapacity = batCapacity;
        }
    }

    Component.onDestruction: {
        NotificationManager.sysPanelOpen = false;
        briPollerTimer.stop();
    }

    Timer {
        id: briPollerTimer
        interval: root.usesDdcBrightness ? 10000 : 1500
        repeat: false
        onTriggered: {
            if (root.visible) {
                briPoller.running = true;
                interval = root.usesDdcBrightness ? 10000 : 1500;
            }
        }
    }

    Process {
        id: briBackend
        command: ["bash", Caching.qsDir + "/../scripts/brightness.sh", "backend"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.usesDdcBrightness = this.text.trim() === "ddc"
        }
    }

    Process {
        id: briPoller
        command: ["bash", Caching.qsDir + "/../scripts/brightness.sh", "get"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text.trim();
                if (out !== "" && !root.isDraggingBri) {
                    root.sysBrightness = parseInt(out) || 0;
                }
                if (root.visible) briPollerTimer.start();
            }
        }
    }

    ParallelAnimation {
        id: startupSequence
        NumberAnimation { target: root; property: "introContent"; to: 1.0; duration: 320; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "introTop"; from: 0; to: 1.0; duration: 320; easing.type: Easing.OutCubic }

        SequentialAnimation {
            PauseAnimation { duration: 30 }
            NumberAnimation { target: root; property: "introSliders"; from: 0; to: 1.0; duration: 320; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 55 }
            NumberAnimation { target: root; property: "introQuickActions"; from: 0; to: 1.0; duration: 320; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 80 }
            NumberAnimation { target: root; property: "introNotifs"; from: 0; to: 1.0; duration: 330; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 105 }
            NumberAnimation { target: root; property: "introActions"; from: 0; to: 1.0; duration: 330; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 130 }
            NumberAnimation { target: root; property: "introCore"; from: 0; to: 1.0; duration: 340; easing.type: Easing.OutCubic }
        }
    }

    property alias closeAnim: closeSequence

    property var exitCallback: null

    function startExit(onFinished) {
        startupSequence.stop();
        exitCallback = onFinished;
        closeSequence.restart();
    }

    SequentialAnimation {
        id: closeSequence
        ParallelAnimation {
            NumberAnimation { target: root; property: "introContent"; to: 0.0; duration: 260; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "introTop"; to: 0.0; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "introSliders"; to: 0.0; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "introQuickActions"; to: 0.0; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "introNotifs"; to: 0.0; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "introActions"; to: 0.0; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "introCore"; to: 0.0; duration: 220; easing.type: Easing.InCubic }
        }
        ScriptAction {
            script: {
                if (root.exitCallback) {
                    let cb = root.exitCallback;
                    root.exitCallback = null;
                    cb();
                } else {
                    Quickshell.execDetached(["bash", Caching.ghostDir + "/scripts/qs_manager.sh", "close"]);
                }
            }
        }
    }

    Keys.onEscapePressed: (event) => {
        if (typeof masterWindow !== "undefined" && masterWindow.switchWidget) {
            masterWindow.switchWidget("hidden", "");
        } else {
            closeSequence.restart();
        }
        event.accepted = true;
    }

    readonly property string batTimeString: {
        if (root.batStatus === "Fully Charged") return I18n.t("syspanel.battery.fully_charged");
        if (root.batStatus === "Charging") {
            if (root.batHours === 0 && root.batMins === 0) return I18n.t("syspanel.battery.charging");
            return I18n.t("syspanel.battery.charging_time", { hours: root.batHours, mins: root.batMins });
        }
        if (root.batHours === 0 && root.batMins === 0) return I18n.t("syspanel.battery.discharging");
        return I18n.t("syspanel.battery.left_time", { hours: root.batHours, mins: root.batMins });
    }

    function openWidget(name, arg) {
        closeSequence.start();
        let cmd = ["bash", Caching.ghostDir + "/scripts/qs_manager.sh", "toggle", name];
        if (arg) cmd.push(arg);
        Quickshell.execDetached(cmd);
    }

    Rectangle {
        id: sidebarPanel
        anchors.fill: parent
        color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
        radius: root.panelRadius
        border.width: 1
        border.color: Qt.alpha(ThemeBackend.surface1, 0.55)
        clip: true
        opacity: root.introContent
        transform: Translate { x: (root.isLeftAnchored ? -root.slideDistance : root.slideDistance) * (1.0 - root.introContent) }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.s(10)
            spacing: root.s(8)

            Rectangle {
                id: userBox
                Layout.fillWidth: true
                Layout.preferredHeight: root.s(60)
                Layout.maximumHeight: root.s(60)
                radius: root.boxRadius
                color: root.cardColor
                opacity: root.introTop
                transform: Translate { x: (root.isLeftAnchored ? -root.rowSlideDistance : root.rowSlideDistance) * (1.0 - root.introTop) }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: root.s(10)
                    anchors.rightMargin: root.s(10)
                    spacing: root.s(10)

                    ImageBox {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: root.s(40)
                        Layout.preferredHeight: root.s(40)
                        size: root.s(40)
                        cornerRadius: root.s(20)
                        imageRadius: root.s(20)
                        source: SystemInfo.avatarPath !== "" ? "file://" + SystemInfo.avatarPath : ""
                        backgroundColor: SystemInfo.avatarPath === "" ? ThemeBackend.surface1 : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            font.family: ThemeBackend.iconFont
                            font.pixelSize: root.s(18)
                            color: ThemeBackend.text
                            visible: SystemInfo.avatarPath === ""
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: root.s(1)

                        Text {
                            Layout.fillWidth: true
                            text: SystemInfo.username !== "" ? SystemInfo.username : I18n.t("syspanel.user.default_name")
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Black
                            font.pixelSize: root.s(15)
                            color: ThemeBackend.text
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: (SystemInfo.osName !== "" ? SystemInfo.osName : I18n.t("syspanel.user.default_os"))
                                + (SystemInfo.uptime !== "" ? " · " + SystemInfo.uptime : "")
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Medium
                            font.pixelSize: root.s(10)
                            color: ThemeBackend.subtext0
                            elide: Text.ElideRight
                        }
                    }

                    IconButton {
                        Layout.alignment: Qt.AlignVCenter
                        size: root.s(36)
                        cornerRadius: root.s(12)
                        buttonIcon: "󰒓"
                        iconFontSize: root.s(16)
                        accentColor: ThemeBackend.surface1
                        textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.subtext0
                        onClicked: root.openWidget("guide", "")
                    }

                    IconButton {
                        id: logoutBtn
                        Layout.alignment: Qt.AlignVCenter
                        size: root.s(36)
                        cornerRadius: root.s(12)
                        buttonIcon: "󰍃"
                        iconFontSize: root.s(16)
                        accentColor: ThemeBackend.surface1
                        textColor: isHoveredOrHighlighted ? ThemeBackend.red : ThemeBackend.subtext0

                        Timer {
                            id: logoutOpenTimer
                            interval: 150
                            onTriggered: {
                                closeSequence.start();
                                Quickshell.execDetached(["bash", Caching.ghostDir + "/scripts/system/exit.sh"]);
                                Quickshell.execDetached(["sh", "-c", "echo 'close' > " + Caching.runDir + "/widget_state"]);
                            }
                        }

                        onClicked: logoutOpenTimer.start()
                    }
                }
            }

            SystemPanelSliders {
                id: slidersBox
                panel: root
            }

            SystemPanelQuickActions {
                id: quickActionsBox
                panel: root
            }

            Rectangle {
                id: batteryBox
                Layout.fillWidth: true
                Layout.preferredHeight: batteryCol.implicitHeight + root.s(24)
                Layout.maximumHeight: Layout.preferredHeight
                radius: root.boxRadius
                color: root.cardColor
                opacity: root.introCore
                transform: Translate { x: (root.isLeftAnchored ? -root.rowSlideDistance : root.rowSlideDistance) * (1.0 - root.introCore) }

                ColumnLayout {
                    id: batteryCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: root.s(12)
                    spacing: root.s(10)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.s(10)
                        visible: !root.isDesktop

                        Text {
                            font.family: ThemeBackend.iconFont
                            font.pixelSize: root.s(22)
                            color: root.batColorFlat
                            text: root.isCharging ? "󰂄" : (root.batCapacity > 20 ? "󰁹" : "󰂃")
                            Behavior on color {
                                enabled: root.visible
                                ColorAnimation { duration: 400 }
                            }
                        }

                        Text {
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Black
                            font.pixelSize: root.s(20)
                            color: ThemeBackend.text
                            text: Math.round(root.animCapacity) + "%"
                        }

                        Text {
                            Layout.fillWidth: true
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: root.s(10)
                            color: root.isCharging ? ThemeBackend.green : ThemeBackend.subtext0
                            text: root.batTimeString
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.s(6)
                        radius: height / 2
                        color: ThemeBackend.surface1
                        visible: !root.isDesktop

                        Rectangle {
                            height: parent.height
                            radius: parent.radius
                            width: parent.width * Math.max(0, Math.min(1, root.animCapacity / 100))
                            color: root.batColorFlat
                            Behavior on color {
                                enabled: root.visible
                                ColorAnimation { duration: 400 }
                            }
                        }
                    }

                    Switch {
                        id: profileSwitch
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.s(36)
                        implicitHeight: root.s(36)
                        cornerRadius: root.s(12)
                        fontPixelSize: root.s(11)
                        options: PowerProfiles.hasPerformanceProfile
                            ? ["󰌪 " + I18n.t("syspanel.profiles.power_saver"), "󰗑 " + I18n.t("syspanel.profiles.balanced"), "󰓅 " + I18n.t("syspanel.profiles.performance")]
                            : ["󰌪 " + I18n.t("syspanel.profiles.power_saver"), "󰗑 " + I18n.t("syspanel.profiles.balanced")]
                        accentColor: root.profileColor
                        baseColor: ThemeBackend.surface1
                        textColor: ThemeBackend.subtext0
                        activeTextColor: ThemeBackend.crust
                        currentIndex: {
                            if (PowerProfiles.hasPerformanceProfile) {
                                if (root.powerProfile === "power-saver") return 0;
                                if (root.powerProfile === "balanced") return 1;
                                return 2;
                            }
                            return root.powerProfile === "power-saver" ? 0 : 1;
                        }

                        onValueChanged: (idx, val) => {
                            if (idx === 0) PowerProfiles.profile = PowerProfile.PowerSaver;
                            else if (idx === 1) PowerProfiles.profile = PowerProfile.Balanced;
                            else PowerProfiles.profile = PowerProfile.Performance;
                        }
                    }
                }
            }

            NotificationBox {
                id: notifsBox
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: root.s(110)
                cornerRadius: root.boxRadius
                cardRadius: root.cardRadius
                baseColor: root.cardColor
                emptyGraphicSize: root.s(96)
                rootContext: root
                opacity: root.introNotifs
                transform: Translate { x: (root.isLeftAnchored ? -root.rowSlideDistance : root.rowSlideDistance) * (1.0 - root.introNotifs) }
            }

            SystemPanelPowerActions {
                panel: root
            }

            Text {
                Layout.fillWidth: true
                Layout.topMargin: -root.s(2)
                horizontalAlignment: Text.AlignHCenter
                text: I18n.t("syspanel.actions.hold_hint")
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(9)
                color: ThemeBackend.overlay0
                opacity: root.introActions
            }
        }
    }
}
