.pragma library

// Grade maths for the School tab, working on what canvas.sh groups returns:
//   { weighted, groups: [{ name, weight, items: [{ name, points, score, graded, excused }] }] }
// "Graded" items count toward what you have now; the others are still to come.

function prep(data) {
    var groups = data.groups.map(function (g) {
        var earned = 0, possible = 0, pending = 0, pendingItems = []
        g.items.forEach(function (it, i) {
            if (it.excused || !(it.points > 0)) return
            if (it.graded) { earned += it.score; possible += it.points }
            else { pending += it.points; pendingItems.push({ name: it.name, points: it.points, index: i }) }
        })
        return { name: g.name, weight: g.weight || 0, earned: earned, possible: possible, pending: pending, pendingItems: pendingItems,
                 pct: possible > 0 ? 100 * earned / possible : null }
    })
    return groups
}

// the course percentage if every pending item scored `pctOf(item)` percent
function composite(data, groups, pctOf) {
    if (data.weighted) {
        var sum = 0, wsum = 0
        groups.forEach(function (g) {
            var total = g.possible + g.pending
            if (total <= 0) return
            var earned = g.earned
            g.pendingItems.forEach(function (it) { earned += it.points * pctOf(g, it) / 100 })
            sum += g.weight * (100 * earned / total)
            wsum += g.weight
        })
        return wsum > 0 ? sum / wsum : null
    }
    var e = 0, t = 0
    groups.forEach(function (g) {
        e += g.earned; t += g.possible + g.pending
        g.pendingItems.forEach(function (it) { e += it.points * pctOf(g, it) / 100 })
    })
    return t > 0 ? 100 * e / t : null
}

// what the course stands at right now, counting only graded work
function current(data) {
    var groups = prep(data)
    if (data.weighted) {
        var sum = 0, wsum = 0
        groups.forEach(function (g) { if (g.pct !== null) { sum += g.weight * g.pct; wsum += g.weight } })
        return wsum > 0 ? sum / wsum : null
    }
    var e = 0, p = 0
    groups.forEach(function (g) { e += g.earned; p += g.possible })
    return p > 0 ? 100 * e / p : null
}

// Percent you need on ALL remaining work to finish on `target`.
function neededOnRest(data, target) {
    var groups = prep(data)
    var any = groups.some(function (g) { return g.pending > 0 })
    if (!any) return { none: true }
    var lo = composite(data, groups, function () { return 0 }), hi = composite(data, groups, function () { return 100 })
    if (lo === null || hi === null || hi === lo) return { none: true }
    var x = (target - lo) / (hi - lo) * 100
    return { pct: x, secure: x <= 0, impossible: x > 100, best: hi, worst: lo }
}

// Percent you need on ONE pending item (group g, item idx) if everything else still pending scores `assume` percent.
function neededOnItem(data, gi, name, target, assume) {
    var groups = prep(data), g = groups[gi]
    if (!g) return { none: true }
    var item = g.pendingItems.find(function (it) { return it.name === name })
    if (!item) return { none: true }
    var f = function (y) { return composite(data, groups, function (gg, it) { return (gg === g && it === item) ? y : assume }) }
    var lo = f(0), hi = f(100)
    if (lo === null || hi === lo) return { none: true }
    var x = (target - lo) / (hi - lo) * 100
    return { pct: x, points: x / 100 * item.points, secure: x <= 0, impossible: x > 100, outOf: item.points }
}

function letter(p) {
    if (p === null || p === undefined) return "–"
    return p >= 93 ? "A" : p >= 90 ? "A-" : p >= 87 ? "B+" : p >= 83 ? "B" : p >= 80 ? "B-" : p >= 77 ? "C+" : p >= 73 ? "C" : p >= 70 ? "C-" : p >= 60 ? "D" : "F"
}
function pendingList(data) {
    var out = []
    prep(data).forEach(function (g, gi) { g.pendingItems.forEach(function (it) { out.push({ group: gi, groupName: g.name, name: it.name, points: it.points }) }) })
    return out
}
