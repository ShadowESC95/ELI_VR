shader_type spatial;
render_mode cull_back;

// A fish swimming, done here so a whole school is one batch (kit/flock.gd): a wave runs back along
// its body, growing towards the tail (UV2.x, MeshKit.fish: 0 at the snout, 1 at the tail's tip),
// faster and wider while it swims hard, smaller while it coasts. Each fish's phase, how hard it is
// swimming and its pace come in INSTANCE_CUSTOM (x, y, z). Scales catch the light.
uniform float body = 0.3;           // metres from snout to tail
uniform float beat_hz = 3.0;        // tail beats a second
uniform float sway = 0.12;          // the tail's swing either way, as a share of the length
uniform float waves = 0.9;          // how many waves there are along the body at once

void vertex() {
    float t = UV2.x;
    float swim = INSTANCE_CUSTOM.y;
    float phase = TIME * beat_hz * INSTANCE_CUSTOM.z * (0.5 + 0.5 * swim) + INSTANCE_CUSTOM.x;
    float amp = body * sway * (0.3 + 0.7 * swim) * t * t;
    float s = TAU * (phase - t * waves);
    VERTEX.x += amp * sin(s);
    // the body's new slope turns its normal with it
    float slope = -amp * cos(s) * TAU * waves / body;
    NORMAL = normalize(NORMAL - vec3(0.0, 0.0, 1.0) * NORMAL.x * slope);
}

void fragment() {
    ALBEDO = COLOR.rgb;
    ROUGHNESS = 0.32;
    METALLIC = 0.35;
    SPECULAR = 0.6;
}
