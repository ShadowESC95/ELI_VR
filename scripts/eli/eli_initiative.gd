class_name EliInitiative
extends Node

# ELI making something of its own while you are there to see it. When a moment of ELI's own is
# waiting to be made into something (an insight, a goal, a trouble: ELI's world keeps them, see
# eli/world/urges.py in ELI v3), ELI is in your room with nothing else to do, and ELI's world says
# it is free (a model already in memory, nobody's mood asking it to hold back), ELI VR asks ELI to
# act on it: what ELI makes, and where in its house, is ELI's.
#
# It never presses: not while you talk to ELI, not while one act is under way, and after each act
# you have been quiet for three times as long as that act took before the next. The pace is this
# machine's own.

var _app: Node
var _presence: EliPresence
var _waiting := 0
var _free := false
var _busy := false
var _quiet := 0.0
var _last_took := 0.0

func setup(app: Node, presence: EliPresence) -> void:
    _app = app
    _presence = presence

func apply_world_state(state: Dictionary) -> void:
    _waiting = int(state.get("waiting", 0))
    _free = bool(state.get("free", false))

func _process(delta: float) -> void:
    if _presence == null:
        return
    if _presence.mode in ["listening", "thinking", "speaking"]:
        if not _busy:
            _quiet = 0.0
        return
    _quiet += delta
    if _busy or _waiting <= 0 or not _free or not _presence.visible or _presence.mode == "dormant":
        return
    if _quiet < _last_took * 3.0:
        return
    _act()

func _act() -> void:
    _busy = true
    _waiting = 0                  # until ELI's world says again
    var started := Time.get_ticks_msec()
    _presence.set_mode("thinking")
    await _app.eli_build()
    if _presence.mode == "thinking":
        _presence.set_mode("idle")
    _last_took = (Time.get_ticks_msec() - started) / 1000.0
    _quiet = 0.0
    _busy = false
