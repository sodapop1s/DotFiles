.pragma library

// Two-body orbit maths for the Aero page. SI units (m, s, m^3/s^2) in and out.

// ── bodies ──────────────────────────────────────────────────────────────
// id, name, mu (m^3/s^2), R (m), atmosphere height (m), parent id (null = the system's star), semi-major axis around the parent (m), kind
function body(id, name, mu, R, atmo, parent, sma, color) { return { id: id, name: name, mu: mu, R: R, atmo: atmo, parent: parent, sma: sma, color: color || "sky" } }
// KSP turns "surface gravity in g" into a gravitational parameter with g = 9.81
function muFromGee(gee, R) { return gee * 9.81 * R * R }

var REAL = [
    body("sun",     "Sun",     1.32712440018e20, 695700000, 0, null, 0, "yellow"),
    body("mercury", "Mercury", 2.2032e13,   2439700, 0,      "sun", 5.791e10,    "subtext"),
    body("venus",   "Venus",   3.24859e14,  6051800, 250000, "sun", 1.0821e11,   "peach"),
    body("earth",   "Earth",   3.986004418e14, 6378137, 100000, "sun", 1.495978707e11, "sky"),
    body("moon",    "Moon",    4.9048695e12, 1737400, 0,     "earth", 3.844e8,   "subtext"),
    body("mars",    "Mars",    4.282837e13, 3389500, 80000,  "sun", 2.2794e11,   "red"),
    body("jupiter", "Jupiter", 1.26686534e17, 71492000, 0,   "sun", 7.7857e11,   "yellow"),
    body("saturn",  "Saturn",  3.7931187e16, 60268000, 0,    "sun", 1.43353e12,  "peach"),
    body("uranus",  "Uranus",  5.793939e15, 25559000, 0,     "sun", 2.87246e12,  "teal"),
    body("neptune", "Neptune", 6.836529e15, 24764000, 0,     "sun", 4.49506e12,  "blue")
]
// Kerbal Space Program, stock. The gravitational parameters match the in-game surface gravities (Kerbin 9.81 m/s^2, Jool 7.85, ...).
var KSP = [
    body("kerbol", "Kerbol", 1.1723328e18, 261600000, 0, null, 0, "yellow"),
    body("moho",   "Moho",   1.6860938e11, 250000,  0,     "kerbol", 5263138304,  "subtext"),
    body("eve",    "Eve",    8.1717302e12, 700000,  90000, "kerbol", 9832684544,  "mauve"),
    body("gilly",  "Gilly",  8289449.8,    13000,   0,     "eve",    31500000,    "subtext"),
    body("kerbin", "Kerbin", 3.5316e12,    600000,  70000, "kerbol", 13599840256, "green"),
    body("mun",    "Mun",    6.5138398e10, 200000,  0,     "kerbin", 12000000,    "subtext"),
    body("minmus", "Minmus", 1.7658e9,     60000,   0,     "kerbin", 47000000,    "teal"),
    body("duna",   "Duna",   3.0136321e11, 320000,  50000, "kerbol", 20726155264, "red"),
    body("ike",    "Ike",    1.8568369e10, 130000,  0,     "duna",   3200000,     "subtext"),
    body("dres",   "Dres",   2.1484489e10, 138000,  0,     "kerbol", 40839348203, "subtext"),
    body("jool",   "Jool",   2.82528e14,   6000000, 200000, "kerbol", 68773560320, "green"),
    body("laythe", "Laythe", 1.962e12,     500000,  50000, "jool",   27184000,    "sky"),
    body("vall",   "Vall",   2.074815e11,  300000,  0,     "jool",   43152000,    "teal"),
    body("tylo",   "Tylo",   2.82528e12,   600000,  0,     "jool",   68500000,    "subtext"),
    body("bop",    "Bop",    2.4868349e9,  65000,   0,     "jool",   128500000,   "mauve"),
    body("pol",    "Pol",    7.2170208e8,  44000,   0,     "jool",   179890000,   "yellow"),
    body("eeloo",  "Eeloo",  7.4410815e10, 210000,  0,     "kerbol", 90118820000, "subtext")
]
// Outer Planets Mod (Poodmund): values taken from its own Kopernicus configs (radius, geeASL, orbit, atmosphere). Eeloo is moved to orbit Sarnus.
function opm(id, name, R, gee, parent, sma, atmo, color) { return body(id, name, muFromGee(gee, R), R, atmo, parent, sma, color) }
var OPM = [
    opm("sarnus", "Sarnus", 5300000, 0.298, "kerbol", 125798522368, 580000, "peach"),
    opm("hale",   "Hale",   6000,    0.0023, "sarnus", 10488231, 0, "subtext"),
    opm("ovok",   "Ovok",   26000,   0.002,  "sarnus", 12169413, 0, "subtext"),
    body("eeloo", "Eeloo",  7.4410815e10, 210000, 0, "sarnus", 19105978, "subtext"),
    opm("slate",  "Slate",  540000,  0.692,  "sarnus", 42592946, 0, "teal"),
    opm("tekto",  "Tekto",  280000,  0.2503, "sarnus", 97355304, 95000, "yellow"),
    opm("urlum",  "Urlum",  2177000, 0.257,  "kerbol", 254317012787, 325000, "sky"),
    opm("polta",  "Polta",  220000,  0.19,   "urlum",  11727895, 0, "subtext"),
    opm("priax",  "Priax",  74000,   0.063,  "urlum",  11727895, 0, "subtext"),
    opm("wal",    "Wal",    370000,  0.37,   "urlum",  67553668, 0, "mauve"),
    opm("tal",    "Tal",    22000,   0.045,  "wal",    3109163, 0, "subtext"),
    opm("neidon", "Neidon", 2145000, 0.314,  "kerbol", 409355191706, 260000, "blue"),
    opm("thatmo", "Thatmo", 286000,  0.232,  "neidon", 32300895, 35000, "sky"),
    opm("nissee", "Nissee", 30000,   0.045,  "neidon", 487743514, 0, "subtext"),
    opm("plock",  "Plock",  189000,  0.148,  "kerbol", 535833706086, 0, "red"),
    opm("karen",  "Karen",  85050,   0.066,  "plock",  2457800, 0, "subtext")
]
var OPM_IDS = {}; OPM.forEach(function (b) { OPM_IDS[b.id] = 1 })
var SYSTEMS = [
    { id: "real", name: "Real", bodies: REAL },
    { id: "ksp",  name: "KSP",  bodies: KSP },
    { id: "opm",  name: "KSP + Outer Planets", bodies: KSP.filter(function (b) { return !OPM_IDS[b.id] }).concat(OPM) }
]
var BODIES = REAL       // older name

function findBody(system, id) { var list = system.bodies, i; for (i = 0; i < list.length; i++) if (list[i].id === id) return list[i]; return null }
function parentOf(system, b) { return b && b.parent ? findBody(system, b.parent) : null }
function moonsOf(system, b) { return system.bodies.filter(function (x) { return x.parent === b.id }) }
function planetsOf(system) { return system.bodies.filter(function (x) { return x.parent && !parentOf(system, x).parent }) }
// sphere of influence radius, the same formula KSP uses
function soi(system, b) { var p = parentOf(system, b); return p ? b.sma * Math.pow(b.mu / p.mu, 0.4) : Infinity }
// a sensible default "low orbit" for a body: just above the atmosphere, or 10% of the radius over bare rock
function lowAlt(b) { return b.atmo > 0 ? b.atmo + 10000 : Math.max(5000, Math.round(b.R * 0.1 / 5000) * 5000) }

function circularSpeed(mu, r) { return Math.sqrt(mu / r) }
function escapeSpeed(mu, r) { return Math.sqrt(2 * mu / r) }
function period(mu, a) { return 2 * Math.PI * Math.sqrt(a * a * a / mu) }

// Hohmann transfer between circular, coplanar orbits of radius r1 -> r2 (measured from the body's centre).
// dInc (radians) is a plane change done at the same time as the burn at the higher orbit, where it is cheapest.
function hohmann(mu, r1, r2, dInc) {
    var a = (r1 + r2) / 2
    var v1 = circularSpeed(mu, r1), v2 = circularSpeed(mu, r2)
    var vp = Math.sqrt(mu * (2 / r1 - 1 / a)), va = Math.sqrt(mu * (2 / r2 - 1 / a))
    var dv1 = Math.abs(vp - v1)
    var dv2flat = Math.abs(v2 - va)
    var inc = dInc || 0
    // combined burn at the far end: |vector difference| of two speeds that differ by an angle
    var dv2 = inc === 0 ? dv2flat : Math.sqrt(va * va + v2 * v2 - 2 * va * v2 * Math.cos(inc))
    var rp = Math.min(r1, r2), ra = Math.max(r1, r2)
    var tof = Math.PI * Math.sqrt(a * a * a / mu)
    // phase angle between chaser and target at departure, for a target on the outer/inner orbit (degrees, positive = target ahead)
    var n2 = Math.sqrt(mu / (r2 * r2 * r2))
    var phase = (Math.PI - n2 * tof) * 180 / Math.PI
    return { a: a, e: (ra - rp) / (ra + rp), v1: v1, v2: v2, vPeri: vp, vApo: va, dv1: dv1, dv2: dv2, dv: dv1 + dv2, tof: tof,
             t1: period(mu, r1), t2: period(mu, r2), tTransfer: period(mu, a), phase: phase, rp: rp, ra: ra, up: r2 > r1 }
}

// Bi-elliptic transfer through an intermediate apoapsis rb (needs rb >= r2): usually cheaper only when r2/r1 > 11.94
function biElliptic(mu, r1, r2, rb) {
    var a1 = (r1 + rb) / 2, a2 = (r2 + rb) / 2
    var v1 = circularSpeed(mu, r1), v2 = circularSpeed(mu, r2)
    var dv1 = Math.sqrt(mu * (2 / r1 - 1 / a1)) - v1
    var dv2 = Math.sqrt(mu * (2 / rb - 1 / a2)) - Math.sqrt(mu * (2 / rb - 1 / a1))
    var dv3 = Math.abs(Math.sqrt(mu * (2 / r2 - 1 / a2)) - v2)
    var tof = Math.PI * (Math.sqrt(a1 * a1 * a1 / mu) + Math.sqrt(a2 * a2 * a2 / mu))
    return { dv1: Math.abs(dv1), dv2: Math.abs(dv2), dv3: dv3, dv: Math.abs(dv1) + Math.abs(dv2) + dv3, tof: tof }
}

// pretty numbers
function km(m) { var k = m / 1000; return k >= 100 ? String(Math.round(k)) : k.toFixed(1) }
function dur(s) {
    if (s < 120) return s.toFixed(0) + " s"
    if (s < 7200) return (s / 60).toFixed(1) + " min"
    if (s < 172800) return (s / 3600).toFixed(2) + " h"
    return (s / 86400).toFixed(2) + " days"
}
function speed(v) { return v >= 1000 ? (v / 1000).toFixed(3) + " km/s" : v.toFixed(1) + " m/s" }


// ── planning between bodies ─────────────────────────────────────────────
// Leave a circular parking orbit (radius rA around body A) for body B, both planets of the same star, using Hohmann transfer between their orbits.
// Ideal: circular, coplanar orbits. Returns the burn out of orbit A, the burn into orbit B (or 0 when B has an atmosphere and you aerobrake), time and phase angle.
function planetHop(star, A, rA, B, rB) {
    var muS = star.mu, a1 = A.sma, a2 = B.sma, at = (a1 + a2) / 2
    var v1 = Math.sqrt(muS / a1), v2 = Math.sqrt(muS / a2)
    var vt1 = Math.sqrt(muS * (2 / a1 - 1 / at)), vt2 = Math.sqrt(muS * (2 / a2 - 1 / at))
    var vinf1 = Math.abs(vt1 - v1), vinf2 = Math.abs(v2 - vt2)
    var depart = Math.sqrt(vinf1 * vinf1 + 2 * A.mu / rA) - Math.sqrt(A.mu / rA)
    var arrive = Math.sqrt(vinf2 * vinf2 + 2 * B.mu / rB) - Math.sqrt(B.mu / rB)
    var tof = Math.PI * Math.sqrt(at * at * at / muS)
    var T1 = period(muS, a1), T2 = period(muS, a2)
    var phase = 180 - 360 * tof / T2
    phase = ((phase + 180) % 360 + 360) % 360 - 180
    return { depart: depart, arrive: arrive, vinf1: vinf1, vinf2: vinf2, tof: tof, phase: phase, synodic: 1 / Math.abs(1 / T1 - 1 / T2), up: a2 > a1 }
}
// From a parking orbit (rA) around planet A to a circular orbit (rM) around one of its moons M.
function moonHop(A, rA, M, rM) {
    var a1 = rA, a2 = M.sma, at = (a1 + a2) / 2
    var v1 = Math.sqrt(A.mu / a1), vM = Math.sqrt(A.mu / a2)
    var vt1 = Math.sqrt(A.mu * (2 / a1 - 1 / at)), vt2 = Math.sqrt(A.mu * (2 / a2 - 1 / at))
    var depart = Math.abs(vt1 - v1)
    var vinf2 = Math.abs(vM - vt2)
    var arrive = Math.sqrt(vinf2 * vinf2 + 2 * M.mu / rM) - Math.sqrt(M.mu / rM)
    var tof = Math.PI * Math.sqrt(at * at * at / A.mu)
    var phase = 180 - 360 * tof / period(A.mu, a2)
    phase = ((phase + 180) % 360 + 360) % 360 - 180
    return { depart: depart, arrive: arrive, vinf2: vinf2, tof: tof, phase: phase, synodic: 0 }
}
// every destination reachable from planet A's parking orbit: the other planets of its star, and A's own moons
function deltaVTable(system, A, parkAlt, aerobrake) {
    var star = parentOf(system, A), rows = [], rA = A.R + parkAlt
    if (!star) return rows
    system.bodies.forEach(function (B) {
        if (B.id === A.id) return
        var rB = B.R + lowAlt(B)
        if (B.parent === A.id) {
            var m = moonHop(A, rA, B, rB), aero = false
            rows.push({ id: B.id, name: B.name, kind: "moon", depart: m.depart, arrive: m.arrive, aero: aero, tof: m.tof, phase: m.phase, rB: rB })
        } else if (B.parent === A.parent && !(star.parent)) {
            var h = planetHop(star, A, rA, B, rB), canAero = B.atmo > 0 && aerobrake
            rows.push({ id: B.id, name: B.name, kind: "planet", depart: h.depart, arrive: canAero ? 0 : h.arrive, arriveFull: h.arrive, aero: canAero, tof: h.tof, phase: h.phase, synodic: h.synodic, rB: rB })
        }
    })
    rows.forEach(function (r) { r.total = r.depart + r.arrive })
    rows.sort(function (a, b) { return a.kind === b.kind ? a.total - b.total : (a.kind === "moon" ? -1 : 1) })
    return rows
}
