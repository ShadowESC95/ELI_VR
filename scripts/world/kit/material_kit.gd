class_name MaterialKit
extends RefCounted

# Materials rooms share. The metal sets are real scanned surfaces (see
# assets/CREDITS.md); meshes carry UVs in metres, so `tile` is how many metres
# one repeat of the texture covers.

# `polish` below 1 makes the surface smoother than the scan, so it picks up
# reflections; above 1 makes it duller.
static func metal(name: String, tile: float = 1.0, tint: Color = Color.WHITE, polish: float = 1.0) -> StandardMaterial3D:
    var packed: Texture2D = load("res://assets/materials/%s_orm.jpg" % name)
    var m := StandardMaterial3D.new()
    m.albedo_texture = load("res://assets/materials/%s_albedo.jpg" % name)
    m.albedo_color = tint
    m.normal_enabled = true
    m.normal_texture = load("res://assets/materials/%s_normal.jpg" % name)
    # one texture carries occlusion (red), roughness (green) and metalness (blue)
    m.ao_enabled = true
    m.ao_texture = packed
    m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
    m.roughness_texture = packed
    m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
    m.roughness = polish
    m.metallic_texture = packed
    m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
    m.metallic = 1.0
    m.uv1_scale = Vector3(1.0 / tile, 1.0 / tile, 1.0)
    return m

# A surface that is a light: strips, lamps, screens.
static func light(colour: Color, energy: float = 2.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    m.albedo_color = colour * energy
    return m

static func shader(path: String, params: Dictionary = {}) -> ShaderMaterial:
    var m := ShaderMaterial.new()
    m.shader = load(path)
    for key in params:
        m.set_shader_parameter(key, params[key])
    return m

# A soft point of light that always faces the viewer. Stands in for bloom,
# which a headset does not always get. `core` is how hot the centre is.
static func halo(colour: Color, size: float, energy: float = 1.0, core: float = 0.5) -> MeshInstance3D:
    var quad := QuadMesh.new()
    quad.size = Vector2(size, size)
    var node := MeshInstance3D.new()
    node.mesh = quad
    node.material_override = shader("res://assets/shaders/glow_sprite.gdshader", {
        "tint": Vector3(colour.r, colour.g, colour.b), "energy": energy, "core": core,
    })
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return node
