class_name EliProps
extends RefCounted

# The real things ELI VR can draw (assets/models/, each measured by tools/measure_models.gd), as
# ELI is told of them: an id, what it is in plain words, and its size in metres [wide, tall, deep].
# ELI places them by id; a thing whose form names one is drawn as that model.

const LISTED := "res://assets/models/models.json"

static func catalogue() -> Array:
    var listed = JSON.parse_string(FileAccess.get_file_as_string(LISTED))
    if typeof(listed) != TYPE_DICTIONARY:
        return []
    var out := []
    for id in listed:
        var entry: Dictionary = listed[id]
        var size = entry.get("size", [])
        if typeof(size) != TYPE_ARRAY or size.size() != 3:
            continue
        out.append({"id": id, "name": plain(str(entry.get("name", id))), "size": size})
    var had := {}
    for entry in out:
        had[entry["id"]] = true
    for entry in EliModels.catalogue():      # ELI's own, fetched from ELI v3
        if not had.has(entry["id"]):
            out.append(entry)
    return out

# "Arm Chair 01" -> "arm chair": what a thing is, without the catalogue's numbering.
static func plain(name: String) -> String:
    var words := Array(name.to_lower().replace("_", " ").split(" ", false)).filter(func(w): return not w.is_valid_int())
    return " ".join(words)

static func model(id: String) -> PackedScene:
    if id.is_empty() or not id.is_valid_filename():
        return null
    return ModelCache.scene(id)
