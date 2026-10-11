shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.12, 0.24, 0.55);
uniform vec3 secondary_color : source_color = vec3(0.65, 0.78, 0.95);
uniform float seed = 1.0;
uniform float self_light = 0.10;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 345.45) + seed);
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
        mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
        f.y
    );
}

void fragment() {
    vec2 p = UV * vec2(18.0, 9.0);
    float n = noise(p) * 0.62;
    n += noise(p * 2.7 + 4.0) * 0.27;
    n += noise(p * 7.0) * 0.11;

    float bands = 0.5 + 0.5 * sin((UV.y + n * 0.10) * 44.0);
    float mix_value = clamp(n * 0.82 + bands * 0.24, 0.0, 1.0);
    vec3 col = mix(base_color, secondary_color, mix_value);

    ALBEDO = col;
    ROUGHNESS = 0.70;
    METALLIC = 0.01;
    EMISSION = col * self_light;
}
