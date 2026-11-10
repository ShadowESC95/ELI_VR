// The air at night, seen from the ground: how much of the light from a direction gets through it,
// the twilight under a sun that has set, and the airglow of the upper air. The sky
// (space_sky.gdshader) is drawn with these, and the hot air over a desert (land_blend.gdshader,
// its mirage) bends the same twilight down onto the ground, so the two always agree.
//
// Method constants of the air (not tuning): the share of each colour Rayleigh scattering takes,
// as wavelength^-4 at 680, 550 and 450 nm, set relative to blue; how thick the air is per unit of
// air mass; the Earth's radius over the height of the airglow layer, squared (6371/6471 km); how
// many radians deeper the sun goes for the twilight to fade by e (about four and a half degrees);
// and how high above the horizon (as a sine) the twilight band reaches before fading by e.
const vec3 RAYLEIGH = vec3(0.19, 0.45, 1.0);
const float OPTICAL_DEPTH = 0.28;
const float AIRGLOW_SHELL = 0.9694;
const float TWILIGHT_FADE = 0.0785;
const float TWILIGHT_BAND = 0.11;

// Air mass along a line of sight `up` (the sine of its height above the horizon): plane-parallel,
// softened at the horizon.
float air_mass(float up) {
    return 1.0 / (max(up, 0.0) + 0.035);
}

// The share of light from direction `d` that comes through the air (stars dim and redden low down).
vec3 air_through(vec3 d, float air) {
    return exp(-OPTICAL_DEPTH * air * air_mass(d.y) * (0.35 + 0.65 * RAYLEIGH));
}

// The twilight seen in direction `d` with the sun towards `sun_dir` under the horizon: brightest
// at the horizon under the sun, warm low down where the long path through the air has taken the
// blue out, fading with height and with how far the sun has set; and the high sky's blue.
vec3 twilight_light(vec3 d, vec3 sun_dir, float twilight) {
    float up = max(d.y, 0.0);
    float depression = max(-asin(clamp(sun_dir.y, -1.0, 1.0)), 0.0);
    vec2 look = normalize(d.xz + vec2(1e-5));
    vec2 sun_way = normalize(sun_dir.xz + vec2(1e-5));
    float toward = 0.5 + 0.5 * dot(look, sun_way);
    float fade = exp(-depression / TWILIGHT_FADE);
    float band = exp(-up / TWILIGHT_BAND) * (0.1 + 0.9 * toward * toward * toward);
    vec3 low = exp(-0.22 * air_mass(up) * RAYLEIGH);
    return twilight * fade * band * low * vec3(1.0, 0.86, 0.7)
         + twilight * fade * fade * 0.06 * RAYLEIGH * (0.3 + 0.7 * toward) * (1.0 - up * 0.5);
}

// Airglow: a thin shell of the upper air glowing, seen edge-on (thickest) near the horizon.
vec3 airglow_light(vec3 d, float airglow, float air) {
    float up = max(d.y, 0.0);
    float across = 1.0 / sqrt(max(1.0 - AIRGLOW_SHELL * (1.0 - up * up), 0.02));
    return airglow * vec3(0.24, 0.42, 0.26) * across * air_through(d, air);
}
