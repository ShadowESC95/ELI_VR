extends SceneTree

# Drives ELI's motion and initiative headless with the real orb and things, and prints one line per
# check: "PASS name" or "FAIL name: what happened". tests/test_eli_alive.py runs it.

const EliPresenceClass = preload("res://scripts/eli/eli_presence.gd")
const EliThingsClass = preload("res://scripts/eli/eli_things.gd")
const EliMotionClass = preload("res://scripts/eli/eli_motion.gd")
const EliInitiativeClass = preload("res://scripts/eli/eli_initiative.gd")
const EliPlayClass = preload("res://scripts/eli/eli_play.gd")

# Stands in for the app: a camera where you stand, a room, and the BUILD action, which takes a while.
class StandIn extends Node3D:
    var built := 0
    var room_root: Node3D
    var camera: Camera3D
    var xr_active := false
    var xr_origin = null
    var left_hand = null
    var right_hand = null
    var spoken := []
    func current_room_id() -> String:
        return "core_room"
    func eli_build() -> void:
        built += 1
        await get_tree().create_timer(0.3).timeout
    func eli_speak(words: String) -> void:
        spoken.append(words)

# Stands in for the link to ELI v3: it takes the result of a game and answers as ELI's world would.
class FakeLink extends Node:
    var posted := []
    func can(_capability: String) -> bool:
        return true
    func played(game_id: String, result: Dictionary):
        posted.append([game_id, result])
        return EliResult.good({"ok": true, "text": "That is your best so far.", "best": true})

var _app: StandIn
var _presence
var _things
var _motion
var _initiative

func _initialize() -> void:
    _run.call_deferred()

func _frames(seconds: float) -> void:
    var until := Time.get_ticks_msec() + int(seconds * 1000.0)
    while Time.get_ticks_msec() < until:
        await process_frame

func _check(name: String, ok: bool, detail: String) -> void:
    print(("PASS %s" % name) if ok else ("FAIL %s: %s" % [name, detail]))

func _run() -> void:
    _app = StandIn.new()
    root.add_child(_app)
    _app.camera = Camera3D.new()
    _app.add_child(_app.camera)
    _app.camera.position = Vector3(0, 1.7, 3.0)
    _app.camera.current = true
    _presence = EliPresenceClass.new()
    root.add_child(_presence)
    _presence.setup(Color("#63ddff"))
    _presence.set_mode("idle")
    _things = EliThingsClass.new()
    root.add_child(_things)
    _things.show_room("core_room")
    _motion = EliMotionClass.new()
    root.add_child(_motion)
    _motion.setup(_app, _presence, _things)
    _initiative = EliInitiativeClass.new()
    root.add_child(_initiative)
    _initiative.setup(_app, _presence)

    # you come into the room ELI is in: it is simply there, and says nothing of leaving
    _motion.set_here(true, "core_room", "Core Room")
    await _frames(0.2)
    _check("there_when_you_come_in", _presence.visible and _presence.scale.x > 0.9, "visible=%s scale=%s" % [_presence.visible, _presence.scale])

    # what was standing when you came in is drawn quietly; a new thing is gone to
    var stood := {"id": "stone", "name": "Stone", "room": "core_room", "made_by": "eli",
                  "form": {"shape": "orb", "colour": "#888888", "size": 1.0, "glow": 0.2, "pos": [-2.0, 0.0, -1.0]}}
    _things.apply_world_state({"objects": [stood]})
    var made := {"id": "lantern", "name": "Lantern", "room": "core_room", "made_by": "eli",
                 "form": {"shape": "lamp", "colour": "#f5b942", "size": 1.0, "glow": 0.8, "pos": [2.0, 0.0, -2.0]}}
    _things.apply_world_state({"objects": [stood, made]})
    await _frames(3.0)
    var drawn: Array = _things.standing().filter(func(th): return th.thing_id == "lantern")
    var lantern: Vector3 = drawn[0].global_position if not drawn.is_empty() else Vector3.INF
    var near := Vector2(_presence.global_position.x, _presence.global_position.z).distance_to(Vector2(lantern.x, lantern.z))
    _check("goes_to_what_it_makes", near < 1.2, "orb at %s, %.2f m from the lantern" % [_presence.global_position, near])

    # ELI acts on a waiting moment when it is free, once, and not while you talk
    _initiative.apply_world_state({"waiting": 1, "free": false})
    await _frames(0.3)
    _check("not_when_not_free", _app.built == 0, "built %d" % _app.built)
    _presence.set_mode("listening")
    _initiative.apply_world_state({"waiting": 1, "free": true})
    await _frames(0.3)
    _check("not_while_you_talk", _app.built == 0, "built %d" % _app.built)
    _presence.set_mode("idle")
    await _frames(0.6)
    _check("acts_when_free", _app.built == 1, "built %d" % _app.built)
    # the next waits for three times as long as that one took (0.3 s here): not at once
    _initiative.apply_world_state({"waiting": 1, "free": true})
    await _frames(0.4)
    _check("paced_by_the_last", _app.built == 1, "built %d" % _app.built)
    await _frames(1.0)
    _check("acts_again_after", _app.built == 2, "built %d" % _app.built)

    # you go to another room where ELI is not: it is simply not there, nothing about leaving
    _motion.set_here(false, "workshop", "Core Room")
    await _frames(0.1)
    _check("gone_when_you_leave", not _presence.visible, "visible=%s" % _presence.visible)
    await _play_checks()
    await _range_checks()
    _voice_checks()
    quit()

func _piece(id: String, game_id: String, role: String, tag: String, index: int, shape: String, pos: Array) -> Dictionary:
    return {"id": id, "name": id.capitalize(), "room": "core_room", "made_by": "eli", "kind": "built",
            "piece": {"game": game_id, "role": role, "tag": tag, "index": index},
            "form": {"shape": shape, "colour": "#f5b942", "size": 0.5, "glow": 0.6, "pos": pos}}

func _game(id: String, rules: Dictionary) -> Dictionary:
    return {"id": id, "name": str(rules.get("name", "")), "room": "core_room", "made_by": "eli", "kind": "game",
            "status": "set", "game": rules, "form": {"shape": "board", "colour": "#f5b942", "size": 1.0, "glow": 0.3, "pos": [0.0, 1.6, 4.0]}}

# The games ELI sets are run on its things: each mechanic, the score, and the result told back.
func _play_checks() -> void:
    var link := FakeLink.new()
    root.add_child(link)
    var play := EliPlayClass.new()
    root.add_child(play)
    play.setup(_app, link, _presence, _things)
    _motion.set_here(true, "core_room", "Core Room")
    var lines := {"start": "Go.", "hit": "Got one.", "miss": "Gone.", "end": "That was it."}

    # targets: pieces come up one after another, a hit scores, one left too long is a miss, the end is told
    var targets := {"name": "Lantern Hunt", "kind": "targets", "goal": "hit them", "count": 3, "seconds": 3, "pace": 1.0,
                    "motion": "drift", "lines": lines}
    var state := {"objects": [_game("g1", targets), _piece("t1", "g1", "target", "lamp", 0, "lamp", [1.0, 1.0, 2.0]),
                              _piece("t2", "g1", "target", "lamp", 1, "lamp", [-1.0, 1.2, 2.0]),
                              _piece("t3", "g1", "target", "lamp", 2, "lamp", [0.0, 1.4, 3.0])]}
    _things.apply_world_state(state)
    play.apply_world_state(state)
    await _frames(0.1)
    var pieces: Array = _things.pieces_of("g1")
    var up: Array = pieces.filter(func(t): return not t.is_gone())
    var drawn_as_thing: bool = _things.standing().size() == 1 and str(_things.game_here().get("id", "")) == "g1"
    _check("a_game_set_in_the_room_begins_with_its_first_piece_up", play.running and pieces.size() == 3 and up.size() == 1
           and up[0].thing_id == "t1" and _app.spoken == ["Go."] and drawn_as_thing,
           "running=%s pieces=%d up=%d spoken=%s standing=%d" % [play.running, pieces.size(), up.size(), _app.spoken, _things.standing().size()])
    play.hit(up[0])
    var hit_scored: bool = play.score == 1 and up[0].is_gone()
    await _frames(2.3)        # the second came up at 1 s and lived 1 s: a miss; the third is up now
    var missed: bool = play.misses >= 1
    await _frames(1.2)        # time is up
    var told: Array = link.posted
    _check("a_hit_scores_a_piece_left_too_long_is_a_miss_and_the_result_is_told",
           hit_scored and missed and not play.running and told.size() == 1 and told[0][0] == "g1" and int(told[0][1]["score"]) == 1
           and int(told[0][1]["misses"]) >= 1 and not bool(told[0][1]["abandoned"]) and _app.spoken.size() == 2
           and _app.spoken[1].begins_with("That was it.") and "best" in _app.spoken[1],
           "hit=%s missed=%s running=%s posted=%s spoken=%s" % [hit_scored, missed, play.running, told, _app.spoken])

    # sort: a piece let go on its mat scores, on the wrong one is a miss; all sorted ends it
    _app.spoken.clear()
    var sort := {"name": "Tidy", "kind": "sort", "goal": "sort them", "count": 2, "seconds": 30, "pace": 0.3, "lines": lines}
    state = {"objects": [_game("g2", sort), _piece("m1", "g2", "mat", "a", 0, "mat", [-2.0, 0.0, 2.0]),
                         _piece("m2", "g2", "mat", "b", 1, "mat", [2.0, 0.0, 2.0]),
                         _piece("s1", "g2", "piece", "a", 0, "block", [-0.4, 0.0, 1.9]),
                         _piece("s2", "g2", "piece", "b", 1, "orb", [0.4, 0.0, 1.9])]}
    _things.apply_world_state(state)
    play.apply_world_state(state)
    await _frames(0.1)
    var s1 = _things._things["s1"]
    var s2 = _things._things["s2"]
    s1.position = Vector3(-2.1, 0.0, -2.0)      # set down on mat a (ELI's forward 2.0 is -2.0 here)
    play._on_dropped(s1)
    s2.position = Vector3(-1.9, 0.0, -2.1)      # on mat a: the wrong one
    play._on_dropped(s2)
    var wrong: bool = play.score == 1 and play.misses == 1 and play.running
    s2.position = Vector3(2.0, 0.0, -2.0)       # on mat b
    play._on_dropped(s2)
    await _frames(0.2)
    _check("a_piece_let_go_on_its_mat_scores_and_on_the_wrong_one_is_a_miss", wrong and play.score == 2 and not play.running
           and link.posted.size() == 2 and int(link.posted[1][1]["score"]) == 2,
           "score=%d misses=%d running=%s posted=%d" % [play.score, play.misses, play.running, link.posted.size()])

    # order: the lights are shown, then hit in that order; a wrong one is a miss and they are shown again
    var order := {"name": "Simon", "kind": "order", "goal": "follow", "count": 3, "seconds": 20, "pace": 1.0, "lines": lines}
    state = {"objects": [_game("g3", order), _piece("l1", "g3", "light", "l", 0, "orb", [-1.5, 1.2, 2.5]),
                         _piece("l2", "g3", "light", "l", 1, "orb", [0.0, 1.2, 2.5]),
                         _piece("l3", "g3", "light", "l", 2, "orb", [1.5, 1.2, 2.5])]}
    _things.apply_world_state(state)
    play.apply_world_state(state)
    await _frames(1.5)        # one light, shown at a beat of 0.4 s
    var shown: bool = play._showing == -1 and play._sequence.size() == 1
    var wrong_light = play._pieces.filter(func(t): return t != play._sequence[0])[0]
    play.hit(wrong_light)
    var missed_light: bool = play.misses == 1 and play._showing >= 0
    await _frames(1.5)
    play.hit(play._sequence[0])
    var first_round: bool = play.rounds == 1 and play.score == 1
    play.stop()
    await _frames(0.2)
    _check("the_lights_are_hit_in_the_order_shown_and_stopping_tells_how_far_it_got", shown and missed_light and first_round
           and not play.running and link.posted.size() == 3 and bool(link.posted[2][1]["abandoned"]) and int(link.posted[2][1]["score"]) == 1,
           "shown=%s missed=%s round=%s posted=%s" % [shown, missed_light, first_round, link.posted.back()])

    # catch: a piece coming down is caught in the hand, one that reaches the floor is a miss
    var catch := {"name": "Catch", "kind": "catch", "goal": "catch", "count": 2, "seconds": 2, "pace": 1.0, "lines": lines}
    state = {"objects": [_game("g4", catch), _piece("c1", "g4", "catch", "c", 0, "orb", [1.0, 6.0, 2.0]),
                         _piece("c2", "g4", "catch", "c", 1, "orb", [-1.0, 6.0, 2.0])]}
    _things.apply_world_state(state)
    play.apply_world_state(state)
    await _frames(0.3)
    var c1 = _things._things["c1"]
    var falling: bool = not c1.is_gone() and c1.position.y < 6.0
    c1.begin_grab()          # the grip closes on it
    var caught: bool = play.score == 1
    c1.end_grab()
    await _frames(2.2)
    _check("a_piece_coming_down_is_caught_in_the_hand_and_one_that_lands_is_a_miss", falling and caught and play.misses == 1
           and not play.running and link.posted.size() == 4 and c1.is_gone(),
           "falling=%s caught=%s misses=%d running=%s" % [falling, caught, play.misses, play.running])

    # hide: the piece is somewhere in the room; a look that rests on it finds it, and it hides again elsewhere
    var hide := {"name": "Seek", "kind": "hide", "goal": "find it", "count": 2, "seconds": 20, "pace": 0.5, "lines": lines}
    state = {"objects": [_game("g5", hide), _piece("h1", "g5", "hidden", "h", 0, "crystal", [3.0, 0.5, -3.0])]}
    _things.apply_world_state(state)
    play.apply_world_state(state)
    await _frames(0.1)
    var h1 = _things._things["h1"]
    var first_spot: Vector3 = h1.position
    _app.camera.look_at(h1.global_position + Vector3(0, h1.eye_height(), 0))
    await _frames(0.8)
    var found_by_looking: bool = play.score == 1
    await _frames(1.7)       # hidden again, elsewhere
    var moved: bool = h1.position.distance_to(first_spot) >= 2.0 and not h1.is_gone()
    play.hit(h1)
    await _frames(0.2)
    _check("a_hidden_piece_is_found_by_looking_at_it_then_hides_elsewhere", found_by_looking and moved and play.score == 2
           and not play.running and link.posted.size() == 5,
           "looked=%s moved=%s score=%d running=%s" % [found_by_looking, moved, play.score, play.running])

    # a game taken down by ELI's world while it is on ends here with nothing to post
    state = {"objects": [_game("g6", targets), _piece("x1", "g6", "target", "lamp", 0, "lamp", [1.0, 1.0, 2.0])]}
    _things.apply_world_state(state)
    play.apply_world_state(state)
    await _frames(0.1)
    var was_on: bool = play.running
    _things.apply_world_state({"objects": []})
    play.apply_world_state({"objects": []})
    _check("a_game_taken_down_by_elis_world_ends_without_a_word", was_on and not play.running and link.posted.size() == 5,
           "on=%s running=%s posted=%d" % [was_on, play.running, link.posted.size()])
    play.queue_free()
    link.queue_free()
    _app.camera.rotation = Vector3.ZERO

# The range: guns on the table in the hand, targets ahead shot by their rings, bolts that fly, a beam
# that must rest, a rail through everything on its line, a gun let go going back to the table, a click
# on a flat screen, and the result told with each gun's part.
func _range_checks() -> void:
    var link := FakeLink.new()
    root.add_child(link)
    var play := EliPlayClass.new()
    root.add_child(play)
    play.setup(_app, link, _presence, _things)
    _motion.set_here(true, "core_room", "Core Room")
    var arms := {"pistol": {"name": "Pistol", "class": "real", "fire": "shot", "rate": 0.0, "spread": 0.0, "shots": 1},
                 "shotgun": {"name": "Shotgun", "class": "real", "fire": "shot", "rate": 0.0, "spread": 0.0, "shots": 7},
                 "bolt": {"name": "Bolt caster", "class": "energy", "fire": "bolt", "rate": 0.0, "speed": 16.0, "drop": 3.0},
                 "beam": {"name": "Beam lance", "class": "sci-fi", "fire": "beam", "rate": 0.0, "hold": 0.3},
                 "rail": {"name": "Rail gun", "class": "sci-fi", "fire": "rail", "rate": 0.0, "charge": 0.1}}
    var lines := {"start": "Take a gun.", "hit": "Hit.", "miss": "Missed.", "end": "Done."}
    var rules := {"name": "The range", "kind": "range", "goal": "shoot the targets", "count": 6, "seconds": 60, "pace": 0.0,
                  "motion": "still", "arms": arms, "rings": [3, 2, 1], "lines": lines}
    var objects := [_game("r1", rules)]
    objects.append({"id": "rack", "name": "Gun table", "room": "core_room", "made_by": "eli", "kind": "built",
                    "piece": {"game": "r1", "role": "rack", "tag": "rack", "index": 0},
                    "form": {"shape": "table", "colour": "#8a5a3c", "size": 1.0, "glow": 0.0, "pos": [0.75, 0.0, 1.1], "turn": 90.0}})
    var n := 0
    for tag in arms:
        objects.append({"id": "arm_" + tag, "name": str(arms[tag]["name"]), "room": "core_room", "made_by": "eli", "kind": "built",
                        "piece": {"game": "r1", "role": "arm", "tag": tag, "index": n},
                        "form": {"shape": "arm", "colour": "#4fd2f2", "size": 1.0, "glow": 0.6, "pos": [0.5 + 0.1 * n, 0.78, 1.1], "turn": 180.0}})
        n += 1
    var spots := [[0.0, 1.2, 5.0], [2.0, 1.2, 5.0], [-2.0, 1.2, 5.0], [0.0, 1.6, 6.0], [1.0, 1.2, 5.0], [1.0, 1.2, 7.0]]
    for i in 6:
        var t := _piece("t%d" % (i + 1), "r1", "target", "target", i, "target", spots[i])
        t["form"]["turn"] = 180.0
        objects.append(t)
    var state := {"objects": objects}
    _things.apply_world_state(state)
    play.apply_world_state(state)
    await _frames(0.15)
    var targets: Array = play._pieces
    var guns: Array = play._arms
    var up: Array = targets.filter(func(t): return not t.is_gone())
    var guns_drawn: bool = guns.size() == 5 and guns.all(func(g): return g.has_method("aim") and not g.is_gone() and g._body.get_child_count() > 3)
    _check("the_range_begins_with_the_guns_on_the_table_and_a_target_up", play.running and targets.size() == 6 and up.size() == 1
           and guns_drawn and play._rack != null and not play._rack.is_gone() and _app.spoken.back() == "Take a gun.",
           "running=%s targets=%d up=%d guns=%d drawn=%s rack=%s" % [play.running, targets.size(), up.size(), guns.size(), guns_drawn, play._rack])
    for i in range(1, 6):
        play._bring_up(targets[i], 60.0)
    var by_tag := {}
    for g in guns:
        by_tag[str(g.piece.get("tag", ""))] = g
    # a shot from the pistol through the middle of the first target: three points
    var centre: Vector3 = targets[0].global_position + Vector3(0, targets[0].eye_height(), 0)
    # each gun is held so that its muzzle (a little above the hand) is on the line to the target
    var pistol = by_tag["pistol"]
    pistol.hold(centre + Vector3(0, -pistol.muzzle.y, 3.0), Vector3(0, 0, -1), Vector2.ZERO, 0.0)
    var aim: Dictionary = pistol.aim()
    # the muzzle lies ahead of the hand by the gun's own length, on the line to the target's middle
    var in_hand: bool = pistol.wielded and aim["dir"].is_equal_approx(Vector3(0, 0, -1)) \
        and absf(aim["from"].distance_to(centre) - (3.0 + pistol.muzzle.z)) < 0.01 and absf(aim["from"].y - centre.y) < 0.001
    play._shoot(pistol, play.arm_rules(pistol), null)
    var middle_ok: bool = play.score == 3 and play.hits == 1 and play.shots == 1 and play._by_arm.get("pistol") == {"shots": 1, "hits": 1, "points": 3} \
        and not play._live.has(targets[0]) and play._marks.size() == 1
    # the shotgun at the edge of the second: one point, and one shot however many pellets
    var edge: Vector3 = targets[1].global_position + Vector3(0, targets[1].eye_height(), 0) + Vector3(targets[1].target_radius() * 0.9, 0, 0)
    var shotgun = by_tag["shotgun"]
    shotgun.hold(edge + Vector3(0, -shotgun.muzzle.y, 3.0), Vector3(0, 0, -1), Vector2.ZERO, 0.0)
    play._shoot(shotgun, play.arm_rules(shotgun), null)
    var edge_ok: bool = play.score == 4 and play.hits == 2 and play.shots == 2 and play._by_arm["shotgun"]["points"] == 1
    _check("a_shot_scores_by_the_ring_it_hits", in_hand and middle_ok and edge_ok,
           "in hand %s, middle %s (score %d hits %d shots %d), edge %s (score %d)" % [in_hand, middle_ok, play.score, play.hits, play.shots, edge_ok, play.score])
    # a bolt flies from the caster and meets the third; a miss by a mile falls and is gone
    var third: Vector3 = targets[2].global_position + Vector3(0, targets[2].eye_height(), 0)
    var caster = by_tag["bolt"]
    caster.hold(third + Vector3(0, -caster.muzzle.y, 2.0), Vector3(0, 0, -1), Vector2.ZERO, 0.0)
    play._cast(caster, play.arm_rules(caster), null)
    var flying: bool = play._bolts.size() == 1
    await _frames(0.5)
    var bolt_ok: bool = flying and play.hits == 3 and play._bolts.is_empty() and play._by_arm["bolt"]["hits"] == 1
    caster.hold(third + Vector3(0, -caster.muzzle.y, 2.0), Vector3(1, 0, 0), Vector2.ZERO, 0.0)
    play._cast(caster, play.arm_rules(caster), null)
    await _frames(play.BOLT_SECONDS + 0.3)
    var gone: bool = play._bolts.is_empty() and play.hits == 3
    _check("a_bolt_flies_and_hits_what_it_meets_and_one_that_meets_nothing_is_gone", bolt_ok and gone,
           "flying %s hits %d bolts %d, gone %s" % [flying, play.hits, play._bolts.size(), gone])
    # a gun let go goes back to the table in a moment (while the game is still on: at its end the guns leave)
    var home: Vector3 = pistol.home
    pistol.end_grab()
    var waiting: bool = play._homing.has(pistol) and not pistol.wielded
    await _frames(play.HOME_SECONDS + 0.3)
    var homed: bool = not play._homing.has(pistol) and pistol._target.is_equal_approx(home) and pistol.basis.is_equal_approx(Basis.IDENTITY)
    _check("a_gun_let_go_goes_back_to_the_table", waiting and homed, "waiting %s homed %s target %s home %s" % [waiting, homed, pistol._target, home])
    # the beam must rest on the fourth for its hold; the rail goes through the fifth and the sixth at once
    var fourth: Vector3 = targets[3].global_position + Vector3(0, targets[3].eye_height(), 0)
    var lance = by_tag["beam"]
    lance.hold(fourth + Vector3(0, -lance.muzzle.y, 3.0), Vector3(0, 0, -1), Vector2.ZERO, 0.0)
    play._beam(lance, play.arm_rules(lance), 0.2)
    var resting: bool = play.hits == 3 and lance._beam != null and play._beam_on.has(lance)
    play._beam(lance, play.arm_rules(lance), 0.15)
    var burnt: bool = play.hits == 4 and play._by_arm["beam"]["hits"] == 1
    lance.beam_off()
    var fifth: Vector3 = targets[4].global_position + Vector3(0, targets[4].eye_height(), 0)
    var rail = by_tag["rail"]
    rail.hold(fifth + Vector3(0, -rail.muzzle.y, 3.0), Vector3(0, 0, -1), Vector2.ZERO, 0.0)
    play._rail(rail, play.arm_rules(rail), null)
    var through: bool = play.hits == 6 and play._by_arm["rail"]["hits"] == 2 and play._by_arm["rail"]["shots"] == 1 and play._live.is_empty()
    _check("a_beam_must_rest_on_a_target_and_a_rail_goes_through_every_target_on_its_line", resting and burnt and through and lance._beam == null,
           "resting %s burnt %s through %s (hits %d)" % [resting, burnt, through, play.hits])
    # the end: every target resolved, the result told with each gun's part
    await _frames(0.3)
    var told: Array = link.posted
    var result: Dictionary = told.back()[1] if not told.is_empty() else {}
    _check("the_range_tells_each_guns_part_in_the_result", not play.running and told.size() == 1 and told.back()[0] == "r1"
           and int(result.get("score", 0)) == 16 and int(result.get("hits", 0)) == 6 and int(result.get("shots", 0)) == 6
           and result.get("arms", {}).get("rail", {}).get("hits") == 2 and not bool(result.get("abandoned", true)),
           "running %s told %s" % [play.running, told])
    # on a flat screen a click fires the first gun from where you look
    _app.spoken.clear()
    var again := {"objects": [_game("r2", rules), objects[1], objects[2], _piece("u1", "r2", "target", "target", 0, "target", [0.0, 1.2, 5.0])]}
    again["objects"][1] = {"id": "rack2", "name": "Gun table", "room": "core_room", "made_by": "eli", "kind": "built",
                           "piece": {"game": "r2", "role": "rack", "tag": "rack", "index": 0},
                           "form": {"shape": "table", "colour": "#8a5a3c", "size": 1.0, "glow": 0.0, "pos": [0.75, 0.0, 1.1]}}
    again["objects"][2] = {"id": "arm2_pistol", "name": "Pistol", "room": "core_room", "made_by": "eli", "kind": "built",
                           "piece": {"game": "r2", "role": "arm", "tag": "pistol", "index": 0},
                           "form": {"shape": "arm", "colour": "#4fd2f2", "size": 1.0, "glow": 0.0, "pos": [0.5, 0.78, 1.1], "turn": 180.0}}
    _things.apply_world_state(again)
    play.apply_world_state(again)
    await _frames(0.15)
    var first: Vector3 = play._pieces[0].global_position + Vector3(0, play._pieces[0].eye_height(), 0)
    play._shoot_from_camera(first + Vector3(0, 0, 4.0), Vector3(0, 0, -1))      # from where you look: no muzzle
    _check("a_click_on_a_flat_screen_fires_the_first_gun", play.score == 3 and play.shots == 1 and play._by_arm.has("pistol"),
           "score %d shots %d by %s" % [play.score, play.shots, play._by_arm])
    play.stop()
    await _frames(0.2)
    play.queue_free()
    link.queue_free()

# Stands in for the app's settings, keeping what is set.
class Kept extends RefCounted:
    var saved := {}
    func get_value(key, fallback = null):
        return saved.get(key, fallback)
    func set_value(key, value) -> void:
        saved[key] = value
    func save_runtime() -> void:
        pass

# Which microphone is talked through, and that one giving only silence is passed over. Nothing is
# recorded here: the frames are put in by hand.
func _voice_checks() -> void:
    var listed := ["Default", "alsa_input.usb-Some_Headset_Audio-00.mono", "alsa_input.usb-Desk_Microphone-00.mono",
                   "alsa_input.pci-0000_00_1f.3.analog-stereo"]
    var headset := EliVoice._words("Some Headset (Runtime)")
    var by_headset := EliVoice.order_microphones(listed, ["", ""], headset)
    var by_name := EliVoice.order_microphones(listed, ["alsa_input.usb-Desk_Microphone-00.mono", "gone"], headset)
    var flat := EliVoice.order_microphones(listed, [], [])
    _check("the_headsets_own_microphone_is_tried_before_the_default", by_headset[0] == listed[1] and by_headset[1] == "Default"
           and by_name[0] == listed[2] and by_name[1] == listed[1] and flat[0] == "Default" and flat.size() == 4,
           "headset %s named %s flat %s" % [by_headset, by_name, flat])

    var settings := Kept.new()
    var voice := EliVoice.new()
    root.add_child(voice)
    voice.setup(null, null, settings)
    voice._inputs = ["Default", listed[1]]
    voice._frames = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
    var silent := not voice._heard_anything()
    voice._input_at = 1
    voice._frames.append(Vector2(0.0, 0.00003))     # the quietest a real microphone is
    var heard := voice._heard_anything()
    _check("a_microphone_giving_only_silence_is_passed_over_and_the_one_heard_is_kept", silent and heard
           and settings.saved.get("eli_bridge.microphone_found") == listed[1], "silent %s heard %s kept %s" % [silent, heard, settings.saved])
    voice.queue_free()
