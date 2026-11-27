import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// Study window: due dates, exams, grades and the focus timer. `host` is the shell root, which provides
// what the pages need (school, studyFocus, dndOn).
//   qs -c orbit ipc call study tab due|exams|grades|focus     (opens that tab; handy for scripts and testing)
//   qs -c orbit ipc call study course <n> | exam | addexam    (open a course, expand the first exam, show the add form)
//   qs -c orbit ipc call study timer start|pause|toggle|reset (the study timer, so it can sit on a key)
Item {
    id: root
    width: parent.width
    height: 640

    required property var host
    property bool active: false
    property string tab: "due"
    signal done()

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

    IpcHandler {
        target: "study"
        function tab(t: string): void { root.setTab(t) }
        function timer(action: string): void {
            if (action === "start") host.studyFocus.start()
            else if (action === "pause") host.studyFocus.pause()
            else if (action === "toggle") host.studyFocus.toggle()
            else if (action === "reset") host.studyFocus.reset()
        }
        function course(n: int): void { root.setTab("grades"); if (host.school.courses[n]) gradesPage.open(host.school.courses[n]) }
        function exam(): void { root.setTab("exams"); if (host.school.exams.length) examsPage.openId = host.school.exams[0].id }
        function addexam(): void { root.setTab("exams"); examsPage.adding = true }
    }

    Row {
        id: tabs
        spacing: 8
        Repeater {
            model: root.tabList
            delegate: Chip {
                id: tb
                required property var modelData
                text: modelData.label
                selected: root.tab === modelData.id
                onClicked: root.setTab(modelData.id)
                Rectangle {   // something on this tab needs attention
                    visible: (tb.modelData.id === "due" && root.host.school.overdue.length > 0)
                             || (tb.modelData.id === "focus" && (root.host.studyFocus.modeOn || root.host.studyFocus.phase !== "idle"))
                    x: parent.width - 11; y: 5; width: 6; height: 6; radius: 3
                    color: tb.modelData.id === "focus" ? Theme.good : Theme.crit
                }
            }
        }
    }
    Rectangle { id: sep; anchors { top: tabs.bottom; topMargin: 12; left: parent.left; right: parent.right } height: 1; color: Theme.hairline }

    SchoolDue    { id: duePage;    bar: root.host; visible: root.tab === "due";    onCloseRequested: root.done(); anchors { top: sep.bottom; topMargin: 6; left: parent.left; right: parent.right; bottom: parent.bottom } }
    SchoolExams  { id: examsPage;  bar: root.host; visible: root.tab === "exams";  onCloseRequested: root.done(); anchors { top: sep.bottom; topMargin: 6; left: parent.left; right: parent.right; bottom: parent.bottom } }
    SchoolGrades { id: gradesPage; bar: root.host; visible: root.tab === "grades"; onCloseRequested: root.done(); anchors { top: sep.bottom; topMargin: 6; left: parent.left; right: parent.right; bottom: parent.bottom } }
    SchoolFocus  { id: focusPage;  bar: root.host; visible: root.tab === "focus";  onCloseRequested: root.done(); anchors { top: sep.bottom; topMargin: 6; left: parent.left; right: parent.right; bottom: parent.bottom } }
}
