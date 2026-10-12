shader_type spatial;
render_mode unshaded, cull_back;

// A banded gas giant, lit from one side.
uniform vec3 sun_dir = vec3(0.6, 0.35, 0.5);
uniform vec3 band_a : source_color = vec3(0.80, 0.66, 0.50);
uniform vec3 band_b : source_color = vec3(0.52, 0.38, 0.30);
uniform vec3 band_c : source_color = vec3(0.92, 0.86, 0.74);
uniform vec3 air : source_color = vec3(0.95, 0.75, 0.55);
uniform float drift = 0.0;

varying vec3 world_normal;
varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.1; a *= 0.5; } return v; }

void vertex() {
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 uv = vec2(UV.x * 2.0 + drift, UV.y);
    float swirl = fbm(uv * vec2(6.0, 22.0)) * 0.06 + fbm(uv * vec2(18.0, 60.0)) * 0.015;
    float lat = uv.y + swirl;
    float bands = sin(lat * 46.0) * 0.5 + 0.5;
    float broad = sin(lat * 13.0 + 1.3) * 0.5 + 0.5;
    vec3 col = mix(band_a, band_b, smoothstep(0.25, 0.75, bands));
    col = mix(col, band_c, broad * 0.5);
    col *= 0.82 + 0.3 * fbm(uv * vec2(40.0, 110.0));
    float storm = smoothstep(0.045, 0.0, length((uv - vec2(1.25 + drift, 0.62)) * vec2(0.5, 1.6)));
    col = mix(col, vec3(0.75, 0.36, 0.24), storm * 0.8);

    vec3 n = normalize(world_normal);
    vec3 v = normalize(CAMERA_POSITION_WORLD - world_pos);
    float ndl = dot(n, normalize(sun_dir));
    float lit = smoothstep(-0.08, 0.45, ndl);
    float edge = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 3.0);
    ALBEDO = col * (0.015 + 1.1 * lit) + air * edge * 0.5 * smoothstep(-0.2, 0.3, ndl);
}
