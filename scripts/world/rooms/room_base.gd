class_name RoomBase
extends Node3D

# What every rebuilt room is made with: the theme's colours, the lights and
# skies rooms share, a floor to stand on, and the list of things that move.
# A room is a script in this folder that fills in _build().

const MeshKitClass = preload("res://scripts/world/kit/mesh_kit.gd")
const MaterialKitClass = preload("res://scripts/world/kit/material_kit.gd")

var accent := Color("#63ddff")
var secondary := Color("#6f8995")
var shadows := true
var motes := true

var _turning: Array = []        # [node, axis, radians per second]
var _blinking: Array = []       # [node, seconds per cycle, offset]
var _clock := 0.0

func build(theme: Dictionary, config) -> void:
    accent = Color(str(theme.get("accent", "#63ddff")))
    secondary = Color(str(theme.get("secondary", "#6f8995")))
    shadows = bool(config.get_value("graphics.shadows", true))
    motes = bool(config.get_value("graphics.particles", true))
    _build()

func _build() -> void:
    pass

# Anything a room moves by hand each frame.
func _animate(_delta: float) -> void:
    pass

func _process(delta: float) -> void:
    _clock += delta
    for entry in _turning:
        (entry[0] as Node3D).rotate_object_local(entry[1], float(entry[2]) * delta)
    for entry in _blinking:
        (entry[0] as Node3D).visible = fmod(_clock + float(entry[2]), float(entry[1])) < 0.22
    _animate(delta)

# --- small helpers -----------------------------------------------------------

func add(mesh: Mesh, material: Material, at: Vector3 = Vector3.ZERO, parent: Node3D = self) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.material_override = material
    node.position = at
    parent.add_child(node)
    return node

func spin(node: Node3D, axis: Vector3, speed: float) -> void:
    _turning.append([node, axis.normalized(), speed])

func blink(node: Node3D, period: float, offset: float = 0.0) -> void:
    _blinking.append([node, period, offset])

func rgb(colour: Color) -> Vector3:
    return Vector3(colour.r, colour.g, colour.b)

# A strip of light in the theme's colour, with a slow pulse along it.
func strip(extra: Dictionary = {}) -> ShaderMaterial:
    var params := {"tint": rgb(accent)}
    params.merge(extra, true)
    return MaterialKitClass.shader("res://assets/shaders/light_strip.gdshader", params)

func lamp(at: Vector3, colour: Color, energy: float, reach: float, parent: Node3D = self) -> OmniLight3D:
    var light := OmniLight3D.new()
    light.position = at
    light.light_color = colour
    light.light_energy = energy
    light.omni_range = reach
    parent.add_child(light)
    return light

func glow(at: Vector3, colour: Color, size: float, energy: float = 1.0, core: float = 0.5, parent: Node3D = self) -> MeshInstance3D:
    var node := MaterialKitClass.halo(colour, size, energy, core)
    node.position = at
    parent.add_child(node)
    return node

# --- world: air, sky, sun ----------------------------------------------------

# The room's Environment, with the look every room shares. Returned so a room
# can add fog or change the fill light.
func environment(fill: Color, fill_energy: float) -> Environment:
    var env := Environment.new()
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = fill
    env.ambient_light_energy = fill_energy
    env.tonemap_mode = Environment.TONE_MAPPER_ACES
    env.tonemap_white = 6.0
    # Bloom is not always there in a headset; the glows on the lamps carry the
    # look, this only adds to it on a monitor.
    env.glow_enabled = not get_viewport().use_xr
    env.glow_intensity = 0.55
    env.glow_bloom = 0.04
    env.glow_hdr_threshold = 1.0
    var world := WorldEnvironment.new()
    world.environment = env
    add_child(world)
    return env

# The real night sky, turned so the heart of the Milky Way stands in the
# direction `towards`.
func star_sky(env: Environment, towards: Vector3, roll_deg: float = -25.0, energy: float = 1.5) -> void:
    var in_map := Vector3(0.873, -0.485, 0.055).normalized()   # where the galactic centre is in the map
    var turn := Basis(in_map, deg_to_rad(roll_deg)) * Basis(Quaternion(towards.normalized(), in_map))
    var sky := Sky.new()
    sky.sky_material = MaterialKitClass.shader("res://assets/shaders/space_sky.gdshader", {
        "stars": load("res://assets/space/starmap_8k.jpg"),
        "orient": turn,
        "energy": energy,
        "contrast": 1.2,
    })
    sky.radiance_size = Sky.RADIANCE_SIZE_256
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

# A photograph of a real place as the surroundings. The same picture lights
# the room and shows in reflections. `reach` is how far the photo's ground is
# laid flat before it stands up as a backdrop.
func photo_sky(env: Environment, name: String, reach: float, ground_y: float = 0.0, exposure: float = 1.0, wash: Color = Color.WHITE) -> ShaderMaterial:
    var photo: Texture2D = load("res://assets/skies/%s.jpg" % name)
    var panorama := PanoramaSkyMaterial.new()
    panorama.panorama = photo
    var sky := Sky.new()
    sky.sky_material = panorama
    sky.radiance_size = Sky.RADIANCE_SIZE_256
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

    var ball := SphereMesh.new()
    ball.radius = 900.0
    ball.height = 1800.0
    ball.radial_segments = 48
    ball.rings = 24
    var material := MaterialKitClass.shader("res://assets/shaders/photo_dome.gdshader", {
        "photo": photo, "reach": reach, "ground_y": ground_y, "exposure": exposure, "wash": rgb(wash),
    })
    var dome := add(ball, material)
    dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return material

# Light from `towards` (the direction of the sun or moon from here).
func sun(towards: Vector3, colour: Color, energy: float) -> DirectionalLight3D:
    var light := DirectionalLight3D.new()
    light.basis = Basis.looking_at(-towards.normalized(), Vector3.UP)
    light.light_color = colour
    light.light_energy = energy
    light.shadow_enabled = shadows
    light.directional_shadow_max_distance = 45.0
    add_child(light)
    return light

# --- things most rooms have --------------------------------------------------

# The floor everyone stands on: a round platform with the theme's light set
# into it. The control panels and portals assume it is there and level.
func deck(radius: float, surface: Material, edge: Material, rings: bool = true) -> void:
    add(MeshKitClass.annulus(0.0, radius, 128), surface)
    add(MeshKitClass.lathe(PackedVector2Array([
        Vector2(radius, 0.0), Vector2(radius + 0.35, 0.0), Vector2(radius + 0.45, -0.12),
        Vector2(radius + 0.45, -0.5), Vector2(radius - 0.2, -0.9), Vector2(0.0, -1.0),
    ]), 128), edge)
    if rings:
        add(MeshKitClass.annulus(2.94, 3.03, 128), strip({"energy": 1.6, "wave": 0.12}), Vector3(0, 0.006, 0))
        add(MeshKitClass.annulus(radius - 0.5, radius - 0.42, 160), strip({"energy": 1.3, "wave": 0.08, "phase": 1.6}), Vector3(0, 0.006, 0))

# Specks drifting in the air: dust in a beam, snow, plankton.
func drift(centre: Vector3, extents: Vector3, amount: int, colour: Color, size: float = 0.03, velocity: Vector3 = Vector3(0.3, 0.2, -0.4), speed: float = 0.05, energy: float = 0.7) -> GPUParticles3D:
    var process := ParticleProcessMaterial.new()
    process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
    process.emission_box_extents = extents
    process.gravity = Vector3.ZERO
    process.direction = velocity.normalized()
    process.spread = 180.0 if speed < 0.1 else 25.0
    process.initial_velocity_min = speed * 0.3
    process.initial_velocity_max = speed
    process.scale_min = 0.5
    process.scale_max = 1.4

    var speck := MaterialKitClass.halo(colour, size, energy, 0.6)
    var field := GPUParticles3D.new()
    field.amount = amount
    field.lifetime = 16.0
    field.preprocess = 16.0
    field.process_material = process
    field.draw_pass_1 = speck.mesh
    field.material_override = speck.material_override
    field.position = centre
    field.visibility_aabb = AABB(-extents * 1.5, extents * 3.0)
    speck.free()
    add_child(field)
    return field

# A few birds wheeling in the distance. Small, dark, and never still.
func flock(centre: Vector3, radius: float, count: int, speed: float = 0.12) -> void:
    var dark := StandardMaterial3D.new()
    dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    dark.albedo_color = Color(0.03, 0.03, 0.04)
    dark.cull_mode = BaseMaterial3D.CULL_DISABLED
    var wing := PrismMesh.new()
    wing.size = Vector3(1.5, 0.02, 0.45)
    var rng := RandomNumberGenerator.new()
    rng.seed = int(radius) + count
    for i in count:
        var orbit := Node3D.new()
        orbit.position = centre + Vector3(0, rng.randf_range(-6.0, 6.0), 0)
        orbit.rotation = Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, 0.0)
        add_child(orbit)
        var bird := add(wing, dark, Vector3(radius * rng.randf_range(0.6, 1.0), 0, 0), orbit)
        bird.rotation = Vector3(deg_to_rad(90.0), 0.0, deg_to_rad(rng.randf_range(-20.0, 20.0)))
        bird.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        spin(orbit, Vector3.UP, speed * rng.randf_range(0.7, 1.3))

# A round room to be indoors in: floor, wall and ceiling. The wall and
# ceiling face inwards.
func hall(radius: float, height: float, floor_surface: Material, wall: Material, ceiling: Material) -> void:
    add(MeshKitClass.annulus(0.0, radius, 128), floor_surface)
    add(MeshKitClass.lathe(PackedVector2Array([Vector2(radius, 0.0), Vector2(radius, height)]), 96), wall)
    add(MeshKitClass.annulus(0.0, radius, 96), ceiling, Vector3(0, height, 0)).rotation.x = PI

# A lamp that points: a pool of light on a bench, a wall, the floor.
func spot(at: Vector3, towards: Vector3, colour: Color, energy: float, reach: float, angle: float = 40.0, parent: Node3D = self) -> SpotLight3D:
    var light := SpotLight3D.new()
    light.position = at
    light.basis = Basis.looking_at((towards - at).normalized(), Vector3.UP if absf((towards - at).normalized().y) < 0.98 else Vector3.FORWARD)
    light.light_color = colour
    light.light_energy = energy
    light.spot_range = reach
    light.spot_angle = angle
    parent.add_child(light)
    return light

func box(size: Vector3, material: Material, at: Vector3, parent: Node3D = self) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    return add(mesh, material, at, parent)

func rod(radius: float, length: float, material: Material, at: Vector3, parent: Node3D = self) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = length
    mesh.radial_segments = 12
    return add(mesh, material, at, parent)

# Reflections on metal, water and polished floors. `inside` is for rooms
# with no sky.
func probe(size: Vector3 = Vector3(26, 13, 26), at: Vector3 = Vector3(0, 2.4, 0), inside: bool = false) -> void:
    var p := ReflectionProbe.new()
    p.position = at
    p.size = size
    p.box_projection = true
    p.interior = inside
    p.update_mode = ReflectionProbe.UPDATE_ONCE
    p.max_distance = 1200.0
    add_child(p)
