class_name XRControllerVisual
extends Node3D

var controller: XRController3D
var side := "left"
var body: MeshInstance3D
var trigger_led: MeshInstance3D
var base_color := Color("#63ddff")

func setup(p_controller: XRController3D, p_side: String) -> void:
    controller = p_controller
    side = p_side
    base_color = Color("#63ddff") if side == "left" else Color("#ffb45c")
    _build()
    visible = false

func _build() -> void:
    body = MeshInstance3D.new()
    var body_mesh := BoxMesh.new()
    body_mesh.size = Vector3(0.055, 0.115, 0.10)
    body.mesh = body_mesh
    body.position = Vector3(0.0, -0.035, 0.02)
    body.rotation_degrees.x = -18.0
    body.material_override = _material(base_color * 0.35, base_color, 0.45)
    add_child(body)

    var head := MeshInstance3D.new()
    var head_mesh := SphereMesh.new()
    head_mesh.radius = 0.045
    head_mesh.height = 0.09
    head.mesh = head_mesh
    head.position = Vector3(0.0, 0.025, -0.035)
    head.material_override = _material(base_color * 0.22, base_color, 0.30)
    add_child(head)

    trigger_led = MeshInstance3D.new()
    var led_mesh := SphereMesh.new()
    led_mesh.radius = 0.012
    led_mesh.height = 0.024
    trigger_led.mesh = led_mesh
    trigger_led.position = Vector3(0.0, 0.025, -0.09)
    trigger_led.material_override = _material(base_color * 0.3, base_color, 0.15)
    add_child(trigger_led)

func _process(_delta: float) -> void:
    if controller == null:
        visible = false
        return

    visible = controller.get_is_active() and controller.get_has_tracking_data()
    if not visible:
        return

    var trigger := controller.get_float("trigger")
    var led_mat := trigger_led.material_override as StandardMaterial3D
    if led_mat:
        led_mat.emission_energy_multiplier = 0.7 + trigger * 4.0

func _material(albedo: Color, emission: Color, roughness: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = albedo
    mat.metallic = 0.35
    mat.roughness = roughness
    mat.emission_enabled = true
    mat.emission = emission
    mat.emission_energy_multiplier = 1.0
    return mat
