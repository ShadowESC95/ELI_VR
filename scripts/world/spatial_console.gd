class_name SpatialConsole
extends Node3D

const Interactable3DClass = preload("res://scripts/world/interactable_3d.gd")
const MovablePanelClass = preload("res://scripts/world/movable_panel_3d.gd")

var app: Node
var accent: Color = Color("#63ddff")
var surface: Color = Color("#08131b")
var panels: Dictionary = {}
var desktop_workspace: bool = false

func setup(p_app: Node, registry, config) -> void:
    app = p_app
    var theme: Dictionary = registry.theme(str(config.get_value("world.theme", "frontier")))
    accent = Color(str(theme.get("accent", "#63ddff")))
    surface = Color(str(theme.get("surface", "#08131b")))

    _build_panel("ROOMS", "RoomsPanel", Vector3(-2.35, 1.30, -3.10), -16.0, [
        ["CORE","room","core_room"],["WORKSHOP","room","workshop"],["REFLECT","room","reflection_chamber"],
        ["MEMORY","room","memory_archive"],["DEBUG","room","debug_basement"],["UPGRADE","room","upgrade_bay"],
        ["SIM LAB","room","simulation_lab"],["ANOMALY","room","anomaly_room"],["EVIDENCE","room","evidence_wall"],
        ["ELI'S ROOM","room","own_room"],["ELI: BUILD","eli","compose"],["UNDO","eli","undo"]
    ], 3)

    _build_panel("ENVIRONMENTS", "EnvironmentsPanel", Vector3(0.0, 1.30, -3.30), 0.0, [
        ["MOUNTAINS","environment","mountain_observatory"],["FOREST","environment","forest_sanctuary"],
        ["OCEAN","environment","ocean_platform"],["DEEP SPACE","environment","deep_space"],
        ["DIGITAL","environment","digital_matrix"],["ARCTIC","environment","arctic_aurora"],
        ["DESERT","environment","desert_observatory"],["UNDERWATER","environment","underwater_lab"]
    ], 2)

    _build_panel("VISUAL / SYSTEM", "VisualPanel", Vector3(2.35, 1.30, -3.10), 16.0, [
        ["BLUE","theme","frontier"],["BLACK","theme","obsidian"],["PURPLE","theme","nebula"],
        ["GREEN","theme","emerald"],["ORANGE","theme","solar"],["CYAN","theme","abyssal"],
        ["ICE BLUE","theme","aurora"],["WHITE","theme","monolith"],["AUTO","quality","auto"],
        ["LOW","quality","low"],["MEDIUM","quality","medium"],["HIGH","quality","high"],
        ["ULTRA","quality","ultra"],["DESKTOP","toggle","desktop"],["HUD","toggle","hud"],
        ["RESET UI","system","reset_workspace"],["EXIT","system","exit"]
    ], 4)

# ELI's mind: the models he has, by his own list. The one in use is marked.
# Pressing another has him load it. Nothing is listed until he has said.
func show_mind(models: Array, current: String, loaded: bool) -> void:
    if panels.has("MindPanel"):
        panels["MindPanel"].queue_free()
        panels.erase("MindPanel")
    if models.is_empty():
        return
    var buttons := []
    for model in models.slice(0, 8):
        var model_name := str(model.get("name", ""))
        var shown := model_name.trim_suffix(".gguf").left(30)
        var mark := ("> " if loaded else "~ ") if model_name == current else ""
        buttons.append(["%s%s  %.1f GB" % [mark, shown, float(model.get("size_gb", 0.0))], "eli_model", model_name])
    _build_panel("ELI'S MIND", "MindPanel", Vector3(-3.6, 1.45, -1.3), 66.0, buttons, 1, 2.9)
    set_desktop_workspace(desktop_workspace)

func _build_panel(
    title: String,
    panel_name: String,
    pos: Vector3,
    yaw_deg: float,
    buttons: Array,
    cols: int,
    cell: float = 1.06
) -> void:
    var rows: int = int(ceil(float(buttons.size()) / float(cols)))
    var width: float = float(cols) * cell + 0.32
    var height: float = float(rows) * 0.40 + 0.76

    var panel = MovablePanelClass.new()
    panel.name = panel_name
    panel.position = pos
    panel.rotation_degrees.y = yaw_deg
    panel.setup_panel(Vector2(width, height), accent)
    add_child(panel)
    panels[panel_name] = panel

    var bg: MeshInstance3D = MeshInstance3D.new()
    var box: BoxMesh = BoxMesh.new()
    box.size = Vector3(width, height, 0.055)
    bg.mesh = box
    bg.position = Vector3(0.0, -float(rows) * 0.20 + 0.13, 0.08)

    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.albedo_color = Color(surface.r, surface.g, surface.b, 0.96)
    mat.metallic = 0.42
    mat.roughness = 0.24
    mat.emission_enabled = true
    mat.emission = accent * 0.045
    bg.material_override = mat
    panel.add_child(bg)

    var rail: MeshInstance3D = MeshInstance3D.new()
    var rail_mesh: BoxMesh = BoxMesh.new()
    rail_mesh.size = Vector3(float(cols) * cell + 0.08, 0.022, 0.028)
    rail.mesh = rail_mesh
    rail.position = Vector3(0.0, 0.35, 0.125)
    var rail_mat: StandardMaterial3D = StandardMaterial3D.new()
    rail_mat.albedo_color = accent
    rail_mat.emission_enabled = true
    rail_mat.emission = accent
    rail_mat.emission_energy_multiplier = 1.8
    rail.material_override = rail_mat
    panel.add_child(rail)

    var label: Label3D = Label3D.new()
    label.text = "ELI VR // %s" % title
    label.font_size = 31
    label.modulate = accent
    label.position = Vector3(0.0, 0.49, 0.15)
    label.no_depth_test = true
    panel.add_child(label)

    var hint: Label3D = Label3D.new()
    hint.text = "GRIP PANEL TO MOVE  •  STICK Y DISTANCE  •  STICK X ROTATE"
    hint.font_size = 17
    hint.pixel_size = 0.0010
    hint.modulate = Color("#9fb4c0")
    hint.position = Vector3(0.0, 0.405, 0.15)
    hint.no_depth_test = true
    panel.add_child(hint)

    for i in range(buttons.size()):
        var row: int = int(i / cols)
        var col: int = i % cols
        var b = Interactable3DClass.new()
        b.setup(
            str(buttons[i][0]),
            str(buttons[i][1]),
            str(buttons[i][2]),
            accent,
            Vector2(cell - 0.10, 0.30)
        )
        b.position = Vector3(
            (float(col) - float(cols - 1) * 0.5) * (cell - 0.02),
            -0.04 - float(row) * 0.39,
            0.15
        )
        b.activated.connect(_on_action)
        panel.add_child(b)

func set_desktop_workspace(enabled: bool) -> void:
    desktop_workspace = enabled
    # Heights are set so the lowest row of buttons clears the floor, and with
    # the desktop on, so the top stays under the line of sight to its screen.
    if enabled:
        _place_panel("RoomsPanel", Vector3(-2.05, 1.20, -2.80), -18.0)
        _place_panel("EnvironmentsPanel", Vector3(0.0, 1.20, -2.95), 0.0)
        _place_panel("VisualPanel", Vector3(2.40, 1.20, -2.80), 18.0)
        _place_panel("MindPanel", Vector3(-3.6, 1.20, -1.3), 66.0)
    else:
        _place_panel("MindPanel", Vector3(-3.6, 1.45, -1.3), 66.0)
        _place_panel("RoomsPanel", Vector3(-2.05, 1.45, -3.10), -16.0)
        _place_panel("EnvironmentsPanel", Vector3(0.0, 1.45, -3.30), 0.0)
        _place_panel("VisualPanel", Vector3(2.40, 1.45, -3.10), 16.0)

func reset_layout() -> void:
    set_desktop_workspace(desktop_workspace)

func _place_panel(panel_name: String, pos: Vector3, yaw_deg: float) -> void:
    if not panels.has(panel_name):
        return
    var panel: Node3D = panels[panel_name] as Node3D
    panel.position = pos
    panel.rotation = Vector3(0.0, deg_to_rad(yaw_deg), 0.0)
    panel.scale = Vector3.ONE * 0.62

func _on_action(kind: String, value: String) -> void:
    if app and app.has_method("apply_console_action"):
        app.apply_console_action(kind, value)
