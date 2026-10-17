import QtQuick
import QtQuick.Window
import Qt5Compat.GraphicalEffects
import SddmComponents 2.0

Rectangle {
    id: root
    width: Screen.width
    height: Screen.height
    color: "#0b0b0d"

    // Layout is designed at 1366x768 and scales with the screen height
    readonly property real s: Math.max(0.75, Screen.height / 768)

    // Ghost mirrors its wallpaper, colors and avatar here (scripts/sddm_sync.sh)
    readonly property string syncDir: (typeof config !== "undefined" && config.syncDir) ? config.syncDir : "/var/lib/ghost-sddm"

    Loader {
        id: ghostPalette
        source: "file://" + root.syncDir + "/Colors.qml"
    }
    readonly property var pal: ghostPalette.status === Loader.Ready ? ghostPalette.item : null

    readonly property color accent: pal ? pal.accent : ((typeof config !== "undefined" && config.accent) ? config.accent : "#a8c7fa")
    readonly property color onAccent: pal ? pal.crust : "#0b0b0d"
    readonly property color surfaceHi: pal ? Qt.alpha(pal.surface, 0.9) : "#1b1b1f"
    readonly property color textColor: pal ? pal.text : "#ececf0"
    readonly property color subtext: pal ? pal.subtext : "#9b9ba5"
    readonly property color warn: pal ? pal.warn : "#e8c27a"
    readonly property color danger: pal ? pal.danger : "#f2a7a7"
    readonly property color cardColor: pal ? Qt.alpha(pal.base, 0.72) : Qt.rgba(0.07, 0.07, 0.08, 0.72)

    readonly property string greeting: {
        let h = clock.now.getHours();
        if (h >= 5 && h < 12) return "Bom dia";
        if (h >= 12 && h < 18) return "Boa tarde";
        return "Boa noite";
    }
    readonly property string hostName: (typeof sddm !== "undefined" && sddm.hostName) ? sddm.hostName : ""
    readonly property string kbLayout: {
        if (typeof keyboard === "undefined" || !keyboard.layouts || keyboard.layouts.length === 0) return "";
        let l = keyboard.layouts[keyboard.currentLayout];
        return l && l.shortName ? l.shortName.toUpperCase() : "";
    }

    QtObject {
        id: clock
        property date now: new Date()
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clock.now = new Date()
    }

    property bool isQuickshell: typeof sddm === "undefined" || sddm.hostName === undefined
    property int sessionIndex: (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0) ? sessionModel.lastIndex : 0
    property int userIndex: (typeof userModel !== "undefined" && userModel.lastIndex >= 0) ? userModel.lastIndex : 0
    property string errorMessage: ""
    property real intro: 0

    FontLoader {
        id: customFont
        source: "font/GoogleSans-VariableFont_GRAD,opsz,wght.ttf"
    }

    readonly property string sansFont: customFont.name !== "" ? customFont.name : "sans-serif"

    function svgIcon(path, stroke) {
        return "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='"
            + String(stroke).replace("#", "%23")
            + "' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'>" + path + "</svg>";
    }

    readonly property string icPower: "<path d='M12 3v9'/><path d='M6.3 6.3a8 8 0 1 0 11.4 0'/>"
    readonly property string icReboot: "<path d='M3 12a9 9 0 1 0 3-6.7L3 8'/><path d='M3 3v5h5'/>"
    readonly property string icSleep: "<path d='M4 6h6l-6 8h6M14 4h6l-6 8h6'/>"
    readonly property string icArrow: "<path d='M5 12h14M13 6l6 6-6 6'/>"
    readonly property string icMonitor: "<rect x='3' y='4' width='18' height='14' rx='2'/><path d='M8 21h8'/>"
    readonly property string icKeyboard: "<rect x='2' y='6' width='20' height='12' rx='2'/><path d='M6 10h.01M10 10h.01M14 10h.01M18 10h.01M7 14h10'/>"

    function login() {
        if (root.isQuickshell || pwd.text.length === 0) return;
        let currentUser = userHelper.currentItem ? userHelper.currentItem.uLogin : userModel.lastUser;
        sddm.login(currentUser, pwd.text, root.sessionIndex);
    }

    // Hidden views that expose the current user/session from SDDM's models
    ListView {
        id: sessionHelper
        model: typeof sessionModel !== "undefined" ? sessionModel : null
        currentIndex: root.sessionIndex
        visible: false
        width: 1; height: 1
        delegate: Item { property string sName: model.name || "" }
    }

    ListView {
        id: userHelper
        model: typeof userModel !== "undefined" ? userModel : null
        currentIndex: root.userIndex
        visible: false
        width: 1; height: 1
        delegate: Item {
            property string uName: model.realName || model.name || ""
            property string uLogin: model.name || ""
            property string uIcon: model.icon || ""
        }
    }

    readonly property string userName: (userHelper.currentItem && userHelper.currentItem.uName) ? userHelper.currentItem.uName : ((typeof userModel !== "undefined" && userModel.lastUser) ? userModel.lastUser : "user")
    readonly property string userIcon: userHelper.currentItem ? userHelper.currentItem.uIcon : ""
    readonly property string sessionName: sessionHelper.currentItem ? sessionHelper.currentItem.sName : ""
    readonly property int userCount: (typeof userModel !== "undefined") ? userModel.rowCount() : 0

    Connections {
        target: typeof sddm !== "undefined" ? sddm : null
        function onLoginFailed() {
            root.errorMessage = "Senha incorreta";
            pwd.text = "";
            shakeAnim.start();
            errTimer.restart();
        }
    }

    Timer {
        id: errTimer
        interval: 3000
        onTriggered: root.errorMessage = ""
    }

    Timer {
        id: focusTimer
        interval: 300
        running: true
        onTriggered: pwd.forceActiveFocus()
    }

    Component.onCompleted: {
        introAnim.start();
        if (typeof keyboard !== "undefined") keyboard.numLock = true;
    }

    NumberAnimation {
        id: introAnim
        target: root; property: "intro"; from: 0; to: 1
        duration: 700; easing.type: Easing.OutCubic
    }

    // Wallpaper, blurred and dimmed
    Image {
        id: bg
        anchors.fill: parent
        source: "file://" + root.syncDir + "/wallpaper.png"
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: root.width
        asynchronous: true
        visible: false
        onStatusChanged: if (status === Image.Error && source != "bg.png") source = "bg.png"
    }

    FastBlur {
        id: bgBlur
        anchors.fill: parent
        source: bg
        radius: 40
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.02, 0.02, 0.03, 0.42)
    }

    // Clock
    Column {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 96 * s
        anchors.bottomMargin: 150 * s
        spacing: 6 * s
        opacity: root.intro
        transform: Translate { y: 20 * s * (1 - root.intro) }

        Text {
            id: clockText
            font.family: root.sansFont
            font.weight: Font.Medium
            font.pixelSize: 128 * s
            font.letterSpacing: -4 * s
            color: "#f2f2f5"
            text: Qt.formatTime(clock.now, "HH:mm")
            Behavior on text {
                SequentialAnimation {
                    NumberAnimation { target: clockText; property: "opacity"; to: 0.35; duration: 160 }
                    PropertyAction {}
                    NumberAnimation { target: clockText; property: "opacity"; to: 1; duration: 260 }
                }
            }
        }

        Text {
            leftPadding: 6 * s
            font.family: root.sansFont
            font.pixelSize: 18 * s
            color: "#d6d6dc"
            text: clock.now.toLocaleDateString(Qt.locale(), "dddd, d 'de' MMMM")
        }
    }

    // Login card
    Rectangle {
        id: card
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: 120 * s
        width: 340 * s
        height: cardCol.implicitHeight + 60 * s
        radius: 28 * s
        color: "transparent"
        clip: true
        opacity: root.intro
        transform: [
            Translate { id: shakeTranslate },
            Translate { x: 30 * s * (1 - root.intro) }
        ]

        // Frosted glass: the blurred wallpaper behind the card, tinted
        ShaderEffectSource {
            anchors.fill: parent
            sourceItem: bgBlur
            sourceRect: Qt.rect(card.x, card.y, card.width, card.height)
            visible: false
            id: cardBackdrop
        }

        Rectangle {
            id: cardMask
            anchors.fill: parent
            radius: parent.radius
            visible: false
        }

        OpacityMask {
            anchors.fill: parent
            source: cardBackdrop
            maskSource: cardMask
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: root.cardColor
            border.color: Qt.rgba(1, 1, 1, 0.10)
            border.width: 1
        }

        Column {
            id: cardCol
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 32 * s
            width: parent.width - 56 * s
            spacing: 14 * s

            // Avatar: user icon when SDDM has one, else the initial
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 88 * s
                height: 88 * s

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: root.accent

                    Text {
                        anchors.centerIn: parent
                        text: root.userName.charAt(0).toUpperCase()
                        font.family: root.sansFont
                        font.weight: Font.Bold
                        font.pixelSize: 34 * s
                        color: root.onAccent
                        visible: avatarImg.status !== Image.Ready
                    }
                }

                Image {
                    id: avatarImg
                    anchors.fill: parent
                    source: "file://" + root.syncDir + "/avatar.png"
                    onStatusChanged: if (status === Image.Error && root.userIcon !== "" && source != root.userIcon) source = root.userIcon
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                }

                Rectangle {
                    id: avatarMask
                    anchors.fill: parent
                    radius: width / 2
                    visible: false
                }

                OpacityMask {
                    anchors.fill: parent
                    source: avatarImg
                    maskSource: avatarMask
                    visible: avatarImg.status === Image.Ready
                }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2 * s

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.greeting + ", " + root.userName
                    font.family: root.sansFont
                    font.weight: Font.Bold
                    font.pixelSize: 19 * s
                    color: root.textColor
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.hostName !== ""
                    text: root.hostName
                    font.family: root.sansFont
                    font.pixelSize: 11 * s
                    color: root.subtext
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.userCount > 1
                    text: "trocar usuário"
                    font.family: root.sansFont
                    font.pixelSize: 11 * s
                    color: userSwitchMouse.containsMouse ? root.textColor : root.subtext

                    MouseArea {
                        id: userSwitchMouse
                        anchors.fill: parent
                        anchors.margins: -4 * s
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.userCount > 0) root.userIndex = (root.userIndex + 1) % root.userCount;
                            pwd.forceActiveFocus();
                        }
                    }
                }
            }

            // Password field
            Rectangle {
                width: parent.width
                height: 48 * s
                radius: 16 * s
                color: root.surfaceHi
                border.width: 1.5 * s
                border.color: root.errorMessage !== "" ? root.danger : (pwd.activeFocus ? root.accent : Qt.rgba(1, 1, 1, 0.1))

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 16 * s
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pwd.text.length === 0
                    text: "Senha"
                    font.family: root.sansFont
                    font.pixelSize: 15 * s
                    color: root.subtext
                }

                TextInput {
                    id: pwd
                    anchors.left: parent.left
                    anchors.right: submitBtn.left
                    anchors.leftMargin: 16 * s
                    anchors.rightMargin: 8 * s
                    anchors.verticalCenter: parent.verticalCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    font.family: root.sansFont
                    font.pixelSize: 16 * s
                    font.letterSpacing: 2 * s
                    color: root.textColor
                    selectionColor: root.accent
                    clip: true
                    focus: true
                    inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    Keys.onReturnPressed: root.login()
                    Keys.onEnterPressed: root.login()
                }

                Rectangle {
                    id: submitBtn
                    anchors.right: parent.right
                    anchors.rightMargin: 6 * s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36 * s
                    height: 36 * s
                    radius: 11 * s
                    color: submitMouse.pressed ? Qt.darker(root.accent, 1.15) : root.accent
                    opacity: pwd.text.length > 0 ? 1.0 : 0.5

                    Image {
                        anchors.centerIn: parent
                        width: 18 * s
                        height: 18 * s
                        sourceSize: Qt.size(36 * s, 36 * s)
                        source: root.svgIcon(root.icArrow, root.onAccent)
                    }

                    MouseArea {
                        id: submitMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.login()
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                height: 14 * s
                text: root.errorMessage !== "" ? root.errorMessage
                    : ((typeof keyboard !== "undefined" && keyboard.capsLock) ? "Caps Lock ativado" : "")
                font.family: root.sansFont
                font.pixelSize: 11 * s
                color: root.errorMessage !== "" ? root.danger : root.warn
            }
        }
    }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: shakeTranslate; property: "x"; to: 12 * s; duration: 50 }
        NumberAnimation { target: shakeTranslate; property: "x"; to: -12 * s; duration: 50 }
        NumberAnimation { target: shakeTranslate; property: "x"; to: 8 * s; duration: 50 }
        NumberAnimation { target: shakeTranslate; property: "x"; to: -8 * s; duration: 50 }
        NumberAnimation { target: shakeTranslate; property: "x"; to: 0; duration: 50 }
    }

    component FooterButton : Rectangle {
        id: fb
        property string icon: ""
        property string label: ""
        signal clicked()

        height: 40 * s
        width: label !== "" ? fbRow.implicitWidth + 28 * s : 40 * s
        radius: 12 * s
        color: fbMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)

        Row {
            id: fbRow
            anchors.centerIn: parent
            spacing: 8 * s

            Image {
                anchors.verticalCenter: parent.verticalCenter
                visible: fb.icon !== ""
                width: 18 * s
                height: 18 * s
                sourceSize: Qt.size(36 * s, 36 * s)
                source: fb.icon
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: fb.label !== ""
                text: fb.label
                font.family: root.sansFont
                font.pixelSize: 13 * s
                color: "#d6d6dc"
            }
        }

        MouseArea {
            id: fbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: fb.clicked()
        }
    }

    // Footer: session on the left, power actions on the right
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 96 * s
        anchors.rightMargin: 120 * s
        anchors.bottomMargin: 36 * s
        height: 40 * s
        opacity: root.intro

        FooterButton {
            id: sessionBtn
            anchors.left: parent.left
            icon: root.svgIcon(root.icMonitor, "#d6d6dc")
            label: (root.sessionName !== "" ? root.sessionName : "Sessão") + "  ▾"
            onClicked: {
                if (typeof sessionModel !== "undefined" && sessionModel.rowCount() > 0)
                    root.sessionIndex = (root.sessionIndex + 1) % sessionModel.rowCount();
                pwd.forceActiveFocus();
            }
        }

        FooterButton {
            anchors.left: sessionBtn.right
            anchors.leftMargin: 8 * s
            visible: root.kbLayout !== ""
            icon: root.svgIcon(root.icKeyboard, "#d6d6dc")
            label: root.kbLayout
            onClicked: {
                if (typeof keyboard !== "undefined" && keyboard.layouts.length > 0)
                    keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length;
                pwd.forceActiveFocus();
            }
        }

        Row {
            anchors.right: parent.right
            spacing: 8 * s

            FooterButton {
                icon: root.svgIcon(root.icSleep, "#d6d6dc")
                visible: root.isQuickshell || sddm.canSuspend
                onClicked: if (!root.isQuickshell) sddm.suspend()
            }

            FooterButton {
                icon: root.svgIcon(root.icReboot, "#d6d6dc")
                onClicked: if (!root.isQuickshell) sddm.reboot()
            }

            FooterButton {
                icon: root.svgIcon(root.icPower, "#f2a7a7")
                onClicked: if (!root.isQuickshell) sddm.powerOff()
            }
        }
    }
}
