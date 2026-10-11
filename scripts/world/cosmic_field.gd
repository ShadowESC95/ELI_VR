class_name CosmicField
extends Node3D

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var accent: Color = Color("#79bfff")
var detail: float = 1.0

func build(seed_value: int, p_detail: float, p_accent: Color) -> void:
    rng.seed = seed_value
    detail = clampf(p_detail, 0.45, 1.65)
    accent = p_accent

    _stochastic_star_volume("NearStars", int(1500.0 * detail), 55.0, 145.0, 0.025, 0.105)
    _stochastic_star_volume("DeepStars", int(4300.0 * detail), 130.0, 390.0, 0.035, 0.16)
    _galaxy_billboards()
    _nebula_volumes()
    _globular_cluster(Vector3(-108.0, -82.0, -205.0), 17.0, int(880.0 * detail), Color("#ffd9a8"))
    _globular_cluster(Vector3(170.0, 132.0, -318.0), 9.0, int(420.0 * detail), Color("#c8dcff"))

func _star_material() -> StandardMaterial3D:
    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.vertex_color_use_as_albedo = true
    mat.albedo_texture = load("res://assets/cinematic/textures/star_soft.png")
    mat.emission_enabled = true
    mat.emission = Color.WHITE
    mat.emission_energy_multiplier = 2.4
    return mat

func _stochastic_star_volume(p_name: String, count: int, min_r: float, max_r: float, min_s: float, max_s: float) -> void:
    var quad: QuadMesh = QuadMesh.new()
    quad.size = Vector2.ONE
    quad.material = _star_material()

    var mm: MultiMesh = MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.use_colors = true
    mm.mesh = quad
    mm.instance_count = count

    var galactic_basis: Basis = Basis(Vector3(0.73, 0.21, 0.65).normalized(), 0.58)
    var void_axes: Array[Vector3] = [
        Vector3(0.32, -0.44, -0.84).normalized(),
        Vector3(-0.62, 0.26, -0.74).normalized(),
        Vector3(0.05, 0.91, -0.41).normalized(),
    ]

    for i in range(count):
        var d: Vector3
        if rng.randf() < 0.40:
            var longitude: float = rng.randf_range(0.0, TAU)
            var latitude: float = clampf(rng.randfn(0.0, 0.10), -0.38, 0.38)
            d = Vector3(
                cos(longitude) * cos(latitude),
                sin(latitude),
                sin(longitude) * cos(latitude)
            )
            d = (galactic_basis * d).normalized()
        else:
            d = Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()

        var masked: bool = false
        for axis in void_axes:
            if d.dot(axis) > 0.86 and rng.randf() < 0.86:
                masked = true
                break
        if masked:
            d = Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()

        var radius: float = lerpf(min_r, max_r, pow(rng.randf(), 0.60))
        var size: float = lerpf(min_s, max_s, pow(rng.randf(), 2.7))
        if rng.randf() > 0.994:
            size *= rng.randf_range(3.0, 6.5)
        mm.set_instance_transform(
            i,
            Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), d * radius)
        )

        var temp: float = rng.randf()
        var color: Color = Color("#eef5ff")
        if temp < 0.13:
            color = Color("#88b5ff")
        elif temp > 0.84:
            color = Color("#ffd09a")
        color = color.lerp(accent, rng.randf_range(0.0, 0.045))
        mm.set_instance_color(i, color)

    var inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
    inst.name = p_name
    inst.multimesh = mm
    add_child(inst)

func _sprite(texture_path: String, pos: Vector3, size: Vector2, tint: Color, energy: float) -> void:
    var quad: QuadMesh = QuadMesh.new()
    quad.size = size
    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.albedo_texture = load(texture_path)
    mat.albedo_color = tint
    mat.emission_enabled = true
    mat.emission_texture = load(texture_path)
    mat.emission = tint
    mat.emission_energy_multiplier = energy
    quad.material = mat
    var n: MeshInstance3D = MeshInstance3D.new()
    n.mesh = quad
    n.position = pos
    add_child(n)

func _galaxy_billboards() -> void:
    var textures: Array[String] = [
        "galaxy_blue.png", "galaxy_edge.png", "galaxy_violet.png", "galaxy_gold.png"
    ]
    var anchors: Array[Vector3] = [
        Vector3(-190,72,-285), Vector3(205,-55,-310), Vector3(86,166,-262),
        Vector3(-118,-142,-240), Vector3(252,105,-172), Vector3(-245,5,-130),
        Vector3(42,-202,-170), Vector3(286,-118,-235), Vector3(-310,138,-250),
        Vector3(145,218,-305), Vector3(-65,245,-322), Vector3(325,42,-345),
        Vector3(-282,-176,-314), Vector3(224,186,-370), Vector3(-344,52,-352),
        Vector3(64,-250,-330), Vector3(355,-45,-282), Vector3(-210,220,-388)
    ]
    for i in range(anchors.size()):
        var tex: String = textures[i % textures.size()]
        var base: float = rng.randf_range(14.0, 54.0)
        var aspect: float = 0.48 if tex == "galaxy_edge.png" else 1.0
        var tint: Color = Color(0.86, 0.91, 1.0, rng.randf_range(0.48, 0.82))
        if tex == "galaxy_gold.png": tint = Color(1.0,0.88,0.68,tint.a)
        elif tex == "galaxy_violet.png": tint = Color(0.90,0.76,1.0,tint.a)
        _sprite(
            "res://assets/cinematic/textures/" + tex,
            anchors[i],
            Vector2(base, base * aspect),
            tint,
            rng.randf_range(0.85, 1.35)
        )

func _nebula_material(texture_name: String, tint: Color) -> StandardMaterial3D:
    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.vertex_color_use_as_albedo = true
    mat.albedo_texture = load("res://assets/cinematic/textures/" + texture_name)
    mat.albedo_color = tint
    mat.emission_enabled = true
    mat.emission_texture = mat.albedo_texture
    mat.emission = tint
    mat.emission_energy_multiplier = 0.72
    return mat

func _nebula_volume(texture_name: String, center: Vector3, extent: Vector3, count: int, tint: Color) -> void:
    var quad: QuadMesh = QuadMesh.new()
    quad.size = Vector2.ONE
    quad.material = _nebula_material(texture_name, tint)
    var mm: MultiMesh = MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.use_colors = true
    mm.mesh = quad
    mm.instance_count = count
    for i in range(count):
        var offset: Vector3 = Vector3(
            rng.randfn(0.0, extent.x * 0.34),
            rng.randfn(0.0, extent.y * 0.34),
            rng.randfn(0.0, extent.z * 0.34)
        )
        var size: float = rng.randf_range(13.0, 38.0)
        mm.set_instance_transform(
            i,
            Transform3D(Basis.IDENTITY.scaled(Vector3(size, size * rng.randf_range(0.55,1.15), 1.0)), center + offset)
        )
        mm.set_instance_color(i, Color(1.0,1.0,1.0,rng.randf_range(0.06,0.20)))
    var inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
    inst.multimesh = mm
    add_child(inst)

func _nebula_volumes() -> void:
    _nebula_volume("nebula_blue.png", Vector3(-125,25,-235), Vector3(100,70,80), int(54.0*detail), Color(0.63,0.82,1.0,0.52))
    _nebula_volume("nebula_purple.png", Vector3(135,72,-285), Vector3(120,84,100), int(62.0*detail), Color(0.90,0.62,1.0,0.48))
    _nebula_volume("nebula_red.png", Vector3(5,-145,-310), Vector3(95,76,95), int(46.0*detail), Color(1.0,0.52,0.58,0.42))

func _globular_cluster(center: Vector3, radius: float, count: int, color: Color) -> void:
    var quad: QuadMesh = QuadMesh.new()
    quad.size = Vector2.ONE
    quad.material = _star_material()
    var mm: MultiMesh = MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.use_colors = true
    mm.mesh = quad
    mm.instance_count = count
    for i in range(count):
        var d: Vector3 = Vector3(rng.randfn(),rng.randfn(),rng.randfn()).normalized()
        var rr: float = radius * pow(rng.randf(), 2.7)
        var size: float = rng.randf_range(0.04,0.12)
        mm.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*size),center+d*rr))
        mm.set_instance_color(i,color.lerp(Color.WHITE,rng.randf_range(0.0,0.65)))
    var inst: MultiMeshInstance3D = MultiMeshInstance3D.new()
    inst.multimesh = mm
    add_child(inst)
