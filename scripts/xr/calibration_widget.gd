class_name XRCalibrationWidget
extends Node3D

var manager: Node
var left_controller: XRController3D
var right_controller: XRController3D
var camera: XRCamera3D
var accent: Color = Color("#6ee7ff")

var status_label: Label3D
var help_label: Label3D
var chord_seconds: float = 0.0
var chord_latched: bool = false
var trim_cooldown: float = 0.0

const CHORD_HOLD_SECONDS: float = 1.0
const NUDGE_METERS: float = 0.02
const YAW_NUDGE_DEG: float = 2.0
const TRIM_REPEAT_SECONDS: float = 0.14
const STICK_THRESHOLD: float = 0.72

func setup(
    p_manager: Node,
    p_left: XRController3D,
    p_right: XRController3D,
    p_camera: XRCamera3D,
    p_accent: Color
) -> void:
    manager = p_manager
    left_controller = p_left
    right_controller = p_right
    camera = p_camera
    accent = p_accent
    position = Vector3(0.0, -0.02, -1.20)
    _build()
    visible = false
    manager.connect(&"calibrated", Callable(self, "_on_calibrated"))
    manager.connect(&"calibration_reset", Callable(self, "_on_reset"))

func _build() -> void:
    var shell: MeshInstance3D = MeshInstance3D.new()
    var shell_mesh: BoxMesh = BoxMesh.new()
    shell_mesh.size = Vector3(1.68, 1.16, 0.045)
    shell.mesh = shell_mesh
    shell.position.z = 0.05

    var shell_mat: StandardMaterial3D = StandardMaterial3D.new()
    shell_mat.albedo_color = Color(0.012, 0.019, 0.027, 0.97)
    shell_mat.metallic = 0.36
    shell_mat.roughness = 0.24
    shell_mat.emission_enabled = true
    shell_mat.emission = accent * 0.06
    shell.material_override = shell_mat
    add_child(shell)

    var rail: MeshInstance3D = MeshInstance3D.new()
    var rail_mesh: BoxMesh = BoxMesh.new()
    rail_mesh.size = Vector3(1.48, 0.018, 0.020)
    rail.mesh = rail_mesh
    rail.position = Vector3(0.0, 0.48, 0.018)

    var rail_mat: StandardMaterial3D = StandardMaterial3D.new()
    rail_mat.albedo_color = accent
    rail_mat.emission_enabled = true
    rail_mat.emission = accent
    rail_mat.emission_energy_multiplier = 1.8
    rail.material_override = rail_mat
    add_child(rail)

    var title: Label3D = Label3D.new()
    title.text = "ELI // XR CALIBRATION"
    title.font_size = 30
    title.pixel_size = 0.00130
    title.modulate = accent
    title.position = Vector3(0.0, 0.405, -0.01)
    title.no_depth_test = true
    add_child(title)

    var instructions: Label3D = Label3D.new()
    instructions.text = (
        "POINTER-INDEPENDENT CALIBRATION\n"
        + "Hold both controllers together naturally in front of your chest.\n"
        + "Hold BOTH GRIPS + BOTH TRIGGERS for 1 second."
    )
    instructions.font_size = 20
    instructions.pixel_size = 0.00110
    instructions.modulate = Color("#eefaff")
    instructions.position = Vector3(0.0, 0.225, -0.005)
    instructions.no_depth_test = true
    add_child(instructions)

    help_label = Label3D.new()
    help_label.text = (
        "MANUAL TRIM WHILE THIS PANEL IS OPEN\n"
        + "Left stick: LEFT / RIGHT + UP / DOWN\n"
        + "Right stick Y: FORWARD / BACK\n"
        + "Right stick X: YAW LEFT / RIGHT\n"
        + "Both thumbstick clicks: RESET CALIBRATION\n"
        + "F6: close/open panel    F7: calibrate\n"
        + "RECENTER VIEW remains separate from hand calibration."
    )
    help_label.font_size = 18
    help_label.pixel_size = 0.00105
    help_label.modulate = Color("#c7d7df")
    help_label.position = Vector3(0.0, -0.085, -0.005)
    help_label.no_depth_test = true
    add_child(help_label)

    status_label = Label3D.new()
    status_label.font_size = 19
    status_label.pixel_size = 0.00110
    status_label.modulate = accent
    status_label.position = Vector3(0.0, -0.425, -0.005)
    status_label.no_depth_test = true
    add_child(status_label)
    _update_status("READY")

func _process(delta: float) -> void:
    if manager == null or left_controller == null or right_controller == null:
        return

    var chord: bool = (
        left_controller.is_button_pressed("grip_click")
        and right_controller.is_button_pressed("grip_click")
        and left_controller.is_button_pressed("trigger_click")
        and right_controller.is_button_pressed("trigger_click")
    )

    if chord and not chord_latched:
        chord_seconds += delta
        if chord_seconds >= CHORD_HOLD_SECONDS:
            chord_latched = true
            chord_seconds = 0.0
            visible = true
            _perform_calibration()
    elif not chord:
        chord_seconds = 0.0
        chord_latched = false

    if not visible:
        return

    trim_cooldown = maxf(0.0, trim_cooldown - delta)
    if trim_cooldown <= 0.0:
        _handle_manual_trim()

func toggle() -> void:
    visible = not visible
    if visible:
        _update_status("READY")

func open() -> void:
    visible = true
    _update_status("READY")

func _perform_calibration() -> void:
    var result: Variant = manager.call(&"calibrate_hands")
    if result is bool and bool(result):
        _update_status("CALIBRATED")
    else:
        _update_status("WAITING FOR BOTH CONTROLLERS TO TRACK")

func _handle_manual_trim() -> void:
    var left_stick: Vector2 = left_controller.get_vector2("primary")
    var right_stick: Vector2 = right_controller.get_vector2("primary")
    var adjustment: Vector3 = Vector3.ZERO
    var did_adjust: bool = false

    if left_stick.x > STICK_THRESHOLD:
        adjustment += Vector3.RIGHT * NUDGE_METERS
        did_adjust = true
    elif left_stick.x < -STICK_THRESHOLD:
        adjustment += Vector3.LEFT * NUDGE_METERS
        did_adjust = true

    if left_stick.y > STICK_THRESHOLD:
        adjustment += Vector3.UP * NUDGE_METERS
        did_adjust = true
    elif left_stick.y < -STICK_THRESHOLD:
        adjustment += Vector3.DOWN * NUDGE_METERS
        did_adjust = true

    if right_stick.y > STICK_THRESHOLD:
        adjustment += Vector3.FORWARD * NUDGE_METERS
        did_adjust = true
    elif right_stick.y < -STICK_THRESHOLD:
        adjustment += Vector3.BACK * NUDGE_METERS
        did_adjust = true

    if adjustment != Vector3.ZERO:
        manager.call(&"nudge", adjustment)

    if right_stick.x > STICK_THRESHOLD:
        manager.call(&"nudge_yaw", -YAW_NUDGE_DEG)
        did_adjust = true
    elif right_stick.x < -STICK_THRESHOLD:
        manager.call(&"nudge_yaw", YAW_NUDGE_DEG)
        did_adjust = true

    var both_sticks_clicked: bool = (
        left_controller.is_button_pressed("primary_click")
        and right_controller.is_button_pressed("primary_click")
    )
    if both_sticks_clicked:
        manager.call(&"reset_calibration")
        _update_status("RESET")
        trim_cooldown = 0.45
        return

    if did_adjust:
        _update_status("TRIMMED")
        trim_cooldown = TRIM_REPEAT_SECONDS

func _on_calibrated(_offset: Vector3, _yaw: float) -> void:
    _update_status("CALIBRATED")

func _on_reset() -> void:
    _update_status("RESET")

func _update_status(prefix: String) -> void:
    if status_label == null or manager == null:
        return
    var cm: Vector3 = Vector3.ZERO
    var cm_value: Variant = manager.call(&"offset_centimeters")
    if cm_value is Vector3:
        cm = cm_value
    var yaw_value: float = float(manager.get(&"yaw_deg"))
    status_label.text = (
        "%s  |  OFFSET cm  X:%+.1f  Y:%+.1f  Z:%+.1f  |  YAW:%+.1f deg"
        % [prefix, cm.x, cm.y, cm.z, yaw_value]
    )
