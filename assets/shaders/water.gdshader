shader_type spatial;
render_mode unshaded, world_vertex_coords;

#include "res://assets/shaders/include/noise.gdshaderinc"

// Open water. Near you the surface really moves: a few trains of swell (Gerstner waves: the water
// goes round in circles, so crests sharpen and troughs flatten), each running at the speed deep
// water gives its length (ω² = g·k), handed in by the room, which floats things on the same
// waves. Each train is faded out where the grid (MeshKit.disc) grows too coarse to carry it, and
// finer ripples on top are only in the shading. What the water shows is the room's own sky,
// mirrored (the same photograph, so the two always agree), a glitter of the sun on the ripples,
// and, where a crest stands between you and the low sun, the green of light through the water.
uniform sampler2D photo : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 deep : source_color = vec3(0.02, 0.07, 0.10);
uniform vec3 through : source_color = vec3(0.05, 0.32, 0.28);   // light seen through a thin crest
uniform float chop = 0.06;
uniform float exposure = 1.0;
uniform float lod = 1.5;
uniform vec3 sun_dir = vec3(0.7, 0.15, -0.7);
uniform vec3 sun_colour : source_color = vec3(1.0, 0.75, 0.5);
uniform float glitter = 6.0;
// the swell: each train is (direction x, direction z, wavelength m, height m), its steepness (how
// far the water goes round, 0..1) and phase; `clock` is the room's own seconds, so what floats on
// the swell rides the same waves
uniform vec4 waves[4];
uniform float steep[4];
uniform float clock = 0.0;
// the grid: the gap between its rings r metres out is growth·(r + offset) (MeshKit.disc_step)
uniform float growth = 0.05;
uniform float offset = 0.5;

const float G = 9.81;

varying vec3 world_pos;
varying vec3 swell_normal;
varying float lift;

vec2 ripple(vec2 p, vec2 dir, float freq, float speed) {
    float phase = dot(p, dir) * freq + TIME * speed;
    return dir * cos(phase) * freq;
}

void vertex() {
    vec3 p = VERTEX;
    vec2 at = p.xz;
    float gap = growth * (length(at - MODEL_MATRIX[3].xz) + offset);
    vec3 moved = vec3(0.0);
    vec3 n = vec3(0.0, 1.0, 0.0);
    for (int i = 0; i < 4; i++) {
        vec2 dir = normalize(waves[i].xy);
        float len = waves[i].z;
        float k = TAU / len;
        float w = sqrt(G * k);
        // a train only where the grid has four points or more along one of its waves
        float a = waves[i].w * (1.0 - smoothstep(len / 8.0, len / 4.0, gap));
        float phase = k * dot(dir, at) - w * clock;
        float c = cos(phase);
        float s = sin(phase);
        moved += vec3(dir.x * steep[i] * a * c, a * s, dir.y * steep[i] * a * c);
        n += vec3(-dir.x * k * a * c, -steep[i] * k * a * s, -dir.y * k * a * c);
    }
    VERTEX = p + moved;
    world_pos = VERTEX;
    swell_normal = normalize(n);
    lift = moved.y;
}

void fragment() {
    vec2 p = world_pos.xz;
    float far = length(p);
    // finer ripples, in the shading only; the finest fade with distance
    vec2 slope = ripple(p, normalize(vec2(1.0, 0.3)), 0.35, 0.9) * 1.0
        + ripple(p, normalize(vec2(-0.4, 1.0)), 0.6, 1.2) * 0.6
        + ripple(p, normalize(vec2(0.7, -0.7)), 1.7, 2.0) * 0.25 * exp(-far / 120.0)
        + ripple(p, normalize(vec2(-0.9, -0.2)), 4.3, 3.1) * 0.10 * exp(-far / 40.0);
    vec3 n = normalize(swell_normal + vec3(-slope.x * chop, 0.0, -slope.y * chop));

    vec3 view = normalize(world_pos - CAMERA_POSITION_WORLD);
    vec3 r = reflect(view, n);
    r.y = abs(r.y);
    vec2 uv = vec2(atan(r.x, -r.z) / TAU + 0.5, acos(clamp(r.y, -1.0, 1.0)) / PI);
    vec3 sky = textureLod(photo, uv, lod).rgb * exposure;

    float facing = clamp(dot(-view, n), 0.0, 1.0);
    float mirror = 0.04 + 0.96 * pow(1.0 - facing, 4.0);
    vec3 col = mix(deep, sky, mirror);

    // the sun's glitter: each ripple facing it just so throws back a point of it
    vec3 sun = normalize(sun_dir);
    float sparkle = pow(max(dot(r, sun), 0.0), 900.0) * (0.6 + 0.8 * vnoise(p * 3.0 + TIME * 0.7));
    col += sun_colour * glitter * sparkle * mirror;

    // light through a crest standing between you and the sun
    float behind = pow(max(dot(view, sun * vec3(1.0, 0.0, 1.0)), 0.0), 3.0);
    col += through * behind * clamp(lift * 2.5, 0.0, 1.0) * (1.0 - mirror) * exposure;
    ALBEDO = col;
}
