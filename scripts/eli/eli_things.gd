class_name EliThings
extends Node3D

# What ELI has put in the rooms. His world says what stands where and how it
# looks; this draws the ones in the room you are in, brings a new one up out
# of the floor, follows a change, and lets one go when he takes it away.

signal moved_by_hand(thing_id: String, position: Vector3)

const ThingClass = preload("res://scripts/eli/eli_thing.gd")
# The mobile renderer lights a mesh with eight lamps at most, and the rooms
# have their own. Only the brightest few of ELI's things carry a real light.
const MAX_LAMPS := 4

var room := ""
var _things: Dictionary = {}       # id -> EliThing
var _last: Array = []

func show_room(room_id: String) -> void:
    if room_id == room:
        return
    room = room_id
    for thing in _things.values():
        thing.queue_free()
    _things.clear()
    _apply(_last)

func apply_world_state(state: Dictionary) -> void:
    _last = state.get("objects", [])
    _apply(_last)

func standing() -> Array:
    return _things.values().filter(func(t): return is_instance_valid(t))

# The nearest of them to a point, as ELI is told of them.
func near(point: Vector3, limit: int) -> Array:
    var all := standing()
    all.sort_custom(func(a, b): return a.global_position.distance_to(point) < b.global_position.distance_to(point))
    var out := []
    for thing in all.slice(0, limit):
        out.append({"name": thing.label, "kind": thing.shape,
                    "distance": snappedf(thing.global_position.distance_to(point), 0.1)})
    return out

func _apply(objects: Array) -> void:
    var seen := {}
    for data in objects:
        if typeof(data) != TYPE_DICTIONARY or str(data.get("room", "")) != room:
            continue
        if not data.has("form"):
            continue                # an ELI v3 that does not say how things look
        var id := str(data.get("id", ""))
        seen[id] = true
        if _things.has(id) and is_instance_valid(_things[id]):
            _things[id].refresh(data)
        else:
            var thing = ThingClass.new()
            add_child(thing)
            thing.build(data)
            thing.let_go.connect(_on_let_go)
            _things[id] = thing
    for id in _things.keys():
        if not seen.has(id):
            if is_instance_valid(_things[id]):
                _things[id].leave()
            _things.erase(id)
    _share_lamps()

func _share_lamps() -> void:
    var lit := standing().filter(func(t): return t.lamp != null)
    lit.sort_custom(func(a, b): return a.glow > b.glow)
    for i in lit.size():
        lit[i].lamp.visible = i < MAX_LAMPS

func _on_let_go(thing) -> void:
    moved_by_hand.emit(thing.thing_id, thing.position)
