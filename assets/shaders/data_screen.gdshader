shader_type spatial;
render_mode unshaded;

// An instrument screen: rows of readings that tick over, and a trace.
uniform vec3 tint : source_color = vec3(0.39, 0.87, 1.0);
uniform float energy = 1.6;
uniform float seed = 0.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.0) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;
    float row = floor(uv.y * 14.0);
    float tick = floor(TIME * (0.4 + hash(vec2(row, 3.0)) * 1.4));
    float fill = hash(vec2(row, tick)) * 0.75 + 0.1;
    float bar = step(uv.x, fill) * step(0.18, fract(uv.y * 14.0)) * step(0.06, uv.x);
    float trace_y = 0.5 + 0.3 * sin(uv.x * 9.0 + TIME * 1.3 + seed) * sin(uv.x * 2.3 - TIME * 0.4);
    float trace = smoothstep(0.02, 0.0, abs(uv.y - trace_y));
    float frame = step(uv.x, 0.015) + step(0.985, uv.x) + step(uv.y, 0.02) + step(0.98, uv.y);
    float v = 0.05 + bar * 0.45 + trace * 0.9 + clamp(frame, 0.0, 1.0) * 0.5;
    ALBEDO = tint * energy * v;
}
