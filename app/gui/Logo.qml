import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material

Item {
    id: root
    // Text parts
    property string prefix: "45"
    property string suffix: "Drives"

    // Sizing (≈ 1.6rem if base is 16px)
    property int pixelSize: 26

    // Theming
    // If you use Material everywhere, this auto-picks up dark mode.
    // Otherwise, override `dark` manually.
    property bool dark: (Material.theme === Material.Dark)

    // Font (bundle Source Sans Pro or let it fall back)
    property string fontFamily: "Source Sans Pro, Sans-Serif"

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Accessible.role: Accessible.Heading
    Accessible.name: prefix + suffix

    Row {
        id: row
        spacing: 0
        anchors.fill: parent

        Image {
            source:  root.dark ? "qrc:/res/45d-fan-dark.svg" : "qrc:/res/45d-fan-light.svg"
            height: 24
            width: 24

            // Render the SVG at device-pixel–scaled size for sharpness
            sourceSize.width:  Math.round(width  * Screen.devicePixelRatio)
            sourceSize.height: Math.round(height * Screen.devicePixelRatio)
        }

        Text {
            id: t45
            text: root.prefix
            font.pixelSize: root.pixelSize
            font.bold: true
            font.family: root.fontFamily
            color: root.dark ? "#ffffff" : "#991b1b"   // dark:white, light:red-800
        }

        Text {
            id: tDrives
            text: root.suffix
            font.pixelSize: root.pixelSize
            font.family: root.fontFamily
            color: root.dark ? "#dc2626" : "#1f2937"   // dark:red-600, light:gray-800
        }
    }
}
