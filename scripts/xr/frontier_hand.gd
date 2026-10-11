class_name FrontierHand
extends Node3D

var controller: XRController3D
var side: String = "left"
var accent: Color = Color("#63ddff")
var pointer_socket: Marker3D
var palm: MeshInstance3D
var finger_roots: Array[Node3D] = []
var finger_segments: Array[Array] = []

func setup(p_controller: XRController3D, p_side: String, p_accent: Color) -> void:
    controller = p_controller
    side = p_side
    accent = p_accent
    _build_hand()

func set_accent(p_accent: Color) -> void:
    accent = p_accent
    _apply_materials()

func _build_hand() -> void:
    # Graphite palm.
    palm = MeshInstance3D.new()
    var palm_mesh := BoxMesh.new()
    palm_mesh.size = Vector3(0.085, 0.032, 0.095)
    palm.mesh = palm_mesh
    palm.position = Vector3(0.0, -0.005, -0.015)
    add_child(palm)

    # Back-of-hand plate to avoid the old block-controller appearance.
    var plate := MeshInstance3D.new()
    var plate_mesh := BoxMesh.new()
    plate_mesh.size = Vector3(0.072, 0.014, 0.068)
    plate.mesh = plate_mesh
    plate.position = Vector3(0.0, 0.019, -0.018)
    add_child(plate)

    # Wrist/cuff.
    var cuff := MeshInstance3D.new()
    var cuff_mesh := CylinderMesh.new()
    cuff_mesh.top_radius = 0.041
    cuff_mesh.bottom_radius = 0.046
    cuff_mesh.height = 0.050
    cuff.mesh = cuff_mesh
    cuff.rotation_degrees.x = 90.0
    cuff.position = Vector3(0.0, -0.002, 0.060)
    add_child(cuff)

    # Four articulated fingers. Each is built from two capsule segments.
    var xs: Array[float] = [-0.031, -0.010, 0.012, 0.032]
    for i in range(4):
        var root := Node3D.new()
        root.position = Vector3(xs[i], 0.0, -0.056)
        add_child(root)
        finger_roots.append(root)

        var segs: Array = []
        var seg1 := _capsule(0.0105, 0.050)
        seg1.position = Vector3(0.0, 0.0, -0.024)
        seg1.rotation_degrees.x = 90.0
        root.add_child(seg1)
        segs.append(seg1)

        var seg2 := _capsule(0.0092, 0.043)
        seg2.position = Vector3(0.0, -0.001, -0.061)
        seg2.rotation_degrees.x = 90.0
        root.add_child(seg2)
        segs.append(seg2)
        finger_segments.append(segs)

    # Thumb, mirrored per hand.
    var thumb_root := Node3D.new()
    var thumb_sign: float = -1.0 if side == "left" else 1.0
    thumb_root.position = Vector3(0.046 * thumb_sign, -0.002, -0.012)
    thumb_root.rotation_degrees = Vector3(22.0, 0.0, -32.0 * thumb_sign)
    add_child(thumb_root)

    var thumb1 := _capsule(0.011, 0.046)
    thumb1.rotation_degrees.x = 90.0
    thumb1.position = Vector3(0.0, 0.0, -0.020)
    thumb_root.add_child(thumb1)

    var thumb2 := _capsule(0.0095, 0.038)
    thumb2.rotation_degrees.x = 90.0
    thumb2.position = Vector3(0.0, 0.0, -0.052)
    thumb_root.add_child(thumb2)

    # Small emissive knuckle/wrist trim.
    for x in [-0.028, 0.0, 0.028]:
        var trim := MeshInstance3D.new()
        var trim_mesh := BoxMesh.new()
        trim_mesh.size = Vector3(0.018, 0.005, 0.010)
        trim.mesh = trim_mesh
        trim.position = Vector3(x, 0.037, -0.032)
        add_child(trim)

    # Pointer originates from the index fingertip rather than the controller
    # origin. Aim orientation still comes from OpenXR's aim pose.
    pointer_socket = Marker3D.new()
    pointer_socket.name = "IndexPointerSocket"
    var index_x: float = -0.031
    pointer_socket.position = Vector3(index_x, 0.004, -0.112)
    add_child(pointer_socket)

    _apply_materials()

func _capsule(radius: float, height: float) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var mesh := CapsuleMesh.new()
    mesh.radius = radius
    mesh.height = height
    mesh.radial_segments = 12
    mesh.rings = 4
    n.mesh = mesh
    return n

func _apply_materials() -> void:
    var graphite := StandardMaterial3D.new()
    graphite.albedo_color = Color("#151a20")
    graphite.metallic = 0.22
    graphite.roughness = 0.50

    var soft := StandardMaterial3D.new()
    soft.albedo_color = Color("#252c33")
    soft.metallic = 0.05
    soft.roughness = 0.78

    var glow := StandardMaterial3D.new()
    glow.albedo_color = accent * 0.55
    glow.emission_enabled = true
    glow.emission = accent
    glow.emission_energy_multiplier = 1.8
    glow.roughness = 0.30

    for child in get_children():
        if child is MeshInstance3D:
            var mi: MeshInstance3D = child as MeshInstance3D
            if "Capsule" in mi.mesh.get_class():
                mi.material_override = soft
            elif child == palm:
                mi.material_override = soft
            else:
                mi.material_override = graphite

    # Re-apply glow to the three small trim boxes by position.
    for child in get_children():
        if child is MeshInstance3D:
            var mi: MeshInstance3D = child as MeshInstance3D
            if mi.position.y > 0.03:
                mi.material_override = glow

    for segs in finger_segments:
        for seg in segs:
            (seg as MeshInstance3D).material_override = soft

func _process(_delta: float) -> void:
    if controller == null:
        visible = false
        return

    visible = controller.get_has_tracking_data()
    if not visible:
        return

    var trigger: float = clampf(controller.get_float("trigger"), 0.0, 1.0)
    var grip: float = clampf(controller.get_float("grip"), 0.0, 1.0)

    # Index follows trigger; remaining fingers follow grip.
    for i in range(finger_roots.size()):
        var curl: float = trigger if i == 0 else grip
        var root: Node3D = finger_roots[i]
        root.rotation_degrees.x = -curl * 57.0

        var segs: Array = finger_segments[i]
        if segs.size() > 1:
            (segs[1] as MeshInstance3D).rotation_degrees.x = 90.0 - curl * 42.0
