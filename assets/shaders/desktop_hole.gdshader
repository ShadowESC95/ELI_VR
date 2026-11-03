shader_type spatial;
render_mode unshaded, blend_mul, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled;

// Where the desktop is, the room is cleared to nothing (colour and alpha), so the headset's
// compositor shows the desktop's own layer behind it there. Hands, pointers, panels and ELI are
// drawn after this, over the desktop.

void fragment() {
    ALBEDO = vec3(0.0);
    ALPHA = 0.0;
}
