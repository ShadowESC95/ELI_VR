class_name EliReadout
extends RefCounted

# ELI's own state put into lines for a screen, the same way in every room. `eli` is what the app
# hands a room: {"connected": bool, "state": the world feed, "mind": the model ELI thinks with,
# "mode": idle / listening / thinking / speaking}. Every line comes from ELI's world; nothing is
# filled in when it is missing.

const TROUBLE := Color("#ffb347")
const GOOD := Color("#8fe8a8")
const REFLECT := Color("#b9a4ff")
const PALE := Color("#d9e4f2")

static func _clock(ts) -> String:
    if typeof(ts) != TYPE_FLOAT and typeof(ts) != TYPE_INT:
        return "     "
    var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
    var t := Time.get_datetime_dict_from_unix_time(int(ts) + bias)
    return "%02d:%02d" % [t.hour, t.minute]

static func _colour_of(kind: String, tint: Color) -> Color:
    match kind:
        "error_detected", "runtime_fault", "evidence_weak", "memory_uncertainty", "trouble":
            return TROUBLE
        "task_completed", "repair_completed", "memory_recall", "review_completed", "goal_done":
            return GOOD
        "reflection", "insight", "belief_changed":
            return REFLECT
        "task_opened", "goal", "improvement_proposal", "upgrade_candidate", "ambition":
            return PALE
    return tint

## ELI's log, newest last, each line "HH:MM what happened". `keep` picks which kinds to show.
static func log_lines(eli: Dictionary, tint: Color, keep: Callable = Callable()) -> Array:
    var out := []
    for entry in (eli.get("state", {}) as Dictionary).get("log", []):
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var kind := str(entry.get("type", ""))
        if keep.is_valid() and not keep.call(kind):
            continue
        out.append(["%s %s" % [_clock(entry.get("ts")), str(entry.get("text", ""))], _colour_of(kind, tint)])
    return out

## The last `rows` of the log, so the newest is always at the bottom.
static func tail(lines: Array, rows: int) -> Array:
    return lines.slice(maxi(0, lines.size() - rows))

static func status_lines(eli: Dictionary, tint: Color) -> Array:
    var state: Dictionary = eli.get("state", {})
    var avatar: Dictionary = state.get("avatar", {})
    var lines := []
    lines.append(["doing   %s" % str(avatar.get("activity", "")).replace("_", " "), tint])
    lines.append(["now     %s" % str(eli.get("mode", "")), tint])
    if not str(eli.get("mind", "")).is_empty():
        lines.append(["mind    %s" % str(eli.get("mind")), tint])
    lines.append(["looks   %s" % str(avatar.get("expression", "")), tint])
    for thought in state.get("mind", []):
        if typeof(thought) == TYPE_DICTIONARY and str(thought.get("kind", "")) == "tone":
            lines.append(["tone    %s" % str(thought.get("text", "")), tint])
    var widgets: Dictionary = state.get("widgets", {})
    if not str(widgets.get("last_event", "")).is_empty():
        lines.append(["", tint])
        lines.append(["last    %s" % str(widgets.get("last_event")), PALE])
    return lines

static func measure_lines(eli: Dictionary, tint: Color) -> Array:
    var awareness: Dictionary = (eli.get("state", {}) as Dictionary).get("awareness", {})
    var lines := []
    for key in ["focus", "curiosity", "uncertainty", "evidence_confidence", "memory_confidence",
                "reflection_depth", "repair_pressure", "tool_activity", "cognitive_load", "autonomy_pressure"]:
        if awareness.has(key):
            var value := float(awareness[key])
            var colour := TROUBLE if key in ["uncertainty", "repair_pressure"] and value > 0.5 else tint
            lines.append(["%-15s %s %.2f" % [key.replace("_", " "), InfoScreen.bar(value, 12), value], colour])
    return lines

static func recent_lines(eli: Dictionary, tint: Color) -> Array:
    var lines := []
    for act in (eli.get("state", {}) as Dictionary).get("recent", []):
        if typeof(act) != TYPE_DICTIONARY:
            continue
        lines.append(["%s in %s" % [str(act.get("what", "")).replace("_", " "), str(act.get("room", "")).replace("_", " ")], tint])
        var why := str(act.get("why", ""))
        if not why.is_empty():
            lines.append(["  %s" % why, PALE])
    return lines

static func mind_lines(eli: Dictionary, tint: Color, kinds: Array = []) -> Array:
    var lines := []
    for thought in (eli.get("state", {}) as Dictionary).get("mind", []):
        if typeof(thought) != TYPE_DICTIONARY:
            continue
        var kind := str(thought.get("kind", ""))
        if not kinds.is_empty() and not kind in kinds:
            continue
        lines.append([kind.replace("_", " "), _colour_of(kind, tint).darkened(0.2)])
        for chunk in _wrap(str(thought.get("text", "")), 40):
            lines.append(["  " + chunk, _colour_of(kind, tint)])
    return lines

static func _wrap(text: String, width: int) -> Array:
    var out := []
    var line := ""
    for word in text.split(" ", false):
        if (line + " " + word).strip_edges().length() > width and not line.is_empty():
            out.append(line)
            line = word
        else:
            line = (line + " " + word).strip_edges()
    if not line.is_empty():
        out.append(line)
    return out

## What is on your agenda soon, from ELI's own: when, then what, earliest first.
static func coming_lines(eli: Dictionary, tint: Color) -> Array:
    var lines := []
    for item in (eli.get("state", {}) as Dictionary).get("coming_up", []):
        if typeof(item) != TYPE_DICTIONARY:
            continue
        lines.append([str(item.get("said", "")), PALE])
        var what := str(item.get("what", ""))
        lines.append(["  " + ("remind: " if str(item.get("kind", "")) == "reminder" else "") + what, tint])
    return lines

## What a screen says when ELI cannot be read.
static func idle_reason(eli: Dictionary) -> String:
    return "ELI is not connected" if not bool(eli.get("connected", false)) else "nothing yet"
