shader_type spatial;
render_mode unshaded;

// The status lights on a bank of racks, drawn together. Each light blinks at its own rate and
// phase (instance custom: r its phase, g its rate) in its own colour (the instance colour); `pace`
// makes the whole bank livelier, blinking faster and burning brighter. It is the room's own and
// stays as the room was built: how ELI is shows on ELI and its own light (eli_presence.gd), not on
// the room's fixtures.

uniform float pace = 0.3;
uniform float energy = 2.2;

varying float phase;
varying float rate;

void vertex() {
    phase = INSTANCE_CUSTOM.r;
    rate = INSTANCE_CUSTOM.g;
}

void fragment() {
    float quick = rate * (0.35 + 1.8 * pace);
    float on = step(0.45, fract(TIME * quick + phase));
    ALBEDO = COLOR.rgb * mix(0.12, energy * (0.7 + 0.6 * pace), on);
}
