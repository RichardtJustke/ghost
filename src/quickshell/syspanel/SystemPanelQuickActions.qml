import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import "../"
import "../reusables"

Item {
    required property var panel
    property alias nightLight: nightLightBtn
    property alias coffee: coffeeBtn

    component QuickActionBtn : Rectangle {
        id: qaBtn
        Layout.fillWidth: true
        Layout.preferredHeight: wide ? view.panel.s(56) : view.panel.s(60)
        Layout.preferredWidth: 1
        radius: view.panel.boxRadius

        property bool isActive: false
        property bool wide: false
        property string iconText: ""
        property string label: ""
        property string status: ""
        property color activeColor: ThemeBackend.blue
        readonly property bool isHovered: qaMa.containsMouse

        signal leftClicked()
        signal rightClicked()

        color: isActive
            ? Qt.alpha(activeColor, qaMa.containsMouse ? 0.26 : 0.18)
            : ThemeBackend.faded(qaMa.containsMouse ? ThemeBackend.surface1 : Qt.darker(ThemeBackend.surface0, 1.04))
        Behavior on color {
            enabled: view.panel.visible
            ColorAnimation { duration: 150 }
        }

        scale: qaMa.pressed ? 0.96 : 1.0
        Behavior on scale {
            enabled: view.panel.visible
            NumberAnimation { duration: 200; easing.type: Easing.OutQuart }
        }

        // Wide tile: icon chip + label/status
        RowLayout {
            visible: qaBtn.wide
            anchors.fill: parent
            anchors.leftMargin: view.panel.s(10)
            anchors.rightMargin: view.panel.s(10)
            spacing: view.panel.s(10)

            Rectangle {
                Layout.preferredWidth: view.panel.s(36)
                Layout.preferredHeight: view.panel.s(36)
                radius: view.panel.cardRadius
                color: qaBtn.isActive ? qaBtn.activeColor : ThemeBackend.surface1
                Behavior on color {
                    enabled: view.panel.visible
                    ColorAnimation { duration: 150 }
                }

                Text {
                    anchors.centerIn: parent
                    font.family: ThemeBackend.iconFont
                    font.pixelSize: view.panel.s(17)
                    color: qaBtn.isActive ? ThemeBackend.crust : ThemeBackend.subtext0
                    text: qaBtn.iconText
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: view.panel.s(1)

                Text {
                    Layout.fillWidth: true
                    text: qaBtn.label
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Black
                    font.pixelSize: view.panel.s(12)
                    color: ThemeBackend.text
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: qaBtn.status
                    visible: text !== ""
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: view.panel.s(10)
                    color: ThemeBackend.subtext0
                    elide: Text.ElideRight
                }
            }
        }

        // Compact tile: icon over label
        ColumnLayout {
            visible: !qaBtn.wide
            anchors.fill: parent
            anchors.margins: view.panel.s(10)
            spacing: view.panel.s(4)

            Text {
                font.family: ThemeBackend.iconFont
                font.pixelSize: view.panel.s(17)
                color: qaBtn.isActive ? qaBtn.activeColor : (qaMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0)
                text: qaBtn.iconText
                Behavior on color {
                    enabled: view.panel.visible
                    ColorAnimation { duration: 150 }
                }
            }

            Item { Layout.fillHeight: true }

            Text {
                Layout.fillWidth: true
                text: qaBtn.status !== "" ? qaBtn.status : qaBtn.label
                font.family: ThemeBackend.fontFamily
                font.weight: Font.Bold
                font.pixelSize: view.panel.s(10)
                color: qaBtn.isActive ? ThemeBackend.text : ThemeBackend.subtext0
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: qaMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
                if (mouse.button === Qt.RightButton) qaBtn.rightClicked();
                else qaBtn.leftClicked();
            }
        }
    }

    id: view
    z: 5
    Layout.fillWidth: true
    Layout.preferredHeight: grid.implicitHeight
    Layout.maximumHeight: grid.implicitHeight
    opacity: view.panel.introQuickActions
    transform: Translate { x: (view.panel.isLeftAnchored ? -view.panel.rowSlideDistance : view.panel.rowSlideDistance) * (1.0 - view.panel.introQuickActions) }

    property string wifiStatus: ""
    property string btStatus: ""

    // Network/Bluetooth names come from in-process models and are refreshed
    // only while the panel is open, so nothing runs in the background.
    function refreshStatus() {
        let ssid = "";
        if (Networking.wifiEnabled && Networking.devices) {
            let devs = Networking.devices.values || Networking.devices;
            let count = devs.length !== undefined ? devs.length : 0;
            for (let i = 0; i < count && ssid === ""; i++) {
                let d = devs[i];
                if (!d || d.type !== DeviceType.Wifi || !d.networks) continue;
                let nets = d.networks.values || d.networks;
                let nCount = nets.length !== undefined ? nets.length : 0;
                for (let j = 0; j < nCount; j++) {
                    let n = nets[j];
                    if (n && n.connected) { ssid = n.name || n.ssid || ""; break; }
                }
            }
        }
        view.wifiStatus = !Networking.wifiEnabled ? I18n.t("syspanel.toggles.off")
            : (ssid !== "" ? ssid : I18n.t("syspanel.toggles.disconnected"));

        let names = [];
        let adapter = Bluetooth.defaultAdapter;
        if (adapter && adapter.enabled && Bluetooth.devices) {
            let bdevs = Bluetooth.devices.values || [];
            for (let k = 0; k < bdevs.length; k++) {
                let bd = bdevs[k];
                if (bd && bd.connected) names.push(bd.name || bd.deviceName || bd.address || "");
            }
        }
        if (!adapter || !adapter.enabled) view.btStatus = I18n.t("syspanel.toggles.off");
        else if (names.length === 1) view.btStatus = names[0];
        else if (names.length > 1) view.btStatus = I18n.t("syspanel.toggles.devices", { count: names.length });
        else view.btStatus = I18n.t("syspanel.toggles.on");
    }

    Timer {
        interval: 3000
        repeat: true
        running: view.panel.visible
        triggeredOnStart: true
        onTriggered: view.refreshStatus()
    }

    Connections {
        target: view.panel
        function onWifiRadioEnabledChanged() { view.refreshStatus(); }
        function onBtRadioEnabledChanged() { view.refreshStatus(); }
    }

    GridLayout {
        id: grid
        anchors.left: parent.left
        anchors.right: parent.right
        columns: 6
        rowSpacing: view.panel.s(8)
        columnSpacing: view.panel.s(8)
        uniformCellWidths: true

        QuickActionBtn {
            id: nightLightBtn
            Layout.row: 1
            Layout.column: 0
            Layout.columnSpan: 2
            iconText: "󰖔"
            label: I18n.t("syspanel.toggles.night_light")
            activeColor: ThemeBackend.peach

            function updateState() {
                let anyEnabled = false;
                if (typeof BlueLight !== "undefined" && typeof BlueLight.isAnyEnabled === "function") {
                    anyEnabled = BlueLight.isAnyEnabled();
                } else if (typeof Config !== "undefined") {
                    let ds = Config.getSetting("display", {"monitors": {}});
                    let mons = (ds && ds.monitors) ? ds.monitors : {};
                    for (let mName in mons) {
                        if (mons[mName] && mons[mName].enabled) {
                            anyEnabled = true;
                            break;
                        }
                    }
                }
                isActive = anyEnabled;
            }

            Component.onCompleted: updateState()

            Connections {
                target: typeof Config !== "undefined" ? Config : null
                enabled: view.panel.visible
                ignoreUnknownSignals: true
                function onSettingsLoaded() {
                    nightLightBtn.updateState();
                }
            }

            Connections {
                target: typeof BlueLight !== "undefined" ? BlueLight : null
                enabled: view.panel.visible
                ignoreUnknownSignals: true
                function onSettingsChanged() {
                    nightLightBtn.updateState();
                }
            }

            onLeftClicked: {
                Sounds.playSfx("system/quick_click.wav");
                let target = !nightLightBtn.isActive;
                nightLightBtn.isActive = target;

                let monNames = [];
                let ds = typeof Config !== "undefined" ? Config.getSetting("display", {"monitors": {}}) : {"monitors": {}};
                let mons = (ds && ds.monitors) ? ds.monitors : {};
                for (let m in mons) {
                    if (monNames.indexOf(m) === -1) {
                        monNames.push(m);
                    }
                }
                if (typeof Quickshell !== "undefined" && Quickshell.screens) {
                    for (let i = 0; i < Quickshell.screens.length; i++) {
                        let scr = Quickshell.screens[i];
                        if (scr && scr.name && monNames.indexOf(scr.name) === -1) {
                            monNames.push(scr.name);
                        }
                    }
                }

                if (monNames.length > 0) {
                    for (let i = 0; i < monNames.length; i++) {
                        BlueLight.setEnabled(monNames[i], target);
                    }
                } else {
                    BlueLight.setEnabled("", target);
                }
                nightLightBtn.updateState();
            }

            onRightClicked: {
                view.panel.closeAnim.start();
                Quickshell.execDetached(["bash", Caching.ghostDir + "/scripts/qs_manager.sh", "toggle", "guide", "display"]);
            }
        }

        QuickActionBtn {
            id: coffeeBtn
            Layout.row: 1
            Layout.column: 2
            Layout.columnSpan: 2
            activeColor: ThemeBackend.yellow
            label: I18n.t("syspanel.toggles.caffeine")
            iconText: "󰅶"
            status: isActive ? remainingTimeString : ""

            readonly property string stateFilePath: Caching.runDir + "/caffeine_state.json"
            property double coffeeStartTime: 0
            property double coffeeEndTime: 0
            property int remainingSeconds: 0

            readonly property string remainingTimeString: {
                let secs = remainingSeconds;
                if (secs <= 0) return "< 1m";
                let h = Math.floor(secs / 3600);
                let m = Math.floor((secs % 3600) / 60);
                if (h > 0) {
                    return h + "h " + (m < 10 ? "0" + m : m) + "m";
                }
                return Math.max(1, m) + "m";
            }


            function updateRemaining() {
                if (!isActive || coffeeEndTime <= 0) {
                    remainingSeconds = 0;
                    return;
                }
                let now = Date.now();
                let diff = Math.round((coffeeEndTime - now) / 1000);
                if (diff <= 0) {
                    remainingSeconds = 0;
                    disableCaffeine();
                } else {
                    remainingSeconds = diff;
                }
            }

            function saveState() {
                let data = {
                    "enabled": isActive,
                    "startTime": coffeeStartTime,
                    "enabledAt": coffeeStartTime > 0 ? new Date(coffeeStartTime).toISOString() : "",
                    "endTime": coffeeEndTime,
                    "durationSeconds": (coffeeEndTime > coffeeStartTime) ? Math.round((coffeeEndTime - coffeeStartTime) / 1000) : 0
                };
                let jsonStr = JSON.stringify(data);
                Quickshell.execDetached(["sh", "-c", "mkdir -p '" + Caching.runDir + "' && echo '" + jsonStr + "' > '" + stateFilePath + "'"]);
            }

            function syncConfig(enabled) {
                if (typeof Config === "undefined") return;
                let idleObj = Object.assign({}, Config.getSetting("idle", {}));
                idleObj.manualInhibit = enabled;
                idleObj.caffeineStartTime = enabled ? coffeeStartTime : 0;
                idleObj.caffeineEndTime = enabled ? coffeeEndTime : 0;
                Config.setSetting("idle", idleObj);
            }

            function enableCaffeine(durationMs) {
                let now = Date.now();
                coffeeStartTime = now;
                coffeeEndTime = now + durationMs;
                isActive = true;
                updateRemaining();
                saveState();
                syncConfig(true);
            }

            function increaseCaffeine(addMs) {
                let now = Date.now();
                if (!isActive || coffeeEndTime <= now) {
                    enableCaffeine(addMs);
                } else {
                    coffeeEndTime += addMs;
                    updateRemaining();
                    saveState();
                    syncConfig(true);
                }
            }

            function disableCaffeine() {
                isActive = false;
                coffeeStartTime = 0;
                coffeeEndTime = 0;
                remainingSeconds = 0;
                saveState();
                syncConfig(false);
            }

            function applyLoadedState(rawText) {
                if (!rawText || rawText.trim() === "") return;
                try {
                    let data = JSON.parse(rawText.trim());
                    if (data && data.enabled && data.endTime) {
                        let now = Date.now();
                        if (now < data.endTime) {
                            coffeeStartTime = data.startTime || now;
                            coffeeEndTime = data.endTime;
                            isActive = true;
                            updateRemaining();
                            syncConfig(true);
                            return;
                        }
                    }
                } catch (e) {}

                if (isActive) {
                    disableCaffeine();
                }
            }

            function updateState() {
                let now = Date.now();
                if (typeof Config !== "undefined") {
                    let idleObj = Config.getSetting("idle", {"manualInhibit": false});
                    if (idleObj && idleObj.manualInhibit && idleObj.caffeineEndTime && idleObj.caffeineEndTime > now) {
                        coffeeStartTime = idleObj.caffeineStartTime || now;
                        coffeeEndTime = idleObj.caffeineEndTime;
                        isActive = true;
                        updateRemaining();
                    } else if (idleObj && !idleObj.manualInhibit) {
                        isActive = false;
                        coffeeEndTime = 0;
                        coffeeStartTime = 0;
                        remainingSeconds = 0;
                    }
                }
                coffeeStateReader.running = true;
            }

            Process {
                id: coffeeStateReader
                command: ["sh", "-c", "cat '" + coffeeBtn.stateFilePath + "' 2>/dev/null || true"]
                running: false
                stdout: StdioCollector {
                    onStreamFinished: {
                        coffeeBtn.applyLoadedState(this.text.trim());
                    }
                }
            }

            Timer {
                id: coffeeTicker
                interval: view.panel.visible ? 1000 : 15000
                repeat: true
                running: coffeeBtn.isActive
                triggeredOnStart: true
                onTriggered: {
                    coffeeBtn.updateRemaining();
                }
            }

            Component.onCompleted: updateState()

            Connections {
                target: typeof Config !== "undefined" ? Config : null
                enabled: true
                ignoreUnknownSignals: true
                function onSettingsLoaded() {
                    coffeeBtn.updateState();
                }
            }

            onLeftClicked: {
                Sounds.playSfx("system/quick_click.wav");
                if (isActive) {
                    disableCaffeine();
                } else {
                    enableCaffeine(3600 * 1000);
                }
            }

            onRightClicked: {
                Sounds.playSfx("system/quick_click.wav");
                increaseCaffeine(3600 * 1000);
            }
        }

        QuickActionBtn {
            Layout.row: 0
            Layout.column: 0
            Layout.columnSpan: 3
            wide: true
            iconText: isActive ? "󰤨" : "󰤮"
            label: I18n.t("syspanel.toggles.wifi")
            status: view.wifiStatus
            activeColor: ThemeBackend.blue
            isActive: view.panel.wifiRadioEnabled
            onLeftClicked: {
                Sounds.playSfx("system/quick_click.wav");
                Networking.wifiEnabled = !Networking.wifiEnabled;
            }
            onRightClicked: {
                view.panel.closeAnim.start();
                Quickshell.execDetached(["bash", Caching.ghostDir + "/scripts/qs_manager.sh", "toggle", "network", "wifi"]);
            }
        }

        QuickActionBtn {
            Layout.row: 0
            Layout.column: 3
            Layout.columnSpan: 3
            wide: true
            iconText: isActive ? "󰂯" : "󰂲"
            label: I18n.t("syspanel.toggles.bluetooth")
            status: view.btStatus
            activeColor: ThemeBackend.mauve
            isActive: view.panel.btRadioEnabled
            onLeftClicked: {
                Sounds.playSfx("system/quick_click.wav");
                if (Bluetooth.defaultAdapter) {
                    Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
                }
            }
            onRightClicked: {
                view.panel.closeAnim.start();
                Quickshell.execDetached(["bash", Caching.ghostDir + "/scripts/qs_manager.sh", "toggle", "network", "bt"]);
            }
        }

        QuickActionBtn {
            Layout.row: 1
            Layout.column: 4
            Layout.columnSpan: 2
            iconText: "󰀝"
            label: I18n.t("syspanel.toggles.airplane")
            activeColor: ThemeBackend.red
            isActive: !view.panel.wifiRadioEnabled && !view.panel.btRadioEnabled
            onLeftClicked: {
                Sounds.playSfx("system/quick_click.wav");
                let enableAirplane = !isActive;
                if (enableAirplane) {
                    view.panel.btStateBeforeAirplane = view.panel.btRadioEnabled;
                    view.panel.wifiStateBeforeAirplane = view.panel.wifiRadioEnabled;
                    Networking.wifiEnabled = false;
                    if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = false;
                } else {
                    let restoreWifi = view.panel.wifiStateBeforeAirplane;
                    let restoreBt = view.panel.btStateBeforeAirplane;
                    if (!restoreWifi && !restoreBt) {
                        restoreWifi = true;
                    }
                    Networking.wifiEnabled = restoreWifi;
                    if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = restoreBt;
                }
            }
        }
    }
}
