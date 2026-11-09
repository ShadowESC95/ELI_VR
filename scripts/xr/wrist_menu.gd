class_name WristMenu
extends Node3D

const Interactable3DClass = preload("res://scripts/world/interactable_3d.gd")
const HudReadoutsClass = preload("res://scripts/ui/hud_readouts.gd")

## How large the deck looks from the eyes, whatever the arm's length: its longer side spans about what
## is read without turning the head. The deck is laid out in its own units below and scaled to this
## at the distance it is opened at.
const DECK_SPAN_DEG := 44.0
const COLUMNS := 3
const CELL := Vector2(0.52, 0.29)
const BUTTON := Vector2(0.46, 0.24)
const TITLE_BAND := 0.30
const EDGE := 0.08
## Nearer than this the head and the wrist are not both tracked yet: the deck keeps the size it had.
const TRACKED_NEAR := 0.05

var app: Node
var left_hand: XRController3D
var left_pose: Node3D
var camera: XRCamera3D
var registry
var config
var accent: Color = Color("#63ddff")
var button_nodes: Array[Area3D] = []
var menu_pressed: bool = false
## The deck's size in its own units, before it is scaled to the eye.
var deck_size: Vector2 = Vector2.ONE

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
    var readouts = app.get("readouts")
    if readouts != null:
        readouts.changed.connect(refresh_labels)

func refresh_theme() -> void:
    for child in get_children():
        child.queue_free()
    button_nodes.clear()
    accent = Color(str(registry.theme(str(config.get_value("world.theme", "cyan"))).get("accent", "#63ddff")))
    _build()
    _set_open(false)

## The buttons in their groups, each group from a new row: where to go, the system, the readouts.
func _groups() -> Array:
    var readouts: Array = [["READOUTS", "readout", "all"]]
    for piece in HudReadoutsClass.PIECES:
        readouts.append([str(piece["label"]), "readout", str(piece["id"])])
    return [
        [
            ["CORE", "room", "core_room"],
            ["SPACE", "environment", "deep_space"],
            ["FOREST", "environment", "forest_sanctuary"],
            ["OCEAN", "environment", "ocean_platform"],
            ["MOUNTAIN", "environment", "mountain_observatory"],
            ["MATRIX", "environment", "digital_matrix"],
        ],
        [
            ["RECALIBRATE POINTER", "system", "recalibrate"],
            ["CALIBRATE", "system", "calibration"],
            ["EXIT", "system", "exit"],
        ],
        readouts,
    ]

func _build() -> void:
    var rows: int = 0
    for group in _groups():
        rows += int(ceil(float(group.size()) / float(COLUMNS)))
    var deck := Vector2(COLUMNS * CELL.x + EDGE * 2.0, TITLE_BAND + rows * CELL.y + EDGE)
    var top: float = deck.y * 0.5

    var shell := MeshInstance3D.new()
    var shell_mesh := BoxMesh.new()
    shell_mesh.size = Vector3(deck.x, deck.y, 0.045)
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
    title.position = Vector3(0.0, top - TITLE_BAND * 0.5, -0.015)
    title.no_depth_test = true
    add_child(title)

    var row: int = 0
    for group in _groups():
        for i in range(group.size()):
            var item: Array = group[i]
            var col: int = i % COLUMNS
            var b = Interactable3DClass.new()
            b.setup(str(item[0]), str(item[1]), str(item[2]), accent, BUTTON)
            b.set_meta("base_label", str(item[0]))
            b.position = Vector3(
                (col - (COLUMNS - 1) * 0.5) * CELL.x,
                top - TITLE_BAND - (row + int(i / COLUMNS) + 0.5) * CELL.y,
                -0.015
            )
            b.activated.connect(_on_action)
            add_child(b)
            button_nodes.append(b)
        row += int(ceil(float(group.size()) / float(COLUMNS)))
    deck_size = deck
    refresh_labels()

## The toggles say how they stand: each readout ON or OFF, all of them ON, OFF or SOME, and the
## recalibration whether it is armed.
func refresh_labels() -> void:
    var readouts = app.get("readouts") if app != null else null
    var widget = app.get("calibration_widget") if app != null else null
    for node in button_nodes:
        if not is_instance_valid(node):
            continue
        var b = node
        var base: String = str(b.get_meta("base_label", b.label))
        var text: String = base
        if b.kind == "readout" and readouts != null:
            text = "%s: %s" % [base, readouts.state() if b.value == "all" else ("ON" if readouts.shown(b.value) else "OFF")]
        elif b.kind == "system" and b.value == "recalibrate" and widget != null and widget.is_armed():
            text = "STOP RECALIBRATING"
        if text != b.label:
            b.set_label(text)

func _process(_delta: float) -> void:
    if left_hand == null or camera == null:
        return

    # Follow the left wrist but always face the user's head for legibility.
    var pose_root: Node3D = left_pose if left_pose != null else left_hand
    global_position = pose_root.to_global(Vector3(0.0, 0.075, 0.105))
    if global_position.distance_to(camera.global_position) > TRACKED_NEAR:
        look_at(camera.global_position, Vector3.UP)

    var pressed: bool = left_hand.is_button_pressed("menu_button")
    if pressed and not menu_pressed:
        _set_open(not visible)
    menu_pressed = pressed

func _set_open(opened: bool) -> void:
    visible = opened
    for b in button_nodes:
        b.collision_layer = 2 if opened else 0
    var widget = app.get("calibration_widget") if app != null else null
    if widget != null:
        widget.set_menu_open(opened)        # its buttons are pressed with the trigger
    if opened:
        refresh_labels()
        _fit_to_eye()

# The deck's longer side spans DECK_SPAN_DEG from the eyes at the distance it opens at.
func _fit_to_eye() -> void:
    if camera == null:
        return
    var distance: float = global_position.distance_to(camera.global_position)
    if distance <= TRACKED_NEAR:
        return
    var span: float = 2.0 * distance * tan(deg_to_rad(DECK_SPAN_DEG) * 0.5)
    scale = Vector3.ONE * (span / maxf(deck_size.x, deck_size.y))

func _on_action(kind: String, value: String) -> void:
    if app and app.has_method("apply_console_action"):
        app.apply_console_action(kind, value)
        if kind != "readout":       # a readout leaves it open: one after another can be switched
            _set_open(false)
