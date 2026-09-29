import QtQuick
import QtQuick.Effects

// Fakes a frosted-glass / vibrancy background by sampling the region of the
// current wallpaper that sits behind this pane (via originX/originY relative
// to the screen), blurring it and laying a tinted, semi-transparent color on
// top. There is no real "blur what's behind the window" support across the
// compositors this shell targets, so this approximates it using the cached
// wallpaper snapshot instead.
Item {
    id: root

    property string wallpaperSource: ""
    property real originX: 0
    property real originY: 0
    property real screenWidth: 1920
    property real screenHeight: 1080
    property real blurAmount: 0.5
    property real frostOpacity: 0.55
    property color tintColor: "#1e1e2e"
    property real cornerRadius: 0

    visible: root.wallpaperSource !== "" && root.width > 0 && root.height > 0

    Rectangle {
        id: maskShape
        anchors.fill: parent
        radius: root.cornerRadius
        color: "black"
        visible: false
        layer.enabled: true
    }

    Item {
        id: content
        anchors.fill: parent
        visible: false
        layer.enabled: true

        Item {
            id: cropWindow
            anchors.fill: parent
            clip: true

            Image {
                id: wallImg
                source: root.wallpaperSource
                asynchronous: true
                smooth: true
                mipmap: true
                cache: false
                fillMode: Image.PreserveAspectCrop
                width: Math.max(1, root.screenWidth)
                height: Math.max(1, root.screenHeight)
                x: -root.originX
                y: -root.originY
                sourceSize.width: Math.max(1, Math.round(root.screenWidth / 2))
                sourceSize.height: Math.max(1, Math.round(root.screenHeight / 2))
            }
        }

        MultiEffect {
            anchors.fill: parent
            source: cropWindow
            autoPaddingEnabled: false
            blurEnabled: root.blurAmount > 0.001
            blurMax: 96
            blur: root.blurAmount
        }

        Rectangle {
            anchors.fill: parent
            color: root.tintColor
            opacity: root.frostOpacity
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: content
        maskEnabled: true
        maskSource: maskShape
    }
}
