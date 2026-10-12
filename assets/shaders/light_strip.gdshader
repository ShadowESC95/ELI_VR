shader_type spatial;
render_mode unshaded;

// A strip of light with a slow pulse travelling along it.
uniform vec3 tint : source_color = vec3(0.39, 0.87, 1.0);
uniform float energy = 2.0;
uniform float speed = 0.12;
uniform float wave = 0.35;
uniform float phase = 0.0;

void fragment() {
    float travel = 0.5 + 0.5 * sin((UV.y * wave - TIME * speed) * TAU + phase);
    ALBEDO = tint * energy * (0.62 + 0.38 * travel * travel);
}
