class_name AnomalyVoidRoom
extends RoomBase

# The Anomaly Room: the deck has drifted too close to a black hole. The
# floor is cracked and glowing, pieces of it circle away towards the dark,
# and nothing here quite holds still.

const HOLE := Vector3(-0.06, 0.50, -1.0)

var _arcs: Array = []

func _build() -> void:
    var strange := accent.lerp(Color(0.9, 0.2, 0.75), 0.45)
    var env := environment(Color(0.20, 0.13, 0.26).lerp(strange, 0.25), 0.9)
    star_sky(env, Vector3(-0.6, 0.3, 0.7), 80.0, 0.9)
    sun(HOLE, Color(1.0, 0.74, 0.48), 2.4)      # the only light is the disc itself

    _black_hole(strange)
    _deck(strange)
    _debris()
    _shards(strange)
    if motes:
        # everything loose is being drawn the same way
        drift(Vector3(0, 3.0, -4.0), Vector3(12, 4, 14), 320, strange.lightened(0.4), 0.035, HOLE, 0.9, 0.9)
    probe()

func _black_hole(strange: Color) -> void:
    var centre := HOLE.normalized() * 430.0
    var dark := StandardMaterial3D.new()
    dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    dark.albedo_color = Color.BLACK
    var ball := SphereMesh.new()
    ball.radius = 62.0
    ball.height = 124.0
    add(ball, dark, centre).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    var disc := add(MeshKitClass.annulus(75.0, 235.0, 160), MaterialKitClass.shader("res://assets/shaders/accretion.gdshader", {
        "cool": rgb(strange),
    }), centre)
    # tipped towards us, so the whole whirlpool shows
    disc.rotation = Vector3(deg_to_rad(64.0), 0.0, deg_to_rad(-14.0))
    disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    # light from behind the hole, bent round it into a ring
    var bent := TorusMesh.new()
    bent.inner_radius = 64.0
    bent.outer_radius = 70.0
    bent.rings = 128
    bent.ring_segments = 8
    var ring := add(bent, MaterialKitClass.light(Color(1.0, 0.86, 0.66), 2.6), centre)
    ring.basis = Basis.looking_at(-centre.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
    ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    glow(centre, Color(1.0, 0.6, 0.3), 720.0, 1.3, 0.0)

func _deck(strange: Color) -> void:
    var plating := MaterialKitClass.metal("hull_panels", 2.4, Color(0.52, 0.50, 0.58), 0.6)
    var hull := MaterialKitClass.metal("hull_panels", 1.8, Color(0.26, 0.26, 0.32))
    deck(9.0, plating, hull, false)

    # cracks, lit from underneath, breathing out of step with each other
    var rng := RandomNumberGenerator.new()
    rng.seed = 11
    for i in 9:
        var angle := TAU * float(i) / 9.0 + rng.randf_range(-0.2, 0.2)
        var path := PackedVector3Array()
        var radius := rng.randf_range(0.8, 2.0)
        while radius < 9.0:
            angle += rng.randf_range(-0.16, 0.16)
            path.append(Vector3(cos(angle) * radius, 0.007, sin(angle) * radius))
            radius += rng.randf_range(0.5, 1.1)
        if path.size() > 2:
            add(MeshKitClass.beam(path, Vector3.UP.cross(path[1] - path[0]), 0.05, 0.004), MaterialKitClass.shader(
                "res://assets/shaders/light_strip.gdshader",
                {"tint": rgb(strange), "energy": 2.2, "wave": 0.5, "speed": 0.18 + 0.05 * (i % 3), "phase": float(i) * 1.7}))

    # pylons that still try to hold a field up, and arcs that jump between them
    var post := MeshKitClass.lathe(PackedVector2Array([
        Vector2(0.0, 2.6), Vector2(0.06, 2.6), Vector2(0.1, 2.2), Vector2(0.07, 0.3), Vector2(0.22, 0.0), Vector2(0.0, 0.0),
    ]), 6)
    var tops: Array[Vector3] = []
    for i in 6:
        var angle := TAU * float(i) / 6.0
        var at := Vector3(cos(angle), 0.0, sin(angle)) * 8.4
        add(post, hull, at)
        tops.append(at + Vector3(0, 2.6, 0))
        glow(at + Vector3(0, 2.62, 0), strange, 0.9, 1.6, 0.9)
        lamp(at + Vector3(0, 2.4, 0), strange, 0.55, 5.0)
    for i in tops.size():
        var from := tops[i]
        var to := tops[(i + 2) % tops.size()]
        var path := PackedVector3Array()
        for s in 9:
            var t := float(s) / 8.0
            path.append(from.lerp(to, t) + Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.2, 0.5), rng.randf_range(-0.3, 0.3)) * sin(t * PI))
        var arc := add(MeshKitClass.beam(path, Vector3.UP, 0.025, 0.025), MaterialKitClass.light(strange.lightened(0.6), 3.5))
        arc.visible = false
        _arcs.append(arc)

func _animate(_delta: float) -> void:
    # an arc jumps now and then, never the same one twice running
    for i in _arcs.size():
        var beat := fmod(_clock * (0.9 + 0.13 * i) + float(i) * 2.1, 5.0)
        (_arcs[i] as Node3D).visible = beat < 0.09 or (beat > 0.16 and beat < 0.21)

func _debris() -> void:
    var plating := MaterialKitClass.metal("hull_panels", 1.4, Color(0.34, 0.34, 0.40), 0.7)
    var rng := RandomNumberGenerator.new()
    rng.seed = 23
    # slabs torn off the rim, spiralling in
    for ring_index in 3:
        var carrier := Node3D.new()
        carrier.rotation = Vector3(deg_to_rad(rng.randf_range(-14.0, 14.0)), 0.0, deg_to_rad(rng.randf_range(-12.0, 12.0)))
        add_child(carrier)
        var slab := MeshKitClass.lathe(PackedVector2Array([
            Vector2(0.0, 0.07), Vector2(1.0, 0.07), Vector2(1.0, -0.07), Vector2(0.0, -0.07),
        ]), 5 + ring_index)
        var many := MultiMesh.new()
        many.transform_format = MultiMesh.TRANSFORM_3D
        many.mesh = slab
        many.instance_count = 18
        for i in 18:
            var angle := rng.randf() * TAU
            var distance := rng.randf_range(12.0, 46.0) + ring_index * 9.0
            var basis := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)).scaled(
                Vector3(rng.randf_range(0.4, 1.9), 1.0, rng.randf_range(0.4, 1.9)))
            many.set_instance_transform(i, Transform3D(basis, Vector3(cos(angle) * distance, rng.randf_range(-6.0, 9.0), sin(angle) * distance)))
        var field := MultiMeshInstance3D.new()
        field.multimesh = many
        field.material_override = plating
        carrier.add_child(field)
        spin(carrier, Vector3.UP, 0.03 - 0.008 * ring_index)

func _shards(strange: Color) -> void:
    # splinters of something that should not be here, turning slowly
    var rng := RandomNumberGenerator.new()
    rng.seed = 5
    var crystal := MeshKitClass.lathe(PackedVector2Array([
        Vector2(0.0, 1.6), Vector2(0.28, 0.5), Vector2(0.34, 0.0), Vector2(0.2, -0.7), Vector2(0.0, -1.4),
    ]), 4)
    for i in 7:
        var angle := TAU * float(i) / 7.0 + 0.3
        var at := Vector3(cos(angle) * rng.randf_range(10.5, 15.0), rng.randf_range(1.5, 6.5), sin(angle) * rng.randf_range(10.5, 15.0))
        var shard := add(crystal, MaterialKitClass.glass(strange, 0.45, 0.9), at)
        shard.scale = Vector3.ONE * rng.randf_range(0.6, 1.5)
        shard.rotation = Vector3(rng.randf() * TAU, 0.0, rng.randf() * TAU)
        spin(shard, Vector3(rng.randf(), 1.0, rng.randf()), rng.randf_range(0.1, 0.3) * (1.0 if i % 2 == 0 else -1.0))
        glow(at, strange, 2.2, 0.5, 0.2)
