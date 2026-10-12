shader_type spatial;
render_mode unshaded;

// Open water. The surface is a pattern of moving ripples, and what it
// shows is the room's own sky, mirrored: the sunset, the sun's path on the
// waves. The same photograph is used for the sky, so the two always agree.
uniform sampler2D photo : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 deep : source_color = vec3(0.02, 0.07, 0.10);
uniform float chop = 0.06;
uniform float exposure = 1.0;
uniform float lod = 1.5;

varying vec3 world_pos;

vec2 swell(vec2 p, vec2 dir, float freq, float speed) {
    float phase = dot(p, dir) * freq + TIME * speed;
    return dir * cos(phase) * freq;
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec2 p = world_pos.xz;
    float far = length(p);
    // slopes of a handful of crossing wave trains; finer ones fade with distance
    vec2 slope = swell(p, normalize(vec2(1.0, 0.3)), 0.35, 0.9) * 1.0
        + swell(p, normalize(vec2(-0.4, 1.0)), 0.6, 1.2) * 0.6
        + swell(p, normalize(vec2(0.7, -0.7)), 1.7, 2.0) * 0.25 * exp(-far / 120.0)
        + swell(p, normalize(vec2(-0.9, -0.2)), 4.3, 3.1) * 0.10 * exp(-far / 40.0);
    vec3 n = normalize(vec3(-slope.x * chop, 1.0, -slope.y * chop));

    vec3 view = normalize(world_pos - CAMERA_POSITION_WORLD);
    vec3 r = reflect(view, n);
    r.y = abs(r.y);
    vec2 uv = vec2(atan(r.x, -r.z) / TAU + 0.5, acos(clamp(r.y, -1.0, 1.0)) / PI);
    vec3 sky = textureLod(photo, uv, lod).rgb * exposure;

    float facing = clamp(dot(-view, n), 0.0, 1.0);
    float mirror = 0.04 + 0.96 * pow(1.0 - facing, 4.0);
    ALBEDO = mix(deep, sky, mirror);
}
