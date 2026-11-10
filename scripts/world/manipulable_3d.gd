class_name Manipulable3D
extends Area3D

var label := ""
var radius := 1.0
var highlight_shell: MeshInstance3D
var _grip_shape: CollisionShape3D

func setup(p_radius: float, p_label: String) -> void:
    radius = p_radius
    label = p_label
    collision_layer = 4
    collision_mask = 0

    var shape := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = radius
    shape.shape = sphere
    add_child(shape)
    _grip_shape = shape

## Where the grip takes hold of it: a box of `extent` round `centre`, for a thing taken where it is
## drawn (a book among others on a shelf), not the sphere round its middle that would reach its
## neighbours.
func reshape(extent: Vector3, centre: Vector3) -> void:
    if _grip_shape == null:
        return
    var box := BoxShape3D.new()
    box.size = extent
    _grip_shape.shape = box
    _grip_shape.position = centre

func set_highlighted(value: bool) -> void:
    if highlight_shell:
        highlight_shell.visible = value

func begin_grab() -> void:
    set_highlighted(true)

func end_grab() -> void:
    set_highlighted(false)
