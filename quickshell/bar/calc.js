.pragma library

// A calculator that reads LaTeX maths. No dependencies; used by the launcher (type "= ..." or anything with a \command).
//
//   Calc.run("\\frac{1}{2} + \\sqrt{9}")            -> { kind: "value", text: "3.5", ... }
//   Calc.run("\\sum_{k=1}^{10} k^2")                -> 385
//   Calc.run("\\int_0^\\pi \\sin x \\, dx")         -> 2
//   Calc.run("\\lim_{x \\to 0} \\frac{\\sin x}{x}")  -> 1
//   Calc.run("\\frac{d}{dx} x^3 |_{x=2}")           -> not supported; use  f(x)=x^3; \\frac{d}{dx} f(x)  with x set:  x=2; \\frac{d}{dx} x^3
//   Calc.run("a=3; f(x)=a x^2; f(2)")               -> 12      (statements are separated by ; )
//   Calc.run("y = \\sin x; y = \\cos x")            -> a graph of both (kind "plot")
//   Calc.run("x^2 - 2 = 0")                         -> roots   (kind "solve", also plotted)
//   Calc.run("\\sqrt{-4} + e^{i\\pi}")              -> complex numbers work:  -1 + 2i
//
// Supported: + - * / ^ ! | | ( ) [ ] { }, implicit multiplication (2x, 3\sin x, xy), \frac \dfrac \sqrt[n]{}
// \sum \prod \int (finite and infinite bounds) \lim \frac{d}{dx} \binom, \sin \cos \tan \sec \csc \cot (and arc*, *h),
// \ln \log \log_b \exp \abs \min \max \gcd \lcm \floor \ceil \lfloor \rfloor \lceil \rceil \round \sign \Re \Im \arg \conj,
// constants \pi \tau \phi e i \infty, variables like x, x_1, \theta, user functions f(x)=..., \mod, \%.
//
// Units: a number followed by a unit is a physical quantity.   9.81 m/s^2 * 3 s  ->  29.43 m/s
//   r = 6778 km; \sqrt{\mu_E / r}  ->  7.6686 km/s     60 mph in m/s     5 kg * 9.81 m/s^2  ->  49.05 N
// Convert with "in" or "to".  Adding metres to seconds is an error, as it should be.
// Constants (names with an underscore, so they never clash with your own letters): g_0, mu_E, R_E, M_E, mu_M, R_M, mu_S,
//   mu_Ma, R_Ma, mu_J, mu_K, R_K, c_0, G, k_B, N_A, R_u, sigma_SB, h_P, q_e, rho_0, p_0, T_0, a_0, R_air.

// ───────────────────────── complex numbers ─────────────────────────
function C(re, im) { return { re: re, im: im } }
function isC(v) { return typeof v === "object" && v.q !== true }
function reOf(v) { return isC(v) ? v.re : v }
function imOf(v) { return isC(v) ? v.im : 0 }
function tidy(v) {
    if (!isC(v)) return v
    if (Math.abs(v.im) <= 1e-12 * Math.max(1, Math.abs(v.re))) return v.re
    return v
}
function add(a, b) { if (isQ(a) || isQ(b)) return qadd(a, b, 1); return (isC(a) || isC(b)) ? tidy(C(reOf(a) + reOf(b), imOf(a) + imOf(b))) : a + b }
function sub(a, b) { if (isQ(a) || isQ(b)) return qadd(a, b, -1); return (isC(a) || isC(b)) ? tidy(C(reOf(a) - reOf(b), imOf(a) - imOf(b))) : a - b }
function mul(a, b) {
    if (isQ(a) || isQ(b)) return qmul(a, b, 1)
    if (!isC(a) && !isC(b)) return a * b
    return tidy(C(reOf(a) * reOf(b) - imOf(a) * imOf(b), reOf(a) * imOf(b) + imOf(a) * reOf(b)))
}
function div(a, b) {
    if (isQ(a) || isQ(b)) return qmul(a, b, -1)
    if (!isC(a) && !isC(b)) return a / b
    var d = reOf(b) * reOf(b) + imOf(b) * imOf(b)
    return tidy(C((reOf(a) * reOf(b) + imOf(a) * imOf(b)) / d, (imOf(a) * reOf(b) - reOf(a) * imOf(b)) / d))
}
function neg(a) { return isQ(a) ? Qty(-a.v, a.d) : isC(a) ? C(-a.re, -a.im) : -a }
function cabs(a) { return isQ(a) ? Math.abs(a.v) : isC(a) ? Math.hypot(a.re, a.im) : Math.abs(a) }
function carg(a) { return Math.atan2(imOf(a), reOf(a)) }
function cexp(a) { return isC(a) ? tidy(C(Math.exp(a.re) * Math.cos(a.im), Math.exp(a.re) * Math.sin(a.im))) : Math.exp(a) }
function cln(a) {
    if (!isC(a) && a > 0) return Math.log(a)
    if (reOf(a) === 0 && imOf(a) === 0) return -Infinity
    return tidy(C(Math.log(cabs(a)), carg(a)))
}
function csqrt(a) {
    if (!isC(a) && a >= 0) return Math.sqrt(a)
    if (!isC(a)) return C(0, Math.sqrt(-a))
    var r = cabs(a), t = carg(a) / 2
    return tidy(C(Math.sqrt(r) * Math.cos(t), Math.sqrt(r) * Math.sin(t)))
}
function pow(a, b) {
    if (isQ(a) || isQ(b)) {
        if (isQ(b) || isC(b)) throw new Error("an exponent must be a plain number")
        if (isC(a)) throw new Error("complex numbers cannot carry units")
        return qnorm(Qty(Math.pow(a.v, b), a.d.map(function (x) { return x * b })))
    }
    if (!isC(a) && !isC(b)) {
        if (a >= 0 || Number.isInteger(b)) return Math.pow(a, b)
        // negative base, fractional exponent: odd roots stay real (cube root of -8 is -2)
        var inv = 1 / b
        if (Number.isInteger(Math.round(inv)) && Math.abs(inv - Math.round(inv)) < 1e-12 && Math.round(inv) % 2 !== 0) return -Math.pow(-a, b)
    }
    if (reOf(a) === 0 && imOf(a) === 0) return (reOf(b) === 0 && imOf(b) === 0) ? 1 : 0
    return cexp(mul(b, cln(a)))
}
function csin(a) { return isC(a) ? tidy(C(Math.sin(a.re) * Math.cosh(a.im), Math.cos(a.re) * Math.sinh(a.im))) : Math.sin(a) }
function ccos(a) { return isC(a) ? tidy(C(Math.cos(a.re) * Math.cosh(a.im), -Math.sin(a.re) * Math.sinh(a.im))) : Math.cos(a) }

function gamma(x) {
    if (x < 0.5) return Math.PI / (Math.sin(Math.PI * x) * gamma(1 - x))
    x -= 1
    var g = 7, c = [0.99999999999980993, 676.5203681218851, -1259.1392167224028, 771.32342877765313, -176.61502916214059,
                    12.507343278686905, -0.13857109526572012, 9.9843695780195716e-6, 1.5056327351493116e-7]
    var a = c[0], t = x + g + 0.5
    for (var i = 1; i < g + 2; i++) a += c[i] / (x + i)
    return Math.sqrt(2 * Math.PI) * Math.pow(t, x + 0.5) * Math.exp(-t) * a
}
function factorial(n) {
    if (isC(n)) throw new Error("factorial of a complex number")
    if (Number.isInteger(n) && n >= 0) {
        if (n > 170) return Infinity
        var r = 1; for (var i = 2; i <= n; i++) r *= i
        return r
    }
    if (Number.isInteger(n) && n < 0) return NaN
    return gamma(n + 1)
}
function gcd(a, b) { a = Math.abs(a); b = Math.abs(b); while (b) { var t = b; b = a % b; a = t } return a }


// ───────────────────────── physical units ─────────────────────────
// A quantity is { v: value in SI units, d: exponents of [m, kg, s, A, K, mol, cd] }. Plain numbers stay plain numbers, and a
// quantity whose exponents all cancel (10 m / 2 m) turns back into a plain number.
function Qty(v, d) { return { v: v, d: d, q: true } }
function isQ(x) { return typeof x === "object" && x !== null && x.q === true }
function D(m, kg, s, A, K, mol, cd) { return [m || 0, kg || 0, s || 0, A || 0, K || 0, mol || 0, cd || 0] }
function dimless(d) { for (var i = 0; i < 7; i++) if (Math.abs(d[i]) > 1e-9) return false; return true }
function qnorm(x) { return isQ(x) && dimless(x.d) ? x.v : x }
function dimsOf(x) { return isQ(x) ? x.d : D() }
function dimsEq(a, b) { for (var i = 0; i < 7; i++) if (Math.abs(a[i] - b[i]) > 1e-9) return false; return true }
function vOf(x) { return isQ(x) ? x.v : x }
function qadd(a, b, sign) {
    if (isC(a) || isC(b)) throw new Error("complex numbers cannot carry units")
    if (!dimsEq(dimsOf(a), dimsOf(b))) throw new Error("cannot " + (sign > 0 ? "add " : "subtract ") + dimName(dimsOf(b)) + (sign > 0 ? " to " : " from ") + dimName(dimsOf(a)))
    return qnorm(Qty(vOf(a) + sign * vOf(b), dimsOf(a)))
}
function qmul(a, b, sign) {
    if (isC(a) || isC(b)) throw new Error("complex numbers cannot carry units")
    var da = dimsOf(a), db = dimsOf(b), d = []
    for (var i = 0; i < 7; i++) d.push(da[i] + sign * db[i])
    return qnorm(Qty(sign > 0 ? vOf(a) * vOf(b) : vOf(a) / vOf(b), d))
}

var L1 = D(1), M1 = D(0, 1), T1 = D(0, 0, 1), V1 = D(1, 0, -1), A1 = D(1, 0, -2)
var F1 = D(1, 1, -2), E1 = D(2, 1, -2), P1 = D(2, 1, -3), PR1 = D(-1, 1, -2), HZ1 = D(0, 0, -1)
var UNITS = {
    m: [1, L1, 1], g: [1e-3, M1, 1], s: [1, T1, 1], A: [1, D(0, 0, 0, 1), 1], K: [1, D(0, 0, 0, 0, 1)], mol: [1, D(0, 0, 0, 0, 0, 1), 1], cd: [1, D(0, 0, 0, 0, 0, 0, 1)],
    N: [1, F1, 1], J: [1, E1, 1], W: [1, P1, 1], Pa: [1, PR1, 1], Hz: [1, HZ1, 1], C: [1, D(0, 0, 1, 1), 1], V: [1, D(2, 1, -3, -1), 1],
    F: [1, D(-2, -1, 4, 2), 1], "Ω": [1, D(2, 1, -3, -2), 1], ohm: [1, D(2, 1, -3, -2), 1], T: [1, D(0, 1, -2, -1), 1], H: [1, D(2, 1, -2, -2), 1], Wb: [1, D(2, 1, -2, -1), 1],
    L: [1e-3, D(3), 1], min: [60, T1], h: [3600, T1], hr: [3600, T1], day: [86400, T1], week: [604800, T1], yr: [31557600, T1],
    ft: [0.3048, L1], yd: [0.9144, L1], inch: [0.0254, L1], mi: [1609.344, L1], nmi: [1852, L1],
    lb: [0.45359237, M1], lbm: [0.45359237, M1], oz: [0.028349523125, M1], slug: [14.59390294, M1], tonne: [1000, M1],
    lbf: [4.4482216152605, F1], kip: [4448.2216152605, F1], mph: [0.44704, V1], kn: [0.5144444444, V1], kt: [0.5144444444, V1], fps: [0.3048, V1],
    deg: [Math.PI / 180, D()], rad: [1, D()], rpm: [Math.PI / 30, HZ1],
    atm: [101325, PR1], bar: [1e5, PR1, 1], psi: [6894.757293168, PR1], cal: [4.184, E1, 1], eV: [1.602176634e-19, E1, 1], Wh: [3600, E1, 1], hp: [745.69987158, P1],
    AU: [1.495978707e11, L1], ly: [9.4607304725808e15, L1], pc: [3.0856775814913673e16, L1]
}
var PREFIXES = { n: 1e-9, u: 1e-6, "µ": 1e-6, m: 1e-3, c: 1e-2, k: 1e3, M: 1e6, G: 1e9, T: 1e12 }
var SINGLE_UNITS = { m: 1, s: 1, g: 1, A: 1, K: 1, N: 1, J: 1, W: 1, V: 1, C: 1, F: 1, H: 1, T: 1, L: 1, h: 1 }
function resolveUnit(sym) {
    var u = UNITS[sym]
    if (u) return { s: u[0], d: u[1] }
    var p = PREFIXES[sym[0]]
    if (p !== undefined && sym.length > 1) {
        var base = UNITS[sym.slice(1)]
        if (base && base[2] && (sym[0] !== "c" || sym.slice(1) === "m")) return { s: p * base[0], d: base[1] }
    }
    return null
}
var SUP = { "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹", "-": "⁻", ".": "·" }
function sup(n) { return String(n).split("").map(function (c) { return SUP[c] || c }).join("") }
var DERIVED = [["N", F1], ["J", E1], ["W", P1], ["Pa", PR1], ["Hz", HZ1], ["V", D(2, 1, -3, -1)], ["C", D(0, 0, 1, 1)], ["F", D(-2, -1, 4, 2)], ["Ω", D(2, 1, -3, -2)], ["T", D(0, 1, -2, -1)], ["H", D(2, 1, -2, -2)], ["Wb", D(2, 1, -2, -1)]]
var BASE_SYMS = ["m", "kg", "s", "A", "K", "mol", "cd"]
var DERIVED2 = [["W/m²", D(0, 1, -3)], ["kg/m³", D(-3, 1)], ["J/kg", D(2, 0, -2)], ["J/(kg·K)", D(2, 0, -2, 0, -1)], ["J/K", D(2, 1, -2, 0, -1)], ["Pa·s", D(-1, 1, -1)], ["N/m", D(0, 1, -2)], ["N·s", D(1, 1, -1)], ["m³/s²", D(3, 0, -2)], ["rad/s", HZ1]]
function dimLabel(d) {
    for (var i = 0; i < DERIVED.length; i++) if (dimsEq(d, DERIVED[i][1])) return DERIVED[i][0]
    for (var i2 = 0; i2 < DERIVED2.length; i2++) if (dimsEq(d, DERIVED2[i2][1]) && DERIVED2[i2][0] !== "rad/s") return DERIVED2[i2][0]
    var up = [], down = []
    for (var j = 0; j < 7; j++) {
        var e = Math.round(d[j] * 100) / 100
        if (e > 0) up.push(BASE_SYMS[j] + (e === 1 ? "" : sup(e)))
        else if (e < 0) down.push(BASE_SYMS[j] + (e === -1 ? "" : sup(-e)))
    }
    if (!up.length && !down.length) return ""
    if (!down.length) return up.join("·")
    if (!up.length) return down.length === 1 ? down[0].replace(/^(\w+)$/, "$1⁻¹").replace(/^(\w+)(.+)$/, function (m, a, b) { return m.indexOf("⁻¹") >= 0 ? m : a + "⁻" + b.replace(/[⁻]/g, "") }) : down.map(function (x) { return x + "⁻¹" }).join("·")
    return up.join("·") + "/" + down.join("·")
}
function dimName(d) { var l = dimLabel(d); return l === "" ? "a plain number" : l }

// a few friendly names for the "also" line
var KINDS = [["length", L1], ["mass", M1], ["time", T1], ["velocity", V1], ["acceleration", A1], ["force", F1], ["pressure", PR1], ["energy", E1], ["power", P1]]
function kindOf(d) { for (var i = 0; i < KINDS.length; i++) if (dimsEq(d, KINDS[i][1])) return KINDS[i][0]; return "" }

function num(v) { return fmtReal(Number(v.toPrecision(8))) }
function fmtQ(x) {
    var v = x.v, lab = dimLabel(x.d), k = kindOf(x.d), a = Math.abs(v)
    var scaled = function (list) { for (var i = 0; i < list.length; i++) if (a >= list[i][1] * 0.9999999) return num(v / list[i][1]) + " " + list[i][0]; var l = list[list.length - 1]; return num(v / l[1]) + " " + l[0] }
    if (a === 0) return "0 " + lab
    if (k === "length") return scaled([["km", 1e3], ["m", 1], ["mm", 1e-3], ["µm", 1e-6], ["nm", 1e-9]])
    if (k === "time") return scaled([["s", 1], ["ms", 1e-3], ["µs", 1e-6], ["ns", 1e-9]])
    if (k === "mass") return scaled([["kg", 1], ["g", 1e-3], ["mg", 1e-6]])
    if (k === "velocity") return scaled([["km/s", 1e3], ["m/s", 1], ["mm/s", 1e-3]])
    if (lab === "N" || lab === "J" || lab === "W" || lab === "Pa" || lab === "Hz" || lab === "V" || lab === "C" || lab === "F" || lab === "Ω" || lab === "H" || lab === "T")
        return scaled([["G" + lab, 1e9], ["M" + lab, 1e6], ["k" + lab, 1e3], [lab, 1], ["m" + lab, 1e-3], ["µ" + lab, 1e-6]])
    return num(v) + " " + lab
}
function qAlts(x) {
    var v = x.v, k = kindOf(x.d), a = Math.abs(v), out = []
    if (k === "velocity") { if (a >= 1000) out.push(num(v) + " m/s"); out.push(num(v * 3.6) + " km/h"); out.push(num(v / 0.44704) + " mph") }
    else if (k === "length") { if (a >= 1609.344) out.push(num(v / 1609.344) + " mi"); else out.push(num(v / 0.3048) + " ft"); if (a >= 1.5e9) out.push(num(v / 1.495978707e11) + " AU") }
    else if (k === "mass") out.push(num(v / 0.45359237) + " lb")
    else if (k === "force") out.push(num(v / 4.4482216152605) + " lbf")
    else if (k === "acceleration") out.push(num(v / 9.80665) + " g")
    else if (k === "pressure") { out.push(num(v / 101325) + " atm"); out.push(num(v / 6894.757293168) + " psi") }
    else if (k === "energy") { if (a >= 3.6e3) out.push(num(v / 3.6e6) + " kWh") }
    else if (k === "power") out.push(num(v / 745.69987158) + " hp")
    else if (k === "time" && a >= 120) out.push(a >= 172800 ? num(v / 86400) + " days" : a >= 7200 ? num(v / 3600) + " h" : num(v / 60) + " min")
    return out.join("  ·  ")
}
function constQ(name) { var c = CONSTANTS[name]; return qnorm(Qty(c[0], c[1])) }
var CONSTANTS = {
    g_0: [9.80665, A1], c_0: [299792458, V1], G: [6.6743e-11, D(3, -1, -2)], k_B: [1.380649e-23, D(2, 1, -2, 0, -1)], N_A: [6.02214076e23, D(0, 0, 0, 0, 0, -1)],
    R_u: [8.314462618, D(2, 1, -2, 0, -1, -1)], sigma_SB: [5.670374419e-8, D(0, 1, -3, 0, -4)], h_P: [6.62607015e-34, D(2, 1, -1)], q_e: [1.602176634e-19, D(0, 0, 1, 1)],
    epsilon_0: [8.8541878128e-12, D(-3, -1, 4, 2)], mu_0: [1.25663706212e-6, D(1, 1, -2, -2)],
    mu_E: [3.986004418e14, D(3, 0, -2)], R_E: [6378137, L1], M_E: [5.972168e24, M1], mu_M: [4.9048695e12, D(3, 0, -2)], R_M: [1737400, L1], M_M: [7.346e22, M1],
    mu_S: [1.32712440018e20, D(3, 0, -2)], R_S: [695700000, L1], M_S: [1.98847e30, M1], mu_Ma: [4.282837e13, D(3, 0, -2)], R_Ma: [3389500, L1],
    mu_J: [1.26686534e17, D(3, 0, -2)], R_J: [71492000, L1], mu_K: [3.5316e12, D(3, 0, -2)], R_K: [600000, L1],
    rho_0: [1.225, D(-3, 1)], p_0: [101325, PR1], T_0: [288.15, D(0, 0, 0, 0, 1)], a_0: [340.294, V1], R_air: [287.05, D(2, 0, -2, 0, -1)]
}
function showUnit(n) {
    switch (n.k) {
    case "unit": return n.n
    case "num": return String(n.v)
    case "paren": return "(" + showUnit(n.a) + ")"
    case "bin": return showUnit(n.a) + (n.op === "*" ? "·" : n.op) + showUnit(n.b)
    }
    return "?"
}

// ───────────────────────── lexer ─────────────────────────
var WORDS = ["arcsin", "arccos", "arctan", "sinh", "cosh", "tanh", "sin", "cos", "tan", "sec", "csc", "cot", "ln", "log", "exp", "sqrt", "abs",
             "min", "max", "gcd", "lcm", "floor", "ceil", "round", "sign", "pi"]
var GREEK = { alpha: 1, beta: 1, gamma: 1, delta: 1, epsilon: 1, zeta: 1, eta: 1, theta: 1, iota: 1, kappa: 1, lambda: 1, mu: 1, nu: 1, xi: 1, rho: 1,
              sigma: 1, upsilon: 1, chi: 1, psi: 1, omega: 1, varphi: 1, varepsilon: 1, vartheta: 1 }
var SKIP_CMDS = { ",": 1, ";": 1, ":": 1, "!": 1, " ": 1, quad: 1, qquad: 1, displaystyle: 1, textstyle: 1, limits: 1, nolimits: 1, big: 1, Big: 1, bigg: 1, Bigg: 1 }

function lex(src, inUnit) {
    var t = [], i = 0, n = src.length
    var qty = !!inUnit                     // the last thing was a number or a unit, so a letter that is a unit symbol is one
    function push(type, v, extra) {
        var o = { t: type, v: v, pos: i }; if (extra) for (var k in extra) o[k] = extra[k]; t.push(o)
        if (type === "num" || type === "unit" || type === "conv") qty = true
        else if ((type === "sym" && (v === "/" || v === "*" || v === "^")) || (type === "cmd" && (v === "cdot" || v === "times"))) { /* keeps the state */ }
        else qty = false
    }
    function braced(from) {              // raw text of {...} starting at index `from` (which is '{'); returns [text, indexAfter]
        var d = 0, j = from
        for (; j < n; j++) { if (src[j] === "{") d++; else if (src[j] === "}") { d--; if (d === 0) break } }
        if (d !== 0) throw new Error("missing }")
        return [src.slice(from + 1, j), j + 1]
    }
    function subscript() {                // after a letter: _1  _{12}  _n  -> "_1"; "" when there is none
        if (src[i] !== "_") return ""
        i++
        if (src[i] === "{") { var b = braced(i); i = b[1]; return "_" + b[0].replace(/\s+/g, "") }
        var m = /^(\d+|[A-Za-z])/.exec(src.slice(i)); if (!m) throw new Error("bad subscript"); i += m[1].length
        return "_" + m[1]
    }
    var sortedWords = WORDS.slice().sort(function (a, b) { return b.length - a.length })
    while (i < n) {
        var ch = src[i]
        if (/\s/.test(ch) || ch === "~") { i++; continue }
        if (/\d/.test(ch) || (ch === "." && /\d/.test(src[i + 1] || ""))) {
            var m = /^(\d+\.?\d*|\.\d+)/.exec(src.slice(i))
            push("num", parseFloat(m[1])); i += m[1].length; continue
        }
        if (ch === "\\") {
            var m2 = /^\\([A-Za-z]+)/.exec(src.slice(i))
            if (!m2) {                       // \, \; \! \  \{ \}
                var c2 = src[i + 1] || ""
                if (c2 === "{" || c2 === "}") { push("sym", c2); i += 2; continue }
                if (c2 === "%") { push("cmd", "percent"); i += 2; continue }
                if (c2 === "|") { push("sym", "|"); i += 2; continue }
                if (c2 in SKIP_CMDS || c2 === " ") { i += 2; continue }
                throw new Error("unknown command \\" + c2)
            }
            var name = m2[1]; i += m2[0].length
            if (name in SKIP_CMDS) continue
            if (name === "left" || name === "right") {
                var d = src[i]
                if (d === "." ) { i++; continue }
                if (d === "(" || d === ")" || d === "[" || d === "]" || d === "|") { push("sym", d); i++; continue }
                continue
            }
            if (name === "mathrm" || name === "text" || name === "mathit" || name === "operatorname" || name === "mathbf" || name === "unit") {
                if (src[i] === "{") {
                    var b = braced(i); i = b[1]
                    if (name === "operatorname") { push("cmd", b[0].replace(/\s+/g, "")); continue }
                    var inner = lex(b[0], true)           // \mathrm{m/s^2}: every letter group is read as a unit when it can be
                    inner.pop()
                    inner.forEach(function (tk) { push(tk.t, tk.v) })
                    continue
                }
                continue
            }
            if (name in GREEK) { push("id", name + subscript()); continue }
            push("cmd", name); continue
        }
        if (/[A-Za-zµΩ]/.test(ch)) {
            var rest = src.slice(i)
            var run = /^[A-Za-zµΩ]+/.exec(rest)[0]
            // a named constant typed without braces: R_air, sigma_SB, mu_Ma, g_0
            if (src[i + run.length] === "_") {
                var sm = /^_([A-Za-z0-9]+)/.exec(rest.slice(run.length))
                var hit = false
                if (sm) for (var L = sm[1].length; L >= 1 && !hit; L--) {
                    var cand = run + "_" + sm[1].slice(0, L)
                    if (cand in CONSTANTS) { push("id", cand); i += run.length + 1 + L; hit = true }
                }
                if (hit) continue
            }
            // "10 mi in km" / "60 mph to m/s"
            if (qty && (run === "in" || run === "to") && /^\s+[A-Za-z\\µΩ(0-9]/.test(rest.slice(run.length))) { push("conv", run); i += run.length; continue }
            // plain function words (sin, cos, ...) without a backslash; "min" is minutes right after a number
            var word2 = null
            for (var w = 0; w < sortedWords.length; w++) if (rest.indexOf(sortedWords[w]) === 0) { word2 = sortedWords[w]; break }
            if (word2 === "min" && qty && src[i + 3] !== "(") word2 = null
            if (src[i + run.length] === "_" && run.length > 1) {      // mu_E, sigma_SB, epsilon_0
                var keep = i
                i += run.length
                var full = run + subscript()
                if (run in GREEK || full in CONSTANTS) { push("id", full); continue }
                i = keep
            }
            if (word2 && !(inUnit && resolveUnit(run) && run !== word2)) { push("cmd", word2); i += word2.length; continue }
            if (src[i + run.length] !== "_" && resolveUnit(run) && (run.length > 1 || qty) && (run.length > 1 || SINGLE_UNITS[run])) { push("unit", run); i += run.length; continue }
            if (inUnit && run.length > 1) { for (var q = 0; q < run.length; q++) push("id", run[q]); i += run.length; continue }
            var nm = ch; i++
            nm += subscript()
            push("id", nm); continue
        }
        if ("+-*/^_=(){}[]|!,;'<>%".indexOf(ch) >= 0) { push("sym", ch); i++; continue }
        if (ch === "·" || ch === "×") { push("cmd", "cdot"); i++; continue }
        if (ch === "π") { push("cmd", "pi"); i++; continue }
        if (ch === "√") { push("cmd", "sqrt"); i++; continue }
        if (ch === "−") { push("sym", "-"); i++; continue }
        if (ch === "∞") { push("cmd", "infty"); i++; continue }
        throw new Error("unexpected '" + ch + "'")
    }
    t.push({ t: "end", v: "", pos: n })
    return t
}

// ───────────────────────── parser ─────────────────────────
var FUNC1 = { sin: 1, cos: 1, tan: 1, sec: 1, csc: 1, cot: 1, arcsin: 1, arccos: 1, arctan: 1, sinh: 1, cosh: 1, tanh: 1, ln: 1, exp: 1, sqrt: 1, abs: 1,
              floor: 1, ceil: 1, round: 1, sign: 1, Re: 1, Im: 1, arg: 1, conj: 1, log: 1, lg: 1 }
var FUNCN = { min: 1, max: 1, gcd: 1, lcm: 1 }
var CONSTS = { pi: 1, tau: 1, phi: 1, infty: 1, e: 1, i: 1 }

function Parser(tokens, funcs) {
    this.t = tokens; this.p = 0; this.funcs = funcs || {}; this.stopD = 0; this.bar = 0
}
Parser.prototype = {
    cur: function () { return this.t[this.p] },
    peek: function (k) { return this.t[Math.min(this.p + (k || 1), this.t.length - 1)] },
    next: function () { return this.t[this.p++] },
    isSym: function (s) { var c = this.cur(); return c.t === "sym" && c.v === s },
    isCmd: function (s) { var c = this.cur(); return c.t === "cmd" && c.v === s },
    eatSym: function (s) { if (this.isSym(s)) { this.p++; return true } return false },
    expectSym: function (s) { if (!this.eatSym(s)) throw new Error("expected '" + s + "'" + (this.cur().t === "end" ? " at the end" : " but found '" + this.cur().v + "'")) },
    expectCmd: function (s) { if (this.isCmd(s)) { this.p++; return } throw new Error("expected \\" + s) },

    conv: function (node) {               // "... in km"
        if (this.cur().t === "conv" || this.isCmd("to")) { this.p++; return { k: "conv", a: node, to: this.expr() } }
        return node
    },
    statement: function () {
        var lhs = this.conv(this.expr())
        if (this.isSym("=")) { this.p++; var rhs = this.conv(this.expr()); return { k: "eq", a: lhs, b: rhs } }
        return lhs
    },
    expr: function () {
        var a = this.term()
        for (;;) {
            if (this.isSym("+")) { this.p++; a = { k: "bin", op: "+", a: a, b: this.term() } }
            else if (this.isSym("-")) { this.p++; a = { k: "bin", op: "-", a: a, b: this.term() } }
            else if (this.isCmd("pm")) throw new Error("\\pm is not supported; write both cases")
            else return a
        }
    },
    startsFactor: function () {
        var c = this.cur()
        if (c.t === "unit") return true
        if (c.t === "num" || c.t === "id") {
            if (this.stopD > 0 && c.t === "id" && c.v === "d" && this.peek().t === "id") return false   // the dx of an integral
            return true
        }
        if (c.t === "cmd") return c.v !== "cdot" && c.v !== "times" && c.v !== "div" && c.v !== "mod" && c.v !== "bmod" && c.v !== "to" && c.v !== "rightarrow" &&
                                  c.v !== "rfloor" && c.v !== "rceil" && c.v !== "le" && c.v !== "ge" && c.v !== "leq" && c.v !== "geq" && c.v !== "percent"
        if (c.t === "sym") {
            if (c.v === "(" || c.v === "[" || c.v === "{") return true
            if (c.v === "|") return this.bar === 0
        }
        return false
    },
    term: function () {
        var a = this.unary()
        for (;;) {
            var c = this.cur()
            if (c.t === "sym" && c.v === "*" || c.t === "cmd" && (c.v === "cdot" || c.v === "times")) { this.p++; a = { k: "bin", op: "*", a: a, b: this.unary() } }
            else if (c.t === "sym" && c.v === "/" || c.t === "cmd" && c.v === "div") { this.p++; a = { k: "bin", op: "/", a: a, b: this.unary() } }
            else if (c.t === "sym" && c.v === "%") { this.p++; a = { k: "bin", op: "%", a: a, b: this.unary() } }
            else if (c.t === "cmd" && (c.v === "mod" || c.v === "bmod")) { this.p++; a = { k: "bin", op: "%", a: a, b: this.unary() } }
            else if (c.t === "cmd" && c.v === "percent") { this.p++; a = { k: "bin", op: "/", a: a, b: { k: "num", v: 100 } } }
            else if (this.startsFactor()) { a = { k: "bin", op: "*", a: a, b: this.unary() } }
            else return a
        }
    },
    unary: function () {
        if (this.eatSym("-")) return { k: "neg", a: this.unary() }
        if (this.eatSym("+")) return this.unary()
        return this.power()
    },
    power: function () {
        var base = this.postfix()
        if (this.isSym("^")) {
            this.p++
            return { k: "bin", op: "^", a: base, b: this.powerRhs() }
        }
        return base
    },
    powerRhs: function () {
        var negate = false
        if (this.eatSym("-")) negate = true
        else this.eatSym("+")
        var e
        if (this.isSym("{")) { this.p++; e = this.expr(); this.expectSym("}") }
        else e = this.postfix()
        if (this.isSym("^")) { this.p++; e = { k: "bin", op: "^", a: e, b: this.powerRhs() } }
        return negate ? { k: "neg", a: e } : e
    },
    postfix: function () {
        var a = this.primary()
        for (;;) {
            if (this.isSym("!")) { this.p++; a = { k: "fact", a: a } }
            else return a
        }
    },
    group: function (close) {            // after the opening bracket: comma separated list
        var args = [this.expr()]
        while (this.eatSym(",")) args.push(this.expr())
        this.expectSym(close)
        return args
    },
    braced: function () { this.expectSym("{"); var e = this.expr(); this.expectSym("}"); return e },
    boundsOf: function () {              // optional _{...}^{...} after \sum \int \prod
        var lo = null, hi = null
        for (var k = 0; k < 2; k++) {
            if (this.isSym("_") && lo === null) { this.p++; lo = this.scriptArg() }
            else if (this.isSym("^") && hi === null) { this.p++; hi = this.scriptArg() }
        }
        return { lo: lo, hi: hi }
    },
    scriptArg: function () {
        if (this.isSym("{")) { this.p++; var e = this.scriptBody(); this.expectSym("}"); return e }
        return this.unary1()
    },
    scriptBody: function () {            // inside {...} of a script: may be  k=1  (a binding) or a plain expression
        var save = this.p
        var c = this.cur()
        if (c.t === "id" && this.peek().t === "sym" && this.peek().v === "=") {
            var v = this.next().v; this.p++
            return { k: "bind", v: v, a: this.expr() }
        }
        this.p = save
        return this.expr()
    },
    unary1: function () {                // one atom with optional sign (for  x^2, _1 without braces)
        if (this.eatSym("-")) return { k: "neg", a: this.unary1() }
        return this.primary()
    },
    funcArg: function () {               // argument of \sin etc without brackets: a product of numbers/letters/groups
        if (this.isSym("(") || this.isSym("[")) {
            var open = this.next().v
            return this.group(open === "(" ? ")" : "]")
        }
        if (this.isSym("|") && this.bar === 0) return [this.power()]
        var a = this.unary(), self = this
        // keep multiplying while the next thing is a plain number/letter/bracket (not another function)
        for (;;) {
            var c = this.cur()
            if (c.t === "num" || c.t === "unit" || c.t === "id" && !(this.stopD > 0 && c.v === "d" && this.peek().t === "id") ||
                c.t === "sym" && (c.v === "(" || c.v === "[")) a = { k: "bin", op: "*", a: a, b: this.unary() }
            else break
        }
        return [a]
    },
    primary: function () {
        var c = this.cur()
        if (c.t === "num") {
            this.p++
            var lit = { k: "num", v: c.v }
            while (this.cur().t === "unit") {                       // 9.81 m  /  3 kg m  /  2 s^2: the units belong to the number
                var un = { k: "unit", n: this.next().v }
                if (this.isSym("^")) { this.p++; un = { k: "bin", op: "^", a: un, b: this.powerRhs() } }
                lit = { k: "bin", op: "*", a: lit, b: un }
            }
            return lit
        }
        if (c.t === "unit") { this.p++; return { k: "unit", n: c.v } }
        if (c.t === "id") {
            this.p++
            if (this.funcs[c.v] && this.isSym("(")) { this.p++; return { k: "ucall", n: c.v, args: this.group(")") } }
            return { k: "var", n: c.v }
        }
        if (c.t === "sym") {
            if (c.v === "(") { this.p++; var e = this.expr(); this.expectSym(")"); return { k: "paren", a: e } }
            if (c.v === "[") { this.p++; var e2 = this.expr(); this.expectSym("]"); return { k: "paren", a: e2 } }
            if (c.v === "{") { this.p++; var e3 = this.expr(); this.expectSym("}"); return { k: "paren", a: e3 } }
            if (c.v === "|") {
                this.p++; this.bar++
                var e4 = this.expr()
                this.bar--; this.expectSym("|")
                return { k: "call", f: "abs", args: [e4] }
            }
            throw new Error("unexpected '" + c.v + "'")
        }
        if (c.t === "cmd") return this.command()
        throw new Error("unexpected end of input")
    },
    command: function () {
        var c = this.next(), name = c.v
        switch (name) {
        case "pi": case "tau": case "phi": case "infty": return { k: "const", n: name }
        case "frac": case "dfrac": case "tfrac": return this.frac()
        case "binom": case "dbinom": { var n = this.braced(), k = this.braced(); return { k: "call", f: "binom", args: [n, k] } }
        case "sqrt": {
            var index = null
            if (this.isSym("[")) { this.p++; index = this.expr(); this.expectSym("]") }
            var arg = this.isSym("{") ? this.braced() : this.unary1()
            return index ? { k: "bin", op: "^", a: arg, b: { k: "bin", op: "/", a: { k: "num", v: 1 }, b: index } } : { k: "call", f: "sqrt", args: [arg] }
        }
        case "sum": case "prod": {
            var b = this.boundsOf()
            if (!b.lo || b.lo.k !== "bind") throw new Error("write the sum like \\sum_{k=1}^{10} ...")
            if (!b.hi) throw new Error("the sum needs an upper bound")
            var body = this.term()
            return { k: name, v: b.lo.v, lo: b.lo.a, hi: b.hi, body: body }
        }
        case "int": {
            var bb = this.boundsOf()
            this.stopD++
            var ib = this.expr()
            this.stopD--
            var d = this.cur()
            if (!(d.t === "id" && d.v === "d" && this.peek().t === "id")) throw new Error("end the integral with dx")
            this.p++
            var v = this.next().v
            if (!bb.lo || !bb.hi) throw new Error("only definite integrals are supported: \\int_a^b ... dx")
            return { k: "int", v: v, lo: bb.lo, hi: bb.hi, body: ib }
        }
        case "lim": {
            if (!this.isSym("_")) throw new Error("write the limit like \\lim_{x \\to 0} ...")
            this.p++; this.expectSym("{")
            var vv = this.next()
            if (vv.t !== "id") throw new Error("limit variable expected")
            if (!(this.isCmd("to") || this.isCmd("rightarrow"))) throw new Error("expected \\to")
            this.p++
            var to = this.expr(), side = 0
            if (this.isSym("^")) {                // x \to 0^+  /  0^-
                var s = this.peek()
                if (s.t === "sym" && (s.v === "+" || s.v === "-")) { this.p += 2; side = s.v === "+" ? 1 : -1 }
                else if (s.t === "sym" && s.v === "{") { var sv = this.peek(2); if (sv.t === "sym" && (sv.v === "+" || sv.v === "-")) { this.p += 4; side = sv.v === "+" ? 1 : -1 } }
            }
            this.expectSym("}")
            return { k: "lim", v: vv.v, to: to, side: side, body: this.term() }
        }
        case "lfloor": { var f = this.expr(); this.expectCmd("rfloor"); return { k: "call", f: "floor", args: [f] } }
        case "lceil": { var g = this.expr(); this.expectCmd("rceil"); return { k: "call", f: "ceil", args: [g] } }
        case "percent": throw new Error("misplaced %")
        }
        if (name in FUNC1 || name in FUNCN) return this.callFunction(name)
        throw new Error("unknown command \\" + name)
    },
    callFunction: function (name) {
        var logBase = null, power = null
        if (name === "log" && this.isSym("_")) { this.p++; logBase = this.scriptArg() }
        if (this.isSym("^")) { this.p++; power = this.scriptArg() }
        var args = this.funcArg()
        var node
        if (name === "log") node = logBase ? { k: "call", f: "logb", args: [args[0], logBase] } : { k: "call", f: "log10", args: args }
        else if (name === "lg") node = { k: "call", f: "log2", args: args }
        else node = { k: "call", f: name, args: args }
        if (power) {
            // \sin^{-1} x  is arcsin x ;  \sin^2 x  is (sin x)^2
            if (power.k === "neg" && power.a.k === "num" && power.a.v === 1 && ({ sin: "arcsin", cos: "arccos", tan: "arctan" })[name]) node.f = ({ sin: "arcsin", cos: "arccos", tan: "arctan" })[name]
            else node = { k: "bin", op: "^", a: node, b: power }
        }
        return node
    },
    frac: function () {
        // \frac{d}{dx} body  or  \frac{d^2}{dx^2} body  is a derivative
        var s = this.p
        var m = this.matchDeriv()
        if (m) {
            var body = this.term()
            return { k: "deriv", v: m.v, order: m.order, body: body }
        }
        this.p = s
        var a = this.braced(), b = this.braced()
        return { k: "bin", op: "/", a: a, b: b }
    },
    matchDeriv: function () {
        var t = this.t, p = this.p
        function is(i, ty, v) { return t[i] && t[i].t === ty && (v === undefined || t[i].v === v) }
        if (!is(p, "sym", "{") || !is(p + 1, "id", "d")) return null
        var q = p + 2, order = 1
        if (is(q, "sym", "^")) {
            if (is(q + 1, "num")) { order = t[q + 1].v; q += 2 }
            else if (is(q + 1, "sym", "{") && is(q + 2, "num") && is(q + 3, "sym", "}")) { order = t[q + 2].v; q += 4 }
            else return null
        }
        if (!is(q, "sym", "}") || !is(q + 1, "sym", "{") || !is(q + 2, "id", "d") || !is(q + 3, "id")) return null
        var v = t[q + 3].v
        q += 4
        if (is(q, "sym", "^")) { q++; if (is(q, "num")) q++; else if (is(q, "sym", "{") && is(q + 1, "num") && is(q + 2, "sym", "}")) q += 3; else return null }
        if (!is(q, "sym", "}")) return null
        this.p = q + 1
        return { v: v, order: order }
    }
}

// ───────────────────────── evaluation ─────────────────────────
var limits = { steps: 0 }
function tick() { if (++limits.steps > 60000000) throw new Error("that is taking too long") }

function child(env) { return Object.create(env) }
function lookup(env, n) {
    if (n in env.vars) return env.vars[n]
    return undefined
}
function bindEnv(env, n, v) { var e = { vars: Object.create(env.vars), funcs: env.funcs }; e.vars[n] = v; return e }

function toReal(v, what) {
    if (isQ(v)) throw new Error((what || "value") + " must be a plain number, not " + dimName(v.d))
    if (isC(v)) { if (Math.abs(v.im) > 1e-9) throw new Error((what || "value") + " must be real"); return v.re }
    return v
}

function callBuiltin(f, a) {
    if (a.some(isQ)) {
        if (f === "abs") return Qty(Math.abs(a[0].v), a[0].d)
        if (f === "sqrt") {
            var hd = a[0].d.map(function (e) { return e / 2 })
            if (hd.some(function (e) { return Math.abs(e - Math.round(e)) > 1e-9 })) throw new Error("cannot take the square root of " + dimName(a[0].d))
            if (a[0].v < 0) throw new Error("cannot take the square root of a negative " + dimName(a[0].d))
            return qnorm(Qty(Math.sqrt(a[0].v), hd))
        }
        if (f === "min" || f === "max") {
            a.forEach(function (v) { if (!isQ(v) || !dimsEq(v.d, a[0].d)) throw new Error(f + " needs values with the same unit") })
            return Qty(Math[f].apply(null, a.map(function (v) { return v.v })), a[0].d)
        }
        a.forEach(function (v) { if (isQ(v)) throw new Error(f + " needs a plain number, not " + dimName(v.d)) })
    }
    var x = a[0]
    switch (f) {
    case "sin": return csin(x)
    case "cos": return ccos(x)
    case "tan": return div(csin(x), ccos(x))
    case "sec": return div(1, ccos(x))
    case "csc": return div(1, csin(x))
    case "cot": return div(ccos(x), csin(x))
    case "arcsin": x = toReal(x); if (Math.abs(x) > 1) throw new Error("arcsin needs a value between -1 and 1"); return Math.asin(x)
    case "arccos": x = toReal(x); if (Math.abs(x) > 1) throw new Error("arccos needs a value between -1 and 1"); return Math.acos(x)
    case "arctan": return Math.atan(toReal(x))
    case "sinh": return isC(x) ? mul(0.5, sub(cexp(x), cexp(neg(x)))) : Math.sinh(x)
    case "cosh": return isC(x) ? mul(0.5, add(cexp(x), cexp(neg(x)))) : Math.cosh(x)
    case "tanh": return isC(x) ? div(sub(cexp(x), cexp(neg(x))), add(cexp(x), cexp(neg(x)))) : Math.tanh(x)
    case "ln": return cln(x)
    case "log10": return div(cln(x), Math.LN10)
    case "log2": return div(cln(x), Math.LN2)
    case "logb": return div(cln(x), cln(a[1]))
    case "exp": return cexp(x)
    case "sqrt": return csqrt(x)
    case "abs": return cabs(x)
    case "floor": return Math.floor(toReal(x))
    case "ceil": return Math.ceil(toReal(x))
    case "round": return Math.round(toReal(x))
    case "sign": return Math.sign(toReal(x))
    case "Re": return reOf(x)
    case "Im": return imOf(x)
    case "arg": return carg(x)
    case "conj": return isC(x) ? C(x.re, -x.im) : x
    case "binom": { var n = toReal(a[0]), k = toReal(a[1]); if (k < 0 || k > n) return 0; return Math.round(factorial(n) / (factorial(k) * factorial(n - k))) }
    case "min": return Math.min.apply(null, a.map(function (v) { return toReal(v) }))
    case "max": return Math.max.apply(null, a.map(function (v) { return toReal(v) }))
    case "gcd": return a.map(function (v) { return toReal(v) }).reduce(gcd)
    case "lcm": return a.map(function (v) { return toReal(v) }).reduce(function (p, q) { return Math.abs(p * q) / gcd(p, q) })
    }
    throw new Error("unknown function " + f)
}

function evalNode(n, env) {
    tick()
    switch (n.k) {
    case "num": return n.v
    case "const":
        switch (n.n) { case "pi": return Math.PI; case "tau": return 2 * Math.PI; case "phi": return (1 + Math.sqrt(5)) / 2; case "infty": return Infinity }
        break
    case "var": {
        var v = lookup(env, n.n)
        if (v !== undefined) return v
        if (CONSTANTS[n.n]) return constQ(n.n)
        if (n.n === "e") return Math.E
        if (n.n === "i") return C(0, 1)
        throw new Error(n.n + " is not defined")
    }
    case "paren": return evalNode(n.a, env)
    case "unit": {
        var uv = lookup(env, n.n)
        if (uv !== undefined) return uv                     // you named a variable m or s yourself: that wins
        var ru = resolveUnit(n.n)
        if (!ru) throw new Error(n.n + " is not defined")
        return qnorm(Qty(ru.s, ru.d))
    }
    case "conv": {
        var cv = evalNode(n.a, env), tu = evalNode(n.to, env)
        if (!dimsEq(dimsOf(cv), dimsOf(tu))) throw new Error("cannot convert " + dimName(dimsOf(cv)) + " to " + dimName(dimsOf(tu)))
        var tv = vOf(tu)
        if (tv === 0) throw new Error("cannot convert to zero")
        return { conv: true, v: vOf(cv) / tv, unit: showUnit(n.to) }
    }
    case "neg": return neg(evalNode(n.a, env))
    case "fact": return factorial(evalNode(n.a, env))
    case "bin": {
        var a = evalNode(n.a, env), b = evalNode(n.b, env)
        switch (n.op) {
        case "+": return add(a, b)
        case "-": return sub(a, b)
        case "*": return mul(a, b)
        case "/": return div(a, b)
        case "^": return pow(a, b)
        case "%": { a = toReal(a); b = toReal(b); return a - b * Math.floor(a / b) }
        }
        break
    }
    case "call": return callBuiltin(n.f, n.args.map(function (x) { return evalNode(x, env) }))
    case "ucall": {
        var fn = env.funcs[n.n]
        if (!fn) throw new Error(n.n + " is not a function")
        if (n.args.length !== fn.params.length) throw new Error(n.n + " takes " + fn.params.length + " value(s)")
        var e2 = { vars: Object.create(env.vars), funcs: env.funcs }
        for (var i = 0; i < fn.params.length; i++) e2.vars[fn.params[i]] = evalNode(n.args[i], env)
        return evalNode(fn.body, e2)
    }
    case "sum": case "prod": {
        var lo = Math.round(toReal(evalNode(n.lo, env))), hi = evalNode(n.hi, env)
        var acc = n.k === "sum" ? 0 : 1
        var inf = hi === Infinity
        hi = inf ? lo + 524288 : Math.round(toReal(hi))
        if (hi - lo > 5000000) throw new Error("that sum is too long")
        var half = null, conv = false, mid = inf ? lo + 262144 : null
        var small = 0
        for (var k = lo; k <= hi; k++) {
            var term = evalNode(n.body, bindEnv(env, n.v, k))
            acc = n.k === "sum" ? add(acc, term) : mul(acc, term)
            if (inf) {
                var mag = n.k === "sum" ? cabs(term) : Math.abs(cabs(term) - 1)
                small = mag < 1e-17 ? small + 1 : 0
                if (k === mid) half = acc
                if (small >= 6) { conv = true; break }
                if (!isFinite(cabs(acc))) { conv = true; break }
            }
        }
        // a slowly converging tail (like 1/k^2) is extrapolated from the partial sums at N/2 and N
        if (inf && !conv && half !== null && n.k === "sum") return clean2(sub(mul(2, acc), half))
        return acc
    }
    case "int": return integrate(n, env)
    case "lim": return limit(n, env)
    case "deriv": {
        var x0 = evalNode({ k: "var", n: n.v }, env)
        return clean(deriv(function (t) { return toReal(evalNode(n.body, bindEnv(env, n.v, t))) }, toReal(x0), n.order))
    }
    case "bind": throw new Error("unexpected '='")
    }
    throw new Error("cannot evaluate " + n.k)
}

// numeric results (derivatives, limits, integrals) carry a little noise; snap near-integers and drop the junk digits
function clean(v) {
    if (!isFinite(v)) return v
    var r = Math.round(v)
    if (Math.abs(v - r) < 1e-6 * Math.max(1, Math.abs(v))) return r
    var q = ratio(v, 200)
    if (q && Math.abs(v - q.p / q.q) < 1e-7 * Math.max(1, Math.abs(v))) return q.p / q.q
    return Number(v.toPrecision(9))
}
// derivative by a five-point stencil (higher orders by repeating it)
function deriv(f, x, order) {
    if (order <= 0) return f(x)
    var h = order === 1 ? 1e-5 * Math.max(1, Math.abs(x)) : 1e-3 * Math.max(1, Math.abs(x))
    var g = order === 1 ? f : function (t) { return deriv(f, t, order - 1) }
    return (-g(x + 2 * h) + 8 * g(x + h) - 8 * g(x - h) + g(x - 2 * h)) / (12 * h)
}

// Gauss–Kronrod (7, 15) on [a, b], adaptive
var XGK = [0.991455371120812639, 0.949107912342758525, 0.864864423359769073, 0.741531185599394440, 0.586087235467691130, 0.405845151377397167, 0.207784955007898468, 0]
var WGK = [0.022935322010529225, 0.063092092629978553, 0.104790010322250184, 0.140653259715525919, 0.169004726639267903, 0.190350578064785410, 0.204432940075298892, 0.209482141084727828]
var WG = [0.129484966168869693, 0.279705391489276668, 0.381830050505118945, 0.417959183673469388]
function gk15(f, a, b) {
    var c = (a + b) / 2, h = (b - a) / 2
    var fc = f(c), rk = fc * WGK[7], rg = fc * WG[3]
    for (var j = 0; j < 7; j++) {
        var dx = h * XGK[j], f1 = f(c - dx), f2 = f(c + dx)
        rk += WGK[j] * (f1 + f2)
        if (j % 2 === 1) rg += WG[(j - 1) / 2] * (f1 + f2)
    }
    return { v: rk * h, err: Math.abs((rk - rg) * h) }
}
function adaptive(f, a, b, tol, depth) {
    var r = gk15(f, a, b)
    if (r.err <= tol || depth <= 0) return r.v
    var m = (a + b) / 2
    return adaptive(f, a, m, tol / 2, depth - 1) + adaptive(f, m, b, tol / 2, depth - 1)
}
function clean2(v) { return isC(v) ? v : Number(v.toPrecision(13)) }
// tanh-sinh quadrature: very accurate, and fine with integrable singularities at the ends (like 1/sqrt(x) at 0)
function tanhSinh(f, a, b) {
    var c = (a + b) / 2, hw = (b - a) / 2, prev = null, sum = 0, tmax = 4.0
    var eval1 = function (t, sgn) {
        var u = Math.PI / 2 * Math.sinh(t), e = 2 / (Math.exp(2 * u) + 1)         // distance of the node from the end, as a fraction of hw
        var x = sgn > 0 ? b - hw * e : a + hw * e
        if (x <= a || x >= b) return 0
        var w = hw * (Math.PI / 2) * Math.cosh(t) / (Math.cosh(u) * Math.cosh(u))
        var y = f(x)
        return isFinite(y) ? y * w : 0
    }
    var h = 1
    sum = f(c) * hw * Math.PI / 2
    if (!isFinite(sum)) sum = 0
    for (var L = 0; L <= 7; L++) {
        var step = h
        for (var t = (L === 0 ? step : step); t <= tmax; t += (L === 0 ? step : 2 * step)) {
            if (L > 0 && t === 0) continue
            sum += eval1(t, 1) + eval1(t, -1)
        }
        var I = sum * h
        if (prev !== null && Math.abs(I - prev) <= 1e-10 * Math.max(1, Math.abs(I))) return I
        prev = I
        h /= 2
    }
    // not converged: fall back on the adaptive Gauss–Kronrod rule
    var g = adaptive(f, a, b, 1e-9, 30)
    return isFinite(g) ? g : prev
}
function integrate(n, env) {
    var a = toReal(evalNode(n.lo, env)), b = toReal(evalNode(n.hi, env))
    var f = function (t) { tick(); return toReal(evalNode(n.body, bindEnv(env, n.v, t)), "the integrand") }
    var sign = 1
    if (a > b) { var tmp = a; a = b; b = tmp; sign = -1 }
    if (a === b) return 0
    var g = f, lo = a, hi = b
    if (a === -Infinity && b === Infinity) { g = function (t) { var d = 1 - t * t; return f(t / d) * (1 + t * t) / (d * d) }; lo = -1; hi = 1 }
    else if (b === Infinity) { g = function (t) { return f(a + t / (1 - t)) / ((1 - t) * (1 - t)) }; lo = 0; hi = 1 }
    else if (a === -Infinity) { g = function (t) { return f(b - t / (1 - t)) / ((1 - t) * (1 - t)) }; lo = 0; hi = 1 }
    var r = tanhSinh(g, lo, hi)
    if (!isFinite(r)) throw new Error("the integral does not converge")
    r = sign * r
    var nearest = Math.round(r), q = ratio(r, 200)
    if (Math.abs(r - nearest) < 1e-8 * Math.max(1, Math.abs(r))) return nearest
    if (q && Math.abs(r - q.p / q.q) < 1e-9 * Math.max(1, Math.abs(r))) return q.p / q.q
    return r
}

function limit(n, env) {
    var to = toReal(evalNode(n.to, env))
    var f = function (t) { return evalNode(n.body, bindEnv(env, n.v, t)) }
    var sides = n.side !== 0 ? [n.side] : [1, -1]
    var results = []
    for (var s = 0; s < sides.length; s++) {
        var best = null, bestDiff = Infinity, prev = null
        for (var e = 2; e <= 9; e++) {
            var h = Math.pow(10, -e)
            var x = !isFinite(to) ? (to > 0 ? 1 : -1) * Math.pow(10, e + 1) : to + sides[s] * h
            var y
            try { y = toReal(f(x)) } catch (err) { continue }
            if (prev !== null && isFinite(y)) {
                var d = Math.abs(y - prev)
                if (d < bestDiff) { bestDiff = d; best = y }
            }
            prev = y
        }
        if (best === null) throw new Error("the limit does not exist")
        results.push(best)
    }
    if (results.length === 2 && Math.abs(results[0] - results[1]) > 1e-4 * Math.max(1, Math.abs(results[0]))) throw new Error("the two sides of the limit differ (" + fmt(results[0]) + " vs " + fmt(results[1]) + ")")
    var v = results[0]
    // blunt the finite-difference noise: round to 9 significant digits
    return clean(v)
}

// ───────────────────────── helpers: free variables, printing ─────────────────────────
function freeVars(n, bound, out) {
    if (!n || typeof n !== "object") return
    switch (n.k) {
    case "var": if (!(n.n in bound)) out[n.n] = 1; return
    case "num": case "const": case "unit": return
    case "conv": freeVars(n.a, bound, out); return
    case "bin": freeVars(n.a, bound, out); freeVars(n.b, bound, out); return
    case "neg": case "fact": case "paren": freeVars(n.a, bound, out); return
    case "call": n.args.forEach(function (x) { freeVars(x, bound, out) }); return
    case "ucall": n.args.forEach(function (x) { freeVars(x, bound, out) }); return
    case "sum": case "prod": case "int": {
        freeVars(n.lo, bound, out); freeVars(n.hi, bound, out)
        var b2 = Object.create(bound); b2[n.v] = 1
        freeVars(n.body, b2, out); return
    }
    case "lim": { freeVars(n.to, bound, out); var b3 = Object.create(bound); b3[n.v] = 1; freeVars(n.body, b3, out); return }
    case "deriv": { out[n.v] = 1; freeVars(n.body, bound, out); return }   // d/dx is taken at the current value of x
    }
}

function show(n) {
    switch (n.k) {
    case "num": return String(n.v)
    case "const": return ({ pi: "π", tau: "τ", phi: "φ", infty: "∞" })[n.n]
    case "unit": return n.n
    case "conv": return show(n.a) + " → " + showUnit(n.to)
    case "var": return n.n.replace("_", "₍").replace(/₍(.*)/, function (m, s) { return "_" + s })
    case "paren": return "(" + show(n.a) + ")"
    case "neg": return "−" + show(n.a)
    case "fact": return show(n.a) + "!"
    case "bin": return show(n.a) + " " + ({ "*": "·", "%": "mod" }[n.op] || n.op) + " " + show(n.b)
    case "call": return n.f + "(" + n.args.map(show).join(", ") + ")"
    case "ucall": return n.n + "(" + n.args.map(show).join(", ") + ")"
    case "sum": return "Σ[" + n.v + "=" + show(n.lo) + ".." + show(n.hi) + "] " + show(n.body)
    case "prod": return "Π[" + n.v + "=" + show(n.lo) + ".." + show(n.hi) + "] " + show(n.body)
    case "int": return "∫[" + show(n.lo) + ".." + show(n.hi) + "] " + show(n.body) + " d" + n.v
    case "lim": return "lim[" + n.v + "→" + show(n.to) + (n.side > 0 ? "+" : n.side < 0 ? "−" : "") + "] " + show(n.body)
    case "deriv": return "d" + (n.order > 1 ? "^" + n.order : "") + "/d" + n.v + (n.order > 1 ? "^" + n.order : "") + " " + show(n.body)
    case "bind": return n.v + "=" + show(n.a)
    }
    return "?"
}

// ───────────────────────── output formatting ─────────────────────────
function fmtReal(v) {
    if (v === Infinity) return "∞"
    if (v === -Infinity) return "−∞"
    if (isNaN(v)) return "undefined"
    if (v === 0) return "0"
    if (Number.isInteger(v) && Math.abs(v) < 1e15) return String(v)
    var a = Math.abs(v)
    if (a < 1e-6 || a >= 1e15) {
        var s = v.toExponential(11).replace(/\.?0+e/, "e").replace("e+", "e")
        var m = /^(-?[\d.]+)e(-?\d+)$/.exec(s)
        var sup = { "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹", "-": "⁻" }
        return m ? (m[1] === "1" ? "" : m[1] + " × ") + "10" + m[2].split("").map(function (d) { return sup[d] }).join("") : s
    }
    return String(Number(v.toPrecision(12)))
}
function fmt(v) {
    if (isQ(v)) return fmtQ(v)
    if (v && v.conv) return num(v.v) + " " + v.unit
    if (!isC(v)) return fmtReal(v)
    var re = Number(v.re.toPrecision(12)), im = Number(v.im.toPrecision(12))
    if (Math.abs(re) < 1e-12 && im !== 0) re = 0
    var imAbs = Math.abs(im), imText = imAbs === 1 ? "i" : fmtReal(imAbs) + "i"
    if (re === 0) return (im < 0 ? "−" : "") + imText
    return fmtReal(re) + (im < 0 ? " − " : " + ") + imText
}
// a short exact form for rational values and multiples of π
function ratio(v, maxDen) {
    if (!isFinite(v) || Number.isInteger(v)) return null
    var sign = v < 0 ? -1 : 1, x = Math.abs(v), h1 = 1, h0 = 0, k1 = 0, k0 = 1, b = x
    for (var i = 0; i < 24; i++) {
        var a = Math.floor(b), h2 = a * h1 + h0, k2 = a * k1 + k0
        if (k2 > maxDen) break
        h0 = h1; h1 = h2; k0 = k1; k1 = k2
        if (Math.abs(x - h1 / k1) < 1e-12 * Math.max(1, x)) return { p: sign * h1, q: k1 }
        var fr = b - a
        if (fr < 1e-14) break
        b = 1 / fr
    }
    return null
}
function exactForm(v) {
    if (isQ(v)) return qAlts(v)
    if (typeof v !== "number") return ""
    if (isC(v) || !isFinite(v) || v === 0 || Math.abs(v) >= 1e6 || Math.abs(v) < 1e-4) return ""
    var r = ratio(v, 2000)
    if (r && r.q > 1) return r.p + "/" + r.q
    var rp = ratio(v / Math.PI, 24)
    if (rp) return (rp.p === 1 ? "" : rp.p === -1 ? "−" : String(rp.p)) + "π" + (rp.q > 1 ? "/" + rp.q : "")
    if (Number.isInteger(v / Math.PI) && v !== 0) { var k = v / Math.PI; return (k === 1 ? "" : k === -1 ? "−" : String(k)) + "π" }
    var sq = v * v
    if (v > 0 && !Number.isInteger(v)) { var rs = ratio(sq, 400); if (!rs && Math.round(sq) > 1 && Math.abs(sq - Math.round(sq)) < 1e-9 * Math.max(1, sq)) rs = { p: Math.round(sq), q: 1 }
                                         if (rs && rs.q === 1 && rs.p > 1 && rs.p < 400) return "√" + rs.p }
    return ""
}

// ───────────────────────── top level ─────────────────────────
// Session state: variables and functions defined by earlier statements in the same input (not kept between inputs).
function splitStatements(tokens) {
    var out = [[]]
    tokens.forEach(function (t) {
        if (t.t === "sym" && t.v === ";") out.push([])
        else if (t.t !== "end") out[out.length - 1].push(t)
    })
    return out.filter(function (s) { return s.length > 0 }).map(function (s) { s.push({ t: "end", v: "", pos: 0 }); return s })
}

function isDefinition(tk) {                // f(x) = ...   (one letter, a parenthesised list of letters, then =)
    if (tk.length < 6 || tk[0].t !== "id" || !(tk[1].t === "sym" && tk[1].v === "(")) return null
    var params = [], i = 2
    for (;;) {
        if (tk[i].t !== "id") return null
        params.push(tk[i].v); i++
        if (tk[i].t === "sym" && tk[i].v === ",") { i++; continue }
        if (tk[i].t === "sym" && tk[i].v === ")") { i++; break }
        return null
    }
    if (!(tk[i].t === "sym" && tk[i].v === "=")) return null
    return { name: tk[0].v, params: params, rest: tk.slice(i + 1) }
}

function run(src, opts) {
    opts = opts || {}
    limits.steps = 0
    var res = { ok: false, kind: "value", text: "", exact: "", parsed: "", error: "", curves: [], roots: [], xvar: "x" }
    try {
        src = String(src).trim().replace(/^=\s*/, "")
        if (!src) { res.error = ""; return res }
        var env = { vars: {}, funcs: {} }
        var stmts = splitStatements(lex(src))
        if (stmts.length === 0) return res
        var last = null, assigned = ""
        var curves = [], solves = []
        for (var si = 0; si < stmts.length; si++) {
            var tk = stmts[si]
            var def = isDefinition(tk)
            if (def) {
                env.funcs[def.name] = { params: def.params, body: null }
                var dp = new Parser(def.rest, env.funcs)
                var body = dp.expr()
                if (dp.cur().t !== "end") throw new Error("unexpected '" + dp.cur().v + "'")
                env.funcs[def.name].body = body
                last = { kind: "def", text: def.name + "(" + def.params.join(", ") + ") = " + show(body) }
                // a one-variable function on its own is drawn
                if (def.params.length === 1 && si === stmts.length - 1) {
                    var fv0 = {}; freeVars(body, (function () { var b = {}; b[def.params[0]] = 1; return b })(), fv0)
                    var undef0 = Object.keys(fv0).filter(function (k) { return !(k in env.vars) && !CONSTS[k] && !CONSTANTS[k] })
                    if (undef0.length === 0) curves.push({ label: def.name + "(" + def.params[0] + ")", node: body, v: def.params[0], env: env })
                }
                continue
            }
            var p = new Parser(tk, env.funcs)
            var ast = p.statement()
            if (p.cur().t !== "end") throw new Error("unexpected '" + p.cur().v + "'" + (p.cur().v === ")" ? " (extra bracket?)" : ""))
            res.parsed = ast.k === "eq" ? show(ast.a) + " = " + show(ast.b) : show(ast)
            var fvs = {}
            if (ast.k === "eq") { freeVars(ast.a, {}, fvs); freeVars(ast.b, {}, fvs) } else freeVars(ast, {}, fvs)
            var free = Object.keys(fvs).filter(function (k) { return !(k in env.vars) && !CONSTS[k] && !CONSTANTS[k] })

            if (ast.k === "eq") {
                var simple = ast.a.k === "var" ? ast.a.n : null
                var rfv = {}; freeVars(ast.b, {}, rfv)
                var rfree = Object.keys(rfv).filter(function (k) { return !(k in env.vars) && !CONSTS[k] && !CONSTANTS[k] })
                if (simple && rfree.length === 0) {            // a = 5
                    var val = evalNode(ast.b, env)
                    env.vars[simple] = val
                    last = { kind: "assign", name: simple, value: val }
                } else if (simple && (simple === "y" || simple !== rfree[0])) {   // y = f(x): a curve
                    var xv = rfree.indexOf("x") >= 0 ? "x" : rfree[0]
                    var others = rfree.filter(function (k) { return k !== xv })
                    if (others.length) throw new Error(others[0] + " is not defined")
                    curves.push({ label: simple + " = " + show(ast.b), node: ast.b, v: xv, env: env })
                    last = { kind: "plot" }
                } else {                                        // an equation: find where both sides meet
                    var xv2 = free.indexOf("x") >= 0 ? "x" : free[0]
                    if (!xv2) { var l = evalNode(ast.a, env), r = evalNode(ast.b, env); last = { kind: "truth", value: Math.abs(reOf(l) - reOf(r)) < 1e-9 * Math.max(1, Math.abs(reOf(l))) }; continue }
                    var others2 = free.filter(function (k) { return k !== xv2 })
                    if (others2.length) throw new Error(others2[0] + " is not defined (give it a value first, e.g. a=2; ...)")
                    solves.push({ node: { k: "bin", op: "-", a: ast.a, b: ast.b }, v: xv2, env: env, a: ast.a, b: ast.b })
                    last = { kind: "solve" }
                }
                continue
            }
            if (free.length === 0) {
                var value = evalNode(ast, env)
                last = { kind: "value", value: value }
            } else {                                            // an expression of x: draw it
                var xv3 = free.indexOf("x") >= 0 ? "x" : free[0]
                var others3 = free.filter(function (k) { return k !== xv3 })
                if (others3.length) throw new Error(others3[0] + " is not defined (give it a value first, e.g. a=2; ...)")
                curves.push({ label: show(ast), node: ast, v: xv3, env: env })
                last = { kind: "plot" }
            }
        }
        res.ok = true
        if (solves.length) {
            var s = solves[solves.length - 1]
            res.kind = "solve"; res.xvar = s.v
            res.roots = findRoots(s, opts.xmin !== undefined ? opts.xmin : -60, opts.xmax !== undefined ? opts.xmax : 60)
            curves.push({ label: show(s.a), node: s.a, v: s.v, env: s.env })
            curves.push({ label: show(s.b), node: s.b, v: s.v, env: s.env })
            res.text = res.roots.length ? res.roots.map(function (r) { return s.v + " = " + fmt(r) }).join(",  ") + (res.roots.more ? "  … (nearest to 0)" : "") : "no solution between −60 and 60"
            res.exact = ""
        } else if (curves.length) {
            res.kind = "plot"; res.xvar = curves[0].v
            res.text = curves.length === 1 ? curves[0].label : curves.length + " curves"
        } else if (last && last.kind === "value") {
            res.kind = "value"; res.value = last.value
            res.text = fmt(last.value); res.exact = exactForm(last.value)
            if (res.exact === res.text) res.exact = ""
        } else if (last && last.kind === "assign") {
            res.kind = "value"; res.value = last.value; res.text = last.name + " = " + fmt(last.value)
        } else if (last && last.kind === "def") { res.kind = "def"; res.text = last.text }
        else if (last && last.kind === "truth") { res.kind = "value"; res.text = last.value ? "true" : "false" }
        res.curves = curves
        return res
    } catch (e) {
        res.ok = false; res.error = e && e.message ? e.message : String(e)
        return res
    }
}

function valueAt(curve, x) {
    try {
        limits.steps = 0
        var env = { vars: Object.create(curve.env.vars), funcs: curve.env.funcs }
        env.vars[curve.v] = x
        var y = evalNode(curve.node, env)
        if (isQ(y)) return y.v
        if (isC(y)) return Math.abs(y.im) < 1e-9 ? y.re : NaN
        return y
    } catch (e) { return NaN }
}

function findRoots(s, lo, hi) {
    var f = function (x) { return valueAt({ node: s.node, v: s.v, env: s.env }, x) }
    var N = 4000, roots = [], px = lo, py = f(lo)
    for (var i = 1; i <= N; i++) {
        var x = lo + (hi - lo) * i / N, y = f(x)
        if (isFinite(py) && isFinite(y)) {
            if (py === 0) roots.push(px)
            else if (py * y < 0) {
                var a = px, b = x, fa = py
                for (var it = 0; it < 80; it++) { var m = (a + b) / 2, fm = f(m); if (fa * fm <= 0) b = m; else { a = m; fa = fm } }
                var r = (a + b) / 2
                if (Math.abs(f(r)) < 1e-6 * Math.max(1, Math.abs(py), Math.abs(y)) * 1e3) roots.push(r)     // skip jumps like 1/x
            }
        }
        px = x; py = y
    }
    // a double root touches zero without changing sign: look for tiny |f| at local minima
    var uniq = []
    roots.sort(function (a, b) { return a - b }).forEach(function (r) { if (!uniq.length || Math.abs(r - uniq[uniq.length - 1]) > 1e-7) uniq.push(r) })
    for (var j = 0; j < uniq.length; j++) if (Math.abs(uniq[j]) < 1e-12) uniq[j] = 0
    uniq = uniq.map(function (r) { return Number(r.toPrecision(12)) })
    // keep the ones closest to zero
    uniq.sort(function (a, b) { return Math.abs(a) - Math.abs(b) })
    var more = uniq.length > 8
    uniq = uniq.slice(0, 8).sort(function (a, b) { return a - b })
    uniq.more = more
    return uniq
}

// y values for every curve over [xmin, xmax]; NaN becomes null so the canvas breaks the line there
function sample(curves, xmin, xmax, n) {
    return curves.map(function (c) {
        var ys = new Array(n + 1)
        for (var i = 0; i <= n; i++) {
            var y = valueAt(c, xmin + (xmax - xmin) * i / n)
            ys[i] = isFinite(y) ? y : null
        }
        return ys
    })
}
// a y-range that shows the interesting part of the curves (ignores wild spikes)
function fitY(ys) {
    var vals = []
    ys.forEach(function (c) { c.forEach(function (y) { if (y !== null) vals.push(y) }) })
    if (!vals.length) return { lo: -5, hi: 5 }
    vals.sort(function (a, b) { return a - b })
    var lo = vals[Math.floor(vals.length * 0.02)], hi = vals[Math.floor(vals.length * 0.98)]
    if (hi - lo < 1e-9) { lo -= 1; hi += 1 }
    var pad = (hi - lo) * 0.12
    return { lo: lo - pad, hi: hi + pad }
}
