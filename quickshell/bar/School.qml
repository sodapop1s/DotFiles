import QtQuick
import QtQuick.Layouts
import Quickshell

// School: Canvas due dates, exams and grades, a study timer and focus mode, Obsidian notes and lectures, aero tools, a budget,
// and a weekly review.
// The data lives in SchoolData.qml / FocusState.qml (created by Bar.qml); this file is the tab strip and the pages.
Item {
    id: root
    required property var bar
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.blue
    property alias notes: notesPage
    property alias due: duePage

    property string tab: "due"                 // due | grades | focus | notes | money | tools
    function setTab(t) { tab = t; activate() }
    function activate() {
        bar.school.refresh(); bar.school.refreshEvents()
        if (tab === "grades") gradesPage.activate()
        else if (tab === "exams") examsPage.activate()
        else if (tab === "aero") aeroPage.activate()
        else if (tab === "week") weekPage.activate()
        else if (tab === "notes") notesPage.activate()
        else if (tab === "money") moneyPage.activate()
        else if (tab === "tools") toolsPage.activate()
    }
    function testGrades() { setTab("grades"); if (bar.school.courses.length) gradesPage.open(bar.school.courses[0]) }     // used for testing from the command line
    // used for testing from the command line
    function testFocus() { bar.studyFocus.start() }
    function testFocusSkip() { bar.studyFocus.skip() }
    function testFocusReset() { bar.studyFocus.reset() }
    function testMode() { bar.studyFocus.startMode(5) }
    function testModeEnd() { bar.studyFocus.endMode() }
    function testWrongPassword() { bar.studyFocus.endWithPassword("definitely-not-the-password") }
    function testKspPlanner() { setTab("aero"); aeroPage.setSystem(1); aeroPage.sub = "planner" }
    function testOpmPlanner() { setTab("aero"); aeroPage.setSystem(2); aeroPage.planOrigin = "kerbin"; aeroPage.sub = "planner" }
    function testKspOrbit() { setTab("aero"); aeroPage.setSystem(1); aeroPage.sub = "orbit" }
    function captureNote() { setTab("notes"); notesPage.focusCapture() }

    // the tab strip: icons for all of them, the name only for the open one
    readonly property var tabList: [
        { id: "due",    label: "Due",    icon: "󰃭" },
        { id: "exams",  label: "Exams",  icon: "󰈙" },
        { id: "grades", label: "Grades", icon: "󰄪" },
        { id: "focus",  label: "Focus",  icon: "󰔟" },
        { id: "notes",  label: "Notes",  icon: "󰎞" },
        { id: "aero",   label: "Aero",   icon: "󰀲" },
        { id: "money",  label: "Money",  icon: "󰠓" },
        { id: "tools",  label: "Tools",  icon: "󰦬" },
        { id: "week",   label: "Week",   icon: "󰃰" }
    ]
    Row {
        id: tabs
        anchors { top: parent.top; topMargin: 2; left: parent.left; leftMargin: 14 }
        width: parent.width - 28
        spacing: 4
        Repeater {
            model: root.tabList
            delegate: Rectangle {
                id: tb
                required property var modelData
                readonly property bool sel: root.tab === modelData.id
                readonly property real small: 36
                width: sel ? tabs.width - (root.tabList.length - 1) * (small + tabs.spacing) : small
                height: 30; radius: 10
                color: sel ? Qt.alpha(root.accent, 0.18) : (ta.containsMouse ? Qt.alpha(Theme.mauve, 0.08) : "transparent")
                border { color: sel ? Qt.alpha(root.accent, 0.45) : Theme.cardBorder; width: 1 }
                Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                RowLayout {
                    anchors.centerIn: parent; spacing: 5
                    Text { text: tb.modelData.icon; color: tb.sel ? root.accent : Theme.dim; font { family: root.font; pixelSize: 14 } }
                    Text { visible: tb.sel; text: tb.modelData.label; color: root.accent; font { family: root.font; pixelSize: 10; bold: true } }
                    Rectangle {      // a dot for things that need you
                        visible: (tb.modelData.id === "due" && root.bar.school.overdue.length > 0)
                                 || (tb.modelData.id === "focus" && (root.bar.studyFocus.modeOn || root.bar.studyFocus.phase !== "idle"))
                                 || (tb.modelData.id === "exams" && root.bar.school.nextExam !== null && root.bar.school.nextExam.whenMs - root.bar.school.nowMs < 3 * 86400000)
                        width: 6; height: 6; radius: 3
                        color: tb.modelData.id === "focus" ? Theme.green : Theme.red
                    }
                }
                MouseArea { id: ta; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setTab(tb.modelData.id) }
            }
        }
    }
    Rectangle { id: sep; anchors { top: tabs.bottom; topMargin: 8; left: parent.left; right: parent.right; leftMargin: 14; rightMargin: 14 } height: 1; color: Theme.sep }

    SchoolDue    { id: duePage;    bar: root.bar; visible: root.tab === "due";    anchors { top: sep.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: parent.bottom } }
    SchoolExams  { id: examsPage;  bar: root.bar; visible: root.tab === "exams";  anchors { top: sep.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: parent.bottom } }
    SchoolGrades { id: gradesPage; bar: root.bar; visible: root.tab === "grades"; anchors { top: sep.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: parent.bottom } }
    SchoolFocus  { id: focusPage;  bar: root.bar; visible: root.tab === "focus";  anchors { top: sep.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: parent.bottom } }
    SchoolNotes  { id: notesPage;  bar: root.bar; visible: root.tab === "notes";  anchors { top: sep.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: parent.bottom } }
    SchoolAero   { id: aeroPage;   bar: root.bar; visible: root.tab === "aero";   anchors { top: sep.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: parent.bottom } }
    SchoolReview { id: weekPage;   bar: root.bar; visible: root.tab === "week";   anchors { top: sep.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: parent.bottom } }
    SchoolMoney  { id: moneyPage;  bar: root.bar; visible: root.tab === "money";  anchors { top: sep.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: parent.bottom } }
    SchoolTools  { id: toolsPage;  bar: root.bar; visible: root.tab === "tools";  anchors { top: sep.bottom; topMargin: 4; left: parent.left; right: parent.right; bottom: parent.bottom } }
}
