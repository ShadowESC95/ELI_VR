shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never;

uniform vec3 atmosphere_color : source_color = vec3(0.25, 0.65, 1.0);
uniform float intensity = 0.52;

void fragment() {
    float fresnel = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 2.6);
    ALBEDO = atmosphere_color;
    EMISSION = atmosphere_color * fresnel * intensity;
    ALPHA = fresnel * 0.55;
}
