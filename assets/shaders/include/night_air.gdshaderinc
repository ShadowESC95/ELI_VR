// The air at night, seen from the ground: how much of the light from a direction gets through it,
// the twilight under a sun that has set, and the airglow of the upper air. The sky
// (space_sky.gdshader) is drawn with these, and the hot air over a desert (land_blend.gdshader,
// its mirage) bends the same twilight down onto the ground, so the two always agree.
//
// The air itself is handed in by the room (desert_observatory.gd NIGHT_AIR), which works out the
// moon's light through the same air: the share of each colour Rayleigh scattering takes, as
// wavelength^-4 at 680, 550 and 450 nm set relative to blue, and how thick the air is per unit of
// air mass. The defaults are a clear, dry night's.
uniform vec3 rayleigh = vec3(0.19, 0.45, 1.0);
uniform float optical_depth = 0.28;

// Method constants (not tuning): the Earth's radius over the height of the airglow layer, squared
// (6371/6471 km); how many radians deeper the sun goes for the twilight to fade by e (about four
// and a half degrees); and how high above the horizon (as a sine) the twilight band reaches
// before fading by e.
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
    return exp(-optical_depth * air * air_mass(d.y) * (0.35 + 0.65 * rayleigh));
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
    vec3 low = exp(-0.22 * air_mass(up) * rayleigh);
    return twilight * fade * band * low * vec3(1.0, 0.86, 0.7)
         + twilight * fade * fade * 0.06 * rayleigh * (0.3 + 0.7 * toward) * (1.0 - up * 0.5);
}

// Airglow: a thin shell of the upper air glowing, seen edge-on (thickest) near the horizon.
vec3 airglow_light(vec3 d, float airglow, float air) {
    float up = max(d.y, 0.0);
    float across = 1.0 / sqrt(max(1.0 - AIRGLOW_SHELL * (1.0 - up * up), 0.02));
    return airglow * vec3(0.24, 0.42, 0.26) * across * air_through(d, air);
}

// The moon, seen through the air: `moon` is its light here (its phase and the air's dimming and
// reddening already in it, worked out by the room with the light it casts), `moon_dir` the way to
// it, `sun_dir` the way to the sun that lights it. Its disc at its true size (MOON_RADIUS, a quarter
// of a degree), lit on the side towards the sun (Lommel-Seeliger, as the Moon's dusty surface
// reflects) with darker seas; its light scattered by the air across the sky, bluish and strongest
// near it and low down, and an aureole close round it from the haze. Method constants: the Moon's
// angular radius; and how bright its disc and the sky it lights are against its light on the ground,
// which sets the exposure of a moonlit night.
const float MOON_RADIUS = 0.00452;
const float MOON_DISC = 9.0;
const float MOON_SKY = 0.25;

vec3 moon_light_in(vec3 d, vec3 moon_dir, vec3 moon, vec3 sun_dir, float air) {
    float c = dot(d, moon_dir);
    float path = 1.0 - exp(-optical_depth * air * air_mass(d.y));
    vec3 glow = moon * path * (MOON_SKY * rayleigh * 0.75 * (1.0 + c * c)
                               + 0.4 * exp((c - 1.0) / 0.0008) + 0.08 * exp((c - 1.0) / 0.012));
    // the disc: where on the moon's face this ray lands
    vec3 across = normalize(cross(moon_dir, vec3(0.0, 1.0, 0.0)));
    vec3 upward = cross(across, moon_dir);
    vec3 off = d - moon_dir * c;
    vec2 at = vec2(dot(off, across), dot(off, upward)) / MOON_RADIUS;
    float r2 = dot(at, at);
    if (c > 0.0 && r2 < 1.0) {
        float facing = sqrt(1.0 - r2);
        vec3 normal = at.x * across + at.y * upward - facing * moon_dir;
        float lit = max(dot(normal, normalize(sun_dir)), 0.0);
        float seas = 0.72 + 0.28 * smoothstep(0.35, 0.65, vnoise(at * 2.3 + 7.0));
        float edge = smoothstep(1.0, 0.92, r2);
        glow += moon * MOON_DISC * seas * 2.0 * lit / (lit + facing + 1e-3) * edge;
    }
    return glow;
}
