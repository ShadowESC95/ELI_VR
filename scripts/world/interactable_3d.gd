class_name Interactable3D
extends Area3D

signal activated(kind: String, value: String)

var kind := ""
var value := ""
var label := ""
var _base_color := Color("#101b23")
var _accent_color := Color("#63ddff")
var mesh_instance: MeshInstance3D
var text_label: Label3D
var _size := Vector2.ONE
var _pixel_size := 0.0

## The words never run past the button: a label wider than this share of it is drawn smaller to fit.
const LABEL_FILL := 0.88

func setup(p_label: String, p_kind: String, p_value: String, accent: Color, size := Vector2(0.92, 0.30)) -> void:
    label = p_label
    kind = p_kind
    value = p_value
    _accent_color = accent
    _size = size
    collision_layer = 2
    collision_mask = 0

    var shape := CollisionShape3D.new()
    var box_shape := BoxShape3D.new()
    box_shape.size = Vector3(size.x, size.y, 0.07)
    shape.shape = box_shape
    add_child(shape)

    mesh_instance = MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(size.x, size.y, 0.045)
    mesh_instance.mesh = mesh

    var mat := StandardMaterial3D.new()
    mat.albedo_color = _base_color
    mat.metallic = 0.32
    mat.roughness = 0.30
    mat.emission_enabled = true
    mat.emission = _accent_color * 0.07
    mesh_instance.material_override = mat
    add_child(mesh_instance)

    text_label = Label3D.new()
    text_label.text = label
    text_label.font_size = 30
    text_label.modulate = Color("#f4fbff")
    text_label.position = Vector3(0, 0, 0.04)
    text_label.no_depth_test = true
    _pixel_size = text_label.pixel_size
    _fit_label()
    add_child(text_label)

## New words on the button (a toggle saying how it stands), fitted as the first were.
func set_label(p_label: String) -> void:
    label = p_label
    if text_label:
        text_label.text = label
        _fit_label()

func _fit_label() -> void:
    var font: Font = text_label.font if text_label.font != null else ThemeDB.fallback_font
    var wide: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, text_label.font_size).x * _pixel_size
    var room: float = _size.x * LABEL_FILL
    text_label.pixel_size = _pixel_size * (room / wide if wide > room else 1.0)

func activate() -> void:
    activated.emit(kind, value)

func set_highlighted(highlighted: bool) -> void:
    if not mesh_instance:
        return
    var mat := mesh_instance.material_override as StandardMaterial3D
    if highlighted:
        mat.albedo_color = _accent_color * 0.24
        mat.emission = _accent_color * 0.72
        mat.emission_energy_multiplier = 1.8
    else:
        mat.albedo_color = _base_color
        mat.emission = _accent_color * 0.07
        mat.emission_energy_multiplier = 1.0
