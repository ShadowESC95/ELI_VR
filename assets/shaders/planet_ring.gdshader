shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

// The rings of a planet: many thin bands of ice and dust.
uniform vec3 tint : source_color = vec3(0.85, 0.78, 0.66);
uniform float inner = 380.0;
uniform float outer = 640.0;
uniform float brightness = 0.9;

float hash(float p) { return fract(sin(p * 91.345) * 47453.5453); }

void fragment() {
    float r = (length(UV) - inner) / (outer - inner);
    float bands = 0.0;
    float scale = 14.0;
    for (int i = 0; i < 4; i++) {
        float cell = floor(r * scale);
        bands += mix(hash(cell + float(i) * 17.0), hash(cell + 1.0 + float(i) * 17.0), smoothstep(0.0, 1.0, fract(r * scale)));
        scale *= 2.7;
    }
    bands /= 4.0;
    float gap = smoothstep(0.02, 0.0, abs(r - 0.56)) * 0.9;
    float edges = smoothstep(0.0, 0.05, r) * smoothstep(1.0, 0.92, r);
    float a = clamp((0.25 + bands * 0.9) * edges - gap, 0.0, 1.0);
    ALBEDO = tint * brightness * (0.6 + bands * 0.6);
    ALPHA = a * 0.85;
}
