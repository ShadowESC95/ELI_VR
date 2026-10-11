shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never;

void fragment() {
    vec2 uv = UV;
    vec3 deep = vec3(0.001, 0.028, 0.045);
    vec3 shallow = vec3(0.015, 0.22, 0.28);
    float rays = pow(max(0.0, sin(uv.x * 44.0 + TIME * 0.12) * 0.5 + 0.5), 14.0);
    float up = smoothstep(0.15, 1.0, uv.y);
    vec3 col = mix(deep, shallow, up);
    col += vec3(0.08, 0.30, 0.34) * rays * up * 0.18;
    ALBEDO = col;
    EMISSION = col * 0.55;
}
