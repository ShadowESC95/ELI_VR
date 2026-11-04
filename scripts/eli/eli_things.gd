class_name EliThings
extends Node3D

# What ELI has put in the rooms. Its world says what stands where and how it
# looks; this draws the ones in the room you are in, brings a new one up out
# of the floor, follows a change, and lets one go when ELI takes it away.

signal moved_by_hand(thing_id: String, position: Vector3)
# ELI made a new thing here, or changed how one looks: it goes and does it where you can see.
# Not sent for what was already standing when you came in.
signal appeared(thing)
signal changed(thing)
# A piece of a game taken in the hand, and one let go (EliPlay runs the game on them).
signal taken(thing)
signal dropped(thing)

const ThingClass = preload("res://scripts/eli/eli_thing.gd")
# The mobile renderer lights a mesh with eight lamps at most, and the rooms
# have their own. Only the brightest few of ELI's things carry a real light.
const MAX_LAMPS := 4

var room := ""
# The room as built: it may keep places for kinds of record (RoomBase.pin_spot).
var pinner: Node
var _things: Dictionary = {}       # id -> EliThing
var _last: Array = []
var _forms: Dictionary = {}        # id -> its form as last drawn
var _games: Dictionary = {}        # id -> the game object ELI's world set in this room (not drawn: EliPlay)
var _settled := false              # the room's things as you found them are drawn

func _ready() -> void:
    add_to_group("eli_things")

## ELI's own models have arrived: a thing drawn as an orb for want of its model is drawn again.
func redraw_props() -> void:
    for id in _things:
        var thing = _things[id]
        if is_instance_valid(thing) and not str(thing.prop).is_empty() and thing.shape == "orb":
            thing.shape = "prop"
            thing._shape()

func show_room(room_id: String) -> void:
    if room_id == room:
        return
    room = room_id
    for thing in _things.values():
        thing.queue_free()
    _things.clear()
    _forms.clear()
    _games.clear()
    _settled = false
    _apply(_last)

func apply_world_state(state: Dictionary) -> void:
    _last = state.get("objects", [])
    _apply(_last)

## The things standing in sight: a piece of a game that is not up yet, or has been hit, is not.
func standing() -> Array:
    return _things.values().filter(func(t): return is_instance_valid(t) and not t.is_gone())

## The game ELI's world has set in this room, as it sent it; {} when there is none.
func game_here() -> Dictionary:
    for data in _games.values():
        if str(data.get("status", "")) != "done":
            return data
    return {}

## The pieces (and mats) of a game, by their index in it, up or not.
func pieces_of(game_id: String) -> Array:
    var out := _things.values().filter(func(t): return is_instance_valid(t) and str(t.piece.get("game", "")) == game_id)
    out.sort_custom(func(a, b): return int(a.piece.get("index", 0)) < int(b.piece.get("index", 0)))
    return out

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
    var counted := {}              # kind -> how many of that kind are placed so far
    var games_here := {}
    for data in objects:
        if typeof(data) != TYPE_DICTIONARY or str(data.get("room", "")) != room:
            continue
        if not data.has("form"):
            continue                # an ELI v3 that does not say how things look
        var id := str(data.get("id", ""))
        if str(data.get("kind", "")) == "game":
            games_here[id] = data   # the rules: EliPlay's, not a thing to draw
            continue
        seen[id] = true
        var form := JSON.stringify(data.get("form", {}))
        if _things.has(id) and is_instance_valid(_things[id]):
            _things[id].refresh(data)
            if _settled and _forms.get(id, form) != form:
                changed.emit(_things[id])
        else:
            var thing = ThingClass.new()
            add_child(thing)
            thing.build(data)
            thing.let_go.connect(_on_let_go)
            thing.taken.connect(func(t): taken.emit(t))
            _things[id] = thing
            if _settled and thing.piece.is_empty():
                appeared.emit(thing)        # a piece of a game is the game's to bring up
        _forms[id] = form
        var record := str(data.get("kind", ""))
        if pinner != null and is_instance_valid(pinner) and pinner.has_method("pin_spot"):
            var spot = pinner.pin_spot(record, int(counted.get(record, 0)))
            if spot is Transform3D:
                _things[id].pin_to(spot)
        counted[record] = int(counted.get(record, 0)) + 1
    for id in _things.keys():
        if not seen.has(id):
            if is_instance_valid(_things[id]):
                _things[id].leave()
            _things.erase(id)
            _forms.erase(id)
    _games = games_here
    _share_lamps()
    # what an ELI that says how things look sent first is what was here before you came
    if objects.any(func(o): return typeof(o) == TYPE_DICTIONARY and o.has("form")):
        _settled = true

func _share_lamps() -> void:
    var lit := standing().filter(func(t): return t.lamp != null)
    lit.sort_custom(func(a, b): return a.glow > b.glow)
    for i in lit.size():
        lit[i].lamp.visible = i < MAX_LAMPS

func _on_let_go(thing) -> void:
    if thing.piece.is_empty():
        moved_by_hand.emit(thing.thing_id, thing.position)
    else:
        dropped.emit(thing)             # a piece of a game: the game says what that means, not ELI's world
