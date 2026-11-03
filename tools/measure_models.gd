extends SceneTree

# Measures every model in assets/models/ and writes its real size, [wide, tall, deep] in metres,
# into assets/models/models.json, so ELI VR can tell ELI what each thing is and how big it is
# without loading them all at start. Run after tools/prepare_models.py:
#
#     godot --headless --path . --script tools/measure_models.gd

const LISTED := "res://assets/models/models.json"

func _bounds(node: Node, xf: Transform3D, found: Array) -> void:
    var here := xf
    if node is Node3D:
        here = xf * (node as Node3D).transform
    if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
        var box: AABB = here * (node as MeshInstance3D).mesh.get_aabb()
        found[0] = box if found[0] == null else (found[0] as AABB).merge(box)
    for child in node.get_children():
        _bounds(child, here, found)

func _init() -> void:
    var listed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LISTED))
    var measured := 0
    for model in listed.keys():
        var scene := load("res://assets/models/%s/%s_1k.gltf" % [model, model]) as PackedScene
        if scene == null:
            push_warning("no model %s" % model)
            continue
        var node := scene.instantiate()
        var found := [null]
        _bounds(node, Transform3D.IDENTITY, found)
        node.free()
        if found[0] == null:
            continue
        var size: Vector3 = (found[0] as AABB).size
        listed[model]["size"] = [snappedf(size.x, 0.01), snappedf(size.y, 0.01), snappedf(size.z, 0.01)]
        for key in listed[model].keys():
            var value = listed[model][key]
            if typeof(value) == TYPE_FLOAT and value == floorf(value) and key != "size":
                listed[model][key] = int(value)      # JSON gives every number back as a float
        measured += 1
    var keys := listed.keys()
    keys.sort()
    var ordered := {}
    for key in keys:
        ordered[key] = listed[key]
    var out := FileAccess.open(LISTED, FileAccess.WRITE)
    out.store_string(JSON.stringify(ordered, " ", false) + "\n")
    out.close()
    print("measured %d models" % measured)
    quit()
