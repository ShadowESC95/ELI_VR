class_name DesktopSurface
extends Area3D

const DesktopBridgeClientClass = preload("res://scripts/desktop/desktop_bridge_client.gd")

var mesh_instance: MeshInstance3D
var material: StandardMaterial3D
var frame_material: StandardMaterial3D
var bridge
var viewport: SubViewport
var texture_rect: TextureRect
var placeholder_label: Label
var title_label: Label
var composition_layer: Node3D
var enabled: bool = true
var xr_active: bool = false
var display_mode: String = "auto"
var capture_backend: String = "local_bridge"
var config_ref
var bridge_started: bool = false
var composition_requested: bool = false

func setup(config, p_xr_active: bool = false, capabilities: Dictionary = {}) -> void:
    config_ref = config
    xr_active = p_xr_active
    enabled = bool(config.get_value("desktop.enabled", true))
    display_mode = str(config.get_value("desktop.display_mode", "auto"))
    capture_backend = str(capabilities.get("desktop_capture_backend", "local_bridge"))

    var layout_version: int = int(config.get_value("desktop.layout_version", 0))
    if layout_version < 2:
        config.set_value("desktop.width_m", 4.20)
        config.set_value("desktop.height_m", 2.36)
        config.set_value("desktop.distance_m", 5.60)
        config.set_value("desktop.vertical_offset_m", 2.55)
        config.set_value("desktop.horizontal_offset_m", 0.0)
        config.set_value("desktop.layout_version", 2)
        config.save_runtime()

    var width: float = float(config.get_value("desktop.width_m", 4.20))
    var height: float = float(config.get_value("desktop.height_m", 2.36))
    var distance: float = float(config.get_value("desktop.distance_m", 5.60))
    var y: float = float(config.get_value("desktop.vertical_offset_m", 2.55))
    var x: float = float(config.get_value("desktop.horizontal_offset_m", 0.0))

    position = Vector3(x, y, -distance)
    collision_layer = 4
    collision_mask = 0
    monitoring = false
    monitorable = true

    _build_viewport(config)
    _build_mesh(width, height)
    _build_frame(width, height)
    _build_grab_surface(width, height)

    # Composition layers are opt-in. The scene-native mesh is the portable
    # default and avoids runtime-specific swapchain/lifecycle faults.
    composition_requested = (
        xr_active
        and display_mode == "composition"
        and ClassDB.class_exists("OpenXRCompositionLayerQuad")
    )
    if composition_requested:
        call_deferred("_activate_composition_layer", width, height)

    bridge = DesktopBridgeClientClass.new()
    bridge.name = "DesktopBridgeClient"
    add_child(bridge)
    bridge.configure(
        str(config.get_value("desktop.bridge_host", "127.0.0.1")),
        int(config.get_value("desktop.bridge_port", 47831))
    )
    bridge.frame_updated.connect(_on_frame)
    bridge.state_changed.connect(_on_state)

    visible = enabled
    if enabled:
        _start_bridge()
    _refresh_placeholder()

func _build_viewport(config) -> void:
    viewport = SubViewport.new()
    viewport.name = "DesktopViewport"
    var vw: int = int(config.get_value("desktop.bridge_width", 1600))
    viewport.size = Vector2i(vw, int(float(vw) * 9.0 / 16.0))
    viewport.disable_3d = true
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(viewport)

    var bg: ColorRect = ColorRect.new()
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    bg.color = Color("#04090d")
    viewport.add_child(bg)

    texture_rect = TextureRect.new()
    texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    bg.add_child(texture_rect)

    title_label = Label.new()
    title_label.text = "ELI VR // DESKTOP"
    title_label.position = Vector2(38, 28)
    title_label.add_theme_font_size_override("font_size", 26)
    title_label.add_theme_color_override("font_color", Color("#dff8ff"))
    bg.add_child(title_label)

    placeholder_label = Label.new()
    placeholder_label.position = Vector2(38, 76)
    placeholder_label.add_theme_font_size_override("font_size", 18)
    placeholder_label.add_theme_color_override("font_color", Color("#b9c9d1"))
    bg.add_child(placeholder_label)

func _activate_composition_layer(width: float, height: float) -> void:
    if not is_inside_tree():
        call_deferred("_activate_composition_layer", width, height)
        return

    composition_layer = ClassDB.instantiate("OpenXRCompositionLayerQuad") as Node3D
    if composition_layer == null:
        return

    composition_layer.name = "DesktopCompositionLayer"
    add_child(composition_layer)
    composition_layer.set("layer_viewport", viewport)
    composition_layer.set("quad_size", Vector2(width, height))
    composition_layer.set("alpha_blend", false)
    composition_layer.set("sort_order", 2)
    composition_layer.set("enable_hole_punch", false)

    # Composition layer is now live. The 3D mesh remains as a robust fallback
    # if a runtime ignores the quad; it is slightly behind the compositor quad.
    if mesh_instance:
        mesh_instance.position.z = 0.012

func _build_mesh(width: float, height: float) -> void:
    var quad: QuadMesh = QuadMesh.new()
    quad.size = Vector2(width, height)
    quad.orientation = PlaneMesh.FACE_Z

    material = StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.albedo_texture = viewport.get_texture()

    mesh_instance = MeshInstance3D.new()
    mesh_instance.name = "DesktopScreen"
    mesh_instance.mesh = quad
    mesh_instance.material_override = material
    add_child(mesh_instance)

func _build_frame(width: float, height: float) -> void:
    frame_material = StandardMaterial3D.new()
    frame_material.albedo_color = Color("#101820")
    frame_material.metallic = 0.78
    frame_material.roughness = 0.22
    frame_material.emission_enabled = true
    frame_material.emission = Color("#315065")
    frame_material.emission_energy_multiplier = 0.20
    var th: float = 0.045

    var specs: Array = [
        [Vector3(width + 0.12, th, 0.06), Vector3(0, height * 0.5 + 0.05, 0.02)],
        [Vector3(width + 0.12, th, 0.06), Vector3(0, -height * 0.5 - 0.05, 0.02)],
        [Vector3(th, height + 0.12, 0.06), Vector3(width * 0.5 + 0.05, 0, 0.02)],
        [Vector3(th, height + 0.12, 0.06), Vector3(-width * 0.5 - 0.05, 0, 0.02)],
    ]

    for spec in specs:
        var box: MeshInstance3D = MeshInstance3D.new()
        var mesh: BoxMesh = BoxMesh.new()
        mesh.size = spec[0]
        box.mesh = mesh
        box.position = spec[1]
        box.material_override = frame_material
        add_child(box)

    var handle: Label3D = Label3D.new()
    handle.text = "GRIP SCREEN TO MOVE  •  STICK Y DISTANCE  •  STICK X ROTATE"
    handle.font_size = 22
    handle.pixel_size = 0.0011
    handle.modulate = Color("#9cc7dd")
    handle.position = Vector3(0.0, -height * 0.5 - 0.13, 0.04)
    handle.no_depth_test = true
    add_child(handle)

func _build_grab_surface(width: float, height: float) -> void:
    var shape_node: CollisionShape3D = CollisionShape3D.new()
    var shape: BoxShape3D = BoxShape3D.new()
    shape.size = Vector3(width + 0.18, height + 0.22, 0.16)
    shape_node.shape = shape
    shape_node.position.z = 0.06
    add_child(shape_node)

func begin_grab() -> void:
    if frame_material:
        frame_material.emission = Color("#76dfff")
        frame_material.emission_energy_multiplier = 0.70

func end_grab() -> void:
    if frame_material:
        frame_material.emission = Color("#315065")
        frame_material.emission_energy_multiplier = 0.20

func _start_bridge() -> void:
    if bridge == null or bridge_started:
        return
    bridge_started = true
    bridge.start()

func _stop_bridge() -> void:
    if bridge == null or not bridge_started:
        return
    bridge.stop()
    bridge_started = false

func _on_frame(texture: Texture2D) -> void:
    texture_rect.texture = texture
    if placeholder_label:
        placeholder_label.visible = false
    if title_label:
        title_label.visible = false

func _on_state(_state: String) -> void:
    _refresh_placeholder()

func _refresh_placeholder() -> void:
    if placeholder_label == null:
        return
    if texture_rect != null and texture_rect.texture != null:
        placeholder_label.visible = false
        return

    placeholder_label.visible = true
    if title_label:
        title_label.visible = true
    var state: String = bridge.status_text() if bridge != null else "off"
    if state == "connected":
        placeholder_label.text = (
            "Capture link connected. Waiting for first frame.\n"
            + "If GNOME shows a share dialog, choose the monitor/window to capture."
        )
    else:
        placeholder_label.text = (
            "Capture backend: %s  •  bridge: %s\n"
            + "Waiting for the local capture adapter."
        ) % [capture_backend, state]

func reset_workspace_transform() -> void:
    position = Vector3(0.0, 2.55, -5.60)
    rotation = Vector3.ZERO
    scale = Vector3.ONE

func set_desktop_visible(value: bool) -> void:
    enabled = value
    visible = value
    if value:
        _start_bridge()
    else:
        _stop_bridge()
    _refresh_placeholder()

func bridge_status() -> String:
    if not visible:
        return "hidden"
    var state: String = bridge.status_text() if bridge != null else "off"
    return "%s/%s/%s" % [
        state,
        capture_backend,
        "composition+mesh" if composition_layer else "mesh"
    ]
