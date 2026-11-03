shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, blend_mix, shadows_disabled;

// The desktop drawn in the room, where the headset's runtime cannot take it as a layer of its own
// (and in the flat window). Like that layer it is never hidden by the room: it is drawn after the
// room, whatever is nearer, and hands, pointers, panels and ELI are drawn after it.

uniform sampler2D view : source_color, filter_linear, repeat_disable;

void fragment() {
    ALBEDO = texture(view, UV).rgb;
    ALPHA = 1.0;
}
