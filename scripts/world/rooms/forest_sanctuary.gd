class_name ForestSanctuaryRoom
extends RoomBase

# Forest Sanctuary: a deck among tall pines in morning mist. The wood beyond
# is a photograph of a real one; the ground near you is a forest floor of
# needles and litter with moss and stone where it rises, the trunks carry
# their boughs, ferns, grass, stumps and logs stand on the ground, and the
# mist joins it all to the photograph.

var _land: LandKit

func _build() -> void:
    var env := environment(Color(0.6, 0.66, 0.62), 1.0)
    photo_sky(env, "misty_pines", 15.0, -0.14, 1.0)
    env.ambient_light_energy = 1.0
    env.fog_enabled = true
    env.fog_light_color = Color(0.74, 0.79, 0.77)
    env.fog_density = 0.011
    env.fog_sky_affect = 0.0
    # light comes down through the canopy, soft, from nearly overhead
    sun(Vector3(-0.3, 0.9, 0.25), Color(1.0, 0.97, 0.9), 1.1)

    _deck_of_boards()
    _ground()
    _trunks()
    _undergrowth()
    _real_undergrowth()
    _light_in_the_mist()
    if motes:
        drift(Vector3(0, 2.4, 0), Vector3(12, 2.4, 12), 260, Color(1.0, 0.96, 0.8), 0.03, Vector3(0.4, 0.15, 0.2), 0.12, 0.8)
    probe(Vector3(28, 14, 28))

# The forest floor: needles and leaf litter, with moss and stone where the ground rises. It settles
# back to the photograph's flat ground over its last stretch, so the two meet without a step.
func _ground() -> void:
    var floor_mix := LandKit.blend("forest_floor", 2.2, Color(0.85, 0.9, 0.8), "moss_rock", 1.8, Color(0.8, 0.95, 0.75),
        {"slope_from": 0.1, "slope_to": 0.3, "breakup": 0.55, "far_blend": 25.0})
    _land = LandKit.lay(self, floor_mix, 6, 0.045, 3, 160.0, 120, 2.6, 10.0, 8.0, 0.0, -0.16, 40.0)

func _deck_of_boards() -> void:
    var boards := MaterialKitClass.surface("planks", 2.4, Color(1.25, 1.1, 0.95), 0.9)
    var timber := MaterialKitClass.surface("bark", 0.9, Color(0.8, 0.7, 0.6))
    deck(9.0, boards, timber)
    # a rail of rough posts and rope-thin bars
    var post := CylinderMesh.new()
    post.top_radius = 0.06
    post.bottom_radius = 0.07
    post.height = 1.05
    for i in 24:
        var angle := TAU * float(i) / 24.0
        add(post, timber, Vector3(cos(angle) * 9.2, 0.5, sin(angle) * 9.2))
    for height in [1.0, 0.55]:
        var rail := TorusMesh.new()
        rail.inner_radius = 9.2 - 0.03
        rail.outer_radius = 9.2 + 0.03
        rail.rings = 96
        rail.ring_segments = 6
        add(rail, timber, Vector3(0, height, 0))
    # lanterns on every fourth post (real ones, assets/models), lit
    var warm := Color(1.0, 0.8, 0.5)
    for i in 6:
        var angle := TAU * float(i) / 6.0
        var at := Vector3(cos(angle) * 9.2, 1.03, sin(angle) * 9.2)
        prop("wooden_lantern_01", at, rad_to_deg(-angle))
        glow(at + Vector3(0, 0.3, 0), warm, 0.9, 1.0, 0.7)
        lamp(at + Vector3(0, 0.3, 0), warm, 0.5, 5.0)

# The near pines: trunks turned on a lathe standing on the ground, and on each three whorls of boughs
# hanging out and down, needles drawn here, moving a little in the air.
func _trunks() -> void:
    var bark := MaterialKitClass.surface("bark", 1.4, Color(0.62, 0.5, 0.44), 1.0)
    var rng := RandomNumberGenerator.new()
    rng.seed = 6
    var trunk := MeshKitClass.lathe(PackedVector2Array([
        Vector2(0.0, 34.0), Vector2(0.14, 34.0), Vector2(0.24, 12.0), Vector2(0.30, 1.2), Vector2(0.44, 0.0), Vector2(0.0, 0.0),
    ]), 14)
    var many := MultiMesh.new()
    many.transform_format = MultiMesh.TRANSFORM_3D
    many.mesh = trunk
    many.instance_count = 46
    var boughs := MultiMesh.new()
    boughs.transform_format = MultiMesh.TRANSFORM_3D
    boughs.mesh = LandKit.tuft("needle", 31)
    boughs.instance_count = 46 * 3
    for i in 46:
        var angle := rng.randf() * TAU
        # keep the way ahead a little more open
        var distance := rng.randf_range(11.0, 38.0)
        var scale := rng.randf_range(0.75, 1.5)
        var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale)
        basis = Basis(Vector3(1, 0, 0), rng.randf_range(-0.03, 0.03)) * basis
        var foot := Vector3(cos(angle) * distance, _land.y_at(cos(angle) * distance, sin(angle) * distance) - 0.2, sin(angle) * distance)
        many.set_instance_transform(i, Transform3D(basis, foot))
        for tier in 3:
            # a whorl of boughs a third, a half and two thirds of the way up, the lower ones wider
            var up := (0.34 + 0.17 * tier) * 34.0 * scale
            var spread := (2.4 - 0.5 * tier) * scale
            var whorl := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, deg_to_rad(165.0))
            boughs.set_instance_transform(i * 3 + tier, Transform3D(whorl.scaled(Vector3(spread, spread * 0.8, spread)), foot + Vector3(0, up, 0)))
    var grove := MultiMeshInstance3D.new()
    grove.multimesh = many
    grove.material_override = bark
    add_child(grove)
    var canopy := MultiMeshInstance3D.new()
    canopy.multimesh = boughs
    canopy.material_override = LandKit.sway_material("needle", Color(0.85, 1.0, 0.8), 0.12, 0.45)
    canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(canopy)

func _undergrowth() -> void:
    var frond := MaterialKitClass.shader("res://assets/shaders/sway.gdshader", {
        "leaf": load("res://assets/materials/fern_frond.png"), "tint": Vector3(0.6, 0.95, 0.5), "reach": 0.07, "pace": 0.9,
    })
    var rng := RandomNumberGenerator.new()
    rng.seed = 17
    for kind in 3:
        var fern := MeshKitClass.plant(7 + kind, 0.34, 0.95, 0.75, 30 + kind)
        _land.cover(self, fern, frond, int(110 * detail), 9.8, 19.0, rng, 0.9, 2.0, 0.08)
    # grass in the gaps between the ferns, and further out among the trunks
    var grass := LandKit.sway_material("grass", Color(0.75, 0.95, 0.6), 0.05, 1.1)
    for kind in 2:
        _land.cover(self, LandKit.tuft("grass", 41 + kind), grass, int(260 * detail), 9.8, 28.0, rng, 0.7, 1.5, 0.04)

    var mossy := MaterialKitClass.surface("moss_rock", 1.6, Color(0.8, 0.9, 0.75), 1.0, true)
    for i in 14:
        var angle := rng.randf() * TAU
        var distance := rng.randf_range(10.5, 24.0)
        var x := cos(angle) * distance
        var z := sin(angle) * distance
        var boulder := add(MeshKitClass.rock(300 + i, rng.randf_range(0.4, 1.5), 0.3, 10), mossy,
            Vector3(x, _land.y_at(x, z) + rng.randf_range(-0.15, 0.1), z))
        boulder.rotation.y = rng.randf() * TAU

# Real ferns, stumps, fallen logs and mossy rocks near the deck, and young pines among the trunks
# (scanned, assets/models), each standing on the ground at its height.
func _real_undergrowth() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 23
    _land.scatter(self, ["fern_02"], 14, 9.9, 14.0, rng, 0.7, 1.2, -0.02)
    _land.scatter(self, ["tree_stump_02", "tree_stump_01"], 4, 10.5, 18.0, rng, 1.0, 1.0, 0.0, true)
    _land.scatter(self, ["rock_moss_set_02"], 3, 11.0, 20.0, rng, 0.6, 1.0, -0.05, true)
    _land.scatter(self, ["dead_tree_trunk"], 2, 11.0, 16.0, rng, 1.3, 1.3, 0.0, true)
    _land.scatter(self, ["fir_sapling", "pine_sapling_small"], 10, 10.0, 22.0, rng, 1.0, 1.8, -0.05)

func _light_in_the_mist() -> void:
    var beam := QuadMesh.new()
    beam.size = Vector2(3.4, 30.0)
    var rng := RandomNumberGenerator.new()
    rng.seed = 40
    for i in 9:
        var angle := rng.randf() * TAU
        var distance := rng.randf_range(11.0, 26.0)
        var shaft := add(beam, MaterialKitClass.shader("res://assets/shaders/light_shaft.gdshader", {
            "seed": float(i) * 3.1, "energy": 0.16,
        }), Vector3(cos(angle) * distance, 13.5, sin(angle) * distance))
        shaft.rotation = Vector3(0.0, -angle + PI * 0.5, deg_to_rad(rng.randf_range(10.0, 20.0)))
        shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
