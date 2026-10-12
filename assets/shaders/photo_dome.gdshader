shader_type spatial;
render_mode unshaded, cull_front, fog_disabled;

// A 360 degree photograph of a real place, as the world around the room.
// A plain panorama sits at infinity, so the ground slides with you and looks
// painted. Here the photo's ground is laid on the real ground out to
// `reach` metres and stands up as a wall beyond that, so what is near stays
// put when you walk or lean, in each eye separately.
uniform sampler2D photo : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 eye = vec3(0.0, 1.7, 0.0);   // where the camera stood for the photo
uniform float ground_y = 0.0;
uniform float reach = 30.0;
uniform float yaw = 0.0;
uniform float exposure = 1.0;
uniform float lod = 0.3;
uniform vec3 wash : source_color = vec3(1.0);

varying vec3 world_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec3 cam = CAMERA_POSITION_WORLD;
    vec3 ray = normalize(world_pos - cam);
    vec3 d = ray;

    vec3 oc = cam - eye;
    float b = dot(oc, ray);
    float disc = b * b - (dot(oc, oc) - reach * reach);
    if (disc > 0.0) {
        vec3 hit = cam + ray * (-b + sqrt(disc));
        if (ray.y < -0.0001) {
            float t = (ground_y - cam.y) / ray.y;
            vec3 ground = cam + ray * t;
            if (t > 0.0 && distance(ground, eye) < reach) {
                hit = ground;
            }
        }
        d = normalize(hit - eye);
    }

    float s = sin(yaw);
    float c = cos(yaw);
    d = vec3(c * d.x - s * d.z, d.y, s * d.x + c * d.z);
    vec2 uv = vec2(atan(d.x, -d.z) / TAU + 0.5, acos(clamp(d.y, -1.0, 1.0)) / PI);
    ALBEDO = textureLod(photo, uv, lod).rgb * exposure * wash;
}
