class_name LandKit
extends RefCounted

# Open ground for the rooms out of doors, and what stands on it. The ground is MeshKit.terrain under
# a material of two scanned surfaces blended by slope and height (land_blend.gdshader): moss and stone
# through a forest floor, rock through snow on a slope, rock through sand. A land knows its own height
# at any point (the same figure the mesh was built from), so the things placed on it (real models,
# boulders, ground cover) stand on the ground instead of floating over it or sinking into it where it
# rises. Ground cover (grass, needles, reeds, dry scrub) is drawn here as blades on an image, laid on
# MeshKit.plant tufts, and sways in the sway shader.

const SHADER := "res://assets/shaders/land_blend.gdshader"
const SWAY := "res://assets/shaders/sway.gdshader"
const BLADE_SIZE := Vector2i(64, 256)

# how each kind of blade is drawn: [root colour, tip colour, strands, width as a share of the image]
const BLADES := {
    "grass": [Color(0.16, 0.32, 0.08), Color(0.55, 0.78, 0.25), 7, 0.08],
    "needle": [Color(0.08, 0.2, 0.09), Color(0.3, 0.5, 0.2), 26, 0.03],
    "reed": [Color(0.1, 0.28, 0.14), Color(0.45, 0.7, 0.35), 1, 0.42],
    "dry": [Color(0.45, 0.36, 0.14), Color(0.85, 0.75, 0.4), 9, 0.06],
}

var size := 420.0
var cells := 150
var noise: FastNoiseLite
var height := 10.0
var flat := 12.0
var rise := 16.0
var bowl := 0.0
var base_y := -0.14
var fade := 0.0
var ground: MeshInstance3D

static var _blades := {}

## The two surfaces of a land as one material: `base` everywhere, `over` where the slope (or the
## height, or the flats: see the shader's uniforms, given in `params`) says. Names are material sets
## in assets/materials; tiles are metres one repeat covers.
static func blend(base: String, base_tile: float, base_tint: Color, over: String, over_tile: float, over_tint: Color,
                  params: Dictionary = {}) -> ShaderMaterial:
    var p := {
        "base_albedo": load("res://assets/materials/%s_albedo.jpg" % base),
        "base_normal": load("res://assets/materials/%s_normal.jpg" % base),
        "base_orm": load("res://assets/materials/%s_orm.jpg" % base),
        "over_albedo": load("res://assets/materials/%s_albedo.jpg" % over),
        "over_normal": load("res://assets/materials/%s_normal.jpg" % over),
        "over_orm": load("res://assets/materials/%s_orm.jpg" % over),
        "base_tile": base_tile, "over_tile": over_tile,
        "base_tint": Vector3(base_tint.r, base_tint.g, base_tint.b), "over_tint": Vector3(over_tint.r, over_tint.g, over_tint.b),
    }
    p.merge(params, true)
    return MaterialKit.shader(SHADER, p)

## Land laid under a room (a child of it), shaped as MeshKit.terrain shapes it: level at `base` inside
## `flat_m` of the middle, rising into the noise over `rise_m`, the far edges lifted by `bowl_m`, and
## settling back to `base` over its last `edge_fade` metres where a photograph's ground takes over.
static func lay(room: Node3D, material: Material, seed_value: int, frequency: float, octaves: int, size_m: float,
                cell_count: int, height_m: float, flat_m: float, rise_m: float, bowl_m: float = 0.0, base: float = -0.14,
                edge_fade: float = 0.0) -> LandKit:
    var land := LandKit.new()
    land.noise = FastNoiseLite.new()
    land.noise.seed = seed_value
    land.noise.frequency = frequency
    land.noise.fractal_octaves = octaves
    land.size = size_m
    land.cells = cell_count
    land.height = height_m
    land.flat = flat_m
    land.rise = rise_m
    land.bowl = bowl_m
    land.base_y = base
    land.fade = edge_fade
    land.ground = MeshInstance3D.new()
    land.ground.mesh = MeshKit.terrain(size_m, cell_count, land.noise, height_m, flat_m, rise_m, bowl_m, base, edge_fade)
    land.ground.material_override = material
    room.add_child(land.ground)
    return land

## The ground's height at a point: the figure the mesh was built from.
func y_at(x: float, z: float) -> float:
    return MeshKit.land_height(x, z, size, noise, height, flat, rise, bowl, base_y, fade)

## How the ground tilts at a point, as a basis whose up is the ground's normal, for a thing to lean with it.
func tilt_at(x: float, z: float) -> Basis:
    var d := maxf(0.25, size / float(cells))
    var normal := Vector3(y_at(x - d, z) - y_at(x + d, z), 2.0 * d, y_at(x, z - d) - y_at(x, z + d)).normalized()
    var axis := Vector3.UP.cross(normal)
    if axis.length() < 0.0001:
        return Basis.IDENTITY
    return Basis(axis.normalized(), Vector3.UP.angle_to(normal))

## A real thing (assets/models) stood on the ground at (at.x, at.z), `at.y` above it, turned `turn`
## degrees; `lean` tilts it with the ground (for small things: a stone, a stump).
func on(room, model: String, at: Vector3, turn: float = 0.0, scale: float = 1.0, lean: bool = false) -> Node3D:
    var node: Node3D = room.prop(model, Vector3(at.x, y_at(at.x, at.z) + at.y, at.z), turn, scale)
    if node != null and lean:
        node.basis = tilt_at(at.x, at.z) * node.basis
    return node

## Real things scattered round the room on the ground, between `inner` and `outer` metres out, each
## one of `models` in turn, turned and sized at random.
func scatter(room, models: Array, count: int, inner: float, outer: float, rng: RandomNumberGenerator,
             scale_lo: float = 1.0, scale_hi: float = 1.0, lift: float = 0.0, lean: bool = false) -> Array:
    var placed := []
    for i in count:
        var angle := rng.randf() * TAU
        var distance := rng.randf_range(inner, outer)
        var node := on(room, str(models[i % models.size()]), Vector3(cos(angle) * distance, lift, sin(angle) * distance),
                       rng.randf() * 360.0, rng.randf_range(scale_lo, scale_hi), lean)
        if node != null:
            placed.append(node)
    return placed

## Ground cover: `count` of one mesh on the ground between `inner` and `outer` metres out, as one
## batch, each turned and sized at random and set a little into the ground so none floats.
func cover(room: Node3D, mesh: Mesh, material: Material, count: int, inner: float, outer: float,
           rng: RandomNumberGenerator, scale_lo: float = 0.8, scale_hi: float = 1.4, sink: float = 0.03) -> MultiMeshInstance3D:
    var many := MultiMesh.new()
    many.transform_format = MultiMesh.TRANSFORM_3D
    many.mesh = mesh
    many.instance_count = count
    var stood := PackedVector3Array()
    for i in count:
        var angle := rng.randf() * TAU
        var distance := rng.randf_range(inner, outer)
        var x := cos(angle) * distance
        var z := sin(angle) * distance
        var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(scale_lo, scale_hi))
        var at := Vector3(x, y_at(x, z) - sink, z)
        many.set_instance_transform(i, Transform3D(basis, at))
        stood.append(at)
    var field := MultiMeshInstance3D.new()
    field.multimesh = many
    field.material_override = material
    field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    # where each stands, kept on the node: the rendering server does not give transforms back headless
    field.set_meta("stood_at", stood)
    room.add_child(field)
    return field

## A blade for ground cover, drawn here: strands from the root (the image's foot, where MeshKit.plant
## puts UV.y = 1) to their tips, tapering, bending a little, darker at the root. Made once per kind.
static func blade_texture(kind: String) -> ImageTexture:
    if _blades.has(kind):
        return _blades[kind]
    var spec: Array = BLADES.get(kind, BLADES["grass"])
    var w := BLADE_SIZE.x
    var h := BLADE_SIZE.y
    var image := Image.create(w, h, true, Image.FORMAT_RGBA8)
    image.fill(Color(0, 0, 0, 0))
    var rng := RandomNumberGenerator.new()
    rng.seed = kind.hash()
    var root: Color = spec[0]
    var tip: Color = spec[1]
    var strands: int = spec[2]
    var width0: float = float(spec[3]) * w
    for _s in strands:
        var x0 := (0.5 * w) if strands == 1 else rng.randf_range(0.15, 0.85) * w
        var bend := rng.randf_range(-0.25, 0.25)
        var top := rng.randf_range(0.55, 1.0)
        for y in h:
            var up := 1.0 - float(y) / float(h)       # how far up the strand this row is
            if up > top:
                continue
            var width := width0 * pow(1.0 - up / top, 0.6)
            var cx := x0 + bend * w * up * up
            var c := root.lerp(tip, up / top)
            for px in range(int(floor(cx - width)), int(ceil(cx + width)) + 1):
                if px >= 0 and px < w:
                    image.set_pixel(px, y, Color(c.r, c.g, c.b, 1.0))
    image.generate_mipmaps()
    var texture := ImageTexture.create_from_image(image)
    _blades[kind] = texture
    return texture

## Ground cover that sways: the blade of `kind`, tinted, moving `reach` metres at `pace`.
static func sway_material(kind: String, tint: Color, reach: float, pace: float, glow: float = 0.0) -> ShaderMaterial:
    return MaterialKit.shader(SWAY, {"leaf": blade_texture(kind), "tint": Vector3(tint.r, tint.g, tint.b),
                                     "reach": reach, "pace": pace, "glow": glow})

## A tuft of ground cover: blades fanned round a point (MeshKit.plant), the usual sizes of each kind.
static func tuft(kind: String, seed_value: int) -> ArrayMesh:
    match kind:
        "needle": return MeshKit.plant(5, 0.9, 2.2, 1.6, seed_value, 5)
        "reed": return MeshKit.plant(5, 0.16, 1.1, 0.35, seed_value, 7)
        "dry": return MeshKit.plant(8, 0.14, 0.42, 0.3, seed_value, 5)
    return MeshKit.plant(9, 0.12, 0.36, 0.25, seed_value, 5)
