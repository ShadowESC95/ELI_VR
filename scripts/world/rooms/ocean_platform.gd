class_name OceanPlatformRoom
extends RoomBase

# Ocean Platform: a deck on legs out at sea as the sun goes down. The swell
# really moves near the rig and carries the sunset and the sun's glitter;
# buoys, the boat and the foam round the legs ride the same waves; a beacon
# turns; gulls work the air round the rig, beating and gliding.

const SUNSET := Vector3(0.711, 0.148, -0.687)
const SEA_Y := -2.6               # the still water line, metres below the deck
const SEA_REACH := 4500.0         # how far out the sea is laid
# The swell, one train per row: direction (x, z), wavelength (m), height (m, half the crest to
# trough), and how far the water goes round in it (Gerstner steepness). A calm sea at sunset: a
# long swell and the shorter waves the evening breeze raises, none steep enough to break
# (height over wavelength well under 1/7). Their speed is deep water's, from their length.
const SWELL := [
    [Vector2(1.0, 0.25), 48.0, 0.32, 0.35],
    [Vector2(0.6, -0.8), 21.0, 0.16, 0.4],
    [Vector2(-0.3, 1.0), 9.0, 0.07, 0.45],
    [Vector2(0.9, 0.45), 4.3, 0.03, 0.5],
]

var _floating: Array = []     # [node, height above the water, how much it leans with the swell, its heading]
var _sea: ShaderMaterial

func _build() -> void:
    var env := environment(Color(0.55, 0.5, 0.6), 1.0)
    # only the sky is wanted from the photograph: the sea below is made here
    photo_sky(env, "sunset_sea", 100000.0, -4000.0, 1.0)
    env.ambient_light_energy = 1.15
    sun(SUNSET, Color(1.0, 0.68, 0.45), 1.5)

    _water()
    _rig()
    _afloat()
    _far_rocks()
    _stores()
    _shoals()
    # gulls round the rig, out past the deck and the beacon, over the water
    flock("gull", Vector3.ZERO, 15.0, 55.0, 14, SEA_Y)
    if motes:
        drift(Vector3(0, 2.0, 0), Vector3(12, 2, 12), 160, Color(1.0, 0.85, 0.7), 0.025, Vector3(1, 0.1, 0.2), 0.4, 0.6)
    probe(Vector3(30, 14, 30))

# The sea: rings finest under the rig (MeshKit.disc), the swell moved on it in water.gdshader.
func _water() -> void:
    var rings := 140
    var first := 0.4
    var growth := MeshKitClass.disc_growth(SEA_REACH, rings, first)
    var waves := PackedVector4Array()
    var steep := PackedFloat32Array()
    for train in SWELL:
        var way: Vector2 = (train[0] as Vector2).normalized()
        waves.append(Vector4(way.x, way.y, float(train[1]), float(train[2])))
        steep.append(float(train[3]))
    _sea = MaterialKitClass.shader("res://assets/shaders/water.gdshader", {
        "photo": load("res://assets/skies/sunset_sea.jpg"), "sun_dir": SUNSET.normalized(),
        "waves": waves, "steep": steep, "growth": growth,
        "offset": SEA_REACH / (exp(growth * float(rings)) - 1.0),
    })
    var sea := add(MeshKitClass.disc(SEA_REACH, rings, 160, first), _sea, Vector3(0, SEA_Y, 0))
    sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## The water's height at (x, z) now: the same swell the sea is drawn with (water.gdshader), read at
## the point under it (the swell's sideways sway, a few centimetres, is left out).
func sea_height(x: float, z: float) -> float:
    var y := SEA_Y
    for train in SWELL:
        var way: Vector2 = (train[0] as Vector2).normalized()
        var k := TAU / float(train[1])
        y += float(train[2]) * sin(k * (way.x * x + way.y * z) - sqrt(9.81 * k) * _clock)
    return y

func _animate(_delta: float) -> void:
    _sea.set_shader_parameter("clock", _clock)
    for entry in _floating:
        var node := entry[0] as Node3D
        var x := node.position.x
        var z := node.position.z
        node.position.y = sea_height(x, z) + float(entry[1])
        var lean := float(entry[2])
        if lean > 0.0:
            # lean with the water's slope under it, still facing its own way
            var step := 0.6
            var dx := (sea_height(x + step, z) - sea_height(x - step, z)) / (2.0 * step)
            var dz := (sea_height(x, z + step) - sea_height(x, z - step)) / (2.0 * step)
            var up := Vector3(-dx * lean, 1.0, -dz * lean).normalized()
            var axis := Vector3.UP.cross(up)
            var tilt := Basis(axis.normalized(), Vector3.UP.angle_to(up)) if axis.length() > 1e-5 else Basis.IDENTITY
            node.basis = tilt * Basis(Vector3.UP, float(entry[3]))

func _rig() -> void:
    var boards := MaterialKitClass.surface("planks", 2.4, Color(1.15, 1.0, 0.9), 0.85)
    var steel := MaterialKitClass.metal("hull_panels", 1.6, Color(0.5, 0.5, 0.54), 0.9)
    var rail_metal := MaterialKitClass.metal("brushed_metal", 0.6, Color(0.8, 0.8, 0.84), 0.8)
    deck(9.0, boards, steel)

    # legs down into the water, braced, the sea breaking white round each
    var leg := CylinderMesh.new()
    leg.top_radius = 0.34
    leg.bottom_radius = 0.4
    leg.height = 9.0
    for i in 6:
        var angle := TAU * float(i) / 6.0
        add(leg, steel, Vector3(cos(angle) * 7.6, -5.0, sin(angle) * 7.6))
        _foam(Vector3(cos(angle) * 7.6, SEA_Y + 0.05, sin(angle) * 7.6), 0.38, 1.3, float(i))

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
        var buoy := add(body, red, Vector3(cos(angle) * distance, SEA_Y, sin(angle) * distance))
        blink(glow(Vector3(0, 2.4, 0), Color(1.0, 0.3, 0.2), 1.2, 2.0, 0.9, buoy), rng.randf_range(2.0, 3.4), rng.randf() * 3.0)
        _floating.append([buoy, 0.0, 1.0, 0.0])

    # a small boat tied up below: a clinker dinghy (MeshKit.hull), its seats across it, a line to the
    # nearest leg
    var hull_wood := MaterialKitClass.surface("planks", 1.2, Color(0.9, 0.75, 0.6))
    hull_wood.cull_mode = BaseMaterial3D.CULL_DISABLED
    var seat_wood := MaterialKitClass.surface("planks", 0.8, Color(0.75, 0.6, 0.45))
    var boat := Node3D.new()
    boat.position = Vector3(11.5, SEA_Y, 3.0)
    boat.rotation.y = 0.5
    add_child(boat)
    var length := 3.6
    var beam := 1.4
    var depth := 0.55
    add(MeshKitClass.hull(length, beam, depth), hull_wood, Vector3(0, depth * 0.55, 0), boat)
    for along in [-0.3, 0.05, 0.3]:
        box(Vector3(beam * (0.92 if along < 0.2 else 0.7), 0.04, 0.24), seat_wood, Vector3(0, depth * 0.55 - 0.08, along * length), boat)
    var leg := Vector3(7.6, 0.0, 0.0)       # the nearest of the rig's legs
    var bow := boat.position + Vector3(0, depth * 0.8, -length * 0.45).rotated(Vector3.UP, boat.rotation.y)
    var line := PackedVector3Array()
    for k in 9:
        var t := float(k) / 8.0
        line.append(bow.lerp(leg + Vector3(0, SEA_Y + 1.1, 0), t) + Vector3(0, -0.5 * sin(t * PI), 0))
    var rope := StandardMaterial3D.new()
    rope.albedo_color = Color(0.55, 0.45, 0.3)
    rope.roughness = 0.9
    add(MeshKitClass.beam(line, Vector3.UP.cross(line[8] - line[0]).normalized(), 0.025, 0.025), rope)
    _floating.append([boat, 0.0, 1.0, boat.rotation.y])

# What a working platform keeps on deck (scanned, assets/models).
func _stores() -> void:
    prop("wooden_barrels_01", Vector3(5.2, 0.0, -5.6), 20.0, 0.9)
    prop("wooden_crate_01", Vector3(6.6, 0.0, -3.4), -15.0, 1.0)
    prop("wooden_crate_01", Vector3(7.2, 0.35, -3.6), 40.0, 1.0)
    prop("wooden_crate_01", Vector3(-6.8, 0.0, 4.2), 70.0, 1.0)
    for at in [Vector3(-7.0, 1.05, -5.2), Vector3(7.4, 1.05, 4.9), Vector3(0.6, 1.05, 8.6)]:
        prop("wooden_lantern_01", at, 0.0, 1.0)
        glow(at + Vector3(0, 0.3, 0), Color(1.0, 0.8, 0.5), 0.5, 1.2, 0.7)
    # on the beacon's mast a lifebuoy and a light; a hose on its post; containers by the barrels;
    # somewhere to sit; lamps at the rail for the dark
    var foot := Vector3(-6.4, 0.0, 5.4)
    var inward := -foot.normalized()
    var facing := rad_to_deg(atan2(inward.x, inward.z))
    prop("lifebuoy", foot + inward * 0.22 + Vector3(0, 1.3, 0), facing)
    prop("security_light", foot + inward * 0.2 + Vector3(0, 5.6, 0), facing)
    var steel := MaterialKitClass.metal("brushed_metal", 0.6, Color(0.6, 0.62, 0.66), 0.7)
    rod(0.03, 1.1, steel, Vector3(7.6, 0.55, 4.2))
    prop("garden_hose_wall_mounted_01", Vector3(7.5, 0.95, 4.1), rad_to_deg(atan2(-7.6, -4.2)))
    prop("industrial_pastic_container", Vector3(4.3, 0.0, -6.2), 25.0)
    prop("industrial_pastic_container", Vector3(4.4, 0.45, -6.25), 10.0)
    prop("folding_wooden_stool", Vector3(-6.0, 0.0, 2.6), 40.0)
    prop("metal_stool_01", Vector3(6.9, 0.0, 5.3), 0.0)
    var cool := Color(0.9, 0.95, 1.0)
    for degrees in [-58.0, 58.0]:
        var a := deg_to_rad(degrees)
        var at := Vector3(sin(a), 0.0, -cos(a)) * 8.6
        prop("street_lamp_02", at + Vector3(0, 0.39, 0), rad_to_deg(atan2(-at.x, -at.z)))
        glow(at + Vector3(0, 1.9, 0), cool, 0.7, 1.0, 0.7)
        lamp(at + Vector3(0, 1.85, 0), cool, 0.8, 6.0)

# Rocks breaking the water near the legs, part under, part over the swell, the sea foaming round them.
func _shoals() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 23
    for i in 7:
        var angle := rng.randf_range(0.6, 5.4)
        var distance := rng.randf_range(13.0, 26.0)
        var size := rng.randf_range(1.4, 2.8)
        var at := Vector3(cos(angle) * distance, SEA_Y - rng.randf_range(0.1, 0.5), sin(angle) * distance)
        prop("coast_rocks_05" if i % 2 else "sand_rocks_small_01", at, rng.randf() * 360.0, size)
        _foam(Vector3(at.x, SEA_Y + 0.05, at.z), 0.6 * size, 2.0 * size, 10.0 + float(i))

# Foam at the waterline round something standing in the sea: a ring from `inner` to `outer` metres.
func _foam(at: Vector3, inner: float, outer: float, seed_value: float) -> void:
    var ring := add(MeshKitClass.annulus(inner, outer, 48), MaterialKitClass.shader("res://assets/shaders/foam.gdshader", {
        "inner": inner, "outer": outer, "seed": seed_value, "energy": 0.7,
    }), at)
    ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _floating.append([ring, at.y - SEA_Y, 0.0, 0.0])

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
