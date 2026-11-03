class_name XRWorldManipulator
extends Node

var controller: XRController3D
var aim_tracking: XRController3D
var fallback_tracking: XRController3D
var aim_pose: Node3D
var fallback_pose: Node3D
var pointer_origin: Node3D
var grabbed: Node3D
var grab_distance: float = 2.0
var grip_before: bool = false

# The grip is held while the squeeze is down. The runtime's own grip "click" can be a press of a
# single frame (Monado with Rift CV1 controllers), which let go of the desktop the moment it was
# taken; so the squeeze's own value is read, taking hold past HOLD and letting go below LET_GO.
const HOLD := 0.6
const LET_GO := 0.35

const MAX_GRAB_DISTANCE := 90.0

## Which controllers are holding something now, so walking and turning leave their stick alone.
static var _holding := {}

static func is_holding(hand: XRController3D) -> bool:
    return hand != null and bool(_holding.get(hand.get_instance_id(), false))

func setup(
    p_controller: XRController3D,
    p_aim_tracking: XRController3D,
    p_fallback_tracking: XRController3D,
    p_aim_pose: Node3D,
    p_fallback_pose: Node3D,
    p_pointer_origin: Node3D
) -> void:
    controller = p_controller
    aim_tracking = p_aim_tracking
    fallback_tracking = p_fallback_tracking
    aim_pose = p_aim_pose
    fallback_pose = p_fallback_pose
    pointer_origin = p_pointer_origin

func _physics_process(delta: float) -> void:
    if controller == null:
        return

    var squeeze: float = controller.get_float("grip")
    var grip_now: bool = squeeze > (LET_GO if grip_before else HOLD) or (
        controller.is_button_pressed("grip_click") and squeeze <= 0.0)       # a controller with no squeeze value
    if grip_now and not grip_before:
        _try_begin_grab()
    elif not grip_now and grip_before:
        _release()

    if grabbed and grip_now:
        var pose: Node3D = _pose_node()
        if pose:
            var origin: Vector3 = pointer_origin.global_position if pointer_origin else pose.global_position
            var direction: Vector3 = -pose.global_transform.basis.z.normalized()
            var stick: Vector2 = controller.get_vector2("primary")
            if grabbed.has_method("hold"):
                grabbed.hold(origin, direction, stick, delta)
                grip_before = grip_now
                _holding[controller.get_instance_id()] = true
                return

            grab_distance = clampf(
                grab_distance - stick.y * delta * 8.0,
                0.45,
                MAX_GRAB_DISTANCE
            )
            var target: Vector3 = origin + direction * grab_distance
            grabbed.global_position = grabbed.global_position.lerp(
                target,
                clampf(delta * 12.0, 0.0, 1.0)
            )

            if absf(stick.x) > 0.12:
                grabbed.rotate_y(-stick.x * delta * 1.8)

    grip_before = grip_now
    _holding[controller.get_instance_id()] = grabbed != null and grip_now

func _try_begin_grab() -> void:
    var pose: Node3D = _pose_node()
    if pose == null:
        return

    var origin: Vector3 = pointer_origin.global_position if pointer_origin else pose.global_position
    var direction: Vector3 = -pose.global_transform.basis.z.normalized()
    var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
        origin,
        origin + direction * MAX_GRAB_DISTANCE
    )
    query.collision_mask = 4
    query.collide_with_areas = true
    query.collide_with_bodies = false

    var hit: Dictionary = get_viewport().get_world_3d().direct_space_state.intersect_ray(query)
    # the desktop has no collider: it is asked where the ray meets it, and taken if that is nearer
    for desktop in get_tree().get_nodes_in_group("eli_desktop"):
        var meets: Dictionary = desktop.ray_hit(origin, direction)
        if not meets.is_empty() and (not hit.has("position") or float(meets["distance"]) < origin.distance_to(hit["position"])):
            grabbed = desktop
            desktop.begin_hold(origin, direction)
            controller.trigger_haptic_pulse("haptic", 0.0, 0.45, 0.06, 0.0)
            print("ELI VR WORLD GRAB: ", desktop.name)
            return
    if not hit.has("collider"):
        return

    var candidate = hit["collider"]
    if candidate == null or not (candidate is Node3D):
        return

    grabbed = candidate as Node3D
    grab_distance = clampf(
        origin.distance_to(grabbed.global_position),
        0.45,
        MAX_GRAB_DISTANCE
    )
    if grabbed.has_method("begin_grab"):
        grabbed.begin_grab()
    controller.trigger_haptic_pulse("haptic", 0.0, 0.45, 0.06, 0.0)
    print("ELI VR WORLD GRAB: ", grabbed.name)

func _release() -> void:
    if grabbed and grabbed.has_method("end_hold"):
        grabbed.end_hold()
    elif grabbed and grabbed.has_method("end_grab"):
        grabbed.end_grab()
    if grabbed:
        controller.trigger_haptic_pulse("haptic", 0.0, 0.22, 0.035, 0.0)
    grabbed = null

func _pose_node() -> Node3D:
    if aim_tracking and aim_tracking.get_has_tracking_data():
        return aim_pose
    if fallback_tracking and fallback_tracking.get_has_tracking_data():
        return fallback_pose
    return null
