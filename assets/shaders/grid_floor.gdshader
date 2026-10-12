shader_type spatial;
render_mode unshaded;

// The ground of a made world: a grid of light running to the horizon, with
// pulses travelling out from where you stand.
uniform vec3 tint : source_color = vec3(0.39, 0.87, 1.0);
uniform vec3 base : source_color = vec3(0.004, 0.008, 0.016);
uniform float cell = 2.0;
uniform float energy = 1.6;
uniform float fade = 260.0;

float line(vec2 p, float width) {
    vec2 g = abs(fract(p - 0.5) - 0.5) / fwidth(p);
    return 1.0 - min(min(g.x, g.y) / width, 1.0);
}

void fragment() {
    vec2 p = UV / cell;
    float fine = line(p, 1.2);
    float coarse = line(p / 5.0, 1.6);
    float r = length(UV);
    float pulse = pow(0.5 + 0.5 * sin(r * 0.12 - TIME * 0.9), 14.0);
    float far = exp(-r / fade);
    float v = (fine * 0.35 + coarse * 0.9) * (0.55 + pulse * 1.6) * far;
    ALBEDO = base + tint * energy * v;
}
