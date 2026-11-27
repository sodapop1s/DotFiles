import QtQuick
import QtQuick.Layouts
import "schoolutil.js" as U

// Study > Focus: study time over a longer stretch than the week: the last month, this semester, or everything ever logged.
// Reads the same focus log as the week chart (days -> { course: minutes }), so nothing is stored twice.
Rectangle {
    id: root
    required property var fs
    required property var sc

    property string range: "semester"                 // month | semester | all
    property string hover: ""                          // tooltip text for the bar under the mouse
    property bool   editingStart: false
    readonly property string defaultStart: { var d = new Date(fs.now); return d.getFullYear() + (d.getMonth() >= 7 ? "-08-24" : "-01-12") }
    readonly property string semesterStart: sc.pref("semesterStart", defaultStart)

    Layout.fillWidth: true; implicitHeight: col.implicitHeight + 28; radius: 12; color: Theme.raised; border { width: 1; color: Theme.hairline }

    function dayDate(iso) { return new Date(iso + "T00:00:00") }
    function monthName(d) { return ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][d.getMonth()] }
    function shortDate(d) { return monthName(d) + " " + d.getDate() }

    // everything for the chosen range in one pass: buckets for the chart, per-course totals, and the headline numbers
    readonly property var stats: {
        var log = fs.log, now = fs.now
        var today = new Date(now); today.setHours(0, 0, 0, 0)
        var keys = Object.keys(log).sort()
        var start
        if (range === "month") start = new Date(today.getTime() - 29 * 86400000)
        else if (range === "semester") start = dayDate(/^\d{4}-\d\d-\d\d$/.test(semesterStart) ? semesterStart : defaultStart)
        else start = keys.length ? dayDate(keys[0]) : today
        if (isNaN(start.getTime()) || start > today) start = today

        var spanDays = Math.round((today - start) / 86400000) + 1
        var gran = range === "month" ? "day" : (spanDays > 200 ? "month" : "week")
        var bucketOf = function (d) {
            if (gran === "day") return new Date(d)
            if (gran === "month") return new Date(d.getFullYear(), d.getMonth(), 1)
            var w = new Date(d); w.setDate(w.getDate() - ((w.getDay() + 6) % 7)); return w      // Monday
        }
        var buckets = [], index = {}, sums = {}, total = 0, active = 0, best = { min: 0, date: null }
        for (var t = new Date(start); t <= today; t.setDate(t.getDate() + 1)) {
            var d = new Date(t)
            var o = Object.assign({}, fs.dayObj(log[U.isoDate(d)]))
            if (d.getTime() === today.getTime() && fs.accumMs > 0) o[fs.course] = (o[fs.course] || 0) + Math.round(fs.accumMs / 60000)
            var day = 0
            Object.keys(o).forEach(function (c) { day += o[c]; sums[c] = (sums[c] || 0) + o[c] })
            total += day
            if (day > 0) active++
            if (day > best.min) best = { min: day, date: d }
            var b = bucketOf(d), k = U.isoDate(b)
            if (index[k] === undefined) { index[k] = buckets.length; buckets.push({ date: b, min: 0, parts: {} }) }
            var bk = buckets[index[k]]
            bk.min += day
            Object.keys(o).forEach(function (c) { bk.parts[c] = (bk.parts[c] || 0) + o[c] })
        }
        var courses = Object.keys(sums).map(function (c) { return { course: c, min: sums[c] } }).filter(function (x) { return x.min > 0 }).sort(function (a, b) { return b.min - a.min })
        var maxMin = 0
        buckets.forEach(function (b) { if (b.min > maxMin) maxMin = b.min })
        return { start: start, buckets: buckets, gran: gran, courses: courses, total: total, active: active, best: best, days: spanDays, maxMin: maxMin }
    }
    function bucketLabel(b) {
        if (stats.gran === "day") return shortDate(b.date)
        if (stats.gran === "month") return monthName(b.date) + " " + b.date.getFullYear()
        return "week of " + shortDate(b.date)
    }
    function setStart(text) {
        if (/^\d{4}-\d\d-\d\d$/.test(text) && !isNaN(dayDate(text).getTime())) sc.setPref("semesterStart", text)
        editingStart = false
    }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
        spacing: 10

        RowLayout {
            Layout.fillWidth: true; spacing: 6
            Text { text: "Study time"; color: Theme.text; font { family: Theme.fontUi; pixelSize: Theme.sizeUi; weight: Font.DemiBold } }
            Item { Layout.fillWidth: true }
            Repeater {
                model: [["month", "30 days"], ["semester", "Semester"], ["all", "All time"]]
                delegate: Chip { required property var modelData; implicitHeight: 26; text: modelData[1]; selected: root.range === modelData[0]; onClicked: root.range = modelData[0] }
            }
        }

        // semester start (click to change)
        RowLayout {
            visible: root.range === "semester"
            Layout.fillWidth: true; spacing: 8
            Text { text: "Since"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 } }
            Text {
                visible: !root.editingStart
                text: root.shortDate(root.stats.start) + "  (change)"; color: Theme.text; font { family: Theme.fontUi; pixelSize: 12 }
                MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: { root.editingStart = true; startInput.text = root.semesterStart; startInput.input.forceActiveFocus(); startInput.input.selectAll() } }
            }
            Field {
                id: startInput
                visible: root.editingStart
                Layout.preferredWidth: 130; implicitHeight: 28
                placeholder: "YYYY-MM-DD"
                onAccepted: root.setStart(text)
                input.Keys.onEscapePressed: root.editingStart = false
            }
            Text { visible: root.editingStart; text: "Press Enter to save"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 } }
            Item { Layout.fillWidth: true }
        }

        // headline numbers
        RowLayout {
            Layout.fillWidth: true; spacing: 22
            ColumnLayout { spacing: 0
                Text { text: U.minutesText(root.stats.total); color: Theme.text; font { family: Theme.fontUi; pixelSize: 18 } }
                Text { text: "Total"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 } } }
            ColumnLayout { spacing: 0
                Text { text: U.minutesText(root.stats.active > 0 ? Math.round(root.stats.total / root.stats.active) : 0); color: Theme.text; font { family: Theme.fontUi; pixelSize: 18 } }
                Text { text: "Per study day"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 } } }
            ColumnLayout { spacing: 0
                Text { text: root.stats.active + " of " + root.stats.days; color: Theme.text; font { family: Theme.fontUi; pixelSize: 18 } }
                Text { text: "Days studied"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 } } }
            ColumnLayout { spacing: 0; visible: root.stats.best.min > 0
                Text { text: U.minutesText(root.stats.best.min); color: Theme.text; font { family: Theme.fontUi; pixelSize: 18 } }
                Text { text: "Best day, " + (root.stats.best.date ? root.shortDate(root.stats.best.date) : ""); color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 } } }
            Item { Layout.fillWidth: true }
        }

        // the chart: one bar per day, week or month
        Item {
            Layout.fillWidth: true; Layout.preferredHeight: 108
            Text {
                anchors.left: parent.left; anchors.top: parent.top
                text: root.hover !== "" ? root.hover : (root.stats.total > 0 ? "Hover a bar for the details" : "Nothing logged in this range yet")
                color: root.hover !== "" ? Theme.text : Theme.muted; font { family: Theme.fontUi; pixelSize: 12 }
            }
            Row {
                id: bars
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 80
                spacing: root.stats.buckets.length > 60 ? 1 : 2
                Repeater {
                    model: root.stats.buckets
                    delegate: Item {
                        id: bar
                        required property var modelData
                        width: Math.max(1, (bars.width - bars.spacing * (root.stats.buckets.length - 1)) / root.stats.buckets.length)
                        height: bars.height
                        Rectangle {
                            anchors.bottom: parent.bottom; width: parent.width
                            height: bar.modelData.min === 0 ? 1 : Math.max(2, bar.modelData.min / Math.max(60, root.stats.maxMin) * bars.height)
                            radius: 1
                            color: hv.containsMouse ? Theme.accent : (bar.modelData.min === 0 ? Theme.hairline : Theme.muted)
                        }
                        MouseArea {
                            id: hv; anchors.fill: parent; hoverEnabled: true
                            onEntered: root.hover = root.bucketLabel(bar.modelData) + ", " + U.minutesText(bar.modelData.min)
                            onExited: root.hover = ""
                        }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Text { text: root.shortDate(root.stats.start) + (root.stats.start.getFullYear() !== new Date(root.fs.now).getFullYear() ? " " + root.stats.start.getFullYear() : ""); color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 } }
            Item { Layout.fillWidth: true }
            Text { text: root.stats.gran === "day" ? "Per day" : root.stats.gran === "week" ? "Per week" : "Per month"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 } }
            Item { Layout.fillWidth: true }
            Text { text: "Today"; color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 } }
        }

        // by course over the same range
        Repeater {
            model: root.stats.courses
            delegate: ColumnLayout {
                id: cb
                required property var modelData
                Layout.fillWidth: true; spacing: 3
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: cb.modelData.course === "" ? "General" : cb.modelData.course; color: Theme.text; font { family: Theme.fontUi; pixelSize: Theme.sizeUi } }
                    Item { Layout.fillWidth: true }
                    Text { text: Math.round(cb.modelData.min / Math.max(1, root.stats.total) * 100) + "%  ·  " + U.minutesText(cb.modelData.min); color: Theme.muted; font { family: Theme.fontUi; pixelSize: 12 } }
                }
                Meter { Layout.fillWidth: true; value: cb.modelData.min / Math.max(1, root.stats.courses[0].min) }
            }
        }
    }
}
