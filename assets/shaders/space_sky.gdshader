shader_type sky;

// The real night sky: NASA's star map as a panorama, turned to wherever the
// room wants the Milky Way.
uniform sampler2D stars : source_color, filter_linear_mipmap, repeat_enable;
uniform mat3 orient = mat3(1.0);
uniform float energy = 1.4;
uniform float contrast = 1.2;
uniform float lod = 0.5;

void sky() {
    vec3 d = normalize(orient * EYEDIR);
    vec2 uv = vec2(atan(d.x, -d.z) / TAU + 0.5, acos(clamp(d.y, -1.0, 1.0)) / PI);
    // A fixed level: the automatic one tears along the seam where u wraps.
    vec3 c = textureLod(stars, uv, lod).rgb;
    COLOR = pow(c, vec3(contrast)) * energy;
}
