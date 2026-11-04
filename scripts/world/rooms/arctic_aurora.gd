class_name ArcticAuroraRoom
extends RoomBase

# Arctic Aurora: a timber platform on a snowfield at night. The northern
# lights hang and sway over the ridge, snow comes down, a hut's window is lit.

const MOON := Vector3(0.62, 0.24, 0.55)

var _land: LandKit

func _build() -> void:
    var env := environment(Color(0.14, 0.20, 0.32), 0.42)
    star_sky(env, Vector3(0.55, 0.5, -0.65), -40.0, 1.3)
    env.fog_enabled = true
    env.fog_light_color = Color(0.10, 0.15, 0.24)
    env.fog_density = 0.0016
    sun(MOON, Color(0.72, 0.82, 1.0), 1.5)
    glow(MOON.normalized() * 900.0, Color(0.85, 0.9, 1.0), 150.0, 2.0, 1.0)

    _lights_in_the_sky()
    _snowfield()
    _timber()
    _platform()
    _hut()
    _camp()
    if motes:
        drift(Vector3(0, 5.0, 0), Vector3(16, 6, 16), 700, Color(0.92, 0.96, 1.0), 0.04, Vector3(0.12, -1.0, 0.06), 0.55, 0.9)
    probe()

func _lights_in_the_sky() -> void:
    var green := Color(0.25, 1.0, 0.55).lerp(accent, 0.25)
    var rng := RandomNumberGenerator.new()
    rng.seed = 3
    for i in 5:
        # each curtain follows its own wandering line across the north
        var path := PackedVector3Array()
        var distance := 190.0 + 55.0 * i
        var start := deg_to_rad(-150.0 + 22.0 * i)
        for s in 60:
            var a := start + deg_to_rad(float(s) * 3.4)
            var wobble := sin(float(s) * 0.45 + i) * 26.0 + sin(float(s) * 0.13 + i * 2.0) * 40.0
            path.append(Vector3(sin(a) * (distance + wobble), 55.0 + 14.0 * i, -cos(a) * (distance + wobble)))
        var veil := add(MeshKitClass.curtain(path, 150.0 + rng.randf_range(0.0, 50.0)), MaterialKitClass.shader("res://assets/shaders/aurora.gdshader", {
            "low": rgb(green), "high": rgb(accent.lerp(Color(0.6, 0.3, 1.0), 0.55)),
            "seed": float(i) * 9.1, "energy": 1.25 - 0.12 * i,
        }))
        veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    # the sky's light on the snow
    lamp(Vector3(0, 30, -40), green, 0.9, 120.0)

func _snowfield() -> void:
    # snow lying on the flats, the dark rock of the ridges showing through where it is steep, and
    # specks of light in the snow near you
    var snow := LandKit.blend("snow", 5.0, Color(0.88, 0.93, 1.0), "rock", 2.2, Color(0.32, 0.34, 0.38),
        {"slope_from": 0.22, "slope_to": 0.48, "breakup": 0.5, "sparkle": 1.0, "far_blend": 60.0, "roughness_scale": 0.85})
    _land = LandKit.lay(self, snow, 21, 0.021, 4, 520.0, 170, 15.0, 11.5, 16.0, 46.0, -0.14)

    # ice standing out of the snow
    var ice := MaterialKitClass.surface("ice", 1.6, Color(0.75, 0.9, 1.0).lerp(accent, 0.15), 0.25)
    var rng := RandomNumberGenerator.new()
    rng.seed = 8
    var spike := MeshKitClass.lathe(PackedVector2Array([
        Vector2(0.0, 3.2), Vector2(0.25, 1.9), Vector2(0.5, 0.5), Vector2(0.62, -0.4), Vector2(0.0, -0.4),
    ]), 6)
    for i in 22:
        var angle := rng.randf() * TAU
        var distance := rng.randf_range(13.0, 46.0)
        var x := cos(angle) * distance
        var z := sin(angle) * distance
        var shard := add(spike, ice, Vector3(x, _land.y_at(x, z) + rng.randf_range(-0.2, 0.9), z))
        shard.scale = Vector3(1.0, rng.randf_range(0.5, 1.7), 1.0) * rng.randf_range(0.6, 1.8)
        shard.rotation = Vector3(rng.randf_range(-0.25, 0.25), rng.randf() * TAU, rng.randf_range(-0.25, 0.25))

# Saplings, stumps and fallen trunks of the treeline, out of the snow (scanned, assets/models).
func _timber() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 5
    _land.scatter(self, ["fir_sapling", "pine_sapling_small"], 14, 12.0, 40.0, rng, 0.9, 1.8, 0.04)
    _land.scatter(self, ["dead_tree_trunk_02", "dead_tree_trunk", "tree_stump_01", "boulder_01", "dead_tree_trunk_02"], 5,
                  11.0, 30.0, rng, 0.9, 1.5, 0.02, true)

func _platform() -> void:
    var boards := MaterialKitClass.surface("planks", 2.4, Color(1.5, 1.35, 1.2), 0.9)
    var timber := MaterialKitClass.surface("bark", 0.8, Color(0.5, 0.42, 0.36))
    deck(9.0, boards, timber)

    # lanterns: the one warm thing out here
    var post := CylinderMesh.new()
    post.top_radius = 0.045
    post.bottom_radius = 0.06
    post.height = 1.9
    var warm := Color(1.0, 0.72, 0.38)
    for i in 8:
        var angle := TAU * float(i) / 8.0 + PI / 8.0
        var at := Vector3(cos(angle), 0.0, sin(angle)) * 8.8
        add(post, timber, at + Vector3(0, 0.95, 0))
        var box := BoxMesh.new()
        box.size = Vector3(0.2, 0.26, 0.2)
        add(box, MaterialKitClass.light(warm, 2.4), at + Vector3(0, 2.0, 0))
        glow(at + Vector3(0, 2.0, 0), warm, 1.3, 1.1, 0.6)
        if i % 2 == 0:
            lamp(at + Vector3(0, 2.0, 0), warm, 0.9, 6.5)

func _hut() -> void:
    var timber := MaterialKitClass.surface("planks", 1.6, Color(0.42, 0.3, 0.24))
    var hut := Node3D.new()
    hut.position = Vector3(11.5, 0.3, -17.0)
    hut.rotation.y = deg_to_rad(-28.0)
    add_child(hut)
    var walls := BoxMesh.new()
    walls.size = Vector3(5.0, 2.6, 3.6)
    add(walls, timber, Vector3(0, 1.3, 0), hut)
    var roof := PrismMesh.new()
    roof.size = Vector3(5.6, 1.5, 4.2)
    add(roof, MaterialKitClass.surface("snow", 2.0, Color(0.9, 0.94, 1.0)), Vector3(0, 3.35, 0), hut)
    var warm := Color(1.0, 0.7, 0.36)
    var pane := BoxMesh.new()
    pane.size = Vector3(0.9, 0.7, 0.05)
    for x in [-1.3, 1.3]:
        add(pane, MaterialKitClass.light(warm, 2.2), Vector3(x, 1.5, 1.81), hut)
    glow(hut.position + Vector3(0, 1.6, 2.2).rotated(Vector3.UP, hut.rotation.y), warm, 4.0, 0.5, 0.1)
    lamp(Vector3(0, 1.5, 3.0), warm, 1.1, 8.0, hut)
    # the mast and its light
    var mast := CylinderMesh.new()
    mast.top_radius = 0.02
    mast.bottom_radius = 0.04
    mast.height = 6.0
    add(mast, timber, Vector3(2.0, 5.4, -1.0), hut)
    blink(glow(hut.position + Vector3(2.0, 8.5, -1.0).rotated(Vector3.UP, hut.rotation.y), Color(1.0, 0.2, 0.15), 1.0, 2.0, 0.9), 2.2)
    # by the door a lantern; the woodpile along the side; stores and the generator that keeps the
    # light on round the back (real things, assets/models)
    prop("Lantern_01", Vector3(-1.9, 0.0, 2.0), 0.0, 1.0, hut)
    glow(Vector3(-1.9, 0.25, 2.0), warm, 0.5, 1.2, 0.8, hut)
    lamp(Vector3(-1.9, 0.4, 2.2), warm, 0.6, 4.0, hut)
    for i in 4:
        prop("dead_tree_trunk", Vector3(-3.3, 0.14 + 0.27 * float(i / 2), 0.4 + 0.3 * float(i % 2)), 90.0, 0.55, hut)
    prop("wooden_crate_01", Vector3(3.2, 0.0, 0.9), 15.0, 1.0, hut)
    prop("wooden_barrels_01", Vector3(3.6, 0.0, -0.9), 0.0, 0.55, hut)
    prop("portable_generator", Vector3(0.6, 0.0, -2.6), 180.0, 1.0, hut)

# A fire by the platform with benches round it, and a path of lamps out to the hut.
func _camp() -> void:
    var fire := Vector3(6.5, -0.1, 7.5)
    var flame := Color(1.0, 0.55, 0.2)
    prop("stone_fire_pit", fire, 0.0)
    glow(fire + Vector3(0, 0.45, 0), flame, 1.6, 1.4, 0.6)
    lamp(fire + Vector3(0, 0.8, 0), flame, 2.2, 9.0)
    if motes:
        drift(fire + Vector3(0, 1.2, 0), Vector3(0.3, 0.8, 0.3), 60, flame, 0.03, Vector3(0.05, 1.0, 0.0), 0.9, 1.2)
    for degrees in [200.0, 320.0]:
        var a := deg_to_rad(degrees)
        var seat := fire + Vector3(sin(a), 0.0, -cos(a)) * 1.9
        prop("painted_wooden_bench", seat, rad_to_deg(atan2(fire.x - seat.x, fire.z - seat.z)))
    var warm := Color(1.0, 0.8, 0.5)
    for i in 3:
        var t := float(i + 1) / 4.0
        var on_path := Vector3(9.4, -0.1, 0.0).lerp(Vector3(11.5, 0.3, -17.0), t) + Vector3(1.2, 0.0, 0.0)
        prop("street_lamp_02", on_path + Vector3(0, 0.39, 0), 0.0)
        glow(on_path + Vector3(0, 1.9, 0), warm, 0.8, 1.0, 0.7)
        lamp(on_path + Vector3(0, 1.85, 0), warm, 0.9, 6.0)
