class_name EliPlay
extends Node

# A small game ELI made up, played where you stand. ELI's world sets it: a game object carrying
# the rules (its name, kind, pieces, how many, how long, how quick, what ELI says), and its pieces
# as built things, each marked with its part (eli/world/games.py in ELI v3). EliThings draws the
# pieces as it draws anything; this runs the rules on them, keeps the score, shows ELI's lines, and
# when the game ends tells ELI's world how it went. Nothing here decides what the game is.
#
#   targets  pieces come up one after another where ELI's world put them; point and pull the
#            trigger at one, or touch it, and it is hit; one left too long fades: a miss
#   catch    pieces come down from above; grab one (the grip) before it reaches the floor
#   sort     pieces stand before you with a mat for each kind; let a piece go on its mat
#   order    the lights flash in a sequence, one longer each round; hit them in that order
#   hide     one piece is hidden in the room each round; look at it for a moment, or touch it
#
# How many are up at once, how fast they move and how long each stays come from what ELI chose
# (count, seconds, pace) and from where things are, never from a table here.

signal started(game: Dictionary)
signal scored(score: int, misses: int)
signal ended(result: Dictionary)

const ROLE_MAT := "mat"
const FOUND_SECONDS := 0.5          # a look that rests this long on the hidden piece has found it
const CARD_SECONDS := 8.0           # how long the score stays up after the end
const BOARD_FONT := 40

var app
var link
var presence
var things

var game := {}                      # the game object as ELI's world sent it
var rules := {}                     # its rules
var running := false
var score := 0
var misses := 0
var rounds := 0
var elapsed := 0.0

var _pieces: Array = []             # EliThing, by index
var _mats: Array = []
var _live: Dictionary = {}          # thing -> {"born", "life", "home"}
var _next_at := 0.0                 # when the next piece comes up (targets, catch)
var _up_to := 0                     # how many pieces have come up
var _done: Dictionary = {}          # thing -> true once it is resolved
var _sequence: Array = []           # order: the lights in order this round
var _showing := -1                  # order: which of the sequence is being shown; -1 while taking input
var _show_left := 0.0
var _expected := 0                  # order: the next light wanted
var _pause := 0.0                   # a breath between rounds
var _looked := 0.0                  # hide: how long the gaze has rested on it
var _board: Label3D
var _card_left := 0.0
var _ended: Dictionary = {}         # game id -> true once this game has been played out here
var _rng := RandomNumberGenerator.new()
var _pressed: Dictionary = {}       # pointer -> whether its trigger was down last frame

func setup(p_app, p_link, p_presence, p_things) -> void:
    app = p_app
    link = p_link
    presence = p_presence
    things = p_things
    things.taken.connect(_on_taken)
    things.dropped.connect(_on_dropped)
    _board = Label3D.new()
    _board.font_size = BOARD_FONT
    _board.pixel_size = 0.004
    _board.outline_size = 10
    _board.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _board.no_depth_test = true
    _board.visible = false
    add_child(_board)

## ELI's world has sent its state: a game set in this room begins, one that is being stopped or
## is gone from the world ends.
func apply_world_state(_state: Dictionary) -> void:
    var here: Dictionary = things.game_here()
    if running:
        if here.is_empty() or str(here.get("id", "")) != str(game.get("id", "")):
            _finish(true, false)            # taken down by ELI's world: nothing to post
        elif str(here.get("status", "")) == "stopping":
            _finish(true, true)             # the user asked to stop: say how far it got
        return
    if not here.is_empty() and str(here.get("status", "")) == "set" and not _ended.has(str(here.get("id", ""))):
        _begin(here)

## The user is going to another room: a game on here is given up.
func room_changing(room_id: String) -> void:
    if running and room_id != str(game.get("room", "")):
        _finish(true, true)

func _begin(obj: Dictionary) -> void:
    var all: Array = things.pieces_of(str(obj.get("id", "")))
    if all.is_empty():
        return                              # its pieces have not arrived yet
    game = obj
    rules = obj.get("game", {})
    _pieces = all.filter(func(t): return str(t.piece.get("role", "")) != ROLE_MAT)
    _mats = all.filter(func(t): return str(t.piece.get("role", "")) == ROLE_MAT)
    if _pieces.is_empty():
        return
    _rng.seed = hash(str(obj.get("id", "")))
    score = 0
    misses = 0
    rounds = 0
    elapsed = 0.0
    _live.clear()
    _done.clear()
    _up_to = 0
    _next_at = 0.0
    _sequence.clear()
    _showing = -1
    _expected = 0
    _pause = 0.0
    _looked = 0.0
    for thing in _pieces:
        thing.driven = true
        if kind() in ["targets", "catch", "hide"]:
            thing.vanish()                  # they come up in their turn
    running = true
    _card_left = 0.0
    var form: Dictionary = obj.get("form", {})
    _board.position = EliSenses.from_protocol(form.get("pos", [0.0, 1.6, 2.2]))
    _board.visible = true
    _refresh_board()
    if kind() == "order":
        _next_round()
    elif kind() == "hide":
        _hide_again(true)
    print("ELI VR PLAY: %s (%s), %d pieces, %d s" % [str(rules.get("name", "")), kind(), _pieces.size(), int(seconds())])
    started.emit(game)
    _say(str(rules.get("lines", {}).get("start", "")))

func kind() -> String:
    return str(rules.get("kind", "targets"))

func seconds() -> float:
    return maxf(1.0, float(rules.get("seconds", 60)))

func pace() -> float:
    return clampf(float(rules.get("pace", 0.5)), 0.0, 1.0)

func count() -> int:
    return maxi(1, int(rules.get("count", _pieces.size())))

## How long between one piece coming up and the next: all of them within the game's time.
func interval() -> float:
    return seconds() / float(mini(count(), _pieces.size()))

func left() -> float:
    return maxf(0.0, seconds() - elapsed)

func _process(delta: float) -> void:
    if not running:
        if _card_left > 0.0:
            _card_left -= delta
            if _card_left <= 0.0:
                _board.visible = false
        return
    elapsed += delta
    match kind():
        "targets": _tick_targets(delta)
        "catch": _tick_catch(delta)
        "sort": _tick_sort()
        "order": _tick_order(delta)
        "hide": _tick_hide(delta)
    _refresh_board()
    if running and elapsed >= seconds():
        _finish(false, true)

# --- targets ---------------------------------------------------------------------------------

func _bring_up(thing, life: float) -> void:
    thing.show_piece()
    _live[thing] = {"born": elapsed, "life": life, "home": thing.position, "turn": _rng.randf() * TAU}
    _up_to += 1
    _next_at = elapsed + interval()
    if presence != null:
        presence.look_toward(thing.global_position)

func _tick_targets(_delta: float) -> void:
    # slow: three up at once; quick: one at a time, each gone as the next comes
    var life := interval() * (3.0 - 2.0 * pace())
    if elapsed >= _next_at and _up_to < mini(count(), _pieces.size()):
        _bring_up(_pieces[_up_to], life)
    var reach := 0.4 + 0.8 * pace()
    for thing in _live.keys():
        if not is_instance_valid(thing):
            _live.erase(thing)
            continue
        var at: Dictionary = _live[thing]
        var age: float = elapsed - float(at["born"])
        match str(rules.get("motion", "still")):
            "drift":
                var turn: float = float(at["turn"]) + age * (0.6 + 1.2 * pace())
                thing.drive(at["home"] + Vector3(sin(turn) * reach, 0.15 * sin(turn * 1.7), cos(turn) * reach))
            "orbit":
                var centre := _you() * Vector3(1, 0, 1)
                var spoke: Vector3 = (at["home"] - centre) * Vector3(1, 0, 1)
                var turn: float = age * (0.3 + 0.7 * pace())
                thing.drive(centre + spoke.rotated(Vector3.UP, turn) + Vector3(0, at["home"].y, 0))
        if age > float(at["life"]):
            _miss(thing)
    if _up_to >= mini(count(), _pieces.size()) and _live.is_empty():
        _finish(false, true)

# --- catch -----------------------------------------------------------------------------------

func _tick_catch(_delta: float) -> void:
    var fall := interval() * (2.5 - 1.5 * pace())
    if elapsed >= _next_at and _up_to < mini(count(), _pieces.size()):
        _bring_up(_pieces[_up_to], fall)
    for thing in _live.keys():
        if not is_instance_valid(thing):
            _live.erase(thing)
            continue
        if thing.held():
            continue
        var at: Dictionary = _live[thing]
        var age: float = elapsed - float(at["born"])
        var home: Vector3 = at["home"]
        thing.drive(Vector3(home.x, lerpf(home.y, 0.0, clampf(age / float(at["life"]), 0.0, 1.0)), home.z))
        if age >= float(at["life"]):
            _miss(thing)
    if _up_to >= mini(count(), _pieces.size()) and _live.is_empty():
        _finish(false, true)

func _on_taken(thing) -> void:
    if not running or kind() != "catch" or not _live.has(thing):
        return
    _live.erase(thing)
    _done[thing] = true
    _hit_scored(thing)

# --- sort ------------------------------------------------------------------------------------

func _tick_sort() -> void:
    if _done.size() >= _pieces.size():
        _finish(false, true)

func _mat_under(thing) -> Variant:
    for mat in _mats:
        var flat: Vector3 = (thing.position - mat.position) * Vector3(1, 0, 1)
        if flat.length() <= mat.footprint():
            return mat
    return null

func _on_dropped(thing) -> void:
    if not running or not thing in _pieces:
        return
    if kind() == "catch":
        if _done.has(thing):
            thing.vanish()              # caught, and let go of
        return
    if kind() != "sort" or _done.has(thing):
        return
    var mat = _mat_under(thing)
    if mat == null:
        return
    if str(mat.piece.get("tag", "")) == str(thing.piece.get("tag", "")):
        _done[thing] = true
        thing.driven = true
        thing.drive(Vector3(thing.position.x, mat.position.y, thing.position.z))
        _hit_scored(thing)
    else:
        _miss(thing, false)

# --- order -----------------------------------------------------------------------------------

func beat() -> float:
    return 0.9 - 0.5 * pace()

func _next_round() -> void:
    _sequence.append(_pieces[_rng.randi() % _pieces.size()])
    _show_sequence()

func _show_sequence() -> void:
    _showing = 0
    _show_left = beat() * 0.5
    _expected = 0

func _tick_order(delta: float) -> void:
    if _pause > 0.0:
        _pause -= delta
        if _pause <= 0.0:
            _next_round()
        return
    if _showing < 0:
        return
    _show_left -= delta
    if _show_left <= 0.0:
        if _showing < _sequence.size():
            _sequence[_showing].flash(beat() * 0.8)
            if presence != null:
                presence.look_toward(_sequence[_showing].global_position)
        _showing += 1
        _show_left = beat()
        if _showing > _sequence.size():
            _showing = -1               # shown: now it is the user's turn

func _order_hit(thing) -> void:
    if _showing >= 0 or _pause > 0.0:
        return                          # not while it is being shown
    thing.flash(beat() * 0.5)
    if thing == _sequence[_expected]:
        _expected += 1
        if _expected >= _sequence.size():
            rounds += 1
            score = rounds
            _note(str(rules.get("lines", {}).get("hit", "")))
            scored.emit(score, misses)
            _pause = beat() * 2.0
            if rounds >= count():
                _finish(false, true)
        return
    misses += 1
    _note(str(rules.get("lines", {}).get("miss", "")))
    scored.emit(score, misses)
    _show_sequence()                    # the same sequence again

# --- hide ------------------------------------------------------------------------------------

func _hide_again(first: bool) -> void:
    var thing = _pieces[0]
    if not first:
        # somewhere else in the room, as far out as ELI's world first hid it: not near where it was,
        # nor where you stand
        var was: Vector3 = thing.position
        var far := maxf(2.0, (was * Vector3(1, 0, 1)).length())
        var you := _you()
        var spot := was
        for _try in 12:
            var bearing := _rng.randf() * TAU
            spot = Vector3(sin(bearing) * far, _rng.randf_range(0.0, maxf(0.5, you.y)), cos(bearing) * far)
            if (spot - was).length() >= 2.0 and ((spot - you) * Vector3(1, 0, 1)).length() >= 2.0:
                break
        thing.drive(spot, true)
    thing.vanish()
    thing.show_piece()
    _looked = 0.0
    _pause = 0.0

func _tick_hide(delta: float) -> void:
    var thing = _pieces[0]
    if _pause > 0.0:
        _pause -= delta
        if _pause <= 0.0:
            _hide_again(false)
        return
    var camera := get_viewport().get_camera_3d()
    if camera != null:
        var gaze := -camera.global_transform.basis.z
        var to: Vector3 = thing.global_position + Vector3(0, thing.eye_height(), 0) - camera.global_position
        if gaze.angle_to(to) < deg_to_rad(EliSenses.LOOK_DEGREES):
            _looked += delta
            if _looked >= FOUND_SECONDS:
                _found(thing)
        else:
            _looked = 0.0

func _found(thing) -> void:
    rounds += 1
    score = rounds
    _note(str(rules.get("lines", {}).get("hit", "")))
    scored.emit(score, misses)
    thing.flash(0.6)
    if rounds >= count():
        _finish(false, true)
        return
    _pause = 1.5

# --- hits, misses, the end -----------------------------------------------------------------------

## A piece pointed at and triggered, or touched. The game decides what that means.
func hit(thing) -> void:
    if not running or thing == null or not thing in _pieces:
        return
    match kind():
        "targets":
            if _live.has(thing):
                _live.erase(thing)
                _done[thing] = true
                thing.flash(0.3)
                thing.vanish()
                _hit_scored(thing)
        "order":
            _order_hit(thing)
        "hide":
            if _pause <= 0.0 and not thing.is_gone():
                _found(thing)

func _hit_scored(_thing) -> void:
    score += 1
    _note(str(rules.get("lines", {}).get("hit", "")))
    scored.emit(score, misses)

func _miss(thing, gone: bool = true) -> void:
    _live.erase(thing)
    if gone:
        _done[thing] = true
        thing.vanish()
    misses += 1
    _note(str(rules.get("lines", {}).get("miss", "")))
    scored.emit(score, misses)

func result() -> Dictionary:
    return {"score": score, "misses": misses, "rounds": rounds, "seconds": int(round(elapsed))}

## The user gives up: how far it got is told.
func stop() -> void:
    if running:
        _finish(true, true)

func _finish(abandoned: bool, post: bool) -> void:
    if not running:
        return
    running = false
    if not abandoned:
        misses += _live.size()          # still up when the time ran out: not hit, not caught
    var out := result()
    out["abandoned"] = abandoned
    _ended[str(game.get("id", ""))] = true
    for thing in _pieces:
        if is_instance_valid(thing):
            thing.driven = false
            thing.vanish()
    for mat in _mats:
        if is_instance_valid(mat):
            mat.vanish()
    if presence != null:
        presence.look_toward(Vector3.INF)
    _live.clear()
    var words := str(rules.get("lines", {}).get("end", "")) if not abandoned else ""
    _card_left = CARD_SECONDS
    _refresh_board(out)
    print("ELI VR PLAY: %s over: %d, %d misses, %d s%s" % [str(rules.get("name", "")), score, misses, out["seconds"],
                                                           " (stopped)" if abandoned else ""])
    ended.emit(out)
    if post and link != null and link.can("games"):
        var told = await link.played(str(game.get("id", "")), out)
        if told.ok:
            var more := str(told.payload.get("text", ""))
            if not more.is_empty():
                words = (words + " " + more).strip_edges()
                _refresh_board(out, more)
        else:
            print("ELI VR PLAY: the result could not be told: %s" % told.sentence())
    _say(words)

func _refresh_board(out: Dictionary = {}, more: String = "") -> void:
    if _board == null:
        return
    var name := str(rules.get("name", "")).to_upper()
    var what: String = {"targets": "hits", "catch": "caught", "sort": "sorted", "order": "rounds", "hide": "found"}.get(kind(), "points")
    if out.is_empty():
        _board.text = "%s\n%s\n%d %s · %d missed · %ds" % [name, str(rules.get("goal", "")), score, what, misses, int(ceil(left()))]
    else:
        _board.text = "%s · OVER\n%d %s · %d missed · %ds%s" % [name, int(out["score"]), what, int(out["misses"]), int(out["seconds"]),
                                                              "" if more.is_empty() else "\n" + more]

func _note(text: String) -> void:
    if presence != null and not text.is_empty():
        presence.note(text, 2.5)

func _say(words: String) -> void:
    if app != null and app.has_method("eli_speak") and not words.is_empty():
        app.eli_speak(words)

func _you() -> Vector3:
    var camera := get_viewport().get_camera_3d()
    return camera.global_position if camera != null else Vector3(0, 1.7, 0)

# --- input: the trigger on a piece, a hand on a piece, a click in the flat window ---------------

func _physics_process(_delta: float) -> void:
    if not running or app == null:
        return
    if not bool(app.get("xr_active")):
        return
    for pointer in _pointers():
        var controller = pointer.get("controller")
        if controller == null:
            continue
        var pressed: bool = controller.is_button_pressed("trigger_click")
        if pressed and not bool(_pressed.get(pointer, false)):
            hit(_along(pointer.global_transform.origin, -pointer.global_transform.basis.z))
        _pressed[pointer] = pressed
    for hand in [app.get("left_hand"), app.get("right_hand")]:
        if hand == null or not hand.get_has_tracking_data():
            continue
        for thing in _touchable():
            if hand.global_position.distance_to(thing.global_position + Vector3(0, thing.eye_height(), 0)) <= thing.radius:
                hit(thing)

func _unhandled_input(event: InputEvent) -> void:
    if not running or app == null or bool(app.get("xr_active")):
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var camera := get_viewport().get_camera_3d()
        if camera != null:
            hit(_along(camera.project_ray_origin(event.position), camera.project_ray_normal(event.position)))

func _pointers() -> Array:
    var out := []
    var origin = app.get("xr_origin")
    if origin == null:
        return out
    for name in ["LeftPointer", "RightPointer"]:
        var pointer = origin.get_node_or_null(name)
        if pointer != null:
            out.append(pointer)
    return out

func _touchable() -> Array:
    match kind():
        "targets": return _live.keys()
        "order", "hide": return _pieces.filter(func(t): return not t.is_gone())
    return []

## The piece of this game a ray from `origin` along `direction` meets first, or null.
func _along(origin: Vector3, direction: Vector3) -> Variant:
    var query := PhysicsRayQueryParameters3D.create(origin, origin + direction.normalized() * 30.0)
    query.collision_mask = 4
    query.collide_with_areas = true
    query.collide_with_bodies = false
    var found: Dictionary = get_viewport().get_world_3d().direct_space_state.intersect_ray(query)
    var collider = found.get("collider")
    return collider if collider != null and collider in _pieces and not collider.is_gone() else null
