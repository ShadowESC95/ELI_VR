shader_type spatial;
render_mode unshaded;

// The status lights on a bank of racks, drawn together. Each light blinks at its own rate and
// phase (instance custom: r its phase, g its rate) in its own colour (the instance colour); how
// busy ELI is makes them all blink faster and burn brighter.

uniform float busy = 0.3;
uniform float energy = 2.2;

varying float phase;
varying float rate;

void vertex() {
    phase = INSTANCE_CUSTOM.r;
    rate = INSTANCE_CUSTOM.g;
}

void fragment() {
    float pace = rate * (0.35 + 1.8 * busy);
    float on = step(0.45, fract(TIME * pace + phase));
    ALBEDO = COLOR.rgb * mix(0.12, energy * (0.7 + 0.6 * busy), on);
}
