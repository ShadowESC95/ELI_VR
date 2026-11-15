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
const ArmClass = preload("res://scripts/eli/eli_arm.gd")
const BookClass = preload("res://scripts/eli/eli_book.gd")
# The mobile renderer lights a mesh with eight lamps at most, and the rooms
# have their own. Only the brightest few of ELI's things carry a real light.
const MAX_LAMPS := 4
## The share of a frame given to bringing books in and putting the writing on those that have come
## within reading distance. A frame is as long as the display's refresh (the physics tick follows
## the headset's: RuntimeOptimizer), so what is done in one never costs the headset a frame.
const BOOKS_SHARE := 0.2

var room := ""
# The room as built: it may keep places for kinds of record (RoomBase.pin_spot).
var pinner: Node
var _things: Dictionary = {}       # id -> EliThing
var _last: Array = []
var _forms: Dictionary = {}        # id -> its form as last drawn
var _games: Dictionary = {}        # id -> the game object ELI's world set in this room (not drawn: EliPlay)
var _settled := false              # the room's things as you found them are drawn
var _said: Dictionary = {}         # id -> what its record said when it was last drawn, as one number
var _placed: Dictionary = {}       # id -> the place the room last gave it, or null
var _coming: Array = []            # books still to be brought in: [record, its place, announce, what it says]
var _unwritten: Array = []         # books whose cover and spine are not written yet
var _read_from := Vector3.INF      # where the eye was when they were last looked over
var _to_write: Array = []          # those within reading distance, the nearest last: [distance squared, book]

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
    _said.clear()
    _placed.clear()
    _unwritten.clear()
    _to_write.clear()
    _coming.clear()
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

## The record of ELI's the user holds in a hand (a thought, a belief, a memory, a finding), as ELI is
## told of it with the scene; {} when they hold none, or hold a thing that is not a record.
func held_record() -> Dictionary:
    for thing in _things.values():
        if is_instance_valid(thing) and thing.held():
            var record: Dictionary = thing.record()
            if not record.is_empty():
                return record
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
    # this room's records, and what each says as one number (hashed in the engine): ELI's world
    # sends every record of every room again whenever any one changes, so a record that says what
    # it said last time is left as it stands. Where it stands is still asked of the room each
    # time: a room may keep its places by more than the records themselves.
    var mine := []
    var says := []
    for data in objects:
        if typeof(data) == TYPE_DICTIONARY and str(data.get("room", "")) == room:
            mine.append(data)
            says.append(data.hash())

    var seen := {}
    var counted := {}              # kind -> how many of that kind are placed so far
    var games_here := {}
    var order := _arranged(mine)
    # with someone there to see, books are brought in a frame's share at a time (_process): they
    # come by the hundred, and nothing waits on one being there. Everything else is made at once,
    # as a game and ELI's own moves act on it in the same frame; so are books when no eye is there.
    var eye := get_viewport().get_camera_3d() if is_inside_tree() else null
    _coming.clear()
    for i in mine.size():
        var data: Dictionary = mine[i]
        if not data.has("form"):
            continue                # an ELI v3 that does not say how things look
        var id := str(data.get("id", ""))
        var record := str(data.get("kind", ""))
        if record == "game":
            games_here[id] = data   # the rules: EliPlay's, not a thing to draw
            continue
        seen[id] = true
        var place := int(order.get(id, counted.get(record, 0)))
        counted[record] = int(counted.get(record, 0)) + 1
        var known: bool = _things.has(id) and is_instance_valid(_things[id])
        if not known and eye != null and BookClass.is_book(data):
            _coming.append([data, place, _settled, says[i]])
            continue
        # a record that says what it said last time is left as it stands
        var same: bool = known and _said.get(id) == says[i]
        if not known:
            _make(data, _settled)
        elif not same:
            var form := JSON.stringify(data.get("form", {}))
            _things[id].refresh(data)
            if _settled and _forms.get(id, form) != form:
                changed.emit(_things[id])
            _forms[id] = form
            _to_be_written(_things[id])     # a book that says something new has a bare cover again
        _said[id] = says[i]
        _put(id, record, place, same)
    for id in _things.keys():
        if not seen.has(id):
            if is_instance_valid(_things[id]):
                _things[id].leave()
            _things.erase(id)
            _forms.erase(id)
            _said.erase(id)
            _placed.erase(id)
    _games = games_here
    _share_lamps()
    # what an ELI that says how things look sent first is what was here before you came
    if mine.any(func(o): return o.has("form")):
        _settled = true

# A record ELI's world placed here, made as the thing it is. `announce`: it came while you were
# here (not what stood here when you came in), so ELI goes and does it where you can see.
func _make(data: Dictionary, announce: bool) -> void:
    var id := str(data.get("id", ""))
    var form_of: Dictionary = data.get("form", {})
    var thing = ArmClass.new() if str(form_of.get("shape", "")) == "arm" else (
        BookClass.new() if BookClass.is_book(data) else ThingClass.new())
    add_child(thing)
    thing.build(data)
    thing.let_go.connect(_on_let_go)
    thing.taken.connect(func(t): taken.emit(t))
    _things[id] = thing
    _forms[id] = JSON.stringify(form_of)
    _placed.erase(id)
    _to_be_written(thing)
    if announce and thing.piece.is_empty():
        appeared.emit(thing)            # a piece of a game is the game's to bring up

# A book whose cover and spine are bare is kept among those looked over as the eye moves.
func _to_be_written(thing) -> void:
    if thing.has_method("is_written") and not thing.is_written() and not thing in _unwritten:
        _unwritten.append(thing)
        _read_from = Vector3.INF        # looked over again, this one with them

# Stand a record in the place the room keeps for the `place`th of its kind, or where ELI's world
# says when the room keeps none. The same record in the same place is not put there again.
func _put(id: String, record: String, place: int, same: bool) -> void:
    if pinner == null or not is_instance_valid(pinner) or not pinner.has_method("pin_spot"):
        return
    var spot = pinner.pin_spot(record, place)
    # a room may say how big the place is (a sheet of the Evidence Wall)
    var size: Vector2 = pinner.pin_size(record, place) if spot is Transform3D and pinner.has_method("pin_size") else Vector2.ZERO
    var where := [spot, size]
    if same and _placed.has(id) and _placed[id] == where:
        return
    _placed[id] = where
    if spot is Transform3D:
        _things[id].pin_to(spot, size)
    else:
        _things[id].unpin()             # no place for it now: not left standing in another record's

# Where each record of this room stands among its kind, when the room keeps them in an order of its
# own (RoomBase.arrange: books by time, beliefs by what they are about): id -> its place in the order.
func _arranged(mine: Array) -> Dictionary:
    var out := {}
    if pinner == null or not is_instance_valid(pinner) or not pinner.has_method("arrange"):
        return out
    var by_kind := {}
    for data in mine:
        if data.has("form"):
            var kind := str(data.get("kind", ""))
            if not by_kind.has(kind):
                by_kind[kind] = []
            by_kind[kind].append(data)
    for kind in by_kind:
        var ordered: Array = pinner.arrange(kind, by_kind[kind])
        for i in ordered.size():
            out[str((ordered[i] as Dictionary).get("id", ""))] = i
    return out

## How long a frame is: the display's refresh, which the physics tick is set to (RuntimeOptimizer).
static func frame_seconds() -> float:
    return 1.0 / float(Engine.physics_ticks_per_second)

## How many books are still to be brought in.
func coming() -> int:
    return _coming.size()

# A frame's share of the books: first those still to be brought in, then the writing on those the
# eye has come within reading distance of (EliBook.write), the nearest first. The unwritten ones
# are looked over when the eye has moved half an arm's reach since the last time, or a new book
# has come; with the eye still and nothing new, nothing is done at all.
func _process(_delta: float) -> void:
    if _coming.is_empty() and _unwritten.is_empty() and _to_write.is_empty():
        return
    var until := Time.get_ticks_usec() + int(frame_seconds() * BOOKS_SHARE * 1e6)
    while not _coming.is_empty() and Time.get_ticks_usec() < until:
        var next: Array = _coming.pop_front()
        var data: Dictionary = next[0]
        var id := str(data.get("id", ""))
        _make(data, next[2])
        _said[id] = next[3]
        _put(id, str(data.get("kind", "")), next[1], false)
    if not _coming.is_empty():
        return
    var camera := get_viewport().get_camera_3d()
    if camera == null:
        return
    var eye := camera.global_position
    if _to_write.is_empty():
        if eye.distance_to(_read_from) < Reading.at_arm() * 0.5:
            return
        # look them over: those within reach are written, the nearest first
        _read_from = eye
        var reach: float = BookClass.writing_reach()
        var still := []
        for book in _unwritten:
            if not is_instance_valid(book) or book.is_written():
                continue
            still.append(book)
            var away: float = (book as Node3D).global_position.distance_squared_to(eye)
            if away <= reach * reach:
                _to_write.append([away, book])
        _unwritten = still
        _to_write.sort_custom(func(a, b): return a[0] > b[0])        # the nearest last, to be taken first
    while not _to_write.is_empty() and Time.get_ticks_usec() < until:
        var book = _to_write.pop_back()[1]
        if is_instance_valid(book):
            book.write()

func _share_lamps() -> void:
    var lit := standing().filter(func(t): return t.lamp != null)
    lit.sort_custom(func(a, b): return a.glow > b.glow)
    for i in lit.size():
        lit[i].lamp.visible = i < MAX_LAMPS

func _on_let_go(thing) -> void:
    _said.erase(thing.thing_id)         # moved by hand: brought in line with ELI's world again at its next word
    if thing.piece.is_empty():
        moved_by_hand.emit(thing.thing_id, thing.position)
    else:
        dropped.emit(thing)             # a piece of a game: the game says what that means, not ELI's world
