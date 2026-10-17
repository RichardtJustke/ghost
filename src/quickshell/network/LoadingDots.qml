import QtQuick
import "../"

Row {
    spacing: Scaler.p(4)
    property color dotCol: ThemeBackend.text
    Repeater {
        model: 3
        Rectangle {
            width: Scaler.p(5); height: Scaler.p(5); radius: Scaler.p(2.5); color: dotCol
            SequentialAnimation on y {
                loops: Animation.Infinite
                running: window.visible && parent.visible
                PauseAnimation { duration: index * 100 }
                NumberAnimation { from: 0; to: Scaler.p(-5); duration: 250; easing.type: Easing.OutSine }
                NumberAnimation { from: Scaler.p(-5); to: 0; duration: 250; easing.type: Easing.InSine }
                PauseAnimation { duration: (2 - index) * 100 }
            }
        }
    }
}
