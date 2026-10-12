shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

// Matter falling into a black hole: a disc that turns faster towards the
// middle, white-hot at the inner edge.
uniform vec3 hot : source_color = vec3(1.0, 0.92, 0.8);
uniform vec3 warm : source_color = vec3(1.0, 0.45, 0.12);
uniform vec3 cool : source_color = vec3(0.5, 0.2, 0.9);
uniform float inner = 75.0;
uniform float outer = 230.0;
uniform float energy = 1.6;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
    float radius = length(UV);
    float r = clamp((radius - inner) / (outer - inner), 0.0, 1.0);
    float angle = atan(UV.y, UV.x);
    float turn = angle + TIME * 0.35 / (0.25 + r * 1.6);
    float streaks = noise(vec2(turn * 9.0, r * 26.0)) * 0.6 + noise(vec2(turn * 23.0, r * 70.0)) * 0.4;
    float heat = pow(1.0 - r, 2.2);
    // the side turning towards you is brighter
    float beaming = 0.55 + 0.45 * cos(angle - 0.6);
    float edges = smoothstep(0.0, 0.03, r) * smoothstep(1.0, 0.75, r);
    float a = (0.2 + streaks * 0.95) * (0.25 + heat * 1.5) * edges * beaming;
    vec3 col = mix(cool, warm, smoothstep(1.0, 0.35, r));
    col = mix(col, hot, heat);
    ALBEDO = col * a * energy;
    ALPHA = clamp(a, 0.0, 1.0);
}
