shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec3 nebula_color : source_color = vec3(0.35, 0.15, 0.8);
uniform float density = 0.32;
uniform float seed = 1.0;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21) + seed);
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec2 uv = UV;
    float n = noise(uv * 5.0 + seed);
    n = n * 0.55 + noise(uv * 11.0 - seed * 0.17) * 0.30 + noise(uv * 27.0 + 3.4) * 0.15;
    float edge = smoothstep(0.0, 0.22, uv.x) * smoothstep(1.0, 0.78, uv.x);
    edge *= smoothstep(0.0, 0.18, uv.y) * smoothstep(1.0, 0.82, uv.y);
    float a = smoothstep(0.48, 0.82, n) * density * (0.35 + 0.65 * edge);
    ALBEDO = nebula_color;
    EMISSION = nebula_color * (1.2 + n * 1.8);
    ALPHA = a;
}
