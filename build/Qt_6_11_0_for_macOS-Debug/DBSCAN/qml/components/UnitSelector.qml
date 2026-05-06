import QtQuick
import QtQuick.Controls.Basic

ComboBox {
    id: control

    implicitHeight: 36
    font.pixelSize: 13
    focusPolicy: Qt.NoFocus

    contentItem: Text {
        leftPadding: 10
        rightPadding: 24
        color: control.enabled ? "#ffffff" : "#777777"
        text: control.displayText
        font: control.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Text {
        x: control.width - width - 9
        y: control.topPadding + (control.availableHeight - height) / 2
        color: control.enabled ? "#ffffff" : "#777777"
        text: "v"
        font.pixelSize: 11
    }

    background: Rectangle {
        radius: 6
        color: control.enabled ? "#050505" : "#0d0d0d"
        border.color: control.activeFocus ? "#ffffff" : "#3a3a3a"
        border.width: 1
    }

    popup: Popup {
        y: control.height + 4
        width: control.width
        implicitHeight: contentItem.implicitHeight
        padding: 1

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
        }

        background: Rectangle {
            radius: 6
            color: "#080808"
            border.color: "#3a3a3a"
            border.width: 1
        }
    }

    delegate: ItemDelegate {
        width: control.width
        height: 34
        highlighted: control.highlightedIndex === index

        contentItem: Text {
            text: modelData
            color: "#ffffff"
            font: control.font
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            color: highlighted ? "#262626" : "#080808"
        }
    }
}
