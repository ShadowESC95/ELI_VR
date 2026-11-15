class_name XRControllerCalibration
extends Node

# Where each hand and each pointer ray is, from the runtime's own poses.
#
# The runtime knows where a controller is and where it points: its grip pose is the hand (the palm in
# the handle), its aim pose is the ray. Both are in the same tracking space as the head, so they are
# used as they come: a hand stands at the grip pose, a ray leaves the aim pose along its -Z. Nothing
# here guesses where the hands "should" be (the old calibration put them a fixed way in front of and
# below the eyes, which moved them off the real hands by however far that guess was out).
#
# What the runtime cannot know is refined here, and only that:
# - the pointer, per controller: how this hand's pointing differs from the runtime's aim axis. The
#   gesture is to point the controllers at the mark on the calibration panel; the turn that brings the
#   ray onto the mark is kept in the controller's own frame (it is a property of the controller in the
#   hand, so it holds wherever the hand goes);
# - the tracking frame, by hand (the trim panel): one rigid turn and shift of the controllers' space
#   against the head's, kept as a fixed transform of that space (its pivot does not ride on the head);
# - a controller whose position the runtime is not tracking (its place does not change by the pose's
#   own resolution while it turns): its hand is placed from the head with the body's proportions and
#   the controller's real direction, as a controller with no position is, until its place moves again.
#
# The poses are read from plain nodes (anything with a transform and get_has_tracking_data), so the
# whole path runs headless with stand-in controllers (tests/gd/xr_calibration_check.gd).

## Body proportions as parts of stature (Drillis & Contini 1966, as tabled in Winter, Biomechanics and
## Motor Control of Human Movement): eye height, shoulder height, shoulder width, upper arm, forearm, hand.
const EYE_OF_STATURE: float = 0.936
const SHOULDER_OF_STATURE: float = 0.818
const SHOULDER_WIDTH_OF_STATURE: float = 0.259
const UPPER_ARM_OF_STATURE: float = 0.186
const FOREARM_OF_STATURE: float = 0.146
const HAND_OF_STATURE: float = 0.108
## Mean adult stature, used only while the headset gives no height above a floor to measure from
## (a reading under half of it is not a person's eye height over a floor).
const ADULT_STATURE_M: float = 1.70
## How far a controller must turn with its place unchanged before its position counts as untracked
## (and as far again with its place moving before it counts as tracked again). At a hand's lever arm
## this is thousands of times the pose's resolution, so a tracked hand cannot do it, and it is reached
## in the first seconds of use.
const UNTRACKED_TURN_RAD: float = 0.5

const SIDES: Array[String] = ["left", "right"]
const SETTINGS: String = "xr.controller_calibration"
## Settings of the calibration that guessed where the hands were: what they hold was solved from that
## guess, so it is dropped, not read.
const RETIRED_SETTINGS: Array[String] = [
    "offset_x_m", "offset_y_m", "offset_z_m", "yaw_deg", "target_forward_m", "target_down_m"]

class Hand extends RefCounted:
    var side: String = "left"
    var side_sign: float = -1.0
    var grip_source: Node3D
    var aim_source: Node3D
    var grip_root: Node3D
    var aim_root: Node3D
    ## The ray before this controller's own refinement, in the origin's space.
    var raw_aim: Transform3D = Transform3D.IDENTITY
    ## Where this hand points along, in the aim pose's own frame (-Z: as the runtime gives it).
    var aim_direction: Vector3 = Vector3.FORWARD
    ## The aim pose in the grip pose's frame, as last measured while both were tracked and moving.
    var grip_to_aim: Transform3D = Transform3D.IDENTITY
    var source: String = ""
    var position_tracked: bool = true
    var seen: bool = false
    var last_origin: Vector3 = Vector3.ZERO
    var last_from_head: Vector3 = Vector3.ZERO
    var last_turn: Quaternion = Quaternion.IDENTITY
    var turned_still: float = 0.0
    var turned_still_from_head: float = 0.0
    var turned_moving: float = 0.0

var xr_origin: Node3D
var camera: Node3D
var config
var hands: Dictionary = {}

var left_grip_root: Node3D
var right_grip_root: Node3D
var left_aim_root: Node3D
var right_aim_root: Node3D

## The trim of the controllers' tracking space against the head's: p' = turn(yaw_deg) * p + offset_m.
var offset_m: Vector3 = Vector3.ZERO
var yaw_deg: float = 0.0
## Why the last recalibration took nothing: "" | "untracked" | "off_mark".
var problem: String = ""

var _target_panel: Node3D
var _target_mark: Vector3 = Vector3.ZERO
var _target_half_size: Vector2 = Vector2.ZERO
var _peak_eye_height: float = 0.0

signal calibrated(offset_m: Vector3, yaw_deg: float)
signal calibration_reset

func setup(
    p_origin: Node3D,
    p_camera: Node3D,
    p_left_grip: Node3D,
    p_right_grip: Node3D,
    p_left_aim: Node3D,
    p_right_aim: Node3D,
    p_config
) -> void:
    xr_origin = p_origin
    camera = p_camera
    config = p_config
    # the roots are set before anything that stands on them is drawn or casts its ray
    process_priority = -100

    var grips: Dictionary = {"left": p_left_grip, "right": p_right_grip}
    var aims: Dictionary = {"left": p_left_aim, "right": p_right_aim}
    for side in SIDES:
        var hand: Hand = Hand.new()
        hand.side = side
        hand.side_sign = -1.0 if side == "left" else 1.0
        hand.grip_source = grips[side]
        hand.aim_source = aims[side]
        hand.grip_root = _make_root("%sGripCalibrated" % side.capitalize())
        hand.aim_root = _make_root("%sAimCalibrated" % side.capitalize())
        hands[side] = hand
    left_grip_root = hands["left"].grip_root
    right_grip_root = hands["right"].grip_root
    left_aim_root = hands["left"].aim_root
    right_aim_root = hands["right"].aim_root
    _load()

func _make_root(p_name: String) -> Node3D:
    var root: Node3D = Node3D.new()
    root.name = p_name
    root.visible = false
    xr_origin.add_child(root)
    return root

## The calibration panel: the mark on it the controllers are pointed at, and how far the panel reaches
## either side of its own centre (a ray that is not on the panel is not being pointed at the mark).
func set_aim_target(panel: Node3D, mark: Vector3, half_size: Vector2) -> void:
    _target_panel = panel
    _target_mark = mark
    _target_half_size = half_size

func _process(_delta: float) -> void:
    update_poses()

## One reading of the runtime's poses into the hands and the rays.
func update_poses() -> void:
    if xr_origin == null or camera == null:
        return
    _peak_eye_height = maxf(_peak_eye_height, camera.position.y)
    for side in SIDES:
        _update_hand(hands[side])

static func _tracked(source: Node3D) -> bool:
    return source != null and bool(source.call(&"get_has_tracking_data"))

func _update_hand(hand: Hand) -> void:
    var grip_ok: bool = _tracked(hand.grip_source)
    var aim_ok: bool = _tracked(hand.aim_source)
    hand.grip_root.visible = grip_ok or aim_ok
    hand.aim_root.visible = grip_ok or aim_ok
    if not grip_ok and not aim_ok:
        hand.seen = false
        _say_source(hand, "NO_POSITIONAL_POSE")
        return

    var grip: Transform3D = hand.grip_source.transform if grip_ok else Transform3D.IDENTITY
    var aim: Transform3D = hand.aim_source.transform if aim_ok else Transform3D.IDENTITY
    var moved: bool = _watch_position(hand, grip if grip_ok else aim)
    if grip_ok and aim_ok and moved and hand.position_tracked:
        hand.grip_to_aim = grip.affine_inverse() * aim
    # a pose the runtime is not giving is taken from the other by what was measured between them
    if not aim_ok:
        aim = grip * hand.grip_to_aim
    elif not grip_ok:
        grip = aim * hand.grip_to_aim.affine_inverse()

    if not hand.position_tracked:
        grip.origin = arm_model_origin(camera.transform, -aim.basis.z, hand.side_sign, stature())
        aim.origin = (Transform3D(grip.basis, grip.origin) * hand.grip_to_aim).origin

    var frame: Transform3D = frame_trim()
    hand.grip_root.transform = frame * grip
    hand.raw_aim = frame * aim
    hand.aim_root.transform = refined_aim(hand.raw_aim, hand.aim_direction)
    _say_source(hand, ("AIM" if aim_ok else "AIM_FROM_GRIP") if hand.position_tracked else "PLACED_FROM_HEAD")

# Whether the controller's place moved since the last reading, and the tally of how far it has turned
# with its place unchanged (in the room, or from the head: a runtime may hold it still or carry it with
# the head) against how far with its place moving.
func _watch_position(hand: Hand, pose: Transform3D) -> bool:
    var turn: Quaternion = pose.basis.get_rotation_quaternion()
    var from_head: Vector3 = pose.origin - camera.position
    if not hand.seen:
        hand.seen = true
        hand.last_origin = pose.origin
        hand.last_from_head = from_head
        hand.last_turn = turn
        return false
    var turned: float = hand.last_turn.angle_to(turn)
    var still: bool = pose.origin.is_equal_approx(hand.last_origin)
    var still_from_head: bool = from_head.is_equal_approx(hand.last_from_head)
    hand.turned_still = hand.turned_still + turned if still else 0.0
    hand.turned_still_from_head = hand.turned_still_from_head + turned if still_from_head else 0.0
    hand.turned_moving = 0.0 if (still or still_from_head) else hand.turned_moving + turned
    hand.last_origin = pose.origin
    hand.last_from_head = from_head
    hand.last_turn = turn

    var was: bool = hand.position_tracked
    if hand.turned_still > UNTRACKED_TURN_RAD or hand.turned_still_from_head > UNTRACKED_TURN_RAD:
        hand.position_tracked = false
    elif not hand.position_tracked and hand.turned_moving > UNTRACKED_TURN_RAD:
        hand.position_tracked = true
    if was != hand.position_tracked:
        print("ELI VR XR POSE: ", hand.side, " position tracked by the runtime=", hand.position_tracked)
    return not still and not still_from_head

func _say_source(hand: Hand, source: String) -> void:
    if source == hand.source:
        return
    hand.source = source
    print("ELI VR XR POINTER [", hand.side, "_hand]: ", source)

## Whether the runtime is tracking where this controller is (not only how it is turned).
func position_tracked(side: String) -> bool:
    return hands.has(side) and (hands[side] as Hand).position_tracked

## The player's stature: from the highest the eyes have stood over the floor, when the headset gives that.
func stature() -> float:
    if _peak_eye_height > ADULT_STATURE_M * 0.5:
        return _peak_eye_height / EYE_OF_STATURE
    return ADULT_STATURE_M

## Where a hand is when only the controller's direction is known: the shoulder below and beside the
## eyes, the upper arm hanging from it, the forearm and half the hand along what the controller points at.
static func arm_model_origin(head: Transform3D, pointing: Vector3, side_sign: float, p_stature: float) -> Vector3:
    var forward: Vector3 = -head.basis.z
    forward.y = 0.0
    forward = forward.normalized() if forward.length_squared() > 0.0 else Vector3.FORWARD
    var right: Vector3 = forward.cross(Vector3.UP)
    var shoulder: Vector3 = (
        head.origin
        + Vector3.DOWN * (EYE_OF_STATURE - SHOULDER_OF_STATURE) * p_stature
        + right * side_sign * SHOULDER_WIDTH_OF_STATURE * 0.5 * p_stature
    )
    var elbow: Vector3 = shoulder + Vector3.DOWN * UPPER_ARM_OF_STATURE * p_stature
    var along: Vector3 = pointing.normalized() if pointing.length_squared() > 0.0 else forward
    return elbow + along * (FOREARM_OF_STATURE + HAND_OF_STATURE * 0.5) * p_stature

## The trim of the controllers' tracking space, as one fixed transform of that space.
func frame_trim() -> Transform3D:
    return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), offset_m)

## The ray with this controller's refinement: the aim pose turned, in its own frame, so that its -Z is
## the direction the hand points along.
static func refined_aim(aim: Transform3D, direction: Vector3) -> Transform3D:
    return Transform3D(aim.basis * Basis(aim_turn(direction)), aim.origin)

static func aim_turn(direction: Vector3) -> Quaternion:
    var to: Vector3 = direction.normalized() if direction.length_squared() > 0.0 else Vector3.FORWARD
    if to.is_equal_approx(Vector3.FORWARD):
        return Quaternion.IDENTITY
    if to.is_equal_approx(Vector3.BACK):
        return Quaternion(Vector3.UP, PI)
    return Quaternion(Vector3.FORWARD, to)

## The direction, in the aim pose's own frame, that makes its ray pass through the target.
static func aim_direction_to(aim: Transform3D, target: Vector3) -> Vector3:
    return (aim.basis.orthonormalized().inverse() * (target - aim.origin)).normalized()

## Where a ray meets the panel's own plane, in the panel's frame; INF when it does not.
static func ray_on_plane(ray: Transform3D, panel: Transform3D) -> Vector3:
    var local: Transform3D = panel.affine_inverse() * ray
    var direction: Vector3 = -local.basis.z
    if is_zero_approx(direction.z):
        return Vector3.INF
    var reach: float = -local.origin.z / direction.z
    if reach <= 0.0:
        return Vector3.INF
    return local.origin + direction * reach

## The recalibration: each tracked controller that is pointed at the calibration panel has its ray
## brought onto the panel's mark. A controller that is not pointed at the panel is left as it was.
func calibrate_hands() -> bool:
    update_poses()
    problem = ""
    var any_tracked: bool = false
    var solved: Array[Hand] = []
    if _target_panel != null and xr_origin != null:
        var panel: Transform3D = xr_origin.global_transform.affine_inverse() * _target_panel.global_transform
        var target: Vector3 = panel * _target_mark
        for side in SIDES:
            var hand: Hand = hands[side]
            if not hand.aim_root.visible:
                continue
            any_tracked = true
            var met: Vector3 = ray_on_plane(hand.raw_aim, panel)
            if met == Vector3.INF or absf(met.x) > _target_half_size.x or absf(met.y) > _target_half_size.y:
                continue
            hand.aim_direction = aim_direction_to(hand.raw_aim, target)
            solved.append(hand)
    if solved.is_empty():
        problem = "off_mark" if any_tracked else "untracked"
        return false

    update_poses()
    _save()
    calibrated.emit(offset_m, yaw_deg)
    for hand in solved:
        _pulse(hand)
        print("ELI VR XR CALIBRATION: ", hand.side, " pointer turned ",
            snappedf(rad_to_deg(Vector3.FORWARD.angle_to(hand.aim_direction)), 0.1), " deg onto the mark")
    return true

func _pulse(hand: Hand) -> void:
    for source in [hand.grip_source, hand.aim_source]:
        if source != null and source.has_method(&"trigger_haptic_pulse"):
            source.call(&"trigger_haptic_pulse", "haptic", 0.0, 0.55, 0.08, 0.0)
            return

func nudge(delta_m: Vector3) -> void:
    offset_m += delta_m
    _save()
    calibrated.emit(offset_m, yaw_deg)

## Turns the controllers' space about the head where it is now; the turn is folded into the fixed
## transform, so the hands do not slide afterwards when the head moves.
func nudge_yaw(delta_deg: float) -> void:
    var turn: Basis = Basis(Vector3.UP, deg_to_rad(delta_deg))
    var pivot: Vector3 = camera.position if camera != null else Vector3.ZERO
    offset_m = pivot + turn * (offset_m - pivot)
    yaw_deg = wrapf(yaw_deg + delta_deg, -180.0, 180.0)
    _save()
    calibrated.emit(offset_m, yaw_deg)

func reset_calibration() -> void:
    offset_m = Vector3.ZERO
    yaw_deg = 0.0
    for side in SIDES:
        (hands[side] as Hand).aim_direction = Vector3.FORWARD
    _save()
    calibration_reset.emit()
    print("ELI VR XR CALIBRATION: reset")

func recenter_view() -> void:
    # Recenter the HMD/reference frame separately from hand correction.
    XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, true)
    print("ELI VR XR CALIBRATION: view recentered")

func offset_centimeters() -> Vector3:
    return offset_m * 100.0

func _load() -> void:
    offset_m = _vector(config.get_value("%s.frame.offset_m" % SETTINGS, null), Vector3.ZERO)
    yaw_deg = float(config.get_value("%s.frame.yaw_deg" % SETTINGS, 0.0))
    for side in SIDES:
        var kept: Vector3 = _vector(config.get_value("%s.aim.%s" % [SETTINGS, side], null), Vector3.FORWARD)
        (hands[side] as Hand).aim_direction = kept.normalized() if kept.length_squared() > 0.0 else Vector3.FORWARD
    var retired: bool = false
    for key in RETIRED_SETTINGS:
        if config.get_value("%s.%s" % [SETTINGS, key], null) != null:
            config.remove_value("%s.%s" % [SETTINGS, key])
            retired = true
    if retired:
        config.save_runtime()

static func _vector(value: Variant, fallback: Vector3) -> Vector3:
    if value is Array and (value as Array).size() == 3:
        return Vector3(float(value[0]), float(value[1]), float(value[2]))
    return fallback

func _save() -> void:
    config.set_value("%s.frame.offset_m" % SETTINGS, [offset_m.x, offset_m.y, offset_m.z])
    config.set_value("%s.frame.yaw_deg" % SETTINGS, yaw_deg)
    for side in SIDES:
        var direction: Vector3 = (hands[side] as Hand).aim_direction
        config.set_value("%s.aim.%s" % [SETTINGS, side], [direction.x, direction.y, direction.z])
    config.save_runtime()
