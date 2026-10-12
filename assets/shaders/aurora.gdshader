shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

// A curtain of northern light: rays that shimmer and sway.
uniform vec3 low : source_color = vec3(0.2, 1.0, 0.55);
uniform vec3 high : source_color = vec3(0.5, 0.3, 1.0);
uniform float energy = 1.0;
uniform float seed = 0.0;

float hash(float p) { return fract(sin(p * 127.1 + seed) * 43758.5453); }
float noise(float p) { float i = floor(p); float f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(hash(i), hash(i + 1.0), f); }

void fragment() {
    float along = UV.x * 0.02;
    float t = TIME * 0.05;
    float rays = noise(along * 26.0 + t * 3.0) * 0.6 + noise(along * 70.0 - t * 5.0) * 0.4;
    float fold = noise(along * 3.0 + t) * 0.8 + 0.2;
    float up = UV.y;
    // bright along the bottom edge, thinning out upwards
    float body = smoothstep(0.0, 0.06, up) * pow(1.0 - up, 1.7 + rays * 2.0);
    float ends = smoothstep(0.0, 0.08, fract(UV.x * 0.002 + 0.5)) ;
    float a = body * (0.25 + rays * 0.9) * fold;
    ALBEDO = mix(low, high, smoothstep(0.15, 0.85, up)) * a * energy;
    ALPHA = clamp(a, 0.0, 1.0);
}
