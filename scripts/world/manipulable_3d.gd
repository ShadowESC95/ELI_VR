class_name Manipulable3D
extends Area3D

var label := ""
var radius := 1.0
var highlight_shell: MeshInstance3D

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

func set_highlighted(value: bool) -> void:
    if highlight_shell:
        highlight_shell.visible = value

func begin_grab() -> void:
    set_highlighted(true)

func end_grab() -> void:
    set_highlighted(false)
