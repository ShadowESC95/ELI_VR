shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

// A soft point of light that always faces the viewer: lamps, the sun, dust.
// Stands in for bloom, which a headset does not always get.
uniform vec3 tint : source_color = vec3(1.0);
uniform float energy = 1.0;
// 0 is all soft haze, 1 puts a hot point at the centre.
uniform float core = 0.5;

void vertex() {
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
        INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
        INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
        INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
        MODEL_MATRIX[3]);
}

float grain(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    float r = length(UV - 0.5) * 2.0;
    float haze = pow(max(1.0 - r, 0.0), 3.0) * 0.30;
    float heart = exp(-r * r * 90.0) * core * 3.0 + exp(-r * r * 14.0) * core * 0.5;
    float a = haze + heart;
    // a little noise so the long falloff does not show as rings
    a += (grain(FRAGCOORD.xy) - 0.5) * 0.012 * step(0.004, a);
    ALBEDO = tint * energy * max(a, 0.0);
    ALPHA = clamp(a, 0.0, 1.0);
}
