extends SceneTree

# Drives ELI's motion and initiative headless with the real orb and things, and prints one line per
# check: "PASS name" or "FAIL name: what happened". tests/test_eli_alive.py runs it.

const EliPresenceClass = preload("res://scripts/eli/eli_presence.gd")
const EliThingsClass = preload("res://scripts/eli/eli_things.gd")
const EliMotionClass = preload("res://scripts/eli/eli_motion.gd")
const EliInitiativeClass = preload("res://scripts/eli/eli_initiative.gd")

# Stands in for the app: a camera where you stand, a room, and the BUILD action, which takes a while.
class StandIn extends Node3D:
    var built := 0
    var room_root: Node3D
    var camera: Camera3D
    func current_room_id() -> String:
        return "core_room"
    func eli_build() -> void:
        built += 1
        await get_tree().create_timer(0.3).timeout

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
    _voice_checks()
    quit()

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
