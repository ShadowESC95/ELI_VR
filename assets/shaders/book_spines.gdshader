shader_type spatial;

// Books on a shelf, drawn together: each its own leather (the instance colour), a gilt band
// across the spine near the top and bottom, and a few of them lit from within, brightening and
// fading slowly (instance custom: r how lit, g where in its pulse it starts). The mesh is a box
// of side 1, so the vertex position says where on the book a point is.

uniform vec3 tint : source_color = vec3(0.39, 0.87, 1.0);
uniform float energy = 1.4;
uniform float pace = 0.35;

varying float height_on_spine;
varying float on_spine;
varying float lit;
varying float phase;

void vertex() {
    height_on_spine = VERTEX.y;
    on_spine = step(0.5, NORMAL.z);
    lit = INSTANCE_CUSTOM.r;
    phase = INSTANCE_CUSTOM.g;
}

void fragment() {
    float h = abs(height_on_spine);
    float band = (smoothstep(0.30, 0.31, h) - smoothstep(0.35, 0.36, h)) * on_spine;
    ALBEDO = mix(COLOR.rgb, vec3(0.74, 0.56, 0.26), band);
    METALLIC = band * 0.8;
    ROUGHNESS = mix(0.74, 0.32, band);
    float pulse = 0.55 + 0.45 * sin(TIME * pace + phase);
    EMISSION = tint * energy * lit * pulse * (0.3 + 0.7 * on_spine);
}
