class_name MovablePanel3D
extends Area3D

var accent: Color = Color("#63ddff")
var panel_size: Vector2 = Vector2.ONE
var highlight_mesh: MeshInstance3D

func setup_panel(p_size: Vector2, p_accent: Color) -> void:
    panel_size = p_size
    accent = p_accent
    collision_layer = 4
    collision_mask = 0
    monitoring = false
    monitorable = true

    var shape_node: CollisionShape3D = CollisionShape3D.new()
    shape_node.name = "GrabSurface"
    var shape: BoxShape3D = BoxShape3D.new()
    shape.size = Vector3(panel_size.x, panel_size.y, 0.12)
    shape_node.shape = shape
    shape_node.position.z = 0.075
    add_child(shape_node)

    highlight_mesh = MeshInstance3D.new()
    highlight_mesh.name = "GrabHighlight"
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = Vector3(panel_size.x + 0.05, panel_size.y + 0.05, 0.018)
    highlight_mesh.mesh = mesh
    highlight_mesh.position.z = 0.105

    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color(accent.r, accent.g, accent.b, 0.08)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.emission_enabled = true
    mat.emission = accent
    mat.emission_energy_multiplier = 0.35
    highlight_mesh.material_override = mat
    highlight_mesh.visible = false
    add_child(highlight_mesh)

func begin_grab() -> void:
    if highlight_mesh:
        highlight_mesh.visible = true

func end_grab() -> void:
    if highlight_mesh:
        highlight_mesh.visible = false
