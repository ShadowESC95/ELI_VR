shader_type spatial;
render_mode unshaded;

// A face of falling symbols: data running down a pillar.
uniform vec3 tint : source_color = vec3(0.39, 0.87, 1.0);
uniform vec3 base : source_color = vec3(0.004, 0.008, 0.016);
uniform float energy = 1.8;
uniform float seed = 0.0;
uniform vec2 cells = vec2(8.0, 40.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453); }

void fragment() {
    vec2 grid = UV * cells;
    vec2 id = floor(grid);
    vec2 in_cell = fract(grid);
    float speed = 2.0 + hash(vec2(id.x, 7.0)) * 6.0;
    float head = fract(hash(vec2(id.x, 3.0)) + TIME * speed / cells.y);
    float behind = fract(head - (1.0 - UV.y));
    float trail = pow(1.0 - behind, 6.0);
    float glyph = step(0.35, hash(id + floor(TIME * 3.0 + hash(id) * 9.0)));
    float dot_shape = step(abs(in_cell.x - 0.5), 0.32) * step(abs(in_cell.y - 0.5), 0.36);
    float lead = smoothstep(0.03, 0.0, behind);
    ALBEDO = base + tint * energy * (trail * glyph * dot_shape + lead * dot_shape * 1.5);
}
