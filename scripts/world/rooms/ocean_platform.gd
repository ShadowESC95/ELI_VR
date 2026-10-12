class_name OceanPlatformRoom
extends RoomBase

# Ocean Platform: a deck on legs out at sea as the sun goes down. The water
# moves and carries the sunset; buoys ride it, a beacon turns, birds circle.

const SUNSET := Vector3(0.711, 0.148, -0.687)

var _floating: Array = []     # [node, rest height, phase, tilt]

func _build() -> void:
    var env := environment(Color(0.55, 0.5, 0.6), 1.0)
    # only the sky is wanted from the photograph: the sea below is made here
    photo_sky(env, "sunset_sea", 100000.0, -4000.0, 1.0)
    env.ambient_light_energy = 1.15
    sun(SUNSET, Color(1.0, 0.68, 0.45), 1.5)

    var sea := add(MeshKitClass.annulus(0.0, 4500.0, 128), MaterialKitClass.shader("res://assets/shaders/water.gdshader", {
        "photo": load("res://assets/skies/sunset_sea.jpg"),
    }), Vector3(0, -2.6, 0))
    sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    _rig()
    _afloat()
    _far_rocks()
    flock(Vector3(-20, 22, -60), 40.0, 7, 0.14)
    if motes:
        drift(Vector3(0, 2.0, 0), Vector3(12, 2, 12), 160, Color(1.0, 0.85, 0.7), 0.025, Vector3(1, 0.1, 0.2), 0.4, 0.6)
    probe(Vector3(30, 14, 30))

func _animate(_delta: float) -> void:
    for entry in _floating:
        var node := entry[0] as Node3D
        var phase := float(entry[2])
        node.position.y = float(entry[1]) + sin(_clock * 0.9 + phase) * 0.16 + sin(_clock * 0.37 + phase * 2.0) * 0.1
        node.rotation.x = sin(_clock * 0.7 + phase) * float(entry[3])
        node.rotation.z = cos(_clock * 0.55 + phase * 1.3) * float(entry[3])

func _rig() -> void:
    var boards := MaterialKitClass.surface("planks", 2.4, Color(1.15, 1.0, 0.9), 0.85)
    var steel := MaterialKitClass.metal("hull_panels", 1.6, Color(0.5, 0.5, 0.54), 0.9)
    var rail_metal := MaterialKitClass.metal("brushed_metal", 0.6, Color(0.8, 0.8, 0.84), 0.8)
    deck(9.0, boards, steel)

    # legs down into the water, braced
    var leg := CylinderMesh.new()
    leg.top_radius = 0.34
    leg.bottom_radius = 0.4
    leg.height = 9.0
    for i in 6:
        var angle := TAU * float(i) / 6.0
        add(leg, steel, Vector3(cos(angle) * 7.6, -5.0, sin(angle) * 7.6))

    var post := CylinderMesh.new()
    post.top_radius = 0.022
    post.bottom_radius = 0.022
    post.height = 1.05
    for i in 30:
        var angle := TAU * float(i) / 30.0
        add(post, rail_metal, Vector3(cos(angle) * 9.25, 0.52, sin(angle) * 9.25))
    for height in [1.05, 0.55]:
        var rail := TorusMesh.new()
        rail.inner_radius = 9.25 - 0.018
        rail.outer_radius = 9.25 + 0.018
        rail.rings = 128
        rail.ring_segments = 8
        add(rail, rail_metal, Vector3(0, height, 0))

    # the beacon: a mast with a lamp that sweeps
    var mast := MeshKitClass.lathe(PackedVector2Array([
        Vector2(0.0, 6.2), Vector2(0.09, 6.2), Vector2(0.16, 0.4), Vector2(0.4, 0.0), Vector2(0.0, 0.0),
    ]), 12)
    var foot := Vector3(-6.4, 0, 5.4)
    add(mast, steel, foot)
    var head := Node3D.new()
    head.position = foot + Vector3(0, 6.4, 0)
    add_child(head)
    var lens := SphereMesh.new()
    lens.radius = 0.22
    lens.height = 0.44
    add(lens, MaterialKitClass.light(Color(1.0, 0.9, 0.7), 4.0), Vector3.ZERO, head)
    glow(Vector3.ZERO, Color(1.0, 0.88, 0.65), 2.0, 1.4, 0.8, head)
    var sweep := SpotLight3D.new()
    sweep.light_color = Color(1.0, 0.9, 0.7)
    sweep.light_energy = 6.0
    sweep.spot_range = 60.0
    sweep.spot_angle = 14.0
    sweep.rotation.x = deg_to_rad(-12.0)
    head.add_child(sweep)
    spin(head, Vector3.UP, 0.7)

    # deck lights in the theme's colour
    for i in 6:
        var angle := TAU * float(i) / 6.0 + PI / 6.0
        var at := Vector3(cos(angle) * 9.25, 1.12, sin(angle) * 9.25)
        glow(at, accent, 0.7, 1.3, 0.8)
        lamp(at, accent, 0.4, 4.5)

func _afloat() -> void:
    var red := StandardMaterial3D.new()
    red.albedo_color = Color(0.8, 0.12, 0.08)
    red.roughness = 0.5
    var body := MeshKitClass.lathe(PackedVector2Array([
        Vector2(0.0, 2.3), Vector2(0.07, 2.3), Vector2(0.1, 1.0), Vector2(0.55, 0.7), Vector2(0.7, 0.0), Vector2(0.5, -0.5), Vector2(0.0, -0.6),
    ]), 16)
    var rng := RandomNumberGenerator.new()
    rng.seed = 19
    for i in 5:
        var angle := rng.randf() * TAU
        var distance := rng.randf_range(16.0, 60.0)
        var buoy := add(body, red, Vector3(cos(angle) * distance, -2.5, sin(angle) * distance))
        blink(glow(Vector3(0, 2.4, 0), Color(1.0, 0.3, 0.2), 1.2, 2.0, 0.9, buoy), rng.randf_range(2.0, 3.4), rng.randf() * 3.0)
        _floating.append([buoy, -2.5, rng.randf() * TAU, 0.12])

    # a small boat tied up below
    var hull_wood := MaterialKitClass.surface("planks", 1.2, Color(0.9, 0.75, 0.6))
    var boat := Node3D.new()
    boat.position = Vector3(11.5, -2.4, 3.0)
    boat.rotation.y = 0.5
    add_child(boat)
    var shell := add(MeshKitClass.lathe(PackedVector2Array([
        Vector2(0.0, 0.5), Vector2(1.0, 0.5), Vector2(1.05, 0.4), Vector2(0.75, -0.1), Vector2(0.0, -0.3),
    ]), 20), hull_wood, Vector3.ZERO, boat)
    shell.scale = Vector3(1.0, 1.0, 2.6)
    _floating.append([boat, -2.4, 1.3, 0.07])

func _far_rocks() -> void:
    var dark := MaterialKitClass.surface("rock", 30.0, Color(0.16, 0.14, 0.16), 1.0, true)
    var rng := RandomNumberGenerator.new()
    rng.seed = 27
    for i in 7:
        var angle := rng.randf_range(-2.6, 0.4)
        var distance := rng.randf_range(260.0, 900.0)
        var stack := add(MeshKitClass.rock(500 + i, rng.randf_range(14.0, 46.0), 0.5, 12), dark,
            Vector3(sin(angle) * distance, -2.0, -cos(angle) * distance))
        stack.scale = Vector3(1.0, rng.randf_range(1.2, 2.6), 1.0)
        stack.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
