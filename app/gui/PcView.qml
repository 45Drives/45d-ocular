import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Controls.Material

import App.Utils 1.0
import ComputerModel 1.0
import ComputerManager 1.0
import StreamingPreferences 1.0
import SystemProperties 1.0
import SdlGamepadKeyNavigation 1.0

Item {
    id: pcView
    focus: true
    activeFocusOnTab: true
    objectName: qsTr("Computers")

    // Track expanded state per group key (IP by default; falls back to name if IP is empty)
    property var expandedByGroup: ({})
    function isExpanded(groupKey) { return expandedByGroup[groupKey] === true }
    function toggleExpanded(groupKey) {
        const next = Object.assign({}, expandedByGroup)
        next[groupKey] = !(expandedByGroup[groupKey] === true)
        expandedByGroup = next
    }

    Control {
        id: themeHost
        visible: false
        Material.theme: SystemProperties.isDarkTheme ? Material.Dark : Material.Light
    }

    QtObject {
        id: theme
        readonly property bool dark: (Material.theme === Material.Dark)
        readonly property color online: dark ? "#81C784" : "#2e7d32"
        readonly property color offline: dark ? "#EF9A9A" : "#b71c1c"
    }

    QtObject {
        id: layoutVars
        property int spacing: 12
        property int headerMargin: 8
        property int rowMargin: 8
    }

    QtObject {
        id: cols
        property int nameW: 300
        property int statusW: 120
        property int pairedW: 90
        property int onlineW: 90
        property int actionsW: 220
        property int spacing: 12
    }

    property ComputerModel computerModel: createModel()
    property string filterText: ""

    function createModel() {
        var model = Qt.createQmlObject(
                    'import ComputerModel 1.0; ComputerModel {}', pcView, '')
        model.initialize(ComputerManager)
        model.pairingCompleted.connect(pairingComplete)
        model.connectionTestCompleted.connect(
                    testConnectionDialog.connectionTestComplete)
        return model
    }

    function parentStackView() {
        var p = pcView
        while (p) {
            if (p.push && p.pop && p.hasOwnProperty("currentItem")
                    && p.visible !== false) {
                return p
            }
            p = p.parent
        }
        return null
    }

    function pairingComplete(error) {
        pairDialog.close()
        if (error !== undefined) {
            errorDialog.text = error
            errorDialog.helpText = ""
            errorDialog.open()
        }
    }

    function addComplete(success, detectedPortBlocking) {
        if (!success) {
            errorDialog.text = qsTr("Unable to connect to the specified PC.")
            if (detectedPortBlocking) {
                errorDialog.text += "\n\n" + qsTr(
                            "This PC's Internet connection is blocking Ocular. Streaming over the Internet may not work while connected to this network.")
            } else {
                errorDialog.helpText = qsTr(
                            "Click the Help button for possible solutions.")
            }
            errorDialog.open()
        }
    }

    StackView.onActivated: {
        ComputerManager.computerAddCompleted.connect(addComplete)
        if (SdlGamepadKeyNavigation.getConnectedGamepads() > 0
                && computerModel.count > 0) {
            list.currentIndex = 0
        }
    }
    StackView.onDeactivating: ComputerManager.computerAddCompleted.disconnect(
                                  addComplete)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: qsTr("Search computers…")
                selectByMouse: true
                focus: true
                onTextChanged: filterText = text
                Keys.onEscapePressed: {
                    clear()
                    filterText = ""
                }
            }

            BusyIndicator {
                visible: StreamingPreferences.enableMdns
                running: visible
                implicitWidth: 20
                implicitHeight: 20
                Layout.alignment: Qt.AlignVCenter
            }
            Label {
                visible: StreamingPreferences.enableMdns
                text: qsTr("Searching local network…")
                elide: Label.ElideRight
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 36
            color: (Material.theme === Material.Dark) ? Qt.rgba(1, 1, 1, 0.06)
                                                      : Qt.rgba(0, 0, 0, 0.04)
            border.color: (Material.theme === Material.Dark) ? Qt.rgba(1, 1, 1, 0.12)
                                                             : Qt.rgba(0, 0, 0, 0.12)
            layer.enabled: true

            RowLayout {
                id: headerRow
                anchors.fill: parent
                anchors.margins: layoutVars.headerMargin
                spacing: layoutVars.spacing

                Label {
                    text: qsTr("Name")
                    font.bold: true
                    Layout.preferredWidth: cols.nameW
                    Layout.minimumWidth: cols.nameW
                    Layout.maximumWidth: cols.nameW
                }
                Label {
                    text: qsTr("Status")
                    font.bold: true
                    Layout.preferredWidth: cols.statusW
                    Layout.minimumWidth: cols.statusW
                    Layout.maximumWidth: cols.statusW
                }
                Label {
                    text: qsTr("Paired")
                    font.bold: true
                    Layout.fillWidth: true
                }

                Label {
                    text: qsTr("Actions")
                    font.bold: true
                    Layout.preferredWidth: cols.actionsW
                    Layout.minimumWidth: cols.actionsW
                    Layout.maximumWidth: cols.actionsW
                }

                Item {
                    Layout.preferredWidth: vbar.visible ? vbar.width : 0
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: computerModel
            focus: true
            currentIndex: -1
            keyNavigationWraps: true
            rightMargin: vbar.visible ? vbar.width : 0

            ScrollBar.vertical: ScrollBar { id: vbar }

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                visible: list.count === 0
                Label {
                    anchors.centerIn: parent
                    text: StreamingPreferences.enableMdns ? qsTr("Searching for compatible hosts on your local network…") : qsTr("Automatic PC discovery is disabled. Add your PC manually.")
                    wrapMode: Text.Wrap
                }
            }

            Keys.onDeletePressed: {
                if (currentIndex >= 0) {
                    deletePcDialog.pcIndex = currentIndex
                    deletePcDialog.pcName = computerModel.data(
                                computerModel.index(currentIndex, 0), "name")
                    deletePcDialog.open()
                }
            }

            delegate: Rectangle {
                id: rowRect
                width: list.width
                color: (index % 2 === 0)
                         ? ((Material.theme === Material.Dark)
                              ? Qt.rgba(1, 1, 1, 0.04)
                              : Qt.rgba(0, 0, 0, 0.02))
                         : "transparent"
                border.color: (Material.theme === Material.Dark)
                                ? Qt.rgba(1, 1, 1, 0.08)
                                : Qt.rgba(0, 0, 0, 0.06)
                layer.enabled: true

                property int rowIndex: index

                // Grouping key: prefer IP; if empty, fall back to name
                property string groupKey: (model.ip && model.ip.length > 0) ? model.ip : (model.name || "")
                property bool primary: isPrimary
                property bool expanded: pcView.isExpanded(groupKey)

                readonly property bool matches: {
                    if (!filterText || filterText.length === 0)
                        return true
                    var n = (model.name || "").toString()
                    return n.toLowerCase().indexOf(filterText.toLowerCase()) !== -1
                }

                // Show primary rows always; show secondaries only when expanded
                height: matches && (primary || expanded) ? 55 : 0
                visible: matches && (primary || expanded)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: layoutVars.rowMargin
                    spacing: layoutVars.spacing


                    // Column: Name (+expand +icon +inline status)
                    RowLayout {
                        Layout.preferredWidth: cols.nameW
                        Layout.minimumWidth: cols.nameW
                        Layout.maximumWidth: cols.nameW
                        spacing: 8

                        // Expand/collapse chevron on primary with multiple displays
                        ToolButton {
                            visible: primary && (displayCount > 1)
                            text: expanded ? "▾" : "▸"
                            onClicked: pcView.toggleExpanded(groupKey)
                            Accessible.name: expanded ? qsTr("Collapse group") : qsTr("Expand group")
                            leftPadding: 1
                            width: 20; height: 20
                        }

                        // Indent secondary rows with a spacer (RowLayout has no leftPadding)
                        Item {
                            visible: !primary;
                            width: (primary ? 0 : 20);
                            height: 20
                        }


                        Image {
                            source: (Material.theme !== Material.Dark)
                                      ? "qrc:/res/desktop_windows-48px-dark.svg"
                                      : "qrc:/res/desktop_windows-48px.svg"
                            sourceSize.width: 20
                            sourceSize.height: 20
                        }
                        Image {
                            visible: !model.statusUnknown && (!model.online || !model.paired)
                            source: !model.online
                                      ? ((Material.theme !== Material.Dark)
                                           ? "qrc:/res/warning_FILL1_wght300_GRAD200_opsz24-dark.svg"
                                           : "qrc:/res/warning_FILL1_wght300_GRAD200_opsz24.svg")
                                      : ((Material.theme !== Material.Dark)
                                           ? "qrc:/res/baseline-lock-24px-dark.svg"
                                           : "qrc:/res/baseline-lock-24px.svg")
                            sourceSize.width: 16
                            sourceSize.height: 16
                        }
                        BusyIndicator {
                            visible: model.statusUnknown
                            running: visible
                            implicitWidth: 16
                            implicitHeight: 16
                        }
                        Label {
                            text: model.name
                            elide: Label.ElideRight
                            opacity: primary ? 1.0 : 0.95
                            Layout.fillWidth: true
                        }
                    }

                    // STATUS
                    Label {
                        Layout.preferredWidth: cols.statusW
                        Layout.minimumWidth: cols.statusW
                        Layout.maximumWidth: cols.statusW
                        text: model.statusUnknown ? qsTr("Checking…")
                                                  : (model.online ? qsTr("Online") : qsTr("Offline"))
                        color: model.online
                                 ? ((Material.theme !== Material.Dark) ? "#81C784" : "#2e7d32")
                                 : ((Material.theme !== Material.Dark) ? "#EF9A9A" : "#b71c1c")
                        verticalAlignment: Text.AlignVCenter
                    }

                    // PAIRED
                    Label {
                        Layout.fillWidth: true
                        text: model.paired ? qsTr("Yes") : qsTr("(No) Required before Launching")
                        verticalAlignment: Text.AlignVCenter
                    }

                    // Column: Actions
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Button {
                            visible: primary
                            text: qsTr("Launch All Displays (%1)").arg(launchableDisplayCountRole)
                            enabled: model.online && model.paired && !model.statusUnknown
                            onClicked: {
                                const required = launchableDisplayCountRole
                                const available = UIValidator.availableDisplayCount()
                                if (!UIValidator.verifyDisplayCount(required)) {
                                    displayWarningPopup.openWithCounts(required, available)
                                    return
                                }
                                const launched = computerModel.launchAllDisplaysViaCli(index)
                                if (launched <= 0) {
                                    console.log("No displays launched for row", index)
                                }
                            }
                        }


                        Button {
                            visible: !primary
                            text: qsTr("Launch")
                            enabled: model.online && model.paired && !model.statusUnknown
                            onClicked: {
                                computerModel.launchDisplayViaCli(rowIndex, model.index)
                            }
                        }

                        Button {
                            text: qsTr("Wake")
                            enabled: !model.online && model.wakeable
                            onClicked: computerModel.wakeComputer(index)
                        }

                        Button {
                            id: moreBtn
                            text: qsTr("More")
                            onClicked: rowMenu.popup(moreBtn, Qt.point(0, moreBtn.height))
                        }
                        Menu {
                            id: rowMenu
                            property int rowIndex: index

                            Menu {
                                title: qsTr("Launch (Select Display)")
                                enabled: online && paired && !statusUnknown

                                Repeater {
                                    model: displayNames ?? []
                                    delegate: MenuItem {
                                        text: modelData
                                        onTriggered: {
                                            const ok = computerModel.launchDisplayViaCli(rowIndex, model.index)
                                            if (!ok) {
                                                console.log("Launch display failed at row", index, "display", model.index)
                                            }
                                        }
                                    }
                                }
                            }
                            MenuSeparator {}

                            MenuItem {
                                text: qsTr("Pair…")
                                enabled: online && !paired && !statusUnknown
                                onTriggered: {
                                    if (!serverSupported) {
                                        errorDialog.text = qsTr(
                                                    "The version of GeForce Experience on %1 is not supported by this build of Ocular. You must update Ocular to stream from %1.").arg(name)
                                        errorDialog.helpText = ""
                                        errorDialog.open()
                                    } else if (paired) {
                                        const component = Qt.createComponent("AppView.qml")
                                        if (component.status === Component.Ready) {
                                            const appView = component.createObject(parentStackView(), {
                                                "computerIndex": rowIndex,
                                                "objectName": name
                                            })
                                            parentStackView().push(appView)
                                        } else if (component.status === Component.Error) {
                                            console.log("Failed to load AppView.qml:", component.errorString())
                                        }
                                    } else {
                                        var pin = computerModel.generatePinString()
                                        computerModel.pairComputer(rowIndex, pin)
                                        pairDialog.pin = pin
                                        pairDialog.webUIURL = computerModel.webUIURL(rowIndex)
                                        pairDialog.open()
                                    }
                                }
                            }

                            MenuItem {
                                text: qsTr("Rename…")
                                onTriggered: {
                                    renamePcDialog.pcIndex = rowIndex
                                    renamePcDialog.originalName = name
                                    renamePcDialog.open()
                                }
                            }
                            MenuItem {
                                text: qsTr("Delete…")
                                onTriggered: {
                                    deletePcDialog.pcIndex = rowIndex
                                    deletePcDialog.pcName = name
                                    deletePcDialog.open()
                                }
                            }
                            MenuItem {
                                text: qsTr("View Details")
                                onTriggered: {
                                    showPcDetailsDialog.pcDetails = model.details
                                    showPcDetailsDialog.open()
                                }
                            }
                            MenuItem {
                                text: qsTr("Test")
                                onTriggered: {
                                    computerModel.testConnectionForComputer(rowIndex)
                                    testConnectionDialog.open()
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: rowMenu.popup(rowRect, Qt.point(mouse.x, mouse.y))
                }
            }
        }
    }

    StackView {
        id: stackView
        visible: false
    }

    ErrorMessageDialog {
        id: errorDialog
        helpUrl: "https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide"
    }

    NavigableMessageDialog {
        id: pairDialog
        modal: true
        closePolicy: Popup.CloseOnEscape

        property string webUIURL: ""
        property string pin: "0000"

        contentItem: Label {
            wrapMode: Text.WordWrap
            textFormat: Text.RichText
            text: {
                var lines = [];
                lines.push(qsTr("Please enter %1 on your host PC. This dialog will close when pairing is completed.").arg(pairDialog.pin));
                if (pairDialog.webUIURL.length > 0) {
                    lines.push(qsTr('If your host PC is running Sunshine, open the web UI at <a href="%1/pin">%1/pin</a> and enter the PIN.').arg(pairDialog.webUIURL));
                } else {
                    lines.push(qsTr("If your host PC is running Sunshine, navigate to the Sunshine web UI to enter the PIN."));
                }
                return lines.join("<br><br>");
            }
            onLinkActivated: function(link) {
                Qt.openUrlExternally(link);
            }
        }

        standardButtons: Dialog.Cancel
    }

    NavigableMessageDialog {
        id: deletePcDialog
        property int pcIndex: -1
        property string pcName: ""
        imageSrc: (Material.theme !== Material.Dark) ? "qrc:/res/baseline-error_outline-24px-dark.svg" : "qrc:/res/baseline-error_outline-24px.svg"
        text: qsTr("Are you sure you want to remove '%1'?").arg(pcName)
        standardButtons: Dialog.Yes | Dialog.No
        onAccepted: computerModel.deleteComputer(pcIndex)
    }

    NavigableMessageDialog {
        id: testConnectionDialog
        closePolicy: Popup.CloseOnEscape
        standardButtons: Dialog.Ok

        onAboutToShow: {
            testConnectionDialog.text = qsTr(
                        "Ocular is testing your network connection to determine if any required ports are blocked.") + "\n\n" + qsTr(
                        "This may take a few seconds…")
            showSpinner = true
        }

        property alias text: textLabel.text
        property alias imageSrc: img.source
        property bool showSpinner: false

        contentItem: ColumnLayout {
            spacing: 12
            RowLayout {
                spacing: 12
                BusyIndicator {
                    visible: testConnectionDialog.showSpinner
                    running: visible
                }
                Image {
                    id: img
                    visible: !testConnectionDialog.showSpinner
                    sourceSize.width: 24
                    sourceSize.height: 24
                }
                Label {
                    id: textLabel
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
            }
        }

        function connectionTestComplete(result, blockedPorts) {
            if (result === -1) {
                text = qsTr("The network test could not be performed because none of Ocular's connection testing servers were reachable from this PC. Check your Internet connection or try again later.")
                imageSrc = (Material.theme !== Material.Dark) ? "qrc:/res/baseline-warning-24px-dark.svg" : "qrc:/res/baseline-warning-24px.svg"
            } else if (result === 0) {
                text = qsTr("This network does not appear to be blocking Ocular. If you still have trouble connecting, check your PC's firewall settings.") + "\n\n" + qsTr(
                            "If you are trying to stream over the Internet, install the Ocular Internet Hosting Tool on your gaming PC and run the included Internet Streaming Tester to check your gaming PC's Internet connection.")
                imageSrc = (Material.theme !== Material.Dark) ? "qrc:/res/baseline-check_circle_outline-24px-dark.svg" : "qrc:/res/baseline-check_circle_outline-24px.svg"
            } else {
                text = qsTr("Your PC's current network connection seems to be blocking Ocular. Streaming over the Internet may not work while connected to this network.") + "\n\n" + qsTr(
                            "The following network ports were blocked:") + "\n"
                text += blockedPorts
                imageSrc = (Material.theme !== Material.Dark) ? "qrc:/res/baseline-error_outline-24px-dark.svg" : "qrc:/res/baseline-error_outline-24px.svg"
            }
            showSpinner = false
        }
    }

    NavigableDialog {
        id: renamePcDialog
        property string label: qsTr("Enter the new name for this PC:")
        property string originalName
        property int pcIndex: -1

        standardButtons: Dialog.Ok | Dialog.Cancel

        onOpened: editText.forceActiveFocus()
        onClosed: editText.clear()
        onAccepted: {
            if (editText.text) {
                computerModel.renameComputer(pcIndex, editText.text)
            }
        }

        ColumnLayout {
            Label {
                text: renamePcDialog.label
                font.bold: true
            }

            TextField {
                id: editText
                placeholderText: renamePcDialog.originalName
                Layout.fillWidth: true
                focus: true
                Keys.onReturnPressed: renamePcDialog.accept()
                Keys.onEnterPressed: renamePcDialog.accept()
            }
        }
    }

    NavigableMessageDialog {
        id: showPcDetailsDialog
        property string pcDetails: ""
        text: showPcDetailsDialog.pcDetails
        imageSrc: (Material.theme !== Material.Dark) ? "qrc:/res/baseline-help_outline-24px-dark.svg" : "qrc:/res/baseline-help_outline-24px.svg"
        standardButtons: Dialog.Ok
    }

    WarningPopup { id: displayWarningPopup }
}
