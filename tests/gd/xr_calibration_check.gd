extends SceneTree

# The hands and the pointer rays from simulated controller poses, headless, with the real calibration
# manager, pointer, hand and panel. One line per check: "PASS name" or "FAIL name: what happened".
# tests/test_xr_controls.py runs it.

const CalibrationClass = preload("res://scripts/xr/controller_calibration.gd")
const CalibrationWidgetClass = preload("res://scripts/xr/calibration_widget.gd")
const PointerClass = preload("res://scripts/xr/xr_pointer.gd")
const ManipulatorClass = preload("res://scripts/xr/world_manipulator.gd")
const HandClass = preload("res://scripts/xr/frontier_hand.gd")
const AppConfigClass = preload("res://scripts/core/app_config.gd")

## Single-precision poses through a chain of a few transforms at room scale.
const FLOAT_EPS: float = 1.1920929e-07
const CHAIN: float = 256.0

# Stands in for a tracked controller pose: where it is put, tracked or not.
class FakePose extends Node3D:
    var tracked := true
    var pulses := 0
    func get_has_tracking_data() -> bool:
        return tracked
    func trigger_haptic_pulse(_action, _frequency, _amplitude, _seconds, _delay) -> void:
        pulses += 1

var _failed := 0

func _check(name: String, ok: bool, what: String) -> void:
    if ok:
        print("PASS ", name)
    else:
        _failed += 1
        print("FAIL ", name, ": ", what)

func _near(a: Vector3, b: Vector3) -> bool:
    return a.distance_to(b) <= FLOAT_EPS * CHAIN * maxf(1.0, maxf(a.length(), b.length()))

func _same(a: Transform3D, b: Transform3D) -> bool:
    return (_near(a.origin, b.origin) and _near(a.basis.x, b.basis.x) and _near(a.basis.y, b.basis.y)
            and _near(a.basis.z, b.basis.z))

# A rig: an origin that has walked and turned, a head, and each hand's grip and aim poses, the aim
# pose turned and shifted from the grip as a controller's is.
class Rig extends RefCounted:
    var origin: Node3D
    var head: Node3D
    var grip := {}
    var aim := {}
    var manager
    var config

func _grip_basis(tilt_deg: float, yaw_deg: float) -> Basis:
    # a controller held as it is: +X to the right, the fist's tube (-Z) up and forward by tilt
    return Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Basis(Vector3.RIGHT, deg_to_rad(tilt_deg))

func _place(rig: Rig, side: String, at: Vector3, tilt_deg: float, yaw_deg: float) -> void:
    var grip := Transform3D(_grip_basis(tilt_deg, yaw_deg), at)
    # the ray leaves ahead of and above the palm, along the tube turned back down to level
    var in_grip := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-tilt_deg)), Vector3(0.0, -0.03, -0.06))
    rig.grip[side].transform = grip
    rig.aim[side].transform = grip * in_grip

func _rig(config = null) -> Rig:
    var rig := Rig.new()
    rig.origin = Node3D.new()
    root.add_child(rig.origin)
    rig.origin.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(40.0)), Vector3(3.0, 0.5, -2.0))
    rig.head = Node3D.new()
    rig.origin.add_child(rig.head)
    rig.head.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(-15.0)), Vector3(0.2, 1.62, 0.1))
    for side in ["left", "right"]:
        rig.grip[side] = FakePose.new()
        rig.aim[side] = FakePose.new()
        rig.origin.add_child(rig.grip[side])
        rig.origin.add_child(rig.aim[side])
    _place(rig, "left", Vector3(-0.05, 1.18, -0.28), 48.0, -8.0)
    _place(rig, "right", Vector3(0.42, 1.25, -0.22), 52.0, -21.0)
    rig.config = config if config != null else AppConfigClass.new()
    rig.manager = CalibrationClass.new()
    rig.manager.setup(rig.origin, rig.head, rig.grip["left"], rig.grip["right"], rig.aim["left"], rig.aim["right"], rig.config)
    root.add_child(rig.manager)
    rig.manager.update_poses()
    return rig

func _drop(rig: Rig) -> void:
    rig.manager.queue_free()
    rig.origin.queue_free()

func _initialize() -> void:
    _run.call_deferred()

func _run() -> void:
    await process_frame
    await _ray_and_hands()
    await _recalibration()
    _kept_and_loaded()
    _trim()
    _untracked()
    print("XR CALIBRATION CHECKS DONE failed=", _failed)
    quit(1 if _failed > 0 else 0)

# With no calibration at all the ray is the aim pose and the hand is the grip pose, wherever the
# player has walked and turned to, and after a room change.
func _ray_and_hands() -> void:
    var rig := _rig()
    var m = rig.manager
    var pointers := {}
    var grabbers := {}
    for side in ["left", "right"]:
        var controller := XRController3D.new()
        rig.origin.add_child(controller)
        var pointer = PointerClass.new()
        pointer.setup(controller, m.hands[side].aim_root)
        rig.origin.add_child(pointer)
        pointers[side] = pointer
        var grabber = ManipulatorClass.new()
        grabber.setup(controller, m.hands[side].aim_root)
        root.add_child(grabber)
        grabbers[side] = grabber
    await physics_frame
    await physics_frame
    var on_aim := true
    var said := ""
    for side in ["left", "right"]:
        var want: Transform3D = rig.origin.global_transform * rig.aim[side].transform
        var got: Transform3D = pointers[side].global_transform
        var beam: MeshInstance3D = pointers[side].beam
        var ok: bool = _same(got, want) and beam.visible and grabbers[side].pose == m.hands[side].aim_root
        on_aim = on_aim and ok
        said += "%s ray %s wants %s; " % [side, got, want]
    _check("with_no_calibration_the_ray_leaves_the_aim_pose_along_where_the_controller_points", on_aim, said)

    var on_grip := true
    said = ""
    for side in ["left", "right"]:
        on_grip = on_grip and _same(m.hands[side].grip_root.transform, rig.grip[side].transform)
        said += "%s hand %s wants %s; " % [side, m.hands[side].grip_root.transform, rig.grip[side].transform]
    _check("with_no_calibration_the_hand_is_at_the_grip_pose", on_grip, said)

    # the hand model on the grip pose: its back away from the palm, its thumb up the tube, the fingers'
    # tube round the grip's origin, and the two hands mirror images
    var held := true
    said = ""
    for side in ["left", "right"]:
        var hand = HandClass.new()
        hand.setup(null, side, Color.WHITE)
        m.hands[side].grip_root.add_child(hand)
        var grip: Transform3D = rig.grip[side].transform
        var in_origin: Transform3D = m.hands[side].grip_root.transform * hand.transform
        var thumb: float = HandClass.thumb_side(side)
        var back: Vector3 = in_origin.basis.y
        var palm_out: Vector3 = grip.basis.x * (1.0 if side == "left" else -1.0)
        var to_thumb: Vector3 = in_origin.basis.x * thumb
        var fingers: Vector3 = -in_origin.basis.z
        var ok: bool = (_near(back, -palm_out) and _near(to_thumb, -grip.basis.z)
                        and _near(in_origin * HandClass.tube_centre(), grip.origin)
                        and fingers.dot(grip.basis.y) < 0.0
                        and is_equal_approx(in_origin.basis.determinant(), 1.0)
                        and signf(hand.finger_roots[0].position.x) == thumb)
        held = held and ok
        said += "%s back %s palm-out %s thumb %s tube %s fingers %s; " % [side, back, palm_out, to_thumb, -grip.basis.z, fingers]
    var mirrored: bool = _near(HandClass.on_grip("left").basis.y, -HandClass.on_grip("right").basis.y)
    _check("the_hand_stands_on_the_grip_pose_as_a_hand_holds_a_controller", held and mirrored, said + "mirrored %s" % mirrored)

    # walking, turning and a room change move the origin: hands and rays go with it
    rig.origin.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(-130.0)), Vector3(-40.0, 2.0, 17.0))
    _place(rig, "left", Vector3(-0.3, 0.9, -0.4), 30.0, 70.0)
    _place(rig, "right", Vector3(0.1, 1.6, -0.5), 85.0, -100.0)
    m.update_poses()
    await physics_frame
    await physics_frame
    var carried := true
    said = ""
    for side in ["left", "right"]:
        var want: Transform3D = rig.origin.global_transform * rig.aim[side].transform
        var ok: bool = (_same(pointers[side].global_transform, want)
                        and _same(m.hands[side].grip_root.global_transform, rig.origin.global_transform * rig.grip[side].transform))
        carried = carried and ok
        said += "%s ray %s wants %s; " % [side, pointers[side].global_transform, want]
    _check("walking_turning_and_a_room_change_carry_the_hands_and_the_rays", carried, said)

    # a controller the runtime is not tracking has no ray; one with only its grip pose keeps its ray
    # from what was measured between the two poses
    rig.grip["left"].tracked = false
    rig.aim["left"].tracked = false
    rig.aim["right"].tracked = false
    var before: Transform3D = rig.aim["right"].transform
    m.update_poses()
    await physics_frame
    await physics_frame
    var gone: bool = not pointers["left"].beam.visible and not m.hands["left"].grip_root.visible
    var from_grip: bool = pointers["right"].beam.visible and _same(m.hands["right"].aim_root.transform, before)
    _check("a_controller_not_tracked_has_no_ray_and_one_with_only_its_grip_keeps_its_ray", gone and from_grip,
           "left gone %s; right from grip %s: %s wants %s" % [gone, from_grip, m.hands["right"].aim_root.transform, before])
    for side in ["left", "right"]:
        grabbers[side].queue_free()
    _drop(rig)

# The recalibration: the controllers are pointed at the panel's mark; each ray is brought onto it, in
# the controller's own frame, and the hands stay where the controllers are.
func _recalibration() -> void:
    var rig := _rig()
    var m = rig.manager
    var widget = CalibrationWidgetClass.new()
    widget.setup(m, null, null, null, Color("#63ddff"))
    rig.head.add_child(widget)
    await process_frame
    var panel: Transform3D = rig.head.transform * widget.transform
    var mark: Vector3 = panel * CalibrationWidgetClass.MARK_AT

    # each hand points near the mark, off it by a different amount
    var off := {"left": Vector3(0.11, -0.07, 0.0), "right": Vector3(-0.2, 0.16, 0.0)}
    for side in ["left", "right"]:
        var from: Vector3 = rig.aim[side].position
        var aim := Transform3D(Basis.looking_at(panel * (CalibrationWidgetClass.MARK_AT + off[side]) - from, Vector3.UP), from)
        rig.aim[side].transform = aim
        rig.grip[side].transform = aim * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(50.0)), Vector3(0.0, -0.02, 0.07))
    m.update_poses()
    var hands_before := {"left": m.hands["left"].grip_root.transform, "right": m.hands["right"].grip_root.transform}
    var done: bool = m.calibrate_hands()
    var on_mark := true
    var hands_stay := true
    var said := ""
    for side in ["left", "right"]:
        var ray: Transform3D = m.hands[side].aim_root.transform
        var along: Vector3 = -ray.basis.z
        var nearest: Vector3 = ray.origin + along * (mark - ray.origin).dot(along)
        on_mark = on_mark and _near(nearest, mark) and _near(ray.origin, rig.aim[side].position)
        hands_stay = hands_stay and _same(m.hands[side].grip_root.transform, hands_before[side]) \
            and _same(m.hands[side].grip_root.transform, rig.grip[side].transform)
        said += "%s ray passes %s of mark %s, hand %s was %s; " % [side, nearest, mark, m.hands[side].grip_root.transform.origin,
            hands_before[side].origin]
    var pulsed: bool = rig.grip["left"].pulses == 1 and rig.grip["right"].pulses == 1
    _check("recalibrating_brings_each_ray_onto_the_mark_and_leaves_the_hands_on_the_controllers",
           done and on_mark and hands_stay and pulsed, "done %s pulsed %s; %s" % [done, pulsed, said])

    # the turn is the controller's own: it is the same turn wherever the hand goes afterwards
    var turns := {}
    for side in ["left", "right"]:
        turns[side] = rig.aim[side].transform.basis.inverse() * m.hands[side].aim_root.transform.basis
    _place(rig, "left", Vector3(-0.6, 0.7, 0.3), 20.0, 140.0)
    _place(rig, "right", Vector3(0.5, 1.9, -0.1), 95.0, -60.0)
    m.update_poses()
    var own := true
    for side in ["left", "right"]:
        var now: Basis = rig.aim[side].transform.basis.inverse() * m.hands[side].aim_root.transform.basis
        own = own and _near(now.x, turns[side].x) and _near(now.y, turns[side].y) and _near(now.z, turns[side].z) \
            and _near(m.hands[side].aim_root.position, rig.aim[side].position)
    var differ: bool = not m.hands["left"].aim_direction.is_equal_approx(m.hands["right"].aim_direction)
    _check("the_pointers_turn_is_each_controllers_own_and_goes_with_the_hand", own and differ,
           "own %s; left %s right %s" % [own, m.hands["left"].aim_direction, m.hands["right"].aim_direction])

    # a controller that is not pointed at the panel is left as it was; with neither on it nothing is
    # taken and it says so; with neither tracked it says that
    var left_kept: Vector3 = m.hands["left"].aim_direction
    var right_kept: Vector3 = m.hands["right"].aim_direction
    rig.aim["right"].transform = Transform3D(Basis.looking_at(mark - rig.aim["right"].position, Vector3.UP), rig.aim["right"].position)
    m.update_poses()
    var one: bool = m.calibrate_hands()
    var one_only: bool = (one and m.hands["left"].aim_direction == left_kept
                          and m.hands["right"].aim_direction.is_equal_approx(Vector3.FORWARD))
    _place(rig, "right", Vector3(0.5, 1.9, -0.1), 95.0, -60.0)
    m.update_poses()
    var none: bool = not m.calibrate_hands() and m.problem == "off_mark" \
        and m.hands["left"].aim_direction == left_kept and m.hands["right"].aim_direction.is_equal_approx(Vector3.FORWARD)
    for side in ["left", "right"]:
        rig.grip[side].tracked = false
        rig.aim[side].tracked = false
    var untracked: bool = not m.calibrate_hands() and m.problem == "untracked"
    _check("a_controller_not_pointed_at_the_panel_is_left_as_it_was_and_it_says_why_nothing_was_taken",
           one_only and none and untracked, "one %s (right was %s, is %s) none %s (%s) untracked %s" % [one_only, right_kept,
           m.hands["right"].aim_direction, none, m.problem, untracked])
    _drop(rig)

# What the recalibration found is kept per controller and comes back the same; what the old
# calibration saved (a guess at where the hands were) is dropped, not applied.
func _kept_and_loaded() -> void:
    var config = AppConfigClass.new()
    config.set_value("xr.controller_calibration.offset_x_m", -0.3)
    config.set_value("xr.controller_calibration.offset_y_m", -0.275)
    config.set_value("xr.controller_calibration.offset_z_m", -0.09)
    config.set_value("xr.controller_calibration.yaw_deg", 0.0)
    config.set_value("xr.controller_calibration.target_forward_m", 0.42)
    config.set_value("xr.controller_calibration.target_down_m", 0.3)
    var rig := _rig(config)
    var m = rig.manager
    var old_gone: bool = (config.get_value("xr.controller_calibration.offset_x_m") == null
                          and config.get_value("xr.controller_calibration.target_forward_m") == null
                          and _same(m.hands["left"].grip_root.transform, rig.grip["left"].transform)
                          and _same(m.hands["right"].aim_root.transform, rig.aim["right"].transform))
    _check("what_the_old_calibration_saved_is_dropped_and_moves_nothing", old_gone,
           "settings %s; left hand %s wants %s" % [config.get_value("xr.controller_calibration"),
           m.hands["left"].grip_root.transform.origin, rig.grip["left"].position])

    m.hands["left"].aim_direction = Vector3(0.05, -0.12, -1.0).normalized()
    m.hands["right"].aim_direction = Vector3(-0.2, 0.03, -1.0).normalized()
    m.nudge(Vector3(0.02, -0.04, 0.06))
    m.nudge_yaw(6.0)
    m.update_poses()
    var again := _rig(config)
    var same := true
    var said := ""
    for side in ["left", "right"]:
        same = same and _same(again.manager.hands[side].aim_root.transform, m.hands[side].aim_root.transform) \
            and _same(again.manager.hands[side].grip_root.transform, m.hands[side].grip_root.transform)
        said += "%s ray %s was %s; " % [side, again.manager.hands[side].aim_root.transform, m.hands[side].aim_root.transform]
    var per_hand: bool = (config.get_value("xr.controller_calibration.aim.left") is Array
                          and config.get_value("xr.controller_calibration.aim.right") is Array
                          and config.get_value("xr.controller_calibration.aim.left") != config.get_value("xr.controller_calibration.aim.right"))
    var moved: bool = not _same(m.hands["left"].aim_root.transform, rig.aim["left"].transform)
    _check("the_calibration_is_kept_per_controller_and_comes_back_the_same", same and per_hand and moved,
           "same %s per hand %s moved %s; %s" % [same, per_hand, moved, said])

    again.manager.reset_calibration()
    again.manager.update_poses()
    var plain: bool = (_same(again.manager.hands["left"].aim_root.transform, again.aim["left"].transform)
                       and _same(again.manager.hands["right"].grip_root.transform, again.grip["right"].transform))
    _check("a_reset_puts_hands_and_rays_back_on_the_runtimes_poses", plain, "left ray %s wants %s" % [
           again.manager.hands["left"].aim_root.transform, again.aim["left"].transform])
    _drop(rig)
    _drop(again)

# The trim by hand turns the controllers' space about the head where it is, and is then fixed: the
# hands do not slide when the head moves.
func _trim() -> void:
    var rig := _rig()
    var m = rig.manager
    var head_at: Vector3 = rig.head.position
    var raw: Vector3 = rig.grip["left"].position
    m.nudge_yaw(12.0)
    m.update_poses()
    var turned: Vector3 = m.hands["left"].grip_root.position
    var about_head: bool = _near(turned, head_at + Basis(Vector3.UP, deg_to_rad(12.0)) * (raw - head_at))
    rig.head.position += Vector3(0.35, -0.1, 0.25)
    m.update_poses()
    var fixed: bool = _near(m.hands["left"].grip_root.position, turned)
    m.nudge(Vector3(0.02, 0.0, 0.0))
    m.update_poses()
    var shifted: bool = _near(m.hands["left"].grip_root.position, turned + Vector3(0.02, 0.0, 0.0))
    _check("the_trim_turns_about_the_head_where_it_is_and_then_holds_when_the_head_moves", about_head and fixed and shifted,
           "about head %s, fixed %s (%s was %s), shifted %s" % [about_head, fixed, m.hands["left"].grip_root.position, turned, shifted])
    _drop(rig)

# A controller whose place does not change while it turns is not tracked in position: its hand is
# placed from the head and the controller's direction until its place moves again.
func _untracked() -> void:
    var rig := _rig()
    var m = rig.manager
    var step: float = CalibrationClass.UNTRACKED_TURN_RAD / 8.0
    var turns: int = 10

    # tracked: it turns and moves; a still one does not turn: neither is ever placed from the head
    for i in range(turns * 3):
        var grip: Transform3D = rig.grip["left"].transform
        rig.grip["left"].transform = Transform3D(grip.basis * Basis(Vector3.RIGHT, step), grip.origin + Vector3(0.002, 0.001, -0.001))
        rig.aim["left"].transform = Transform3D(rig.aim["left"].transform.basis * Basis(Vector3.RIGHT, step),
            rig.aim["left"].position + Vector3(0.002, 0.001, -0.001))
        m.update_poses()
    var stays: bool = (m.position_tracked("left") and m.position_tracked("right")
                       and _same(m.hands["left"].grip_root.transform, rig.grip["left"].transform)
                       and _same(m.hands["right"].grip_root.transform, rig.grip["right"].transform))
    _check("a_tracked_controller_turning_and_a_still_one_stay_on_the_runtimes_poses", stays,
           "left tracked %s right tracked %s" % [m.position_tracked("left"), m.position_tracked("right")])

    # the right one's place freezes where the runtime last had it (far from the hand) while it turns
    rig.grip["right"].position = rig.head.position + Vector3(0.69, -0.02, -0.07)
    rig.aim["right"].position = rig.grip["right"].position
    for i in range(turns):
        rig.grip["right"].transform = Transform3D(rig.grip["right"].transform.basis * Basis(Vector3.UP, step), rig.grip["right"].position)
        rig.aim["right"].transform = Transform3D(rig.aim["right"].transform.basis * Basis(Vector3.UP, step), rig.aim["right"].position)
        m.update_poses()
    var pointing: Vector3 = -rig.aim["right"].transform.basis.z
    var want: Vector3 = CalibrationClass.arm_model_origin(rig.head.transform, pointing, 1.0, m.stature())
    var hand: Vector3 = m.hands["right"].grip_root.position
    var head_right: Vector3 = (-rig.head.transform.basis.z).cross(Vector3.UP).normalized()
    var from_head: Vector3 = hand - rig.head.position
    var arm: float = m.stature() * (CalibrationClass.UPPER_ARM_OF_STATURE + CalibrationClass.FOREARM_OF_STATURE
                                    + CalibrationClass.HAND_OF_STATURE)
    var placed: bool = (not m.position_tracked("right") and _near(hand, want)
                        and from_head.dot(head_right) > 0.0 and from_head.length() < arm
                        and _near(-m.hands["right"].aim_root.transform.basis.z, pointing)
                        and is_equal_approx(m.stature(), rig.head.position.y / CalibrationClass.EYE_OF_STATURE))
    _check("a_controller_whose_place_does_not_move_while_it_turns_is_placed_from_the_head", placed,
           "tracked %s hand %s wants %s, %s from the head (arm %s)" % [m.position_tracked("right"), hand, want, from_head, arm])

    # carried with the head by the runtime (its place from the head never changes) is the same thing
    for i in range(turns):
        rig.head.position += Vector3(0.01, 0.0, 0.004)
        var at: Vector3 = rig.head.position + Vector3(-0.2, 0.1, -0.3)
        rig.grip["left"].transform = Transform3D(rig.grip["left"].transform.basis * Basis(Vector3.FORWARD, step), at)
        rig.aim["left"].transform = Transform3D(rig.aim["left"].transform.basis * Basis(Vector3.FORWARD, step), at)
        m.update_poses()
    var carried: bool = not m.position_tracked("left") and _near(m.hands["left"].grip_root.position,
        CalibrationClass.arm_model_origin(rig.head.transform, -rig.aim["left"].transform.basis.z, -1.0, m.stature()))
    # the placed hand goes with the head
    var was: Vector3 = m.hands["right"].grip_root.position
    rig.head.position += Vector3(0.3, 0.0, -0.2)
    m.update_poses()
    var follows: bool = _near(m.hands["right"].grip_root.position, was + Vector3(0.3, 0.0, -0.2))
    _check("a_hand_placed_from_the_head_goes_with_the_head_whether_its_place_was_held_or_carried", carried and follows,
           "carried %s follows %s" % [carried, follows])

    # its place moves again while it turns: back on the runtime's pose
    for i in range(turns):
        var at: Vector3 = rig.grip["right"].position + Vector3(-0.003, 0.002, 0.001)
        rig.grip["right"].transform = Transform3D(rig.grip["right"].transform.basis * Basis(Vector3.UP, step), at)
        rig.aim["right"].transform = Transform3D(rig.aim["right"].transform.basis * Basis(Vector3.UP, step), at)
        m.update_poses()
    var back: bool = m.position_tracked("right") and _same(m.hands["right"].grip_root.transform, rig.grip["right"].transform)
    _check("when_its_place_moves_again_the_hand_is_back_on_the_runtimes_pose", back,
           "tracked %s hand %s wants %s" % [m.position_tracked("right"), m.hands["right"].grip_root.position, rig.grip["right"].position])
    _drop(rig)
