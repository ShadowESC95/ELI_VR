shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

// A projected globe: grid lines, the land picked out in light, a scan line
// sweeping down it.
uniform sampler2D land_tex : source_color, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(0.39, 0.87, 1.0);
uniform float energy = 1.0;

void fragment() {
    vec2 cell = abs(fract(UV * vec2(36.0, 18.0)) - 0.5);
    float grid = smoothstep(0.455, 0.5, max(cell.x, cell.y));
    vec3 map = texture(land_tex, UV).rgb;
    float land = smoothstep(0.03, 0.12, map.g - map.b * 0.82);
    vec2 dots = abs(fract(UV * vec2(220.0, 110.0)) - 0.5);
    float stipple = step(max(dots.x, dots.y), 0.30);
    float scan = pow(0.5 + 0.5 * sin(UV.y * 9.0 - TIME * 0.9), 12.0);
    float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.2);
    float a = grid * 0.28 + land * stipple * 0.75 + rim * 0.55 + scan * 0.35;
    ALBEDO = tint * energy * a;
    ALPHA = clamp(a, 0.0, 1.0);
}
