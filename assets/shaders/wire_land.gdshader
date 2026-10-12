shader_type spatial;
render_mode unshaded;

// Hills drawn as lines: land in a made world.
uniform vec3 tint : source_color = vec3(0.39, 0.87, 1.0);
uniform vec3 peak : source_color = vec3(1.0, 0.3, 0.8);
uniform vec3 base : source_color = vec3(0.004, 0.008, 0.016);
uniform float cell = 9.0;
uniform float top = 90.0;
uniform float energy = 1.5;

varying float tall;

void vertex() {
    tall = VERTEX.y;
}

void fragment() {
    vec2 p = UV / cell;
    vec2 g = abs(fract(p - 0.5) - 0.5) / fwidth(p);
    float wire = 1.0 - min(min(g.x, g.y) / 1.3, 1.0);
    float h = clamp(tall / top, 0.0, 1.0);
    float far = exp(-length(UV) / 420.0);
    ALBEDO = base + mix(tint, peak, h) * wire * energy * (0.35 + h) * far;
}
