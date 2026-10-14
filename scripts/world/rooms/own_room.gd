class_name OwnRoom
extends RoomBase

# ELI's own room: open ground under an open sky, and nothing there but what
# ELI has made. The sky, the ground, the light and the mist are its to choose
# (ELI v3 keeps them; see eli/world/building.py there). This draws its choice:
# a sky by name, or one it painted itself from two colours, stars and a sun;
# ground by name or of any colour, flat or rising into hills.

# sky -> [panorama, reach, ground height, where the light comes from, its warmth]
const PHOTO_SKIES := {
    "dawn": ["mountain_dawn", 46.0, -0.14, Vector3(0.754, 0.242, -0.611), Color(1.0, 0.82, 0.66)],
    "mist": ["misty_pines", 15.0, -0.14, Vector3(-0.3, 0.9, 0.25), Color(0.96, 0.98, 0.95)],
    "sunset": ["sunset_sea", 100000.0, -4000.0, Vector3(0.711, 0.148, -0.687), Color(1.0, 0.74, 0.55)],
}
# ground -> [material set, tile size, tint, polish, is it metal]
const GROUNDS := {
    "stone": ["concrete", 2.6, Color(0.86, 0.86, 0.9), 0.85, false],
    "marble": ["marble_white", 3.0, Color.WHITE, 1.0, false],
    "wood": ["wood_floor", 2.4, Color.WHITE, 0.9, false],
    "sand": ["sand", 3.0, Color.WHITE, 1.0, false],
    "snow": ["snow", 3.0, Color.WHITE, 1.0, false],
    "moss": ["forest_floor", 2.6, Color(0.8, 0.95, 0.8), 1.0, false],
    "metal": ["deck_plating", 2.0, Color.WHITE, 1.0, true],
    "dark": ["marble_black", 3.0, Color.WHITE, 1.0, false],
}
const RADIUS := 13.0

var mood := {"sky": "stars", "light": "#9fd8ff", "ground": "stone", "mist": 0.15}

# Called when ELI's world says the room has changed.
func apply_mood(new_mood: Dictionary) -> void:
    var wanted := {"sky": "stars", "light": "#9fd8ff", "ground": "stone", "mist": 0.15}
    wanted.merge(new_mood, true)
    if wanted == mood:
        return
    mood = wanted
    for child in get_children():
        remove_child(child)
        child.queue_free()
    _turning.clear()
    _blinking.clear()
    _build()

func _build() -> void:
    var light := Color(str(mood.get("light", "#9fd8ff")))
    var sky := str(mood.get("sky", "stars"))
    var mist := clampf(float(mood.get("mist", 0.15)), 0.0, 1.0)
    var env: Environment

    if PHOTO_SKIES.has(sky):
        var photo: Array = PHOTO_SKIES[sky]
        env = environment(Color(0.55, 0.52, 0.58).lerp(light, 0.25), 1.0)
        photo_sky(env, photo[0], photo[1], photo[2], 1.0)
        sun(photo[3], (photo[4] as Color).lerp(light, 0.45), 1.5)
    elif sky == "painted":
        env = _painted_sky(light)
    elif sky == "void":
        env = environment(light.darkened(0.82), 0.5)
        env.background_mode = Environment.BG_COLOR
        env.background_color = Color(0.004, 0.005, 0.008)
        sun(Vector3(0.2, 0.9, -0.3), light.lerp(Color.WHITE, 0.3), 0.9)
    else:
        env = environment(light.darkened(0.7), 0.6)
        star_sky(env, Vector3(0.05, 0.62, -0.78), 40.0, 2.0)
        sun(Vector3(-0.35, 0.72, -0.4), light.lerp(Color(0.8, 0.86, 1.0), 0.5), 1.2)

    if mist > 0.02:
        env.fog_enabled = true
        env.fog_light_color = light.lerp(Color(0.72, 0.76, 0.8), 0.6)
        if mood.has("mist_colour"):
            env.fog_light_color = Color(str(mood["mist_colour"]))
        env.fog_density = 0.0015 + 0.02 * mist * mist
        env.fog_sky_affect = 0.25 * mist

    _ground(light)
    lamp(Vector3(0, 4.2, 0), light, 0.9, 16.0)
    if motes:
        drift(Vector3(0, 2.2, 0), Vector3(11, 2.2, 11), 180, light.lightened(0.4), 0.028, Vector3(0.2, 0.25, -0.1), 0.1, 0.8)
    probe(Vector3(30, 14, 30))

# Its own sky: the colours, the stars and the sun are whatever it chose.
func _painted_sky(light: Color) -> Environment:
    var top := Color(str(mood.get("sky_top", "#05070f")))
    var horizon := Color(str(mood.get("sky_horizon", "#3a2a55")))
    var given: Dictionary = mood.get("sun", {}) if typeof(mood.get("sun")) == TYPE_DICTIONARY else {}
    var height := clampf(float(given.get("height", 0.35)), -0.2, 1.0)
    var bearing := deg_to_rad(float(given.get("bearing", 0.0)))
    var elevation := height * PI * 0.5
    var towards := Vector3(sin(bearing) * cos(elevation), sin(elevation), -cos(bearing) * cos(elevation))
    var sun_colour := Color(str(given.get("colour", "#fff2d8")))
    var size := clampf(float(given.get("size", 0.3 if mood.has("sun") else 0.0)), 0.0, 1.0)

    var env := environment(horizon.lerp(top, 0.5).lerp(light, 0.2), 0.8)
    var sky := Sky.new()
    sky.sky_material = MaterialKitClass.shader("res://assets/shaders/painted_sky.gdshader", {
        "top": rgb(top), "horizon": rgb(horizon), "stars": clampf(float(mood.get("stars", 0.0)), 0.0, 1.0),
        "star_map": load("res://assets/space/starmap_8k.jpg"),
        "sun_dir": towards, "sun_colour": rgb(sun_colour), "sun_size": size,
    })
    sky.radiance_size = Sky.RADIANCE_SIZE_256
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    # the light comes from where it put the sun; with none, from overhead and faint
    if size > 0.0:
        sun(towards if height > 0.02 else Vector3(towards.x, 0.05, towards.z),
            sun_colour.lerp(light, 0.3), 0.25 + 1.3 * clampf(height, 0.0, 1.0))
    else:
        sun(Vector3(0.2, 0.9, -0.3), light.lerp(Color.WHITE, 0.4), 0.7)
    return env

func _ground(light: Color) -> void:
    var ground: Array = GROUNDS.get(str(mood.get("ground", "stone")), GROUNDS["stone"])
    var surface: Material
    if mood.has("ground_colour"):
        var plain := StandardMaterial3D.new()       # a colour of its own, not a material from the list
        plain.albedo_color = Color(str(mood["ground_colour"]))
        plain.roughness = 0.78
        surface = plain
    elif ground[4]:
        surface = MaterialKitClass.metal(ground[0], ground[1], ground[2], ground[3])
    else:
        surface = MaterialKitClass.surface(ground[0], ground[1], ground[2], ground[3])
    var hills := clampf(float(mood.get("terrain", 0.0)), 0.0, 1.0)
    if hills > 0.02:
        # the ground rises round the flat middle, as much as ELI asked
        var noise := FastNoiseLite.new()
        noise.seed = 7
        noise.frequency = 0.02
        noise.fractal_octaves = 3
        add(MeshKitClass.terrain(420.0, 150, noise, 4.0 + 30.0 * hills, RADIUS + 1.0, 30.0, 18.0 * hills, -0.3), surface)
    add(MeshKitClass.annulus(0.0, RADIUS, 160), surface)
    # a rim, so the ground has an edge and a thickness
    add(MeshKitClass.lathe(PackedVector2Array([
        Vector2(RADIUS, 0.0), Vector2(RADIUS + 0.35, 0.0), Vector2(RADIUS + 0.45, -0.3), Vector2(0.0, -0.3),
    ]), 160), surface)
    # two rings of light set into it: where the middle is, and where it ends
    var inlay := strip({"energy": 1.4, "wave": 0.1})
    inlay.set_shader_parameter("tint", rgb(light))
    add(MeshKitClass.annulus(2.96, 3.03, 128), inlay, Vector3(0, 0.006, 0))
    add(MeshKitClass.annulus(RADIUS - 0.5, RADIUS - 0.42, 160), inlay, Vector3(0, 0.006, 0))
