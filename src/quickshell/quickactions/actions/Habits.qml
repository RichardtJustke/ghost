import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../reusables"
import "../../"

Item {
    id: root

    property int requestedLayoutTemplate: 1
    property bool isActiveTab: typeof isCurrentTarget !== "undefined" ? isCurrentTarget : true
    property string safeActiveEdge: typeof activeEdge !== "undefined" ? activeEdge : "left"

    function s(val) {
        return typeof scaleFunc === "function" ? scaleFunc(val) : val;
    }

    property real baseW: s(300)
    property real baseL: s(340)

    property real preferredWidth: (root.safeActiveEdge === "bottom" || root.safeActiveEdge === "top") ? baseL : baseW
    property real preferredExtraLength: (root.safeActiveEdge === "bottom" || root.safeActiveEdge === "top") ? baseW : baseL

    readonly property var habitIds: ["coding", "water", "read"]
    readonly property var habitNames: ({
        coding: I18n.t("quickactions.habits.habit.coding"),
        water: I18n.t("quickactions.habits.habit.water"),
        read: I18n.t("quickactions.habits.habit.read")
    })
    readonly property string scriptPath: Quickshell.env("QS_DIR") + "/quickactions/actions/habits.py"

    property var habitStatus: []
    property int xp: 0
    property int level: 1
    property int xpIntoLevel: 0
    property int xpPerLevel: 10
    property var heatmap: []

    function getStorageDir() {
        return Quickshell.env("QS_STATE_HABITS") || ((Quickshell.env("HOME") || "/tmp") + "/.local/state/serpantinum/habits");
    }

    function getIsoDate(d) {
        let z = d.getTimezoneOffset() * 60000;
        return (new Date(d - z)).toISOString().slice(0, 10);
    }

    function applyStatus(data) {
        root.habitStatus = data.habits || [];
        root.xp = data.xp || 0;
        root.level = data.level || 1;
        root.xpIntoLevel = data.xpIntoLevel || 0;
        root.xpPerLevel = data.xpPerLevel || 10;
        root.heatmap = data.heatmap || [];
    }

    function habitStatusFor(id) {
        for (let i = 0; i < root.habitStatus.length; i++) {
            if (root.habitStatus[i].id === id) return root.habitStatus[i];
        }
        return { id: id, done: false, streak: 0 };
    }

    function requestStatus() {
        statusProc.command = ["python3", root.scriptPath, "status", root.getIsoDate(new Date()), "--habits", root.habitIds.join(","), "--db-dir", root.getStorageDir()];
        statusProc.running = true;
    }

    function toggleHabit(habitId) {
        toggleProc.command = ["python3", root.scriptPath, "toggle", root.getIsoDate(new Date()), habitId, "--habits", root.habitIds.join(","), "--db-dir", root.getStorageDir()];
        toggleProc.running = true;
    }

    Process {
        id: statusProc
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = this.text.trim();
                if (raw === "") return;
                try { root.applyStatus(JSON.parse(raw)); } catch(e) {}
            }
        }
    }

    Process {
        id: toggleProc
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = this.text.trim();
                if (raw === "") return;
                try { root.applyStatus(JSON.parse(raw)); } catch(e) {}
            }
        }
    }

    Component.onCompleted: root.requestStatus()
    onIsActiveTabChanged: if (root.isActiveTab) root.requestStatus()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.s(16)
        spacing: root.s(12)

        RowLayout {
            Layout.fillWidth: true
            spacing: root.s(4)

            Text {
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(11)
                color: ThemeBackend.green
                text: (Quickshell.env("USER") || "user") + "@ghost"
            }
            Text {
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(11)
                color: ThemeBackend.overlay0
                text: "$"
            }
            Text {
                font.family: ThemeBackend.fontFamily
                font.weight: Font.DemiBold
                font.pixelSize: root.s(11)
                color: ThemeBackend.text
                text: I18n.t("quickactions.habits.title")
            }
            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: root.s(8)

            Text {
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(10)
                color: ThemeBackend.subtext0
                text: I18n.t("quickactions.habits.level", { "n": root.level })
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.s(6)
                radius: height / 2
                color: ThemeBackend.surface0

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    radius: height / 2
                    width: parent.width * (root.xpIntoLevel / root.xpPerLevel)
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: ThemeBackend.mauve }
                        GradientStop { position: 1.0; color: ThemeBackend.blue }
                    }
                }
            }

            Text {
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(10)
                color: ThemeBackend.overlay0
                text: root.xpIntoLevel + "/" + root.xpPerLevel + " xp"
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: root.s(6)

            Repeater {
                model: root.habitIds
                delegate: Item {
                    id: habitRow
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.s(22)

                    property var st: root.habitStatusFor(modelData)

                    RowLayout {
                        anchors.fill: parent
                        spacing: root.s(10)

                        Rectangle {
                            Layout.preferredWidth: root.s(16)
                            Layout.preferredHeight: root.s(16)
                            radius: root.s(4)
                            color: habitRow.st.done ? ThemeBackend.green : "transparent"
                            border.width: 1
                            border.color: habitRow.st.done ? ThemeBackend.green : ThemeBackend.surface2
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                visible: habitRow.st.done
                                text: "✓"
                                font.pixelSize: root.s(10)
                                font.bold: true
                                color: ThemeBackend.crust
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(12)
                            color: habitRow.st.done ? ThemeBackend.overlay0 : ThemeBackend.text
                            font.strikeout: habitRow.st.done
                            text: root.habitNames[habitRow.modelData] || habitRow.modelData
                            elide: Text.ElideRight
                        }

                        Text {
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(10.5)
                            color: ThemeBackend.peach
                            text: "🔥 " + habitRow.st.streak
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -root.s(4)
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleHabit(habitRow.modelData)
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: root.s(4)

            Flow {
                Layout.fillWidth: true
                spacing: root.s(3)

                Repeater {
                    model: root.heatmap
                    delegate: Rectangle {
                        required property var modelData
                        width: root.s(8)
                        height: root.s(8)
                        radius: root.s(2)
                        color: modelData.ratio <= 0 ? ThemeBackend.surface1 : Qt.rgba(ThemeBackend.green.r, ThemeBackend.green.g, ThemeBackend.green.b, Math.min(1.0, 0.25 + 0.75 * modelData.ratio))
                        Behavior on color { ColorAnimation { duration: 400 } }
                    }
                }
            }

            Text {
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(9.5)
                color: ThemeBackend.overlay0
                text: I18n.t("quickactions.habits.heatmap_caption")
            }
        }
    }
}
