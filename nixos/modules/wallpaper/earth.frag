#version 440
// Earth wallpaper: an orthographic globe lit by the real sun, with the ISS marked.
// Day and night are the NASA Blue Marble and Black Marble maps, blended at the terminator.
// Compiled to earth.frag.qsb by modules/wallpaper (qsb --qt6).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;   // surface size, px
    vec2 subsolar;     // latitude, longitude of the sun overhead (radians)
    vec2 view;         // latitude, longitude at the sphere's centre (radians)
    vec3 sphere;       // centre x, centre y (px from top-left), radius (px)
    vec2 iss;          // ISS latitude, longitude (radians)
    float issOn;       // 1 when a position is known
    vec4 bgColor;
    vec4 issColor;
} ubuf;

layout(binding = 1) uniform sampler2D dayTex;
layout(binding = 2) uniform sampler2D nightTex;

const float PI = 3.14159265359;
const float ISS_SCALE = 1.066;     // (6371 + 420 km) / 6371 km

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

vec3 dirFromLatLon(float lat, float lon) {
    return vec3(cos(lat) * cos(lon), cos(lat) * sin(lon), sin(lat));
}

// inverse orthographic projection: point on the unit disc -> (lat, lon)
vec2 latLonAt(vec2 q) {
    float rho = max(length(q), 1e-6);
    float c = asin(min(rho, 1.0));
    float p0 = ubuf.view.x;
    float lat = asin(clamp(cos(c) * sin(p0) + q.y * sin(c) * cos(p0) / rho, -1.0, 1.0));
    float lon = ubuf.view.y + atan(q.x * sin(c), rho * cos(p0) * cos(c) - q.y * sin(p0) * sin(c));
    return vec2(lat, lon);
}

void main() {
    vec2 px = qt_TexCoord0 * ubuf.resolution;
    float R = ubuf.sphere.z;
    vec2 q = vec2(px.x - ubuf.sphere.x, ubuf.sphere.y - px.y) / R;   // y up
    float rho = length(q);
    vec3 sun = dirFromLatLon(ubuf.subsolar.x, ubuf.subsolar.y);

    // space: flat background colour plus a sparse, static star field
    vec2 cell = floor(px / 3.0);
    float star = step(0.9968, hash(cell)) * (0.2 + 0.6 * hash(cell + 7.7));
    vec3 col = ubuf.bgColor.rgb + vec3(star);

    // atmosphere glow just outside the limb, on the sunlit side only
    vec2 limb = latLonAt(q / max(rho, 1e-6));
    float limbLight = dot(dirFromLatLon(limb.x, limb.y), sun);
    float glow = exp(-(rho - 1.0) * 42.0) * smoothstep(-0.3, 0.4, limbLight);
    float outside = step(1.0, rho);
    col = mix(col, ubuf.bgColor.rgb + vec3(0.27, 0.52, 1.0) * glow * 0.55, outside * clamp(glow * 2.0, 0.0, 1.0));
    col += outside * vec3(0.27, 0.52, 1.0) * glow * 0.35;

    // the planet
    float edge = 1.0 - smoothstep(1.0 - 1.5 / R, 1.0, rho);
    if (edge > 0.0) {
        vec2 ll = latLonAt(q);
        vec2 uv = vec2(mod(ll.y + PI, 2.0 * PI) / (2.0 * PI), 0.5 - ll.x / PI);
        float l = dot(dirFromLatLon(ll.x, ll.y), sun);

        vec3 day = texture(dayTex, uv).rgb;
        vec3 night = texture(nightTex, uv).rgb;
        vec3 dayLit = day * (0.5 + 0.55 * clamp(l, 0.0, 1.0));
        vec3 nightLit = night * 1.5 + day * vec3(0.015, 0.02, 0.03);
        vec3 planet = mix(nightLit, dayLit, smoothstep(-0.10, 0.10, l));

        // warm tint where the sun is just rising or setting
        planet = mix(planet, planet * vec3(1.12, 0.86, 0.72), exp(-pow(l / 0.12, 2.0)) * 0.5);

        // atmosphere seen edge-on
        float z = sqrt(max(0.0, 1.0 - rho * rho));
        planet += vec3(0.27, 0.52, 1.0) * pow(1.0 - z, 2.5) * (0.12 + 0.88 * smoothstep(-0.25, 0.35, l)) * 0.8;

        col = mix(col, planet, edge);
    }

    // ISS marker
    if (ubuf.issOn > 0.5) {
        float p0 = ubuf.view.x, p = ubuf.iss.x, dl = ubuf.iss.y - ubuf.view.y;
        float cosc = sin(p0) * sin(p) + cos(p0) * cos(p) * cos(dl);
        vec2 s = vec2(cos(p) * sin(dl), cos(p0) * sin(p) - sin(p0) * cos(p) * cos(dl)) * ISS_SCALE;
        bool visible = cosc >= 0.0 || length(s) >= 1.0;
        if (visible) {
            float d = distance(px, vec2(ubuf.sphere.x + R * s.x, ubuf.sphere.y - R * s.y));
            float core = 1.0 - smoothstep(3.0, 4.5, d);
            float ring = (1.0 - smoothstep(0.0, 1.0, abs(d - 11.0))) * 0.45;
            float halo = exp(-d / 14.0) * 0.25;
            col = mix(col, ubuf.issColor.rgb, clamp(core + ring + halo, 0.0, 1.0));
        }
    }

    fragColor = vec4(col, 1.0) * ubuf.qt_Opacity;
}
