import QtQuick
import QtQuick.Layouts
import Quickshell
import "schoolutil.js" as U

// School > Money: a simple monthly budget. Add spending by typing "$12 coffee", or import the CSV your bank lets you
// download (Bank of America: Accounts → Activity → Download). Nothing here talks to a bank; it all stays in
// ~/.local/share/qs-bar/budget.json.
Flickable {
    id: root
    required property var bar
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property color accent: Theme.green
    contentHeight: col.implicitHeight + 24
    clip: true; boundsBehavior: Flickable.StopAtBounds

    property var    sum: null
    property string month: ""
    property var    found: []                   // bank CSVs waiting in Downloads
    property string status: ""
    property bool   statusErr: false
    property string chooseFor: ""               // transaction whose category is being picked
    property string limitFor: ""                // category whose monthly limit is being typed
    readonly property var palette: [Theme.green, Theme.sky, Theme.mauve, Theme.peach, Theme.pink, Theme.yellow, Theme.teal, Theme.red]

    Job { id: sumJob;  script: Quickshell.shellPath("budget.sh") }
    Job { id: actJob;  script: Quickshell.shellPath("budget.sh") }
    Job { id: scanJob; script: Quickshell.shellPath("budget.sh") }
    function say(msg, err) { status = msg; statusErr = !!err; statusTimer.restart() }
    Timer { id: statusTimer; interval: 4500; onTriggered: root.status = "" }
    function activate() { load(month); scanJob.go(["scan"], r => { if (Array.isArray(r)) found = r }) }
    function load(m) { sumJob.go(m ? ["summary", m] : ["summary"], r => { if (r && !r.error) { sum = r; month = r.month } else if (r) say(r.error, true) }) }
    function act(args, then) { actJob.go(args, r => { if (r && r.error) say(r.error, true); else if (then) then(r); load(month) }) }
    function monthStep(d) {
        if (!sum) return
        var i = sum.months.indexOf(month) - d      // months are newest first
        if (i >= 0 && i < sum.months.length) load(sum.months[i])
    }
    function monthName(m) { if (!m) return ""; var d = new Date(m + "-01T12:00:00"); return ["January","February","March","April","May","June","July","August","September","October","November","December"][d.getMonth()] + " " + d.getFullYear() }

    ColumnLayout {
        id: col
        x: 14; width: root.width - 28; y: 8
        spacing: 10

        RowLayout {
            Layout.fillWidth: true; spacing: 10
            Text { text: "󰁍"; color: Theme.dim; font { family: root.font; pixelSize: 14 }
                   MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: root.monthStep(-1) } }
            Text { text: root.monthName(root.month); color: Theme.text; font { family: root.font; pixelSize: 13; bold: true } }
            Text { text: "󰁔"; color: Theme.dim; font { family: root.font; pixelSize: 14 }
                   MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: root.monthStep(1) } }
            Item { Layout.fillWidth: true }
            Text { visible: root.status.length > 0; text: root.status; color: root.statusErr ? Theme.red : Theme.green; elide: Text.ElideRight; Layout.maximumWidth: 250; font { family: root.font; pixelSize: 10 } }
        }

        // totals
        RowLayout {
            Layout.fillWidth: true; spacing: 8
            Repeater {
                model: root.sum ? [
                    { label: "spent", value: U.money(root.sum.spent), color: Theme.text },
                    { label: "income", value: U.money(root.sum.income), color: Theme.green },
                    root.sum.left !== null ? { label: root.sum.left >= 0 ? "left of budget" : "over budget", value: U.money(Math.abs(root.sum.left)), color: root.sum.left >= 0 ? Theme.sky : Theme.red }
                                           : { label: "budget", value: "not set", color: Theme.dim }
                ] : []
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true; Layout.preferredWidth: 1; implicitHeight: 54; radius: 12; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                    ColumnLayout {
                        anchors.centerIn: parent; spacing: 0
                        Text { Layout.alignment: Qt.AlignHCenter; text: modelData.value; color: modelData.color; font { family: root.font; pixelSize: 16; bold: true } }
                        Text { Layout.alignment: Qt.AlignHCenter; text: modelData.label; color: Theme.dim; font { family: root.font; pixelSize: 9 } }
                    }
                }
            }
        }
        Text {
            visible: root.sum && root.sum.perDay !== null && root.sum.left > 0
            text: root.sum && root.sum.perDay !== null ? "about " + U.money(root.sum.perDay) + " a day for the next " + root.sum.daysLeft + " days" : ""
            color: Theme.subtext; font { family: root.font; pixelSize: 10 }
        }

        // quick add
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 40; radius: 12; color: Qt.alpha(root.accent, 0.08)
            border { color: addIn.activeFocus ? Qt.alpha(root.accent, 0.6) : Qt.alpha(root.accent, 0.3); width: 1 }
            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 10 }
spacing: 8
                Text { text: "󰐕"; color: root.accent; font { family: root.font; pixelSize: 15 } }
                TextInput {
                    id: addIn
                    Layout.fillWidth: true; color: Theme.text; clip: true; font { family: root.font; pixelSize: 12 }
                    onAccepted: { var t = text; text = ""; root.act(["add", t], r => root.say("added " + r.tx.desc + " (" + r.tx.cat + ")", false)) }
                    Text { visible: addIn.text.length === 0; anchors.verticalCenter: parent.verticalCenter; color: Theme.dim; font { family: root.font; pixelSize: 11 }
text: "$12.50 coffee      (+200 paycheck for income)" }
                }
            }
        }

        // categories
        Text { visible: root.sum && root.sum.byCat.length > 0; text: "WHERE IT WENT   (click a bar to set a monthly limit)"; color: Theme.dim; font { family: root.font; pixelSize: 9; bold: true; letterSpacing: 1 } }
        Repeater {
            model: root.sum ? root.sum.byCat : []
            delegate: ColumnLayout {
                id: cat
                required property var modelData
                required property int index
                readonly property color c: root.palette[index % root.palette.length]
                readonly property real frac: modelData.limit > 0 ? Math.min(1, modelData.spent / modelData.limit) : (root.sum.spent > 0 ? modelData.spent / root.sum.spent : 0)
                readonly property bool over: modelData.limit > 0 && modelData.spent > modelData.limit
                Layout.fillWidth: true; spacing: 3
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: cat.modelData.cat; color: Theme.text; font { family: root.font; pixelSize: 11 } }
                    Item { Layout.fillWidth: true }
                    Text { text: U.money(cat.modelData.spent) + (cat.modelData.limit > 0 ? " / " + U.money(cat.modelData.limit) : ""); color: cat.over ? Theme.red : Theme.subtext; font { family: root.font; pixelSize: 10 } }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 8; radius: 4; color: Qt.alpha(cat.c, 0.15)
                    Rectangle { width: parent.width * cat.frac; height: parent.height; radius: 4; color: cat.over ? Theme.red : cat.c }
                    MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: { root.limitFor = root.limitFor === cat.modelData.cat ? "" : cat.modelData.cat; limIn.text = cat.modelData.limit > 0 ? String(cat.modelData.limit) : ""; limIn.forceActiveFocus() } }
                }
                RowLayout {
                    visible: root.limitFor === cat.modelData.cat
                    Layout.fillWidth: true; spacing: 8
                    Text { text: "monthly limit $"; color: Theme.subtext; font { family: root.font; pixelSize: 10 } }
                    Rectangle {
                        Layout.preferredWidth: 80; Layout.preferredHeight: 26; radius: 8; color: Qt.alpha(Theme.mauve, 0.08); border { color: Theme.sep; width: 1 }
                        TextInput { id: limIn; anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
verticalAlignment: TextInput.AlignVCenter; color: Theme.text; font { family: root.font; pixelSize: 11 }
                                    onAccepted: { var v = text; root.limitFor = ""; root.act(["limit", cat.modelData.cat, v || "0"]) } }
                    }
                    Text { text: "enter to save  (0 clears)"; color: Theme.dim; font { family: root.font; pixelSize: 9 } }
                }
            }
        }

        // transactions
        Text { visible: root.sum && root.sum.recent.length > 0; text: "RECENT"; color: Theme.dim; font { family: root.font; pixelSize: 9; bold: true; letterSpacing: 1 } }
        Repeater {
            model: root.sum ? root.sum.recent : []
            delegate: ColumnLayout {
                id: tx
                required property var modelData
                Layout.fillWidth: true; spacing: 4
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 40; radius: 10; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
spacing: 8
                        Text { text: tx.modelData.date.slice(5).replace("-", "/"); color: Theme.dim; Layout.preferredWidth: 36; font { family: root.font; pixelSize: 9 } }
                        Text { text: tx.modelData.desc; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 11 } }
                        Rectangle {
                            Layout.preferredHeight: 20; Layout.preferredWidth: ct.implicitWidth + 14; radius: 10
                            color: tx.modelData.cat === "Other" ? Qt.alpha(Theme.yellow, 0.18) : Qt.alpha(Theme.mauve, 0.12)
                            Text { id: ct; anchors.centerIn: parent; text: tx.modelData.cat; color: tx.modelData.cat === "Other" ? Theme.yellow : Theme.subtext; font { family: root.font; pixelSize: 9 } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.chooseFor = root.chooseFor === tx.modelData.id ? "" : tx.modelData.id }
                        }
                        Text { text: U.money(tx.modelData.amt); color: tx.modelData.amt < 0 ? Theme.text : Theme.green; Layout.preferredWidth: 62; horizontalAlignment: Text.AlignRight; font { family: root.font; pixelSize: 11; bold: true } }
                        Text { text: "✕"; color: Theme.dim; font { family: root.font; pixelSize: 10 }
                               MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.act(["drop", tx.modelData.id]) } }
                    }
                }
                Flow {
                    visible: root.chooseFor === tx.modelData.id
                    Layout.fillWidth: true; spacing: 5
                    Repeater {
                        model: root.sum ? root.sum.cats : []
                        delegate: Rectangle {
                            required property string modelData
                            height: 22; width: pc.implicitWidth + 16; radius: 11; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
                            Text { id: pc; anchors.centerIn: parent; text: modelData; color: Theme.text; font { family: root.font; pixelSize: 10 } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { var id = root.chooseFor; root.chooseFor = ""; root.act(["recat", id, modelData], r => root.say("remembered for this merchant", false)) } }
                        }
                    }
                }
            }
        }
        Text { visible: root.sum && root.sum.count === 0; Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.dim; font { family: root.font; pixelSize: 11 }
               text: "Nothing this month yet. Type an expense above, or import your bank's CSV below." }

        // import
        Rectangle {
            Layout.fillWidth: true; implicitHeight: impCol.implicitHeight + 24; radius: 12; color: Theme.card; border { color: Theme.cardBorder; width: 1 }
            ColumnLayout {
                id: impCol
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
                spacing: 8
                Text { text: "󰈙  Import from your bank"; color: Theme.text; font { family: root.font; pixelSize: 12; bold: true } }
                Text {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap; color: Theme.dim; font { family: root.font; pixelSize: 10 }
                    text: "Bank of America: sign in on their website → pick the account → Activity → Download → CSV. Save it in Downloads and it shows up here. This never logs in to your bank, and duplicates are skipped when you import again."
                }
                Repeater {
                    model: root.found
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true; spacing: 8
                        Text { text: modelData.name; color: Theme.text; elide: Text.ElideRight; Layout.fillWidth: true; textFormat: Text.PlainText; font { family: root.font; pixelSize: 11 } }
                        Text { text: modelData.count + " rows"; color: Theme.dim; font { family: root.font; pixelSize: 9 } }
                        Rectangle {
                            Layout.preferredWidth: 70; Layout.preferredHeight: 26; radius: 9; color: root.accent
                            Text { anchors.centerIn: parent; text: "Import"; color: Theme.crust; font { family: root.font; pixelSize: 11; bold: true } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: root.act(["import", modelData.path], r => { root.say("imported " + r.added + " new, skipped " + r.skipped, false); scanJob.go(["scan"], s => { if (Array.isArray(s)) root.found = s }) }) }
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 30; radius: 8; color: Qt.alpha(Theme.mauve, 0.07); border { color: pathIn.activeFocus ? Qt.alpha(root.accent, 0.5) : Theme.sep; width: 1 }
                    TextInput {
                        id: pathIn
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
verticalAlignment: TextInput.AlignVCenter; clip: true; color: Theme.text; font { family: root.font; pixelSize: 11 }
                        onAccepted: { var p = text; text = ""; root.act(["import", p], r => root.say("imported " + r.added + " new, skipped " + r.skipped, false)) }
                        Text { visible: pathIn.text.length === 0; anchors.verticalCenter: parent.verticalCenter; color: Theme.dim; font { family: root.font; pixelSize: 10 }
text: "or type the path of a .csv file and press enter" }
                    }
                }
            }
        }
    }
}
