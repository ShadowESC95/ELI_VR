// The real night sky (NASA's star map, assets/space/starmap_8k.jpg) read in a direction. The sky
// (space_sky.gdshader) and anything that has to show the same stars (the black hole's bent light)
// read it here, turned by the same `orient` RoomBase.star_sky() made, so the two always agree.

vec2 starmap_uv(vec3 d) {
    return vec2(atan(d.x, -d.z) / TAU + 0.5, acos(clamp(d.y, -1.0, 1.0)) / PI);
}

// `lod` is a fixed mip level: the automatic one tears along the seam where u wraps.
vec3 starmap(sampler2D stars, mat3 orient, vec3 dir, float energy, float contrast, float lod) {
    vec3 c = textureLod(stars, starmap_uv(normalize(orient * dir)), lod).rgb;
    return pow(c, vec3(contrast)) * energy;
}
