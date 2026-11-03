class_name ModelCache
extends RefCounted

# The real models (assets/models/), loaded once and kept for as long as ELI VR runs. A room that is
# taken down lets go of its models, and without a hold on them Godot read every one from disk again
# the next time a room used it: changing rooms stalled for up to a second. warm() starts them all
# loading on worker threads at start, so a room built later only places copies.

static var _held := {}                  # path -> PackedScene
static var _asked := {}                 # path -> true, while it loads in the background
static var _queue: Array = []           # paths still to start, one after another

static func path_of(model: String) -> String:
    return "res://assets/models/%s/%s_1k.gltf" % [model, model]

## Lines every listed model up to load in the background, one at a time (all at once filled every
## worker thread and the first frame after waited on one for ever). Safe to call more than once.
static func warm() -> void:
    var listed = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/models.json"))
    if typeof(listed) != TYPE_DICTIONARY:
        return
    for model in listed:
        var path := path_of(str(model))
        if not _held.has(path) and not _asked.has(path) and not path in _queue and ResourceLoader.exists(path):
            _queue.append(path)

## Takes in the models that have finished loading. Called every frame while any are on their way;
## never waits, so a load that needs the main thread is never stuck behind it.
static func poll() -> int:
    if _asked.is_empty() and not _queue.is_empty():
        var next: String = _queue.pop_front()
        if ResourceLoader.load_threaded_request(next, "PackedScene", false) == OK:
            _asked[next] = true
    var left := _queue.size()
    for path in _asked.keys():
        var status := ResourceLoader.load_threaded_get_status(path)
        if status == ResourceLoader.THREAD_LOAD_LOADED:
            var got: Resource = ResourceLoader.load_threaded_get(path)
            if got is PackedScene:
                _held[path] = got
            _asked.erase(path)
        elif status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
            left += 1
        else:
            _asked.erase(path)
    return left

## The model by name, from what is held. One not here yet (never asked for, or still on its way) is
## loaded now, on its own, rather than waited for. null when there is no such model.
static func scene(model: String) -> PackedScene:
    var path := path_of(model)
    if _held.has(path):
        return _held[path]
    if not ResourceLoader.exists(path):
        return null
    _queue.erase(path)                  # wanted now: not left waiting its turn
    var got: Resource = ResourceLoader.load(path, "PackedScene",
        ResourceLoader.CACHE_MODE_IGNORE if _asked.has(path) else ResourceLoader.CACHE_MODE_REUSE)
    if got is PackedScene:
        if not _asked.has(path):
            _held[path] = got
        return got
    return null
