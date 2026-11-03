class_name DesktopSurface
extends Node3D

## The desktop, shown the way a VR desktop should be. In the headset it is handed to the runtime's
## compositor as a layer of its own (flat, or curved round you), so its pixels are sampled once,
## through the lenses, and not through the room's rendering first. Where the runtime has no such
## layer, and in the flat window, it is drawn in the room instead. Either way the room never hides
## it, and hands, pointers, panels and ELI are drawn over it.
##
## Its size is a scale: 1 is one desktop pixel to one pixel of the display, as sharp as the display
## can show. It can be curved round you or flat, moved round you, brought nearer or sent further.
## Holding it with the grip: move the hand to move it, pull the hand in or push it out to bring it
## nearer or further, the stick up or down to make it larger or smaller, left or right to curve it.

const DesktopBridgeClientClass = preload("res://scripts/desktop/desktop_bridge_client.gd")

## Drawn after the room (whose own see-through things are below this), and before what is in front.
const SCREEN_PRIORITY := 100
const FRONT_PRIORITY := 110
## The downsample shader averages up to this many desktop pixels into one (desktop_downsample).
const MOST_SHRUNK := 16.0

var bridge
var enabled: bool = true
var xr_active: bool = false
var display_mode: String = "auto"       # "auto": the runtime's own layer where it has one; "mesh": drawn in the room
var capture_backend: String = "local_bridge"
var config_ref

var distance := 0.0     # metres from the viewer to the middle of the screen
var scale_px := 1.0     # its size: 1 is one desktop pixel to one display pixel
var curve := 1.0        # 0 flat, 1 curved round the viewer
var yaw := 0.0          # where it is round the viewer, radians from straight ahead
var lift := 0.0         # radians above eye level its middle is

var _source := Vector2i.ZERO            # the desktop's own size, once its first picture has come
var _canvas: SubViewport                # the desktop at that size, put together from its tiles
var _tiles := {}                        # Rect2i -> TextureRect
var _tile_material: ShaderMaterial
var _view: SubViewport                  # the desktop brought to the size it is seen at
var _view_rect: ColorRect
var _view_material: ShaderMaterial
var _waiting: Label
var _view_frames := 0                   # frames the view is still to be drawn for

var _mesh: MeshInstance3D               # the screen's shape in the room
var _screen_material: ShaderMaterial    # the desktop itself, drawn in the room
var _hole_material: ShaderMaterial      # the hole the runtime's layer shows through
var _layer: Node3D                      # OpenXRCompositionLayerQuad or ...Cylinder
var _layer_kind := ""
var _using_layer := false
var _placed := false
var _front_roots: Array[Node] = []
var _last_point := Vector2(-1, -1)
var _hold := {}

func setup(config, p_xr_active: bool = false, capabilities: Dictionary = {}) -> void:
    config_ref = config
    xr_active = p_xr_active
    enabled = bool(config.get_value("desktop.enabled", true))
    display_mode = str(config.get_value("desktop.display_mode", "auto"))
    capture_backend = str(capabilities.get("desktop_capture_backend", "local_bridge"))
    add_to_group("eli_desktop")

    if int(config.get_value("desktop.layout_version", 0)) < 3:
        # the screen was a flat panel of fixed size far away; it is now sized by the display
        for key in ["desktop.distance_m", "desktop.scale", "desktop.curve", "desktop.yaw_deg", "desktop.lift_deg"]:
            config.set_value(key, 0.0 if key != "desktop.curve" else 1.0)
        # drawing it in the room was the default then, chosen by no one; the runtime's layer is now
        config.set_value("desktop.display_mode", "auto")
        config.set_value("desktop.layout_version", 3)
        config.save_runtime()
    distance = float(config.get_value("desktop.distance_m", 0.0))
    scale_px = float(config.get_value("desktop.scale", 0.0))
    curve = clampf(float(config.get_value("desktop.curve", 1.0)), 0.0, 1.0)
    yaw = deg_to_rad(float(config.get_value("desktop.yaw_deg", 0.0)))
    lift = deg_to_rad(float(config.get_value("desktop.lift_deg", 0.0)))
    if distance <= 0.0:
        # as far as the console's panels, so they are never behind it
        distance = float(config.get_value("ui.console_distance_m", 0.0))
    if scale_px <= 0.0:
        scale_px = 1.0

    _build_views()
    _build_mesh()

    bridge = DesktopBridgeClientClass.new()
    bridge.name = "DesktopBridgeClient"
    add_child(bridge)
    bridge.configure(
        str(config.get_value("desktop.bridge_host", "127.0.0.1")),
        int(config.get_value("desktop.bridge_port", 47831))
    )
    bridge.tiles_arrived.connect(_on_tiles)
    bridge.state_changed.connect(_on_state)
    get_tree().node_added.connect(_on_node_added)

    visible = enabled
    if enabled:
        bridge.start()
    _refresh_waiting()
    _reshape()

# --- what is shown ---------------------------------------------------------------------------

func _build_views() -> void:
    _view = SubViewport.new()
    _view.name = "DesktopView"
    _view.disable_3d = true
    _view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    add_child(_view)

    _canvas = SubViewport.new()                 # inside the view, so it is drawn before it
    _canvas.name = "DesktopCanvas"
    _canvas.disable_3d = true
    _canvas.render_target_update_mode = SubViewport.UPDATE_DISABLED
    _view.add_child(_canvas)

    _tile_material = ShaderMaterial.new()
    _tile_material.shader = load("res://assets/shaders/desktop_tile.gdshader")

    _view_material = ShaderMaterial.new()
    _view_material.shader = load("res://assets/shaders/desktop_downsample.gdshader")
    _view_material.set_shader_parameter("desktop", _canvas.get_texture())
    _view_rect = ColorRect.new()
    _view_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _view_rect.material = _view_material
    _view_rect.visible = false
    _view.add_child(_view_rect)

    var card := ColorRect.new()                 # shown until the desktop's first picture
    card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    card.color = Color("#04090d")
    _view.add_child(card)
    _waiting = Label.new()
    _waiting.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    _waiting.anchor_bottom = 0.5                # the upper half: the console stands in front of the lower
    _waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _waiting.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _waiting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _waiting.add_theme_color_override("font_color", Color("#b9c9d1"))
    card.add_child(_waiting)

func _on_tiles(screen: Vector2i, tiles: Array) -> void:
    if screen != _source:
        _source = screen
        _canvas.size = screen
        for shown in _tiles.values():
            shown.queue_free()
        _tiles.clear()
        _reshape()
    for tile in tiles:
        var rect: Rect2i = tile[0]
        var image: Image = tile[1]
        var shown: TextureRect = _tiles.get(rect)
        if shown == null:
            shown = TextureRect.new()
            shown.position = rect.position
            shown.size = rect.size
            shown.texture = ImageTexture.create_from_image(image)
            shown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
            shown.material = _tile_material
            _canvas.add_child(shown)
            _tiles[rect] = shown
        else:
            (shown.texture as ImageTexture).update(image)
    _canvas.render_target_update_mode = SubViewport.UPDATE_ONCE
    _view_rect.visible = true
    _waiting.get_parent().visible = false
    _redraw()

## Draw the view again. Its layer's image is only replaced when the view is drawn, so between
## changes the runtime keeps showing the last one and nothing is drawn or sent.
func _redraw() -> void:
    _view_frames = 2                        # the canvas is drawn in the first, the view in either
    _view.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _process(_delta: float) -> void:
    if not _placed and visible:
        _place_when_seen()
    if _view_frames > 0:
        _view_frames -= 1
        if _view_frames == 0:
            _view.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _on_state(_state: String) -> void:
    _refresh_waiting()

func _refresh_waiting() -> void:
    if _waiting == null or _source != Vector2i.ZERO:
        return
    var state: String = bridge.status_text() if bridge != null else "off"
    if state == "connected":
        _waiting.text = ("Waiting for the screen to be shared.\n"
            + "If a share dialog is open on your monitor, choose a screen there. It is asked once.")
    elif state == "connecting":
        _waiting.text = "Connecting to the desktop helper on this computer."
    else:
        _waiting.text = ("The desktop helper on this computer is not running.\n"
            + "No network is needed. Start ELI VR with its launcher to start the helper.")
    # as large as lets its longest line fit the card
    var font := ThemeDB.fallback_font
    var widest := 1.0
    var trial := maxi(1, _view.size.y / 12)
    for line in _waiting.text.split("\n"):
        widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, trial).x)
    _waiting.add_theme_font_size_override("font_size", maxi(1, floori(trial * _view.size.x * 0.9 / widest)))
    _redraw()

# --- its shape -------------------------------------------------------------------------------

## The display's pixels per radian: the headset's own render size over its field of view, or the
## flat window's height over the camera's.
func _display_density() -> float:
    if xr_active:
        var xr := XRServer.primary_interface
        if xr and xr.is_initialized():
            var target := Vector2(xr.get_render_target_size())
            var fov := deg_to_rad(xr.get_projection_for_view(0, target.x / maxf(1.0, target.y), 0.05, 100.0).get_fov())
            if target.x > 0.0 and fov > 0.0:
                return target.x / fov
    var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
    var height := get_viewport().get_visible_rect().size.y if is_inside_tree() else 0.0
    if camera and camera.fov > 0.0 and height > 0.0:
        return height / deg_to_rad(camera.fov)
    return 0.0

## The display's own size, for the card shown before the desktop's first picture.
func _display_size() -> Vector2i:
    var xr := XRServer.primary_interface if xr_active else null
    if xr and xr.is_initialized():
        return xr.get_render_target_size()
    return Vector2i(get_viewport().get_visible_rect().size) if is_inside_tree() else Vector2i.ONE

func _shown_size() -> Vector2i:
    return _source if _source != Vector2i.ZERO else _display_size()

## Radians the screen spans as seen from the viewer when curved round them.
func span() -> float:
    var density := _display_density()
    var shown := _shown_size()
    if density <= 0.0:
        return 0.0
    if _source == Vector2i.ZERO:
        return float(shown.x) / density * 0.5        # the waiting card: half the view across
    return float(shown.x) * scale_px / density

func _widest_scale() -> float:
    var density := _display_density()
    if density <= 0.0 or _source.x <= 0 or curve <= 0.0:
        return INF
    # a layer curved right round may not close on itself: one desktop pixel short of it
    return TAU * (1.0 - 1.0 / float(_source.x)) / curve * density / float(_source.x)

func width_m() -> float:
    return distance * span()

func height_m() -> float:
    var shown := _shown_size()
    return width_m() * float(shown.y) / float(maxi(1, shown.x))

func radius_m() -> float:
    return distance / curve if curve > 0.0 else INF

## Radians of the cylinder the screen is a part of.
func arc() -> float:
    return span() * curve

## Radians the screen spans from where the viewer is, whatever its curve.
func seen_angle() -> float:
    if curve <= 0.0:
        return 2.0 * atan2(width_m() * 0.5, distance)
    var r := radius_m()
    var half := arc() * 0.5
    return 2.0 * atan2(r * sin(half), distance - r + r * cos(half))

func _reshape() -> void:
    if _mesh == null or distance <= 0.0 or span() <= 0.0:
        return
    scale_px = clampf(scale_px, 1.0 / MOST_SHRUNK, _widest_scale())
    # drawn at the size it is seen at, and never above the desktop's own
    var shown := _shown_size()
    var across := clampi(ceili(seen_angle() * _display_density()), 1, shown.x)
    var size := Vector2i(across, maxi(1, roundi(across * float(shown.y) / float(shown.x))))
    if _view.size != size:
        _view.size = size
    var ratio := Vector2(_source) / Vector2(size) if _source != Vector2i.ZERO else Vector2.ONE
    _view_material.set_shader_parameter("ratio", ratio)
    _view_material.set_shader_parameter("desktop_size", Vector2(maxi(1, _source.x), maxi(1, _source.y)))
    _mesh.mesh = _shape_mesh()
    _choose_drawing()
    if _using_layer:
        _shape_layer()
    _refresh_waiting()
    _redraw()

## The screen as a mesh: a part of a cylinder round the viewer, or flat. Curved, it is cut into as
## many strips as keep it within half a desktop pixel of the true curve.
func _shape_mesh() -> ArrayMesh:
    var w := width_m()
    var h := height_m()
    var strips := 1
    if curve > 0.0:
        var pixel := w / float(maxi(1, _shown_size().x))
        strips = maxi(1, ceili(arc() / sqrt(4.0 * pixel / radius_m())))
    var vertices := PackedVector3Array()
    var uvs := PackedVector2Array()
    var indices := PackedInt32Array()
    for i in strips + 1:
        var u := float(i) / float(strips)
        var at := _surface_point(u)
        vertices.append_array([at + Vector3(0, h * 0.5, 0), at - Vector3(0, h * 0.5, 0)])
        uvs.append_array([Vector2(u, 0), Vector2(u, 1)])
        if i < strips:
            var k := i * 2
            indices.append_array([k, k + 2, k + 1, k + 1, k + 2, k + 3])
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh

## The point on the screen's middle line at u (0 left edge, 1 right), in its own space: its middle
## is the origin, and it faces +Z, where the viewer is.
func _surface_point(u: float) -> Vector3:
    if curve <= 0.0:
        return Vector3((u - 0.5) * width_m(), 0, 0)
    var r := radius_m()
    var angle := (u - 0.5) * arc()
    return Vector3(r * sin(angle), 0, r - r * cos(angle))

func _build_mesh() -> void:
    _screen_material = ShaderMaterial.new()
    _screen_material.shader = load("res://assets/shaders/desktop_screen.gdshader")
    _screen_material.set_shader_parameter("view", _view.get_texture())
    _screen_material.render_priority = SCREEN_PRIORITY
    _hole_material = ShaderMaterial.new()
    _hole_material.shader = load("res://assets/shaders/desktop_hole.gdshader")
    _hole_material.render_priority = SCREEN_PRIORITY
    _mesh = MeshInstance3D.new()
    _mesh.name = "DesktopScreen"
    _mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _mesh.material_override = _screen_material
    add_child(_mesh)

# --- the runtime's own layer -----------------------------------------------------------------

## The layer for this shape, where the runtime has one: a cylinder when curved, a quad when flat.
func _choose_drawing() -> void:
    var kind := "OpenXRCompositionLayerCylinder" if curve > 0.0 else "OpenXRCompositionLayerQuad"
    var wanted := xr_active and display_mode != "mesh" and _runtime_has(kind)
    if wanted and (_layer == null or _layer_kind != kind):
        _drop_layer()
        _layer = ClassDB.instantiate(kind) as Node3D
        _layer_kind = kind
        _layer.name = "DesktopLayer"
        add_child(_layer)                   # in the tree before it is given its viewport
        _layer.set("sort_order", -1)        # behind the room, seen through the hole cut for it
        _layer.set("alpha_blend", false)
        _layer.set("enable_hole_punch", false)
        _layer.set("layer_viewport", _view)
    elif not wanted:
        _drop_layer()
    if wanted != _using_layer:
        _using_layer = wanted
        print("ELI VR DESKTOP: drawn by ", ("the headset's compositor (%s)" % kind.trim_prefix("OpenXRCompositionLayer").to_lower()) if wanted else "ELI VR in the room")
    _mesh.material_override = _hole_material if _using_layer else _screen_material
    # the hole shows what is behind the room only where the room leaves its alpha
    get_tree().root.transparent_bg = _using_layer and visible

func _runtime_has(kind: String) -> bool:
    if not ClassDB.class_exists(kind):
        return false
    var probe := ClassDB.instantiate(kind) as Node3D
    var has := bool(probe.call("is_natively_supported"))
    probe.free()
    return has

func _drop_layer() -> void:
    if _layer:
        _layer.set("layer_viewport", null)
        _layer.queue_free()
        _layer = null
        _layer_kind = ""

func _shape_layer() -> void:
    if _layer_kind == "OpenXRCompositionLayerCylinder":
        _layer.position = Vector3(0, 0, radius_m())     # a cylinder layer is placed at its axis
        _layer.set("radius", radius_m())
        _layer.set("central_angle", arc())
        _layer.set("aspect_ratio", width_m() / maxf(height_m(), 0.000001))
    else:
        _layer.position = Vector3.ZERO
        _layer.set("quad_size", Vector2(width_m(), height_m()))

# --- where it is -----------------------------------------------------------------------------

## The viewer's eyes, in the space this screen is placed in.
func _viewer() -> Transform3D:
    var camera := get_viewport().get_camera_3d()
    var parent := get_parent_node_3d()
    if camera == null:
        return Transform3D.IDENTITY
    return parent.global_transform.affine_inverse() * camera.global_transform if parent else camera.global_transform

func _place_when_seen() -> void:
    # in the headset, the eyes are where the runtime says only once it is tracking
    if xr_active and _viewer().origin == Vector3.ZERO:
        return
    _placed = true
    place()

## Put the screen round the viewer, `yaw` from straight ahead and `lift` above eye level, facing
## them, and curved about them.
func place() -> void:
    var head := _viewer().origin
    var ahead := Basis(Vector3.UP, yaw) * Vector3.FORWARD
    var middle := head + ahead * distance + Vector3.UP * distance * tan(lift)
    transform = Transform3D(Basis.looking_at(ahead, Vector3.UP), middle)
    _reshape()

## Straight ahead of where the viewer is looking, at eye level.
func reset_workspace_transform() -> void:
    yaw = _yaw_of(-_viewer().basis.z)
    lift = 0.0
    place()
    _save()

func _yaw_of(direction: Vector3) -> float:
    return atan2(-direction.x, -direction.z)

func _lift_of(direction: Vector3) -> float:
    return atan2(direction.y, Vector2(direction.x, direction.z).length())

func _save() -> void:
    if config_ref == null:
        return
    config_ref.set_value("desktop.distance_m", snappedf(distance, 0.001))
    config_ref.set_value("desktop.scale", snappedf(scale_px, 0.0001))
    config_ref.set_value("desktop.curve", snappedf(curve, 0.001))
    config_ref.set_value("desktop.yaw_deg", snappedf(rad_to_deg(yaw), 0.01))
    config_ref.set_value("desktop.lift_deg", snappedf(rad_to_deg(lift), 0.01))
    config_ref.save_runtime()

# --- held by a hand --------------------------------------------------------------------------

## Taken by a controller's grip, its ray from `origin` along `direction` (global).
func begin_hold(origin: Vector3, direction: Vector3) -> void:
    var to_parent := _parent_basis_inverse()
    var aim := (to_parent * direction).normalized()
    _hold = {
        "yaw": yaw - _yaw_of(aim),
        "lift": lift - _lift_of(aim),
        "reach": maxf(0.001, _viewer().origin.distance_to(_parent_point(origin))),
        "distance": distance,
    }

## Each frame it is held: it follows the ray round the viewer, comes nearer or goes further as the
## hand is pulled in or pushed out, grows or shrinks with the stick up or down (doubling in a
## second), and curves with the stick left or right (flat to round in a second).
func hold(origin: Vector3, direction: Vector3, stick: Vector2, delta: float) -> void:
    if _hold.is_empty():
        begin_hold(origin, direction)
    var aim := (_parent_basis_inverse() * direction).normalized()
    yaw = _yaw_of(aim) + float(_hold["yaw"])
    lift = clampf(_lift_of(aim) + float(_hold["lift"]), -PI * 0.5 + 0.01, PI * 0.5 - 0.01)
    var reach := _viewer().origin.distance_to(_parent_point(origin))
    var camera := get_viewport().get_camera_3d()
    distance = clampf(float(_hold["distance"]) * reach / float(_hold["reach"]),
        camera.near if camera else 0.0, camera.far * 0.5 if camera else INF)
    if absf(stick.y) > 0.15:
        scale_px *= exp(stick.y * delta * log(2.0))
    if absf(stick.x) > 0.15:
        curve = clampf(curve + stick.x * delta, 0.0, 1.0)
    place()

func end_hold() -> void:
    _hold = {}
    _save()

func _parent_basis_inverse() -> Basis:
    var parent := get_parent_node_3d()
    return parent.global_basis.inverse() if parent else Basis.IDENTITY

func _parent_point(point: Vector3) -> Vector3:
    var parent := get_parent_node_3d()
    return parent.global_transform.affine_inverse() * point if parent else point

# --- pointing at it --------------------------------------------------------------------------

## Where a ray meets the screen, from the side it faces: {"uv": (0, 0) top left to (1, 1) bottom
## right, "at": the point (global), "distance"}; empty when it misses.
func ray_hit(origin: Vector3, direction: Vector3) -> Dictionary:
    if not is_visible_in_tree() or distance <= 0.0:
        return {}
    var from := to_local(origin)
    var along := (global_basis.inverse() * direction).normalized()
    var w := width_m()
    var h := height_m()
    var t := -1.0
    var u := 0.0
    if curve <= 0.0:
        if along.z >= 0.0:
            return {}
        t = -from.z / along.z
        u = (from.x + along.x * t) / w + 0.5
    else:
        # the cylinder about the vertical line at (0, _, r); the far side is the inside it shows
        var r := radius_m()
        var ox := from.x
        var oz := from.z - r
        var a := along.x * along.x + along.z * along.z
        var b := 2.0 * (ox * along.x + oz * along.z)
        var c := ox * ox + oz * oz - r * r
        var disc := b * b - 4.0 * a * c
        if a <= 0.0 or disc < 0.0:
            return {}
        t = (-b + sqrt(disc)) / (2.0 * a)
        var meets := from + along * t
        u = atan2(meets.x, r - meets.z) / arc() + 0.5
    var hit := from + along * t
    var v := 0.5 - hit.y / h
    if t <= 0.0 or u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
        return {}
    var at_global := to_global(hit)
    return {"uv": Vector2(u, v), "at": at_global, "distance": origin.distance_to(at_global)}

## The controller pointing at `uv` on the screen: the desktop's pointer goes there, a button
## presses or lets go, steps scroll (up is negative).
func point_uv(uv: Vector2, button: String = "", down: bool = false, steps: int = 0) -> void:
    if bridge == null:
        return
    if uv.distance_to(_last_point) > 0.5 / float(maxi(1, _source.x)):
        _last_point = uv
        bridge.send_input({"kind": "move", "x": snappedf(uv.x, 0.00001), "y": snappedf(uv.y, 0.00001)})
    if not button.is_empty():
        bridge.send_input({"kind": "button", "button": button, "down": down})
    if steps != 0:
        bridge.send_input({"kind": "scroll", "steps": steps})

## In the flat window the desktop is on the same screen as the window, so the pointer is not passed
## through (it would leave the window); the wheel resizes it with Ctrl held and curves it with Shift.
func _unhandled_input(event: InputEvent) -> void:
    if xr_active or not is_visible_in_tree() or not (event is InputEventMouseButton) or not event.pressed:
        return
    var wheel: int = {MOUSE_BUTTON_WHEEL_UP: 1, MOUSE_BUTTON_WHEEL_DOWN: -1}.get(event.button_index, 0)
    if wheel == 0 or not (event.ctrl_pressed or event.shift_pressed):
        return
    var camera := get_viewport().get_camera_3d()
    if camera == null or ray_hit(camera.project_ray_origin(event.position), camera.project_ray_normal(event.position)).is_empty():
        return
    if event.ctrl_pressed:
        scale_px *= pow(2.0, wheel * 0.125)
    else:
        curve = clampf(curve + wheel * 0.125, 0.0, 1.0)
    place()
    _save()
    get_viewport().set_input_as_handled()

# --- what is drawn over it -------------------------------------------------------------------

## Draw everything under `node` (hands, pointers, panels, ELI) over the desktop, now and as it
## changes: its materials go after the screen, see-through ones keeping their look, solid ones
## drawn in the same pass with their depth so they still hide one another as before.
func keep_in_front(node: Node) -> void:
    if node == null:
        return
    if not _front_roots.has(node):
        _front_roots.append(node)
    for shown in [node] + node.find_children("*", "GeometryInstance3D", true, false):
        if shown is GeometryInstance3D and not is_ancestor_of(shown):
            bring_forward(shown)

func _on_node_added(node: Node) -> void:
    if not (node is GeometryInstance3D) or node == self or is_ancestor_of(node):
        return
    for root in _front_roots:
        if is_instance_valid(root) and (root == node or root.is_ancestor_of(node)):
            bring_forward.call_deferred(node)   # its materials may be given just after it is added
            return

static func bring_forward(shown: GeometryInstance3D) -> void:
    if not is_instance_valid(shown):
        return
    if "render_priority" in shown:          # Label3D, Sprite3D
        shown.set("render_priority", FRONT_PRIORITY)
        if "outline_render_priority" in shown:
            shown.set("outline_render_priority", FRONT_PRIORITY - 1)
    for material in [shown.material_override, shown.material_overlay]:
        _forward(material)
    if shown is MeshInstance3D and shown.mesh:
        for i in shown.mesh.get_surface_count():
            var own: Material = shown.get_surface_override_material(i)
            if own == null and shown.mesh.surface_get_material(i):
                # the mesh's material may be shared with things in the room; this one gets its own
                own = shown.mesh.surface_get_material(i).duplicate()
                shown.set_surface_override_material(i, own)
            _forward(own)

static func _forward(material: Material) -> void:
    while material != null:
        if material is BaseMaterial3D and material.transparency in [BaseMaterial3D.TRANSPARENCY_DISABLED,
                BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, BaseMaterial3D.TRANSPARENCY_ALPHA_HASH]:
            material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
        material.render_priority = FRONT_PRIORITY
        material = material.next_pass

# --- on and off ------------------------------------------------------------------------------

func set_desktop_visible(value: bool) -> void:
    enabled = value
    visible = value
    if value:
        bridge.start()
    else:
        bridge.stop()
    get_tree().root.transparent_bg = _using_layer and value
    _refresh_waiting()

func bridge_status() -> String:
    if not visible:
        return "hidden"
    var state: String = bridge.status_text() if bridge != null else "off"
    return "%s/%s/%s" % [state, capture_backend, "compositor" if _using_layer else "mesh"]
