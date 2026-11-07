import QtQuick
import QtQuick.Layouts

// Study window: due dates, exams, grades and the focus timer. The pages are the existing School pages;
// `host` is the shell root, which provides what they used to get from the old bar (school, studyFocus, hubOpen, dndOn).
Item {
    id: root
    width: parent.width
    height: 640

    required property var host
    property bool active: false
    property string tab: "due"

    readonly property var tabList: [
        { id: "due", label: "Due" }, { id: "exams", label: "Exams" },
        { id: "grades", label: "Grades" }, { id: "focus", label: "Focus" }
    ]
    function setTab(t) { tab = t; load() }
    function load() {
        host.school.refresh(); host.school.refreshEvents()
        if (tab === "exams") examsPage.activate()
        else if (tab === "grades") gradesPage.activate()
    }
    onActiveChanged: if (active) load()

    Row {
        id: tabs
        spacing: 8
        Repeater {
            model: root.tabList
            delegate: Rectangle {
                id: tb
                required property var modelData
                readonly property bool sel: root.tab === modelData.id
                implicitWidth: lbl.implicitWidth + 28; implicitHeight: 32
                radius: 8
                color: sel || ta.containsMouse ? Theme.raised : "transparent"
                border { width: 1; color: sel ? Theme.accent : Theme.hairline }
                Text { id: lbl; anchors.centerIn: parent; text: tb.modelData.label; color: Theme.text; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
                Rectangle {   // something here needs attention
                    visible: (tb.modelData.id === "due" && root.host.school.overdue.length > 0)
                             || (tb.modelData.id === "focus" && (root.host.studyFocus.modeOn || root.host.studyFocus.phase !== "idle"))
                    x: parent.width - 10; y: 6; width: 6; height: 6; radius: 3
                    color: tb.modelData.id === "focus" ? Theme.good : Theme.crit
                }
                MouseArea { id: ta; anchors.fill: parent; hoverEnabled: true; onClicked: root.setTab(tb.modelData.id) }
            }
        }
    }
    Rectangle { id: sep; anchors { top: tabs.bottom; topMargin: 10; left: parent.left; right: parent.right } height: 1; color: Theme.hairline }

    SchoolDue    { id: duePage;    bar: root.host; visible: root.tab === "due";    anchors { top: sep.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: parent.bottom } }
    SchoolExams  { id: examsPage;  bar: root.host; visible: root.tab === "exams";  anchors { top: sep.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: parent.bottom } }
    SchoolGrades { id: gradesPage; bar: root.host; visible: root.tab === "grades"; anchors { top: sep.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: parent.bottom } }
    SchoolFocus  { id: focusPage;  bar: root.host; visible: root.tab === "focus";  anchors { top: sep.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: parent.bottom } }
}
