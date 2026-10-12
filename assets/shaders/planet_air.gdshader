shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never;

// The glow of the atmosphere just outside the planet's edge. Drawn on a
// slightly larger sphere, from the inside.
uniform vec3 sun_dir = vec3(-0.85, 0.3, 0.2);
uniform vec3 air : source_color = vec3(0.32, 0.58, 1.0);
uniform float strength = 1.0;

varying vec3 world_normal;
varying vec3 world_pos;

void vertex() {
    world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec3 n = normalize(world_normal);
    vec3 v = normalize(CAMERA_POSITION_WORLD - world_pos);
    float through = clamp(dot(-n, v), 0.0, 1.0);
    float glow = pow(through, 2.5) * 2.2;
    float lit = smoothstep(-0.35, 0.3, dot(n, normalize(sun_dir)));
    ALBEDO = air * glow * lit * strength;
    ALPHA = clamp(glow * lit, 0.0, 1.0);
}
