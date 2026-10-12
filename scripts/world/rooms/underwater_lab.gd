class_name UnderwaterLabRoom
extends RoomBase

# Underwater Research Lab: a glass dome on the seabed. Light comes down in
# shafts and ripples over the sand, kelp leans in the current, fish go by in
# shoals, bubbles rise.

var _shoals: Array = []

func _build() -> void:
    var water := Color(0.02, 0.17, 0.24)
    var env := environment(Color(0.08, 0.28, 0.36), 0.8)
    env.background_mode = Environment.BG_COLOR
    env.background_color = water
    env.fog_enabled = true
    env.fog_light_color = water * 1.6
    env.fog_density = 0.028
    sun(Vector3(0.2, 1.0, 0.15), Color(0.6, 0.95, 1.0), 1.0)

    _seabed()
    _surface_and_shafts()
    _kelp()
    _fish()
    _dome()
    if motes:
        # bubbles going up, and the fine stuff that hangs in the water
        drift(Vector3(0, 6.0, 0), Vector3(20, 7, 20), 420, Color(0.8, 1.0, 1.0), 0.06, Vector3(0.05, 1, 0.02), 0.7, 0.9)
        drift(Vector3(0, 4.0, 0), Vector3(22, 5, 22), 500, Color(0.6, 0.9, 0.85), 0.025, Vector3(1, 0.1, 0.3), 0.08, 0.5)
    probe()

func _seabed() -> void:
    var noise := FastNoiseLite.new()
    noise.seed = 52
    noise.frequency = 0.03
    noise.fractal_octaves = 3
    var sand := MaterialKitClass.surface("sand", 3.0, Color(0.5, 0.62, 0.6), 0.95)
    sand.next_pass = MaterialKitClass.shader("res://assets/shaders/caustics.gdshader", {"energy": 0.16})
    add(MeshKitClass.terrain(300.0, 120, noise, 7.0, 12.0, 14.0, 22.0, -0.2), sand)

    var stone := MaterialKitClass.surface("moss_rock", 2.0, Color(0.55, 0.7, 0.66), 1.0, true)
    stone.next_pass = MaterialKitClass.shader("res://assets/shaders/caustics.gdshader", {"energy": 0.12})
    var rng := RandomNumberGenerator.new()
    rng.seed = 33
    for i in 24:
        var angle := rng.randf() * TAU
        var distance := rng.randf_range(12.5, 48.0)
        var boulder := add(MeshKitClass.rock(700 + i, rng.randf_range(0.6, 3.4), 0.38, 10), stone,
            Vector3(cos(angle) * distance, rng.randf_range(-0.3, 1.2), sin(angle) * distance))
        boulder.rotation.y = rng.randf() * TAU

func _surface_and_shafts() -> void:
    # the underside of the surface, far overhead
    var top := add(MeshKitClass.annulus(0.0, 260.0, 64), MaterialKitClass.shader("res://assets/shaders/caustics.gdshader", {
        "energy": 0.5, "scale": 0.02, "tint": Vector3(0.6, 0.95, 1.0),
    }), Vector3(0, 44.0, 0))
    top.rotation.x = PI
    top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    var beam := QuadMesh.new()
    beam.size = Vector2(5.0, 34.0)
    var rng := RandomNumberGenerator.new()
    rng.seed = 61
    for i in 14:
        var angle := rng.randf() * TAU
        var distance := rng.randf_range(8.0, 40.0)
        var shaft := add(beam, MaterialKitClass.shader("res://assets/shaders/light_shaft.gdshader", {
            "seed": float(i) * 2.3, "energy": 0.22, "tint": Vector3(0.6, 1.0, 0.95),
        }), Vector3(cos(angle) * distance, 15.0, sin(angle) * distance))
        shaft.rotation = Vector3(0.0, rng.randf() * TAU, deg_to_rad(rng.randf_range(-14.0, 14.0)))
        shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _kelp() -> void:
    var blade := MaterialKitClass.shader("res://assets/shaders/sway.gdshader", {
        "leaf": load("res://assets/materials/kelp_blade.png"), "tint": Vector3(0.7, 1.0, 0.75), "reach": 0.9, "pace": 0.5, "glow": 0.08,
    })
    var rng := RandomNumberGenerator.new()
    rng.seed = 71
    for kind in 3:
        var stalk := MeshKitClass.plant(4 + kind, 0.5, 8.0 + 3.0 * kind, 1.2, 80 + kind, 10)
        var many := MultiMesh.new()
        many.transform_format = MultiMesh.TRANSFORM_3D
        many.mesh = stalk
        many.instance_count = 40
        for i in 40:
            var angle := rng.randf() * TAU
            var distance := rng.randf_range(13.0, 46.0)
            var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.6, 1.3))
            many.set_instance_transform(i, Transform3D(basis, Vector3(cos(angle) * distance, -0.2, sin(angle) * distance)))
        var bed := MultiMeshInstance3D.new()
        bed.multimesh = many
        bed.material_override = blade
        bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(bed)

func _fish() -> void:
    var body := SphereMesh.new()
    body.radius = 0.09
    body.height = 0.18
    body.radial_segments = 8
    body.rings = 4
    var rng := RandomNumberGenerator.new()
    rng.seed = 88
    var colours := [Color(0.95, 0.75, 0.25), Color(0.75, 0.85, 0.95), accent.lightened(0.3), Color(0.95, 0.45, 0.3)]
    for s in 4:
        var scales := StandardMaterial3D.new()
        scales.albedo_color = colours[s]
        scales.metallic = 0.5
        scales.roughness = 0.3
        scales.emission_enabled = true
        scales.emission = colours[s]
        scales.emission_energy_multiplier = 0.15
        var carrier := Node3D.new()
        carrier.position = Vector3(rng.randf_range(-8.0, 8.0), rng.randf_range(3.0, 9.0), rng.randf_range(-8.0, 8.0))
        carrier.rotation.x = rng.randf_range(-0.12, 0.12)
        add_child(carrier)
        var many := MultiMesh.new()
        many.transform_format = MultiMesh.TRANSFORM_3D
        many.mesh = body
        many.instance_count = 60
        var ring := rng.randf_range(13.0, 24.0)
        for i in 60:
            var angle := rng.randf_range(0.0, 0.9)
            var at := Vector3(cos(angle) * (ring + rng.randf_range(-1.5, 1.5)), rng.randf_range(-1.2, 1.2), sin(angle) * (ring + rng.randf_range(-1.5, 1.5)))
            # nose along the way they are going, long and thin
            var basis := Basis(Vector3.UP, -angle).scaled(Vector3(0.6, 0.8, 2.6) * rng.randf_range(0.7, 1.4))
            many.set_instance_transform(i, Transform3D(basis, at))
        var shoal := MultiMeshInstance3D.new()
        shoal.multimesh = many
        shoal.material_override = scales
        shoal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        carrier.add_child(shoal)
        spin(carrier, Vector3.UP, (0.16 + 0.05 * s) * (1.0 if s % 2 == 0 else -1.0))
        _shoals.append([carrier, carrier.position.y, rng.randf() * TAU])

func _animate(_delta: float) -> void:
    for entry in _shoals:
        (entry[0] as Node3D).position.y = float(entry[1]) + sin(_clock * 0.3 + float(entry[2])) * 1.4

func _dome() -> void:
    var tiles := MaterialKitClass.surface("lab_tiles", 1.6, Color(0.42, 0.52, 0.56), 0.6)
    tiles.next_pass = MaterialKitClass.shader("res://assets/shaders/caustics.gdshader", {"energy": 0.07})
    var steel := MaterialKitClass.metal("brushed_metal", 0.6, Color(0.75, 0.8, 0.84), 0.7)
    deck(9.0, tiles, steel)

    # the glass, and the ribs that hold it
    var profile := PackedVector2Array()
    for s in 13:
        var a := float(s) / 12.0 * PI * 0.5
        profile.append(Vector2(sin(a) * 10.4 + 0.001, cos(a) * 9.0))
    var pane := add(MeshKitClass.lathe(profile, 64), MaterialKitClass.glass(Color(0.6, 0.95, 1.0), 0.07))
    pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    for i in 10:
        var angle := TAU * float(i) / 10.0 + PI / 10.0
        var side := Vector3(-sin(angle), 0.0, cos(angle))
        add(MeshKitClass.beam(MeshKitClass.arc(10.4, 0.0, 0.6, 9.0, angle, 22), side, 0.16, 0.2), steel)
        add(MeshKitClass.beam(MeshKitClass.arc(10.22, 0.02, 0.6, 8.82, angle, 22), side, 0.05, 0.03),
            strip({"energy": 1.5, "wave": 0.25, "speed": 0.08, "phase": float(i) * 0.7}))
    for height in [3.0, 6.2]:
        var hoop := TorusMesh.new()
        var radius := 10.4 * sqrt(1.0 - pow(height / 9.0, 2.0))
        hoop.inner_radius = radius - 0.07
        hoop.outer_radius = radius + 0.07
        hoop.rings = 96
        hoop.ring_segments = 8
        add(hoop, steel, Vector3(0, height, 0))
    lamp(Vector3(0, 6.5, 0), Color(1, 1, 1).lerp(accent, 0.4), 1.6, 14.0)

    # sample tanks: something glowing kept under glass
    var tank := CylinderMesh.new()
    tank.top_radius = 0.42
    tank.bottom_radius = 0.42
    tank.height = 1.7
    for bearing in [70.0, 125.0, 235.0, 290.0]:
        var a := deg_to_rad(float(bearing))
        var at := Vector3(sin(a), 0.0, -cos(a)) * 7.9
        add(tank, MaterialKitClass.glass(accent, 0.22, 0.5), at + Vector3(0, 1.05, 0))
        var cap := CylinderMesh.new()
        cap.top_radius = 0.48
        cap.bottom_radius = 0.48
        cap.height = 0.2
        add(cap, steel, at + Vector3(0, 0.1, 0))
        add(cap, steel, at + Vector3(0, 2.0, 0))
        glow(at + Vector3(0, 1.05, 0), accent, 1.6, 0.6, 0.3)
        lamp(at + Vector3(0, 1.1, 0), accent, 0.5, 4.0)
