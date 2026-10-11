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

const MAX_GRAB_DISTANCE := 90.0

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

    var grip_now: bool = controller.is_button_pressed("grip_click")
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
    if grabbed and grabbed.has_method("end_grab"):
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
