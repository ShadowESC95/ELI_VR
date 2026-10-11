shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 color : source_color = vec3(0.2, 0.8, 1.0);

void fragment() {
    float edge = smoothstep(0.48, 0.30, length(UV - vec2(0.5)));
    float pulse = 0.62 + 0.38 * sin(TIME * 2.0);
    ALBEDO = color * (0.15 + pulse * 0.35);
    EMISSION = color * (0.8 + pulse * 1.2) * edge;
    ALPHA = 0.78;
}
