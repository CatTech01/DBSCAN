import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

ColumnLayout {
    id: fieldRoot

    property alias label: fieldLabel.text
    property alias text: fieldInput.text
    property bool enabled: true

    spacing: 6

    Label {
        id: fieldLabel

        color: fieldRoot.enabled ? "#d5d5d5" : "#747474"
        font.pixelSize: 13
    }

    TextField {
        id: fieldInput

        Layout.fillWidth: true
        implicitHeight: 36
        enabled: fieldRoot.enabled
        color: "#ffffff"
        selectedTextColor: "#000000"
        selectionColor: "#ffffff"
        font.pixelSize: 14
        inputMethodHints: Qt.ImhFormattedNumbersOnly

        background: Rectangle {
            radius: 6
            color: fieldInput.enabled ? "#050505" : "#0d0d0d"
            border.color: fieldInput.activeFocus ? "#ffffff" : "#3a3a3a"
            border.width: 1
        }
    }
}
