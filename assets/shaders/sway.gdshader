shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

// A leaf or frond that moves: kelp in a current, ferns in a breeze. The
// higher up the blade, the further it swings.
uniform sampler2D leaf : source_color, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(1.0);
uniform float reach = 0.25;
uniform float pace = 0.6;
uniform float glow = 0.0;

void vertex() {
    vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float lift = 1.0 - UV.y;
    float swing = sin(TIME * pace + world.x * 0.4 + world.z * 0.3) + 0.5 * sin(TIME * pace * 2.3 + world.z * 0.9);
    VERTEX.x += swing * reach * lift * lift;
    VERTEX.z += cos(TIME * pace * 0.7 + world.x * 0.5) * reach * 0.6 * lift * lift;
}

void fragment() {
    vec4 c = texture(leaf, UV);
    ALBEDO = c.rgb * tint;
    ALPHA = c.a;
    ALPHA_SCISSOR_THRESHOLD = 0.4;
    ROUGHNESS = 0.7;
    EMISSION = c.rgb * tint * glow;
    BACKLIGHT = c.rgb * 0.4;
}
