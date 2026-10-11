class_name EliRegistry
extends RefCounted

var rooms: Dictionary = {}
var environments: Dictionary = {}
var themes: Dictionary = {}

func load_all() -> void:
    rooms = _load("res://config/rooms/rooms.json")
    environments = _load("res://config/rooms/environments.json")
    themes = _load("res://config/themes/themes.json")

func room_ids() -> Array:
    var ids := rooms.keys()
    ids.sort()
    return ids

func environment_ids() -> Array:
    var ids := environments.keys()
    ids.sort()
    return ids

func theme_ids() -> Array:
    var ids := themes.keys()
    ids.sort()
    return ids

func room(id: String) -> Dictionary:
    return rooms.get(id, {})

func environment(id: String) -> Dictionary:
    return environments.get(id, {})

func theme(id: String) -> Dictionary:
    return themes.get(id, themes.get("cyan", {}))

func _load(path: String) -> Dictionary:
    var f := FileAccess.open(path, FileAccess.READ)
    if not f:
        push_error("ELI VR registry missing: %s" % path)
        return {}
    var parsed = JSON.parse_string(f.get_as_text())
    return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
