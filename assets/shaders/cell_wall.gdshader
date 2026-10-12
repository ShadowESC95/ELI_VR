shader_type spatial;
render_mode unshaded;

// A wall of small lit cells, each keeping its own time: stored memories,
// status lamps on a rack. `lit` is how many are on, `alarm` how many of
// those show the warning colour.
uniform vec3 tint : source_color = vec3(0.39, 0.87, 1.0);
uniform vec3 warn : source_color = vec3(1.0, 0.25, 0.15);
uniform vec3 base : source_color = vec3(0.01, 0.012, 0.016);
uniform vec2 cells = vec2(24.0, 40.0);
uniform float lit = 0.6;
uniform float alarm = 0.0;
uniform float pace = 0.5;
uniform float energy = 1.6;
uniform float seed = 0.0;
uniform float roundness = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453); }

void fragment() {
    vec2 grid = UV * cells;
    vec2 id = floor(grid);
    vec2 f = fract(grid) - 0.5;
    float shape = mix(step(abs(f.x), 0.36) * step(abs(f.y), 0.30), smoothstep(0.34, 0.24, length(f)), roundness);
    float who = hash(id);
    float on = step(who, lit);
    float beat = 0.5 + 0.5 * sin(TIME * pace * (0.6 + hash(id + 3.0) * 2.4) + who * 40.0);
    float flick = step(0.35, hash(id + floor(TIME * pace * 2.0 * (0.5 + hash(id + 9.0)))));
    float glow = on * (0.25 + 0.75 * beat) * mix(1.0, flick, 0.6);
    vec3 colour = mix(tint, warn, step(hash(id + 21.0), alarm));
    ALBEDO = base + colour * energy * glow * shape;
}
