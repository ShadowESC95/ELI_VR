shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

// The sun of a made world: a disc of colour cut by rising lines.
uniform vec3 top : source_color = vec3(1.0, 0.85, 0.3);
uniform vec3 bottom : source_color = vec3(1.0, 0.2, 0.6);
uniform float energy = 1.3;

void fragment() {
    vec2 p = UV - 0.5;
    float r = length(p) * 2.0;
    float disc = smoothstep(1.0, 0.985, r);
    float y = 1.0 - UV.y;
    float cuts = step(0.5, fract(y * 14.0 + TIME * 0.12)) + step(0.52, y);
    float halo = pow(max(1.0 - r * 0.72, 0.0), 3.0) * 0.25;
    float a = disc * clamp(cuts, 0.0, 1.0);
    ALBEDO = mix(bottom, top, y) * energy * (a + halo);
    ALPHA = clamp(a + halo, 0.0, 1.0);
}
