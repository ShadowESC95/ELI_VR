class_name DeepSpaceRoom
extends RoomBase

# Deep Space Observatory: a platform adrift beside a ringed giant, far from
# any sun worth the name. Moons go round, rocks tumble past, gas clouds churn.

const SUN_DIR := Vector3(0.62, 0.34, 0.52)

func _build() -> void:
    var env := environment(Color(0.10, 0.12, 0.18).lerp(accent, 0.2), 0.5)
    star_sky(env, Vector3(0.35, 0.5, -0.8), 15.0, 2.0)
    sun(SUN_DIR, Color(0.95, 0.97, 1.0), 1.7)
    glow(SUN_DIR.normalized() * 900.0, Color(0.9, 0.95, 1.0), 260.0, 2.2, 1.0)

    _giant()
    _clouds()
    _rocks()
    _platform()
    _gear()
    if motes:
        drift(Vector3(0, 3.0, 0), Vector3(9, 3, 9), 160, Color(1, 1, 1).lerp(accent, 0.3))
    probe()

func _giant() -> void:
    var centre := Vector3(-0.42, 0.10, -0.90).normalized() * 720.0
    var ball := SphereMesh.new()
    ball.radius = 300.0
    ball.height = 600.0
    ball.radial_segments = 128
    ball.rings = 64
    var planet := add(ball, MaterialKitClass.shader("res://assets/shaders/gas_giant.gdshader", {"sun_dir": SUN_DIR.normalized()}), centre)
    planet.rotation = Vector3(deg_to_rad(18.0), 0.0, deg_to_rad(-22.0))
    planet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    spin(planet, Vector3.UP, 0.006)

    var ring := add(MeshKitClass.annulus(380.0, 640.0, 160), MaterialKitClass.shader("res://assets/shaders/planet_ring.gdshader", {}), centre)
    ring.rotation = planet.rotation
    ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    # two moons on their way round
    var stone := MaterialKitClass.surface("rock", 30.0, Color(0.8, 0.8, 0.85), 1.0, true)
    for i in 2:
        var orbit := Node3D.new()
        orbit.position = centre
        orbit.rotation = Vector3(deg_to_rad(18.0 + 9.0 * i), float(i) * 2.4, deg_to_rad(-22.0))
        add_child(orbit)
        var moon := add(MeshKitClass.rock(40 + i, 24.0 - 9.0 * i, 0.08, 20), stone, Vector3(760.0 + 190.0 * i, 0, 0), orbit)
        moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        spin(orbit, Vector3.UP, 0.012 - 0.005 * i)

func _clouds() -> void:
    var sheet := QuadMesh.new()
    sheet.size = Vector2(1100, 800)
    var places := [
        [Vector3(0.75, 0.30, -0.6), accent, Color(0.9, 0.3, 0.6)],
        [Vector3(-0.2, 0.75, -0.55), secondary.lerp(accent, 0.5), Color(0.3, 0.4, 1.0)],
        [Vector3(0.5, -0.25, 0.8), Color(0.9, 0.4, 0.2), accent],
        [Vector3(-0.85, 0.2, 0.45), accent.lerp(Color(0.5, 0.2, 0.9), 0.6), Color(0.2, 0.7, 0.9)],
    ]
    for i in places.size():
        var where: Vector3 = (places[i][0] as Vector3).normalized() * 1500.0
        var cloud := add(sheet, MaterialKitClass.shader("res://assets/shaders/nebula.gdshader", {
            "tint": rgb(places[i][1]), "tint_b": rgb(places[i][2]), "seed": float(i) * 13.7, "energy": 0.42,
        }), where)
        cloud.basis = Basis.looking_at(-where.normalized(), Vector3.UP)
        cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _rocks() -> void:
    var stone := MaterialKitClass.surface("rock", 2.5, Color(0.55, 0.52, 0.5), 1.0, true)
    var rng := RandomNumberGenerator.new()
    rng.seed = 7
    # a loose belt drifting round the platform
    var belt := Node3D.new()
    belt.rotation = Vector3(deg_to_rad(8.0), 0.0, deg_to_rad(-12.0))
    add_child(belt)
    for kind in 4:
        var shape := MeshKitClass.rock(kind + 1, 1.0, 0.45, 10)
        var many := MultiMesh.new()
        many.transform_format = MultiMesh.TRANSFORM_3D
        many.mesh = shape
        many.instance_count = 26
        for i in 26:
            var angle := rng.randf() * TAU
            var distance := rng.randf_range(26.0, 120.0)
            var basis := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)).scaled(Vector3.ONE * rng.randf_range(0.5, 3.6))
            many.set_instance_transform(i, Transform3D(basis, Vector3(cos(angle) * distance, rng.randf_range(-9.0, 7.0), sin(angle) * distance)))
        var field := MultiMeshInstance3D.new()
        field.multimesh = many
        field.material_override = stone
        belt.add_child(field)
    spin(belt, Vector3.UP, 0.008)

    # a few close by, each turning on its own
    for i in 7:
        var angle := TAU * float(i) / 7.0 + 0.5
        var near := add(MeshKitClass.rock(20 + i, rng.randf_range(0.7, 2.2), 0.4, 12), stone,
            Vector3(cos(angle) * rng.randf_range(13.0, 20.0), rng.randf_range(0.5, 7.0), sin(angle) * rng.randf_range(13.0, 20.0)))
        spin(near, Vector3(rng.randf(), rng.randf(), rng.randf()), rng.randf_range(0.03, 0.12))

# What a platform out here is worked from (real things, assets/models): an instrument desk facing
# the giant with a lantern on it, the stores behind you, a bench to sit and watch from, and a
# searchlight on its plinth at the edge.
func _gear() -> void:
    var warm := Color(1.0, 0.85, 0.6)
    var a := deg_to_rad(-50.0)
    var desk := Node3D.new()
    desk.position = Vector3(sin(a), 0.0, -cos(a)) * 6.6
    desk.rotation.y = -a                        # its front to the middle: the giant is over its far edge
    add_child(desk)
    prop("metal_office_desk", Vector3.ZERO, 0.0, 1.0, desk)
    var top := 0.79
    prop("classic_laptop", Vector3(-0.35, top, -0.05), 15.0, 1.0, desk)
    prop("vintage_spacecraft_instrument", Vector3(0.45, top + 0.13, -0.15), -10.0, 1.0, desk)
    prop("Lantern_01", Vector3(0.85, top, 0.1), 0.0, 1.0, desk)
    prop("metal_stool_01", Vector3(0.0, 0.0, 0.75), 0.0, 1.0, desk)
    glow(Vector3(0.85, top + 0.2, 0.1), warm, 0.35, 1.2, 0.8, desk)
    lamp(Vector3(0.85, top + 0.3, 0.1), warm, 0.6, 3.5, desk)
    for spec in [["drawer_cabinet", 150.0, 7.6], ["industrial_storage_cart", 172.0, 7.2],
                 ["plastic_crate_02", 190.0, 7.8], ["wooden_crate_01", 197.0, 7.3]]:
        var b := deg_to_rad(float(spec[1]))
        var at := Vector3(sin(b), 0.0, -cos(b)) * float(spec[2])
        prop(str(spec[0]), at, rad_to_deg(atan2(-at.x, -at.z)))
    var c := deg_to_rad(-22.0)
    prop("painted_wooden_bench", Vector3(sin(c), 0.0, -cos(c)) * 6.4, 180.0 + 22.0)
    var steel := MaterialKitClass.metal("brushed_metal", 0.6, Color(0.7, 0.72, 0.78), 0.7)
    var d := deg_to_rad(120.0)
    var edge := Vector3(sin(d), 0.0, -cos(d)) * 8.5
    box(Vector3(0.3, 1.0, 0.3), steel, edge + Vector3(0, 0.5, 0))
    prop("portable_searchlight", edge + Vector3(0, 1.0 + 0.08, 0), rad_to_deg(atan2(-edge.x, -edge.z)) + 180.0)

func _platform() -> void:
    var plating := MaterialKitClass.metal("deck_plating", 2.2, Color(0.46, 0.50, 0.58), 0.5)
    var hull := MaterialKitClass.metal("hull_panels", 1.8, Color(0.40, 0.43, 0.50))
    deck(9.0, plating, hull)

    # light masts round the edge
    var mast := CylinderMesh.new()
    mast.top_radius = 0.035
    mast.bottom_radius = 0.06
    mast.height = 3.4
    for i in 6:
        var angle := TAU * float(i) / 6.0 + PI / 6.0
        var at := Vector3(cos(angle), 0.0, sin(angle)) * 8.9
        add(mast, hull, at + Vector3(0, 1.7, 0))
        glow(at + Vector3(0, 3.45, 0), accent, 1.1, 1.5, 0.8)
        lamp(at + Vector3(0, 3.2, 0), accent, 0.5, 6.0)

    # the telescope, trained on the giant
    var steel := MaterialKitClass.metal("brushed_metal", 0.6, Color(0.7, 0.72, 0.78), 0.7)
    var stand := Node3D.new()
    stand.position = Vector3(5.6, 0, -4.4)
    add_child(stand)
    add(MeshKitClass.lathe(PackedVector2Array([
        Vector2(0.0, 1.5), Vector2(0.22, 1.5), Vector2(0.3, 0.12), Vector2(0.8, 0.06), Vector2(0.8, 0.0), Vector2(0.0, 0.0),
    ]), 24), hull, Vector3.ZERO, stand)
    var tube := add(MeshKitClass.lathe(PackedVector2Array([
        Vector2(0.0, 1.9), Vector2(0.44, 1.9), Vector2(0.47, 1.7), Vector2(0.42, 1.6), Vector2(0.42, -1.3),
        Vector2(0.3, -1.5), Vector2(0.18, -1.9), Vector2(0.0, -1.9),
    ]), 32), steel, Vector3(0, 1.75, 0), stand)
    tube.rotation = Vector3(deg_to_rad(-68.0), deg_to_rad(52.0), 0.0)
    glow(Vector3(5.6, 1.2, -4.4), accent, 0.5, 1.2, 0.9)
