.pragma library

function pad(n) { return n < 10 ? "0" + n : "" + n }
function isoDate(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) }
function dayStart(ms) { var d = new Date(ms); d.setHours(0, 0, 0, 0); return d.getTime() }
function clock(ms) {
    var d = new Date(ms), h = d.getHours(), m = d.getMinutes()
    return (h % 12 === 0 ? 12 : h % 12) + (m ? ":" + pad(m) : "") + (h < 12 ? " AM" : " PM")
}
// "in 3h", "in 25m", "2d ago"
function rel(ms, now) {
    var diff = ms - now, a = Math.abs(diff), s = a / 1000
    var t = s < 90 ? "now" : s < 3600 ? Math.round(s / 60) + "m" : s < 86400 ? Math.floor(s / 3600) + "h" : Math.round(s / 86400) + "d"
    if (t === "now") return "now"
    return diff >= 0 ? "in " + t : t + " ago"
}
// bucket for grouping the assignment list
function bucket(ms, now) {
    if (ms < now) return "Past due"
    var today = dayStart(now), d = dayStart(ms)
    var days = Math.round((d - today) / 86400000)
    if (days === 0) return "Today"
    if (days === 1) return "Tomorrow"
    if (days < 7) return "This week"
    return "Later"
}
function dueLabel(ms, now) {
    var d = new Date(ms), days = Math.round((dayStart(ms) - dayStart(now)) / 86400000)
    var when = days === 0 ? "today" : days === 1 ? "tomorrow" : days < 7 ? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][d.getDay()] : (d.getMonth() + 1) + "/" + d.getDate()
    return when + " " + clock(ms)
}
function shortCourse(code) { return (code || "").replace(/\s+\d{4,}.*$/, "").slice(0, 14) || code }
function money(v) { var n = Math.abs(v); return (v < 0 ? "-" : "") + "$" + (n >= 1000 ? n.toFixed(0).replace(/\B(?=(\d{3})+(?!\d))/g, ",") : n.toFixed(2)) }
function minutesText(m) { return m >= 60 ? Math.floor(m / 60) + "h " + pad(m % 60) + "m" : m + "m" }

// "2026-10-22 14:00", "10/22 2pm", "oct 22 2:30pm", "Oct 22" -> ms (local time), NaN when it cannot be read
var MONTHS = { jan: 0, feb: 1, mar: 2, apr: 3, may: 4, jun: 5, jul: 6, aug: 7, sep: 8, oct: 9, nov: 10, dec: 11 }
function parseWhen(text, now) {
    var s = String(text || "").trim().toLowerCase().replace(/,/g, " ").replace(/\s+/g, " ")
    if (!s) return NaN
    var base = new Date(now || Date.now()), y = base.getFullYear(), mo = -1, d = 0, hh = 9, mm = 0, m
    if ((m = /^(\d{4})-(\d{1,2})-(\d{1,2})/.exec(s))) { y = +m[1]; mo = +m[2] - 1; d = +m[3]; s = s.slice(m[0].length).trim() }
    else if ((m = /^(\d{1,2})\/(\d{1,2})(?:\/(\d{2,4}))?/.exec(s))) { mo = +m[1] - 1; d = +m[2]; if (m[3]) y = +m[3] < 100 ? 2000 + +m[3] : +m[3]; s = s.slice(m[0].length).trim() }
    else if ((m = /^([a-z]{3})[a-z]*\.? (\d{1,2})(?:st|nd|rd|th)?(?: (\d{4}))?/.exec(s)) && MONTHS[m[1]] !== undefined) { mo = MONTHS[m[1]]; d = +m[2]; if (m[3]) y = +m[3]; s = s.slice(m[0].length).trim() }
    else return NaN
    if ((m = /^(?:at )?(\d{1,2})(?::(\d{2}))?\s*(am|pm|a|p)?$/.exec(s))) {
        hh = +m[1]; mm = m[2] ? +m[2] : 0
        if (m[3]) { var pm = m[3][0] === "p"; if (pm && hh < 12) hh += 12; if (!pm && hh === 12) hh = 0 }
    } else if (s.length) return NaN
    if (hh > 23 || mm > 59) return NaN
    var t = new Date(y, mo, d, hh, mm, 0, 0)
    if (isNaN(t.getTime()) || t.getMonth() !== mo) return NaN
    // no year given and it is already past: they mean next year
    if (!/\d{4}/.test(String(text)) && t.getTime() < base.getTime() - 86400000) t = new Date(y + 1, mo, d, hh, mm, 0, 0)
    return t.getTime()
}
function isExamName(name) {
    var n = name || ""
    if (/\b(review|practice|prep|study guide|survey|reflection)\b/i.test(n)) return false
    return /\b(exam|midterm|test|quiz)\b/i.test(n) || /^final\b(?!\s*(project|paper|report|presentation|draft|portfolio|submission))/i.test(n)
}
function dayCount(ms, now) { return Math.round((dayStart(ms) - dayStart(now)) / 86400000) }
// spread the topics you have not finished over the days before an exam, one lot per day, keeping the last day for review.
// -> [{day, ms, topics:[...], review}]
function studyPlan(topics, examMs, now, maxDays) {
    var days = dayCount(examMs, now)
    if (days <= 0) return []
    var open = topics.filter(function (t) { return !t.done }).map(function (t) { return t.t })
    var study = days >= 3 ? days - 1 : days
    var plan = []
    if (open.length) {
        var slots = Math.min(study, open.length), per = []
        for (var i = 0; i < slots; i++) per.push([])
        open.forEach(function (t, k) { per[Math.min(slots - 1, Math.floor(k * slots / open.length))].push(t) })
        var gap = study / slots
        for (var j = 0; j < slots; j++) { var d = Math.min(study - 1, Math.floor(j * gap)); plan.push({ day: d, ms: dayStart(now) + d * 86400000 + 43200000, topics: per[j], review: false }) }
    }
    if (days >= 3) plan.push({ day: days - 1, ms: dayStart(now) + (days - 1) * 86400000 + 43200000, topics: [], review: true })
    return plan.slice(0, maxDays || 8)
}
