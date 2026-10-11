shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 deep_color : source_color = vec3(0.005, 0.10, 0.18);
uniform vec3 crest_color : source_color = vec3(0.15, 0.48, 0.58);

void fragment() {
    vec2 uv = UV * 22.0;
    float w1 = sin(uv.x * 1.5 + TIME * 0.55) * 0.5 + 0.5;
    float w2 = sin((uv.x + uv.y) * 2.25 - TIME * 0.72) * 0.5 + 0.5;
    float w3 = sin(uv.y * 3.1 + TIME * 0.39) * 0.5 + 0.5;
    float wave = (w1 + w2 + w3) / 3.0;
    ALBEDO = mix(deep_color, crest_color, wave * 0.48);
    ROUGHNESS = mix(0.08, 0.28, wave);
    METALLIC = 0.03;
}
