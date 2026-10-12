class_name ForestSanctuaryRoom
extends RoomBase

# Forest Sanctuary: a deck among tall pines in morning mist. The wood beyond
# is a photograph of a real one; the trunks, ferns and stones near you are
# solid, and the mist joins the two.

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
    _trunks()
    _undergrowth()
    _light_in_the_mist()
    if motes:
        drift(Vector3(0, 2.4, 0), Vector3(12, 2.4, 12), 260, Color(1.0, 0.96, 0.8), 0.03, Vector3(0.4, 0.15, 0.2), 0.12, 0.8)
    probe(Vector3(28, 14, 28))

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
    # lanterns hung low
    var warm := Color(1.0, 0.8, 0.5)
    for i in 6:
        var angle := TAU * float(i) / 6.0 + 0.3
        var at := Vector3(cos(angle) * 9.2, 1.35, sin(angle) * 9.2)
        glow(at, warm, 0.9, 1.0, 0.7)
        lamp(at, warm, 0.5, 5.0)

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
    for i in 46:
        var angle := rng.randf() * TAU
        # keep the way ahead a little more open
        var distance := rng.randf_range(11.0, 38.0)
        var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.75, 1.5))
        basis = Basis(Vector3(1, 0, 0), rng.randf_range(-0.03, 0.03)) * basis
        many.set_instance_transform(i, Transform3D(basis, Vector3(cos(angle) * distance, -0.2, sin(angle) * distance)))
    var grove := MultiMeshInstance3D.new()
    grove.multimesh = many
    grove.material_override = bark
    add_child(grove)

func _undergrowth() -> void:
    var frond := MaterialKitClass.shader("res://assets/shaders/sway.gdshader", {
        "leaf": load("res://assets/materials/fern_frond.png"), "tint": Vector3(0.6, 0.95, 0.5), "reach": 0.07, "pace": 0.9,
    })
    var rng := RandomNumberGenerator.new()
    rng.seed = 17
    for kind in 3:
        var fern := MeshKitClass.plant(7 + kind, 0.34, 0.95, 0.75, 30 + kind)
        var many := MultiMesh.new()
        many.transform_format = MultiMesh.TRANSFORM_3D
        many.mesh = fern
        many.instance_count = 110
        for i in 110:
            var angle := rng.randf() * TAU
            var distance := rng.randf_range(9.8, 19.0)
            var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 2.0))
            many.set_instance_transform(i, Transform3D(basis, Vector3(cos(angle) * distance, -0.14, sin(angle) * distance)))
        var patch := MultiMeshInstance3D.new()
        patch.multimesh = many
        patch.material_override = frond
        patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(patch)

    var mossy := MaterialKitClass.surface("moss_rock", 1.6, Color(0.8, 0.9, 0.75), 1.0, true)
    for i in 14:
        var angle := rng.randf() * TAU
        var distance := rng.randf_range(10.5, 24.0)
        var boulder := add(MeshKitClass.rock(300 + i, rng.randf_range(0.4, 1.5), 0.3, 10), mossy,
            Vector3(cos(angle) * distance, rng.randf_range(-0.25, 0.2), sin(angle) * distance))
        boulder.rotation.y = rng.randf() * TAU

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
