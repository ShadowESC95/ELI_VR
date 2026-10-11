class_name XRControllerCalibration
extends Node

var xr_origin: XROrigin3D
var camera: XRCamera3D
var left_grip_source: XRController3D
var right_grip_source: XRController3D
var left_aim_source: XRController3D
var right_aim_source: XRController3D
var config

var left_grip_root: Node3D
var right_grip_root: Node3D
var left_aim_root: Node3D
var right_aim_root: Node3D

var offset_m: Vector3 = Vector3.ZERO
var yaw_deg: float = 0.0
var stable_tracking_seconds: float = 0.0

signal calibrated(offset_m: Vector3, yaw_deg: float)
signal calibration_reset

func setup(
    p_origin: XROrigin3D,
    p_camera: XRCamera3D,
    p_left_grip: XRController3D,
    p_right_grip: XRController3D,
    p_left_aim: XRController3D,
    p_right_aim: XRController3D,
    p_config
) -> void:
    xr_origin = p_origin
    camera = p_camera
    left_grip_source = p_left_grip
    right_grip_source = p_right_grip
    left_aim_source = p_left_aim
    right_aim_source = p_right_aim
    config = p_config

    offset_m = Vector3(
        float(config.get_value("xr.controller_calibration.offset_x_m", 0.0)),
        float(config.get_value("xr.controller_calibration.offset_y_m", 0.0)),
        float(config.get_value("xr.controller_calibration.offset_z_m", 0.0))
    )
    yaw_deg = float(config.get_value("xr.controller_calibration.yaw_deg", 0.0))

    left_grip_root = _make_root("LeftGripCalibrated")
    right_grip_root = _make_root("RightGripCalibrated")
    left_aim_root = _make_root("LeftAimCalibrated")
    right_aim_root = _make_root("RightAimCalibrated")

func _make_root(p_name: String) -> Node3D:
    var root: Node3D = Node3D.new()
    root.name = p_name
    xr_origin.add_child(root)
    return root

func _physics_process(delta: float) -> void:
    if xr_origin == null or camera == null:
        return

    _update_pose(left_grip_source, left_grip_root)
    _update_pose(right_grip_source, right_grip_root)
    _update_pose(left_aim_source, left_aim_root)
    _update_pose(right_aim_source, right_aim_root)

    if has_both_grip_tracking():
        stable_tracking_seconds += delta
    else:
        stable_tracking_seconds = 0.0

func _update_pose(source: XRController3D, target: Node3D) -> void:
    if source == null or target == null:
        return

    var raw: Transform3D = source.transform
    var yaw_basis: Basis = Basis(Vector3.UP, deg_to_rad(yaw_deg))
    var head_local: Vector3 = camera.position
    var rel: Vector3 = raw.origin - head_local
    var corrected_origin: Vector3 = head_local + yaw_basis * rel + offset_m
    var corrected_basis: Basis = yaw_basis * raw.basis
    target.transform = Transform3D(corrected_basis, corrected_origin)
    target.visible = source.get_has_tracking_data()

func has_both_grip_tracking() -> bool:
    return (
        left_grip_source != null
        and right_grip_source != null
        and left_grip_source.get_has_tracking_data()
        and right_grip_source.get_has_tracking_data()
    )

func calibrate_hands() -> bool:
    if not has_both_grip_tracking() or stable_tracking_seconds < 0.20:
        return false

    # Guided pose: user holds both controllers naturally together/in front of
    # the sternum while looking approximately forward. We correct the common
    # translation error but preserve the runtime's measured hand separation.
    var raw_mid: Vector3 = (left_grip_source.position + right_grip_source.position) * 0.5

    var forward: Vector3 = -camera.transform.basis.z
    forward.y = 0.0
    if forward.length_squared() < 0.001:
        forward = Vector3.FORWARD
    forward = forward.normalized()

    var target_forward: float = float(config.get_value("xr.controller_calibration.target_forward_m", 0.42))
    var target_down: float = float(config.get_value("xr.controller_calibration.target_down_m", 0.30))
    var target_mid: Vector3 = camera.position + forward * target_forward + Vector3.DOWN * target_down

    # Yaw is preserved during automatic calibration. It can be trimmed
    # separately from the calibration widget if required.
    var yaw_basis: Basis = Basis(Vector3.UP, deg_to_rad(yaw_deg))
    var head_local: Vector3 = camera.position
    var rotated_raw_mid: Vector3 = head_local + yaw_basis * (raw_mid - head_local)
    offset_m = target_mid - rotated_raw_mid

    _save()
    calibrated.emit(offset_m, yaw_deg)

    left_grip_source.trigger_haptic_pulse("haptic", 0.0, 0.55, 0.08, 0.0)
    right_grip_source.trigger_haptic_pulse("haptic", 0.0, 0.55, 0.08, 0.0)

    print(
        "ELI VR XR CALIBRATION: hands calibrated offset=",
        offset_m,
        " yaw_deg=",
        yaw_deg
    )
    return true

func nudge(delta_m: Vector3) -> void:
    offset_m += delta_m
    _save()
    calibrated.emit(offset_m, yaw_deg)

func nudge_yaw(delta_deg: float) -> void:
    yaw_deg = wrapf(yaw_deg + delta_deg, -180.0, 180.0)
    _save()
    calibrated.emit(offset_m, yaw_deg)

func reset_calibration() -> void:
    offset_m = Vector3.ZERO
    yaw_deg = 0.0
    _save()
    calibration_reset.emit()
    print("ELI VR XR CALIBRATION: reset")

func recenter_view() -> void:
    # Recenter the HMD/reference frame separately from hand correction.
    XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)
    print("ELI VR XR CALIBRATION: view recentered")

func offset_centimeters() -> Vector3:
    return offset_m * 100.0

func _save() -> void:
    config.set_value("xr.controller_calibration.offset_x_m", offset_m.x)
    config.set_value("xr.controller_calibration.offset_y_m", offset_m.y)
    config.set_value("xr.controller_calibration.offset_z_m", offset_m.z)
    config.set_value("xr.controller_calibration.yaw_deg", yaw_deg)
    config.save_runtime()
