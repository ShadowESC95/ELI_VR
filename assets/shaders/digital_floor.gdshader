shader_type spatial;
render_mode unshaded;

uniform vec3 base_color : source_color = vec3(0.002, 0.015, 0.008);
uniform vec3 line_color : source_color = vec3(0.12, 1.0, 0.40);
uniform float grid_scale = 38.0;
uniform float pulse_speed = 1.2;

void fragment() {
    vec2 g = abs(fract(UV * grid_scale - 0.5) - 0.5) / fwidth(UV * grid_scale);
    float line = 1.0 - min(min(g.x, g.y), 1.0);
    float pulse = 0.65 + 0.35 * sin(TIME * pulse_speed + UV.y * 14.0);
    ALBEDO = mix(base_color, line_color, line * 0.36 * pulse);
    EMISSION = line_color * line * 0.48 * pulse;
}
