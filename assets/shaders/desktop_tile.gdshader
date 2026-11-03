shader_type canvas_item;
render_mode blend_disabled;

// One tile of the desktop, put down as it came. Some captures leave alpha empty, so it is opaque.
void fragment() {
    COLOR = vec4(texture(TEXTURE, UV).rgb, 1.0);
}
