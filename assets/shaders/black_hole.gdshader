shader_type spatial;
render_mode unshaded, cull_back, fog_disabled, shadows_disabled;

#include "res://assets/shaders/include/noise.gdshaderinc"
#include "res://assets/shaders/include/starmap.gdshaderinc"

// A black hole as light really shows one. Drawn on a ball round the hole (the lens): every pixel
// follows its own ray back past the hole, using the table of rays scripts/world/kit/black_hole.gd
// worked out (Schwarzschild geodesics). A ray that falls in is the shadow. A ray that gets away
// shows the stars where it really came from, bent: the sky round the hole is pulled into rings.
// On the way a ray may cross the plane of the disc of hot gas going round the hole, in front of it
// and, bent back towards you, behind it: so the far side of the disc shows over the top of the
// shadow and under its bottom. The gas is hottest just outside its inner edge (the innermost
// stable orbit), glows at its own temperature, and moves at a good part of the speed of light, so
// the side coming towards you is bluer and much brighter than the side going away, and everything
// is reddened climbing out of the hole's pull. Just outside the shadow lies the photon ring: light
// that went round the hole before it got away. At the lens's edge the bending is eased to nothing,
// so the ball shows exactly the sky behind it.
//
// Lengths are in units of the hole's mass (GM/c²): `mass` is metres per unit.

uniform sampler2D lens : filter_linear, repeat_disable;  // red: u = 1/r along each ray; green: how far it was bent
uniform vec3 hole;                          // the hole's middle, in the world
uniform float mass = 10.0;                  // metres per unit of the hole's mass
uniform float reach = 0.7;                  // the lens's angular radius from the room's middle (the table's last row)
uniform float sweep = 9.42477796;           // the orbit angle the table's columns run to
uniform vec3 spin = vec3(0.0, 1.0, 0.0);    // the disc's axis, the way its gas goes round
uniform vec3 disc_x = vec3(1.0, 0.0, 0.0);  // any direction in the disc's plane
uniform float disc_in = 6.0;                // the disc's inner and outer edge
uniform float disc_out = 18.0;
uniform float kelvin = 5600.0;              // the gas's temperature where it is hottest, as it would look at rest
uniform float energy = 2.0;
uniform float period = 40.0;                // seconds for the gas at the inner edge to go round once
uniform sampler2D stars : source_color, filter_linear_mipmap, repeat_enable;
uniform mat3 orient = mat3(1.0);
uniform float star_energy = 1.0;
uniform float contrast = 1.2;
uniform float lod = 0.5;

const float CRITICAL = 5.196152;            // 3√3: the shadow's edge, as an impact parameter
const float ISCO = 6.0;
// The hottest point of a thin disc's temperature profile (Shakura-Sunyaev), r = 49/36 of the inner
// edge, where (r_in/r)^(3/4) (1 − √(r_in/r))^(1/4) is 0.4880: the profile is scaled to 1 there.
const float PROFILE_PEAK = 0.4880;

varying vec3 world_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// The colour of a black body at `k` kelvin, in linear light, brightest channel 1 (a fit to the
// Planckian locus: Tanner Helland's, from Mitchell Charity's table).
vec3 blackbody(float k) {
    float t = clamp(k, 1000.0, 40000.0) / 100.0;
    vec3 c;
    c.r = t <= 66.0 ? 1.0 : clamp(1.2929362 * pow(t - 60.0, -0.1332048), 0.0, 1.0);
    c.g = t <= 66.0 ? clamp(0.3900816 * log(t) - 0.6318414, 0.0, 1.0) : clamp(1.1298909 * pow(t - 60.0, -0.0755148), 0.0, 1.0);
    c.b = t >= 66.0 ? 1.0 : (t <= 19.0 ? 0.0 : clamp(0.5432068 * log(t - 10.0) - 1.1962541, 0.0, 1.0));
    return pow(c, vec3(2.2));
}

// The gas where the ray meets the disc: `r` from the middle, `p` the direction to that point,
// `lambda` the ray's angular momentum about the disc's axis. Returns light (rgb) and how much of
// what is behind it the gas hides (a).
vec4 gas(float r, vec3 p, float lambda) {
    // how far out, and where round the disc in its own frame
    vec3 disc_y = cross(spin, disc_x);
    float theta = atan(dot(p, disc_y), dot(p, disc_x));

    // the gas goes round at the Kepler rate, faster further in; blobs of it are drawn out into
    // arcs by that shear. Two layers taken in turn, each started again while the other shows, so
    // the winding never gets finer than the disc can show (as a flow map does).
    float rate = TAU / period * pow(ISCO / r, 1.5);
    float cycle = TIME / (period * 0.5);
    float clumps = 0.0;
    for (int layer = 0; layer < 2; layer++) {
        float f = fract(cycle + 0.5 * float(layer));
        float age = f * period * 0.5;
        float a = theta - rate * age;
        vec2 q = vec2(cos(a), sin(a)) * r;
        float seed = floor(cycle + 0.5 * float(layer)) * 17.3 + float(layer) * 41.7;
        float n = vnoise2(q * 0.9 + seed) * 0.7 + vnoise(q * 3.1 - seed) * 0.3;
        clumps += n * (1.0 - abs(2.0 * f - 1.0));
    }
    float inner = smoothstep(disc_in, disc_in + 0.5, r);
    float outer = 1.0 - smoothstep(disc_out * 0.4, disc_out, r);
    float density = inner * outer * clamp(0.25 + 1.1 * (clumps - 0.3), 0.0, 1.2);

    // its own temperature, then seen from here: shifted by its speed towards or away from us and by
    // climbing out of the hole's pull, g = √(1 − 3/r) / (1 − Ωλ) with Ω = r^(−3/2)
    float s = sqrt(max(disc_in / r, 0.0));
    float t = pow(disc_in / r, 0.75) * pow(max(1.0 - s, 0.0), 0.25) / PROFILE_PEAK;
    float omega = pow(r, -1.5);
    float g = sqrt(max(1.0 - 3.0 / r, 0.0)) / max(1.0 - omega * lambda, 0.05);
    // a fixed band of colours carries g³ of the light (specific intensity over frequency cubed)
    vec3 light = blackbody(kelvin * t * g) * (t * t * t * t) * (g * g * g) * energy * density;
    return vec4(light, clamp(density * 1.1, 0.0, 0.92));
}

void fragment() {
    vec3 eye = CAMERA_POSITION_WORLD;
    vec3 d = normalize(world_pos - eye);
    vec3 rel = (eye - hole) / mass;
    float dist = length(rel);
    vec3 e1 = rel / dist;                       // from the hole to the eye
    float cos_a = clamp(dot(d, -e1), -1.0, 1.0);
    float alpha = acos(cos_a);                  // the ray's angle from the hole's middle
    float sin_a = max(sqrt(1.0 - cos_a * cos_a), 1e-5);
    vec3 e2 = (d + cos_a * e1) / sin_a;         // in the ray's plane, the way it goes round
    float row = alpha / reach;

    // the impact parameter, 1/b² = 1/(D² sin²a) − 2/D³: under CRITICAL the ray falls in
    float inv_b2 = 1.0 / (dist * dist * sin_a * sin_a) - 2.0 / (dist * dist * dist);
    float b = inversesqrt(max(inv_b2, 1e-8));
    float aa = fwidth(b) * 0.75 + 1e-4;
    float fallen = 1.0 - smoothstep(CRITICAL - aa, CRITICAL + aa, b);

    // the ray's angular momentum about the disc's axis: L = r × p, the light moving along −d
    float lambda = dot(-dist * cross(e1, d), spin);

    // where the ray's plane meets the disc's: first at `first` round from the eye, then every half turn
    float a_n = dot(e1, spin);
    float side = a_n >= 0.0 ? 1.0 : -1.0;
    float first = atan(abs(a_n), -side * dot(e2, spin));
    vec3 col = vec3(0.0);
    float through = 1.0;
    for (int k = 0; k < 3; k++) {
        float phi = first + float(k) * PI;
        if (phi < sweep) {
            float u = textureLod(lens, vec2(phi / sweep, row), 0.0).r;
            float r = 1.0 / max(u, 1e-4);
            if (r > disc_in * 0.95 && r < disc_out) {
                vec4 here = gas(r, cos(phi) * e1 + sin(phi) * e2, lambda);
                col += through * here.rgb;
                through *= 1.0 - here.a;
            }
        }
    }

    // the photon ring: light from round the hole that circled it before getting away
    float ring_w = max(0.025, fwidth(b));
    float ring = exp(-pow((b - CRITICAL - ring_w) / ring_w, 2.0));
    float g_ring = 1.0 / max(1.0 - pow(ISCO, -1.5) * lambda, 0.2);
    col += through * (1.0 - fallen) * ring * blackbody(kelvin * 0.9 * g_ring) * (g_ring * g_ring * g_ring) * energy * 0.4;

    // the stars, in the direction the ray really came from: bent by the table's angle, eased to
    // nothing at the lens's edge, and read at the mip the bent sky's spread over this pixel asks for
    float ease = clamp((row - 0.55) / 0.45, 0.0, 1.0);
    float bent = textureLod(lens, vec2(0.0, row), 0.0).g * (1.0 - ease * ease) * (1.0 - ease * ease);
    float out_phi = PI - alpha + bent;
    vec3 out_dir = cos(out_phi) * e1 + sin(out_phi) * e2;
    float texels = float(textureSize(stars, 0).x) / TAU;
    float level = max(lod, log2(max(length(fwidth(out_dir)) * texels, 1e-6)));
    vec3 sky = starmap(stars, orient, out_dir, star_energy, contrast, level);
    col += through * (1.0 - fallen) * sky;

    ALBEDO = col;
}
