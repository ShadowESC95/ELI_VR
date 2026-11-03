shader_type canvas_item;
render_mode blend_disabled;

// The desktop brought down to the size it is seen at: each pixel is the average of the desktop
// pixels it covers, so small text stays smooth and does not shimmer. At one desktop pixel to one
// pixel or larger it is a single sample.

uniform sampler2D desktop : filter_linear, repeat_disable;
uniform vec2 ratio = vec2(1.0);         // desktop pixels per pixel here, across and down
uniform vec2 desktop_size = vec2(1.0);

void fragment() {
    vec2 taps = clamp(ceil(ratio * 0.5), vec2(1.0), vec2(8.0));   // each linear sample covers two
    vec2 footprint = ratio / desktop_size;
    vec3 sum = vec3(0.0);
    for (int j = 0; j < int(taps.y); j++) {
        for (int i = 0; i < int(taps.x); i++) {
            vec2 offset = (vec2(float(i), float(j)) + 0.5) / taps - 0.5;
            sum += textureLod(desktop, UV + offset * footprint, 0.0).rgb;
        }
    }
    COLOR = vec4(sum / (taps.x * taps.y), 1.0);
}
