// Value noise the room shaders share, from the world position alone: no texture to fetch.
// Include it rather than writing another copy into a shader.

// A number in 0..1 for a lattice point; `s` makes a different set of them (a shader's own seed).
float hash12s(vec2 p, float s) {
    return fract(sin(dot(p, vec2(127.1, 311.7)) + s) * 43758.5453);
}

float hash12(vec2 p) {
    return hash12s(p, 0.0);
}

// Smooth noise in 0..1, one lattice cell per unit of p, of the set `s`.
float vnoises(vec2 p, float s) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12s(i, s), hash12s(i + vec2(1.0, 0.0), s), u.x),
               mix(hash12s(i + vec2(0.0, 1.0), s), hash12s(i + vec2(1.0, 1.0), s), u.x), u.y);
}

float vnoise(vec2 p) {
    return vnoises(p, 0.0);
}

// Two octaves: the shape and its grain.
float vnoise2(vec2 p) {
    return vnoise(p) * 0.65 + vnoise(p * 2.7 + 13.1) * 0.35;
}
