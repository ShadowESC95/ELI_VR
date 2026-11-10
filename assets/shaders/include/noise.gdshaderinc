// Value noise the room shaders share, from the world position alone: no texture to fetch.
// Include it rather than writing another copy into a shader.

float hash12(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smooth noise in 0..1, one lattice cell per unit of p.
float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
               mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Two octaves: the shape and its grain.
float vnoise2(vec2 p) {
    return vnoise(p) * 0.65 + vnoise(p * 2.7 + 13.1) * 0.35;
}
