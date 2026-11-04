class_name EliPlay
extends Node

# A small game ELI set, played where you stand. ELI's world sets it: a game object carrying the
# rules (its name, kind, pieces, how many, how long, how quick, the guns of a range, what ELI says),
# and its pieces as built things, each marked with its part (eli/world/games.py in ELI v3). EliThings
# draws the pieces as it draws anything; this runs the rules on them, keeps the score, shows ELI's
# lines (which arrive on the game object once ELI has them), and when the game ends tells ELI's world
# how it went. Nothing here decides what the game is.
#
#   targets  pieces come up one after another where ELI's world put them; point and pull the
#            trigger at one, or touch it, and it is hit; one left too long fades: a miss
#   catch    pieces come down from above; grab one (the grip) before it reaches the floor
#   sort     pieces stand before you with a mat for each kind; let a piece go on its mat
#   order    the lights flash in a sequence, one longer each round; hit them in that order
#   hide     one piece is hidden in the room each round; look at it for a moment, or touch it
#   range    guns lie on a table beside you (EliArm); take one in the grip, point it, and pull the
#            trigger: targets come up ahead and a target shot scores by the ring it was hit in
#            (the rules' rings: the middle most); one left too long fades: a miss. A shot is
#            instant; a bolt flies and falls; a beam must rest on a target; a rail gun charges
#            while the trigger is held and then goes through everything on its line. On a flat
#            screen a click fires the first gun from where you look.
#
# How many are up at once, how fast they move and how long each stays come from what ELI chose
# (count, seconds, pace) and from where things are, never from a table here.

signal started(game: Dictionary)
signal scored(score: int, misses: int)
signal ended(result: Dictionary)

const ROLE_MAT := "mat"
const ROLE_ARM := "arm"
const ROLE_RACK := "rack"
const FOUND_SECONDS := 0.5          # a look that rests this long on the hidden piece has found it
const CARD_SECONDS := 8.0           # how long the score stays up after the end
const BOARD_FONT := 40
const BOLT_SECONDS := 4.0           # a bolt that has hit nothing by then is gone
const MARK_SECONDS := 1.5           # how long a hit's mark stays on the target
const HOME_SECONDS := 2.0           # a gun let go lies where it fell this long, then goes back to the table

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
var hits := 0                       # range: targets hit
var shots := 0                      # range: trigger pulls
var elapsed := 0.0

var _pieces: Array = []             # EliThing, by index
var _mats: Array = []
var _arms: Array = []               # EliArm, the range's guns
var _rack = null
var _live: Dictionary = {}          # thing -> {"born", "life", "home"}
var _next_at := 0.0                 # when the next piece comes up (targets, catch, range)
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
var _said_start := false            # ELI's start line, said once it is there
var _rng := RandomNumberGenerator.new()
var _pressed: Dictionary = {}       # pointer -> whether its trigger was down last frame
var _arm_pressed: Dictionary = {}   # arm -> whether its hand's trigger was down last frame
var _last_shot: Dictionary = {}     # arm -> when it last fired
var _by_arm: Dictionary = {}        # arm tag -> {"shots", "hits", "points"}
var _bolts: Array = []              # [node, velocity, arm, born]
var _beam_on: Dictionary = {}       # arm -> {"target", "since"}
var _charge: Dictionary = {}        # arm -> seconds the trigger has been held
var _marks: Array = []              # [node, until]
var _homing: Dictionary = {}        # arm -> when it goes back to the table

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
## is gone from the world ends; a game on takes ELI's words as they arrive on it.
func apply_world_state(_state: Dictionary) -> void:
    var here: Dictionary = things.game_here()
    if running:
        if here.is_empty() or str(here.get("id", "")) != str(game.get("id", "")):
            _finish(true, false)            # taken down by ELI's world: nothing to post
        elif str(here.get("status", "")) == "stopping":
            _finish(true, true)             # the user asked to stop: say how far it got
        else:
            _take_words(here)
        return
    if not here.is_empty() and str(here.get("status", "")) == "set" and not _ended.has(str(here.get("id", ""))):
        _begin(here)

# ELI's words for the game come after it is set (eli/world/games.py words_after): its name, goal and
# lines land on the game object, and the board and ELI's start line follow.
func _take_words(here: Dictionary) -> void:
    var now: Dictionary = here.get("game", {})
    if now == rules:
        return
    rules = now
    game = here
    _refresh_board()
    if not _said_start:
        var start := str(rules.get("lines", {}).get("start", ""))
        if not start.is_empty():
            _said_start = true
            _say(start)

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
    _pieces = all.filter(func(t): return not str(t.piece.get("role", "")) in [ROLE_MAT, ROLE_ARM, ROLE_RACK])
    _mats = all.filter(func(t): return str(t.piece.get("role", "")) == ROLE_MAT)
    _arms = all.filter(func(t): return str(t.piece.get("role", "")) == ROLE_ARM)
    var racks: Array = all.filter(func(t): return str(t.piece.get("role", "")) == ROLE_RACK)
    _rack = racks[0] if not racks.is_empty() else null
    if _pieces.is_empty():
        return
    _rng.seed = hash(str(obj.get("id", "")))
    score = 0
    misses = 0
    rounds = 0
    hits = 0
    shots = 0
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
    _arm_pressed.clear()
    _last_shot.clear()
    _by_arm.clear()
    _beam_on.clear()
    _charge.clear()
    _homing.clear()
    _clear_bolts()
    for thing in _pieces:
        thing.driven = true
        if kind() in ["targets", "catch", "hide", "range"]:
            thing.vanish()                  # they come up in their turn
    for arm in _arms:
        arm.driven = true                   # where it lies is the game's: ELI's world's figure is its home
    running = true
    _said_start = false
    _card_left = 0.0
    var form: Dictionary = obj.get("form", {})
    _board.position = EliSenses.from_protocol(form.get("pos", [0.0, 1.6, 2.2]))
    _board.visible = true
    _refresh_board()
    if kind() == "order":
        _next_round()
    elif kind() == "hide":
        _hide_again(true)
    print("ELI VR PLAY: %s (%s), %d pieces, %d guns, %d s" % [str(rules.get("name", "")), kind(), _pieces.size(), _arms.size(), int(seconds())])
    started.emit(game)
    var start := str(rules.get("lines", {}).get("start", ""))
    if not start.is_empty():
        _said_start = true
        _say(start)

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
        _tick_marks(delta)
        return
    elapsed += delta
    match kind():
        "targets": _tick_targets(delta)
        "range":
            _tick_targets(delta)
            _tick_firing(delta)
        "catch": _tick_catch(delta)
        "sort": _tick_sort()
        "order": _tick_order(delta)
        "hide": _tick_hide(delta)
    _tick_marks(delta)
    _refresh_board()
    if running and elapsed >= seconds():
        _finish(false, true)

# --- targets, and the range's targets ----------------------------------------------------------

func _bring_up(thing, life: float) -> void:
    var home: Vector3 = thing.position
    thing.show_piece()
    _live[thing] = {"born": elapsed, "life": life, "home": home, "turn": _rng.randf() * TAU, "side": 1.0 if _rng.randf() < 0.5 else -1.0}
    match str(rules.get("motion", "still")):
        "pop":
            thing.drive(home - Vector3(0, thing.eye_height() + thing.target_radius() + 0.4, 0), true)   # up out of the floor
            thing.drive(home)
        "fly":
            thing.drive(_fly_at(thing, 0.0), true)
    _up_to += 1
    _next_at = elapsed + interval()
    if presence != null:
        presence.look_toward(thing.global_position)

# Where a flying target is at `t` of its life: across the room from one side to the other, in an
# arc, as a clay goes.
func _fly_at(thing, t: float) -> Vector3:
    var at: Dictionary = _live[thing]
    var home: Vector3 = at["home"]
    var you := _you() * Vector3(1, 0, 1)
    var across := ((home * Vector3(1, 0, 1)) - you).normalized().cross(Vector3.UP) * float(at["side"])
    var span := 2.0 + 4.0 * pace()
    return home + across * span * (1.0 - 2.0 * t) + Vector3(0, 1.4 * sin(t * PI), 0)

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
            "fly":
                thing.drive(_fly_at(thing, clampf(age / float(at["life"]), 0.0, 1.0)), true)
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
    if not running:
        return
    if thing in _arms:
        _homing.erase(thing)
        return
    if kind() != "catch" or not _live.has(thing):
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
    if not running:
        return
    if thing in _arms:
        _homing[thing] = elapsed + HOME_SECONDS    # a gun let go goes back to the table in a moment
        return
    if not thing in _pieces:
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

# --- the range: guns in hand, shots, bolts, beams and rails ----------------------------------------

## How a gun fires, by the rules ELI's world set for it.
func arm_rules(arm) -> Dictionary:
    var arms: Dictionary = rules.get("arms", {})
    var info = arms.get(str(arm.piece.get("tag", "")), {})
    return info if typeof(info) == TYPE_DICTIONARY else {}

# The hand (the world manipulator) holding a gun, or null.
func _hand_holding(arm) -> Node:
    if app == null:
        return null
    for name in ["LeftWorldManipulator", "RightWorldManipulator"]:
        var hand = app.get_node_or_null(name)
        if hand != null and hand.get("grabbed") == arm:
            return hand
    return null

func _tick_firing(delta: float) -> void:
    for arm in _arms:
        if not is_instance_valid(arm):
            continue
        if _homing.has(arm) and elapsed >= float(_homing[arm]):
            _homing.erase(arm)
            arm.go_home()
        if not arm.wielded:
            if _beam_on.has(arm):
                arm.beam_off()
                _beam_on.erase(arm)
            _charge.erase(arm)
            continue
        var hand := _hand_holding(arm)
        var pressed: bool = hand != null and hand.controller != null and hand.controller.is_button_pressed("trigger_click")
        var info := arm_rules(arm)
        var edge: bool = pressed and not bool(_arm_pressed.get(arm, false))
        match str(info.get("fire", "shot")):
            "shot":
                if edge:
                    _shoot(arm, info, hand)
            "bolt":
                if edge:
                    _cast(arm, info, hand)
            "beam":
                if pressed:
                    _beam(arm, info, delta)
                else:
                    arm.beam_off()
                    _beam_on.erase(arm)
            "rail":
                var needed := maxf(0.05, float(info.get("charge", 0.6)))
                if pressed:
                    _charge[arm] = float(_charge.get(arm, 0.0)) + delta
                    arm.charging(float(_charge[arm]) / needed)
                else:
                    if float(_charge.get(arm, 0.0)) >= needed:
                        _rail(arm, info, hand)
                    _charge.erase(arm)
                    arm.charging(0.0)
        _arm_pressed[arm] = pressed
    _tick_bolts(delta)

func _ready_to_fire(arm, info: Dictionary) -> bool:
    return elapsed - float(_last_shot.get(arm, -1e9)) >= float(info.get("rate", 0.0))

func _fired(arm, hand) -> void:
    _last_shot[arm] = elapsed
    shots += 1
    _tally(arm, "shots")
    if hand != null and hand.controller != null:
        hand.controller.trigger_haptic_pulse("haptic", 0.0, 0.7, 0.06, 0.0)

func _tally(arm, key: String, by: int = 1) -> void:
    var tag := str(arm.piece.get("tag", "")) if arm != null else "camera"
    var done: Dictionary = _by_arm.get(tag, {"shots": 0, "hits": 0, "points": 0})
    done[key] = int(done[key]) + by
    _by_arm[tag] = done

# A direction scattered within a cone of `spread` radians round `dir`.
func _scattered(dir: Vector3, spread: float) -> Vector3:
    if spread <= 0.0:
        return dir
    var side := dir.cross(Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT).normalized()
    var up := side.cross(dir).normalized()
    var angle := _rng.randf() * TAU
    var off := _rng.randf() * spread
    return (dir + (side * cos(angle) + up * sin(angle)) * tan(off)).normalized()

## A shot: instant along the aim, `shots` of them for a shotgun, each scattered by `spread`.
func _shoot(arm, info: Dictionary, hand) -> void:
    if not _ready_to_fire(arm, info):
        return
    var aim: Dictionary = arm.aim()
    var pellets := maxi(1, int(info.get("shots", 1)))
    var end: Vector3 = aim["from"] + aim["dir"] * 30.0
    for _p in pellets:
        var dir := _scattered(aim["dir"], float(info.get("spread", 0.0)))
        var found := _target_on_line(aim["from"], dir)
        if not found.is_empty():
            _struck(found["target"], found["ring"], arm, found["at"])
            end = found["at"]
    _fired(arm, hand)
    arm.fired("shot", end)

## A bolt: a light that flies from the muzzle at `speed`, falling at `drop`, and hits what it meets.
func _cast(arm, info: Dictionary, hand) -> void:
    if not _ready_to_fire(arm, info):
        return
    var aim: Dictionary = arm.aim()
    var bolt := MaterialKit.halo(arm.colour.lightened(0.4), 0.16, 2.5, 1.0)
    bolt.top_level = true
    add_child(bolt)
    bolt.global_position = aim["from"]
    var light := OmniLight3D.new()
    light.light_color = arm.colour
    light.light_energy = 0.8
    light.omni_range = 2.0
    light.shadow_enabled = false
    bolt.add_child(light)
    _bolts.append([bolt, aim["dir"] * float(info.get("speed", 16.0)), arm, elapsed, float(info.get("drop", 3.0))])
    _fired(arm, hand)
    arm.fired("bolt")

func _tick_bolts(delta: float) -> void:
    for entry in _bolts.duplicate():
        var bolt: Node3D = entry[0]
        if not is_instance_valid(bolt):
            _bolts.erase(entry)
            continue
        var velocity: Vector3 = entry[1]
        velocity.y -= float(entry[4]) * delta
        entry[1] = velocity
        var from: Vector3 = bolt.global_position
        var to: Vector3 = from + velocity * delta
        bolt.global_position = to
        var found := _target_on_line(from, (to - from).normalized(), (to - from).length())
        if not found.is_empty():
            _struck(found["target"], found["ring"], entry[2], found["at"])
            bolt.queue_free()
            _bolts.erase(entry)
        elif to.y < -1.0 or elapsed - float(entry[3]) > BOLT_SECONDS:
            bolt.queue_free()
            _bolts.erase(entry)

func _clear_bolts() -> void:
    for entry in _bolts:
        if is_instance_valid(entry[0]):
            entry[0].queue_free()
    _bolts.clear()

## A beam: on while the trigger is; a target it rests on for `hold` seconds is hit where it rests.
func _beam(arm, info: Dictionary, delta: float) -> void:
    var aim: Dictionary = arm.aim()
    var found := _target_on_line(aim["from"], aim["dir"])
    var to: Vector3 = found["at"] if not found.is_empty() else aim["from"] + aim["dir"] * 30.0
    arm.beam_to(to)
    if found.is_empty():
        _beam_on.erase(arm)
        return
    var on: Dictionary = _beam_on.get(arm, {})
    if on.get("target") != found["target"]:
        on = {"target": found["target"], "since": 0.0}
    on["since"] = float(on["since"]) + delta
    _beam_on[arm] = on
    if float(on["since"]) >= float(info.get("hold", 0.3)):
        _struck(found["target"], found["ring"], arm, found["at"])
        _beam_on.erase(arm)
        shots += 1
        _tally(arm, "shots")

## A rail gun: through everything on its line.
func _rail(arm, info: Dictionary, hand) -> void:
    if not _ready_to_fire(arm, info):
        return
    var aim: Dictionary = arm.aim()
    var struck := false
    for thing in _live.keys():
        var found := _ring_on_line(thing, aim["from"], aim["dir"], 60.0)
        if not found.is_empty():
            _struck(thing, found["ring"], arm, found["at"])
            struck = true
    _fired(arm, hand)
    arm.fired("rail", aim["from"] + aim["dir"] * 40.0)
    if not struck:
        _note(str(rules.get("lines", {}).get("miss", "")))

# The nearest live target a line from `from` along `dir` passes through (within its face's radius),
# with the ring it is hit in and where: {"target", "ring", "at"}; {} when it meets none.
func _target_on_line(from: Vector3, dir: Vector3, reach: float = 60.0) -> Dictionary:
    var best := {}
    var nearest := INF
    for thing in _live.keys():
        if not is_instance_valid(thing) or thing.is_gone():
            continue
        var found := _ring_on_line(thing, from, dir, reach)
        if not found.is_empty() and float(found["along"]) < nearest:
            nearest = float(found["along"])
            best = found
            best["target"] = thing
    return best

# Where a line passes a target's face: the ring (points) by how far from its middle, as the rules'
# rings share the face's radius; {} when the line misses it or it is behind the shooter.
func _ring_on_line(thing, from: Vector3, dir: Vector3, reach: float) -> Dictionary:
    var centre: Vector3 = thing.global_position + Vector3(0, thing.eye_height(), 0)
    var along := (centre - from).dot(dir)
    if along < 0.0 or along > reach:
        return {}
    var nearest := from + dir * along
    var off := nearest.distance_to(centre)
    var radius: float = thing.target_radius()
    if off > radius:
        return {}
    var rings: Array = rules.get("rings", [3, 2, 1])
    if rings.is_empty():
        rings = [1]
    var band := mini(rings.size() - 1, int(floor(off / radius * float(rings.size()))))
    return {"ring": int(rings[band]), "at": nearest, "along": along}

## A target hit in a ring: it scores that ring's points, is marked where it was hit, and goes.
func _struck(thing, points: int, arm, at: Vector3) -> void:
    if not _live.has(thing):
        return
    _live.erase(thing)
    _done[thing] = true
    hits += 1
    score += points
    _tally(arm, "hits")
    _tally(arm, "points", points)
    var mark := MaterialKit.halo(Color(0.1, 0.1, 0.1), 0.06, 1.0, 1.0)
    mark.top_level = true
    add_child(mark)
    mark.global_position = at
    _marks.append([mark, elapsed + MARK_SECONDS, thing])
    thing.flash(0.3)
    _note(str(rules.get("lines", {}).get("hit", "")))
    scored.emit(score, misses)
    if presence != null:
        presence.look_toward(at)

func _tick_marks(_delta: float) -> void:
    for entry in _marks.duplicate():
        var mark: Node3D = entry[0]
        if not is_instance_valid(mark):
            _marks.erase(entry)
            continue
        if elapsed >= float(entry[1]) or not running:
            mark.queue_free()
            _marks.erase(entry)
            if is_instance_valid(entry[2]) and _done.has(entry[2]):
                entry[2].vanish()           # the target goes once its mark has been seen

# On a flat screen: a click fires the first gun on the table from where you look.
func _shoot_from_camera(from: Vector3, dir: Vector3) -> void:
    if _arms.is_empty():
        return
    var arm = _arms[0]
    var info := arm_rules(arm)
    if not _ready_to_fire(arm, info):
        return
    var found := _target_on_line(from, dir)
    if not found.is_empty():
        _struck(found["target"], found["ring"], arm, found["at"])
    _fired(arm, null)
    arm.fired("shot", found["at"] if not found.is_empty() else from + dir * 30.0)

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
    var out := {"score": score, "misses": misses, "rounds": rounds, "seconds": int(round(elapsed))}
    if kind() == "range":
        out["hits"] = hits
        out["shots"] = shots
        out["arms"] = _by_arm.duplicate(true)
    return out

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
    for arm in _arms:
        if is_instance_valid(arm):
            arm.beam_off()
            arm.driven = false
            arm.vanish()
    if _rack != null and is_instance_valid(_rack):
        _rack.vanish()
    _clear_bolts()
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
    var what: String = {"targets": "hits", "catch": "caught", "sort": "sorted", "order": "rounds", "hide": "found",
                        "range": "pts"}.get(kind(), "points")
    if out.is_empty():
        if kind() == "range":
            _board.text = "%s\n%s\n%d pts · %d hits · %d shots · %d missed · %ds" % [name, str(rules.get("goal", "")), score, hits, shots, misses, int(ceil(left()))]
        else:
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
        # a hand with a gun in it fires the gun (the range), not the pointer
        if pressed and not bool(_pressed.get(pointer, false)) and not XRWorldManipulator.is_holding(controller):
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
            if kind() == "range":
                _shoot_from_camera(camera.project_ray_origin(event.position), camera.project_ray_normal(event.position))
            else:
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
