shader_type sky;

#include "res://assets/shaders/include/starmap.gdshaderinc"
#include "res://assets/shaders/include/night_air.gdshaderinc"

// The real night sky: NASA's star map as a panorama, turned to wherever the
// room wants the Milky Way. In space that is all there is. Seen from the
// ground (a room sets `air` above 0) the sky is seen through the air: stars
// dim and redden towards the horizon, the upper air glows faintly green, and
// the last of the twilight lies along the horizon under a sun that has set
// (include/night_air.gdshaderinc).
uniform sampler2D stars : source_color, filter_linear_mipmap, repeat_enable;
uniform mat3 orient = mat3(1.0);
uniform float energy = 1.4;
uniform float contrast = 1.2;
uniform float lod = 0.5;

uniform float air = 0.0;                    // 0 in space; 1 for a clear, dry night (a desert's)
uniform vec3 sun_dir = vec3(0.0, -1.0, 0.0);  // towards the sun, below the horizon after sunset
uniform float twilight = 0.0;               // how bright the twilight is with the sun just under the horizon
uniform float airglow = 0.0;                // the night's own faint light from the upper air
uniform vec3 ground : source_color = vec3(0.004, 0.0035, 0.003);

void sky() {
    vec3 d = EYEDIR;
    vec3 c = starmap(stars, orient, d, energy, contrast, lod);
    if (air > 0.0) {
        c = c * air_through(d, air) + twilight_light(d, sun_dir, twilight) + airglow_light(d, airglow, air);
        // below the horizon is ground, never stars
        c = mix(c, ground, smoothstep(0.0, -0.015, d.y));
    }
    COLOR = c;
}
