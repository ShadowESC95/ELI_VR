shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

// A shape drawn only by its edges, and a faint skin of light.
uniform vec3 tint : source_color = vec3(0.39, 0.87, 1.0);
uniform float energy = 1.2;
uniform vec2 cells = vec2(8.0, 4.0);

void fragment() {
    vec2 p = UV * cells;
    vec2 g = abs(fract(p - 0.5) - 0.5) / fwidth(p);
    float wire = 1.0 - min(min(g.x, g.y) / 1.4, 1.0);
    float a = wire + 0.04;
    ALBEDO = tint * energy * a;
    ALPHA = clamp(a, 0.0, 1.0);
}
