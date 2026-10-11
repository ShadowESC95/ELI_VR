shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never;

uniform vec3 grid_color : source_color = vec3(0.08, 1.0, 0.38);

float hash21(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

void fragment() {
    vec2 uv = UV;
    vec2 g = abs(fract(uv * vec2(72.0, 36.0)) - 0.5);
    float line = 1.0 - smoothstep(0.46, 0.495, max(g.x, g.y));

    float columns = step(0.86, hash21(vec2(floor(uv.x * 110.0), floor((uv.y + TIME * 0.035) * 55.0))));
    float horizon = exp(-abs(uv.y - 0.5) * 9.0);

    vec3 col = vec3(0.0005, 0.004, 0.001);
    col += grid_color * line * 0.18;
    col += grid_color * columns * 0.32;
    col += grid_color * horizon * 0.08;

    ALBEDO = col;
    EMISSION = col * 2.5;
}
