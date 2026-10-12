shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

// A cloud of glowing gas far away, slowly churning.
uniform vec3 tint : source_color = vec3(0.4, 0.6, 1.0);
uniform vec3 tint_b : source_color = vec3(0.9, 0.3, 0.6);
uniform float energy = 0.5;
uniform float seed = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { v += a * noise(p); p = p * 2.03 + 7.1; a *= 0.5; } return v; }

void fragment() {
    vec2 p = UV * 3.0 + seed;
    float t = TIME * 0.008;
    float warp = fbm(p + vec2(t, -t));
    float cloud = fbm(p * 1.6 + warp * 1.8 + vec2(-t, t * 0.6));
    float dark = fbm(p * 3.1 - warp);
    float shape = smoothstep(1.0, 0.25, length(UV - 0.5) * 2.0);
    float a = pow(clamp(cloud * 1.5 - 0.35, 0.0, 1.0), 1.6) * shape * (0.55 + 0.45 * dark);
    ALBEDO = mix(tint, tint_b, clamp(warp * 1.4 - 0.2, 0.0, 1.0)) * a * energy;
    ALPHA = clamp(a, 0.0, 1.0);
}
