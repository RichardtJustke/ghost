import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore
import Quickshell
import Quickshell.Io
import QtQuick.Window
import "../"
import "../reusables"

Item {
    id: window
    visible: false
    focus: true

    function s(val) {
        return Scaler.s(val);
    }

    property real targetMasterHeight: window.s(340)
    property real targetMasterWidth: window.s(940)
    implicitWidth: targetMasterWidth
    implicitHeight: targetMasterHeight
    width: targetMasterWidth
    height: targetMasterHeight

    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: window.forceActiveFocus()
    }

    Shortcut {
        sequence: "Left"
        enabled: window.visible
        onActivated: {
            if (calHover.hovered) {
                window.setMonthOffset(window.targetMonthOffset - 1);
            } else {
                window.setWeatherView(window.targetWeatherView - 1);
            }
        }
    }

    Shortcut {
        sequence: "Right"
        enabled: window.visible
        onActivated: {
            if (calHover.hovered) {
                window.setMonthOffset(window.targetMonthOffset + 1);
            } else {
                window.setWeatherView(window.targetWeatherView + 1);
            }
        }
    }

    readonly property color base: ThemeBackend.base
    readonly property color mantle: ThemeBackend.mantle
    readonly property color crust: ThemeBackend.crust
    readonly property color text: ThemeBackend.text
    readonly property color subtext1: ThemeBackend.subtext1
    readonly property color subtext0: ThemeBackend.subtext0
    readonly property color overlay2: ThemeBackend.overlay2
    readonly property color overlay1: ThemeBackend.overlay1
    readonly property color overlay0: ThemeBackend.overlay0
    readonly property color surface2: ThemeBackend.surface2
    readonly property color surface1: ThemeBackend.surface1
    readonly property color surface0: ThemeBackend.surface0

    readonly property color mauve: ThemeBackend.mauve
    readonly property color pink: ThemeBackend.pink
    readonly property color blue: ThemeBackend.blue
    readonly property color sapphire: ThemeBackend.sapphire
    readonly property color peach: ThemeBackend.peach
    readonly property color yellow: ThemeBackend.yellow
    readonly property color teal: ThemeBackend.teal
    readonly property color green: ThemeBackend.green
    readonly property color red: ThemeBackend.red

    readonly property string scriptsDir: Caching.qsDir + "/calendar"

    readonly property color timeColor: {
        let h = window.currentTime.getHours();
        if (h >= 5 && h < 12) return window.peach;
        if (h >= 12 && h < 17) return window.sapphire;
        if (h >= 17 && h < 21) return window.mauve;
        return window.blue;
    }

    readonly property color timeAccent: {
        let h = window.currentTime.getHours();
        if (h >= 5 && h < 12) return window.yellow;
        if (h >= 12 && h < 17) return window.teal;
        if (h >= 17 && h < 21) return window.pink;
        return window.mauve;
    }

    readonly property color textAccent: Qt.tint(window.timeAccent, Qt.alpha(window.text, 0.35))

    property bool startupComplete: false
    property real introMain: 0
    property real introAmbient: 0
    property real introClock: 0
    property real introCalendar: 0
    property real introWeather: 0

    property var exitCallback: null

    function startExit(onFinished) {
        introAnim.stop();
        exitCallback = onFinished;
        exitAnim.restart();
    }

    function resetAndPlayIntro() {
        exitAnim.stop();
        startupComplete = false;
        introMain = 0;
        introAmbient = 0;
        introClock = 0;
        introCalendar = 0;
        introWeather = 0;
        transitionSpin = 0.0;
        transitionScale = 1.0;
        weatherContentOpacity = 1.0;
        weatherContentOffset = 0.0;
        calendarContentOpacity = 1.0;
        calendarContentOffset = 0.0;
        introAnim.restart();
    }

    onVisibleChanged: {
        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            window.currentTime = new Date();
            updateCalendarGrid();
            Weather.refresh(false);
            resetAndPlayIntro();
        } else {
            introAnim.stop();
            exitAnim.stop();
            weatherTransitionAnim.stop();
            calendarTransitionAnim.stop();
            startupComplete = false;
            introMain = 0;
            introAmbient = 0;
            introClock = 0;
            introCalendar = 0;
            introWeather = 0;
            transitionSpin = 0.0;
            transitionScale = 1.0;
            weatherContentOpacity = 1.0;
            weatherContentOffset = 0.0;
            calendarContentOpacity = 1.0;
            calendarContentOffset = 0.0;
        }
    }

    SequentialAnimation {
        id: introAnim
        running: false

        PauseAnimation { duration: 20 }

        ParallelAnimation {
            NumberAnimation { target: window; property: "introMain"; from: 0; to: 1.0; duration: 800; easing.type: Easing.OutQuart }

            SequentialAnimation {
                PauseAnimation { duration: 150 }
                NumberAnimation { target: window; property: "introAmbient"; from: 0; to: 1.0; duration: 1000; easing.type: Easing.OutSine }
            }

            SequentialAnimation {
                PauseAnimation { duration: 250 }
                NumberAnimation { target: window; property: "introClock"; from: 0; to: 1.0; duration: 900; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
            }

            SequentialAnimation {
                PauseAnimation { duration: 350 }
                NumberAnimation { target: window; property: "introCalendar"; from: 0; to: 1.0; duration: 850; easing.type: Easing.OutQuint }
            }

            SequentialAnimation {
                PauseAnimation { duration: 400 }
                NumberAnimation { target: window; property: "introWeather"; from: 0; to: 1.0; duration: 850; easing.type: Easing.OutQuint }
            }
        }
        ScriptAction { script: window.startupComplete = true }
    }

    SequentialAnimation {
        id: exitAnim
        running: false
        ParallelAnimation {
            NumberAnimation { target: window; property: "introWeather"; to: 0; duration: 150; easing.type: Easing.InCubic }
            NumberAnimation { target: window; property: "introCalendar"; to: 0; duration: 150; easing.type: Easing.InCubic }
            SequentialAnimation {
                PauseAnimation { duration: 30 }
                NumberAnimation { target: window; property: "introClock"; to: 0; duration: 160; easing.type: Easing.InBack }
                NumberAnimation { target: window; property: "introAmbient"; to: 0; duration: 140; easing.type: Easing.InQuad }
            }
            SequentialAnimation {
                PauseAnimation { duration: 50 }
                NumberAnimation { target: window; property: "introMain"; to: 0; duration: 180; easing.type: Easing.InQuart }
            }
        }
        ScriptAction {
            script: {
                if (window.exitCallback) {
                    let cb = window.exitCallback;
                    window.exitCallback = null;
                    cb();
                }
            }
        }
    }

    property var currentTime: new Date()
    property real currentEpoch: currentTime.getTime() / 1000

    Timer {
        interval: 1000; running: window.visible; repeat: true
        onTriggered: {
            window.currentTime = new Date();

            if (window.currentTime.getHours() === 0 && window.currentTime.getMinutes() === 0 && window.currentTime.getSeconds() === 0) {
                updateCalendarGrid();
            }
        }
    }

    property var weatherData: Weather.data
    property int weatherView: 0
    property color activeWeatherHex: {
        if (!window.weatherData) return window.mauve;
        if (window.weatherView === 0 && window.weatherData.current_hex) return window.weatherData.current_hex;
        if (window.weatherData.forecast && window.weatherData.forecast[window.weatherView]) return window.weatherData.forecast[window.weatherView].hex;
        return window.mauve;
    }

    property int targetWeatherView: 0
    property real weatherContentOpacity: 1.0
    property real weatherContentOffset: 0.0
    property int weatherAnimDirection: 1

    property real transitionSpin: 0.0
    property real transitionScale: 1.0

    property real targetTemp: {
        if (!window.weatherData || window.weatherData.offline) return 0;
        if (window.targetWeatherView === 0 && window.weatherData.current_temp !== undefined) {
            return Number(window.weatherData.current_temp);
        }
        if (window.weatherData.forecast && window.weatherData.forecast[window.targetWeatherView]) {
            return Number(window.weatherData.forecast[window.targetWeatherView].max);
        }
        return 0;
    }

    property real displayedTemp: targetTemp

    Behavior on displayedTemp {
        NumberAnimation {
            id: tempAnim
            duration: 800
            easing.type: Easing.OutQuart
        }
    }

    property bool isTempAnimating: tempAnim.running
    property color tempGlowColor: {
        if (!isTempAnimating || !window.startupComplete) return window.text;
        if (window.targetTemp > window.displayedTemp) return window.red;
        if (window.targetTemp < window.displayedTemp) return window.blue;
        return window.text;
    }

    SequentialAnimation {
        id: weatherTransitionAnim
        ParallelAnimation {
            NumberAnimation { target: window; property: "weatherContentOpacity"; to: 0.0; duration: 250; easing.type: Easing.InSine }
            NumberAnimation { target: window; property: "weatherContentOffset"; to: -window.s(40) * weatherAnimDirection; duration: 250; easing.type: Easing.InSine }
            NumberAnimation { target: window; property: "transitionSpin"; to: 180 * weatherAnimDirection; duration: 300; easing.type: Easing.InBack }
            NumberAnimation { target: window; property: "transitionScale"; to: 0.8; duration: 300; easing.type: Easing.InCubic }
        }
        ScriptAction {
            script: {
                window.weatherView = window.targetWeatherView;
                window.weatherContentOffset = window.s(40) * weatherAnimDirection;
                window.transitionSpin = -180 * weatherAnimDirection;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: window; property: "weatherContentOpacity"; to: 1.0; duration: 450; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "weatherContentOffset"; to: 0.0; duration: 450; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "transitionSpin"; to: 0.0; duration: 600; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            NumberAnimation { target: window; property: "transitionScale"; to: 1.0; duration: 500; easing.type: Easing.OutBack }
        }
    }

    function setWeatherView(idx) {
        if (idx < 0 || idx > 4 || !window.weatherData) return;
        if (idx === window.targetWeatherView) return;

        if (weatherTransitionAnim.running) {
            weatherTransitionAnim.stop();
            window.weatherView = window.targetWeatherView;
            window.transitionSpin = 0.0;
            window.transitionScale = 1.0;
            window.weatherContentOpacity = 1.0;
            window.weatherContentOffset = 0.0;
        }

        window.weatherAnimDirection = idx > window.weatherView ? 1 : -1;
        window.targetWeatherView = idx;
        weatherTransitionAnim.start();
    }

    property int activeHourIndex: {
        if (window.weatherView !== 0 || !window.weatherData || !window.weatherData.forecast || !window.weatherData.forecast[0] || !window.weatherData.forecast[0].hourly) return -1;

        let ch = window.currentTime.getHours();
        let hrArr = window.weatherData.forecast[0].hourly.slice(0, 8);
        let bestIdx = -1;
        let minDiff = 999;

        for (let i = 0; i < hrArr.length; i++) {
            let timeStr = hrArr[i].time || "00:00";
            let parts = timeStr.trim().split(" ");
            let clockPart = parts.length > 1 && parts[0].includes("-") ? parts[1] : parts[0];
            let h = parseInt(clockPart.split(":")[0]);
            if (isNaN(h)) h = 0;
            let diff = Math.abs(h - ch);
            if (diff < minDiff) {
                minDiff = diff;
                bestIdx = i;
            }
        }
        return bestIdx !== -1 ? bestIdx : 0;
    }

    property int monthOffset: 0
    property int targetMonthOffset: 0
    property string targetMonthName: ""
    ListModel { id: calendarModel }

    property real calendarContentOpacity: 1.0
    property real calendarContentOffset: 0.0
    property int calendarAnimDirection: 1

    SequentialAnimation {
        id: calendarTransitionAnim
        ParallelAnimation {
            NumberAnimation { target: window; property: "calendarContentOpacity"; to: 0.0; duration: 200; easing.type: Easing.InSine }
            NumberAnimation { target: window; property: "calendarContentOffset"; to: -window.s(20) * calendarAnimDirection; duration: 200; easing.type: Easing.InSine }
        }
        ScriptAction {
            script: {
                window.monthOffset = window.targetMonthOffset;
                window.calendarContentOffset = window.s(20) * calendarAnimDirection;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: window; property: "calendarContentOpacity"; to: 1.0; duration: 350; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "calendarContentOffset"; to: 0.0; duration: 350; easing.type: Easing.OutQuart }
        }
    }

    function setMonthOffset(newOffset) {
        if (newOffset === window.targetMonthOffset) return;

        if (calendarTransitionAnim.running) {
            calendarTransitionAnim.stop();
            window.monthOffset = window.targetMonthOffset;
            window.calendarContentOpacity = 1.0;
            window.calendarContentOffset = 0.0;
        }

        window.calendarAnimDirection = newOffset > window.targetMonthOffset ? 1 : -1;
        window.targetMonthOffset = newOffset;
        calendarTransitionAnim.start();
    }

    function updateCalendarGrid() {
        let d = new Date(window.currentTime.getTime());
        d.setDate(1);
        d.setMonth(d.getMonth() + window.monthOffset);

        let targetMonth = d.getMonth();
        let targetYear = d.getFullYear();

        let actualToday = new Date();
        let isRealCurrentMonth = (actualToday.getMonth() === targetMonth && actualToday.getFullYear() === targetYear);
        let todayDate = actualToday.getDate();

        window.targetMonthName = d.toLocaleDateString(Qt.locale(I18n.currentLang), "MMMM yyyy");

        let firstDay = new Date(targetYear, targetMonth, 1).getDay();
        firstDay = (firstDay === 0) ? 6 : firstDay - 1;

        let daysInMonth = new Date(targetYear, targetMonth + 1, 0).getDate();
        let daysInPrevMonth = new Date(targetYear, targetMonth, 0).getDate();

        calendarModel.clear();

        for (let i = firstDay - 1; i >= 0; i--) {
            calendarModel.append({ dayNum: (daysInPrevMonth - i).toString(), isCurrentMonth: false, isToday: false });
        }
        for (let i = 1; i <= daysInMonth; i++) {
            calendarModel.append({ dayNum: i.toString(), isCurrentMonth: true, isToday: (isRealCurrentMonth && i === todayDate) });
        }
        let remaining = 42 - calendarModel.count;
        for (let i = 1; i <= remaining; i++) {
            calendarModel.append({ dayNum: i.toString(), isCurrentMonth: false, isToday: false });
        }
    }

    onMonthOffsetChanged: updateCalendarGrid()

    Component.onCompleted: {
        updateCalendarGrid();
        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            Weather.refresh(false);
            resetAndPlayIntro();
        }
    }

    // Hourly strip: 6 slots, starting at the current hour for today
    readonly property var hourlySlots: {
        if (!window.weatherData || !window.weatherData.forecast || !window.weatherData.forecast[window.weatherView]) return [];
        let hourly = window.weatherData.forecast[window.weatherView].hourly;
        if (!hourly) return [];
        let arr = hourly.slice(0, 8);
        let start = 0;
        if (window.weatherView === 0 && window.activeHourIndex > 0) {
            start = Math.max(0, Math.min(window.activeHourIndex, arr.length - 6));
        }
        return arr.slice(start, start + 6).map(function(h, i) {
            return { time: h.time, icon: h.icon, hex: h.hex, temp: h.temp, active: window.weatherView === 0 && (start + i) === window.activeHourIndex };
        });
    }

    readonly property var currentForecast: window.weatherData && window.weatherData.forecast && window.weatherData.forecast[window.weatherView] ? window.weatherData.forecast[window.weatherView] : null
    readonly property color cardColor: Qt.alpha(window.surface0, 0.35)
    readonly property real cardRadius: Math.min(ThemeBackend.borderRadius, window.s(16))

    Rectangle {
        anchors.fill: parent
        radius: ThemeBackend.borderRadius
        color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
        border.color: window.surface0
        border.width: 1
        clip: true
        scale: 0.95 + (0.05 * introMain)
        opacity: introMain

        RowLayout {
            anchors.fill: parent
            anchors.margins: window.s(14)
            spacing: window.s(12)

            // Month
            Rectangle {
                id: calendarRect
                Layout.preferredWidth: window.s(268)
                Layout.fillHeight: true
                color: window.cardColor
                radius: window.cardRadius

                opacity: introCalendar
                transform: Translate { x: -window.s(24) * (1.0 - introCalendar) }

                HoverHandler { id: calHover }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: window.s(10)
                    spacing: window.s(4)

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: window.s(4)
                        layoutDirection: I18n.layoutDirection
                        spacing: window.s(4)

                        IconButton {
                            Layout.preferredWidth: window.s(26)
                            Layout.preferredHeight: window.s(26)
                            size: window.s(26)
                            cornerRadius: window.s(8)
                            buttonIcon: I18n.rtl ? "" : ""
                            iconFontSize: window.s(13)
                            accentColor: window.surface0
                            textColor: window.text
                            onClicked: window.setMonthOffset(window.targetMonthOffset - 1)
                        }

                        Text {
                            Layout.fillWidth: true
                            text: window.targetMonthName.toUpperCase()
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Black
                            font.pixelSize: window.s(12)
                            fontSizeMode: Text.Fit
                            minimumPixelSize: window.s(8)
                            color: window.text
                            horizontalAlignment: Text.AlignHCenter

                            opacity: window.calendarContentOpacity
                            transform: Translate { x: window.calendarContentOffset }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: window.targetMonthOffset !== 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: { if (window.targetMonthOffset !== 0) window.setMonthOffset(0) }
                            }
                        }

                        IconButton {
                            Layout.preferredWidth: window.s(26)
                            Layout.preferredHeight: window.s(26)
                            size: window.s(26)
                            cornerRadius: window.s(8)
                            buttonIcon: I18n.rtl ? "" : ""
                            iconFontSize: window.s(13)
                            accentColor: window.surface0
                            textColor: window.text
                            onClicked: window.setMonthOffset(window.targetMonthOffset + 1)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        layoutDirection: I18n.layoutDirection

                        Repeater {
                            model: [I18n.t("calendar.days.mo"), I18n.t("calendar.days.tu"), I18n.t("calendar.days.we"), I18n.t("calendar.days.th"), I18n.t("calendar.days.fr"), I18n.t("calendar.days.sa"), I18n.t("calendar.days.su")]
                            Text {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                text: modelData
                                font.family: ThemeBackend.fontFamily
                                font.weight: Font.Black
                                font.pixelSize: window.s(9.5)
                                color: window.overlay0
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 7
                        rowSpacing: window.s(1)
                        columnSpacing: window.s(2)
                        uniformCellWidths: true
                        uniformCellHeights: true
                        layoutDirection: I18n.layoutDirection

                        opacity: window.calendarContentOpacity
                        transform: Translate { x: window.calendarContentOffset }

                        Repeater {
                            model: calendarModel
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: window.s(6)
                                color: isToday ? window.textAccent : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: dayNum
                                    font.family: ThemeBackend.fontFamily
                                    font.weight: isToday ? Font.Black : Font.Bold
                                    font.pixelSize: window.s(10.5)
                                    color: isToday ? window.base : (isCurrentMonth ? window.text : window.surface2)
                                }
                            }
                        }
                    }
                }
            }

            // Clock + hourly forecast
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: window.cardColor
                radius: window.cardRadius

                opacity: introClock
                transform: Translate { y: window.s(16) * (1.0 - introClock) }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: window.s(12)
                    spacing: window.s(2)

                    Item { Layout.fillHeight: true }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.maximumWidth: parent.width
                        text: DateTime.time
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Black
                        font.pixelSize: window.s(56)
                        fontSizeMode: Text.HorizontalFit
                        minimumPixelSize: window.s(28)
                        color: window.text
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: DateTime.fullDate
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: window.s(12)
                        color: window.subtext0
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: window.s(6)
                        layoutDirection: I18n.layoutDirection
                        opacity: window.weatherContentOpacity
                        transform: Translate { x: window.weatherContentOffset }

                        Repeater {
                            model: window.hourlySlots

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: window.s(70)
                                radius: Math.min(window.s(12), ThemeBackend.borderRadius)
                                color: modelData.active ? window.textAccent : (hrMa.containsMouse ? Qt.lighter(window.surface0, 1.12) : window.surface0)
                                Behavior on color { ColorAnimation { duration: 180 } }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: window.s(2)

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.active ? I18n.t("calendar.now") : (modelData.time || "")
                                        font.family: ThemeBackend.fontFamily
                                        font.weight: Font.Bold
                                        font.pixelSize: window.s(9.5)
                                        color: modelData.active ? window.base : window.overlay1
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.icon || (window.currentForecast ? window.currentForecast.icon : "")
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: window.s(15)
                                        color: modelData.active ? window.base : (modelData.hex || window.text)
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.temp !== undefined ? modelData.temp + "°" : ""
                                        font.family: ThemeBackend.fontFamily
                                        font.weight: Font.Black
                                        font.pixelSize: window.s(11)
                                        color: modelData.active ? window.base : window.text
                                    }
                                }

                                MouseArea { id: hrMa; anchors.fill: parent; hoverEnabled: true }
                            }
                        }
                    }
                }
            }

            // Weather
            Rectangle {
                Layout.preferredWidth: window.s(240)
                Layout.fillHeight: true
                color: window.cardColor
                radius: window.cardRadius

                opacity: introWeather
                transform: Translate { x: window.s(24) * (1.0 - introWeather) }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: window.s(12)
                    spacing: window.s(4)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: window.s(4)
                        layoutDirection: I18n.layoutDirection

                        IconButton {
                            Layout.preferredWidth: window.s(26)
                            Layout.preferredHeight: window.s(26)
                            size: window.s(26)
                            cornerRadius: window.s(8)
                            buttonIcon: I18n.rtl ? "" : ""
                            iconFontSize: window.s(11)
                            accentColor: window.surface0
                            textColor: isHoveredOrHighlighted ? window.textAccent : window.overlay1
                            onClicked: window.setWeatherView(window.targetWeatherView - 1)
                        }

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: window.currentForecast ? window.currentForecast.day_full.toUpperCase() : I18n.t("calendar.loading")
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Black
                            font.pixelSize: window.s(12)
                            fontSizeMode: Text.Fit
                            minimumPixelSize: window.s(8)
                            color: window.text
                        }

                        IconButton {
                            Layout.preferredWidth: window.s(26)
                            Layout.preferredHeight: window.s(26)
                            size: window.s(26)
                            cornerRadius: window.s(8)
                            buttonIcon: I18n.rtl ? "" : ""
                            iconFontSize: window.s(11)
                            accentColor: window.surface0
                            textColor: isHoveredOrHighlighted ? window.textAccent : window.overlay1
                            onClicked: window.setWeatherView(window.targetWeatherView + 1)
                        }
                    }

                    Text {
                        Layout.topMargin: window.s(4)
                        text: (window.weatherData && window.weatherData.offline ? "--" : window.displayedTemp.toFixed(1)) + (Weather.unitSym || "°")
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Black
                        font.pixelSize: window.s(40)
                        color: window.tempGlowColor
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            let city = (typeof Location !== "undefined" && Location.city && Location.city !== "") ? Location.city : (window.weatherData && window.weatherData.city ? window.weatherData.city : "");
                            let desc = window.currentForecast ? (window.currentForecast.desc || "") : "";
                            return [city, desc].filter(function(x) { return x !== ""; }).join(" · ");
                        }
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: window.s(11)
                        color: window.textAccent
                        elide: Text.ElideRight
                        opacity: window.weatherContentOpacity
                    }

                    Item { Layout.fillHeight: true }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: window.s(6)
                        columnSpacing: window.s(6)
                        uniformCellWidths: true
                        layoutDirection: I18n.layoutDirection

                        Repeater {
                            model: 4

                            ClickButton {
                                Layout.fillWidth: true
                                Layout.preferredHeight: window.s(38)
                                cornerRadius: window.s(9)
                                horizontalPadding: window.s(8)
                                contentAlignment: Qt.AlignLeft

                                property var forecast: window.weatherData && window.weatherData.forecast[window.targetWeatherView] ? window.weatherData.forecast[window.targetWeatherView] : null

                                buttonIcon: index === 0 ? "" : index === 1 ? "" : index === 2 ? "" : ""
                                buttonText: window.weatherData && window.weatherData.offline ? "--" : forecast ? (
                                    index === 0 ? forecast.wind + (Weather.unit === "imperial" ? "mph" : "m/s") :
                                    index === 1 ? forecast.humidity + "%" :
                                    index === 2 ? forecast.pop + "%" :
                                    forecast.feels_like + "°"
                                ) : ""
                                subText: index === 0 ? I18n.t("calendar.weather.wind") : index === 1 ? I18n.t("calendar.weather.humid") : index === 2 ? I18n.t("calendar.weather.rain") : I18n.t("calendar.weather.feels")

                                iconFontSize: window.s(13)
                                textFontSize: window.s(10.5)

                                accentColor: window.surface0
                                textColor: isHoveredOrHighlighted ? window.textAccent : window.subtext0
                            }
                        }
                    }
                }
            }
        }
    }
}
