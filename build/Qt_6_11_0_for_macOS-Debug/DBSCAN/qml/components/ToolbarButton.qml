import QtQuick
import QtQuick.Controls.Basic

Button {
    id: control

    implicitWidth: 86
    implicitHeight: 34
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
        color: control.enabled ? (control.down ? "#2a2a2a" : control.hovered ? "#222222" : "#141414") : "#0d0d0d"
        border.color: control.enabled ? "#4a4a4a" : "#242424"
        border.width: 1
    }
}
