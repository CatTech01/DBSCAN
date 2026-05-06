import QtQuick
import QtQuick.Controls.Basic

Button {
    id: control

    implicitHeight: 40
    font.pixelSize: 14
    focusPolicy: Qt.NoFocus

    contentItem: Text {
        color: control.enabled ? "#ffffff" : "#777777"
        text: control.text
        font: control.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        radius: 6
        color: control.enabled ? (control.down ? "#2a2a2a" : control.hovered ? "#202020" : "#111111") : "#0d0d0d"
        border.color: control.enabled ? "#454545" : "#252525"
        border.width: 1
    }
}
