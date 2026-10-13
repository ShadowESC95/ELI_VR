shader_type sky;

// A sky ELI painted himself: two colours, as many stars as he wants, and a
// sun wherever he put it.

uniform vec3 top : source_color = vec3(0.02, 0.03, 0.08);
uniform vec3 horizon : source_color = vec3(0.30, 0.22, 0.40);
uniform float stars = 0.5;
uniform sampler2D star_map : source_color, filter_linear, repeat_enable;
uniform vec3 sun_dir = vec3(0.0, 0.4, -1.0);
uniform vec3 sun_colour : source_color = vec3(1.0, 0.95, 0.85);
uniform float sun_size = 0.3;

void sky() {
    float up = EYEDIR.y;
    vec3 base = mix(horizon, top, pow(clamp(up, 0.0, 1.0), 0.55));
    // below the horizon the sky closes down into its own darker colour
    base = mix(base, horizon * 0.18, clamp(-up * 5.0, 0.0, 1.0));
    vec3 field = texture(star_map, SKY_COORDS).rgb;
    base += field * stars * 1.8 * clamp(up * 3.0 + 0.25, 0.0, 1.0);
    float facing = max(dot(normalize(EYEDIR), normalize(sun_dir)), 0.0);
    float disc = smoothstep(0.9994 - 0.004 * sun_size, 0.9997, facing);
    float halo = pow(facing, mix(700.0, 50.0, sun_size)) * 0.6 + pow(facing, 8.0) * 0.14 * sun_size;
    COLOR = base + sun_colour * (disc * 4.0 + halo) * step(0.001, sun_size);
}
