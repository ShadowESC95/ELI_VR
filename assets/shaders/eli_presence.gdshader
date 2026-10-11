shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;

// The outer shell of ELI's presence: a rim of light with a slow ripple.
uniform vec3 tint : source_color = vec3(0.39, 0.87, 1.0);
uniform float energy = 1.0;
uniform float activity = 0.2;

void fragment() {
    float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.4);
    float ripple = 0.5 + 0.5 * sin(TIME * (1.5 + activity * 6.0) + UV.y * 18.0);
    float glow = rim * (0.6 + 0.4 * ripple);
    ALBEDO = tint * energy * glow;
    ALPHA = clamp(glow, 0.0, 1.0);
}
