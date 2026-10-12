shader_type spatial;
render_mode unshaded, cull_back;

// Earth from orbit: day side, drifting cloud, city lights on the night side
// and the thin blue line of air at the edge.
uniform sampler2D day_tex : source_color, filter_linear_mipmap;
uniform sampler2D night_tex : source_color, filter_linear_mipmap;
uniform sampler2D cloud_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 sun_dir = vec3(-0.85, 0.3, 0.2);
uniform vec3 air : source_color = vec3(0.32, 0.58, 1.0);
uniform float cloud_shift = 0.0;
uniform float brightness = 1.0;

varying vec3 world_normal;
varying vec3 world_pos;

void vertex() {
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec3 n = normalize(world_normal);
    vec3 v = normalize(CAMERA_POSITION_WORLD - world_pos);
    float ndl = dot(n, normalize(sun_dir));
    float day = smoothstep(-0.10, 0.22, ndl);

    vec3 ground = texture(day_tex, UV).rgb;
    float cloud = texture(cloud_tex, UV + vec2(cloud_shift, 0.0)).r;
    vec3 lit = mix(ground, vec3(0.95), cloud * 0.9) * (0.02 + 1.15 * max(ndl, 0.0));

    vec3 night = texture(night_tex, UV).rgb;
    float lamps = pow(max(max(night.r, night.g) - 0.08, 0.0) * 1.6, 1.5);
    vec3 cities = vec3(1.0, 0.76, 0.45) * lamps * (1.0 - day) * (1.0 - cloud * 0.7);

    float edge = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 3.2);
    vec3 haze = air * edge * (0.05 + 1.3 * smoothstep(-0.25, 0.35, ndl));

    ALBEDO = (lit * day + cities + haze) * brightness;
}
