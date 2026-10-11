class_name WristMenu
extends Node3D

const Interactable3DClass = preload("res://scripts/world/interactable_3d.gd")

var app: Node
var left_hand: XRController3D
var left_pose: Node3D
var camera: XRCamera3D
var registry
var config
var accent: Color = Color("#63ddff")
var button_nodes: Array[Area3D] = []
var menu_pressed: bool = false

func setup(
    p_app: Node,
    p_left_hand: XRController3D,
    p_left_pose: Node3D,
    p_camera: XRCamera3D,
    p_registry,
    p_config
) -> void:
    app = p_app
    left_hand = p_left_hand
    left_pose = p_left_pose
    camera = p_camera
    registry = p_registry
    config = p_config
    accent = Color(str(registry.theme(str(config.get_value("world.theme", "cyan"))).get("accent", "#63ddff")))
    _build()
    _set_open(false)

func refresh_theme() -> void:
    for child in get_children():
        child.queue_free()
    button_nodes.clear()
    accent = Color(str(registry.theme(str(config.get_value("world.theme", "cyan"))).get("accent", "#63ddff")))
    _build()
    _set_open(false)

func _build() -> void:
    var shell := MeshInstance3D.new()
    var shell_mesh := BoxMesh.new()
    shell_mesh.size = Vector3(1.64, 0.82, 0.045)
    shell.mesh = shell_mesh
    shell.position.z = 0.04
    var shell_mat := StandardMaterial3D.new()
    shell_mat.albedo_color = Color(0.015, 0.022, 0.030, 0.94)
    shell_mat.metallic = 0.42
    shell_mat.roughness = 0.23
    shell_mat.emission_enabled = true
    shell_mat.emission = accent * 0.08
    shell.material_override = shell_mat
    add_child(shell)

    var title := Label3D.new()
    title.text = "ELI // WRIST"
    title.font_size = 27
    title.pixel_size = 0.0015
    title.modulate = accent
    title.position = Vector3(0.0, 0.31, -0.015)
    title.no_depth_test = true
    add_child(title)

    var items: Array = [
        ["CORE", "room", "core_room"],
        ["SPACE", "environment", "deep_space"],
        ["FOREST", "environment", "forest_sanctuary"],
        ["OCEAN", "environment", "ocean_platform"],
        ["MOUNTAIN", "environment", "mountain_observatory"],
        ["MATRIX", "environment", "digital_matrix"],
        ["CALIBRATE", "system", "calibration"],
        ["EXIT", "system", "exit"],
    ]

    for i in range(items.size()):
        var row: int = int(i / 3)
        var col: int = i % 3
        var b = Interactable3DClass.new()
        b.setup(str(items[i][0]), str(items[i][1]), str(items[i][2]), accent, Vector2(0.46, 0.24))
        b.position = Vector3((col - 1) * 0.52, 0.08 - row * 0.29, -0.015)
        b.activated.connect(_on_action)
        add_child(b)
        button_nodes.append(b)

func _process(_delta: float) -> void:
    if left_hand == null or camera == null:
        return

    # Follow the left wrist but always face the user's head for legibility.
    var pose_root: Node3D = left_pose if left_pose != null else left_hand
    global_position = pose_root.to_global(Vector3(0.0, 0.075, 0.105))
    if global_position.distance_to(camera.global_position) > 0.05:
        look_at(camera.global_position, Vector3.UP)

    var pressed: bool = left_hand.is_button_pressed("menu_button")
    if pressed and not menu_pressed:
        _set_open(not visible)
    menu_pressed = pressed

func _set_open(opened: bool) -> void:
    visible = opened
    for b in button_nodes:
        b.collision_layer = 2 if opened else 0

func _on_action(kind: String, value: String) -> void:
    if app and app.has_method("apply_console_action"):
        app.apply_console_action(kind, value)
        _set_open(false)
