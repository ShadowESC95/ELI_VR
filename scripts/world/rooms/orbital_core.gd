class_name OrbitalCore
extends RoomBase

# The Core Room: an open observation deck on a station in low orbit. Earth
# turns below, the real night sky is overhead, the station's outer ring swings
# past outside. The theme sets the colour of every light in the room; the
# metal, the planet and the stars stay what they are.

const DECK_RADIUS := 9.0
# Towards the sun. Earth and the deck are lit from the same place.
const SUN_DIR := Vector3(-0.85, 0.30, 0.20)

var _earth_mat: ShaderMaterial
var _cloud_shift := 0.0

func _build() -> void:
    _sky_and_light()
    _earth_below()
    _deck()
    _canopy()
    _consoles()
    _core_globe()
    _outer_ring()
    if motes:
        drift(Vector3(0, 3.4, 0), Vector3(8.0, 3.2, 8.0), 240, Color(1, 1, 1).lerp(accent, 0.35))
    probe()

func _animate(delta: float) -> void:
    if _earth_mat:
        _cloud_shift = fmod(_cloud_shift + delta * 0.0005, 1.0)
        _earth_mat.set_shader_parameter("cloud_shift", _cloud_shift)

# --- sky, sun, air -----------------------------------------------------------

func _sky_and_light() -> void:
    # Starlight alone leaves the shadow side of everything black, so the deck's
    # own lamps are stood in for by a little coloured fill.
    var env := environment(Color(0.20, 0.26, 0.34).lerp(accent, 0.25), 0.55)
    # the Milky Way stands up and to the left, clear of the sun and of Earth
    star_sky(env, Vector3(-0.47, 0.574, -0.671))
    sun(SUN_DIR, Color(1.0, 0.96, 0.90), 2.3)
    glow(SUN_DIR.normalized() * 900.0, Color(1.0, 0.95, 0.86), 520.0, 2.4, 1.0)

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
    var earth := add(ball, _earth_mat, centre)
    earth.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(-30.0), deg_to_rad(23.4))
    earth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    spin(earth, Vector3.UP, 0.004)

    var shell := SphereMesh.new()
    shell.radius = radius * 1.03
    shell.height = radius * 2.06
    shell.radial_segments = 96
    shell.rings = 48
    var air := add(shell, MaterialKitClass.shader("res://assets/shaders/planet_air.gdshader", {
        "sun_dir": SUN_DIR.normalized(),
    }), centre)
    air.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# --- the deck ----------------------------------------------------------------

func _deck() -> void:
    var plating := MaterialKitClass.metal("deck_plating", 2.2, Color(0.50, 0.54, 0.60), 0.55)
    var band := MaterialKitClass.metal("hull_panels", 2.4, Color(0.36, 0.39, 0.44), 0.7)
    var hull := MaterialKitClass.metal("hull_panels", 1.8, Color(0.42, 0.45, 0.50))
    var steel := MaterialKitClass.metal("brushed_metal", 0.6, Color(0.75, 0.78, 0.82))

    add(MeshKitClass.annulus(0.0, 6.45, 128), plating)
    add(MeshKitClass.annulus(6.45, DECK_RADIUS, 128), band)
    add(MeshKitClass.lathe(PackedVector2Array([
        Vector2(DECK_RADIUS, 0.0), Vector2(9.55, 0.0), Vector2(9.78, -0.18),
        Vector2(9.78, -0.80), Vector2(9.10, -1.55), Vector2(5.5, -2.5), Vector2(0.0, -2.9),
    ]), 128), hull)

    # light set into the floor: two rings and the spokes between them
    add(MeshKitClass.annulus(2.94, 3.03, 128), strip({"energy": 1.7, "wave": 0.12}), Vector3(0, 0.006, 0))
    add(MeshKitClass.annulus(6.40, 6.50, 160), strip({"energy": 1.4, "wave": 0.08, "phase": 1.6}), Vector3(0, 0.006, 0))
    var spoke := BoxMesh.new()
    spoke.size = Vector3(0.03, 0.008, 3.30)
    for i in 8:
        var angle := TAU * float(i) / 8.0
        var line := add(spoke, MaterialKitClass.light(accent, 1.3), Vector3(cos(angle), 0.0, sin(angle)) * 4.72 + Vector3(0, 0.004, 0))
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
        add(rail, steel, Vector3(0, height, 0))

# --- ribs and hub overhead ---------------------------------------------------

func _canopy() -> void:
    var hull := MaterialKitClass.metal("hull_panels", 1.3, Color(0.50, 0.53, 0.58))
    for i in 8:
        var angle := PI / 8.0 + TAU * float(i) / 8.0
        var side := Vector3(-sin(angle), 0.0, cos(angle))
        add(MeshKitClass.beam(MeshKitClass.arc(9.45, -0.1, 2.75, 7.45, angle, 28), side, 0.36, 0.58), hull)
        add(
            MeshKitClass.beam(MeshKitClass.arc(9.12, 0.02, 2.75, 7.12, angle, 28), side, 0.07, 0.04),
            strip({"energy": 1.8, "wave": 0.22, "speed": 0.10, "phase": float(i) * 0.8})
        )

    add(MeshKitClass.lathe(PackedVector2Array([
        Vector2(2.1, 7.95), Vector2(3.0, 7.95), Vector2(3.18, 7.6),
        Vector2(3.0, 7.22), Vector2(2.1, 7.22), Vector2(2.1, 7.95),
    ]), 96), hull)
    add(MeshKitClass.annulus(2.14, 2.26, 96), strip({"energy": 2.0, "wave": 0.3}), Vector3(0, 7.21, 0)).rotation.x = PI

    # a ring inside the hub that keeps turning
    var carrier := Node3D.new()
    carrier.position = Vector3(0, 7.45, 0)
    add_child(carrier)
    var ring := TorusMesh.new()
    ring.inner_radius = 1.45
    ring.outer_radius = 1.62
    ring.rings = 96
    ring.ring_segments = 12
    add(ring, MaterialKitClass.metal("brushed_metal", 0.5, Color(0.7, 0.73, 0.78)), Vector3.ZERO, carrier)
    var lamp := BoxMesh.new()
    lamp.size = Vector3(0.34, 0.05, 0.12)
    for i in 6:
        var angle := TAU * float(i) / 6.0
        var pad := add(lamp, MaterialKitClass.light(accent, 3.0), Vector3(cos(angle), -0.07, sin(angle)) * 1.535, carrier)
        pad.rotation.y = -angle + PI * 0.5
    spin(carrier, Vector3.UP, 0.22)

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
        add(body, hull, Vector3(0, 0.43, 0), station)
        add(skirt, MaterialKitClass.light(accent, 1.4), Vector3(0, 0.02, 0), station)
        add(top, hull, Vector3(0, 0.9, 0.1), station).rotation.x = deg_to_rad(-12.0)
        add(back, hull, Vector3(0, 1.42, -0.06), station).rotation.x = deg_to_rad(-14.0)
        var face := add(screen, MaterialKitClass.shader("res://assets/shaders/data_screen.gdshader", {
            "tint": rgb(accent), "seed": float(i) * 3.7,
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
    var tint := rgb(accent)

    var ball := SphereMesh.new()
    ball.radius = 0.95
    ball.height = 1.9
    ball.radial_segments = 64
    ball.rings = 32
    var globe := add(ball, MaterialKitClass.shader("res://assets/shaders/hologram.gdshader", {
        "land_tex": load("res://assets/space/earth_day.jpg"), "tint": tint,
    }), centre)
    globe.rotation.z = deg_to_rad(18.0)
    globe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    spin(globe, Vector3.UP, 0.14)

    for i in 2:
        var hoop := TorusMesh.new()
        hoop.inner_radius = 1.22 + 0.2 * i
        hoop.outer_radius = hoop.inner_radius + 0.012
        hoop.rings = 96
        hoop.ring_segments = 6
        var node := add(hoop, MaterialKitClass.light(accent, 1.6), centre)
        node.rotation = Vector3(0.5 + 0.9 * i, 0.0, 0.35 - 0.8 * i)
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        spin(node, Vector3(0.3, 1.0, 0.1).normalized(), 0.35 - 0.6 * i)

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
    add(ring, hull, Vector3.ZERO, carrier)

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
        var node := add(arm, hull, Vector3(cos(angle), 0.0, sin(angle)) * 21.5, carrier)
        node.rotation.y = -angle

    # running lights, some in the theme's colour and some red
    for i in 8:
        var angle := TAU * float(i) / 8.0 + 0.2
        var red := i % 4 == 0
        var lamp := MaterialKitClass.halo(Color(1.0, 0.25, 0.2) if red else accent, 1.4, 1.6, 0.8)
        lamp.position = Vector3(cos(angle), 1.15, sin(angle)) * 34.0
        carrier.add_child(lamp)
        if red:
            blink(lamp, 1.6, float(i) * 0.4)
    spin(carrier, Vector3.UP, 0.035)
