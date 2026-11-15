class_name XRPointer
extends Node3D

# The ray is the calibrated aim pose itself (XRControllerCalibration's aim root): it leaves where the
# runtime says the controller's ray leaves and goes along its -Z, so it points where the controller
# points. The pose is shown only while the runtime tracks the controller.
var controller: XRController3D
var pose: Node3D
var current
var trigger_before: bool = false

var beam: MeshInstance3D
var beam_material: StandardMaterial3D
var reticle: MeshInstance3D
var reticle_material: StandardMaterial3D

const RAY_LENGTH := 20.0
const RAY_RADIUS := 0.0018

func setup(p_controller: XRController3D, p_pose: Node3D) -> void:
    controller = p_controller
    pose = p_pose
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

    if pose == null or not pose.visible:
        _hide_visuals()
        _set_current(null)
        _update_trigger_latch()
        return

    global_transform = pose.global_transform.orthonormalized()
    var origin: Vector3 = global_position
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

    var pressed: bool = _trigger_down()
    # a hand holding something (a panel, a thing, a gun of the range) is not pressing buttons with it
    if pressed and not trigger_before and current and not XRWorldManipulator.is_holding(controller):
        current.activate()
        controller.trigger_haptic_pulse("haptic", 0.0, 0.30, 0.04, 0.0)
    elif current == null:
        _use_desktop(origin, direction, pressed)
    trigger_before = pressed

# With no panel in the way, the ray may be on the desktop: there the pointer goes where it points
# and the trigger clicks; on the right hand, pressing the stick in right-clicks and pushing it up or
# down scrolls (the left stick walks, and turning is the right stick's left and right).
var _scroll_wait := 0.0
var _side_before := false

func _use_desktop(origin: Vector3, direction: Vector3, pressed: bool) -> void:
    var screen: Node = null
    var hit := {}
    for desktop in get_tree().get_nodes_in_group("eli_desktop"):
        var meets: Dictionary = desktop.ray_hit(origin, direction)
        if not meets.is_empty() and (hit.is_empty() or float(meets["distance"]) < float(hit["distance"])):
            screen = desktop
            hit = meets
    if screen == null:
        return
    var reach: float = maxf(0.05, float(hit["distance"]))
    reticle.visible = true
    reticle.position = Vector3(0.0, 0.0, -reach)
    _set_beam_length(reach)
    var holding := XRWorldManipulator.is_holding(controller)
    var right_hand := str(controller.tracker) == "right_hand"
    var side: bool = right_hand and controller.is_button_pressed("primary_click") and not holding
    var stick: float = controller.get_vector2("primary").y if right_hand and not holding else 0.0
    var steps := 0
    _scroll_wait = maxf(0.0, _scroll_wait - get_physics_process_delta_time())
    if absf(stick) > 0.5 and _scroll_wait <= 0.0:
        steps = -1 if stick > 0.0 else 1
        _scroll_wait = 0.12
    var uv: Vector2 = hit["uv"]
    if holding:                         # the grip is moving it: no clicks meanwhile
        screen.point_uv(uv)
    elif pressed != trigger_before:
        screen.point_uv(uv, "left", pressed, steps)
        controller.trigger_haptic_pulse("haptic", 0.0, 0.25, 0.03, 0.0)
    elif side != _side_before:
        screen.point_uv(uv, "right", side, steps)
    else:
        screen.point_uv(uv, "", false, steps)
    _side_before = side

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
    trigger_before = _trigger_down()

# The trigger, unless a recalibration armed from the wrist menu has it (XRCalibrationWidget): then it
# presses nothing and clicks nothing until let go.
func _trigger_down() -> bool:
    return controller.is_button_pressed("trigger_click") and not XRCalibrationWidget.takes_triggers()

func _set_current(target) -> void:
    if current == target:
        return
    if current:
        current.set_highlighted(false)
    current = target
    if current:
        current.set_highlighted(true)
