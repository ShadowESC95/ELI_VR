shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

// A beam of light through mist or water: bright at the top, gone by the
// bottom, drifting a little.
uniform vec3 tint : source_color = vec3(1.0, 0.97, 0.9);
uniform float energy = 0.18;
uniform float seed = 0.0;

void fragment() {
    float across = 1.0 - abs(UV.x - 0.5) * 2.0;
    float streak = 0.6 + 0.4 * sin(UV.x * 22.0 + seed * 9.0 + TIME * 0.2);
    float down = pow(1.0 - UV.y, 0.6) * smoothstep(1.0, 0.75, 1.0 - UV.y + 0.25);
    float breathe = 0.75 + 0.25 * sin(TIME * 0.35 + seed * 5.0);
    float a = pow(across, 1.6) * streak * UV.y * breathe;
    a = pow(across, 1.6) * streak * breathe * smoothstep(0.0, 0.5, UV.y) * (0.35 + 0.65 * UV.y);
    ALBEDO = tint * energy * a;
    ALPHA = clamp(a, 0.0, 1.0);
}
