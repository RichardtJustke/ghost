import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import "../"
import "../reusables"

Item {
    id: window
    focus: true

    function s(val) {
        return Scaler.s(val);
    }

    // Set by Main.qml from the widget arg: a device MAC, or "auto:<MAC>" when BtAutoPopup opened us on connect.
    property string activeMode: ""
    property bool autoOpened: false
    onActiveModeChanged: {
        let arg = activeMode;
        if (arg.indexOf("auto:") === 0) {
            window.autoOpened = true;
            arg = arg.substring(5);
            if (window.visible) autoClose.restart();
        }
        if (arg !== "" && arg.indexOf(":") !== -1) window.selectedMac = arg.toUpperCase();
    }

    function closePopup() {
        if (window.visible) Quickshell.execDetached(["bash", "-c", Caching.ghostDir + "/scripts/qs_manager.sh close"]);
    }

    // Auto-opened popups dismiss themselves unless the pointer is over them.
    Timer {
        id: autoClose
        interval: 6000
        onTriggered: if (window.autoOpened && !hover.hovered) window.closePopup()
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hovered) autoClose.stop();
            else if (window.autoOpened && window.visible) autoClose.restart();
        }
    }

    // Galaxy Buds get the per-earbud helper; every other headphone uses BlueZ data only.
    function isBuds(d) {
        let name = (d ? (d.name || d.deviceName || "") : "").toLowerCase();
        return name.indexOf("buds") !== -1;
    }

    // Earbuds get the earbud art, anything else (PEI-P10, AirPods Max...) the over-ear one.
    function artFor(d) {
        let name = (d ? (d.name || d.deviceName || "") : "").toLowerCase();
        if (name.indexOf("max") !== -1) return "headphone";
        if (name.indexOf("buds") !== -1 || name.indexOf("pods") !== -1 || name.indexOf("tws") !== -1) return "bud";
        return "headphone";
    }

    property string selectedMac: ""
    property string pendingMac: ""
    property bool forgetArmed: false
    property var cardInfo: ({})

    readonly property string scriptsDir: Caching.qsDir + "/bluetooth"
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool adapterOn: adapter ? adapter.enabled : false

    readonly property var devices: {
        if (!adapter || !adapter.devices) return [];
        let list = [];
        let vals = adapter.devices.values || [];
        for (let i = 0; i < vals.length; i++) {
            let d = vals[i];
            if (d && (d.paired || d.bonded || d.connected) && isAudio(d)) list.push(d);
        }
        return list;
    }

    function isAudio(d) {
        if (!d) return false;
        let icon = (d.icon || "").toLowerCase();
        let name = (d.name || d.deviceName || "").toLowerCase();
        return icon.indexOf("audio") !== -1 || icon.indexOf("headset") !== -1 || icon.indexOf("headphone") !== -1
            || name.indexOf("buds") !== -1 || name.indexOf("pods") !== -1 || name.indexOf("headphone") !== -1;
    }

    function deviceIcon(d) {
        let icon = (d && d.icon ? d.icon : "").toLowerCase();
        let name = (d ? (d.name || d.deviceName || "") : "").toLowerCase();
        if (icon.indexOf("headset") !== -1 || icon.indexOf("headphone") !== -1 || name.indexOf("buds") !== -1 || name.indexOf("pods") !== -1) return "󰋋";
        if (icon.indexOf("audio") !== -1 || name.indexOf("speaker") !== -1) return "󰓃";
        if (icon.indexOf("phone") !== -1) return "󰏲";
        if (icon.indexOf("mouse") !== -1) return "󰍽";
        if (icon.indexOf("keyboard") !== -1) return "󰌌";
        if (icon.indexOf("gaming") !== -1 || icon.indexOf("joystick") !== -1 || name.indexOf("controller") !== -1) return "󰊴";
        return "󰂯";
    }

    function batteryOf(d) {
        return (d && d.batteryAvailable) ? Math.round(d.battery * 100) : -1;
    }

    function batteryColor(p) {
        if (p < 0) return ThemeBackend.surface1;
        if (p <= 15) return ThemeBackend.red;
        if (p <= 30) return ThemeBackend.yellow;
        return ThemeBackend.green;
    }

    // Selected device, or the best guess: connected audio > connected > paired audio > first paired.
    readonly property var device: {
        let list = window.devices;
        if (window.selectedMac !== "") {
            for (let i = 0; i < list.length; i++) {
                if ((list[i].address || "").toUpperCase() === window.selectedMac) return list[i];
            }
        }
        for (let i = 0; i < list.length; i++) if (list[i].connected) return list[i];
        return list.length > 0 ? list[0] : null;
    }

    readonly property string mac: device ? (device.address || "").toUpperCase() : ""
    readonly property string deviceName: device ? (device.name || device.deviceName || mac) : ""
    readonly property bool isConnected: device ? device.connected : false
    readonly property bool isConnecting: device ? (device.state === BluetoothDeviceState.Connecting || (window.pendingMac === window.mac && !device.connected)) : false
    readonly property bool isDisconnecting: device ? device.state === BluetoothDeviceState.Disconnecting : false
    readonly property int battery: batteryOf(device)

    readonly property var connectedDevices: devices.filter(d => d.connected)

    readonly property PwNode sinkNode: {
        if (!isConnected || mac === "") return null;
        let underscored = mac.replace(/:/g, "_");
        let outs = Audio.outputs;
        for (let i = 0; i < outs.length; i++) {
            let n = outs[i];
            let addr = (n.properties?.["api.bluez5.address"] || "").toUpperCase();
            if (addr === mac || (n.name || "").toUpperCase().indexOf(underscored) !== -1) return n;
        }
        return null;
    }
    readonly property bool isDefaultSink: sinkNode !== null && sinkNode === Audio.defaultSink
    readonly property int sinkVol: sinkNode && sinkNode.audio ? Math.round(sinkNode.audio.volume * 100) : 0
    readonly property bool sinkMute: sinkNode && sinkNode.audio ? sinkNode.audio.muted : false
    readonly property string codec: {
        let c = sinkNode ? (sinkNode.properties?.["api.bluez5.codec"] || "") : "";
        return c !== "" ? c.toUpperCase() : "—";
    }

    function profileFor(prefix) {
        let ps = cardInfo && cardInfo.profiles ? cardInfo.profiles : [];
        for (let i = 0; i < ps.length; i++) {
            if (ps[i].available && ps[i].name.indexOf(prefix) === 0) return ps[i].name;
        }
        return "";
    }
    readonly property string hifiProfile: profileFor("a2dp")
    readonly property string headsetProfile: profileFor("headset")
    readonly property string activeProfile: cardInfo && cardInfo.active ? cardInfo.active : ""
    readonly property bool hasProfileChoice: isConnected && hifiProfile !== "" && headsetProfile !== ""
    readonly property int profileIndex: activeProfile.indexOf("headset") === 0 ? 1 : 0
    onProfileIndexChanged: if (profileSwitch.currentIndex !== profileIndex) profileSwitch.currentIndex = profileIndex

    readonly property string statusText: {
        if (!device) return "";
        if (isDisconnecting) return I18n.t("btdevice.status.disconnecting");
        if (isConnecting) return I18n.t("btdevice.status.connecting");
        if (!isConnected) return I18n.t("btdevice.status.disconnected");
        if (activeProfile.indexOf("headset") === 0) return I18n.t("btdevice.status.connected_headset");
        if (activeProfile.indexOf("a2dp") === 0) return I18n.t("btdevice.status.connected_hifi");
        return I18n.t("btdevice.status.connected");
    }
    readonly property color statusColor: (isConnecting || isDisconnecting) ? ThemeBackend.yellow : (isConnected ? ThemeBackend.green : ThemeBackend.overlay1)

    function connectDevice(d) {
        if (!d) return;
        window.selectedMac = (d.address || "").toUpperCase();
        if (d.connected) return;
        window.pendingMac = window.selectedMac;
        pendingTimeout.restart();
        d.connect();
    }

    function setProfile(name) {
        if (!cardInfo || !cardInfo.card || name === "" || name === activeProfile) return;
        Quickshell.execDetached(["pactl", "set-card-profile", cardInfo.card, name]);
        profileRefresh.restart();
    }

    function refreshCard() {
        if (window.mac === "" || !window.isConnected) {
            window.cardInfo = ({});
            return;
        }
        if (!cardPoller.running) cardPoller.running = true;
    }

    onMacChanged: { window.cardInfo = ({}); window.forgetArmed = false; refreshCard(); }
    onIsConnectedChanged: {
        if (isConnected && pendingMac === mac) {
            pendingMac = "";
            Sounds.playSfx("network/connect.wav");
        }
        refreshCard();
        if (!isConnected) disconnectClose.restart();
        else disconnectClose.stop();
    }

    // The popup only makes sense while the earbuds are connected.
    Timer {
        id: disconnectClose
        interval: 800
        onTriggered: if (!window.isConnected && !window.isConnecting) window.closePopup()
    }

    Timer {
        id: pendingTimeout
        interval: 20000
        onTriggered: window.pendingMac = ""
    }

    Timer {
        id: forgetDisarm
        interval: 3000
        onTriggered: window.forgetArmed = false
    }

    Timer {
        id: profileRefresh
        interval: 900
        onTriggered: window.refreshCard()
    }

    Timer {
        interval: 4000
        repeat: true
        running: window.visible && window.isConnected
        onTriggered: window.refreshCard()
    }

    Process {
        id: cardPoller
        command: ["bash", window.scriptsDir + "/bt_device_info.sh", window.mac]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let text = this.text.trim();
                    window.cardInfo = text !== "" ? JSON.parse(text) : ({});
                } catch (e) {
                    window.cardInfo = ({});
                }
            }
        }
    }

    // Per-earbud battery and noise control from buds_daemon.py (Galaxy Buds only).
    property var budsState: ({})
    property var budsUnsupported: ({})
    property int budsFailures: 0
    readonly property bool hasBuds: budsState.left !== undefined && budsState.right !== undefined
    readonly property bool wantBuds: window.visible && window.isConnected && window.isBuds(window.device) && !budsUnsupported[window.mac]

    function noiseIndex(mode) {
        if (mode === "ambient") return 1;
        if (mode === "anc") return 2;
        return 0;
    }
    readonly property int currentNoiseIndex: noiseIndex(budsState.noise)
    onCurrentNoiseIndexChanged: if (noiseSwitch.currentIndex !== currentNoiseIndex) noiseSwitch.currentIndex = currentNoiseIndex

    function setNoise(index) {
        let mode = index === 1 ? "ambient" : (index === 2 ? "anc" : "off");
        if (budsState.noise === mode || !budsProc.running) return;
        budsProc.write("noise " + mode + "\n");
    }

    onWantBudsChanged: {
        if (wantBuds) {
            budsFailures = 0;
            budsRestart.stop();
            budsProc.running = true;
        } else {
            budsRestart.stop();
            budsProc.running = false;
        }
    }

    Process {
        id: budsProc
        property string targetMac: ""
        command: ["python3", window.scriptsDir + "/buds_daemon.py", window.mac]
        stdinEnabled: true
        running: false
        onRunningChanged: {
            if (running) {
                targetMac = window.mac;
            } else {
                window.budsState = ({});
                if (window.wantBuds) budsRestart.restart();
            }
        }
        stdout: SplitParser {
            onRead: data => {
                let msg;
                try { msg = JSON.parse(data); } catch (e) { return; }
                if (msg.error === "unsupported") {
                    let u = Object.assign({}, window.budsUnsupported);
                    u[budsProc.targetMac] = true;
                    window.budsUnsupported = u;
                } else if (msg.error) {
                    window.budsFailures++;
                    if (window.budsFailures >= 3) {
                        let u = Object.assign({}, window.budsUnsupported);
                        u[budsProc.targetMac] = true;
                        window.budsUnsupported = u;
                    }
                } else {
                    window.budsFailures = 0;
                    window.budsState = msg;
                }
            }
        }
    }

    Timer {
        id: budsRestart
        interval: window.budsFailures > 0 ? 8000 : 2500
        onTriggered: if (window.wantBuds && !budsProc.running) budsProc.running = true
    }

    // Popup height follows its content; Main.qml animates to it.
    property real targetMasterHeight: window.s(480)
    readonly property real desiredHeight: {
        if (!window.adapterOn || window.device === null) return window.s(280);
        return Math.ceil(mainCol.implicitHeight + window.s(36));
    }
    function syncHeight() {
        if (window.visible && desiredHeight >= 50) window.targetMasterHeight = desiredHeight;
    }
    onDesiredHeightChanged: Qt.callLater(syncHeight)

    property real introMain: 0
    property real introHeader: 0
    property real introContent: 0

    ParallelAnimation {
        id: introAnim
        running: false
        NumberAnimation { target: window; property: "introMain"; from: 0; to: 1.0; duration: 800; easing.type: Easing.OutExpo }
        SequentialAnimation {
            PauseAnimation { duration: 100 }
            NumberAnimation { target: window; property: "introHeader"; from: 0; to: 1.0; duration: 700; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }
        SequentialAnimation {
            PauseAnimation { duration: 200 }
            NumberAnimation { target: window; property: "introContent"; from: 0; to: 1.0; duration: 800; easing.type: Easing.OutExpo }
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: window.forceActiveFocus()
    }

    function onShown() {
        forceActiveFocus();
        focusTimer.restart();
        introMain = 0; introHeader = 0; introContent = 0;
        introAnim.restart();
        refreshCard();
        Qt.callLater(syncHeight);
        if (autoOpened) autoClose.restart();
        if (!isConnected) disconnectClose.restart();
    }

    onVisibleChanged: {
        if (visible) {
            onShown();
        } else {
            introAnim.stop();
            introMain = 0; introHeader = 0; introContent = 0;
            forgetArmed = false;
            autoOpened = false;
            autoClose.stop();
        }
    }

    Component.onCompleted: if (visible) onShown()

    Item {
        anchors.fill: parent
        scale: 0.95 + (0.05 * introMain)
        opacity: introMain
        transform: Translate { y: window.s(-20) * (1 - introMain) }

        Rectangle {
            anchors.fill: parent
            radius: ThemeBackend.borderRadius
            color: ThemeBackend.base
            border.color: ThemeBackend.surface0
            border.width: 1
            clip: true

            Rectangle {
                width: parent.width * 1.1; height: width; radius: width / 2
                x: parent.width * 0.35; y: -height * 0.55
                color: window.isConnected ? ThemeBackend.mauve : ThemeBackend.surface1
                opacity: 0.06
                Behavior on color { ColorAnimation { duration: 600 } }
            }

            // Adapter missing or off
            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - window.s(48)
                spacing: window.s(12)
                visible: !window.adapter || !window.adapterOn || window.devices.length === 0

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    font.family: ThemeBackend.iconFont; font.pixelSize: window.s(42)
                    color: ThemeBackend.surface2
                    text: "󰂲"
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    font.family: ThemeBackend.fontFamily; font.pixelSize: window.s(14); font.weight: Font.Bold
                    color: ThemeBackend.text
                    text: !window.adapter ? I18n.t("btdevice.no_adapter") : (!window.adapterOn ? I18n.t("btdevice.adapter_off") : I18n.t("btdevice.no_devices"))
                }
                ClickButton {
                    Layout.alignment: Qt.AlignHCenter
                    visible: window.adapter !== null && !window.adapterOn
                    height: window.s(36)
                    horizontalPadding: window.s(18)
                    cornerRadius: ThemeBackend.borderRadius
                    buttonText: I18n.t("btdevice.turn_on")
                    textFontSize: window.s(13)
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.crust
                    onClicked: if (window.adapter) window.adapter.enabled = true
                }
                ClickButton {
                    Layout.alignment: Qt.AlignHCenter
                    visible: window.adapterOn && window.devices.length === 0
                    height: window.s(36)
                    horizontalPadding: window.s(18)
                    cornerRadius: ThemeBackend.borderRadius
                    buttonText: I18n.t("btdevice.open_panel")
                    textFontSize: window.s(13)
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    onClicked: Quickshell.execDetached(["bash", "-c", Caching.ghostDir + "/scripts/qs_manager.sh open network bt"])
                }
            }

            ColumnLayout {
                id: mainCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: window.s(18)
                spacing: window.s(14)
                visible: window.adapterOn && window.device !== null

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: window.s(12)
                    opacity: introHeader
                    transform: Translate { y: window.s(15) * (1.0 - introHeader) }

                    Rectangle {
                        Layout.preferredWidth: window.s(42)
                        Layout.preferredHeight: window.s(42)
                        radius: ThemeBackend.borderRadius
                        color: ThemeBackend.surface0
                        Text {
                            anchors.centerIn: parent
                            font.family: ThemeBackend.iconFont; font.pixelSize: window.s(21)
                            color: window.isConnected ? ThemeBackend.mauve : ThemeBackend.subtext0
                            text: window.deviceIcon(window.device)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: window.s(2)
                        Text {
                            Layout.fillWidth: true; elide: Text.ElideRight
                            font.family: ThemeBackend.fontFamily; font.weight: Font.Black; font.pixelSize: window.s(16)
                            color: ThemeBackend.text
                            text: window.deviceName
                        }
                        RowLayout {
                            spacing: window.s(6)
                            Rectangle {
                                Layout.preferredWidth: window.s(7); Layout.preferredHeight: window.s(7); radius: width / 2
                                color: window.statusColor
                                SequentialAnimation on opacity {
                                    running: window.isConnecting || window.isDisconnecting
                                    loops: Animation.Infinite
                                    onRunningChanged: if (!running) parent.opacity = 1
                                    NumberAnimation { to: 0.2; duration: 500 }
                                    NumberAnimation { to: 1.0; duration: 500 }
                                }
                            }
                            Text {
                                Layout.fillWidth: true; elide: Text.ElideRight
                                font.family: ThemeBackend.fontFamily; font.pixelSize: window.s(12)
                                color: window.statusColor
                                text: window.statusText
                            }
                        }
                    }

                    IconButton {
                        size: window.s(34)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: "󰒓"
                        iconFontSize: window.s(16)
                        accentColor: ThemeBackend.surface0
                        textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.subtext0
                        onClicked: Quickshell.execDetached(["bash", "-c", Caching.ghostDir + "/scripts/qs_manager.sh open network bt"])
                    }
                }

                // Switcher between connected headphones
                RowLayout {
                    Layout.fillWidth: true
                    spacing: window.s(8)
                    visible: window.connectedDevices.length > 1
                    opacity: introHeader

                    Repeater {
                        model: window.connectedDevices
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool selected: (modelData.address || "").toUpperCase() === window.mac
                            readonly property int pct: window.batteryOf(modelData)
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: window.s(34)
                            radius: ThemeBackend.borderRadius
                            color: selected ? ThemeBackend.mauve : (chipMa.containsMouse ? ThemeBackend.surface0 : ThemeBackend.mantle)
                            Behavior on color { ColorAnimation { duration: 180 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: window.s(10)
                                anchors.rightMargin: window.s(10)
                                spacing: window.s(6)
                                Text {
                                    font.family: ThemeBackend.iconFont; font.pixelSize: window.s(14)
                                    color: selected ? ThemeBackend.crust : ThemeBackend.subtext0
                                    text: window.deviceIcon(modelData)
                                }
                                Text {
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                    font.family: ThemeBackend.fontFamily; font.weight: Font.Bold; font.pixelSize: window.s(11.5)
                                    color: selected ? ThemeBackend.crust : ThemeBackend.text
                                    text: modelData.name || modelData.deviceName || modelData.address
                                }
                                Text {
                                    visible: pct >= 0
                                    font.family: ThemeBackend.fontFamily; font.pixelSize: window.s(11)
                                    color: selected ? ThemeBackend.crust : ThemeBackend.subtext0
                                    text: pct + "%"
                                }
                            }

                            MouseArea {
                                id: chipMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.selectedMac = (modelData.address || "").toUpperCase()
                            }
                        }
                    }
                }

                // Per-earbud battery (Galaxy Buds helper)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: window.s(4)
                    visible: window.hasBuds
                    opacity: introContent
                    transform: Translate { y: window.s(15) * (1.0 - introContent) }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: window.s(4)

                        Repeater {
                            model: ["left", "center", "right"]
                            delegate: Item {
                                required property string modelData
                                readonly property bool isCenter: modelData === "center"
                                readonly property int pct: isCenter ? -1 : (window.budsState[modelData] !== undefined ? window.budsState[modelData] : -1)
                                readonly property bool worn: modelData === "left" ? window.budsState.wearLeft === true : window.budsState.wearRight === true
                                Layout.fillWidth: !isCenter
                                Layout.preferredWidth: isCenter ? window.s(92) : window.s(110)
                                Layout.preferredHeight: window.s(132)

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: window.s(4)
                                    visible: !isCenter

                                    EarbudGauge {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.preferredWidth: window.s(104)
                                        Layout.preferredHeight: window.s(104)
                                        percent: pct
                                        mirrored: modelData === "left"
                                        ringColor: window.batteryColor(pct)
                                        artOpacity: worn ? 1.0 : 0.55
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        font.family: ThemeBackend.fontFamily; font.pixelSize: window.s(11.5); font.weight: Font.Bold
                                        color: ThemeBackend.subtext0
                                        text: (modelData === "left" ? I18n.t("btdevice.left") : I18n.t("btdevice.right")) + " " + (pct >= 0 ? pct + "%" : "—")
                                    }
                                }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    width: parent.width
                                    spacing: window.s(2)
                                    visible: isCenter
                                    Text {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        font.family: ThemeBackend.fontFamily; font.weight: Font.Black; font.pixelSize: window.s(30)
                                        color: ThemeBackend.text
                                        text: Math.min(window.budsState.left || 0, window.budsState.right || 0) + "%"
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                        wrapMode: Text.WordWrap
                                        font.family: ThemeBackend.fontFamily; font.pixelSize: window.s(10.5)
                                        color: ThemeBackend.subtext0
                                        text: I18n.t("btdevice.lowest")
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: window.s(8)
                        Text {
                            font.family: ThemeBackend.iconFont; font.pixelSize: window.s(13)
                            color: ThemeBackend.subtext0
                            text: "󰏵"
                        }
                        Text {
                            font.family: ThemeBackend.fontFamily; font.pixelSize: window.s(11.5)
                            color: ThemeBackend.subtext0
                            text: window.budsState.case > 0 ? I18n.t("btdevice.case") + " " + window.budsState.case + "%" : I18n.t("btdevice.case_unknown")
                        }
                    }
                }

                // Battery hero (single value from BlueZ)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: window.s(132)
                    visible: !window.hasBuds
                    spacing: window.s(20)
                    opacity: introContent
                    transform: Translate { y: window.s(15) * (1.0 - introContent) }

                    Item { Layout.fillWidth: true }

                    EarbudGauge {
                        Layout.preferredWidth: window.s(124)
                        Layout.preferredHeight: window.s(124)
                        percent: window.isConnected ? window.battery : (window.isConnecting ? 25 : -1)
                        ringColor: window.isConnecting ? ThemeBackend.yellow : window.batteryColor(window.battery)
                        art: window.artFor(window.device)
                        artOpacity: window.isConnected ? 1.0 : (window.isConnecting ? 0.55 : 0.35)
                    }

                    ColumnLayout {
                        Layout.preferredWidth: window.s(140)
                        spacing: window.s(2)
                        Text {
                            Layout.fillWidth: true
                            fontSizeMode: Text.HorizontalFit
                            minimumPixelSize: window.s(14)
                            font.family: ThemeBackend.fontFamily; font.weight: Font.Black
                            font.pixelSize: (window.isConnected && window.battery >= 0) ? window.s(36) : window.s(20)
                            color: window.isConnected ? ThemeBackend.text : ThemeBackend.subtext0
                            text: {
                                if (window.isConnecting) return I18n.t("btdevice.waiting");
                                if (!window.isConnected) return I18n.t("btdevice.status.disconnected");
                                return window.battery >= 0 ? window.battery + "%" : "—";
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            font.family: ThemeBackend.fontFamily; font.pixelSize: window.s(11.5)
                            color: ThemeBackend.subtext0
                            text: {
                                if (window.isConnecting) return I18n.t("btdevice.waiting_hint");
                                if (!window.isConnected) return window.device && window.device.trusted ? I18n.t("btdevice.paired_trusted") : I18n.t("btdevice.paired");
                                return window.battery >= 0 ? I18n.t("btdevice.battery") : I18n.t("btdevice.battery_unknown");
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                // Volume
                RowLayout {
                    Layout.fillWidth: true
                    spacing: window.s(10)
                    visible: window.sinkNode !== null
                    opacity: introContent

                    IconButton {
                        size: window.s(28)
                        cornerRadius: window.s(8)
                        buttonIcon: window.sinkMute || window.sinkVol === 0 ? "󰖁" : (window.sinkVol > 50 ? "󰕾" : "󰖀")
                        iconFontSize: window.s(15)
                        accentColor: ThemeBackend.surface0
                        textColor: isHoveredOrHighlighted ? ThemeBackend.text : (window.sinkMute ? ThemeBackend.overlay0 : ThemeBackend.subtext0)
                        onClicked: Audio.toggleMute(window.sinkNode)
                    }

                    Draggable {
                        Layout.fillWidth: true
                        Layout.preferredHeight: window.s(16)
                        from: 0.0
                        to: 100.0
                        value: window.sinkVol
                        backgroundColor: ThemeBackend.surface0
                        accentColor: window.sinkMute ? ThemeBackend.surface2 : ThemeBackend.mauve
                        gradColor1: window.sinkMute ? ThemeBackend.surface2 : ThemeBackend.mauve
                        gradColor2: window.sinkMute ? ThemeBackend.surface2 : Qt.lighter(ThemeBackend.mauve, 1.05)
                        gradColor3: window.sinkMute ? ThemeBackend.surface2 : Qt.lighter(ThemeBackend.mauve, 1.10)
                        cornerRadius: window.s(5)
                        handleSize: window.s(18)
                        handleColor: window.sinkMute ? ThemeBackend.overlay0 : Qt.lighter(ThemeBackend.mauve, 1.15)
                        handleHoverColor: window.sinkMute ? ThemeBackend.subtext0 : Qt.lighter(ThemeBackend.mauve, 1.5)
                        handleDragColor: window.sinkMute ? ThemeBackend.text : Qt.lighter(ThemeBackend.mauve, 1.45)
                        handleBorderColor: Qt.rgba(0, 0, 0, 0.2)
                        onMoved: (val) => {
                            let pct = Math.max(0, Math.min(100, Math.round(val)));
                            if (pct > 0 && window.sinkMute) Audio.toggleMute(window.sinkNode);
                            Audio.setVolume(window.sinkNode, pct);
                        }
                    }

                    Text {
                        Layout.preferredWidth: window.s(34)
                        horizontalAlignment: Text.AlignRight
                        font.family: ThemeBackend.fontFamily; font.weight: Font.Bold; font.pixelSize: window.s(11)
                        color: ThemeBackend.subtext0
                        text: window.sinkVol + "%"
                    }
                }

                // Noise control (Galaxy Buds helper)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: window.s(6)
                    visible: window.hasBuds && window.budsState.noise !== undefined
                    opacity: introContent

                    Text {
                        font.family: ThemeBackend.fontFamily; font.pixelSize: window.s(11); font.weight: Font.Bold
                        color: ThemeBackend.overlay1
                        text: I18n.t("btdevice.noise")
                    }
                    Switch {
                        id: noiseSwitch
                        Layout.fillWidth: true
                        Layout.preferredHeight: window.s(36)
                        options: [I18n.t("btdevice.noise_off"), I18n.t("btdevice.noise_ambient"), I18n.t("btdevice.noise_anc")]
                        currentIndex: 0
                        cornerRadius: ThemeBackend.borderRadius
                        baseColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.subtext0
                        activeTextColor: ThemeBackend.crust
                        fontPixelSize: window.s(12)
                        Component.onCompleted: currentIndex = window.currentNoiseIndex
                        onValueChanged: function(index, value) { window.setNoise(index); }
                    }
                }

                // Audio profile
                Switch {
                    id: profileSwitch
                    Layout.fillWidth: true
                    Layout.preferredHeight: window.s(36)
                    visible: window.hasProfileChoice
                    options: [I18n.t("btdevice.profile_hifi"), I18n.t("btdevice.profile_headset")]
                    currentIndex: 0
                    cornerRadius: ThemeBackend.borderRadius
                    baseColor: ThemeBackend.surface0
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.subtext0
                    activeTextColor: ThemeBackend.crust
                    fontPixelSize: window.s(12)
                    opacity: introContent
                    Component.onCompleted: currentIndex = window.profileIndex
                    onValueChanged: function(index, value) {
                        window.setProfile(index === 1 ? window.headsetProfile : window.hifiProfile);
                    }
                }

                // Details
                RowLayout {
                    Layout.fillWidth: true
                    spacing: window.s(8)
                    visible: window.isConnected
                    opacity: introContent

                    Repeater {
                        model: [
                            { label: I18n.t("btdevice.codec"), value: window.codec, action: "" },
                            { label: I18n.t("btdevice.output"), value: window.isDefaultSink ? I18n.t("btdevice.output_default") : I18n.t("btdevice.output_use"), action: window.isDefaultSink || !window.sinkNode ? "" : "default" },
                            { label: "MAC", value: window.mac, action: "" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: window.s(46)
                            radius: ThemeBackend.borderRadius
                            color: metaMa.containsMouse ? ThemeBackend.surface0 : ThemeBackend.mantle
                            Behavior on color { ColorAnimation { duration: 180 } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.leftMargin: window.s(10)
                                anchors.rightMargin: window.s(10)
                                spacing: 0
                                Item { Layout.fillHeight: true }
                                Text {
                                    font.family: ThemeBackend.fontFamily; font.pixelSize: window.s(10.5)
                                    color: ThemeBackend.overlay1
                                    text: modelData.label
                                }
                                Text {
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                    font.family: ThemeBackend.fontFamily; font.weight: Font.Bold; font.pixelSize: window.s(12)
                                    color: modelData.action !== "" ? ThemeBackend.mauve : ThemeBackend.text
                                    text: modelData.value
                                }
                                Item { Layout.fillHeight: true }
                            }

                            MouseArea {
                                id: metaMa
                                anchors.fill: parent
                                enabled: modelData.action !== ""
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Audio.setDefaultOutput(window.sinkNode)
                            }
                        }
                    }
                }

                // Actions
                RowLayout {
                    Layout.fillWidth: true
                    spacing: window.s(8)
                    opacity: introContent

                    ClickButton {
                        Layout.fillWidth: true
                        height: window.s(38)
                        Layout.preferredHeight: window.s(38)
                        cornerRadius: ThemeBackend.borderRadius
                        textFontSize: window.s(13)
                        buttonText: window.isConnecting ? I18n.t("btdevice.cancel")
                            : (window.isConnected ? I18n.t("btdevice.disconnect") : I18n.t("btdevice.connect"))
                        accentColor: (window.isConnected || window.isConnecting) ? ThemeBackend.surface0 : ThemeBackend.mauve
                        textColor: (window.isConnected || window.isConnecting) ? ThemeBackend.text : ThemeBackend.crust
                        enabled: !window.isDisconnecting
                        onClicked: {
                            if (!window.device) return;
                            if (window.isConnected || window.isConnecting) {
                                window.pendingMac = "";
                                window.device.disconnect();
                                Sounds.playSfx("network/disconnect.wav");
                            } else {
                                window.connectDevice(window.device);
                            }
                        }
                    }

                    ClickButton {
                        Layout.fillWidth: true
                        height: window.s(38)
                        Layout.preferredHeight: window.s(38)
                        cornerRadius: ThemeBackend.borderRadius
                        textFontSize: window.s(13)
                        buttonText: window.forgetArmed ? I18n.t("btdevice.confirm_forget") : I18n.t("btdevice.forget")
                        accentColor: window.forgetArmed ? ThemeBackend.red : ThemeBackend.surface0
                        textColor: window.forgetArmed ? ThemeBackend.crust : ThemeBackend.red
                        onClicked: {
                            if (!window.device) return;
                            if (!window.forgetArmed) {
                                window.forgetArmed = true;
                                forgetDisarm.restart();
                                return;
                            }
                            window.forgetArmed = false;
                            window.selectedMac = "";
                            window.device.forget();
                        }
                    }
                }
            }
        }
    }
}
