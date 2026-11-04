shader_type spatial;

// Open ground made of two scanned surfaces (assets/materials): a base everywhere, and an
// over-layer where the slope, the height and a breakup noise say so: rock through the snow on a
// slope, moss in a hollow, sand lying only on the flats. Each is read from three sides (triplanar,
// in metres), and far off the same surface is read again at a coarser scale and mixed in, so the
// tiling never reads. Snow can sparkle and sand can ripple, both from the world position alone.
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
uniform vec2 ripple_dir = vec2(1.0, 0.4);
uniform float ripple_width = 0.35;      // metres from one ripple to the next
uniform float roughness_scale = 1.0;

varying vec3 world_pos;
varying vec3 world_normal;

float hash12(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
               mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

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
    if (ripples > 0.0) {
        vec2 along = normalize(ripple_dir);
        float wave = sin(dot(world_pos.xz, along) * (TAU / ripple_width) + vnoise(world_pos.xz * 0.7) * 5.0);
        bump.xy += along * wave * 0.14 * ripples * (1.0 - over) * smoothstep(60.0, 10.0, dist);
    }
    NORMAL_MAP = normalize(bump * 2.0 - 1.0) * 0.5 + 0.5;
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
}
