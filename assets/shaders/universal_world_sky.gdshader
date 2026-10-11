shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never;

uniform vec3 top_color : source_color = vec3(0.04, 0.12, 0.24);
uniform vec3 horizon_color : source_color = vec3(0.45, 0.32, 0.28);
uniform vec3 bottom_color : source_color = vec3(0.01, 0.015, 0.025);
uniform vec3 accent_color : source_color = vec3(0.25, 0.75, 1.0);

uniform float stars = 0.0;
uniform float nebula = 0.0;
uniform float cloud_amount = 0.0;
uniform float aurora = 0.0;
uniform float grid = 0.0;
uniform float exposure = 1.0;
uniform float seed = 1.0;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 345.45) + seed);
    p += dot(p, p + 34.345);
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
    float y = uv.y;

    float lower_t = smoothstep(0.0, 0.50, y);
    float upper_t = smoothstep(0.50, 1.0, y);
    vec3 low = mix(bottom_color, horizon_color, lower_t);
    vec3 col = mix(low, top_color, upper_t);

    float horizon_glow = exp(-pow(abs(y - 0.5) * 8.0, 2.0));
    col += horizon_color * horizon_glow * 0.14;

    if (cloud_amount > 0.001) {
        float c1 = noise(uv * vec2(10.0, 4.5) + vec2(TIME * 0.006, 0.0));
        float c2 = noise(uv * vec2(25.0, 9.0) - vec2(TIME * 0.004, 0.0));
        float cloud = smoothstep(0.48, 0.78, c1 * 0.68 + c2 * 0.32);
        cloud *= smoothstep(0.25, 0.72, y);
        col = mix(col, horizon_color * 1.15, cloud * cloud_amount * 0.38);
    }

    if (nebula > 0.001) {
        float n = noise(uv * vec2(7.0, 3.0) + 8.0);
        float band = exp(-pow(abs(y - 0.48 + 0.08 * sin(uv.x * 7.0)), 2.0) * 24.0);
        col += mix(accent_color * 0.12, accent_color * 0.55, n) * band * nebula;
    }

    // Dense stellar detail is rendered as real 3D MultiMesh volumes. The
    // background keeps only a faint stochastic dust component so no UV-grid
    // star pattern can become visible in the headset.
    if (stars > 0.001) {
        float dust = noise(uv * vec2(67.0, 29.0) + seed * 3.1);
        col += vec3(0.22, 0.30, 0.44) * pow(dust, 12.0) * stars * 0.16;
    }

    if (aurora > 0.001) {
        float curtain = sin(uv.x * 29.0 + sin(uv.x * 6.0 + TIME * 0.09) * 2.0);
        float band = exp(-pow((y - 0.64 - curtain * 0.035) * 11.0, 2.0));
        col += accent_color * band * aurora * 0.75;
    }

    if (grid > 0.001) {
        vec2 g = abs(fract(uv * vec2(72.0, 36.0)) - 0.5);
        float line = 1.0 - smoothstep(0.465, 0.497, max(g.x, g.y));
        col += accent_color * line * grid * 0.18;
    }

    col *= exposure;
    ALBEDO = col;
    EMISSION = col * 1.15;
}
