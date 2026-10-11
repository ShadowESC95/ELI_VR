class_name XRPointer
extends Node3D

var controller: XRController3D
var aim_tracking: XRController3D
var fallback_tracking: XRController3D
var aim_pose: Node3D
var fallback_pose: Node3D
var origin_marker: Node3D
var current
var trigger_before: bool = false

var beam: MeshInstance3D
var beam_material: StandardMaterial3D
var reticle: MeshInstance3D
var reticle_material: StandardMaterial3D
var status_logged: String = ""

const RAY_LENGTH := 20.0
const RAY_RADIUS := 0.0018

func setup(
    p_controller: XRController3D,
    p_aim_tracking: XRController3D,
    p_fallback_tracking: XRController3D,
    p_aim_pose: Node3D,
    p_fallback_pose: Node3D,
    p_origin_marker: Node3D = null
) -> void:
    controller = p_controller
    aim_tracking = p_aim_tracking
    fallback_tracking = p_fallback_tracking
    aim_pose = p_aim_pose
    fallback_pose = p_fallback_pose
    origin_marker = p_origin_marker
    _build_visuals()

func _build_visuals() -> void:
    beam = MeshInstance3D.new()
    beam.name = "PointerBeam"
    var mesh := CylinderMesh.new()
    mesh.top_radius = RAY_RADIUS
    mesh.bottom_radius = RAY_RADIUS
    mesh.height = RAY_LENGTH
    beam.mesh = mesh
    beam.rotation_degrees.x = 90.0
    beam.position = Vector3(0.0, 0.0, -RAY_LENGTH * 0.5)

    beam_material = StandardMaterial3D.new()
    beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    beam_material.albedo_color = Color(0.83, 0.95, 1.0, 0.82)
    beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    beam.material_override = beam_material
    add_child(beam)

    reticle = MeshInstance3D.new()
    reticle.name = "PointerHit"
    var dot := SphereMesh.new()
    dot.radius = 0.011
    dot.height = 0.022
    reticle.mesh = dot
    reticle_material = StandardMaterial3D.new()
    reticle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    reticle_material.albedo_color = Color(0.92, 0.98, 1.0, 1.0)
    reticle.material_override = reticle_material
    add_child(reticle)

    beam.visible = false
    reticle.visible = false

func _physics_process(_delta: float) -> void:
    if controller == null:
        _hide_visuals()
        _set_current(null)
        return

    var pose_node: Node3D = _select_pose_node()
    if pose_node == null:
        _hide_visuals()
        _set_current(null)
        _log_status_once("NO_POSITIONAL_POSE")
        _update_trigger_latch()
        return

    _log_status_once("AIM" if pose_node == aim_pose else "GRIP_FALLBACK")

    var origin: Vector3 = origin_marker.global_position if origin_marker else pose_node.global_position
    global_transform = Transform3D(pose_node.global_transform.basis, origin)
    beam.visible = true

    var direction: Vector3 = -global_transform.basis.z.normalized()
    var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
        origin,
        origin + direction * RAY_LENGTH
    )
    query.collision_mask = 2
    query.collide_with_areas = true
    query.collide_with_bodies = false

    var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
    var target = null
    var hit_distance: float = RAY_LENGTH

    if hit.has("position"):
        hit_distance = origin.distance_to(hit["position"])
        reticle.visible = true
        reticle.position = Vector3(0.0, 0.0, -hit_distance)
    else:
        reticle.visible = false

    if hit.has("collider"):
        var collider = hit["collider"]
        if (
            collider != null
            and collider.has_method("activate")
            and collider.has_method("set_highlighted")
        ):
            target = collider

    _set_current(target)
    _set_beam_length(maxf(0.05, hit_distance))
    _set_visual_state(target != null)

    var pressed: bool = controller.is_button_pressed("trigger_click")
    if pressed and not trigger_before and current:
        current.activate()
        controller.trigger_haptic_pulse("haptic", 0.0, 0.30, 0.04, 0.0)
    trigger_before = pressed

func _select_pose_node() -> Node3D:
    if (
        aim_tracking != null
        and aim_tracking.get_is_active()
        and aim_tracking.get_has_tracking_data()
    ):
        return aim_pose

    if (
        fallback_tracking != null
        and fallback_tracking.get_is_active()
        and fallback_tracking.get_has_tracking_data()
    ):
        return fallback_pose

    return null

func _set_beam_length(length_m: float) -> void:
    var mesh := beam.mesh as CylinderMesh
    if mesh:
        mesh.height = length_m
    beam.position.z = -length_m * 0.5

func _set_visual_state(on_target: bool) -> void:
    beam_material.albedo_color = (
        Color(0.58, 1.0, 0.76, 0.92)
        if on_target
        else Color(0.83, 0.95, 1.0, 0.82)
    )
    reticle_material.albedo_color = (
        Color(0.58, 1.0, 0.76, 1.0)
        if on_target
        else Color(0.92, 0.98, 1.0, 1.0)
    )

func _hide_visuals() -> void:
    beam.visible = false
    reticle.visible = false

func _update_trigger_latch() -> void:
    trigger_before = controller.is_button_pressed("trigger_click")

func _log_status_once(status: String) -> void:
    if status == status_logged:
        return
    status_logged = status
    print("ELI VR XR POINTER [", controller.tracker, "]: ", status)

func _set_current(target) -> void:
    if current == target:
        return
    if current:
        current.set_highlighted(false)
    current = target
    if current:
        current.set_highlighted(true)
