shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;

// Light through moving water, playing over whatever lies beneath.
uniform vec3 tint : source_color = vec3(0.55, 0.95, 1.0);
uniform float energy = 0.55;
uniform float scale = 0.22;

varying vec3 world_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float web(vec2 p, float t) {
    float v = 0.0;
    vec2 q = p;
    for (int i = 0; i < 3; i++) {
        q += vec2(sin(q.y * 1.3 + t * 0.7 + float(i)), cos(q.x * 1.1 - t * 0.6 + float(i) * 1.7)) * 0.6;
        v += 1.0 / (0.6 + abs(sin(q.x) * cos(q.y)) * 9.0);
    }
    return pow(v / 3.0, 4.0) * 5.0;
}

void fragment() {
    float c = web(world_pos.xz * scale * 11.0, TIME * 0.8);
    float up = clamp(NORMAL.y * 0.5 + 0.5, 0.0, 1.0);
    ALBEDO = tint * energy * c;
    ALPHA = clamp(c * 0.5, 0.0, 1.0);
}
