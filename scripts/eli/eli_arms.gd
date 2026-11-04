class_name EliArms
extends RefCounted

# The guns of ELI's range (eli/world/games.py, ARMS): what each looks like, where its muzzle is, and
# the sound it makes. ELI's world says what they are and how each fires (fire, rate, spread, shots,
# speed, drop, hold, charge); this builds each from parts in the scanned metals, wood and polymer,
# and makes its sound in code, so nothing is downloaded and nothing is a recording. Real guns are
# dull metal and wood; the energy and sci-fi ones carry ELI's colour in their coils, lenses and rails.

const SAMPLE_RATE := 22050

static var _sounds := {}

# --- the looks --------------------------------------------------------------------------------------

## Build the arm `id` on `body`, lying along -Z with its grip under the origin (the hand), coloured
## `tint` where it glows. {"muzzle": where shots leave, in body space; "length": how long it is}.
static func build(body: Node3D, id: String, tint: Color) -> Dictionary:
    var dark := MaterialKit.painted("hull_panels", 0.3, Color(0.11, 0.11, 0.12), 0.5)
    var steel := MaterialKit.metal("brushed_metal", 0.3, Color(0.66, 0.68, 0.72), 0.6)
    var blued := MaterialKit.metal("brushed_metal", 0.3, Color(0.3, 0.32, 0.36), 0.7)
    var wood := MaterialKit.surface("planks", 0.5, Color(0.62, 0.42, 0.26), 0.8)
    var glow := MaterialKit.light(tint, 2.6)
    match id:
        "pistol":
            _box(body, Vector3(0.03, 0.05, 0.16), Vector3(0, 0.01, -0.06), dark)
            _box(body, Vector3(0.032, 0.036, 0.19), Vector3(0, 0.052, -0.07), blued)
            _cyl(body, 0.008, 0.05, Vector3(0, 0.052, -0.185), steel, Vector3(90, 0, 0))
            _box(body, Vector3(0.03, 0.09, 0.04), Vector3(0, -0.045, 0.0), dark, Vector3(-16, 0, 0))
            _box(body, Vector3(0.028, 0.006, 0.05), Vector3(0, -0.012, -0.045), steel)          # the trigger guard
            _box(body, Vector3(0.004, 0.008, 0.012), Vector3(0, -0.02, -0.03), steel)           # the trigger
            _box(body, Vector3(0.004, 0.008, 0.006), Vector3(0, 0.074, -0.16), steel)           # the sights
            _box(body, Vector3(0.012, 0.008, 0.006), Vector3(0, 0.074, 0.02), steel)
            return {"muzzle": Vector3(0, 0.052, -0.21), "length": 0.27}
        "rifle":
            _box(body, Vector3(0.045, 0.07, 0.3), Vector3(0, 0.03, -0.1), dark)
            _box(body, Vector3(0.04, 0.05, 0.25), Vector3(0, 0.045, -0.35), dark)               # the handguard
            _cyl(body, 0.011, 0.46, Vector3(0, 0.06, -0.48), blued, Vector3(90, 0, 0))
            _box(body, Vector3(0.04, 0.065, 0.24), Vector3(0, 0.015, 0.18), wood, Vector3(-6, 0, 0))  # the stock
            _box(body, Vector3(0.03, 0.12, 0.06), Vector3(0, -0.07, -0.1), blued, Vector3(12, 0, 0))   # the magazine
            _box(body, Vector3(0.03, 0.085, 0.04), Vector3(0, -0.04, 0.02), dark, Vector3(-18, 0, 0))  # the grip
            _cyl(body, 0.02, 0.16, Vector3(0, 0.115, -0.1), blued, Vector3(90, 0, 0))            # the scope
            _box(body, Vector3(0.01, 0.03, 0.03), Vector3(0, 0.09, -0.1), steel)
            _cyl(body, 0.017, 0.006, Vector3(0, 0.115, -0.182), glow, Vector3(90, 0, 0))        # its lens
            return {"muzzle": Vector3(0, 0.06, -0.72), "length": 0.9}
        "shotgun":
            for x in [-0.013, 0.013]:
                _cyl(body, 0.012, 0.56, Vector3(x, 0.06, -0.45), blued, Vector3(90, 0, 0))
            _box(body, Vector3(0.05, 0.07, 0.14), Vector3(0, 0.04, -0.1), steel)                # the action
            _box(body, Vector3(0.045, 0.045, 0.22), Vector3(0, 0.032, -0.3), wood)              # the fore-end
            _box(body, Vector3(0.045, 0.075, 0.28), Vector3(0, 0.01, 0.2), wood, Vector3(-8, 0, 0))  # the stock
            _box(body, Vector3(0.028, 0.006, 0.05), Vector3(0, -0.005, -0.06), steel)
            _box(body, Vector3(0.004, 0.01, 0.012), Vector3(0, -0.014, -0.045), steel)
            _box(body, Vector3(0.006, 0.006, 0.006), Vector3(0, 0.078, -0.72), steel)           # the bead
            return {"muzzle": Vector3(0, 0.06, -0.735), "length": 0.95}
        "bolt":
            _ball(body, 0.06, Vector3(0, 0.05, -0.08), dark)
            _cyl(body, 0.03, 0.22, Vector3(0, 0.05, -0.26), blued, Vector3(90, 0, 0))
            for i in 3:
                _torus(body, 0.034, 0.05, Vector3(0, 0.05, -0.18 - 0.06 * i), glow, Vector3(90, 0, 0))
            _ball(body, 0.025, Vector3(0, 0.05, -0.375), glow)
            _light(body, Vector3(0, 0.05, -0.375), tint, 0.6, 1.2)
            _box(body, Vector3(0.03, 0.09, 0.04), Vector3(0, -0.045, 0.0), dark, Vector3(-16, 0, 0))
            _box(body, Vector3(0.028, 0.006, 0.05), Vector3(0, -0.012, -0.045), steel)
            return {"muzzle": Vector3(0, 0.05, -0.39), "length": 0.45}
        "beam":
            _cyl(body, 0.02, 0.5, Vector3(0, 0.05, -0.3), steel, Vector3(90, 0, 0))
            _box(body, Vector3(0.04, 0.06, 0.16), Vector3(0, 0.04, -0.03), dark)
            for turn in [0.0, 120.0, 240.0]:                                                      # three fins
                var fin := _box(body, Vector3(0.004, 0.05, 0.12), Vector3(0, 0.05, -0.16), blued)
                fin.rotation_degrees.z = turn
                fin.position += Vector3(sin(deg_to_rad(turn)), cos(deg_to_rad(turn)), 0.0) * 0.03
            _cyl(body, 0.04, 0.012, Vector3(0, 0.05, -0.56), glow, Vector3(90, 0, 0))           # the lens
            _box(body, Vector3(0.006, 0.006, 0.42), Vector3(0, 0.074, -0.32), glow)             # the strip along the top
            _light(body, Vector3(0, 0.05, -0.56), tint, 0.5, 1.2)
            _box(body, Vector3(0.03, 0.09, 0.04), Vector3(0, -0.045, 0.0), dark, Vector3(-16, 0, 0))
            _box(body, Vector3(0.028, 0.006, 0.05), Vector3(0, -0.012, -0.045), steel)
            return {"muzzle": Vector3(0, 0.05, -0.57), "length": 0.62}
        "rail":
            _box(body, Vector3(0.06, 0.08, 0.34), Vector3(0, 0.04, -0.12), dark)
            for x in [-0.025, 0.025]:
                _box(body, Vector3(0.012, 0.012, 0.42), Vector3(x, 0.07, -0.42), steel)         # the rails
                _box(body, Vector3(0.012, 0.03, 0.02), Vector3(x, 0.085, -0.62), steel)         # the fork at the muzzle
                _cyl(body, 0.02, 0.12, Vector3(x * 1.8, 0.02, -0.08), glow, Vector3(90, 0, 0))   # the capacitors
            _box(body, Vector3(0.05, 0.004, 0.4), Vector3(0, 0.064, -0.42), glow)              # the field between the rails
            _box(body, Vector3(0.04, 0.07, 0.2), Vector3(0, 0.0, 0.18), dark, Vector3(-6, 0, 0))   # the stock
            _box(body, Vector3(0.03, 0.09, 0.04), Vector3(0, -0.045, 0.0), dark, Vector3(-16, 0, 0))
            _box(body, Vector3(0.028, 0.006, 0.05), Vector3(0, -0.012, -0.045), steel)
            _light(body, Vector3(0, 0.07, -0.5), tint, 0.4, 1.4)
            return {"muzzle": Vector3(0, 0.07, -0.63), "length": 0.9}
    # a gun ELI's world names that this body does not know: a plain barrel, so it is still a gun
    _cyl(body, 0.015, 0.3, Vector3(0, 0.05, -0.17), steel, Vector3(90, 0, 0))
    _box(body, Vector3(0.03, 0.09, 0.04), Vector3(0, -0.045, 0.0), dark, Vector3(-16, 0, 0))
    return {"muzzle": Vector3(0, 0.05, -0.33), "length": 0.4}

static func _mesh(body: Node3D, mesh: Mesh, at: Vector3, material: Material, rot: Vector3) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.material_override = material
    node.position = at
    node.rotation_degrees = rot
    body.add_child(node)
    return node

static func _box(body: Node3D, size: Vector3, at: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    return _mesh(body, mesh, at, material, rot)

static func _cyl(body: Node3D, radius: float, length: float, at: Vector3, material: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = length
    mesh.radial_segments = 14
    return _mesh(body, mesh, at, material, rot)

static func _ball(body: Node3D, radius: float, at: Vector3, material: Material) -> MeshInstance3D:
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 16
    mesh.rings = 8
    return _mesh(body, mesh, at, material, Vector3.ZERO)

static func _torus(body: Node3D, inner: float, outer: float, at: Vector3, material: Material, rot: Vector3) -> MeshInstance3D:
    var mesh := TorusMesh.new()
    mesh.inner_radius = inner
    mesh.outer_radius = outer
    mesh.rings = 24
    mesh.ring_segments = 8
    return _mesh(body, mesh, at, material, rot)

static func _light(body: Node3D, at: Vector3, tint: Color, energy: float, reach: float) -> OmniLight3D:
    var light := OmniLight3D.new()
    light.position = at
    light.light_color = tint
    light.light_energy = energy
    light.omni_range = reach
    light.shadow_enabled = false
    body.add_child(light)
    return light

# --- the sounds ---------------------------------------------------------------------------------

## The sound a way of firing makes, made once: a shot's crack and thump, a bolt's falling whine, a
## beam's hum (looped while it fires), a rail gun's rising charge and crack.
static func sound(fire: String) -> AudioStreamWAV:
    if _sounds.has(fire):
        return _sounds[fire]
    var seconds: float = float({"shot": 0.22, "bolt": 0.32, "beam": 0.5, "rail": 0.75}.get(fire, 0.22))
    var count := int(SAMPLE_RATE * seconds)
    var rng := RandomNumberGenerator.new()
    rng.seed = fire.hash()
    var data := PackedByteArray()
    data.resize(count * 2)
    for i in count:
        var t := float(i) / SAMPLE_RATE
        var v := 0.0
        match fire:
            "shot":
                v = rng.randf_range(-1.0, 1.0) * exp(-t / 0.028) * 0.9 + sin(TAU * 70.0 * t) * exp(-t / 0.09) * 0.6
            "bolt":
                var f := lerpf(900.0, 240.0, clampf(t / 0.3, 0.0, 1.0))
                v = sin(TAU * f * t) * minf(t / 0.02, 1.0) * exp(-t / 0.14) * 0.8 + rng.randf_range(-1.0, 1.0) * 0.04 * exp(-t / 0.1)
            "beam":
                v = (sin(TAU * 110.0 * t) * 0.5 + sin(TAU * 221.0 * t) * 0.3 + sin(TAU * 442.0 * t) * 0.1) * 0.6 \
                    + rng.randf_range(-1.0, 1.0) * 0.04
            "rail":
                if t < 0.5:
                    var f2 := lerpf(180.0, 1600.0, t / 0.5)
                    v = sin(TAU * f2 * t) * 0.5 * (0.3 + t)
                else:
                    var u := t - 0.5
                    v = rng.randf_range(-1.0, 1.0) * exp(-u / 0.04) * 0.95 + sin(TAU * 90.0 * u) * exp(-u / 0.1) * 0.5
        var sample := int(clampf(v, -1.0, 1.0) * 32767.0)
        data.encode_s16(i * 2, sample)
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = SAMPLE_RATE
    stream.stereo = false
    stream.data = data
    if fire == "beam":
        stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
        stream.loop_begin = 0
        stream.loop_end = count
    _sounds[fire] = stream
    return stream
