extends SceneTree

# The screens that show ELI's state: what they say, and that they say nothing made up. Prints one
# line per check, "PASS name" or "FAIL name: what happened". tests/test_eli_alive.py runs it.

const DebugBunker = preload("res://scripts/world/rooms/debug_bunker.gd")
const Archive = preload("res://scripts/world/rooms/memory_cathedral.gd")
const Thing = preload("res://scripts/eli/eli_thing.gd")

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

    var archive = Archive.new()
    root.add_child(archive)
    archive.build({}, Settings.new())
    var spots := []
    for i in archive.MEMORY_BAYS.size() * archive.MEMORY_SLOTS:
        spots.append(archive.pin_spot("memory", i))
    var on_shelf := spots.all(func(s): return s is Transform3D and absf(s.origin.y - (archive.EYE_SHELF + 0.025)) < 0.001)
    var apart := true
    for i in spots.size():
        for j in range(i + 1, spots.size()):
            apart = apart and (spots[i] as Transform3D).origin.distance_to((spots[j] as Transform3D).origin) > 0.5
    # face out: a cover looks into the room (straight out from its flat bay, so near the middle)
    var facing := spots.all(func(s): return (s as Transform3D).basis.z.dot(-Vector3(s.origin.x, 0, s.origin.z).normalized()) > 0.95)
    var ahead := (spots[0] as Transform3D).origin.z < -10.0
    _check("memories_stand_on_the_shelf", on_shelf and apart and facing and ahead,
           "on shelf %s, apart %s, facing %s, first ahead %s" % [on_shelf, apart, facing, ahead])
    _check("only_memories_have_a_place", archive.pin_spot("memory", spots.size()) == null
           and archive.pin_spot("claim", 0) == null and archive.pin_spot("memory", -1) == null, "")
    var gap := archive._memory_slot_near(archive._memory_x(2) - 0.02, 0.04)
    var between := archive._memory_slot_near((archive._memory_x(2) + archive._memory_x(3)) * 0.5 - 0.02, 0.04)
    _check("no_book_where_a_memory_stands", gap and not between, "at a memory %s, between two %s" % [gap, between])

    var memory = Thing.new()
    archive.add_child(memory)
    memory.build({"id": "m0", "name": "A walk by the canal", "kind": "memory",
                  "meaning": "A walk along the canal path in light rain.", "form": {"shape": "orb", "colour": "#9fd8ff"}})
    memory.pin_to(spots[0])
    var written := _labels(memory)
    var reads := written.map(func(l): return (l as Label3D).text)
    _check("a_memory_is_written_on_its_cover", "A walk by the canal" in reads and "A walk along the canal path in light rain." in reads,
           str(reads))
    _check("writing_starts_inside_the_page", written.all(func(l): return absf((l as Label3D).position.x + 0.129) < 0.01),
           str(written.map(func(l): return (l as Label3D).position)))
    quit()

func _labels(node: Node) -> Array:
    var out := []
    for child in node.get_children():
        if child is Label3D and (child as Label3D).visible:
            out.append(child)
        out.append_array(_labels(child))
    return out
