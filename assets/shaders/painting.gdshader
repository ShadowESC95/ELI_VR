shader_type spatial;

// A painting of ELI's own: a style and the two to four colours it is painted in, its seed making
// each one different. Styles: 0 rings, 1 stripes, 2 waves, 3 cells, 4 blooms, 5 horizon, 6 rays,
// 7 drift. A faint grain over all of it, as paint on canvas has.

uniform int style = 0;
uniform vec3 colours[4];
uniform int count = 2;
uniform float seed = 0.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 13.17) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float sum = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 5; i++) {
        sum += amp * noise(p);
        p *= 2.03;
        amp *= 0.5;
    }
    return sum;
}

// Along the palette, the colours in their order, blended where they meet.
vec3 paint(float t) {
    float span = float(max(count, 2) - 1);
    float at = clamp(t, 0.0, 1.0) * span;
    int i = int(floor(at));
    int j = min(i + 1, max(count, 2) - 1);
    return mix(colours[i], colours[j], smoothstep(0.2, 0.8, fract(at)));
}

void fragment() {
    vec2 uv = UV;
    vec2 c = uv - vec2(0.5);
    float s = fract(seed * 0.618);
    float t = 0.0;
    if (style == 0) {
        t = fract(length(c) * (4.0 + 6.0 * s) + s);
    } else if (style == 1) {
        float a = 6.2831 * s;
        t = fract(dot(c, vec2(cos(a), sin(a))) * (5.0 + 8.0 * s));
    } else if (style == 2) {
        t = fract(uv.y * (3.0 + 4.0 * s) + 0.12 * sin(uv.x * 6.2831 * (1.5 + 2.0 * s) + seed));
    } else if (style == 3) {
        vec2 g = uv * (4.0 + 5.0 * s);
        vec2 cell = floor(g);
        float best = 9.0;
        vec2 near = cell;
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                vec2 n = cell + vec2(float(x), float(y));
                vec2 p = n + vec2(hash(n), hash(n + 7.0));
                float d = length(g - p);
                if (d < best) { best = d; near = n; }
            }
        }
        t = hash(near);
    } else if (style == 4) {
        float glow = 0.0;
        for (int k = 0; k < 6; k++) {
            vec2 at = vec2(hash(vec2(float(k), 1.0)), hash(vec2(float(k), 2.0)));
            glow += 0.09 / (0.02 + length(uv - at));
        }
        t = clamp(glow * 0.12, 0.0, 1.0);
    } else if (style == 5) {
        float sun = smoothstep(0.16, 0.12, length(c - vec2(0.15 * (s - 0.5), 0.05)));
        t = clamp(uv.y * 0.85 + 0.1 * fbm(uv * 3.0) - sun * 0.6, 0.0, 1.0);
    } else if (style == 6) {
        t = fract((atan(c.y, c.x) / 6.2831 + 0.5) * (6.0 + 10.0 * s) + length(c) * 1.5);
    } else {
        t = fbm(uv * (2.0 + 3.0 * s) + vec2(fbm(uv * 3.0 + seed), fbm(uv * 3.0 - seed)));
    }
    float grain = 0.92 + 0.08 * noise(uv * 240.0);
    ALBEDO = paint(t) * grain;
    ROUGHNESS = 0.82;
}
