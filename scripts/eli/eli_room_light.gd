class_name EliRoomLight
extends Node

# ELI gave the room you are in a new light: ELI goes up and does it where you can see.
signal relit

# A room ELI has relit. ELI's world keeps the light ELI chose for each room of the house (eli/world/
# building.py in ELI v3); that colour is the room's own from then on, worn by its glowing fixtures:
# the trims, strips, screens and points of light it was built with. Nothing else changes: not the
# air, not the ambient light, not the sky. How ELI feels shows on ELI itself (eli_presence.gd).
# ELI's own room draws its whole mood itself (own_room.gd).

var _app: Node
var _room: Node              # the first part of the room the fixtures below belong to
var _moods := {}             # room id -> the mood ELI's world keeps for it
var _worn := ""              # the light the fixtures wear now, "" for their own
var _glows: Array = []       # [StandardMaterial3D, its own emission colour]
var _strips: Array = []      # [StandardMaterial3D, its own colour]: unlit surfaces that are lights
var _halos: Array = []       # [ShaderMaterial, its own tint]: the soft points of light

func setup(app: Node) -> void:
    _app = app

## What ELI's world says now. Only the rooms of the house ELI relit are kept.
func apply_world_state(state: Dictionary) -> void:
    var spaces: Dictionary = state.get("spaces", {})
    _moods.clear()
    for room in spaces:
        var space = spaces[room]
        if room != "own_room" and typeof(space) == TYPE_DICTIONARY and typeof(space.get("mood")) == TYPE_DICTIONARY:
            _moods[room] = space["mood"]
    _refresh()

## The room as it stands: what the room factory built, without what it is letting go of.
func _built() -> Array:
    var root = _app.get("room_root") if _app != null else null
    if root == null:
        return []
    return (root as Node).get_children().filter(func(n): return not n.is_queued_for_deletion())

func _process(_delta: float) -> void:
    var parts := _built()
    var room: Node = parts[0] if not parts.is_empty() else null
    if room != _room:
        _wear("")
        _room = room
        _collect()
        _refresh()

func _refresh() -> void:
    if _app == null:
        return
    var mood: Dictionary = _moods.get(str(_app.call("current_room_id")), {})
    var before := _worn
    _wear(str(mood.get("light", "")))
    if _room != null and _worn != before:
        relit.emit()

func _collect() -> void:
    _glows.clear()
    _strips.clear()
    _halos.clear()
    var seen := {}
    var found: Array = []
    for part in _built():
        if part is GeometryInstance3D:
            found.append(part)
        found.append_array(part.find_children("*", "GeometryInstance3D", true, false))
    for node in found:
        var mats: Array = [(node as GeometryInstance3D).material_override]
        if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
            for i in (node as MeshInstance3D).mesh.get_surface_count():
                mats.append((node as MeshInstance3D).get_active_material(i))
        for m in mats:
            if m == null or seen.has(m.get_instance_id()):
                continue
            seen[m.get_instance_id()] = true
            var std := m as StandardMaterial3D
            if std != null and std.emission_enabled:
                _glows.append([std, std.emission])
            elif std != null and std.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED \
                    and maxf(std.albedo_color.r, maxf(std.albedo_color.g, std.albedo_color.b)) > 1.0:
                _strips.append([std, std.albedo_color])      # brighter than white: a light, not a label
            var shader_mat := m as ShaderMaterial
            if shader_mat != null and shader_mat.get_shader_parameter("tint") is Vector3:
                _halos.append([shader_mat, shader_mat.get_shader_parameter("tint")])

## Put the fixtures in `light` (a colour), or back in their own with "".
func _wear(light: String) -> void:
    if light == _worn:
        return
    _worn = light
    var lit := light != ""
    var chosen := Color(light) if lit else Color.WHITE
    for g in _glows:
        if is_instance_valid(g[0]):
            (g[0] as StandardMaterial3D).emission = chosen if lit else g[1]
    for st in _strips:
        if is_instance_valid(st[0]):
            var own: Color = st[1]
            var bright := maxf(own.r, maxf(own.g, own.b))
            (st[0] as StandardMaterial3D).albedo_color = \
                Color(chosen.r * bright, chosen.g * bright, chosen.b * bright, own.a) if lit else own
    for h in _halos:
        if is_instance_valid(h[0]):
            (h[0] as ShaderMaterial).set_shader_parameter("tint", Vector3(chosen.r, chosen.g, chosen.b) if lit else h[1])

func _exit_tree() -> void:
    _wear("")
