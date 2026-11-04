shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

// Foam where water meets something standing in it: a ring (MeshKit.annulus, whose UVs are its own
// metres) laid at the waterline, whitest at its inner edge, broken by noise, washing in and out
// with the swell.
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float energy = 0.8;
uniform float seed = 0.0;
uniform float inner = 0.4;              // the ring's inner and outer radius, in metres
uniform float outer = 1.0;

float hash12(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.3) * 43758.5453);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
               mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
    vec2 p = UV;
    float r = length(p);
    float across = clamp((r - inner) / max(outer - inner, 0.01), 0.0, 1.0);
    float wash = 0.5 + 0.5 * sin(TIME * 0.9 + seed * 3.0 + across * 4.0);
    float lace = vnoise(p * 6.0 + vec2(TIME * 0.15, 0.0)) * 0.6 + vnoise(p * 17.0 - vec2(0.0, TIME * 0.1)) * 0.4;
    float a = lace * (0.4 + 0.6 * wash) * (1.0 - across) * (1.0 - across);
    ALBEDO = tint * energy * a;
    ALPHA = clamp(a, 0.0, 1.0);
}
