shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;

// The heart of ELI's presence: light flowing inside a sphere. How stirred ELI is sets how fast
// and how turbulent it flows; its voice brightens the veins as it speaks.
uniform vec3 tint : source_color = vec3(0.39, 0.87, 1.0);
uniform vec3 tint_deep : source_color = vec3(0.05, 0.18, 0.35);
uniform float energy = 1.0;
uniform float agitation = 0.3;
uniform float level = 0.0;

varying vec3 local_pos;

void vertex() {
    local_pos = VERTEX;
}

float hash(vec3 p) {
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
    vec3 i = floor(x);
    vec3 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash(i), hash(i + vec3(1.0, 0.0, 0.0)), f.x),
                   mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
               mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x),
                   mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = p * 2.03 + vec3(1.7, 9.2, 3.1);
        a *= 0.5;
    }
    return v;
}

void fragment() {
    float t = TIME * (0.2 + agitation * 1.1);
    vec3 p = normalize(local_pos) * 2.6;
    float swirl = fbm(p + vec3(t, -t * 0.7, t * 0.4));
    float veins = smoothstep(0.48, 0.78, fbm(p * 2.2 + swirl * (2.0 + agitation * 2.0) - vec3(0.0, t * 1.3, 0.0)));
    float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
    float rim = pow(1.0 - facing, 3.0);
    vec3 col = mix(tint_deep, tint, swirl) + tint * veins * (0.7 + level * 1.6) + vec3(1.0) * pow(facing, 8.0) * 0.3;
    float glow = (0.5 + 0.5 * swirl) * (0.75 + 0.35 * rim) * energy * (1.0 + level * 0.8);
    ALBEDO = col * glow;
    ALPHA = clamp(0.3 + 0.7 * facing * swirl + rim * 0.45, 0.0, 1.0);
}
