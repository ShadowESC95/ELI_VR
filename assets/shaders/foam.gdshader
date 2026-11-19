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

#include "res://assets/shaders/include/noise.gdshaderinc"

void fragment() {
    vec2 p = UV;
    float r = length(p);
    float across = clamp((r - inner) / max(outer - inner, 0.01), 0.0, 1.0);
    float wash = 0.5 + 0.5 * sin(TIME * 0.9 + seed * 3.0 + across * 4.0);
    float lace = vnoises(p * 6.0 + vec2(TIME * 0.15, 0.0), seed * 17.3) * 0.6 + vnoises(p * 17.0 - vec2(0.0, TIME * 0.1), seed * 17.3) * 0.4;
    float a = lace * (0.4 + 0.6 * wash) * (1.0 - across) * (1.0 - across);
    ALBEDO = tint * energy * a;
    ALPHA = clamp(a, 0.0, 1.0);
}
