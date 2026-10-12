shader_type spatial;
render_mode unshaded;

// A sheet pinned to a board: lines of type, a heading, sometimes a picture.
// Every sheet is different; none of them says anything.
uniform vec3 paper : source_color = vec3(0.86, 0.82, 0.72);
uniform vec3 ink : source_color = vec3(0.08, 0.07, 0.07);
uniform float seed = 0.0;
uniform float picture = 0.0;
uniform float brightness = 0.9;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 13.1) * 43758.5453); }

void fragment() {
    vec2 uv = UV;
    float line_id = floor(uv.y * 22.0);
    float in_line = fract(uv.y * 22.0);
    float length_of = 0.45 + 0.5 * hash(vec2(line_id, 1.0));
    float word = step(0.25, hash(vec2(floor(uv.x * 26.0), line_id)));
    float text = step(0.3, in_line) * step(in_line, 0.62) * step(0.08, uv.x) * step(uv.x, 0.08 + 0.84 * length_of) * word;
    text *= step(3.0, line_id) * step(line_id, 20.0);
    float heading = step(0.25, in_line) * step(in_line, 0.8) * step(0.08, uv.x) * step(uv.x, 0.6) * step(line_id, 1.5) * step(0.5, line_id);
    vec3 col = mix(paper * (0.92 + 0.08 * hash(floor(uv * 60.0))), ink, clamp(text * 0.75 + heading, 0.0, 1.0));
    if (picture > 0.5) {
        vec2 p = (uv - vec2(0.5, 0.42)) / vec2(0.84, 0.62);
        float inside = step(abs(p.x), 0.5) * step(abs(p.y), 0.5);
        float tone = 0.25 + 0.5 * hash(floor(p * 7.0)) * (0.6 + 0.4 * sin(p.x * 9.0 + seed));
        col = mix(col, vec3(tone * 0.9, tone * 0.85, tone * 0.78), inside);
    }
    ALBEDO = col * brightness;
}
