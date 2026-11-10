shader_type spatial;

#include "res://assets/shaders/include/noise.gdshaderinc"
#include "res://assets/shaders/include/night_air.gdshaderinc"

// Open ground made of two scanned surfaces (assets/materials): a base everywhere, and an
// over-layer where the slope, the height and a breakup noise say so: rock through the snow on a
// slope, moss in a hollow, sand lying only on the flats. Each is read from three sides (triplanar,
// in metres), and far off the same surface is read again at a coarser scale and mixed in, so the
// tiling never reads. Snow can sparkle. Sand can carry wind ripples: low on the windward side,
// steeper on the lee, square across the wind, gone from a dune's slip face where the sand slides,
// and faded before they are finer than a pixel. The wind can stream loose sand across the ground
// (`drift`), and the ground far off can shimmer in rising heat (`haze`), the air over it bending
// light from the horizon's sky down onto it (`mirage`).
uniform sampler2D base_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D over_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D over_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D over_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float base_tile = 3.0;          // metres one repeat of the base covers
uniform float over_tile = 2.0;
uniform vec3 base_tint : source_color = vec3(1.0);
uniform vec3 over_tint : source_color = vec3(1.0);
uniform float slope_from = 0.3;         // the over-layer begins where the slope (1 - up) passes this
uniform float slope_to = 0.55;          // and is whole past this
uniform float over_on_slopes = 1.0;     // 1: the over-layer takes the slopes; 0: it takes the flats
uniform float height_from = -1000.0;    // and only above this height (left wide open: everywhere)
uniform float height_to = -999.0;
uniform float breakup = 0.4;            // how much a noise frays the edge between the two
uniform float far_blend = 40.0;         // metres at which the coarse reading is half the mix
uniform float sparkle = 0.0;            // snow: specks catching the light as you move
uniform float ripples = 0.0;            // sand: wind ripples, as a tilt of the surface
uniform vec2 ripple_dir = vec2(1.0, 0.4);   // the way the wind blows
uniform float ripple_width = 0.35;      // metres from one ripple to the next
uniform float drift = 0.0;              // metres a second loose sand streams over the ground with the wind
uniform float haze = 0.0;               // how much the ground far off shimmers in rising heat
uniform float mirage = 0.0;             // the room's twilight (as its sky has it) the hot air bends onto the ground
uniform vec3 mirage_sun = vec3(0.0, -1.0, 0.0);   // and the way to the set sun, as its sky has it
uniform float roughness_scale = 1.0;

varying vec3 world_pos;
varying vec3 world_normal;

// A texture read from the three sides a surface faces, weighted by how squarely it faces each.
vec4 tri(sampler2D tex, vec3 p, vec3 n, float tile) {
    vec3 w = pow(abs(n), vec3(4.0));
    w /= (w.x + w.y + w.z);
    return texture(tex, p.zy / tile) * w.x + texture(tex, p.xz / tile) * w.y + texture(tex, p.xy / tile) * w.z;
}

// The same, with a coarser reading mixed in far off (seven times the scale: the two never line up).
vec4 tri_far(sampler2D tex, vec3 p, vec3 n, float tile, float dist) {
    float k = smoothstep(far_blend * 0.5, far_blend * 2.0, dist);
    return mix(tri(tex, p, n, tile), tri(tex, p, n, tile * 7.0), k);
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
    if (haze > 0.0) {
        // far ground wavers up and down as hot air rises off it: nothing near, more the further
        // and the more nearly edge-on it is seen
        vec3 eye = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
        float dist = length(world_pos - eye);
        float graze = 1.0 - clamp(abs(world_pos.y - eye.y) / max(dist, 1.0) * 8.0, 0.0, 1.0);
        float boil = vnoise(world_pos.xz * 0.06 + vec2(TIME * 0.9, -TIME * 0.7)) - 0.5;
        float wave = boil + 0.5 * (vnoise(world_pos.xz * 0.17 - vec2(TIME * 1.7, TIME * 1.3)) - 0.5);
        float lift = wave * haze * dist * 0.0022 * smoothstep(60.0, 240.0, dist) * graze;
        VERTEX.y += lift;
        world_pos.y += lift;
    }
}

void fragment() {
    float dist = length(world_pos - CAMERA_POSITION_WORLD);
    vec3 n = normalize(world_normal);
    float slope = 1.0 - n.y;
    float fray = (vnoise(world_pos.xz * 0.18) * 2.0 - 1.0) * breakup;
    float by_slope = smoothstep(slope_from, slope_to, slope + fray * (slope_to - slope_from));
    by_slope = mix(1.0 - by_slope, by_slope, over_on_slopes);
    float by_height = smoothstep(height_from, height_to, world_pos.y + fray * (height_to - height_from));
    float over = clamp(by_slope * by_height, 0.0, 1.0);

    vec4 albedo = mix(tri_far(base_albedo, world_pos, n, base_tile, dist) * vec4(base_tint, 1.0),
                      tri_far(over_albedo, world_pos, n, over_tile, dist) * vec4(over_tint, 1.0), over);
    vec4 orm = mix(tri_far(base_orm, world_pos, n, base_tile, dist), tri_far(over_orm, world_pos, n, over_tile, dist), over);
    // the land is laid out in metres along x and z (MeshKit.terrain), so its tangent frame is the
    // top-down reading of the normal maps
    vec3 bump = mix(texture(base_normal, world_pos.xz / base_tile).xyz, texture(over_normal, world_pos.xz / over_tile).xyz, over);
    vec2 wind = normalize(ripple_dir);
    if (ripples > 0.0) {
        // ripples run square across the wind, their crests wandering and forking; each rises
        // gently on its windward side and drops on its lee. None lie on a slip face (a slope facing
        // down the wind, steeper than the windward side ever is), and they fade before a ripple
        // is finer than a few pixels.
        float phase = dot(world_pos.xz, wind) / ripple_width + vnoise(world_pos.xz * 0.7) * 0.8
                      + vnoise(world_pos.xz * 0.11) * 3.0;
        float f = fract(phase);
        float tilt = mix(0.45, -1.15, smoothstep(0.66, 0.8, f)) * (1.0 - smoothstep(0.92, 1.0, f));
        float lee = smoothstep(0.08, 0.16, slope) * smoothstep(0.1, 0.5, dot(n.xz, wind) / max(length(n.xz), 1e-4));
        float fine = 1.0 - smoothstep(0.25, 0.6, fwidth(phase));
        bump.xy += wind * tilt * 0.16 * ripples * (1.0 - over) * (1.0 - lee) * fine;
    }
    NORMAL_MAP = normalize(bump * 2.0 - 1.0) * 0.5 + 0.5;
    if (drift > 0.0) {
        // streamers of loose sand blown along the ground, thickest where the wind meets the ground
        // squarely (windward slopes, crests), thin in the lee, lighter than the sand lying still
        vec2 across = vec2(-wind.y, wind.x);
        vec2 q = vec2(dot(world_pos.xz, wind) * 0.12 - TIME * drift * 0.12, dot(world_pos.xz, across) * 1.4);
        float streak = smoothstep(0.55, 0.85, vnoise2(q) * 0.8 + vnoise(q * vec2(0.3, 0.2) + TIME * 0.05) * 0.4);
        float exposed = 0.4 + 0.6 * clamp(1.0 - dot(n.xz, wind) * 4.0, 0.0, 1.0);
        albedo.rgb = mix(albedo.rgb, albedo.rgb * 1.35 + 0.02, streak * exposed * (1.0 - over) * smoothstep(90.0, 15.0, dist));
    }
    ALBEDO = albedo.rgb;
    AO = orm.r;
    ROUGHNESS = clamp(orm.g * roughness_scale, 0.03, 1.0);
    METALLIC = orm.b;
    if (sparkle > 0.0) {
        // specks of light in the snow that come and go as the head moves
        vec3 to_eye = normalize(CAMERA_POSITION_WORLD - world_pos);
        float speck = hash12(floor(world_pos.xz * 70.0) + floor(to_eye.xz * 9.0));
        float glint = step(0.994, speck) * smoothstep(25.0, 4.0, dist) * (1.0 - over);
        EMISSION = vec3(glint) * sparkle * 1.5;
    }
    if (haze > 0.0) {
        // where the ground is seen nearly edge on and far off, the hot air over it bends the
        // horizon's sky down: a shimmering sheet of sky lying on the ground, brightest under the
        // brightest of the sky
        vec3 view = normalize(world_pos - CAMERA_POSITION_WORLD);
        float graze = smoothstep(-0.035, -0.004, view.y);
        vec3 bent = normalize(vec3(view.x, abs(view.y), view.z));
        float flicker = 0.6 + 0.4 * vnoise(world_pos.xz * vec2(0.02, 0.2) + vec2(TIME * 0.6, 0.0));
        EMISSION += twilight_light(bent, mirage_sun, mirage) * haze * graze * flicker * smoothstep(150.0, 400.0, dist);
    }
}
