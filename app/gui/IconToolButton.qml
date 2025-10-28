// IconToolButton.qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

NavigableToolButton {
    id: root

    // Tunables (override per instance)
    property int toolSize: 36
    property int toolPad: 6
    property int iconSize: 18
    property real cornerRadius: 3
    // Use this instead of icon.source for convenience:
    property alias source: icon.source

    // Sizing & layout (prevents vertical stretch in RowLayout)
    implicitWidth: toolSize
    implicitHeight: toolSize
    padding: toolPad
    Layout.preferredWidth: toolSize
    Layout.preferredHeight: toolSize
    Layout.fillHeight: false
    Layout.alignment: Qt.AlignVCenter

    hoverEnabled: true
    focusPolicy: Qt.TabFocus

    // Background styling
    background: Rectangle {
        radius: cornerRadius
        color: root.down ? "#2D6CDF"
             : root.checked ? "#b02428"
             : root.hovered ? "#821b1f"
             : Material.accentColor
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? "#a02226"
                    : root.hovered ? "#821b1f"
                    : "#a02226"
    }

    // Icon centered and respecting padding
    contentItem: Item {
        anchors {
            fill: parent
            leftMargin: root.leftPadding
            rightMargin: root.rightPadding
            topMargin: root.topPadding
            bottomMargin: root.bottomPadding
        }
        Image {
            id: icon
            anchors.centerIn: parent
            width: root.iconSize
            height: root.iconSize
            fillMode: Image.PreserveAspectFit
        }
    }
}
