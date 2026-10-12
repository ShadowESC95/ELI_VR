class_name OrbitalCore
extends Node3D

# The Core Room: an open observation deck on a station in low orbit. Earth
# turns below, the real night sky is overhead, the station's outer ring swings
# past outside. The theme sets the colour of every light in the room; the
# metal, the planet and the stars stay what they are.

const MeshKitClass = preload("res://scripts/world/kit/mesh_kit.gd")
const MaterialKitClass = preload("res://scripts/world/kit/material_kit.gd")

const DECK_RADIUS := 9.0
# Towards the sun. Earth and the deck are lit from the same place.
const SUN_DIR := Vector3(-0.85, 0.30, 0.20)

var accent := Color("#63ddff")
var secondary := Color("#6f8995")

var _turning: Array = []        # [node, axis, radians per second]
var _blinking: Array = []       # [node, seconds per cycle, offset]
var _clock := 0.0
var _earth_mat: ShaderMaterial
var _cloud_shift := 0.0

func build(theme: Dictionary, config) -> void:
    accent = Color(str(theme.get("accent", "#63ddff")))
    secondary = Color(str(theme.get("secondary", "#6f8995")))
    _sky_and_light(bool(config.get_value("graphics.shadows", true)))
    _earth_below()
    _deck()
    _canopy()
    _consoles()
    _core_globe()
    _outer_ring()
    if bool(config.get_value("graphics.particles", true)):
        _dust()
    _probe()

func _process(delta: float) -> void:
    for entry in _turning:
        (entry[0] as Node3D).rotate_object_local(entry[1], float(entry[2]) * delta)
    _clock += delta
    for entry in _blinking:
        (entry[0] as Node3D).visible = fmod(_clock + float(entry[2]), float(entry[1])) < 0.22
    if _earth_mat:
        _cloud_shift = fmod(_cloud_shift + delta * 0.0005, 1.0)
        _earth_mat.set_shader_parameter("cloud_shift", _cloud_shift)

func _add(mesh: Mesh, material: Material, at: Vector3 = Vector3.ZERO, parent: Node3D = self) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.material_override = material
    node.position = at
    parent.add_child(node)
    return node

func _strip(extra: Dictionary = {}) -> ShaderMaterial:
    var params := {"tint": Vector3(accent.r, accent.g, accent.b)}
    params.merge(extra, true)
    return MaterialKitClass.shader("res://assets/shaders/light_strip.gdshader", params)

# --- sky, sun, air -----------------------------------------------------------

func _sky_and_light(shadows: bool) -> void:
    var sky := Sky.new()
    sky.sky_material = MaterialKitClass.shader("res://assets/shaders/space_sky.gdshader", {
        "stars": load("res://assets/space/starmap_8k.jpg"),
        "orient": _sky_turn(),
        "energy": 1.5,
        "contrast": 1.2,
    })
    sky.radiance_size = Sky.RADIANCE_SIZE_256

    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    # Starlight alone leaves the shadow side of everything black, so the deck's
    # own lamps are stood in for by a little coloured fill.
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.20, 0.26, 0.34).lerp(accent, 0.25)
    env.ambient_light_energy = 0.55
    env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    env.tonemap_mode = Environment.TONE_MAPPER_ACES
    env.tonemap_white = 6.0
    # Bloom is not always there in a headset; the halos on the lamps carry the
    # look, this only adds to it on a monitor.
    env.glow_enabled = not get_viewport().use_xr
    env.glow_intensity = 0.55
    env.glow_bloom = 0.04
    env.glow_hdr_threshold = 1.0
    var world := WorldEnvironment.new()
    world.environment = env
    add_child(world)

    var sun := DirectionalLight3D.new()
    sun.basis = Basis.looking_at(-SUN_DIR.normalized(), Vector3.UP)
    sun.light_color = Color(1.0, 0.96, 0.90)
    sun.light_energy = 2.3
    sun.shadow_enabled = shadows
    sun.directional_shadow_max_distance = 45.0
    add_child(sun)

    var glare := MaterialKitClass.halo(Color(1.0, 0.95, 0.86), 520.0, 2.4, 1.0)
    glare.position = SUN_DIR.normalized() * 900.0
    add_child(glare)

# Turn the sky so the bright heart of the Milky Way stands up and to the left
# of straight ahead, clear of the sun and of Earth.
func _sky_turn() -> Basis:
    # where the galactic centre sits in the star map, as a direction
    var in_map := Vector3(0.873, -0.485, 0.055).normalized()
    var wanted := Vector3(-0.47, 0.574, -0.671).normalized()
    var turn := Basis(Quaternion(wanted, in_map))
    return Basis(in_map, deg_to_rad(-25.0)) * turn

# --- Earth -------------------------------------------------------------------

func _earth_below() -> void:
    # Six hundred metres stands in for four hundred kilometres. At that range
    # neither eye nor head movement can tell the difference.
    var centre := Vector3(0.0, -0.616, -0.788) * 600.0
    var radius := 473.0

    var ball := SphereMesh.new()
    ball.radius = radius
    ball.height = radius * 2.0
    ball.radial_segments = 128
    ball.rings = 64
    _earth_mat = MaterialKitClass.shader("res://assets/shaders/planet_earth.gdshader", {
        "day_tex": load("res://assets/space/earth_day.jpg"),
        "night_tex": load("res://assets/space/earth_night.jpg"),
        "cloud_tex": load("res://assets/space/earth_clouds.jpg"),
        "sun_dir": SUN_DIR.normalized(),
    })
    var earth := _add(ball, _earth_mat, centre)
    earth.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(-30.0), deg_to_rad(23.4))
    earth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _turning.append([earth, Vector3.UP, 0.004])

    var shell := SphereMesh.new()
    shell.radius = radius * 1.03
    shell.height = radius * 2.06
    shell.radial_segments = 96
    shell.rings = 48
    var air := _add(shell, MaterialKitClass.shader("res://assets/shaders/planet_air.gdshader", {
        "sun_dir": SUN_DIR.normalized(),
    }), centre)
    air.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# --- the deck ----------------------------------------------------------------

func _deck() -> void:
    var plating := MaterialKitClass.metal("deck_plating", 2.2, Color(0.50, 0.54, 0.60), 0.55)
    var band := MaterialKitClass.metal("hull_panels", 2.4, Color(0.36, 0.39, 0.44), 0.7)
    var hull := MaterialKitClass.metal("hull_panels", 1.8, Color(0.42, 0.45, 0.50))
    var steel := MaterialKitClass.metal("brushed_metal", 0.6, Color(0.75, 0.78, 0.82))

    _add(MeshKitClass.annulus(0.0, 6.45, 128), plating)
    _add(MeshKitClass.annulus(6.45, DECK_RADIUS, 128), band)
    _add(MeshKitClass.lathe(PackedVector2Array([
        Vector2(DECK_RADIUS, 0.0), Vector2(9.55, 0.0), Vector2(9.78, -0.18),
        Vector2(9.78, -0.80), Vector2(9.10, -1.55), Vector2(5.5, -2.5), Vector2(0.0, -2.9),
    ]), 128), hull)

    # light set into the floor: two rings and the spokes between them
    _add(MeshKitClass.annulus(2.94, 3.03, 128), _strip({"energy": 1.7, "wave": 0.12}), Vector3(0, 0.006, 0))
    _add(MeshKitClass.annulus(6.40, 6.50, 160), _strip({"energy": 1.4, "wave": 0.08, "phase": 1.6}), Vector3(0, 0.006, 0))
    var spoke := BoxMesh.new()
    spoke.size = Vector3(0.03, 0.008, 3.30)
    for i in 8:
        var angle := TAU * float(i) / 8.0
        var line := _add(spoke, MaterialKitClass.light(accent, 1.3), Vector3(cos(angle), 0.0, sin(angle)) * 4.72 + Vector3(0, 0.004, 0))
        line.rotation.y = PI * 0.5 - angle

    # a rail round the edge
    var post := CylinderMesh.new()
    post.top_radius = 0.022
    post.bottom_radius = 0.022
    post.height = 1.05
    post.radial_segments = 8
    var posts := MultiMesh.new()
    posts.transform_format = MultiMesh.TRANSFORM_3D
    posts.mesh = post
    posts.instance_count = 36
    for i in 36:
        var angle := TAU * float(i) / 36.0
        posts.set_instance_transform(i, Transform3D(Basis(), Vector3(cos(angle) * 9.3, 0.525, sin(angle) * 9.3)))
    var post_field := MultiMeshInstance3D.new()
    post_field.multimesh = posts
    post_field.material_override = steel
    add_child(post_field)
    for height in [1.05, 0.55]:
        var rail := TorusMesh.new()
        rail.inner_radius = 9.3 - 0.018
        rail.outer_radius = 9.3 + 0.018
        rail.rings = 128
        rail.ring_segments = 8
        _add(rail, steel, Vector3(0, height, 0))

# --- ribs and hub overhead ---------------------------------------------------

func _canopy() -> void:
    var hull := MaterialKitClass.metal("hull_panels", 1.3, Color(0.50, 0.53, 0.58))
    for i in 8:
        var angle := PI / 8.0 + TAU * float(i) / 8.0
        var side := Vector3(-sin(angle), 0.0, cos(angle))
        _add(MeshKitClass.beam(MeshKitClass.arc(9.45, -0.1, 2.75, 7.45, angle, 28), side, 0.36, 0.58), hull)
        _add(
            MeshKitClass.beam(MeshKitClass.arc(9.12, 0.02, 2.75, 7.12, angle, 28), side, 0.07, 0.04),
            _strip({"energy": 1.8, "wave": 0.22, "speed": 0.10, "phase": float(i) * 0.8})
        )

    _add(MeshKitClass.lathe(PackedVector2Array([
        Vector2(2.1, 7.95), Vector2(3.0, 7.95), Vector2(3.18, 7.6),
        Vector2(3.0, 7.22), Vector2(2.1, 7.22), Vector2(2.1, 7.95),
    ]), 96), hull)
    _add(MeshKitClass.annulus(2.14, 2.26, 96), _strip({"energy": 2.0, "wave": 0.3}), Vector3(0, 7.21, 0)).rotation.x = PI

    # a ring inside the hub that keeps turning
    var carrier := Node3D.new()
    carrier.position = Vector3(0, 7.45, 0)
    add_child(carrier)
    var ring := TorusMesh.new()
    ring.inner_radius = 1.45
    ring.outer_radius = 1.62
    ring.rings = 96
    ring.ring_segments = 12
    _add(ring, MaterialKitClass.metal("brushed_metal", 0.5, Color(0.7, 0.73, 0.78)), Vector3.ZERO, carrier)
    var lamp := BoxMesh.new()
    lamp.size = Vector3(0.34, 0.05, 0.12)
    for i in 6:
        var angle := TAU * float(i) / 6.0
        var pad := _add(lamp, MaterialKitClass.light(accent, 3.0), Vector3(cos(angle), -0.07, sin(angle)) * 1.535, carrier)
        pad.rotation.y = -angle + PI * 0.5
    _turning.append([carrier, Vector3.UP, 0.22])

    var down := SpotLight3D.new()
    down.position = Vector3(0, 7.1, 0)
    down.rotation.x = -PI * 0.5
    down.light_color = Color(1, 1, 1).lerp(accent, 0.45)
    down.light_energy = 5.0
    down.spot_range = 14.0
    down.spot_angle = 58.0
    down.spot_attenuation = 1.2
    add_child(down)

# --- instrument stations round the edge --------------------------------------

func _consoles() -> void:
    var hull := MaterialKitClass.metal("brushed_metal", 0.5, Color(0.22, 0.24, 0.28), 0.8)
    var body := BoxMesh.new()
    body.size = Vector3(1.24, 0.86, 0.34)
    var top := BoxMesh.new()
    top.size = Vector3(1.56, 0.05, 0.86)
    var screen := QuadMesh.new()
    screen.size = Vector2(1.44, 0.74)
    var back := BoxMesh.new()
    back.size = Vector3(1.52, 0.82, 0.04)
    var skirt := BoxMesh.new()
    skirt.size = Vector3(1.28, 0.03, 0.38)

    # Degrees round from straight ahead. Nothing directly in front: that is
    # where the control panels and the desktop screen hang.
    var bearings := [62.0, 118.0, 180.0, -118.0, -62.0]
    for i in bearings.size():
        var bearing := deg_to_rad(float(bearings[i]))
        var station := Node3D.new()
        station.position = Vector3(sin(bearing), 0.0, -cos(bearing)) * 7.7
        station.rotation.y = -bearing
        add_child(station)
        _add(body, hull, Vector3(0, 0.43, 0), station)
        _add(skirt, MaterialKitClass.light(accent, 1.4), Vector3(0, 0.02, 0), station)
        _add(top, hull, Vector3(0, 0.9, 0.1), station).rotation.x = deg_to_rad(-12.0)
        _add(back, hull, Vector3(0, 1.42, -0.06), station).rotation.x = deg_to_rad(-14.0)
        var face := _add(screen, MaterialKitClass.shader("res://assets/shaders/data_screen.gdshader", {
            "tint": Vector3(accent.r, accent.g, accent.b), "seed": float(i) * 3.7,
        }), Vector3(0, 1.425, -0.035), station)
        face.rotation.x = deg_to_rad(-14.0)
        var glow := OmniLight3D.new()
        glow.position = Vector3(0, 1.35, 0.3)
        glow.light_color = accent
        glow.light_energy = 0.55
        glow.omni_range = 3.2
        station.add_child(glow)

# --- the projected globe -----------------------------------------------------

func _core_globe() -> void:
    var centre := Vector3(0, 5.35, -3.4)
    var tint := Vector3(accent.r, accent.g, accent.b)

    var ball := SphereMesh.new()
    ball.radius = 0.95
    ball.height = 1.9
    ball.radial_segments = 64
    ball.rings = 32
    var globe := _add(ball, MaterialKitClass.shader("res://assets/shaders/hologram.gdshader", {
        "land_tex": load("res://assets/space/earth_day.jpg"), "tint": tint,
    }), centre)
    globe.rotation.z = deg_to_rad(18.0)
    globe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _turning.append([globe, Vector3.UP, 0.14])

    for i in 2:
        var hoop := TorusMesh.new()
        hoop.inner_radius = 1.22 + 0.2 * i
        hoop.outer_radius = hoop.inner_radius + 0.012
        hoop.rings = 96
        hoop.ring_segments = 6
        var node := _add(hoop, MaterialKitClass.light(accent, 1.6), centre)
        node.rotation = Vector3(0.5 + 0.9 * i, 0.0, 0.35 - 0.8 * i)
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        _turning.append([node, Vector3(0.3, 1.0, 0.1).normalized(), 0.35 - 0.6 * i])

    var halo := MaterialKitClass.halo(accent, 4.6, 0.5, 0.0)
    halo.position = centre
    add_child(halo)
    var glow := OmniLight3D.new()
    glow.position = centre
    glow.light_color = accent
    glow.light_energy = 1.1
    glow.omni_range = 7.0
    add_child(glow)

# --- the rest of the station, outside ----------------------------------------

func _outer_ring() -> void:
    var hull := MaterialKitClass.metal("hull_panels", 3.0, Color(0.34, 0.36, 0.41))
    var carrier := Node3D.new()
    carrier.position = Vector3(0, -0.4, 0)
    carrier.rotation = Vector3(deg_to_rad(9.0), 0.0, deg_to_rad(-5.0))
    add_child(carrier)

    var ring := TorusMesh.new()
    ring.inner_radius = 33.0
    ring.outer_radius = 35.0
    ring.rings = 160
    ring.ring_segments = 16
    _add(ring, hull, Vector3.ZERO, carrier)

    var module := BoxMesh.new()
    module.size = Vector3(2.6, 1.9, 3.6)
    var modules := MultiMesh.new()
    modules.transform_format = MultiMesh.TRANSFORM_3D
    modules.mesh = module
    modules.instance_count = 24
    for i in 24:
        var angle := TAU * float(i) / 24.0
        modules.set_instance_transform(i, Transform3D(
            Basis(Vector3.UP, -angle), Vector3(cos(angle), 0.0, sin(angle)) * 34.0 + Vector3(0, 0.25 if i % 2 == 0 else -0.25, 0)))
    var module_field := MultiMeshInstance3D.new()
    module_field.multimesh = modules
    module_field.material_override = hull
    carrier.add_child(module_field)

    # lit windows on the side of each module that faces the deck
    var pane := BoxMesh.new()
    pane.size = Vector3(0.06, 0.26, 0.5)
    var panes := MultiMesh.new()
    panes.transform_format = MultiMesh.TRANSFORM_3D
    panes.mesh = pane
    panes.instance_count = 72
    for i in 72:
        var angle := TAU * float(i / 3) / 24.0
        var along := (float(i % 3) - 1.0) * 0.95
        var out := Vector3(cos(angle), 0.0, sin(angle))
        var tangent := Vector3(-sin(angle), 0.0, cos(angle))
        panes.set_instance_transform(i, Transform3D(
            Basis(Vector3.UP, -angle), out * 32.68 + tangent * along + Vector3(0, 0.45, 0)))
    var pane_field := MultiMeshInstance3D.new()
    pane_field.multimesh = panes
    pane_field.material_override = MaterialKitClass.light(Color(1.0, 0.86, 0.62), 1.7)
    carrier.add_child(pane_field)

    var arm := BoxMesh.new()
    arm.size = Vector3(23.4, 0.45, 0.45)
    for i in 4:
        var angle := PI * 0.25 + TAU * float(i) / 4.0
        var node := _add(arm, hull, Vector3(cos(angle), 0.0, sin(angle)) * 21.5, carrier)
        node.rotation.y = -angle

    # running lights, some in the theme's colour and some red
    for i in 8:
        var angle := TAU * float(i) / 8.0 + 0.2
        var red := i % 4 == 0
        var lamp := MaterialKitClass.halo(Color(1.0, 0.25, 0.2) if red else accent, 1.4, 1.6, 0.8)
        lamp.position = Vector3(cos(angle), 1.15, sin(angle)) * 34.0
        carrier.add_child(lamp)
        if red:
            _blinking.append([lamp, 1.6, float(i) * 0.4])
    _turning.append([carrier, Vector3.UP, 0.035])

# --- dust in the light -------------------------------------------------------

func _dust() -> void:
    var process := ParticleProcessMaterial.new()
    process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    process.emission_box_extents = Vector3(8.0, 3.2, 8.0)
    process.gravity = Vector3.ZERO
    process.direction = Vector3(0.3, 0.2, -0.4)
    process.spread = 180.0
    process.initial_velocity_min = 0.01
    process.initial_velocity_max = 0.05
    process.scale_min = 0.5
    process.scale_max = 1.4

    var mote := MaterialKitClass.halo(Color(1, 1, 1).lerp(accent, 0.35), 0.03, 0.7, 0.6)
    var motes := GPUParticles3D.new()
    motes.amount = 240
    motes.lifetime = 16.0
    motes.preprocess = 16.0
    motes.process_material = process
    motes.draw_pass_1 = mote.mesh
    motes.material_override = mote.material_override
    motes.position = Vector3(0, 3.4, 0)
    motes.visibility_aabb = AABB(Vector3(-10, -5, -10), Vector3(20, 10, 20))
    mote.free()
    add_child(motes)

# --- reflections on the metal ------------------------------------------------

func _probe() -> void:
    var probe := ReflectionProbe.new()
    probe.position = Vector3(0, 2.4, 0)
    probe.size = Vector3(26, 13, 26)
    probe.box_projection = true
    probe.update_mode = ReflectionProbe.UPDATE_ONCE
    probe.max_distance = 1200.0
    add_child(probe)
