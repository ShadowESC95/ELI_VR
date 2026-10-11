class_name DesktopNavigation
extends Node

var camera: Camera3D
var speed := 5.0
var yaw := 0.0
var pitch := 0.0
var mouse_captured := false

func setup(p_camera: Camera3D) -> void:
    camera = p_camera

func _ready() -> void:
    set_process_unhandled_input(true)

func _process(delta: float) -> void:
    if not camera:
        return
    var move := Vector3.ZERO
    if Input.is_key_pressed(KEY_W): move.z -= 1
    if Input.is_key_pressed(KEY_S): move.z += 1
    if Input.is_key_pressed(KEY_A): move.x -= 1
    if Input.is_key_pressed(KEY_D): move.x += 1
    if Input.is_key_pressed(KEY_Q): move.y -= 1
    if Input.is_key_pressed(KEY_E): move.y += 1
    if move.length() > 0:
        move = move.normalized()
        camera.global_position += (camera.global_transform.basis * move) * speed * delta

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
        mouse_captured = event.pressed
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mouse_captured else Input.MOUSE_MODE_VISIBLE
    elif event is InputEventMouseMotion and mouse_captured:
        yaw -= event.relative.x * 0.0022
        pitch = clamp(pitch - event.relative.y * 0.0022, -1.45, 1.45)
        camera.rotation = Vector3(pitch, yaw, 0)
