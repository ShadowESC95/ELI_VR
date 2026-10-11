shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never;

void fragment() {
    vec2 uv = UV;
    vec3 night = mix(vec3(0.003,0.012,0.035), vec3(0.015,0.045,0.095), smoothstep(0.0,1.0,uv.y));
    float curtain = sin(uv.x * 31.0 + sin(uv.x * 7.0 + TIME * 0.08) * 2.2);
    float band = exp(-pow((uv.y - 0.63 - curtain * 0.035) * 12.0, 2.0));
    vec3 aurora = mix(vec3(0.08,1.0,0.55), vec3(0.25,0.45,1.0), 0.5 + 0.5*sin(uv.x*9.0));
    vec3 col = night + aurora * band * 0.65;
    ALBEDO = col;
    EMISSION = col * 1.25;
}
