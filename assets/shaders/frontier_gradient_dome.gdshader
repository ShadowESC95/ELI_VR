shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never;

uniform vec3 top_color : source_color = vec3(0.08, 0.24, 0.48);
uniform vec3 horizon_color : source_color = vec3(0.75, 0.58, 0.42);
uniform vec3 bottom_color : source_color = vec3(0.04, 0.05, 0.06);
uniform float exposure = 1.0;

void fragment() {
    float y = UV.y;
    float upper = smoothstep(0.50, 1.0, y);
    float lower = smoothstep(0.0, 0.50, y);
    vec3 low_mix = mix(bottom_color, horizon_color, lower);
    vec3 col = mix(low_mix, top_color, upper);
    float horizon_glow = exp(-pow(abs(y - 0.5) * 8.0, 2.0));
    col += horizon_color * horizon_glow * 0.18;
    ALBEDO = col * exposure;
    EMISSION = col * exposure * 0.55;
}
