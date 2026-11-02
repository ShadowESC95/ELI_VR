class_name EliThoughts
extends Node3D

# What is on ELI's mind, rising from its light now and then: its latest insight, the moments of
# its own waiting to be made into something, the goal it holds first, its tone. The words come
# from ELI's records through its world (the feed's "mind"); nothing is made up here. They rise
# while ELI is on its own or thinking, more often while it thinks, and never while it listens to
# you or answers.

const RISE := 0.9               # metres a thought climbs before it is gone
const SECONDS := 7.0
const LINE := 34                # characters a line holds
const LINES := 3

var _presence: EliPresence
var _mind: Array = []
var _next := 0
var _wait := 3.0
var _rng := RandomNumberGenerator.new()

func setup(presence: EliPresence) -> void:
    _presence = presence
    top_level = true
    _rng.randomize()

func apply_world_state(state: Dictionary) -> void:
    var mind = state.get("mind", [])
    if typeof(mind) != TYPE_ARRAY:
        return
    _mind = mind.filter(func(t): return typeof(t) == TYPE_DICTIONARY and not str(t.get("text", "")).strip_edges().is_empty())

func _process(delta: float) -> void:
    if _presence == null or not _presence.visible or _mind.is_empty():
        return
    if _presence.mode in ["dormant", "listening", "speaking"]:
        return
    _wait -= delta
    if _wait > 0.0:
        return
    _rise(_mind[_next % _mind.size()])
    _next += 1
    _wait = _rng.randf_range(4.0, 7.0) if _presence.mode == "thinking" else _rng.randf_range(10.0, 16.0)

func _colour(kind: String) -> Color:
    var own: Color = _presence.tint_now()
    match kind:
        "trouble": return Color("#ffb347")
        "goal", "goal_done": return Color("#8fe8a8")
        "ambition": return Color("#c58bff")
        "belief": return Color("#d9e4f2")
        _: return own.lightened(0.35)

func _wrap(text: String) -> String:
    var words := text.split(" ", false)
    var lines: Array[String] = []
    var line := ""
    for word in words:
        if (line + " " + word).strip_edges().length() > LINE and not line.is_empty():
            lines.append(line)
            line = word
            if lines.size() == LINES:
                break
        else:
            line = (line + " " + word).strip_edges()
    if lines.size() < LINES and not line.is_empty():
        lines.append(line)
    var shown := "\n".join(lines)
    return shown if shown.length() >= text.length() - 1 else shown + "…"

func _rise(thought: Dictionary) -> void:
    var label := Label3D.new()
    label.text = _wrap(str(thought.get("text", "")))
    label.font_size = 26
    label.pixel_size = 0.0018
    label.outline_size = 5
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.modulate = Color(_colour(str(thought.get("kind", ""))), 0.0)
    label.outline_modulate = Color(0, 0, 0, 0.0)
    add_child(label)
    var a := _rng.randf() * TAU
    var start := _presence.global_position + Vector3(cos(a) * 0.25, 0.32, sin(a) * 0.25)
    label.global_position = start
    var tween := create_tween()
    tween.set_parallel(true)
    tween.tween_property(label, "global_position", start + Vector3(cos(a) * 0.2, RISE, sin(a) * 0.2), SECONDS) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(label, "modulate:a", 1.0, 0.8)
    tween.tween_property(label, "outline_modulate:a", 0.6, 0.8)
    tween.tween_property(label, "modulate:a", 0.0, 2.2).set_delay(SECONDS - 2.2)
    tween.tween_property(label, "outline_modulate:a", 0.0, 2.2).set_delay(SECONDS - 2.2)
    tween.chain().tween_callback(label.queue_free)
