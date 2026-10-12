class_name RoomFactory
extends RefCounted

const Manipulable3DClass = preload("res://scripts/world/manipulable_3d.gd")
const CosmicFieldClass = preload("res://scripts/world/cosmic_field.gd")
const ProceduralGeometryClass = preload("res://scripts/world/procedural_geometry.gd")
const CinematicAssetsClass = preload("res://scripts/world/cinematic_assets.gd")
# Rooms rebuilt as places of their own. Each is a script in rooms/; anything
# not listed here still comes from the older builders further down.
const REBUILT := {
    "core_station": preload("res://scripts/world/rooms/orbital_core.gd"),
    "deep_space": preload("res://scripts/world/rooms/deep_space.gd"),
    "anomaly_void": preload("res://scripts/world/rooms/anomaly_void.gd"),
    "arctic_aurora": preload("res://scripts/world/rooms/arctic_aurora.gd"),
    "digital_matrix": preload("res://scripts/world/rooms/digital_matrix.gd"),
    "desert_observatory": preload("res://scripts/world/rooms/desert_observatory.gd"),
    "mountain_observatory": preload("res://scripts/world/rooms/mountain_observatory.gd"),
    "forest_sanctuary": preload("res://scripts/world/rooms/forest_sanctuary.gd"),
    "ocean_platform": preload("res://scripts/world/rooms/ocean_platform.gd"),
    "underwater_lab": preload("res://scripts/world/rooms/underwater_lab.gd"),
    "memory_cathedral": preload("res://scripts/world/rooms/memory_cathedral.gd"),
    "workshop_bay": preload("res://scripts/world/rooms/workshop_bay.gd"),
    "debug_bunker": preload("res://scripts/world/rooms/debug_bunker.gd"),
    "fabrication_lab": preload("res://scripts/world/rooms/fabrication_lab.gd"),
    "evidence_studio": preload("res://scripts/world/rooms/evidence_studio.gd"),
}

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var theme: Dictionary = {}
var detail: float = 1.0
var shadows: bool = true
var fog: bool = true
var particles: bool = true
var current_environment_id: String = ""
var palette_world_strength: float = 0.02
var geometry = ProceduralGeometryClass.new()
var cinematic = CinematicAssetsClass.new()

func build(
    parent: Node3D,
    environment_id: String,
    p_theme: Dictionary,
    config
) -> void:
    current_environment_id = environment_id
    for child in parent.get_children():
        child.queue_free()

    rng.seed = abs(environment_id.hash())
    theme = p_theme
    detail = float(config.get_value("graphics.world_detail_scale", 1.0))
    shadows = bool(config.get_value("graphics.shadows", true))
    fog = bool(config.get_value("graphics.fog", true))
    particles = bool(config.get_value("graphics.particles", true))
    palette_world_strength = float(config.get_value("world.palette_world_strength", 0.02))

    if REBUILT.has(environment_id):
        var room = REBUILT[environment_id].new()
        room.name = environment_id
        parent.add_child(room)
        room.build(theme, config)
        return

    match environment_id:
        "core_station":
            _build_core(parent)
        "memory_cathedral":
            _build_memory(parent)
        "workshop_bay":
            _build_workshop(parent)
        "mountain_observatory":
            _build_mountain(parent)
        "debug_bunker":
            _build_debug(parent)
        "fabrication_lab":
            _build_fabrication(parent)
        "digital_matrix":
            _build_digital(parent)
        "anomaly_void":
            _build_anomaly(parent)
        "evidence_studio":
            _build_evidence(parent)
        "forest_sanctuary":
            _build_forest(parent)
        "ocean_platform":
            _build_ocean(parent)
        "deep_space":
            _build_space(parent)
        "arctic_aurora":
            _build_arctic(parent)
        "desert_observatory":
            _build_desert(parent)
        "underwater_lab":
            _build_underwater(parent)
        _:
            _build_core(parent)

func _theme_color(key: String, fallback: Color) -> Color:
    return Color(str(theme.get(key, fallback.to_html())))

func _accent() -> Color:
    return _theme_color("accent", Color("#6ee7ff"))

func _secondary() -> Color:
    return _theme_color("secondary", Color("#6f8995"))

func _surface() -> Color:
    return _theme_color("surface", Color("#07121a"))

func _tint(base: Color, amount: float = 0.14) -> Color:
    # Colour palettes are UI/accent choices, not environment recolouring.
    # Keep world art physically coherent and only allow a very small tint.
    return base.lerp(_surface(), clampf(amount * palette_world_strength, 0.0, 0.04))

func _environment(
    parent: Node3D,
    bg: Color,
    ambient: Color,
    energy: float = 0.7,
    fog_color: Color = Color(0.05, 0.07, 0.1),
    fog_density: float = 0.008
) -> void:
    var we: WorldEnvironment = WorldEnvironment.new()
    var env: Environment = Environment.new()

    env.background_mode = Environment.BG_COLOR
    env.background_color = bg
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = ambient.lerp(_accent(), palette_world_strength)
    env.ambient_light_energy = energy
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

    var rendering_method: String = str(
        RenderingServer.get_current_rendering_method()
    )
    if fog and rendering_method == "forward_plus":
        env.volumetric_fog_enabled = true
        env.volumetric_fog_density = fog_density
        env.volumetric_fog_albedo = fog_color.lerp(_accent(), palette_world_strength)
        env.volumetric_fog_length = 110.0

    we.environment = env
    parent.add_child(we)

func _sky(
    parent: Node3D,
    top: Color,
    horizon: Color,
    bottom: Color,
    stars: float,
    nebula: float,
    clouds: float,
    aurora: float,
    grid: float,
    seed_value: float,
    exposure: float = 1.0,
    radius: float = 240.0
) -> MeshInstance3D:
    var dome: MeshInstance3D = MeshInstance3D.new()
    var mesh: SphereMesh = SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 64
    mesh.rings = 32
    dome.mesh = mesh

    var mat: ShaderMaterial = ShaderMaterial.new()
    mat.shader = load("res://assets/shaders/universal_world_sky.gdshader")

    mat.set_shader_parameter("top_color", Vector3(top.r, top.g, top.b))
    mat.set_shader_parameter("horizon_color", Vector3(horizon.r, horizon.g, horizon.b))
    mat.set_shader_parameter("bottom_color", Vector3(bottom.r, bottom.g, bottom.b))

    var accent: Color = _accent()
    mat.set_shader_parameter("accent_color", Vector3(
        accent.r,
        accent.g,
        accent.b
    ))
    mat.set_shader_parameter("stars", stars)
    mat.set_shader_parameter("nebula", nebula)
    mat.set_shader_parameter("cloud_amount", clouds)
    mat.set_shader_parameter("aurora", aurora)
    mat.set_shader_parameter("grid", grid)
    mat.set_shader_parameter("seed", seed_value)
    mat.set_shader_parameter("exposure", exposure)

    dome.material_override = mat
    parent.add_child(dome)
    return dome

func _sun(
    parent: Node3D,
    color: Color,
    energy: float = 1.1,
    rot: Vector3 = Vector3(-0.65, -0.8, 0.0)
) -> void:
    var light: DirectionalLight3D = DirectionalLight3D.new()
    light.light_color = color
    light.light_energy = energy
    light.shadow_enabled = shadows
    light.rotation = rot
    parent.add_child(light)

func _mat(
    color: Color,
    metallic: float = 0.0,
    rough: float = 0.65,
    emission: Color = Color(0, 0, 0, 1),
    emission_energy: float = 1.0
) -> StandardMaterial3D:
    var m: StandardMaterial3D = StandardMaterial3D.new()
    m.albedo_color = _tint(color, 0.10)
    m.metallic = metallic
    m.roughness = rough

    if emission.r > 0.0 or emission.g > 0.0 or emission.b > 0.0:
        m.emission_enabled = true
        m.emission = emission
        m.emission_energy_multiplier = emission_energy * float(
            theme.get("emission_gain", 1.0)
        )
    return m

func _box(
    parent: Node3D,
    size: Vector3,
    pos: Vector3,
    color: Color,
    metallic: float = 0.0,
    rough: float = 0.65,
    emission: Color = Color(0, 0, 0, 1),
    rot: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
    var n: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = size
    n.mesh = mesh
    n.position = pos
    n.rotation = rot
    n.material_override = _mat(color, metallic, rough, emission)
    parent.add_child(n)
    return n

func _cylinder(
    parent: Node3D,
    radius: float,
    height: float,
    pos: Vector3,
    color: Color,
    top_radius: float = -1.0,
    rot: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
    var n: MeshInstance3D = MeshInstance3D.new()
    var mesh: CylinderMesh = CylinderMesh.new()
    mesh.bottom_radius = radius
    mesh.top_radius = radius if top_radius < 0.0 else top_radius
    mesh.height = height
    mesh.radial_segments = 16
    n.mesh = mesh
    n.position = pos
    n.rotation = rot
    n.material_override = _mat(color, 0.08, 0.72)
    parent.add_child(n)
    return n

func _sphere(
    parent: Node3D,
    radius: float,
    pos: Vector3,
    color: Color,
    emission: Color = Color(0, 0, 0, 1)
) -> MeshInstance3D:
    var n: MeshInstance3D = MeshInstance3D.new()
    var mesh: SphereMesh = SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 20
    mesh.rings = 10
    n.mesh = mesh
    n.position = pos
    n.material_override = _mat(color, 0.0, 0.65, emission, 1.4)
    parent.add_child(n)
    return n

func _floor(
    parent: Node3D,
    color: Color,
    size: Vector2 = Vector2(60, 60),
    y: float = 0.0
) -> MeshInstance3D:
    var n: MeshInstance3D = MeshInstance3D.new()
    var mesh: PlaneMesh = PlaneMesh.new()
    mesh.size = size
    n.mesh = mesh
    n.position.y = y
    n.material_override = _mat(color, 0.06, 0.84)
    parent.add_child(n)
    return n

func _ring(
    parent: Node3D,
    radius: float,
    y: float,
    count: int,
    color: Color,
    emission: Color
) -> void:
    for i in range(count):
        var a: float = TAU * float(i) / float(count)
        _box(
            parent,
            Vector3(0.52, 0.055, 0.12),
            Vector3(cos(a) * radius, y, sin(a) * radius),
            color,
            0.48,
            0.26,
            emission,
            Vector3(0.0, -a, 0.0)
        )

func _terrain(
    parent: Node3D,
    size: float,
    resolution: int,
    amplitude: float,
    low: Color,
    high: Color,
    basin_radius: float,
    seed_offset: int
) -> MeshInstance3D:
    var noise: FastNoiseLite = FastNoiseLite.new()
    noise.seed = int(rng.seed) + seed_offset
    noise.frequency = 0.018
    noise.fractal_octaves = 5
    noise.fractal_gain = 0.52
    noise.fractal_lacunarity = 2.0

    var st: SurfaceTool = SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)

    var step: float = size / float(resolution - 1)
    for z in range(resolution - 1):
        for x in range(resolution - 1):
            var x0: float = -size * 0.5 + float(x) * step
            var x1: float = x0 + step
            var z0: float = -size * 0.5 + float(z) * step
            var z1: float = z0 + step

            var p00: Vector3 = Vector3(
                x0, _height(noise, x0, z0, amplitude, basin_radius), z0
            )
            var p10: Vector3 = Vector3(
                x1, _height(noise, x1, z0, amplitude, basin_radius), z0
            )
            var p01: Vector3 = Vector3(
                x0, _height(noise, x0, z1, amplitude, basin_radius), z1
            )
            var p11: Vector3 = Vector3(
                x1, _height(noise, x1, z1, amplitude, basin_radius), z1
            )

            _terrain_vertex(st, p00, low, high, amplitude)
            _terrain_vertex(st, p10, low, high, amplitude)
            _terrain_vertex(st, p11, low, high, amplitude)
            _terrain_vertex(st, p00, low, high, amplitude)
            _terrain_vertex(st, p11, low, high, amplitude)
            _terrain_vertex(st, p01, low, high, amplitude)

    st.generate_normals()

    var terrain: MeshInstance3D = MeshInstance3D.new()
    terrain.mesh = st.commit()
    var kind: String = "rock"
    match current_environment_id:
        "forest_sanctuary": kind = "seabed"
        "desert_observatory": kind = "sand"
        "arctic_aurora": kind = "ice"
        "underwater_lab": kind = "seabed"
        "mountain_observatory": kind = "rock"
    var mat: StandardMaterial3D = cinematic.material(kind, Color.WHITE, 0.0, 0.90)
    mat.vertex_color_use_as_albedo = true
    terrain.material_override = mat
    parent.add_child(terrain)
    return terrain

func _height(
    noise: FastNoiseLite,
    x: float,
    z: float,
    amplitude: float,
    basin_radius: float
) -> float:
    var radial: float = Vector2(x, z).length()
    var basin: float = smoothstep(basin_radius, basin_radius * 2.5, radial)
    var large: float = noise.get_noise_2d(x, z)
    var detail_n: float = noise.get_noise_2d(
        x * 2.8 + 31.0,
        z * 2.8 - 17.0
    )
    return (
        large * 0.78 + detail_n * 0.22
    ) * amplitude * basin

func _terrain_vertex(
    st: SurfaceTool,
    p: Vector3,
    low: Color,
    high: Color,
    amplitude: float
) -> void:
    var t: float = clampf(
        (p.y / maxf(amplitude, 0.001) + 1.0) * 0.5,
        0.0,
        1.0
    )
    st.set_color(_tint(low.lerp(high, t), 0.08))
    st.set_uv(Vector2(p.x * 0.055, p.z * 0.055))
    st.add_vertex(p)

func _forest_instances(parent: Node3D, count: int, radius: float) -> void:
    var variants: int = 6
    var per_variant: int = int(ceil(float(count) / float(variants)))
    for variant in range(variants):
        var mesh: ArrayMesh = cinematic.tree_mesh(9001 + variant * 101)
        var mm: MultiMesh = MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = mesh
        mm.instance_count = per_variant
        for i in range(per_variant):
            var a: float = rng.randf_range(0.0, TAU)
            var r: float = rng.randf_range(10.0, radius)
            var scale_value: float = rng.randf_range(0.72, 1.35)
            var basis: Basis = Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(
                Vector3(scale_value, scale_value * rng.randf_range(0.92, 1.18), scale_value)
            )
            mm.set_instance_transform(i, Transform3D(basis, Vector3(cos(a)*r, 0.0, sin(a)*r)))
        var inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
        inst.multimesh = mm
        parent.add_child(inst)

func _planet(
    parent: Node3D,
    p_name: String,
    radius: float,
    pos: Vector3,
    base: Color,
    secondary: Color,
    atmosphere: Color,
    seed_value: float,
    ringed: bool = false
) -> Node3D:
    var root = Manipulable3DClass.new()
    root.name = p_name
    root.setup(radius, p_name)
    root.position = pos
    parent.add_child(root)

    var body: MeshInstance3D = MeshInstance3D.new()
    var mesh: SphereMesh = SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 48
    mesh.rings = 24
    body.mesh = mesh

    var planet_mat: ShaderMaterial = ShaderMaterial.new()
    planet_mat.shader = load("res://assets/shaders/frontier_planet.gdshader")
    planet_mat.set_shader_parameter(
        "base_color",
        Vector3(base.r, base.g, base.b)
    )
    planet_mat.set_shader_parameter(
        "secondary_color",
        Vector3(secondary.r, secondary.g, secondary.b)
    )
    planet_mat.set_shader_parameter("seed", seed_value)
    planet_mat.set_shader_parameter("self_light", 0.13)
    body.material_override = planet_mat
    root.add_child(body)

    var shell: MeshInstance3D = MeshInstance3D.new()
    var shell_mesh: SphereMesh = SphereMesh.new()
    shell_mesh.radius = radius * 1.04
    shell_mesh.height = radius * 2.08
    shell_mesh.radial_segments = 40
    shell_mesh.rings = 20
    shell.mesh = shell_mesh

    var atm_mat: ShaderMaterial = ShaderMaterial.new()
    atm_mat.shader = load("res://assets/shaders/frontier_atmosphere.gdshader")
    atm_mat.set_shader_parameter(
        "atmosphere_color",
        Vector3(atmosphere.r, atmosphere.g, atmosphere.b)
    )
    shell.material_override = atm_mat
    root.add_child(shell)

    var highlight: MeshInstance3D = MeshInstance3D.new()
    var hmesh: SphereMesh = SphereMesh.new()
    hmesh.radius = radius * 1.07
    hmesh.height = radius * 2.14
    highlight.mesh = hmesh
    var hmat: StandardMaterial3D = StandardMaterial3D.new()
    hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    hmat.albedo_color = Color(0.25, 0.95, 1.0, 0.08)
    hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    hmat.cull_mode = BaseMaterial3D.CULL_FRONT
    highlight.material_override = hmat
    highlight.visible = false
    root.add_child(highlight)
    root.highlight_shell = highlight

    if ringed:
        var ring_color: Color = secondary.lerp(Color.WHITE, 0.45)
        for i in range(64):
            var a: float = TAU * float(i) / 64.0
            var rr: float = radius * 1.62
            var seg: MeshInstance3D = _box(
                root,
                Vector3(radius * 0.22, 0.025, radius * 0.055),
                Vector3(cos(a) * rr, 0.0, sin(a) * rr),
                ring_color,
                0.0,
                0.76,
                Color(0, 0, 0, 1),
                Vector3(0.0, -a, 0.0)
            )
            seg.rotation.x = deg_to_rad(11.0)

    return root

func _asteroids(
    parent: Node3D,
    count: int,
    inner_radius: float,
    outer_radius: float
) -> void:
    var mesh: SphereMesh = SphereMesh.new()
    mesh.radius = 0.35
    mesh.height = 0.7
    mesh.radial_segments = 6
    mesh.rings = 4
    mesh.material = _mat(Color("#55515b"), 0.0, 0.95)

    var mm: MultiMesh = MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = mesh
    mm.instance_count = count

    for i in range(count):
        var theta: float = rng.randf_range(0.0, TAU)
        var phi: float = acos(rng.randf_range(-1.0, 1.0))
        var r: float = rng.randf_range(inner_radius, outer_radius)
        var p: Vector3 = Vector3(
            sin(phi) * cos(theta),
            cos(phi),
            sin(phi) * sin(theta)
        ) * r
        var s: float = rng.randf_range(0.14, 1.2)
        var basis: Basis = Basis.from_euler(
            Vector3(
                rng.randf_range(0.0, TAU),
                rng.randf_range(0.0, TAU),
                rng.randf_range(0.0, TAU)
            )
        ).scaled(
            Vector3(
                s,
                s * rng.randf_range(0.55, 1.3),
                s
            )
        )
        mm.set_instance_transform(i, Transform3D(basis, p))

    var inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
    inst.multimesh = mm
    parent.add_child(inst)


func _distant_star(parent: Node3D, pos: Vector3, radius: float, color: Color, energy: float) -> void:
    var n: MeshInstance3D = MeshInstance3D.new()
    var mesh: SphereMesh = SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 32
    mesh.rings = 16
    n.mesh = mesh
    n.position = pos
    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = color
    mat.emission_enabled = true
    mat.emission = color
    mat.emission_energy_multiplier = energy
    n.material_override = mat
    parent.add_child(n)

func _asteroid_belt(
    parent: Node3D,
    center: Vector3,
    inner_radius: float,
    outer_radius: float,
    count: int,
    tilt: Vector3
) -> void:
    var belt_basis: Basis = Basis.from_euler(tilt)
    var meshes: Array[ArrayMesh] = []
    for variant in range(6):
        var mesh: ArrayMesh = geometry.rock_mesh(1.0, 31.0 + float(variant) * 9.17, 16, 10)
        var tint: Color = Color("#817d79").lerp(Color("#b0a79e"), float(variant) / 8.0)
        mesh.surface_set_material(0, cinematic.material("rock", tint, 0.0, 0.88))
        meshes.append(mesh)

    var per_variant: int = int(ceil(float(count) / 6.0))
    for variant in range(6):
        var mm: MultiMesh = MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = meshes[variant]
        mm.instance_count = per_variant
        for i in range(per_variant):
            var a: float = rng.randf_range(0.0, TAU)
            var rr: float = rng.randf_range(inner_radius, outer_radius)
            var local: Vector3 = Vector3(cos(a) * rr, rng.randfn(0.0, 1.3), sin(a) * rr)
            var p: Vector3 = center + belt_basis * local
            var s: float = rng.randf_range(0.28, 1.45)
            var basis: Basis = Basis.from_euler(Vector3(
                rng.randf_range(0.0,TAU), rng.randf_range(0.0,TAU), rng.randf_range(0.0,TAU)
            )).scaled(Vector3(
                s * rng.randf_range(0.65,1.45),
                s * rng.randf_range(0.55,1.20),
                s * rng.randf_range(0.65,1.45)
            ))
            mm.set_instance_transform(i, Transform3D(basis, p))
        var inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
        inst.multimesh = mm
        parent.add_child(inst)

func _torus(
    parent: Node3D,
    major_radius: float,
    tube_radius: float,
    pos: Vector3,
    color: Color,
    emission: Color = Color(0, 0, 0, 1),
    rot: Vector3 = Vector3.ZERO,
    arc_radians: float = TAU
) -> MeshInstance3D:
    var n: MeshInstance3D = MeshInstance3D.new()
    n.mesh = geometry.torus_mesh(
        major_radius,
        tube_radius,
        int(56.0 * clampf(detail, 0.7, 1.4)),
        9,
        arc_radians
    )
    n.position = pos
    n.rotation = rot
    n.material_override = _mat(color, 0.52, 0.25, emission, 1.15)
    parent.add_child(n)
    return n

func _rock_field(
    parent: Node3D,
    count: int,
    radius_min: float,
    radius_max: float,
    area_radius: float,
    y_min: float,
    y_max: float,
    color: Color
) -> void:
    var variants: Array = []
    for variant in range(4):
        var mesh = geometry.rock_mesh(1.0, float(variant) * 7.31 + 1.7, 13, 8)
        var mat: StandardMaterial3D = cinematic.material(
            "rock",
            color.lerp(Color("#969aa0"), float(variant) * 0.055),
            0.0,
            0.93
        )
        mesh.surface_set_material(0, mat)
        variants.append(mesh)

    var per_variant: int = int(ceil(float(count) / 4.0))
    for variant in range(4):
        var mm: MultiMesh = MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = variants[variant]
        mm.instance_count = per_variant

        for i in range(per_variant):
            var a: float = rng.randf_range(0.0, TAU)
            var rr: float = area_radius * sqrt(rng.randf())
            var s: float = rng.randf_range(radius_min, radius_max)
            var p: Vector3 = Vector3(
                cos(a) * rr,
                rng.randf_range(y_min, y_max),
                sin(a) * rr
            )
            var basis: Basis = Basis.from_euler(Vector3(
                rng.randf_range(-0.35, 0.35),
                rng.randf_range(0.0, TAU),
                rng.randf_range(-0.35, 0.35)
            )).scaled(Vector3(
                s * rng.randf_range(0.75, 1.35),
                s * rng.randf_range(0.70, 1.45),
                s * rng.randf_range(0.75, 1.35)
            ))
            mm.set_instance_transform(i, Transform3D(basis, p))

        var inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
        inst.multimesh = mm
        parent.add_child(inst)

func _architectural_ribs(
    parent: Node3D,
    count: int,
    spacing: float,
    radius: float,
    color: Color,
    accent: Color
) -> void:
    for i in range(count):
        var z: float = (float(i) - float(count - 1) * 0.5) * spacing
        _torus(
            parent,
            radius,
            0.12,
            Vector3(0.0, 2.8, z),
            color,
            accent * 0.08,
            Vector3(PI * 0.5, 0.0, 0.0),
            PI
        )

func _mesh_asset(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material, scale_value: Vector3 = Vector3.ONE, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var n: MeshInstance3D = MeshInstance3D.new()
    n.mesh = mesh
    n.position = pos
    n.scale = scale_value
    n.rotation = rot
    n.material_override = material
    parent.add_child(n)
    return n

func _glacier_field(parent: Node3D, count: int, radius: float) -> void:
    for variant in range(5):
        var mesh: ArrayMesh = cinematic.glacier_mesh(7100 + variant * 79)
        var mm: MultiMesh = MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = mesh
        var per: int = int(ceil(float(count) / 5.0))
        mm.instance_count = per
        for i in range(per):
            var a: float = rng.randf_range(0.0, TAU)
            var r: float = rng.randf_range(14.0, radius)
            var sc: float = rng.randf_range(0.45, 1.65)
            mm.set_instance_transform(i, Transform3D(
                Basis(Vector3.UP,rng.randf_range(0.0,TAU)).scaled(Vector3(sc,sc,sc)),
                Vector3(cos(a)*r,rng.randf_range(-3.0,2.0),sin(a)*r)
            ))
        var inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
        inst.multimesh = mm
        parent.add_child(inst)

func _coral_garden(parent: Node3D, count: int, radius: float) -> void:
    for variant in range(5):
        var mesh: ArrayMesh = cinematic.coral_mesh(8100 + variant * 83)
        var mm: MultiMesh = MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = mesh
        var per: int = int(ceil(float(count) / 5.0))
        mm.instance_count = per
        for i in range(per):
            var a: float = rng.randf_range(0.0,TAU)
            var r: float = radius*sqrt(rng.randf())
            var sc: float = rng.randf_range(0.45,1.35)
            mm.set_instance_transform(i,Transform3D(
                Basis(Vector3.UP,rng.randf_range(0.0,TAU)).scaled(Vector3(sc,sc,sc)),
                Vector3(cos(a)*r,-0.5,sin(a)*r)
            ))
        var inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
        inst.multimesh = mm
        parent.add_child(inst)

func _mobius(parent: Node3D, radius: float, width: float, pos: Vector3, color: Color, rot: Vector3) -> void:
    var mesh: ArrayMesh = cinematic.mobius_mesh(radius,width,128,10)
    var mat: StandardMaterial3D = cinematic.material("dark_metal",color,0.25,0.32,_accent(),0.22)
    _mesh_asset(parent,mesh,pos,mat,Vector3.ONE,rot)

func _lorenz_ribbon(parent: Node3D, origin: Vector3, scale_value: float, color: Color, steps: int = 1800) -> void:
    var pts: PackedVector3Array = PackedVector3Array()
    var x: float = 0.1
    var y: float = 0.0
    var z: float = 0.0
    var dt: float = 0.006
    for i in range(steps):
        var dx: float = 10.0*(y-x)
        var dy: float = x*(28.0-z)-y
        var dz: float = x*y-(8.0/3.0)*z
        x += dx*dt; y += dy*dt; z += dz*dt
        if i > 80 and i % 2 == 0:
            pts.append(origin + Vector3(x,z-24.0,y)*scale_value)
    var mesh: ArrayMesh = cinematic.ribbon_mesh(pts,0.035*scale_value)
    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = color
    mat.emission_enabled = true
    mat.emission = color
    mat.emission_energy_multiplier = 1.6
    _mesh_asset(parent,mesh,Vector3.ZERO,mat)

func _observatory(parent: Node3D) -> void:
    var metal: StandardMaterial3D = cinematic.material("metal",Color("#b8c8d0"),0.62,0.25)
    var dome: MeshInstance3D = MeshInstance3D.new()
    var sphere: SphereMesh = SphereMesh.new()
    sphere.radius = 4.4
    sphere.height = 8.8
    sphere.radial_segments = 48
    sphere.rings = 24
    dome.mesh = sphere
    dome.scale = Vector3(1.0,0.55,1.0)
    dome.position = Vector3(0.0,2.2,0.0)
    dome.material_override = metal
    parent.add_child(dome)
    var tube: CylinderMesh = CylinderMesh.new()
    tube.top_radius = 0.55; tube.bottom_radius = 0.68; tube.height = 7.5; tube.radial_segments = 24
    var telescope: MeshInstance3D = MeshInstance3D.new()
    telescope.mesh = tube
    telescope.material_override = cinematic.material("dark_metal",Color.WHITE,0.75,0.22)
    telescope.position = Vector3(0.0,4.4,-1.0)
    telescope.rotation = Vector3(deg_to_rad(64.0),0.0,0.0)
    parent.add_child(telescope)

func _gallery_arches(parent: Node3D, count: int, spacing: float, radius: float, kind: String, tint: Color) -> void:
    var mesh: ArrayMesh = cinematic.arch_mesh(radius,0.42,0.65,42)
    mesh.surface_set_material(0,cinematic.material(kind,tint,0.0,0.78))
    for i in range(count):
        var n: MeshInstance3D = MeshInstance3D.new()
        n.mesh = mesh
        n.position = Vector3(0.0,0.0,(float(i)-float(count-1)*0.5)*spacing)
        parent.add_child(n)

func _cosmic_field(parent: Node3D) -> void:
    var field = CosmicFieldClass.new()
    field.name = "CosmicField"
    field.build(int(rng.seed) + 1701, detail, _accent())
    parent.add_child(field)

# ---------------------------------------------------------------------------
# Every environment below has:
# - a full 4π background sphere;
# - substantially larger world geometry;
# - enough vertical/depth variation for universal free flight;
# - theme-aware materials and illumination.
# ---------------------------------------------------------------------------

func _build_core(parent: Node3D) -> void:
    _environment(parent,Color("#02050a"),Color("#35556c"),0.70)
    _sky(parent,Color("#031228"),Color("#173b55"),Color("#010207"),0.10,0.20,0.0,0.0,0.0,2.0)
    _sun(parent,Color("#b9e7ff"),0.90)
    var metal: StandardMaterial3D = cinematic.material("dark_metal",Color.WHITE,0.72,0.22,_accent(),0.08)
    for spec in [[9.0,0.38,Vector3(0,1,0),Vector3(0.15,0,0)],[16.0,0.28,Vector3(0,5,-4),Vector3(0.55,0.18,0.12)],[27.0,0.20,Vector3(0,-7,-10),Vector3(-0.26,0.30,0.15)]]:
        _mesh_asset(parent,geometry.torus_mesh(float(spec[0]),float(spec[1]),84,12),spec[2],metal,Vector3.ONE,spec[3])
    for i in range(12):
        var a: float = TAU*float(i)/12.0
        var arch: ArrayMesh = cinematic.arch_mesh(5.4,0.35,1.1,42)
        arch.surface_set_material(0,metal)
        var n: MeshInstance3D = MeshInstance3D.new()
        n.mesh=arch
        n.position=Vector3(cos(a)*11.0,-1.0,sin(a)*11.0)
        n.rotation=Vector3(0,-a+PI*0.5,0)
        parent.add_child(n)
    _cosmic_field(parent)

func _build_memory(parent: Node3D) -> void:
    _environment(parent,Color("#080611"),Color("#675582"),0.74)
    _sky(parent,Color("#180d31"),Color("#50386c"),Color("#05040b"),0.10,0.42,0.08,0.0,0.0,7.0)
    _sun(parent,Color("#d6c5ff"),0.50)
    _gallery_arches(parent,19,5.4,8.7,"memory_stone",Color.WHITE)
    var floor_mat: StandardMaterial3D = cinematic.material("stone",Color("#5a4a68"),0.0,0.76)
    var aisle: MeshInstance3D = _box(parent,Vector3(6.0,0.16,105.0),Vector3(0,-0.1,-8),Color.WHITE)
    aisle.material_override=floor_mat
    for i in range(46):
        var z: float = rng.randf_range(-58.0,46.0)
        var x: float = rng.randf_range(-5.0,5.0)
        var light: MeshInstance3D = _sphere(parent,rng.randf_range(0.045,0.13),Vector3(x,rng.randf_range(1.0,7.5),z),_accent(),_accent())
        light.name="MemoryLight"

func _build_workshop(parent: Node3D) -> void:
    _environment(parent,Color("#0b0a08"),Color("#6d5943"),0.80)
    _sky(parent,Color("#1b1712"),Color("#7a5736"),Color("#070604"),0.03,0.04,0.12,0.0,0.0,11.0)
    _sun(parent,Color("#ffe0a3"),0.92)
    var metal: StandardMaterial3D = cinematic.material("metal",Color("#98856f"),0.58,0.28,_accent(),0.06)
    for level in range(-2,4):
        _mesh_asset(parent,geometry.torus_mesh(12.0+absf(float(level))*2.2,0.24,72,10),Vector3(0,float(level)*4.6,-6),metal,Vector3.ONE,Vector3(0.15*level,0.08*level,0))
    for i in range(9):
        var a: float = TAU*float(i)/9.0
        var arm: CylinderMesh = CylinderMesh.new()
        arm.top_radius=0.16
        arm.bottom_radius=0.22
        arm.height=8.0
        arm.radial_segments=12
        var n: MeshInstance3D = MeshInstance3D.new()
        n.mesh=arm
        n.material_override=metal
        n.position=Vector3(cos(a)*8.0,4.0,sin(a)*8.0-6.0)
        n.rotation=Vector3(0,0,deg_to_rad(35.0)*sin(a))
        parent.add_child(n)
        _sphere(parent,0.40,n.position+Vector3(0,4.0,0),_accent()*0.3,_accent())

func _build_mountain(parent: Node3D) -> void:
    _environment(parent,Color("#0a1728"),Color("#93adbd"),0.80)
    _sky(parent,Color("#174b78"),Color("#e1a36e"),Color("#08111a"),0.02,0.0,0.62,0.0,0.0,17.0)
    _sun(parent,Color("#ffe0b2"),1.35,Vector3(-0.45,-0.75,0.0))
    _terrain(parent,320.0,int(60.0*clampf(detail,0.65,1.55)),52.0,Color("#202b32"),Color("#e7eff1"),13.0,10)
    _rock_field(parent,int(150.0*detail),0.35,3.4,145.0,-8.0,22.0,Color("#596269"))
    _observatory(parent)

func _build_debug(parent: Node3D) -> void:
    _environment(parent,Color("#040405"),Color("#54282a"),0.62)
    _sky(parent,Color("#10070a"),Color("#50181c"),Color("#020203"),0.08,0.06,0.0,0.0,0.34,23.0)
    var metal: StandardMaterial3D = cinematic.material("dark_metal",Color("#6a363b"),0.65,0.28,_accent(),0.08)
    _gallery_arches(parent,18,5.0,7.8,"dark_metal",Color("#4a262a"))
    for side in [-1,1]:
        for i in range(14):
            var rack: MeshInstance3D = _box(parent,Vector3(2.3,3.2,0.65),Vector3(float(side)*6.1,1.6,-42+float(i)*6.0),Color.WHITE)
            rack.material_override=metal
            for led in range(7):
                _sphere(parent,0.035,rack.position+Vector3(-0.6+float(led)*0.2,0.5,0.37),_accent(),_accent())
    _lorenz_ribbon(parent,Vector3(0,4,-5),0.26,_accent(),1200)

func _build_fabrication(parent: Node3D) -> void:
    _environment(parent,Color("#07100d"),Color("#7b9683"),0.90)
    _sky(parent,Color("#13251d"),Color("#9db8a5"),Color("#040907"),0.02,0.0,0.16,0.0,0.0,29.0)
    _sun(parent,Color("#ecfff1"),1.0)
    var white: StandardMaterial3D = cinematic.material("metal",Color("#c7d3cc"),0.35,0.24,_accent(),0.05)
    for r in [8.0,14.0,21.0]:
        _mesh_asset(parent,geometry.torus_mesh(float(r),0.20,72,10),Vector3(0,2.0,-5),white)
    for i in range(10):
        var a: float=TAU*float(i)/10.0
        var root: Vector3=Vector3(cos(a)*11.0,1.0,sin(a)*11.0-5.0)
        var elbow: Vector3=root+Vector3(cos(a)*2.0,3.0,sin(a)*2.0)
        var tip: Vector3=elbow+Vector3(-sin(a)*2.0,2.0,cos(a)*2.0)
        var pts: PackedVector3Array=PackedVector3Array([root,elbow,tip])
        var arm_mesh: ArrayMesh=cinematic.ribbon_mesh(pts,0.22)
        _mesh_asset(parent,arm_mesh,Vector3.ZERO,white)
        _sphere(parent,0.28,tip,_accent()*0.25,_accent())

func _build_digital(parent: Node3D) -> void:
    _environment(parent,Color("#000200"),Color("#073c17"),0.28)
    _sky(parent,Color("#001006"),Color("#083a18"),Color("#000100"),0.12,0.04,0.0,0.0,1.0,31.0)
    _lorenz_ribbon(parent,Vector3(-8,4,-18),0.48,_accent(),1900)
    _lorenz_ribbon(parent,Vector3(12,-8,-28),0.34,Color("#9effda"),1600)
    _mobius(parent,9.0,1.2,Vector3(0,5,-42),_accent()*0.50,Vector3(0.4,0.2,0.1))
    _mobius(parent,15.0,0.7,Vector3(5,-9,-58),Color("#65ffc0"),Vector3(1.0,-0.4,0.6))

func _build_anomaly(parent: Node3D) -> void:
    _environment(parent,Color("#09020d"),Color("#602666"),0.52)
    _sky(parent,Color("#160521"),Color("#5f1b68"),Color("#010103"),0.18,0.72,0.0,0.25,0.0,37.0)
    _mobius(parent,8.0,1.6,Vector3(-7,7,-25),Color("#7c2b95"),Vector3(0.3,0.5,0.1))
    _mobius(parent,13.0,0.8,Vector3(10,-4,-40),Color("#3d1a66"),Vector3(1.1,-0.2,0.8))
    _lorenz_ribbon(parent,Vector3(0,3,-14),0.55,_accent(),2100)
    _lorenz_ribbon(parent,Vector3(-14,-12,-42),0.36,Color("#ff69df"),1500)

func _build_evidence(parent: Node3D) -> void:
    _environment(parent,Color("#0e0c08"),Color("#756849"),0.86)
    _sky(parent,Color("#211c12"),Color("#887548"),Color("#050403"),0.02,0.0,0.12,0.0,0.0,41.0)
    _sun(parent,Color("#fff0c5"),0.75)
    _gallery_arches(parent,14,6.5,9.0,"stone",Color("#7b6a50"))
    var panel_mat: StandardMaterial3D = cinematic.material("metal",Color("#4c4438"),0.18,0.50,_accent(),0.04)
    for i in range(26):
        var side: float = -1.0 if i%2==0 else 1.0
        var z: float = -38.0 + float(i/2)*6.2
        var frame: MeshInstance3D=_box(parent,Vector3(3.4,2.2,0.14),Vector3(side*7.2,2.6,z),Color.WHITE)
        frame.material_override=panel_mat
        var evidence: MeshInstance3D=_box(parent,Vector3(2.9,1.7,0.04),frame.position+Vector3(-side*0.08,0,0.09),Color("#d8caa8"))
        evidence.material_override=cinematic.material("stone",Color("#d8caa8"),0.0,0.88)

func _build_forest(parent: Node3D) -> void:
    _environment(parent,Color("#07120d"),Color("#789a7f"),0.70)
    _sky(parent,Color("#173b35"),Color("#9caf88"),Color("#04100b"),0.01,0.0,0.54,0.0,0.0,47.0)
    _sun(parent,Color("#dcffd7"),0.82)
    _terrain(parent,260.0,int(56.0*clampf(detail,0.65,1.55)),12.0,Color("#102319"),Color("#60774f"),12.0,21)
    _forest_instances(parent,int(155.0*clampf(detail,0.55,1.45)),112.0)
    _rock_field(parent,int(95.0*detail),0.25,2.4,105.0,-2.0,5.0,Color("#465049"))

func _build_ocean(parent: Node3D) -> void:
    _environment(parent,Color("#0a3550"),Color("#a0bfca"),0.90)
    _sky(parent,Color("#1a78a7"),Color("#f0bf85"),Color("#07324a"),0.01,0.0,0.55,0.0,0.0,53.0)
    _sun(parent,Color("#fff1c6"),1.38,Vector3(-0.35,-0.6,0.0))
    var ocean: MeshInstance3D=_floor(parent,Color("#075b78"),Vector2(1400,1400),-1.2)
    var water: ShaderMaterial=ShaderMaterial.new()
    water.shader=load("res://assets/shaders/ocean.gdshader")
    ocean.material_override=water
    _rock_field(parent,int(160.0*detail),0.45,6.0,210.0,-2.0,18.0,Color("#40585b"))
    var metal: StandardMaterial3D=cinematic.material("metal",Color("#758b94"),0.55,0.24)
    _mesh_asset(parent,geometry.torus_mesh(10.5,0.30,72,10),Vector3(0,0.5,0),metal)
    _mesh_asset(parent,geometry.torus_mesh(16.0,0.18,72,10),Vector3(0,4,-2),metal,Vector3.ONE,Vector3(0.3,0,0.1))

func _build_space(parent: Node3D) -> void:
    _environment(parent,Color("#000002"),Color("#111a31"),0.24)
    # The background dome carries only extremely low-frequency nebular colour.
    # All visible stars/galaxies are spatial objects from CosmicField, removing
    # the old UV-cell star layout.
    _sky(parent,Color("#01020a"),Color("#070612"),Color("#000001"),0.0,0.05,0.0,0.0,0.0,59.0,0.72,430.0)
    _cosmic_field(parent)
    _sun(parent,Color("#fff0d5"),1.82,Vector3(-0.32,-1.0,-0.25))

    _planet(parent,"Aurelia",7.2,Vector3(-25,6,-39),Color("#1b4d7a"),Color("#7cc7eb"),Color("#55afff"),1.7,true)
    _planet(parent,"Cinder",3.8,Vector3(20,-5,-29),Color("#67251b"),Color("#e47a43"),Color("#ff815b"),4.2,false)
    _planet(parent,"Violet Moon",2.0,Vector3(-11,14,-23),Color("#34275b"),Color("#a186df"),Color("#c4acff"),9.0,false)
    _planet(parent,"Verdant",4.6,Vector3(36,14,-58),Color("#163f31"),Color("#63ae78"),Color("#8ce8c1"),12.0,false)
    _planet(parent,"Helios",10.0,Vector3(-62,-18,-92),Color("#7a3e16"),Color("#f2ba55"),Color("#ffd27a"),15.0,false)
    _planet(parent,"Ice Giant",6.0,Vector3(54,-20,-78),Color("#205069"),Color("#78d0de"),Color("#b8f4ff"),21.0,true)
    _planet(parent,"Distant Azure",14.0,Vector3(160,72,-245),Color("#153c6b"),Color("#75aee0"),Color("#5ba7ff"),33.0,true)
    _planet(parent,"Distant Ember",9.0,Vector3(-185,-65,-270),Color("#612219"),Color("#cc663b"),Color("#ff7e54"),44.0,false)
    _planet(parent,"Pale Wanderer",5.5,Vector3(92,-112,-220),Color("#665d4d"),Color("#d8d0ba"),Color("#ddd8c9"),51.0,false)

    _distant_star(parent,Vector3(255,-92,-365),13.0,Color("#ffdcb4"),3.2)
    _distant_star(parent,Vector3(-315,156,-390),8.0,Color("#a7c9ff"),3.6)
    _distant_star(parent,Vector3(105,285,-410),6.0,Color("#fff1d0"),3.0)

    # Purposeful asteroid belts orbit distant systems. No random black rocks
    # are sprayed around the player any more.
    _asteroid_belt(parent,Vector3(-62,-18,-92),23.0,41.0,int(115.0*detail),Vector3(0.18,0.0,0.25))
    _asteroid_belt(parent,Vector3(160,72,-245),20.0,34.0,int(80.0*detail),Vector3(-0.35,0.20,0.10))

func _build_arctic(parent: Node3D) -> void:
    _environment(parent,Color("#061321"),Color("#759db4"),0.62)
    _sky(parent,Color("#071c38"),Color("#356a79"),Color("#020712"),0.20,0.04,0.10,1.0,0.0,67.0)
    _sun(parent,Color("#c6e6ff"),0.58)
    _terrain(parent,260.0,int(54.0*clampf(detail,0.65,1.55)),22.0,Color("#7eacba"),Color("#f4ffff"),12.0,33)
    _glacier_field(parent,int(85.0*detail),115.0)

func _build_desert(parent: Node3D) -> void:
    _environment(parent,Color("#65321b"),Color("#d2a16d"),0.88)
    _sky(parent,Color("#9e4e28"),Color("#f2c17d"),Color("#351b13"),0.01,0.0,0.36,0.0,0.0,71.0)
    _sun(parent,Color("#fff0bd"),1.45)
    _terrain(parent,300.0,int(58.0*clampf(detail,0.65,1.55)),17.0,Color("#814522"),Color("#e0a35a"),13.0,44)
    var stone: StandardMaterial3D=cinematic.material("rock",Color("#8a5737"),0.0,0.94)
    for i in range(11):
        var arch: ArrayMesh=cinematic.arch_mesh(rng.randf_range(4.0,8.0),rng.randf_range(0.8,1.8),rng.randf_range(2.0,4.5),40)
        arch.surface_set_material(0,stone)
        var n: MeshInstance3D=MeshInstance3D.new()
        n.mesh=arch
        var a: float=rng.randf_range(0.0,TAU)
        var r: float=rng.randf_range(28.0,110.0)
        n.position=Vector3(cos(a)*r,rng.randf_range(-1.0,3.0),sin(a)*r)
        n.rotation=Vector3(0,rng.randf_range(0.0,TAU),0)
        parent.add_child(n)

func _build_underwater(parent: Node3D) -> void:
    _environment(parent,Color("#001720"),Color("#28798c"),0.50)
    _sky(parent,Color("#036074"),Color("#0c8890"),Color("#001118"),0.0,0.05,0.22,0.0,0.0,79.0)
    _terrain(parent,230.0,int(52.0*clampf(detail,0.65,1.55)),13.0,Color("#123b3d"),Color("#4a806c"),11.0,55)
    _coral_garden(parent,int(110.0*detail),95.0)
    _rock_field(parent,int(80.0*detail),0.25,2.4,100.0,-5.0,4.0,Color("#315b58"))
    for i in range(int(100.0*detail)):
        _sphere(parent,rng.randf_range(0.012,0.045),Vector3(rng.randf_range(-90,90),rng.randf_range(-15,45),rng.randf_range(-100,70)),_accent()*0.45,_accent())

