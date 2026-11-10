shader_type spatial;
render_mode cull_back;

// A bird's wing beat and glide, done here so a whole flock is one batch (kit/flock.gd). Each wing
// vertex knows how far out along its wing it is (UV2.x, MeshKit.bird): the arm turns about the
// shoulder, the hand about the wrist on top of that, a little behind the arm in the beat. Gliding,
// the wings are held in the kind's glide (a gull's crook: arm raised, hand down). Each bird's own
// phase, how much it is flapping and its pace come in INSTANCE_CUSTOM (x, y, z). Light shows
// through the feathers of a wing against the sun.
uniform float shoulder = 0.05;      // metres out from the middle where each wing hinges
uniform float wrist = 0.28;         // metres out from the shoulder where the hand hinges
uniform float beat_hz = 3.0;        // wing beats a second
uniform float arm_beat = 0.6;       // radians the arm swings either way in a beat
uniform float hand_beat = 0.5;      // and the hand on top of it
uniform float glide_arm = 0.17;     // radians the arm is raised when gliding
uniform float glide_hand = -0.4;    // and the hand's angle against the arm
uniform float translucency = 0.35;

varying float wing;

void vertex() {
    float s = UV2.x;
    wing = abs(s);
    if (wing > 0.0) {
        float side = sign(s);
        float flap = INSTANCE_CUSTOM.y;
        float t = TIME * beat_hz * INSTANCE_CUSTOM.z + INSTANCE_CUSTOM.x;
        // the downstroke, which carries the bird, takes a little less of the beat than the upstroke
        float beat = sin(TAU * t + 0.35 * sin(TAU * t));
        float lag = sin(TAU * t - 0.7 + 0.35 * sin(TAU * t - 0.7));
        float arm = mix(glide_arm, 0.08 + arm_beat * beat, flap);
        float hand = arm + mix(glide_hand, hand_beat * lag, flap);
        float out_m = max(abs(VERTEX.x) - shoulder, 0.0);
        float bend = out_m > wrist ? hand : arm;
        vec2 along = vec2(cos(arm), sin(arm)) * min(out_m, wrist) + vec2(cos(hand), sin(hand)) * max(out_m - wrist, 0.0);
        vec2 thick = vec2(-sin(bend), cos(bend)) * VERTEX.y;
        VERTEX.x = side * (shoulder + along.x + thick.x);
        VERTEX.y = along.y + thick.y;
        vec2 n = vec2(NORMAL.x * side, NORMAL.y);
        n = vec2(n.x * cos(bend) - n.y * sin(bend), n.x * sin(bend) + n.y * cos(bend));
        NORMAL = vec3(n.x * side, n.y, NORMAL.z);
    }
}

void fragment() {
    ALBEDO = COLOR.rgb;
    ROUGHNESS = 0.85;
    SPECULAR = 0.25;
    BACKLIGHT = COLOR.rgb * translucency * step(0.001, wing);
}
