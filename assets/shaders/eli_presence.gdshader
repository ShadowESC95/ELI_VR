shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;

// The outer shell of ELI's presence: a rim of light like a thin film, its colour sliding along
// the edge as the view changes, with a slow ripple that quickens as ELI listens, thinks or speaks.
uniform vec3 tint : source_color = vec3(0.39, 0.87, 1.0);
uniform float energy = 1.0;
uniform float activity = 0.2;

vec3 hue_turn(vec3 c, float turn) {
    // rotation about the grey axis
    const vec3 k = vec3(0.57735);
    float a = turn * 6.2831853;
    return c * cos(a) + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - cos(a));
}

void fragment() {
    float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
    float rim = pow(1.0 - facing, 2.4);
    float ripple = 0.5 + 0.5 * sin(TIME * (1.5 + activity * 6.0) + UV.y * 18.0 + UV.x * 12.566);
    vec3 film = max(hue_turn(tint, (1.0 - facing) * 0.18 + 0.03 * sin(TIME * 0.3)), vec3(0.0));
    float glow = rim * (0.55 + 0.45 * ripple);
    ALBEDO = mix(tint, film, 0.6) * energy * glow;
    ALPHA = clamp(glow, 0.0, 1.0);
}
