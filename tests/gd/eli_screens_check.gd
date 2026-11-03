extends SceneTree

# The screens that show ELI's state: what they say, and that they say nothing made up. Prints one
# line per check, "PASS name" or "FAIL name: what happened". tests/test_eli_alive.py runs it.

const DebugBunker = preload("res://scripts/world/rooms/debug_bunker.gd")

# Stands in for the app's settings: every value as its default.
class Settings extends RefCounted:
    func get_value(_key, fallback = null):
        return fallback

func _initialize() -> void:
    _run.call_deferred()

func _check(name: String, ok: bool, detail: String) -> void:
    print(("PASS %s" % name) if ok else ("FAIL %s: %s" % [name, detail]))

func _texts(screen: InfoScreen) -> Array:
    var out := []
    for child in screen.get_children():
        if child is Label3D and child != screen._title:
            out.append((child as Label3D).text)
    return out

func _run() -> void:
    var tint := Color("#63ddff")
    var screen := InfoScreen.make(Vector2(1.4, 0.7), "Log", tint, 20)
    root.add_child(screen)
    var taller := InfoScreen.make(Vector2(1.4, 1.4), "Log", tint, 20)
    root.add_child(taller)
    _check("fits_its_rows", screen.rows() > 0 and taller.rows() >= screen.rows() * 2,
           "%d rows, %d when twice as tall" % [screen.rows(), taller.rows()])
    screen.show_lines(["x".repeat(30), ["short", Color.RED]])
    var shown := _texts(screen)
    _check("cuts_a_long_line", shown[0].length() == 20 and shown[0].ends_with("…"), "first line %s" % shown[0])

    var eli := {"connected": true, "mind": "", "mode": "idle", "state": {"log": [
        {"type": "reasoning_stage", "source": "reasoning_engine", "text": "Stage 1/2", "ts": 1_790_000_000.0},
        {"type": "error_detected", "source": "executor", "text": "WEB_SEARCH failed: the network is off", "ts": 1_790_000_060.0},
        {"type": "task_completed", "source": "executor", "text": "NOTE_SAVE worked.", "ts": 1_790_000_120.0},
    ]}}
    var lines := EliReadout.log_lines(eli, tint)
    _check("log_in_order", lines.size() == 3 and str(lines[2][0]).ends_with("NOTE_SAVE worked."), str(lines))
    _check("trouble_in_amber", lines[1][1] == EliReadout.TROUBLE and lines[2][1] == EliReadout.GOOD, str(lines))
    var troubles := EliReadout.log_lines(eli, tint, func(kind): return kind == "error_detected")
    _check("strand_keeps_its_kind", troubles.size() == 1 and "WEB_SEARCH" in str(troubles[0][0]), str(troubles))
    _check("tail_is_the_newest", EliReadout.tail(lines, 2)[0] == lines[1], str(EliReadout.tail(lines, 2)))

    var room = DebugBunker.new()
    root.add_child(room)
    room.build({}, Settings.new())
    room.show_eli({"connected": false})
    var said := _texts(room._board)
    _check("says_when_not_connected", said[0] == "ELI is not connected" and said.slice(1).all(func(t): return t == ""), str(said))
    room.show_eli(eli)
    said = _texts(room._board).filter(func(t): return t != "")
    _check("board_shows_the_log", said.size() == 3 and said[2].ends_with("NOTE_SAVE worked."), str(said))
    quit()
