class_name AppConfig
extends RefCounted

var data: Dictionary = {}
var defaults_path := "res://config/defaults.json"
var project_override_path := "res://config/user.json"
var runtime_path := "user://eli_vr/settings.json"

func load_all() -> void:
    data = _load_json(defaults_path)
    if FileAccess.file_exists(project_override_path):
        data = _deep_merge(data, _load_json(project_override_path))
    if FileAccess.file_exists(runtime_path):
        data = _deep_merge(data, _load_json(runtime_path))
    _apply_cmdline()

func save_runtime() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://eli_vr"))
    var f := FileAccess.open(runtime_path, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(data, "\t"))

func get_value(path: String, fallback = null):
    var cur = data
    for key in path.split("."):
        if typeof(cur) != TYPE_DICTIONARY or not cur.has(key):
            return fallback
        cur = cur[key]
    return cur

func set_value(path: String, value) -> void:
    var keys := path.split(".")
    var cur := data
    for i in range(keys.size() - 1):
        var key: String = keys[i]
        if not cur.has(key) or typeof(cur[key]) != TYPE_DICTIONARY:
            cur[key] = {}
        cur = cur[key]
    cur[keys[-1]] = value

func apply_profile(name: String) -> bool:
    var path := "res://config/profiles/%s.json" % name
    if not FileAccess.file_exists(path):
        return false
    data = _deep_merge(data, _load_json(path))
    return true

func _apply_cmdline() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--eli-room="):
            set_value("world.room", arg.get_slice("=", 1))
        elif arg.begins_with("--eli-environment="):
            set_value("world.environment_override", arg.get_slice("=", 1))
        elif arg.begins_with("--eli-theme="):
            set_value("world.theme", arg.get_slice("=", 1))
        elif arg.begins_with("--eli-quality="):
            apply_profile(arg.get_slice("=", 1))
        elif arg.begins_with("--eli-xr="):
            set_value("xr.mode", arg.get_slice("=", 1))
        elif arg.begins_with("--eli-link="):
            set_value("eli_bridge.enabled", arg.get_slice("=", 1) == "on")
        elif arg.begins_with("--eli-endpoint="):
            set_value("eli_bridge.endpoint", arg.get_slice("=", 1))
        elif arg == "--eli-desktop=off":
            set_value("desktop.enabled", false)
        elif arg == "--eli-desktop=on":
            set_value("desktop.enabled", true)

func _load_json(path: String) -> Dictionary:
    var f := FileAccess.open(path, FileAccess.READ)
    if not f:
        push_error("ELI VR: cannot read %s" % path)
        return {}
    var parsed = JSON.parse_string(f.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("ELI VR: invalid JSON object in %s" % path)
        return {}
    return parsed

func _deep_merge(base: Dictionary, override: Dictionary) -> Dictionary:
    var out := base.duplicate(true)
    for key in override.keys():
        if out.has(key) and typeof(out[key]) == TYPE_DICTIONARY and typeof(override[key]) == TYPE_DICTIONARY:
            out[key] = _deep_merge(out[key], override[key])
        else:
            out[key] = override[key]
    return out
