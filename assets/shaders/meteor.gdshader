shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

// A meteor: a short-lived streak along its path, a bright head and a train fading behind it.
// The quad is laid along `way` (its length) and turned about that line to face the eye (its width).
uniform vec3 way = vec3(1.0, 0.0, 0.0);     // the direction it is falling, in the world
uniform float length_m = 60.0;              // the streak's length
uniform float width_m = 1.2;
uniform vec3 tint : source_color = vec3(1.0, 0.97, 0.9);
uniform float energy = 3.0;

void vertex() {
    vec3 centre = MODEL_MATRIX[3].xyz;
    vec3 along = normalize(way);
    vec3 side = normalize(cross(along, CAMERA_POSITION_WORLD - centre));
    vec3 world = centre + along * VERTEX.x * length_m + side * VERTEX.y * width_m;
    POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
    float head = UV.x;                       // 0 at the end of the train, 1 at the head
    float across = abs(UV.y - 0.5) * 2.0;
    float train = pow(head, 3.0) * exp(-across * across * 6.0);
    float core = exp(-pow((1.0 - head) * 18.0, 2.0)) * exp(-across * across * 3.0);
    ALBEDO = tint * energy * (train + 2.0 * core);
}
