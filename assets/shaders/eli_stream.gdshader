shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

// ELI pouring itself into what it is making: a thread of its light with pulses running along it
// from ELI to the thing, fading at both ends.
uniform vec3 tint : source_color = vec3(0.39, 0.87, 1.0);
uniform float energy = 1.0;

void fragment() {
    float along = UV.y;
    float pulses = 0.5 + 0.5 * sin((along * 9.0 + TIME * 4.0) * 3.14159);
    float ends = smoothstep(0.0, 0.12, along) * smoothstep(1.0, 0.82, along);
    float edge = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.5);
    float glow = ends * edge * (0.35 + 0.65 * pulses);
    ALBEDO = tint * energy * glow;
    ALPHA = clamp(glow, 0.0, 1.0);
}
