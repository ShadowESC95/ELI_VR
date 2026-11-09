class_name XRCalibrationWidget
extends Node3D

# Built-in Godot classes only (docs/XR-CALIBRATION-0.3.5-ISOLATION-FIX.md): the manager is called by
# name, never typed, so this panel compiles on its own.
#
# The pointer is recalibrated at any time, with the existing guided calibration of the manager
# (calibrate_hands, which keeps and saves the result as it always has):
# - the chord: CHORD_ACTION held on both controllers for CHORD_HOLD_SECONDS. B/Y is bound on both hands
#   in the Touch, Index and generic profiles (openxr_action_map.tres: Touch Y and B, Index B and B,
#   generic secondary and secondary), no other action is bound to its input, and its only other use is
#   a press on its own (the spatial console), decided here on letting go, so the chord never toggles the
#   console (tests/test_xr_controls.py reads the map and the scripts for it). A/X is held to talk, the
#   stick clicks boost, right-click the desktop and reset the trim, the grips and triggers grab and fire:
#   none of those is free for a chord;
# - RECALIBRATE POINTER on the wrist menu arms it, for controllers without B/Y as well: then both
#   triggers held for the same time take the pose, and the triggers are this panel's, not the pointer's,
#   the desktop's or a game's, until both are let go (takes_triggers); while the wrist menu is open they
#   are the pointer's again, so the menu's own buttons (STOP RECALIBRATING among them) can be pressed.
# The hold shows as a bar filling, and the result is said and felt before the panel goes again.
# The old chord, both grips and both triggers, is what holding a gun in each hand and firing is.

var manager: Node
var left_controller: XRController3D
var right_controller: XRController3D
var camera: XRCamera3D
var accent: Color = Color("#6ee7ff")

var title_label: Label3D
var instructions_label: Label3D
var status_label: Label3D
var help_label: Label3D
var progress_fill: MeshInstance3D
var progress_track: MeshInstance3D
var trim_cooldown: float = 0.0

## The panel opened to trim by hand (CALIBRATE, F6): the sticks trim while it is open.
var trim_open: bool = false
## Whether the offsets are written out (the COORDINATES readout, HudReadouts).
var show_offsets: bool = false

var _mode: String = ""              # "" | "chord": the chord is being held | "armed": from the wrist menu
var _hold: float = 0.0
var _latched: bool = false
var _closing_in: float = 0.0
var _triggers_free: bool = false
var _took_triggers: bool = false
var _chord_button_down: bool = false
var _chord_press_both: bool = false
var _menu_open: bool = false
var _status_prefix: String = "READY"
var _percent_shown: int = -1

static var _trigger_owner: bool = false

signal chord_button_alone

const CHORD_ACTION: String = "by_button"
const CHORD_HOLD_SECONDS: float = 1.0
## How long the result stays up before the panel goes: long enough to read two words.
const CONFIRM_SECONDS: float = 1.6
const NUDGE_METERS: float = 0.02
const YAW_NUDGE_DEG: float = 2.0
const TRIM_REPEAT_SECONDS: float = 0.14
const STICK_THRESHOLD: float = 0.72
const BAR_WIDTH: float = 1.24
const BAR_HEIGHT: float = 0.026
## The percent written beside the bar moves in these steps, so its text is not rebuilt every frame.
const PERCENT_STEP: int = 10

## Whether the triggers are taken by a recalibration armed from the wrist menu.
static func takes_triggers() -> bool:
    return _trigger_owner

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
    _refresh()
    manager.connect(&"calibrated", Callable(self, "_on_calibrated"))
    manager.connect(&"calibration_reset", Callable(self, "_on_reset"))

func _exit_tree() -> void:
    _trigger_owner = false

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

    title_label = Label3D.new()
    title_label.font_size = 30
    title_label.pixel_size = 0.00130
    title_label.modulate = accent
    title_label.position = Vector3(0.0, 0.405, -0.01)
    title_label.no_depth_test = true
    add_child(title_label)

    instructions_label = Label3D.new()
    instructions_label.font_size = 20
    instructions_label.pixel_size = 0.00110
    instructions_label.modulate = Color("#eefaff")
    instructions_label.position = Vector3(0.0, 0.225, -0.005)
    instructions_label.no_depth_test = true
    add_child(instructions_label)

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
    status_label.position = Vector3(0.0, -0.405, -0.005)
    status_label.no_depth_test = true
    add_child(status_label)

    progress_track = _bar(Color(accent.r, accent.g, accent.b, 0.18), 0.4)
    progress_track.position = Vector3(0.0, -0.475, -0.004)
    add_child(progress_track)
    progress_fill = _bar(accent, 1.8)
    progress_fill.position = Vector3(0.0, -0.475, -0.008)
    add_child(progress_fill)
    _show_progress(0.0)
    _update_status("READY")

func _bar(colour: Color, glow: float) -> MeshInstance3D:
    var bar: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = Vector3(BAR_WIDTH, BAR_HEIGHT, 0.010)
    bar.mesh = mesh
    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color = colour
    mat.emission_enabled = true
    mat.emission = Color(colour.r, colour.g, colour.b)
    mat.emission_energy_multiplier = glow
    bar.material_override = mat
    return bar

func _process(delta: float) -> void:
    if manager == null or left_controller == null or right_controller == null:
        return

    advance(
        delta,
        left_controller.is_button_pressed(CHORD_ACTION),
        right_controller.is_button_pressed(CHORD_ACTION),
        left_controller.is_button_pressed("trigger_click"),
        right_controller.is_button_pressed("trigger_click")
    )

    if not trim_open:
        return

    trim_cooldown = maxf(0.0, trim_cooldown - delta)
    if trim_cooldown <= 0.0:
        _handle_manual_trim()

## One frame of the recalibration gestures, from what the buttons are doing.
func advance(delta: float, chord_left: bool, chord_right: bool, trigger_left: bool, trigger_right: bool) -> void:
    _sort_chord_button(chord_left, chord_right)

    var chord: bool = chord_left and chord_right
    var armed_now: bool = _mode == "armed" and not _menu_open
    if armed_now and not trigger_left and not trigger_right:
        _triggers_free = true           # the trigger that pressed RECALIBRATE POINTER is let go first
    var holding: bool = chord or (armed_now and _triggers_free and trigger_left and trigger_right)

    if _closing_in > 0.0:
        _closing_in -= delta
        if _closing_in <= 0.0:
            _closing_in = 0.0
            if _mode == "chord":
                _mode = ""
            _refresh()

    if holding and not _latched:
        if _hold <= 0.0:
            _begin_hold()
        _hold += delta
        _show_progress(_hold / CHORD_HOLD_SECONDS)
        if _hold >= CHORD_HOLD_SECONDS:
            _latched = true
            _recalibrate()
    elif not holding:
        if _hold > 0.0 and not _latched:
            _cancel_hold()
        _hold = 0.0
        _latched = false

    if not trigger_left and not trigger_right:
        _took_triggers = false
    _own_triggers()

func _own_triggers() -> void:
    _trigger_owner = (_mode == "armed" and not _menu_open) or _took_triggers

# B/Y on its own is the spatial console's: told on letting go, and only when the other B/Y was not
# down at any moment of the press, so the chord never toggles the console as well.
func _sort_chord_button(left: bool, right: bool) -> void:
    if left and right:
        _chord_press_both = true
    if left or right:
        _chord_button_down = true
    elif _chord_button_down:
        _chord_button_down = false
        if not _chord_press_both:
            chord_button_alone.emit()
        _chord_press_both = false

func _begin_hold() -> void:
    _closing_in = 0.0
    if _mode == "":
        _mode = "chord"
    _refresh()
    _update_status("HOLD")
    _pulse(0.20, 0.03)

func _cancel_hold() -> void:
    _show_progress(0.0)
    if _mode == "chord":
        _mode = ""
    _update_status("READY")
    _refresh()

func _recalibrate() -> void:
    var was_armed: bool = _mode == "armed"
    var result: Variant = manager.call(&"calibrate_hands")
    _show_progress(0.0)
    if result is bool and bool(result):
        if was_armed:
            _took_triggers = true
        _mode = ""
        _update_status("POINTER RECALIBRATED")
        _closing_in = 0.0 if trim_open else CONFIRM_SECONDS
    else:
        _update_status("WAITING FOR BOTH CONTROLLERS TO TRACK")
        if _mode == "chord":
            _closing_in = CONFIRM_SECONDS       # then the chord's prompt goes; an open panel stays
    _refresh()

## RECALIBRATE POINTER on the wrist menu: arms a recalibration, or stops the one armed.
func toggle_recalibration() -> void:
    if _mode == "armed":
        _mode = ""
        _hold = 0.0
        _show_progress(0.0)
        _update_status("READY")
    else:
        _mode = "armed"
        _closing_in = 0.0
        _hold = 0.0
        _latched = false
        _triggers_free = false
        _show_progress(0.0)
        _update_status("READY")
    _own_triggers()
    _refresh()

func is_armed() -> bool:
    return _mode == "armed"

## The wrist menu opening or closing: while it is open an armed recalibration leaves the triggers to
## the pointer, and once it closes a fresh press of both is needed.
func set_menu_open(open: bool) -> void:
    _menu_open = open
    _triggers_free = false
    _own_triggers()

func toggle() -> void:
    trim_open = not trim_open
    if trim_open:
        _update_status("READY")
    _refresh()

func open() -> void:
    trim_open = true
    _update_status("READY")
    _refresh()

func set_show_offsets(on: bool) -> void:
    show_offsets = on
    _update_status(_status_prefix)

# What the panel says for what it is open for, and whether it is up at all.
func _refresh() -> void:
    visible = trim_open or _mode != "" or _closing_in > 0.0
    if title_label == null:
        return
    var hold_text: String = "%s s" % String.num(CHORD_HOLD_SECONDS)
    help_label.visible = trim_open
    if trim_open:
        title_label.text = "ELI // XR CALIBRATION"
        instructions_label.text = (
            "POINTER-INDEPENDENT CALIBRATION\n"
            + "Hold both controllers together naturally in front of your chest.\n"
            + "Hold B/Y (the upper face button) on BOTH controllers for %s." % hold_text
        )
    elif _mode == "armed":
        title_label.text = "ELI // RECALIBRATE POINTER"
        instructions_label.text = (
            "Hold both controllers together naturally in front of your chest,\n"
            + "then hold BOTH TRIGGERS (or B/Y on both) for %s.\n" % hold_text
            + "STOP RECALIBRATING on the wrist menu stops it."
        )
    else:
        title_label.text = "ELI // RECALIBRATE POINTER"
        instructions_label.text = (
            "Keep holding B/Y on both controllers,\n"
            + "with both controllers together in front of your chest."
        )

func _show_progress(fraction: float) -> void:
    if progress_fill == null:
        return
    var f: float = clampf(fraction, 0.0, 1.0)
    progress_track.visible = f > 0.0
    progress_fill.visible = f > 0.0
    if f > 0.0:
        progress_fill.scale.x = f
        progress_fill.position.x = -BAR_WIDTH * (1.0 - f) * 0.5
    var percent: int = int(floor(f * 100.0 / float(PERCENT_STEP))) * PERCENT_STEP
    if f > 0.0 and percent != _percent_shown and _status_prefix.begins_with("HOLD"):
        _percent_shown = percent
        _update_status("HOLD %d%%" % percent)
    elif f <= 0.0:
        _percent_shown = -1

func _pulse(amplitude: float, seconds: float) -> void:
    for controller in [left_controller, right_controller]:
        if controller != null:
            controller.trigger_haptic_pulse("haptic", 0.0, amplitude, seconds, 0.0)

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
    _status_prefix = prefix
    if status_label == null or manager == null:
        return
    if not show_offsets:
        status_label.text = prefix
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
