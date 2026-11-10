class_name AnomalyVoidRoom
extends RoomBase

# The Anomaly Room: the deck has drifted too close to a black hole. The
# floor is cracked and glowing, pieces of it circle away towards the dark,
# and nothing here quite holds still.

const BlackHole = preload("res://scripts/world/kit/black_hole.gd")

const HOLE := Vector3(-0.06, 0.50, -1.0)
# The hole and its disc, in units of its mass (GM/c², see kit/black_hole.gd). The deck is HOLE_AWAY
# metres from the hole's middle, and that is DECK_AWAY of these units: near enough for its light
# to bend round it in plain sight, outside the disc and the photon sphere. The disc's gas reaches
# from the innermost stable orbit (BlackHole.ISCO) out to DISC_OUT; the lens is drawn out to
# LENS_REACH, where what bending is left is eased away.
const HOLE_AWAY := 430.0
const DECK_AWAY := 40.0
const DISC_OUT := 22.0
const LENS_REACH := 34.0
# The deck sits this far above the disc's plane, so the disc is seen nearly edge on and its far
# side, bent back towards you, stands over the shadow; and the disc is rolled a little off level.
const ABOVE_DISC := deg_to_rad(11.0)
const DISC_ROLL := deg_to_rad(-14.0)

var _arcs: Array = []
var _lens: MeshInstance3D

func _build() -> void:
    var strange := accent.lerp(Color(0.9, 0.2, 0.75), 0.45)
    var env := environment(Color(0.20, 0.13, 0.26).lerp(strange, 0.25), 0.9)
    var sky := star_sky(env, Vector3(-0.6, 0.3, 0.7), 80.0, 0.9)
    sun(HOLE, Color(1.0, 0.8, 0.6), 2.4)        # the only light is the disc itself

    _black_hole(sky)
    _deck(strange)
    _debris()
    _shards(strange)
    if motes:
        # everything loose is being drawn the same way
        drift(Vector3(0, 3.0, -4.0), Vector3(12, 4, 14), 320, strange.lightened(0.4), 0.035, HOLE, 0.9, 0.9)
    probe()

# The black hole as light shows one (kit/black_hole.gd and black_hole.gdshader): its shadow, the
# photon ring just outside it, the thin hot disc of gas brighter and bluer on the side coming
# towards you, its far side bent up over the shadow and under it, and the stars behind pulled into
# rings. It is drawn on a ball round the hole that shows exactly the sky at its edge.
func _black_hole(sky: ShaderMaterial) -> void:
    var mass := HOLE_AWAY / DECK_AWAY
    var toward := HOLE.normalized()
    var centre := toward * HOLE_AWAY
    var back := -toward
    var up := (Vector3.UP - back * Vector3.UP.dot(back)).normalized()
    var axis := (up * cos(ABOVE_DISC) + back * sin(ABOVE_DISC)).normalized().rotated(back, DISC_ROLL)
    var across := axis.cross(Vector3.RIGHT if absf(axis.x) < 0.9 else Vector3.FORWARD).normalized()
    var ball := SphereMesh.new()
    ball.radius = LENS_REACH * mass
    ball.height = ball.radius * 2.0
    ball.radial_segments = 64
    ball.rings = 32
    _lens = add(ball, MaterialKitClass.shader("res://assets/shaders/black_hole.gdshader", {
        "lens": BlackHole.table(DECK_AWAY, LENS_REACH),
        "hole": centre, "mass": mass, "reach": asin(LENS_REACH / DECK_AWAY), "sweep": BlackHole.SWEEP,
        "spin": axis, "disc_x": across, "disc_in": BlackHole.ISCO, "disc_out": DISC_OUT,
        "stars": sky.get_shader_parameter("stars"), "orient": sky.get_shader_parameter("orient"),
        "star_energy": sky.get_shader_parameter("energy"), "contrast": sky.get_shader_parameter("contrast"),
        "lod": sky.get_shader_parameter("lod"),
    }), centre)
    _lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

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

# What surprised ELI, and what it was told two ways, pinned to the pylons round the deck, one sheet
# each, facing the middle: the user can take one down and ask ELI about it.
func pin_spot(kind: String, index: int) -> Variant:
    if kind != "thought" or index < 0 or index >= 6:
        return null
    var angle := TAU * float(index) / 6.0
    var at := Vector3(cos(angle), 0.0, sin(angle)) * 8.25
    return Transform3D(Basis(Vector3.UP, atan2(-at.x, -at.z)), at + Vector3(0, 1.3, 0))

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
