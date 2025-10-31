import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

Dialog {
    id: warningPopup
    modal: true
    standardButtons: Dialog.Ok
    title: qsTr("Display Configuration Warning")

    property int requiredCount: 0
    property int availableCount: 0

    function openWithCounts(required, available) {
        requiredCount = required
        availableCount = available
        open()
    }

    contentItem: ColumnLayout {
        spacing: 12
        width: 420

        RowLayout {
            spacing: 10
            Image {
                source: (Material.theme !== Material.Dark)
                        ? "qrc:/res/baseline-warning-24px-dark.svg"
                        : "qrc:/res/baseline-warning-24px.svg"
                sourceSize.width: 24
                sourceSize.height: 24
                Layout.alignment: Qt.AlignTop
            }
            Label {
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                text: qsTr("Not enough monitors available for the requested number of displays.")
                      + "\n\n"
                      + qsTr("Required: %1 • Available: %2")
                        .arg(requiredCount).arg(availableCount)
            }
        }
    }
}
