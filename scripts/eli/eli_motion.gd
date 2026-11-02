class_name EliMotion
extends Node

# Where ELI's light goes in the room, and why. ELI is not pinned to a spot: it goes to the thing it
# is making and pours itself into it while it grows; it comes to you while you talk to it, while it
# thinks about what you said and while it answers; otherwise it moves among what is its in the room
# (what it made, its memories, goals and beliefs) and stops to look at each. When ELI's world puts it
# in another room it rises and fades away, and when it comes back it flies in.
#
# Nothing here decides what ELI does: that is ELI's world. This only shows it where you can see it.

# How quickly the light follows its target: the stiffness of a critically damped spring, gentle
# when it wanders, quicker when it is called or has work to do.
const WANDER_PULL := 1.1
const ERRAND_PULL := 2.6
# Where it stops beside you: ahead, to one side, a little below your eyes.
const BESIDE_YOU := Vector3(0.45, -0.15, -1.25)
# The height it keeps above the floor when it moves about.
const LOWEST := 0.8
const HIGHEST := 2.6

var _app: Node
var _presence: EliPresence
var _things: EliThings
var _velocity := Vector3.ZERO
var _target := Vector3.ZERO
var _pull := WANDER_PULL
var _errand: Node3D            # the thing ELI is making, while it grows
var _errand_left := 0.0
var _looking_at: Node3D        # what it has stopped by
var _linger := 0.0
var _here := false
var _your_room := ""
var _fade := 0.0               # 0 gone, 1 fully here
var _rng := RandomNumberGenerator.new()

func setup(app: Node, presence: EliPresence, things: EliThings) -> void:
    _app = app
    _presence = presence
    _things = things
    _rng.randomize()
    things.appeared.connect(_on_made)
    things.changed.connect(_on_made)

## Whether ELI is in the room you are in (or has been called to it). When ELI goes elsewhere
## it is seen leaving, and coming back it flies in; when you go to another room, ELI is simply
## there or not.
func set_here(here: bool, your_room: String, eli_room_name: String = "") -> void:
    if your_room != _your_room:
        _your_room = your_room
        _here = here
        _fade = 1.0 if here else 0.0
        _presence.visible = here
        _velocity = Vector3.ZERO
        _errand = null
        _errand_left = 0.0
        if here:
            _choose_wander()
            _presence.global_position = _target
        return
    if here == _here:
        return
    _here = here
    if here:
        _presence.visible = true
        _presence.global_position = _arrival_point()
        _velocity = Vector3.ZERO
        _choose_wander()
    elif _presence.visible and not eli_room_name.is_empty():
        _presence.note("went to %s" % eli_room_name, 4.0)

## ELI relit the room: it rises to the middle of the room while the light changes.
func relit() -> void:
    if _here:
        _errand = null
        _errand_left = 3.0
        _target = Vector3(0.0, HIGHEST + 0.6, 0.0)
        _pull = ERRAND_PULL

func _on_made(thing: Node3D) -> void:
    if not _here or thing == null:
        return
    _errand = thing
    _errand_left = 4.0
    _pull = ERRAND_PULL

func _camera() -> Camera3D:
    return _app.get_viewport().get_camera_3d() if _app != null else null

# The edge of the room on the far side from you: ELI comes in from there.
func _arrival_point() -> Vector3:
    var camera := _camera()
    var from := camera.global_position if camera != null else Vector3.ZERO
    var away := (-camera.global_transform.basis.z if camera != null else Vector3.FORWARD) * Vector3(1, 0, 1)
    if away.length() < 0.01:
        away = Vector3.FORWARD
    return from + away.normalized() * 7.0 + Vector3(0, 1.4, 0)

func _beside_you() -> Vector3:
    var camera := _camera()
    if camera == null:
        return EliPresence.HOME
    var basis := camera.global_transform.basis
    var flat_forward := (-basis.z * Vector3(1, 0, 1)).normalized()
    var flat_right := (basis.x * Vector3(1, 0, 1)).normalized()
    return camera.global_position + flat_right * BESIDE_YOU.x - flat_forward * BESIDE_YOU.z + Vector3(0, BESIDE_YOU.y, 0)

# Somewhere to go next, of its own: one of its things, or a spot near you when there are none.
func _choose_wander() -> void:
    _pull = WANDER_PULL
    var mine := _things.standing() if _things != null else []
    mine = mine.filter(func(t): return t != _looking_at)
    if not mine.is_empty():
        _looking_at = mine[_rng.randi() % mine.size()]
        var by := _looking_at.global_position
        var camera := _camera()
        var toward_you := Vector3.ZERO
        if camera != null:
            toward_you = ((camera.global_position - by) * Vector3(1, 0, 1)).normalized()
        _target = by + toward_you * 0.7 + Vector3(0, _looking_at.call("eye_height") + 0.45, 0)
    else:
        _looking_at = null
        var camera := _camera()
        var centre := camera.global_position if camera != null else Vector3.ZERO
        var a := _rng.randf() * TAU
        _target = centre + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(1.6, 3.2)
        _target.y = centre.y + _rng.randf_range(-0.35, 0.15)        # about the height of your eyes
    _linger = _rng.randf_range(4.0, 9.0)

func _process(delta: float) -> void:
    if _presence == null:
        return
    # fading in and out
    var want := 1.0 if _here else 0.0
    _fade = move_toward(_fade, want, delta / 1.4)
    if _fade <= 0.0 and not _here:
        _presence.visible = false
        return
    _presence.scale = Vector3.ONE * maxf(0.01, _fade)
    if not _here:
        _velocity += Vector3(0, 2.2, 0) * delta          # leaving: up and away
        _presence.global_position += _velocity * delta
        return

    var talking := _presence.mode in ["listening", "thinking", "speaking"]
    if _errand_left > 0.0:
        _errand_left -= delta
        if is_instance_valid(_errand):
            var at := _errand.global_position + Vector3(0, _errand.call("eye_height") + 0.55, 0)
            var camera := _camera()
            if camera != null:
                at += ((camera.global_position - _errand.global_position) * Vector3(1, 0, 1)).normalized() * 0.6
            _target = at
            _presence.pour_into(_errand.global_position + Vector3(0, _errand.call("eye_height") * 0.6, 0))
            _presence.look_toward(_errand.global_position)
        if _errand_left <= 0.0:
            _errand = null
            _presence.pour_into(Vector3.INF)
            _choose_wander()
    elif talking:
        _pull = ERRAND_PULL
        _target = _beside_you()
        _presence.look_toward(Vector3.INF)
    else:
        _linger -= delta
        if _looking_at != null and is_instance_valid(_looking_at):
            _presence.look_toward(_looking_at.global_position)
        else:
            _presence.look_toward(Vector3.INF)
        if _linger <= 0.0 or (_looking_at != null and not is_instance_valid(_looking_at)):
            _choose_wander()

    _target.y = clampf(_target.y, LOWEST, HIGHEST + 0.6)
    # a critically damped spring: no overshoot, no snapping
    var offset := _target - _presence.global_position
    var accel := offset * _pull * _pull - _velocity * 2.0 * _pull
    _velocity += accel * delta
    _presence.global_position += _velocity * delta
