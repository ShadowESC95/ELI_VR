shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
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
    vec2 centered = vec2(uv.x, uv.y - 0.5);

    float n1 = noise(uv * vec2(8.0, 4.0));
    float n2 = noise(uv * vec2(23.0, 11.0) + 7.4);
    float galactic_band = exp(-pow(abs(centered.y + 0.10 * sin(uv.x * 8.0)), 2.0) * 42.0);

    vec3 base = vec3(0.0015, 0.0022, 0.008);
    vec3 nebula = mix(vec3(0.015, 0.025, 0.08), vec3(0.15, 0.035, 0.22), n1);
    nebula += vec3(0.02, 0.10, 0.18) * n2;
    vec3 col = base + nebula * galactic_band * 0.55;

    vec2 cell = floor(uv * vec2(1500.0, 750.0));
    float s = hash21(cell);
    float star = smoothstep(0.996, 1.0, s);
    float bright = smoothstep(0.9993, 1.0, s);
    col += vec3(0.72, 0.84, 1.0) * star * 1.3;
    col += vec3(1.0, 0.92, 0.78) * bright * 3.0;

    ALBEDO = col;
    EMISSION = col * 1.9;
}
