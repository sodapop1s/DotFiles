.pragma library

// The Aero page's formula sheet. `pretty` is what you read, `latex` is what gets copied (paste it into Obsidian, or into the
// launcher after "=" if it has numbers in it). Add your own in ~/.config/qs-bar/formulas.json as
//   [{ "cat": "Mine", "name": "...", "pretty": "...", "latex": "...", "note": "..." }]

var FORMULAS = [
    // ── orbital mechanics ──
    { cat: "Orbits", name: "Vis-viva", pretty: "v² = μ (2/r − 1/a)", latex: "v^2 = \\mu \\left(\\frac{2}{r} - \\frac{1}{a}\\right)", note: "speed anywhere on an orbit of semi-major axis a" },
    { cat: "Orbits", name: "Circular orbit speed", pretty: "v = √(μ/r)", latex: "v = \\sqrt{\\frac{\\mu}{r}}", note: "try:  =\\sqrt{\\mu_E / (6778 km)}" },
    { cat: "Orbits", name: "Orbital period", pretty: "T = 2π √(a³/μ)", latex: "T = 2\\pi\\sqrt{\\frac{a^3}{\\mu}}", note: "Kepler's third law" },
    { cat: "Orbits", name: "Escape speed", pretty: "v_esc = √(2μ/r) = √2 · v_circ", latex: "v_{esc} = \\sqrt{\\frac{2\\mu}{r}}", note: "" },
    { cat: "Orbits", name: "Specific orbital energy", pretty: "ε = v²/2 − μ/r = −μ/(2a)", latex: "\\varepsilon = \\frac{v^2}{2} - \\frac{\\mu}{r} = -\\frac{\\mu}{2a}", note: "negative = bound" },
    { cat: "Orbits", name: "Periapsis / apoapsis", pretty: "r_p = a(1 − e),  r_a = a(1 + e)", latex: "r_p = a(1-e), \\quad r_a = a(1+e)", note: "" },
    { cat: "Orbits", name: "Orbit equation", pretty: "r = p / (1 + e cos θ),  p = h²/μ", latex: "r = \\frac{p}{1 + e\\cos\\theta}, \\quad p = \\frac{h^2}{\\mu}", note: "" },
    { cat: "Orbits", name: "Kepler's equation", pretty: "M = E − e sin E", latex: "M = E - e\\sin E", note: "mean anomaly from eccentric anomaly" },
    { cat: "Orbits", name: "Hohmann Δv₁", pretty: "Δv₁ = √(μ/r₁) (√(2r₂/(r₁+r₂)) − 1)", latex: "\\Delta v_1 = \\sqrt{\\frac{\\mu}{r_1}}\\left(\\sqrt{\\frac{2r_2}{r_1+r_2}} - 1\\right)", note: "the Orbit tab does this for you" },
    { cat: "Orbits", name: "Hohmann Δv₂", pretty: "Δv₂ = √(μ/r₂) (1 − √(2r₁/(r₁+r₂)))", latex: "\\Delta v_2 = \\sqrt{\\frac{\\mu}{r_2}}\\left(1 - \\sqrt{\\frac{2r_1}{r_1+r_2}}\\right)", note: "" },
    { cat: "Orbits", name: "Hohmann transfer time", pretty: "t = π √(a_t³/μ),  a_t = (r₁+r₂)/2", latex: "t = \\pi\\sqrt{\\frac{a_t^3}{\\mu}}", note: "half the transfer ellipse's period" },
    { cat: "Orbits", name: "Plane change", pretty: "Δv = 2 v sin(Δi/2)", latex: "\\Delta v = 2 v \\sin\\left(\\frac{\\Delta i}{2}\\right)", note: "do it where v is smallest (apoapsis)" },
    { cat: "Orbits", name: "Sphere of influence", pretty: "r_SOI = a (m/M)^(2/5)", latex: "r_{SOI} = a\\left(\\frac{m}{M}\\right)^{2/5}", note: "" },
    { cat: "Orbits", name: "Hill sphere", pretty: "r_H = a (m/3M)^(1/3)", latex: "r_H = a\\sqrt[3]{\\frac{m}{3M}}", note: "" },
    // ── propulsion ──
    { cat: "Propulsion", name: "Rocket equation", pretty: "Δv = I_sp g₀ ln(m₀/m_f)", latex: "\\Delta v = I_{sp} g_0 \\ln\\frac{m_0}{m_f}", note: "try:  =300 s * g_0 * \\ln(5)" },
    { cat: "Propulsion", name: "Mass ratio", pretty: "m₀/m_f = exp(Δv / (I_sp g₀))", latex: "\\frac{m_0}{m_f} = e^{\\Delta v/(I_{sp} g_0)}", note: "" },
    { cat: "Propulsion", name: "Thrust", pretty: "F = ṁ v_e + (p_e − p_a) A_e", latex: "F = \\dot m v_e + (p_e - p_a) A_e", note: "" },
    { cat: "Propulsion", name: "Specific impulse", pretty: "I_sp = F / (ṁ g₀) = v_eff / g₀", latex: "I_{sp} = \\frac{F}{\\dot m g_0}", note: "seconds" },
    { cat: "Propulsion", name: "Exhaust velocity (ideal nozzle)", pretty: "v_e = √( 2γ/(γ−1) · R T_c [1 − (p_e/p_c)^((γ−1)/γ)] )", latex: "v_e = \\sqrt{\\frac{2\\gamma}{\\gamma-1} R T_c\\left[1 - \\left(\\frac{p_e}{p_c}\\right)^{(\\gamma-1)/\\gamma}\\right]}", note: "" },
    { cat: "Propulsion", name: "Thrust-to-weight", pretty: "T/W = F / (m g)", latex: "\\frac{T}{W} = \\frac{F}{m g}", note: "> 1 to lift off" },
    // ── aerodynamics ──
    { cat: "Aero", name: "Dynamic pressure", pretty: "q = ½ ρ V²", latex: "q = \\tfrac{1}{2}\\rho V^2", note: "try:  =0.5 * rho_0 * (100 m/s)^2" },
    { cat: "Aero", name: "Lift", pretty: "L = ½ ρ V² S C_L", latex: "L = \\tfrac{1}{2}\\rho V^2 S C_L", note: "" },
    { cat: "Aero", name: "Drag", pretty: "D = ½ ρ V² S C_D", latex: "D = \\tfrac{1}{2}\\rho V^2 S C_D", note: "" },
    { cat: "Aero", name: "Drag polar", pretty: "C_D = C_D0 + k C_L²,  k = 1/(π e AR)", latex: "C_D = C_{D0} + k C_L^2, \\quad k = \\frac{1}{\\pi e AR}", note: "" },
    { cat: "Aero", name: "Mach number", pretty: "M = V / a,  a = √(γ R T)", latex: "M = \\frac{V}{a}, \\quad a = \\sqrt{\\gamma R T}", note: "" },
    { cat: "Aero", name: "Isentropic temperature ratio", pretty: "T₀/T = 1 + (γ−1)/2 · M²", latex: "\\frac{T_0}{T} = 1 + \\frac{\\gamma-1}{2}M^2", note: "" },
    { cat: "Aero", name: "Isentropic pressure ratio", pretty: "p₀/p = (1 + (γ−1)/2 · M²)^(γ/(γ−1))", latex: "\\frac{p_0}{p} = \\left(1 + \\frac{\\gamma-1}{2}M^2\\right)^{\\gamma/(\\gamma-1)}", note: "" },
    { cat: "Aero", name: "Reynolds number", pretty: "Re = ρ V L / μ", latex: "Re = \\frac{\\rho V L}{\\mu}", note: "" },
    { cat: "Aero", name: "Bernoulli", pretty: "p + ½ρV² + ρgh = const", latex: "p + \\tfrac{1}{2}\\rho V^2 + \\rho g h = \\text{const}", note: "incompressible, steady, inviscid" },
    { cat: "Aero", name: "Thin airfoil lift slope", pretty: "C_L = 2π (α − α₀)", latex: "C_L = 2\\pi(\\alpha - \\alpha_0)", note: "" },
    { cat: "Aero", name: "Best glide", pretty: "(L/D)_max = 1 / (2 √(k C_D0))", latex: "\\left(\\frac{L}{D}\\right)_{max} = \\frac{1}{2\\sqrt{k C_{D0}}}", note: "" },
    // ── thermodynamics ──
    { cat: "Thermo", name: "Ideal gas", pretty: "p V = n R T = m R_s T", latex: "pV = nRT", note: "try:  =R_air * 300 K * 1 kg / (1 m^3)" },
    { cat: "Thermo", name: "First law", pretty: "ΔU = Q − W", latex: "\\Delta U = Q - W", note: "" },
    { cat: "Thermo", name: "Carnot efficiency", pretty: "η = 1 − T_c / T_h", latex: "\\eta = 1 - \\frac{T_c}{T_h}", note: "" },
    { cat: "Thermo", name: "Isentropic process", pretty: "p v^γ = const;  T₂/T₁ = (p₂/p₁)^((γ−1)/γ)", latex: "\\frac{T_2}{T_1} = \\left(\\frac{p_2}{p_1}\\right)^{(\\gamma-1)/\\gamma}", note: "" },
    { cat: "Thermo", name: "Specific heats", pretty: "c_p − c_v = R,  γ = c_p / c_v", latex: "c_p - c_v = R, \\quad \\gamma = \\frac{c_p}{c_v}", note: "" },
    { cat: "Thermo", name: "Enthalpy", pretty: "h = u + p v", latex: "h = u + pv", note: "" },
    // ── structures ──
    { cat: "Structures", name: "Stress and strain", pretty: "σ = F/A,  ε = ΔL/L,  σ = E ε", latex: "\\sigma = \\frac{F}{A}, \\quad \\varepsilon = \\frac{\\Delta L}{L}, \\quad \\sigma = E\\varepsilon", note: "" },
    { cat: "Structures", name: "Bending stress", pretty: "σ = M y / I", latex: "\\sigma = \\frac{M y}{I}", note: "" },
    { cat: "Structures", name: "Torsion", pretty: "τ = T r / J", latex: "\\tau = \\frac{T r}{J}", note: "" },
    { cat: "Structures", name: "Euler buckling", pretty: "P_cr = π² E I / (K L)²", latex: "P_{cr} = \\frac{\\pi^2 E I}{(K L)^2}", note: "" },
    { cat: "Structures", name: "Cantilever tip deflection", pretty: "δ = P L³ / (3 E I)", latex: "\\delta = \\frac{P L^3}{3 E I}", note: "" },
    { cat: "Structures", name: "Thin-wall pressure vessel", pretty: "σ_hoop = p r / t,  σ_axial = p r / (2t)", latex: "\\sigma_h = \\frac{pr}{t}, \\quad \\sigma_a = \\frac{pr}{2t}", note: "" },
    // ── dynamics and controls ──
    { cat: "Dynamics", name: "Newton's second law", pretty: "F = m a,  τ = I α", latex: "F = ma, \\quad \\tau = I\\alpha", note: "" },
    { cat: "Dynamics", name: "Kinetic energy", pretty: "KE = ½ m v² = ½ I ω²", latex: "KE = \\tfrac{1}{2}mv^2", note: "try:  =1/2 * 4 kg * (3 m/s)^2" },
    { cat: "Dynamics", name: "Angular momentum", pretty: "L = I ω = r × m v", latex: "\\vec L = I\\vec\\omega = \\vec r\\times m\\vec v", note: "" },
    { cat: "Dynamics", name: "Centripetal acceleration", pretty: "a_c = v² / r = ω² r", latex: "a_c = \\frac{v^2}{r} = \\omega^2 r", note: "" },
    { cat: "Controls", name: "Second-order system", pretty: "G(s) = ωₙ² / (s² + 2ζωₙ s + ωₙ²)", latex: "G(s) = \\frac{\\omega_n^2}{s^2 + 2\\zeta\\omega_n s + \\omega_n^2}", note: "" },
    { cat: "Controls", name: "Percent overshoot", pretty: "%OS = 100 · exp(−ζπ / √(1−ζ²))", latex: "\\%OS = 100\\,e^{-\\zeta\\pi/\\sqrt{1-\\zeta^2}}", note: "" },
    { cat: "Controls", name: "Settling time (2%)", pretty: "t_s ≈ 4 / (ζ ωₙ)", latex: "t_s \\approx \\frac{4}{\\zeta\\omega_n}", note: "" },
    { cat: "Controls", name: "PID controller", pretty: "u = K_p e + K_i ∫e dt + K_d de/dt", latex: "u(t) = K_p e(t) + K_i\\int_0^t e(\\tau)d\\tau + K_d\\frac{de}{dt}", note: "" },
    // ── constants (also usable in the calculator) ──
    { cat: "Constants", name: "Standard gravity", pretty: "g₀ = 9.80665 m/s²", latex: "g_0 = 9.80665\\ \\mathrm{m/s^2}", note: "calculator: g_0" },
    { cat: "Constants", name: "Earth μ and radius", pretty: "μ_E = 3.986004418×10¹⁴ m³/s²,  R_E = 6378.137 km", latex: "\\mu_E = 3.986\\times10^{14}\\ \\mathrm{m^3/s^2}", note: "calculator: mu_E, R_E, M_E" },
    { cat: "Constants", name: "Sun, Moon, Mars, Jupiter, Kerbin", pretty: "μ_S 1.327×10²⁰ · μ_M 4.905×10¹² · μ_Ma 4.283×10¹³ · μ_J 1.267×10¹⁷ · μ_K 3.532×10¹² (m³/s²)", latex: "\\mu_S,\\ \\mu_M,\\ \\mu_{Ma},\\ \\mu_J,\\ \\mu_K", note: "calculator: mu_S, mu_M, mu_Ma, mu_J, mu_K (and R_M, R_Ma, R_J, R_K)" },
    { cat: "Constants", name: "Speed of light, G, Boltzmann", pretty: "c = 299 792 458 m/s · G = 6.6743×10⁻¹¹ · k_B = 1.380649×10⁻²³ J/K", latex: "c_0,\\ G,\\ k_B", note: "calculator: c_0, G, k_B, N_A, R_u, sigma_SB, h_P, q_e" },
    { cat: "Constants", name: "Sea-level air (ISA)", pretty: "ρ₀ = 1.225 kg/m³ · p₀ = 101325 Pa · T₀ = 288.15 K · a₀ = 340.294 m/s · R = 287.05 J/(kg·K)", latex: "\\rho_0,\\ p_0,\\ T_0,\\ a_0,\\ R_{air}", note: "calculator: rho_0, p_0, T_0, a_0, R_air" }
]
