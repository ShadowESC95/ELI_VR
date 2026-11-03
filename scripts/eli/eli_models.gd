class_name EliModels
extends RefCounted

# ELI's own models: real things ELI brought into its rooms that ELI VR did not come with, fetched
# from ELI v3 (GET /v1/world/model/<id>/<file>, as the world feed's `models` lists them) into a
# folder of ELI VR's own, loaded while running (GLTFDocument), measured, and told back to ELI with
# their real size. Fetched once each; the files stay for next time.

const FOLDER := "user://eli_vr/models"
const MANIFEST := FOLDER + "/models.json"

static var link: Node                   # the EliLink, set when the app makes it
static var _listed := {}                # id -> {name, size, files, source, licence, measured}
static var _read := false
static var _fetching := false
static var _wanted: Array = []          # the feed's models, newest list wins

## What is here, by id.
static func listed() -> Dictionary:
    if not _read:
        _read = true
        var data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
        _listed = data if typeof(data) == TYPE_DICTIONARY else {}
    return _listed

## As ELI is told of them, beside the bundled ones: id, plain name and size in metres.
static func catalogue() -> Array:
    var out := []
    for id in listed():
        var entry: Dictionary = listed()[id]
        if path_of(id).is_empty():
            continue
        out.append({"id": id, "name": EliProps.plain(str(entry.get("name", id))), "size": entry.get("size", [1, 1, 1])})
    return out

## The model's glTF, when it is here; "" otherwise.
static func path_of(id: String) -> String:
    var entry: Dictionary = listed().get(id, {})
    var files: Array = entry.get("files", [])
    if files.is_empty() or not id.is_valid_filename():
        return ""
    var path := "%s/%s/%s" % [FOLDER, id, str(files[0])]
    return path if FileAccess.file_exists(path) else ""

## Load one while running. Its size is measured the first time and kept.
static func load_scene(id: String) -> PackedScene:
    var path := path_of(id)
    if path.is_empty():
        return null
    var doc := GLTFDocument.new()
    var state := GLTFState.new()
    if doc.append_from_file(ProjectSettings.globalize_path(path), state) != OK:
        push_warning("ELI VR: the model %s could not be read" % id)
        return null
    var node := doc.generate_scene(state)
    if node == null:
        return null
    var entry: Dictionary = listed()[id]
    if not bool(entry.get("measured", false)):
        var box := bounds(node)
        if box.size.length() > 0.0:
            entry["size"] = [snappedf(box.size.x, 0.01), snappedf(box.size.y, 0.01), snappedf(box.size.z, 0.01)]
            entry["measured"] = true
            _save()
    var packed := PackedScene.new()
    packed.pack(node)
    node.free()
    return packed

static func bounds(node: Node, xf: Transform3D = Transform3D.IDENTITY, found: Array = [null]) -> AABB:
    var here := xf
    if node is Node3D:
        here = xf * (node as Node3D).transform
    if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
        var box: AABB = here * (node as MeshInstance3D).mesh.get_aabb()
        found[0] = box if found[0] == null else (found[0] as AABB).merge(box)
    for child in node.get_children():
        bounds(child, here, found)
    return found[0] if found[0] != null else AABB()

## The feed said which models ELI has: fetch the ones not here, one file at a time, then tell ELI
## their measured sizes. Called with every world message; a fetch already going on finishes first.
static func want(models: Array) -> void:
    _wanted = models
    if _fetching or link == null or not link.can("models"):
        return
    _fetching = true
    var brought := 0
    while true:
        var next := _missing()
        if next.is_empty():
            break
        if await _fetch(next):
            brought += 1
        else:
            _listed[str(next.get("id"))] = {"failed": true}      # not asked for again this run
    _fetching = false
    if brought > 0:
        _save()
        ModelCache.forget_user_models()
        if link.has_method("report_body"):
            link.report_body()
        for things in Engine.get_main_loop().get_nodes_in_group("eli_things") if Engine.get_main_loop() is SceneTree else []:
            things.redraw_props()

static func _missing() -> Dictionary:
    for entry in _wanted:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var id := str(entry.get("id", ""))
        if id.is_empty() or not id.is_valid_filename() or listed().has(id):
            continue
        if typeof(entry.get("files")) == TYPE_ARRAY and not entry["files"].is_empty():
            return entry
    return {}

static func _fetch(entry: Dictionary) -> bool:
    var id := str(entry["id"])
    var folder := "%s/%s" % [FOLDER, id]
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
    var files := []
    for rel in entry["files"]:
        var path := str(rel).replace("\\", "/")
        if path.is_empty() or path.begins_with("/") or ".." in path.split("/"):
            continue
        var got = await link.fetch("/v1/world/model/%s/%s" % [id, path], "models")
        if not got.ok:
            print("ELI VR MODELS: %s could not be fetched (%s)" % [id, got.sentence()])
            return false
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder.path_join(path).get_base_dir()))
        var file := FileAccess.open(folder.path_join(path), FileAccess.WRITE)
        if file == null:
            return false
        file.store_buffer(got.payload)
        file.close()
        files.append(path)
    if files.is_empty():
        return false
    _listed[id] = {"name": str(entry.get("name", id)), "size": entry.get("size", [1, 1, 1]), "files": files,
                   "source": str(entry.get("source", "")), "licence": str(entry.get("licence", "")), "measured": false}
    print("ELI VR MODELS: brought in %s (%s)" % [id, _listed[id]["name"]])
    return true

static func _save() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
    var kept := {}
    for id in _listed:
        if not bool(_listed[id].get("failed", false)):
            kept[id] = _listed[id]
    var file := FileAccess.open(MANIFEST, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(kept, "\t"))
