extends SceneTree

# The screens that show ELI's state: what they say, and that they say nothing made up. Prints one
# line per check, "PASS name" or "FAIL name: what happened". tests/test_eli_alive.py runs it.

const DebugBunker = preload("res://scripts/world/rooms/debug_bunker.gd")
const Archive = preload("res://scripts/world/rooms/memory_cathedral.gd")
const Thing = preload("res://scripts/eli/eli_thing.gd")
const EvidenceWall = preload("res://scripts/world/rooms/evidence_studio.gd")
const Workshop = preload("res://scripts/world/rooms/workshop_bay.gd")
const Core = preload("res://scripts/world/rooms/orbital_core.gd")
const UpgradeBay = preload("res://scripts/world/rooms/fabrication_lab.gd")
const Anomaly = preload("res://scripts/world/rooms/anomaly_void.gd")
const Things = preload("res://scripts/eli/eli_things.gd")
const Forest = preload("res://scripts/world/rooms/forest_sanctuary.gd")
const Ocean = preload("res://scripts/world/rooms/ocean_platform.gd")
const Desert = preload("res://scripts/world/rooms/desert_observatory.gd")
const Mountain = preload("res://scripts/world/rooms/mountain_observatory.gd")
const Underwater = preload("res://scripts/world/rooms/underwater_lab.gd")
const Arctic = preload("res://scripts/world/rooms/arctic_aurora.gd")
const BlackHole = preload("res://scripts/world/kit/black_hole.gd")
const Book = preload("res://scripts/eli/eli_book.gd")
const OwnRoomClass = preload("res://scripts/world/rooms/own_room.gd")
const Factory = preload("res://scripts/world/room_factory.gd")
const Manipulator = preload("res://scripts/xr/world_manipulator.gd")

# Stands in for the app's settings: every value as its default.
class Settings extends RefCounted:
    func get_value(_key, fallback = null):
        return fallback

# Stands in for the desktop helper: keeps what would have gone to the desktop, and sends nothing.
class FakeHelper extends Node:
    var sent := []
    func send_input(event: Dictionary) -> bool:
        sent.append(event)
        return true
    func status_text() -> String:
        return "off"

# The desktop's settings, switched off so nothing reaches a real helper.
class DesktopSettings extends RefCounted:
    var saved := {}
    func get_value(key, fallback = null):
        if saved.has(key):
            return saved[key]
        return 3 if key == "desktop.layout_version" else (false if key == "desktop.enabled" else fallback)
    func set_value(key, value) -> void:
        saved[key] = value
    func save_runtime() -> void:
        pass

# Stands in for the link to ELI v3 serving a model ELI brought in: its files from a folder here.
class ModelLink extends Node:
    var folder := ""
    var asked := []
    var reported := 0
    func can(capability: String) -> bool:
        return capability == "models" or capability == "props"
    func fetch(path: String, _capability: String = "pictures") -> EliResult:
        asked.append(path)
        var rel := path.trim_prefix("/v1/world/model/")
        var file := folder.path_join(rel.get_slice("/", 0)).path_join(rel.substr(rel.find("/") + 1))
        if not FileAccess.file_exists(file):
            return EliResult.bad("unsupported")
        return EliResult.good(FileAccess.get_file_as_bytes(file))
    func report_body() -> EliResult:
        reported += 1
        return EliResult.good()

# Stands in for the link to ELI v3: serves one picture, a 6 by 3 PNG.
class PictureLink extends Node:
    var asked := []
    func can(capability: String) -> bool:
        return capability == "pictures"
    func fetch(path: String) -> EliResult:
        asked.append(path)
        var image := Image.create(6, 3, false, Image.FORMAT_RGB8)
        image.fill(Color(0.2, 0.6, 0.9))
        return EliResult.good(image.save_png_to_buffer())

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

    # ELI's thoughts (the feed's "thoughts"): what it decided, why, how sure, what became of it
    var thoughtful := {"connected": true, "mind": "", "mode": "idle", "state": {"log": [], "thoughts": [
        {"kind": "action", "room": "debug_basement", "what": "open app for spotify failed", "why": ["the app was not found"],
         "chance": 0.2, "decision": "tried", "reason": "open url had worked instead", "status": "open", "outcome": "",
         "when": 1_790_000_200.0, "words": "Open app for spotify failed."},
        {"kind": "recall", "room": "memory_archive", "what": "you prefer early starts", "why": [], "chance": 0.72,
         "decision": "shown", "reason": "readiest to mind", "status": "settled", "outcome": "right", "when": 1_790_000_100.0, "words": ""}]}}
    var thought := EliReadout.thought_lines(thoughtful, tint)
    _check("thoughts_are_lines", thought.size() == 6 and str(thought[0][0]).ends_with("open app for spotify failed")
           and str(thought[1][0]) == "  tried: open url had worked instead" and str(thought[2][0]) == "  chance 20%"
           and str(thought[5][0]) == "  chance 72% · proved right", str(thought))
    var only_actions := EliReadout.thought_lines(thoughtful, tint, ["action"])
    _check("thoughts_keep_their_kind", only_actions.size() == 3 and only_actions[0][1] == EliReadout.TROUBLE, str(only_actions))
    _check("thoughts_keep_their_room", EliReadout.thought_lines(thoughtful, tint, [], "memory_archive").size() == 3, "")
    room.show_eli(thoughtful)
    said = _texts(room._board).filter(func(t): return t != "")
    _check("board_shows_what_eli_tried", said.size() >= 3 and said[0].ends_with("open app for spotify failed")
           and said[1] == "  tried: open url had worked instead", str(said))

    var archive = Archive.new()
    root.add_child(archive)
    archive.build({}, Settings.new())
    var spots := []
    for i in archive.MEMORY_BAYS.size() * archive.MEMORY_SLOTS:
        spots.append(archive.pin_spot("memory", i))
    var on_shelf := spots.all(func(s): return s is Transform3D and absf(s.origin.y - (archive.memory_board() + 0.025)) < 0.001)
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

    # a memory is a book of one page, what ELI remembers written on its cover
    var memory = Book.new()
    archive.add_child(memory)
    memory.build({"id": "m0", "name": "A walk by the canal", "kind": "memory",
                  "meaning": "A walk along the canal path in light rain.", "form": {"shape": "orb", "colour": "#9fd8ff"}})
    memory.pin_to(spots[0])
    var written := _labels(memory._closed).filter(func(l): return l.name.begins_with("Cover"))
    var reads := " ".join(written.map(func(l): return (l as Label3D).text.replace("\n", " ")))
    _check("a_memory_is_written_on_its_cover", "A walk by the canal" in reads and "A walk along the canal path in light rain." in reads,
           reads)
    var inside := written.all(func(l): return _within(l, memory._size.x))
    _check("writing_starts_inside_the_page", not written.is_empty() and inside,
           str(written.map(func(l): return [(l as Label3D).position, (l as Label3D).text])))
    memory.position = spots[0].origin
    var rest: Vector3 = memory._body.position
    for n in 30:
        memory._process(0.1)
    _check("a_written_record_holds_still", memory._body.position.is_equal_approx(rest), str(memory._body.position))

    # what ELI did for you: each kind has its room's places, and only that room's
    var homes := {"found": EvidenceWall, "written": Workshop, "playing": Core}
    var kept := {"found": 6, "written": 6, "playing": 1}
    var placed := true
    for kind in homes:
        var home = homes[kind].new()
        root.add_child(home)
        home.build({}, Settings.new())
        for i in kept[kind]:
            placed = placed and home.pin_spot(kind, i) is Transform3D
        placed = placed and home.pin_spot(kind, kept[kind]) == null
        for other in homes:
            if other != kind:
                placed = placed and home.pin_spot(other, 0) == null
        if kind == "found":
            placed = placed and home.pin_spot("claim", 0) is Transform3D          # the beliefs keep theirs
        home.queue_free()
    _check("what_eli_did_has_its_places", placed, "")

    var radio = Thing.new()
    root.add_child(radio)
    var song := {"id": "playing", "name": "Harbour Lights", "kind": "playing", "meaning": "The Quiet Ferries",
                 "lines": ["The Quiet Ferries", "Low Tide"], "form": {"shape": "lamp", "colour": "#e8e2d4"}}
    radio.build(song)
    radio.pin_to(Transform3D.IDENTITY)
    var card := _labels(radio).map(func(l): return (l as Label3D).text)
    var named := card.any(func(t): return "Harbour Lights" in t and "Low Tide" in t)
    song["name"] = "Night Ferry"
    song["lines"] = ["The Quiet Ferries", "paused"]
    radio.refresh(song)
    await process_frame
    card = _labels(radio).map(func(l): return (l as Label3D).text)
    var moved_on := card.any(func(t): return "Night Ferry" in t and "(paused)" in t) and not card.any(func(t): return "Harbour Lights" in t)
    _check("the_radio_says_what_is_playing", named and moved_on, str(card))

    var printout = Thing.new()
    root.add_child(printout)
    printout.build({"id": "found_1", "name": "Searched: when do the tides turn", "kind": "found", "meaning": "Tide times",
                    "lines": ["Tide times explained", "    example.org"], "form": {"shape": "board", "colour": "#e8e2d4"}})
    printout.pin_to(Transform3D.IDENTITY)
    var printed := _labels(printout).map(func(l): return (l as Label3D).text)
    _check("a_finding_is_printed_with_its_lines", "Searched: when do the tides turn" in printed
           and "Tide times explained\n    example.org" in printed, str(printed))

    var bay = UpgradeBay.new()
    root.add_child(bay)
    bay.build({}, Settings.new())
    # the racks' lights are the room's own: how hard ELI is working, or ELI being away, leaves them as built
    var built := [bay._leds.get_shader_parameter("pace"), bay._leds.get_shader_parameter("busy")]
    var after := []
    for working in [{"connected": true, "state": {"awareness": {"cognitive_load": 0.9, "tool_activity": 0.2}}},
                    {"connected": true, "state": {"awareness": {"cognitive_load": 0.1, "tool_activity": 0.0}}},
                    {"connected": false}]:
        bay.show_eli(working)
        after.append([bay._leds.get_shader_parameter("pace"), bay._leds.get_shader_parameter("busy")])
    _check("the_racks_keep_their_own_pace_whatever_eli_is_doing", built[0] != null and after.all(func(a): return a == built),
           "built %s, then %s" % [built, after])

    # what ELI may place: every real thing, by id, with what it is and how big
    var offered := EliProps.catalogue()
    var chair_offer := offered.filter(func(p): return p["id"] == "ArmChair_01")
    _check("eli_is_told_the_real_things_there_are", offered.size() >= 40 and chair_offer.size() == 1
           and chair_offer[0]["name"] == "arm chair" and float(chair_offer[0]["size"][1]) > 0.9, str(chair_offer))
    var chair = Thing.new()
    root.add_child(chair)
    chair.build({"id": "c", "name": "Arm Chair", "kind": "built",
                 "form": {"shape": "prop", "prop": "ArmChair_01", "size": 1.0, "pos": [2.0, 0.0, 1.0], "turn": 90.0}})
    var turned: bool = is_equal_approx(chair._body.rotation.y, deg_to_rad(90.0))
    var drawn: bool = chair._body.get_child_count() == 1 and not chair._name_tag.visible and absf(chair.eye_height() - 0.535) < 0.05
    var missing = Thing.new()
    root.add_child(missing)
    missing.build({"id": "m", "name": "Sofa", "kind": "built", "form": {"shape": "prop", "prop": "no_such_sofa", "pos": [0, 0, 0]}})
    _check("a_real_thing_is_its_model_turned_as_eli_turned_it", turned and drawn and missing.shape == "orb",
           "turned %s, drawn %s, missing as %s" % [turned, drawn, missing.shape])
    var hung = Thing.new()
    root.add_child(hung)
    hung.build({"id": "p1", "name": "Dusk", "kind": "built", "form": {"shape": "painting", "size": 1.0, "pos": [0.0, 1.6, 4.0],
                "turn": 180.0, "art": {"style": "horizon", "colours": ["#8b6cf0", "#f5b942"]}}})
    var standing = Thing.new()
    root.add_child(standing)
    standing.build({"id": "p2", "name": "Dawn", "kind": "built", "form": {"shape": "painting", "size": 1.0, "pos": [1.0, 0.0, 4.0]}})
    var canvas: MeshInstance3D = hung._body.get_child(0)
    var styled: int = (canvas.material_override as ShaderMaterial).get_shader_parameter("style")
    var core = Core.new()
    root.add_child(core)
    core.build({}, Settings.new())
    core.show_eli({"connected": true, "state": {"coming_up": [
        {"when": 1.0, "said": "today (Mon 2 Nov) at 19:30", "what": "Ferry to the island", "kind": "event"},
        {"when": 2.0, "said": "tomorrow (Tue 3 Nov) at 08:00", "what": "Water the basil", "kind": "reminder"}]}})
    var agenda := _texts(core._coming)
    var coming_ok: bool = agenda[0] == "today (Mon 2 Nov) at 19:30" and agenda[1] == "  Ferry to the island" \
        and agenda[3] == "  remind: Water the basil"
    core.show_eli({"connected": true, "state": {"coming_up": []}})
    var none_ok: bool = _texts(core._coming)[0] == "nothing on the agenda"
    _check("the_core_shows_what_is_coming_up", coming_ok and none_ok, str(agenda))
    var wall = EvidenceWall.new()
    root.add_child(wall)
    wall.build({}, Settings.new())
    var link := PictureLink.new()
    root.add_child(link)
    EliPictures.link = link
    var sight = Thing.new()
    wall.add_child(sight)
    sight.build({"id": "seen_31", "name": "A screenshot", "kind": "seen", "meaning": "The desktop",
                 "lines": ["The desktop, two windows open"], "picture": "/v1/world/picture/31",
                 "form": {"shape": "board", "colour": "#e8e2d4"}})
    var placed_at = wall.pin_spot("seen", 0)
    sight.pin_to(placed_at)
    await process_frame
    var faces: Array = sight._body.get_children().filter(func(n): return n is MeshInstance3D)
    var shown_face: StandardMaterial3D = faces[1].material_override
    var pictured: bool = shown_face.albedo_texture != null and is_equal_approx((faces[1].mesh as QuadMesh).size.x / (faces[1].mesh as QuadMesh).size.y, 2.0)
    var radio_model := ModelCache.scene("boombox")
    var cached: bool = radio_model != null and ModelCache.scene("boombox") == radio_model and ModelCache.scene("no_such_model") == null
    ModelCache.warm()
    var frames := 0
    while (ModelCache.poll() > 0 or not ModelCache._asked.is_empty()) and frames < 20000:
        frames += 1
        await process_frame
    _check("models_load_once_in_the_background_and_are_kept", cached and ModelCache._held.size() >= 40 and frames < 20000,
           "kept %s, held %d after %d frames" % [cached, ModelCache._held.size(), frames])
    await _desktop_checks()
    await _models_check()
    _check("a_picture_eli_took_is_pinned_up_as_a_photograph", placed_at is Transform3D and wall.pin_spot("seen", 4) == null
           and pictured and link.asked == ["/v1/world/picture/31"], "placed %s, pictured %s, asked %s" % [placed_at is Transform3D, pictured, link.asked])
    _check("a_painting_is_painted_and_stands_on_an_easel_on_the_floor", styled == 5 and hung.eye_height() < 0.6
           and standing.eye_height() > 0.8 and standing._body.get_child_count() > hung._body.get_child_count(),
           "style %d, hung %s, standing %s" % [styled, hung.eye_height(), standing.eye_height()])
    await _thought_checks(wall)
    _land_checks()
    await _room_checks()
    await _knowledge_checks()
    quit()

# ELI's thoughts hang as sheets: six rooms keep places for them, a sheet is written with its lines
# under its kind's tab, and the one in the user's hand is reported as the record it is.
func _thought_checks(wall) -> void:
    var homes := {"evidence_wall": wall, "debug_basement": DebugBunker, "upgrade_bay": UpgradeBay, "core_room": Core,
                  "memory_archive": Archive, "anomaly_room": Anomaly}
    var placed := true
    var apart := true
    for name in homes:
        var home = homes[name] if homes[name] is Node else homes[name].new()
        if not home is Node or not home.is_inside_tree():
            root.add_child(home)
            home.build({}, Settings.new())
        var spots := []
        for i in 6:
            var spot = home.pin_spot("thought", i)
            placed = placed and spot is Transform3D
            if spot is Transform3D:
                spots.append(spot)
        placed = placed and home.pin_spot("thought", 6) == null and home.pin_spot("thought", -1) == null
        for i in spots.size():
            for j in range(i + 1, spots.size()):
                apart = apart and (spots[i] as Transform3D).origin.distance_to((spots[j] as Transform3D).origin) > 0.5
        if home != wall:
            home.queue_free()
    _check("thought_sheets_have_places_in_six_rooms", placed and apart, "placed %s apart %s" % [placed, apart])
    var sheet = Thing.new()
    wall.add_child(sheet)
    sheet.build({"id": "thought_12", "name": "claim: you live in Harbour Town", "kind": "thought",
                 "meaning": "You live in Harbour Town. Held because confirmed twice.",
                 "lines": ["you live in Harbour Town", "held: confirmed twice", "chance 90% · proved right"],
                 "thought": {"kind": "claim", "chance": 0.9, "decision": "held", "status": "settled", "outcome": "right"},
                 "form": {"shape": "board", "colour": "#d9e4f2", "size": 0.6, "glow": 0.8, "pos": [0, 0, 0]}})
    sheet.pin_to(wall.pin_spot("thought", 0))
    var written := _labels(sheet).map(func(l): return (l as Label3D).text)
    var record: Dictionary = sheet.record()
    _check("a_thought_sheet_is_written_under_its_kinds_tab", "CLAIM" in written and "claim: you live in Harbour Town" in written
           and "you live in Harbour Town\nheld: confirmed twice\nchance 90% · proved right" in written
           and record == {"id": "thought_12", "kind": "thought", "name": "claim: you live in Harbour Town",
                          "lines": ["you live in Harbour Town", "held: confirmed twice", "chance 90% · proved right"]},
           str(written))
    var things = Things.new()
    root.add_child(things)
    things.show_room("evidence_wall")
    things.apply_world_state({"objects": [
        {"id": "thought_12", "name": "claim: you live in Harbour Town", "kind": "thought", "room": "evidence_wall", "meaning": "x",
         "lines": ["you live in Harbour Town"], "thought": {"kind": "claim"}, "form": {"shape": "board", "colour": "#d9e4f2", "pos": [0, 1, 2]}},
        {"id": "built_lamp", "name": "Lamp", "kind": "built", "room": "evidence_wall", "made_by": "eli",
         "form": {"shape": "lamp", "colour": "#f5b942", "size": 1.0, "glow": 0.8, "pos": [2, 0, 2]}}]})
    await process_frame
    var none_held: bool = things.held_record().is_empty()
    things._things["built_lamp"].begin_grab()
    var a_thing_is_not: bool = things.held_record().is_empty()
    things._things["built_lamp"].end_grab()
    things._things["thought_12"].begin_grab()
    var held: Dictionary = things.held_record()
    things._things["thought_12"].end_grab()
    _check("the_sheet_in_the_users_hand_is_reported_as_its_record", none_held and a_thing_is_not
           and held == {"id": "thought_12", "kind": "thought", "name": "claim: you live in Harbour Town", "lines": ["you live in Harbour Town"]},
           "none %s thing %s held %s" % [none_held, a_thing_is_not, held])
    things.queue_free()

# The land: its height is the mesh's, what is stood on it stands on it, the ground cover sits on it,
# its edge settles flat, the blades are drawn with their alpha, and the forest builds on it.
func _land_checks() -> void:
    var room = RoomBase.new()
    root.add_child(room)
    var land := LandKit.lay(room, LandKit.blend("sand", 3.0, Color.WHITE, "rock", 2.0, Color.WHITE), 7, 0.03, 3, 120.0, 60, 6.0, 10.0, 8.0, 4.0, -0.2, 20.0)
    var vertices: PackedVector3Array = land.ground.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    var agree := true
    var rises := false
    for i in range(0, vertices.size(), 97):
        var v := vertices[i]
        agree = agree and absf(land.y_at(v.x, v.z) - v.y) < 0.001
        rises = rises or v.y > 0.5
    var flat_middle: bool = absf(land.y_at(3.0, -4.0) + 0.2) < 0.0001
    var flat_edge: bool = absf(land.y_at(59.9, 0.0) + 0.2) < 0.001 and absf(land.y_at(0.0, -59.9) + 0.2) < 0.001
    var stone = land.on(room, "boulder_01", Vector3(24.0, 0.1, 9.0), 30.0, 1.2, true)
    var on_ground: bool = stone != null and absf(stone.position.y - (land.y_at(24.0, 9.0) + 0.1)) < 0.0001 \
        and absf(stone.scale.x - 1.2) < 0.001 and stone.basis.y.dot(Vector3.UP) > 0.8
    var rng := RandomNumberGenerator.new()
    rng.seed = 3
    var field := land.cover(room, LandKit.tuft("grass", 1), LandKit.sway_material("grass", Color.WHITE, 0.05, 1.0), 24, 12.0, 30.0, rng)
    var stood: PackedVector3Array = field.get_meta("stood_at")
    var sits := field.multimesh.instance_count == 24 and stood.size() == 24
    for at in stood:
        sits = sits and absf(at.y - (land.y_at(at.x, at.z) - 0.03)) < 0.0001 and Vector2(at.x, at.z).length() >= 11.99
    var blade := LandKit.blade_texture("needle")
    var image := blade.get_image()
    var clear := 0
    var drawn := 0
    for y in range(0, image.get_height(), 8):
        for x in image.get_width():
            if image.get_pixel(x, y).a < 0.5:
                clear += 1
            else:
                drawn += 1
    var blades_ok: bool = clear > 0 and drawn > 0 and LandKit.blade_texture("needle") == blade and image.get_pixel(32, image.get_height() - 1).a > 0.5
    var sound := EliArms.sound("shot")
    var hum := EliArms.sound("beam")
    var sounds_ok: bool = sound.data.size() > 4000 and hum.loop_mode == AudioStreamWAV.LOOP_FORWARD and EliArms.sound("rail").data.size() > sound.data.size()
    _check("the_land_knows_its_height_and_what_stands_on_it_stands_on_it", agree and rises and flat_middle and flat_edge and on_ground and sits,
           "agree %s rises %s middle %s edge %s stone %s cover %s" % [agree, rises, flat_middle, flat_edge, on_ground, sits])
    _check("ground_cover_blades_are_drawn_and_the_guns_have_their_sounds", blades_ok and sounds_ok, "blades %s sounds %s" % [blades_ok, sounds_ok])
    var forest = Forest.new()
    root.add_child(forest)
    forest.build({}, Settings.new())
    var fields := forest.get_children().filter(func(c): return c is MultiMeshInstance3D)
    _check("the_forest_stands_on_its_floor_with_boughs_and_cover", forest._land != null and fields.size() >= 6
           and fields.any(func(f): return (f as MultiMeshInstance3D).multimesh.instance_count == 46 * 3),
           "land %s fields %d" % [forest._land != null, fields.size()])
    forest.queue_free()
    room.queue_free()

# A model ELI brought in: fetched from the feed's list once, loaded while running, measured, in the
# catalogue ELI is told of, and drawn as itself. The files come from the bundled side table, served
# by a stand-in link, into the sandbox folder the test was given.
func _models_check() -> void:
    var sandbox := OS.get_environment("ELI_VR_TEST_SANDBOX")
    if sandbox.is_empty() or not _in_sandbox(ProjectSettings.globalize_path(EliModels.FOLDER), sandbox):
        _check("a_model_eli_brought_in_is_fetched_once_measured_and_drawn", false,
               "not run: %s is not in the test's sandbox" % ProjectSettings.globalize_path(EliModels.FOLDER))
        return
    var link := ModelLink.new()
    root.add_child(link)
    link.folder = ProjectSettings.globalize_path("user://served")
    var served := link.folder.path_join("little_table")
    DirAccess.make_dir_recursive_absolute(served.path_join("textures"))
    var src := ProjectSettings.globalize_path("res://assets/models/side_table_01")
    var files := []
    for f in DirAccess.get_files_at(src):
        if not f.ends_with(".import") and not f.ends_with(".uid"):
            DirAccess.copy_absolute(src.path_join(f), served.path_join(f))
            files.append(f)
    for f in DirAccess.get_files_at(src.path_join("textures")):
        if not f.ends_with(".import"):
            DirAccess.copy_absolute(src.path_join("textures").path_join(f), served.path_join("textures").path_join(f))
            files.append("textures/" + f)
    files.sort_custom(func(a, b): return a.ends_with(".gltf") and not b.ends_with(".gltf"))
    EliModels.link = link
    var feed := [{"id": "little_table", "name": "Little Table", "size": [1, 1, 1], "files": files + ["../escape.bin"],
                  "source": "Poly Haven side_table_01", "licence": "CC0 1.0"}]
    await EliModels.want(feed)
    await EliModels.want(feed)                      # the same list again: nothing more is fetched
    var listed := EliModels.listed()
    var size: Array = listed.get("little_table", {}).get("size", [])
    var in_catalogue := EliProps.catalogue().filter(func(e): return e["id"] == "little_table")
    var scene := ModelCache.scene("little_table")
    var thing = Thing.new()
    root.add_child(thing)
    thing.build({"id": "t1", "name": "A table", "room": "own_room", "form": {"shape": "prop", "prop": "little_table",
                 "colour": "#ffffff", "size": 1.0, "glow": 0.0, "pos": [0, 0, 2]}})
    var drawn: int = thing._body.find_children("*", "MeshInstance3D", true, false).size()
    var ok: bool = link.asked.size() == files.size() and listed.has("little_table") and bool(listed["little_table"]["measured"]) \
        and size.size() == 3 and float(size[1]) > 0.3 and float(size[1]) < 1.5 and in_catalogue.size() == 1 \
        and in_catalogue[0]["name"] == "little table" and scene != null and drawn > 0 and link.reported == 1 \
        and not FileAccess.file_exists(ProjectSettings.globalize_path(EliModels.FOLDER).path_join("escape.bin"))
    _check("a_model_eli_brought_in_is_fetched_once_measured_and_drawn", ok,
           "asked %d of %d, listed %s, catalogue %s, scene %s, drawn %d, reported %d" % [link.asked.size(), files.size(),
           listed.get("little_table"), in_catalogue, scene != null, drawn, link.reported])
    thing.queue_free()
    link.queue_free()
    EliModels.link = null

func _desktop_checks() -> void:
    var eye := Camera3D.new()
    root.add_child(eye)
    eye.current = true
    var settings := DesktopSettings.new()
    settings.saved["desktop.distance_m"] = 2.0
    var desk := DesktopSurface.new()
    root.add_child(desk)
    desk.setup(settings, false, {})
    var helper := FakeHelper.new()
    desk.bridge = helper
    desk.visible = true                         # shown, with no helper behind it
    var tile := Image.create(240, 240, false, Image.FORMAT_RGBA8)
    desk._on_tiles(Vector2i(3840, 2160), [[Rect2i(0, 0, 240, 240), tile]])
    desk.place()                                # the viewer at the origin, looking down -Z

    # curved round the viewer, one desktop pixel to one display pixel, and pointed at where it shows
    var density := desk._display_density()
    var round_ok: bool = absf(desk.span() - 3840.0 / density) < 0.0001 and absf(desk.radius_m() - 2.0) < 0.0001 \
        and absf(desk.seen_angle() - desk.arc()) < 0.0001 and desk._view.size == Vector2i(3840, 2160)
    var on_curve := true
    for vertex in desk._mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
        var from_axis := desk.to_global(vertex)
        on_curve = on_curve and absf(Vector2(from_axis.x, from_axis.z).length() - 2.0) < 0.001
    var ahead: Dictionary = desk.ray_hit(Vector3.ZERO, Vector3.FORWARD)
    var turned := 0.6
    var aside: Dictionary = desk.ray_hit(Vector3.ZERO, Basis(Vector3.UP, -turned) * Vector3.FORWARD)
    var up: Dictionary = desk.ray_hit(Vector3.ZERO, Vector3(0, 0.5, -2.0))
    var behind: Dictionary = desk.ray_hit(Vector3.ZERO, Vector3.BACK)
    var hits_ok: bool = not ahead.is_empty() and ahead["uv"].distance_to(Vector2(0.5, 0.5)) < 0.0001 \
        and absf(ahead["distance"] - 2.0) < 0.0001 \
        and absf(aside["uv"].x - (0.5 + turned / desk.arc())) < 0.0001 \
        and absf(up["uv"].y - (0.5 - 0.5 / desk.height_m())) < 0.0001 and behind.is_empty()
    desk.scale_px = 5.0                         # larger than all the way round: it stops short
    desk.place()
    var never_closes: bool = desk.arc() < TAU and desk.arc() > TAU * 0.99
    desk.scale_px = 1.0
    desk.place()
    _check("the_desktop_curves_round_you_one_pixel_to_one_and_is_pointed_at_where_it_shows",
           round_ok and on_curve and hits_ok and never_closes, "round %s, on its curve %s, ahead %s aside %s up %s behind %s, never closes %s"
           % [round_ok, on_curve, ahead, aside, up, behind, never_closes])

    # the runtime's cylinder is given the same shape as the mesh that cuts its hole
    var layer := ClassDB.instantiate("OpenXRCompositionLayerCylinder") as Node3D
    desk.add_child(layer)
    desk._layer = layer
    desk._layer_kind = "OpenXRCompositionLayerCylinder"
    desk._shape_layer()
    var shaped: bool = absf(layer.get("radius") - desk.radius_m()) < 0.0001 and absf(layer.get("central_angle") - desk.arc()) < 0.0001 \
        and absf(layer.get("aspect_ratio") - 3840.0 / 2160.0) < 0.0001 and layer.position.is_equal_approx(Vector3(0, 0, desk.radius_m()))
    desk._drop_layer()
    _check("the_runtime_layer_has_the_screens_shape", shaped, "radius %s angle %s aspect %s at %s" % [layer.get("radius"),
           layer.get("central_angle"), layer.get("aspect_ratio"), layer.position])

    desk.curve = 0.0
    desk.place()
    var edge := desk.width_m() * 0.5
    var left: Dictionary = desk.ray_hit(Vector3.ZERO, Vector3(-edge * 0.999, 0, -2.0))
    var past: Dictionary = desk.ray_hit(Vector3.ZERO, Vector3(-edge * 1.001, 0, -2.0))
    _check("a_flat_desktop_is_pointed_at_where_it_shows", not left.is_empty() and left["uv"].x < 0.001 and past.is_empty()
           and desk._mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == 4, "left %s past %s" % [left, past])

    desk.point_uv(Vector2(0.5, 0.5), "left", true)
    desk.point_uv(Vector2(0.5, 0.5), "", false, -1)
    var sent: Array = helper.sent
    _check("pointing_at_the_desktop_moves_clicks_and_scrolls_it", sent == [{"kind": "move", "x": 0.5, "y": 0.5},
           {"kind": "button", "button": "left", "down": true}, {"kind": "scroll", "steps": -1}], str(sent))

    # held: the stick up for a second doubles it, left flattens it, pulling the hand in halves its distance
    desk.curve = 0.5
    desk.place()
    var hand := Vector3(0.3, -0.2, -0.6)
    desk.begin_hold(hand, Vector3.FORWARD)
    var scale_before: float = desk.scale_px
    for _i in 10:
        desk.hold(hand, Vector3.FORWARD, Vector2(0.0, 1.0), 0.1)
    for _i in 10:
        desk.hold(hand, Vector3.FORWARD, Vector2(-1.0, 0.0), 0.04)
    desk.hold(hand * 0.5, Vector3.FORWARD, Vector2.ZERO, 0.0)
    var turned_with := desk.global_basis.z
    desk.hold(hand * 0.5, Basis(Vector3.UP, 0.4) * Vector3.FORWARD, Vector2.ZERO, 0.0)
    desk.end_hold()
    var held_ok: bool = absf(desk.scale_px / scale_before - 2.0) < 0.001 and absf(desk.curve - 0.1) < 0.001 \
        and absf(desk.distance - 1.0) < 0.001 and absf(desk.yaw - 0.4) < 0.001 and turned_with.is_equal_approx(Vector3.BACK) \
        and is_equal_approx(float(settings.saved.get("desktop.scale", 0.0)), snappedf(desk.scale_px, 0.0001))
    _check("holding_the_desktop_moves_sizes_curves_and_brings_it_nearer", held_ok,
           "scale x%s curve %s distance %s yaw %s saved %s" % [desk.scale_px / scale_before, desk.curve, desk.distance,
           desk.yaw, settings.saved])

    # hands, panels and ELI are drawn over it; the room is not, nor the screen itself
    var front := Node3D.new()
    root.add_child(front)
    var solid := MeshInstance3D.new()
    solid.mesh = BoxMesh.new()
    solid.material_override = StandardMaterial3D.new()
    front.add_child(solid)
    var words := Label3D.new()
    front.add_child(words)
    var shared := StandardMaterial3D.new()
    var in_room := MeshInstance3D.new()
    in_room.mesh = BoxMesh.new()
    in_room.mesh.material = shared
    root.add_child(in_room)
    desk.keep_in_front(front)
    var later := MeshInstance3D.new()
    later.mesh = in_room.mesh                   # the room's own mesh and material, used again in front
    front.add_child(later)
    await process_frame
    await process_frame
    var lifted: StandardMaterial3D = solid.material_override
    var front_ok: bool = lifted.render_priority == DesktopSurface.FRONT_PRIORITY \
        and lifted.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS \
        and words.render_priority == DesktopSurface.FRONT_PRIORITY \
        and later.get_surface_override_material(0) != null \
        and later.get_surface_override_material(0).render_priority == DesktopSurface.FRONT_PRIORITY \
        and shared.render_priority == 0 and shared.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED \
        and desk._mesh.material_override.render_priority == DesktopSurface.SCREEN_PRIORITY
    _check("hands_panels_and_eli_are_drawn_over_the_desktop_and_the_room_is_not", front_ok,
           "solid %s/%s words %s later %s shared %s/%s screen %s" % [lifted.render_priority, lifted.transparency,
           words.render_priority, later.get_surface_override_material(0), shared.render_priority, shared.transparency,
           desk._mesh.material_override.render_priority])
    front.queue_free()
    in_room.queue_free()
    desk.queue_free()
    eye.queue_free()
    await _desktop_link_check()

# The link to the desktop helper, against a stand-in helper here: the key first, the screen as tiles,
# then only what changed, and pointer lines back. Its key goes in the sandbox the test was given.
func _desktop_link_check() -> void:
    var sandbox := OS.get_environment("ELI_VR_TEST_SANDBOX")
    if sandbox.is_empty() or not _in_sandbox(DesktopBridgeClient.key_path(), sandbox):
        _check("the_desktop_link_gives_the_key_and_reads_the_screen_as_tiles", false,
               "not run: the key's folder %s is not the test's sandbox" % DesktopBridgeClient.key_path())
        return
    DirAccess.make_dir_recursive_absolute(DesktopBridgeClient.key_path().get_base_dir())
    var key_file := FileAccess.open(DesktopBridgeClient.key_path(), FileAccess.WRITE)
    key_file.store_string("the-key")
    key_file.close()
    var server := TCPServer.new()
    server.listen(0, "127.0.0.1")
    var link := DesktopBridgeClient.new()
    root.add_child(link)
    link.configure("127.0.0.1", server.get_local_port())
    var got := []
    link.tiles_arrived.connect(func(screen, tiles): got.append([screen, tiles]))
    link.start()
    var waited := 0
    while not server.is_connection_available() and waited < 500:
        waited += 1
        await process_frame
    var helper := server.take_connection()
    var hello := ""
    while helper and not hello.ends_with("\n") and waited < 1000:
        waited += 1
        helper.poll()
        if helper.get_available_bytes() > 0:
            hello += helper.get_utf8_string(helper.get_available_bytes())
        await process_frame
    var whole := _tile_message(4, 2, [[Rect2i(0, 0, 2, 2), 10], [Rect2i(2, 0, 2, 2), 20]])
    var part := _tile_message(4, 2, [[Rect2i(2, 0, 2, 2), 30]])
    if helper:
        helper.put_data(whole)
        helper.put_data(part)
    while got.size() < 1 and waited < 1500:
        waited += 1
        await process_frame
    while link.status_text() != "connected" and waited < 1500:
        waited += 1
        await process_frame
    link.send_input({"kind": "scroll", "steps": 2})
    var back := ""
    while helper and not back.ends_with("\n") and waited < 2000:
        waited += 1
        helper.poll()
        if helper.get_available_bytes() > 0:
            back += helper.get_utf8_string(helper.get_available_bytes())
        await process_frame
    var newest := {}
    for batch in got:
        for t in batch[1]:
            newest[t[0]] = t[1].get_pixel(0, 0).r8
    var link_ok: bool = JSON.parse_string(hello) == {"kind": "hello", "key": "the-key"} and not got.is_empty() \
        and got[0][0] == Vector2i(4, 2) and newest == {Rect2i(0, 0, 2, 2): 10, Rect2i(2, 0, 2, 2): 30} \
        and JSON.parse_string(back) == {"kind": "scroll", "steps": 2.0}
    _check("the_desktop_link_gives_the_key_and_reads_the_screen_as_tiles", link_ok,
           "hello %s, tiles %s, back %s" % [hello.strip_edges(), newest, back.strip_edges()])
    link.stop()
    link.queue_free()
    server.stop()
    DirAccess.remove_absolute(DesktopBridgeClient.key_path())

## Whether a path is under the test's sandbox folder: Windows gives one with forward slashes and the
## other with backslashes, and spells the drive either way.
func _in_sandbox(path: String, sandbox: String) -> bool:
    return path.replace("\\", "/").to_lower().begins_with(sandbox.replace("\\", "/").to_lower())

## An ELIT message: the screen's size, then each tile filled with one grey.
func _tile_message(width: int, height: int, tiles: Array) -> PackedByteArray:
    var out := StreamPeerBuffer.new()
    out.big_endian = true
    out.put_data("ELIT".to_ascii_buffer())
    for n in [width, height, tiles.size()]:
        out.put_u32(n)
    for t in tiles:
        var rect: Rect2i = t[0]
        for n in [rect.position.x, rect.position.y, rect.size.x, rect.size.y]:
            out.put_u32(n)
        for _p in rect.size.x * rect.size.y:
            out.put_data(PackedByteArray([t[1], t[1], t[1], 255]))
    return out.data_array

# --- ELI's books, the Evidence Wall's records, the bookcase in ELI's room ------------------------

# Stands in for the link to ELI v3 serving its books whole by id (GET /v1/world/book/<id>), or failing.
class BookLink extends Node:
    var asked := []
    var books := {}
    func can(capability: String) -> bool:
        return capability == "books"
    func fetch(path: String, _capability: String = "pictures") -> EliResult:
        asked.append(path)
        var id := path.trim_prefix("/v1/world/book/")
        if not books.has(id):
            return EliResult.bad("unsupported", "no such book", 404)
        return EliResult.good(JSON.stringify({"id": id, "book": {}, "sections": books[id]}).to_utf8_buffer())

# Stands in for a room that keeps one place for a belief, and then none.
class Pinner extends Node:
    var allow := true
    func pin_spot(kind: String, index: int) -> Variant:
        return Transform3D(Basis.IDENTITY, Vector3(float(index), 1.0, -2.0)) if allow and kind == "claim" else null

const T0 := 1_790_000_000.0
const DAY := 86400.0

func _book_record(id: String, of: String, title: String, from: float, sections: Array, room: String = "memory_archive", extra: Dictionary = {}) -> Dictionary:
    var book := {"of": of, "title": title, "spine": title, "about": "", "from": from, "to": from + 3600.0, "sections": sections}
    book.merge(extra, true)
    return {"id": id, "name": title, "kind": "book", "room": room, "meaning": "", "when": from, "book": book,
            "form": {"shape": "board", "colour": "#6b4f9a", "size": 1.0, "glow": 0.0, "pos": [0.0, 0.0, 2.0]}}

func _texts_under(node: Node) -> Array:
    return _labels(node).map(func(l): return (l as Label3D).text)

func _knowledge_checks() -> void:
    # writing sized by where it is read: the angle a capital fills is the same held, at a shelf or across a room
    var arcs := [Reading.in_hand(), Reading.at_arm(), Reading.before_board(), 13.0].all(
        func(d): return absf(atan(Reading.em(d) * Reading.CAP / d) - Reading.ARC) < 0.0002)
    var inks := [Color(0.95, 0.92, 0.84), EliBook.MANILA, EliBook.LEATHER, Color(0.015, 0.022, 0.03), Color(0.78, 0.6, 0.3)].all(
        func(paper): return Reading.contrast(Reading.ink(paper), paper) >= Reading.CONTRAST)
    var wrapped := Reading.wrap_lines("aaaaaaaaaaaaaaaaaaaa bb", 8)
    var wraps: bool = wrapped == ["aaaaaaaa", "aaaaaaaa", "aaaa bb"]
    var said := "the first light came over the hill and the gulls rose from the water one by one"
    var cut := Reading.paginate([{"heading": "Morning", "text": said + "\n" + said}], Reading.typed(), Reading.DRAWN,
                                Reading.measurer(Reading.typed()).call("x".repeat(20)), 4)
    var flowed := []
    var fits := true
    for page in cut:
        fits = fits and (page["lines"] as Array).size() <= 4 and str(page["lines"][0]) != ""
        for line in page["lines"]:
            if str(line) != "MORNING":
                flowed.append_array(str(line).split(" ", false))
    var kept_words: bool = " ".join(flowed) == said + " " + said
    _check("writing_is_sized_for_where_it_is_read_and_stands_out_from_its_paper", arcs and inks and wraps and fits and kept_words,
           "arcs %s inks %s wraps %s pages %s words %s" % [arcs, inks, wrapped, fits, kept_words])

    # a book: its pages cut to fit, its cover and spine saying what it is and when
    var words := []
    for i in 400:
        words.append("word%d" % i)
    var story := _book_record("book_story_1", "story", "The Lighthouse Keeper's Week", T0,
        [{"heading": "One", "text": " ".join(words)}, {"heading": "Two", "text": "The tide came in.\nThe lamp was lit."}],
        "memory_archive", {"about": "A story ELI wrote from a week of logs", "by": "ELI", "drawn_from": ["a session of 2 Nov"]})
    var book = Book.new()
    root.add_child(book)
    book.build(story)
    var held := Reading.in_hand()
    var room_px: float = (book._page.x - 2.0 * Book.MARGIN * Reading.em(held)) / Reading.pixel(held)
    var rows := Book._rows_for(book._page, Reading.eye_height())
    var measure := Reading.measurer(Reading.printed())
    var paged := book.page_count() > 2
    var read := []
    for page in book._pages:
        paged = paged and (page["lines"] as Array).size() <= rows
        for line in page["lines"]:
            paged = paged and float(measure.call(str(line))) <= room_px + 0.5
            if not str(line) in ["ONE", "TWO", ""]:
                read.append_array(str(line).split(" ", false))
    var in_order: bool = " ".join(read) == " ".join(words) + " The tide came in. The lamp was lit."
    _check("a_book_cuts_its_writing_into_pages_that_fit_and_keeps_every_word_in_order", paged and in_order,
           "pages %d of %d rows, fit %s, in order %s" % [book.page_count(), rows, paged, in_order])
    var cover := " ".join(_labels(book._closed).filter(func(l): return l.name.begins_with("Cover")).map(func(l): return (l as Label3D).text.replace("\n", " ")))
    var spine := _labels(book._closed).filter(func(l): return not l.name.begins_with("Cover")).map(func(l): return (l as Label3D).text)
    var grip: Shape3D = book._grip_shape.shape
    _check("a_book_says_on_its_cover_and_spine_what_it_is_and_when", "The Lighthouse Keeper's Week" in cover
           and "A story ELI wrote from a week of logs" in cover and Reading.span(T0, T0 + 3600.0) in cover
           and spine.size() == 1 and str(spine[0]).begins_with("The Lighthouse") and grip is BoxShape3D
           and (grip as BoxShape3D).size.is_equal_approx(book._size), "cover %s spine %s grip %s" % [cover, spine, grip])

    # taken down: open in the hand, facing the eye; the trigger, the stick and the other hand turn pages; let go, back to its place
    var slot := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(1.0, 1.4, -3.0))
    book.pin_to(slot)
    book.begin_grab()
    var opened: bool = book.opened and book._open.visible and not book._closed.visible
    var hand := Vector3(0.0, 1.2, -0.4)
    var aim := Vector3(0.0, 0.0, -1.0)
    book.hold(hand, aim, Vector2.ZERO, 0.016)
    var camera := root.get_viewport().get_camera_3d()
    var eye: Vector3 = camera.global_position if camera != null else hand - aim * Reading.in_hand()
    var facing: bool = book.global_transform.basis.z.dot((eye - hand).normalized()) > 0.9
    var turned := []
    book.press(true)
    turned.append(book.spread)                  # 1
    book.press(true)
    turned.append(book.spread)                  # still 1: one press, one page
    book.press(false)
    book.press(true)
    turned.append(book.spread)                  # 2
    book.press(false)
    book.hold(hand, aim, Vector2(0.9, 0.0), 0.016)
    turned.append(book.spread)                  # 3: a flick
    book.hold(hand, aim, Vector2(0.5, 0.0), 0.016)
    turned.append(book.spread)                  # still 3 until the stick comes back
    book.hold(hand, aim, Vector2(0.0, 0.0), 0.016)
    book.hold(hand, aim, Vector2(-0.9, 0.0), 0.016)
    turned.append(book.spread)                  # 2: flicked back
    var other := Node.new()
    book.swipe(other, Vector3(book._page.x * 0.6, 0.0, 0.01))
    book.swipe(other, Vector3(-book._page.x * 0.3, 0.0, 0.01))
    turned.append(book.spread)                  # 3: the other hand drawn across from the right page
    for n in book.spreads() + 2:
        book.turn_page(1)
    var last_ok: bool = book.spread == book.spreads() - 1
    book.spread = 1
    book._show_spread()
    var reading: Dictionary = book.record()
    var first_shown := str(book.spread_pages(1)[0]["lines"][0]).split(" ", false)[0]
    var tells: bool = reading["id"] == "book_story_1" and reading["kind"] == "book" and reading["name"] == "The Lighthouse Keeper's Week" \
        and not (reading["lines"] as Array).is_empty() and (reading["lines"] as Array).size() <= Book.REPORT_LINES \
        and str(reading["lines"][0]).begins_with(first_shown) and (reading["lines"] as Array).all(func(l): return str(l).length() <= Book.REPORT_WIDTH)
    var moved := [0]
    book.let_go.connect(func(_t): moved[0] += 1)
    book.end_grab()
    for n in 80:
        book._process(0.05)
    var back: bool = not book.opened and book._closed.visible and book.position.distance_to(slot.origin) < 0.01 \
        and book.basis.z.dot(slot.basis.z) > 0.999 and moved[0] == 0
    _check("a_book_taken_down_opens_in_the_hand_turns_its_pages_and_goes_back_to_its_place",
           opened and facing and turned == [1, 1, 2, 3, 3, 2, 3] and last_ok and tells and back,
           "opened %s facing %s turned %s last %s tells %s back %s (%s)" % [opened, facing, turned, last_ok, tells, back, reading])
    book.queue_free()

    # the Archive: ELI's books by time along the eye-level shelf, a plate where each month begins, stories on their own
    var archive = Archive.new()
    root.add_child(archive)
    archive.build({}, Settings.new())
    var month := 30.0 * DAY
    var told := [
        _book_record("book_c2", "conversation", "Planting the tomatoes", T0 + month, [{"heading": "You", "text": "When do the seedlings go out?"}]),
        _book_record("book_s1", "session", "A morning of questions", T0, [{"heading": "", "text": "Questions about the garden."}]),
        _book_record("book_p3", "period", "The second week", T0 + 2.0 * month, [{"heading": "Monday", "text": "Rain."}]),
        _book_record("book_c1b", "conversation", "Fixing the bicycle", T0 + 5.0 * 3600.0, [{"heading": "You", "text": "The chain slips."}]),
        _book_record("book_tale", "story", "The Quiet Ferry", T0 + DAY, [{"heading": "", "text": "Once, on the river..."}]),
    ]
    var shelved = Things.new()
    root.add_child(shelved)
    shelved.pinner = archive
    shelved.show_room("memory_archive")
    shelved.apply_world_state({"objects": told})
    await process_frame
    var order := ["book_s1", "book_c1b", "book_c2", "book_p3"]
    var first_case: Bookcase = archive._record_cases[0]
    var xs := order.map(func(id): return (first_case.to_room.affine_inverse() * (shelved._things[id] as Node3D).position).x)
    var along := true
    for i in range(1, xs.size()):
        along = along and float(xs[i]) > float(xs[i - 1])
    var on_row: bool = order.all(func(id): return absf((shelved._things[id] as Node3D).position.y - float(first_case.tops[0])) < 0.001)
    var spine_out: bool = order.all(func(id): return (shelved._things[id] as Node3D).basis.x.dot(-(first_case.to_room.basis.z)) > 0.99)
    var plates := _texts_under(first_case._plates)
    var months: bool = plates == [Reading.month(T0), Reading.month(T0 + month), Reading.month(T0 + 2.0 * month)]
    var story_case: Bookcase = archive._story_cases[0]
    var tale: Vector3 = story_case.to_room.affine_inverse() * (shelved._things["book_tale"] as Node3D).position
    var stories_apart: bool = absf(tale.x) < story_case.width * 0.5 and absf(tale.y - float(story_case.tops[0])) < 0.001
    _check("the_archive_shelves_elis_books_by_time_with_a_plate_where_each_month_begins",
           along and on_row and spine_out and months and stories_apart,
           "along %s row %s spine out %s plates %s stories %s" % [along, on_row, spine_out, plates, stories_apart])
    var say := func(eli: Dictionary) -> String:
        archive.show_eli(eli)
        var card: Label3D = first_case._empty
        return card.text if card != null and card.visible else ""
    var empties := [say.call({"connected": false}), say.call({"connected": true, "can": ["world-state"], "state": {"objects": []}}),
                    say.call({"connected": true, "can": ["books"], "state": {"objects": []}}),
                    say.call({"connected": true, "can": ["books"], "state": {"objects": told}})]
    _check("bare_shelves_say_why_from_the_data", empties == ["ELI is not connected", "this ELI does not keep books yet", "nothing on record yet", ""],
           str(empties))
    shelved.queue_free()
    archive.queue_free()

    # ELI's own room: a bookcase of its own books, a shelf for each kind, built once with ELI's look
    var holder := Node3D.new()
    root.add_child(holder)
    var factory = Factory.new()
    factory.build(holder, "eli_room", {}, Settings.new(), {"sky": "void", "ground": "sand"})
    await process_frame
    var own = holder.get_children().filter(func(c): return not c.is_queued_for_deletion())[0]
    var before: Array = own.get_children().map(func(c): return c.get_instance_id())
    own.apply_mood({"sky": "void", "ground": "sand"})
    var once: bool = own.mood["sky"] == "void" and own.mood["light"] == "#9fd8ff" \
        and own.get_children().map(func(c): return c.get_instance_id()) == before
    _check("elis_room_is_built_once_with_the_look_eli_gave_it", once, "mood %s" % own.mood)
    var mine := [
        _book_record("book_diary_1", "diary", "Notes from a quiet day", T0 + 2.0 * DAY, [{"heading": "", "text": "Rain on the roof."}], "own_room", {"shelf": "My diary"}),
        _book_record("book_like_2", "likes", "Tides", T0 + 5.0 * DAY, [{"heading": "", "text": "I like how they keep time."}], "own_room", {"shelf": "What I like"}),
        _book_record("book_goal_1", "goals", "Learning the garden", T0, [{"heading": "", "text": "Know every plant by name."}], "own_room", {"shelf": "What I hope for"}),
        _book_record("book_like_1", "likes", "Old maps", T0 + DAY, [{"heading": "", "text": "I like their margins."}], "own_room", {"shelf": "What I like"}),
    ]
    var kept = Things.new()
    root.add_child(kept)
    kept.pinner = own
    kept.show_room("own_room")
    kept.apply_world_state({"objects": mine})
    await process_frame
    var case: Bookcase = own._case
    var ranked := ["book_like_1", "book_like_2", "book_goal_1", "book_diary_1"].map(func(id): return case.to_room.affine_inverse() * (kept._things[id] as Node3D).position)
    var shelf_order := true
    for i in range(1, ranked.size()):
        var a: Vector3 = ranked[i - 1]
        var b: Vector3 = ranked[i]
        shelf_order = shelf_order and (b.y < a.y - 0.001 or (absf(b.y - a.y) < 0.001 and b.x > a.x))
    var reachable: bool = ranked.all(func(p): return absf(p.x) < case.width * 0.5 and p.y >= Reading.low_shelf() - 0.001 and p.y <= Reading.top_shelf())
    var named := _texts_under(case._plates)
    _check("elis_room_has_a_bookcase_of_its_own_books_a_shelf_for_each_kind", shelf_order and reachable
           and named == ["What I like", "What I hope for", "My diary"], "order %s reach %s plates %s at %s" % [shelf_order, reachable, named, ranked])
    kept.queue_free()
    holder.queue_free()

    # the Evidence Wall: beliefs as case cards (how sure, since when), disputes first with their question, threads between related
    var wall = EvidenceWall.new()
    root.add_child(wall)
    wall.build({}, Settings.new())
    var claims := [
        {"id": "claim_2", "name": "favourite tea: green tea", "kind": "claim", "room": "evidence_wall", "importance": 0.9, "meaning": "",
         "claim": {"relation": "favourite_tea", "value": "green tea", "chance": 0.9, "since": T0, "learned": T0, "basis": "you said so once",
                   "sources": [{"id": "m11", "text": "I grew up in Harbour Town, drinking green tea", "when": T0, "origin": "you said so"}]},
         "form": {"shape": "board", "colour": "#d9e4f2", "pos": [0.0, 1.0, 2.0]}},
        {"id": "claim_3", "name": "works as: a baker", "kind": "claim", "room": "evidence_wall", "importance": 0.4,
         "meaning": "works as: a baker (since 2026-01-04; learned 2026-01-05; sure 0.40: ELI's inference)",
         "form": {"shape": "board", "colour": "#d9e4f2", "pos": [0.0, 1.0, 2.0]}},
        {"id": "claim_1", "name": "home town: Harbour Town", "kind": "claim", "room": "evidence_wall", "importance": 0.72, "meaning": "",
         "claim": {"relation": "home_town", "value": "Harbour Town", "chance": 0.72, "since": T0, "learned": T0 + 3.0 * DAY,
                   "basis": "you said so twice", "contested": true,
                   "sources": [{"id": "m11", "text": "I grew up in Harbour Town, drinking green tea", "when": T0, "origin": "you said so"}]},
         "form": {"shape": "board", "colour": "#f5b942", "pos": [0.0, 1.0, 2.0]}},
    ]
    var conflict := {"id": "conflict_1", "name": "Home town?", "kind": "conflict", "room": "anomaly_room",
                     "meaning": "I have your home town as Harbour Town, but something else says Hill Village. Which is right?",
                     "form": {"shape": "crystal", "colour": "#ff6a4d", "pos": [0.0, 1.0, 2.0]}}
    var evidence := {"actions": {"days": 30, "runs": 20, "rows": [
        {"action": "OPEN_APP", "name": "open app", "n": 12, "ok": 9, "p": 0.74,
         "causes": [{"cause": "not_installed", "words": "the app was not installed", "n": 2}],
         "weeks": [{"from": T0, "n": 5, "ok": 2}, {"from": T0 + 7.0 * DAY, "n": 0, "ok": 0}, {"from": T0 + 14.0 * DAY, "n": 5, "ok": 4}],
         "instead": [{"action": "OPEN_URL", "name": "open url", "n": 3, "p": 0.8}]},
        {"action": "WEB_SEARCH", "name": "web search", "n": 8, "ok": 3, "p": 0.4, "causes": [], "weeks": [], "instead": []}]},
        "accuracy": [{"kind": "answer", "words": "replies to you", "n": 40, "right": 0.82, "ece": 0.07,
                      "weeks": [{"from": T0, "n": 10, "right": 0.7}, {"from": T0 + 7.0 * DAY, "n": 30, "right": 0.86}]},
                     {"kind": "route", "words": "readings of what a sentence asked for", "n": 0, "right": 0.0}]}
    var lessons := [
        _book_record("book_lesson_3", "lesson", "Open app: open the site when the app is missing", T0, [{"heading": "When", "text": "The app is not installed."}], "evidence_wall", {"applies_to": "OPEN_APP"}),
        _book_record("book_lesson_4", "lesson", "Web search: say what came back", T0 + DAY, [{"heading": "When", "text": "A search came back empty."}], "evidence_wall"),
    ]
    var state := {"objects": claims + [conflict] + lessons, "evidence": evidence}
    var eli := {"connected": true, "mind": "", "mode": "idle", "can": ["books", "evidence"], "state": state}
    wall.show_eli(eli)
    var pinned = Things.new()
    root.add_child(pinned)
    pinned.pinner = wall
    pinned.show_room("evidence_wall")
    pinned.apply_world_state(state)
    await process_frame
    var ranked_claims: Array = wall.arrange("claim", claims).map(func(c): return c["id"])
    var card_1 := " ".join(_texts_under(pinned._things["claim_1"]._body)).replace("\n", " ")
    var card_3 := " ".join(_texts_under(pinned._things["claim_3"]._body)).replace("\n", " ")
    var stamp: bool = _labels(pinned._things["claim_1"]._body).any(func(l): return l.name == "Stamp" and l.text == "CONTESTED")
    var unstamped: bool = not _labels(pinned._things["claim_2"]._body).any(func(l): return l.name == "Stamp")
    var fill: MeshInstance3D = pinned._things["claim_1"]._body.find_child("Sureness", false, false)
    var track: MeshInstance3D = pinned._things["claim_1"]._body.find_child("Track", false, false)
    var share: float = (fill.mesh as BoxMesh).size.x / (track.mesh as BoxMesh).size.x
    var as_sheet: bool = pinned._things["claim_1"]._pin_size == wall._slots[wall._claim_slot["claim_1"]]["now"]
    var cards_ok: bool = ranked_claims == ["claim_1", "claim_2", "claim_3"] and "home town: Harbour Town" in card_1 and "chance 72%" in card_1 \
        and ("since %s · learned %s" % [Reading.day(T0), Reading.day(T0 + 3.0 * DAY)]) in card_1 and "you said so twice" in card_1 \
        and "rests on 1 record" in card_1 and stamp and unstamped and absf(share - 0.72) < 0.01 and as_sheet \
        and "works as: a baker" in card_3 and "chance 40%" in card_3 and "since 2026-01-04" in card_3
    _check("a_belief_is_a_case_card_saying_how_sure_eli_is_and_since_when", cards_ok,
           "order %s card %s / %s stamp %s share %.2f" % [ranked_claims, card_1, card_3, stamp, share])
    # nothing on the wall but ELI's records: no sheets pinned up for show
    var shown_for_show := _meshes(wall).filter(func(m): return _shaded_with(m, "document.gdshader"))
    _check("the_evidence_wall_pins_up_nothing_that_is_not_elis", shown_for_show.is_empty(), "%d made-up sheets" % shown_for_show.size())
    # the question is the next record after the belief it is about (each goes to the nearest sheet that takes it whole)
    var question_at: int = wall._placed.keys().filter(func(i): return wall._placed[i].get("id") == "conflict_1")[0]
    var question := " ".join(_texts_under(wall._sheets.get_node("Sheet_%d" % question_at))).replace("\n", " ")
    var asked_after: bool = wall._evidence(state, claims).map(func(e): return e["id"]).slice(0, 2) == ["claim_1", "conflict_1"]
    # threads: home town to its question, the two beliefs and the exhibit resting on one record, open app to its lesson
    _check("disputes_come_first_with_their_question_and_thread_runs_between_related_cards",
           wall._threads.mesh != null and wall.threads_drawn() == 4 and "Hill Village" in question and "DISPUTED" in question and asked_after,
           "threads %d question %s next %s" % [wall.threads_drawn(), question, asked_after])
    # the owner's wall: seven boards of thirteen sheets, each with a record while there are records, the rest blank
    var wall_boards: Array = wall.get_children().filter(func(c): return c.name.begins_with("Wall_"))
    var on_sheets: Array = wall._sheets.get_children().filter(func(c): return not c.is_queued_for_deletion())
    var blank_say_nothing: bool = on_sheets.size() == 10 - 3 and on_sheets.all(func(c): return wall._placed.has(int(str(c.name).get_slice("_", 1))))
    _check("the_evidence_wall_is_a_full_wall_of_pinned_sheets", wall_boards.size() == 7 and wall.sheet_count() == 91
           and wall._papers.multimesh.instance_count == 91 and wall.records_on_wall() == 10 and blank_say_nothing
           and wall._on_file.text == "10 records on file",
           "boards %d sheets %d filled %d written %d says %s" % [wall_boards.size(), wall.sheet_count(), wall.records_on_wall(), on_sheets.size(), wall._on_file.text])
    var allowed := _allowed_words(state)
    var said_on_wall: Array = _texts_under(wall._sheets) + [wall._on_file.text]
    for id in ["claim_1", "claim_2", "claim_3"]:
        said_on_wall.append_array(_texts_under(pinned._things[id]._body))
    var invented: Array = _invented(said_on_wall, allowed)
    var checker_catches: bool = _invented(["lorem ipsum 72%"], allowed) == ["lorem", "ipsum"]
    _check("no_sheet_on_the_wall_says_anything_elis_records_do_not", invented.is_empty() and checker_catches and said_on_wall.size() > 20,
           "invented %s (checker catches %s)" % [invented, checker_catches])
    var exhibit := " ".join(_texts_under(wall._exhibits)).replace("\n", " ")
    _check("the_exhibits_are_the_records_elis_beliefs_rest_on", exhibit.begins_with("EXHIBIT 1") and "Harbour Town, drinking" in exhibit
           and "supports: home town: Harbour Town; favourite tea: green tea" in exhibit and not "EXHIBIT 2" in exhibit, exhibit)
    var scored := EvidenceWall.score_lines(evidence, 60)
    var board := _texts(wall._score).filter(func(t): return t != "")
    var detail := " ".join(scored.filter(func(l): return l[1] == EliReadout.PALE).map(func(l): return str(l[0]).strip_edges()))
    var searched := scored.filter(func(l): return str(l[0]).begins_with("web search"))
    var scores_ok: bool = str(scored[0][0]).begins_with("open app") and " 75% 9 of 12" in str(scored[0][0]) and "▄·▇" in str(scored[0][0]) \
        and "↑ 40%→80%" in str(scored[0][0]) and scored[0][1] == EliReadout.GOOD \
        and detail == "failed: the app was not installed (2); open url worked instead 3×" and scored.all(func(l): return str(l[0]).length() <= 60) \
        and searched.size() == 1 and " 38% 3 of 8" in str(searched[0][0]) and searched[0][1] == EliReadout.TROUBLE and str(board[0]).begins_with("open app")
    _check("the_scoreboard_says_how_often_each_action_worked_how_that_changed_and_what_worked_instead", scores_ok, "%s / %s" % [scored, board])
    var chart := " ".join(_texts_under(wall._chart)).replace("\n", " ")
    var bars: MultiMeshInstance3D = wall._chart.find_child("RowBars", false, false)
    _check("the_charts_show_how_often_elis_figures_proved_right_week_by_week", "replies to you" in chart and "82% of 40 · off by 0.07" in chart
           and not "readings of what" in chart and bars != null and bars.multimesh.instance_count == 4, "%s bars %s" % [chart, bars])
    var files := ["book_lesson_3", "book_lesson_4"].map(func(id): return pinned._things[id])
    var on_desk: bool = files.all(func(f): return f.pinned and f.position.y > wall._desk_top and (f as Node3D).basis.z.dot(Vector3.UP) > 0.99) \
        and files[1].position.y > files[0].position.y and not (wall._empty[wall._desk] as Label3D).visible
    _check("the_case_files_of_what_eli_learned_lie_on_the_desk", on_desk, str(files.map(func(f): return f.position)))
    var told_board := []
    for why in [{"connected": false}, {"connected": true, "can": ["world-state"], "state": {"objects": []}},
                {"connected": true, "can": ["evidence"], "state": {"objects": [], "evidence": {}}}]:
        wall.show_eli(why)
        told_board.append(_texts(wall._score)[0])
    _check("a_bare_board_says_why_from_the_data", told_board == ["ELI is not connected", "this ELI does not send that yet", "nothing on record yet"],
           str(told_board))

    # a record let go goes back to its place and is not moved in ELI's world; one that loses its place lets go of it
    var sent := [0]
    pinned.moved_by_hand.connect(func(_id, _at): sent[0] += 1)
    var sheet = pinned._things["claim_2"]
    sheet.begin_grab()
    sheet.position += Vector3(1.0, 0.0, 0.0)
    sheet.end_grab()
    _check("a_record_let_go_goes_back_to_its_place_and_is_not_moved_in_elis_world", sent[0] == 0 and sheet._target.is_equal_approx(sheet._pin.origin),
           "sent %d target %s pin %s" % [sent[0], sheet._target, sheet._pin.origin])
    pinned.queue_free()
    var loose = Things.new()
    root.add_child(loose)
    var pinner := Pinner.new()
    root.add_child(pinner)
    loose.pinner = pinner
    loose.show_room("evidence_wall")
    loose.apply_world_state({"objects": [claims[1]]})
    var was: bool = loose._things["claim_3"].pinned
    pinner.allow = false
    loose.apply_world_state({"objects": [claims[1]]})
    _check("a_record_that_loses_its_place_lets_go_of_it", was and not loose._things["claim_3"].pinned, "pinned before %s" % was)
    var grabber = Manipulator.new()
    root.add_child(grabber)
    grabber.setup(null, null, null, null, null, null)
    _check("a_hand_holding_a_book_is_known_to_the_book_for_the_other_hand", grabber.is_in_group("world_manipulators"), "")
    for node in [loose, pinner, grabber, wall]:
        node.queue_free()
    await _book_read_whole_check()
    await _whole_and_once_checks()
    await _example_feed_checks()

# A book too long for the world message comes with its length and no sections: opened, it is read
# whole from ELI v3 by its id and laid out; one ELI v3 cannot give stays blank and is asked again.
func _book_read_whole_check() -> void:
    var served := BookLink.new()
    root.add_child(served)
    served.books["book_conversation_long"] = [{"heading": "You, 10:02", "when": T0, "text": "Where did the ferry timetable go?"},
                                              {"heading": "ELI, 10:03", "when": T0, "text": "Pinned to the board by the door."}]
    var was = EliBook.link
    EliBook.link = served
    var long = Book.new()
    root.add_child(long)
    var record := _book_record("book_conversation_long", "conversation", "The ferry timetable", T0, [])
    record["book"].erase("sections")
    record["book"]["length"] = 4000
    long.build(record)
    # as long as it says: a long book sent without its pages is as thick as its length makes it
    var thick: bool = EliBook.measure({"book": {"length": 2_000_000}}).z > EliBook.measure({"book": {"length": 0}}).z
    long.begin_grab()
    for n in 5:
        await process_frame
    var read := " ".join(long._pages.map(func(p): return " ".join(p["lines"])))
    var whole: bool = served.asked == ["/v1/world/book/book_conversation_long"] and "Where did the ferry timetable go?" in read \
        and "Pinned to the board by the door." in read and long.page_count() >= 1
    long.end_grab()
    var missing = Book.new()
    root.add_child(missing)
    var none := _book_record("book_log_gone", "log", "A log", T0, [])
    none["book"].erase("sections")
    none["book"]["length"] = 300
    missing.build(none)
    missing.begin_grab()
    for n in 5:
        await process_frame
    var blank: bool = missing.page_count() == 0 and missing._text[4].text == ""
    missing.end_grab()
    missing.begin_grab()                 # asked again at the next opening
    for n in 5:
        await process_frame
    var again: bool = served.asked.count("/v1/world/book/book_log_gone") == 2
    _check("a_book_sent_without_its_pages_is_read_whole_by_its_id_when_opened", thick and whole and blank and again,
           "thick %s whole %s (%s) blank %s again %s asked %s" % [thick, whole, read.substr(0, 80), blank, again, served.asked])
    EliBook.link = was
    for node in [long, missing, served]:
        node.queue_free()

# The wall's sheets take their records whole, and a record is pinned up once. Invented records, shaped
# like a real wall's: long beliefs, a lesson with a long change, the same thought in turn after turn.
func _whole_and_once_checks() -> void:
    var long_fact := "Prefers every reply to begin with the conclusion and to leave the reasoning for afterwards, with the commands written out one to a line so each can be run as it stands and checked before the next."
    var long_change := "before opening an app by its name, look the name up among the installed apps and open the site when it is not there"
    var belief := func(id: String, relation: String, value: String, chance: float, also: Array = []) -> Dictionary:
        return {"id": id, "name": (relation + ": " + value).substr(0, 48), "kind": "claim", "room": "evidence_wall", "importance": chance, "meaning": "",
                "claim": {"relation": relation, "value": value, "chance": chance, "since": T0, "learned": T0, "basis": "you mentioned it once",
                          "contested": false, "status": "current", "sources": [], "also": also},
                "form": {"shape": "board", "colour": "#d9e4f2", "pos": [0.0, 1.0, 2.0]}}
    var claims := [belief.call("claim_1", "preference.session", long_fact, 0.7),
                   belief.call("claim_2", "identity.fact", "Keeps bees and grows pears on the south wall.", 0.6,
                               [{"id": "claim_3", "relation": "identity.fact", "value": "Keeps bees.", "learned": T0}]),
                   # one ELI folded into claim_2 and one that reads the same as claim_2, both still arriving
                   belief.call("claim_3", "identity.fact", "Keeps bees.", 0.5),
                   belief.call("claim_4", "identity.fact", "keeps bees and grows pears on the south wall", 0.4)]
    var lesson := _book_record("book_lesson_7", "lesson", "open app: before opening an app by its name, look the…", T0,
                               [{"heading": "When", "text": "OPEN_APP failed with: the app is not installed."},
                                {"heading": "Why", "text": "A fault that shows up whatever the app, so what the action needs is not there."}],
                               "evidence_wall", {"applies_to": "OPEN_APP", "spine": "open app", "change": long_change})
    var rows := [{"id": "action_OPEN_APP", "action": "OPEN_APP", "name": "open app", "n": 12, "ok": 3, "p": 0.3,
                  "causes": [{"cause": "dependency", "words": "something it needs was not there", "n": 9}], "last": T0, "weeks": [], "instead": []}]
    var thoughts := []
    for i in 4:
        thoughts.append({"id": 40 + i, "kind": "route", "room": "core_room", "what": "read as chat", "why": [], "chance": 0.9, "decision": "taken",
                         "reason": "", "status": "open", "outcome": "", "when": T0 + float(i), "words": "", "subject": "sentence %d" % i, "ref": "route:r%d" % i})
    var evidence := {"actions": {"days": 30, "runs": 12, "rows": rows}, "accuracy": []}
    var state := {"objects": claims + [lesson], "evidence": evidence, "thoughts": thoughts}
    var eli := {"connected": true, "mind": "", "mode": "idle", "can": ["books", "evidence"], "state": state}
    var wall = EvidenceWall.new()
    root.add_child(wall)
    wall.build({}, Settings.new())
    wall.show_eli(eli)
    var pinned = Things.new()
    root.add_child(pinned)
    pinned.pinner = wall
    pinned.show_room("evidence_wall")
    pinned.apply_world_state(state)
    await process_frame
    # (1) every word of every record that is up is on its sheet, and no line was cut short
    var one := func(text: String) -> String: return " ".join(text.replace("\n", " ").split(" ", false))
    var said := {}
    for i in wall._placed:
        var entry: Dictionary = wall._placed[i]
        var node: Node = pinned._things[entry["id"]]._body if entry.has("belief") else wall._sheets.get_node("Sheet_%d" % i)
        said[entry["id"]] = one.call(" ".join(_texts_under(node)))
    var whole: bool = one.call("preference.session: " + long_fact) in said.get("claim_1", "") \
        and one.call("open app: " + long_change) in said.get("book_lesson_7", "") \
        and "OPEN_APP failed with: the app is not installed." in said.get("book_lesson_7", "") \
        and "what the action needs is not there." in said.get("book_lesson_7", "") \
        and "failed: something it needs was not there" in said.get("action_OPEN_APP", "")
    var cut: Array = said.values().filter(func(t): return "…" in t)
    # (2) at the size it is read at where it hangs, on a sheet inside its own share of the board
    var sized := true
    var grown := 0
    for i in wall._placed:
        var slot: Dictionary = wall._slots[i]
        var now: Vector2 = slot["now"]
        var view: Dictionary = wall._placed[i]["view"] if wall._placed[i].has("view") else EvidenceSheet.of_claim(wall._placed[i]["belief"])
        var c := cos(absf(float(slot["tilt"])))
        var sn := sin(absf(float(slot["tilt"])))
        sized = sized and EvidenceSheet.fits(view, now, float(slot["distance"])) and now.x >= slot["size"].x - 0.0001 and now.y >= slot["size"].y - 0.0001 \
            and now.x * c + now.y * sn <= slot["cell"].x + 0.001 and now.x * sn + now.y * c <= slot["cell"].y + 0.001
        grown += 1 if now != slot["size"] else 0
    var read_size := true
    for label in _labels(wall._sheets):
        var sheet_at := int(str(label.get_parent().name).get_slice("_", 1))
        if label.name in ["Heading", "Details"]:
            var scale := 1.1 if label.name == "Heading" else 1.0
            read_size = read_size and absf(label.pixel_size - Reading.pixel(float(wall._slots[sheet_at]["distance"])) * scale) < 0.000001
    _check("a_sheet_takes_its_record_whole_at_the_size_it_is_read_at", whole and cut.is_empty() and sized and grown > 0 and read_size,
           "whole %s cut %s sized %s grown %d read size %s said %s" % [whole, cut, sized, grown, read_size, said])
    # (3) a record is up once: one folded into another by ELI, one that reads the same, a thought had turn after turn
    var up: Array = wall._placed.values().map(func(e): return e["id"])
    var once: bool = up.has("claim_2") and not up.has("claim_3") and not up.has("claim_4") \
        and up.filter(func(id): return str(id).begins_with("thought_")).size() == 1 \
        and not pinned._things["claim_3"].pinned and not pinned._things["claim_4"].pinned and pinned._things["claim_2"].pinned \
        and wall._on_file.text == "%d records on file" % up.size() and up.size() == 5
    _check("a_record_that_arrives_twice_is_pinned_up_once", once, "up %s says %s" % [up, wall._on_file.text])
    # (4) ELI's order is the wall's, nearest sheets first, and what ELI left off the wall stays off it
    state["evidence"]["wall"] = [{"ref": "book_lesson_7", "kind": "lesson", "also": []}, {"ref": "claim_2", "kind": "claim", "also": ["claim_3", "thought_40"]},
                                 {"ref": "action_OPEN_APP", "kind": "action", "also": []}, {"ref": "book_lesson_7", "kind": "lesson", "also": []},
                                 {"ref": "book_lesson_gone", "kind": "lesson", "also": []}, {"ref": "claim_3", "kind": "claim", "also": []}]
    wall.show_eli(eli)
    pinned.apply_world_state(state)
    await process_frame
    var order: Array = wall._evidence(state, claims).map(func(e): return e["id"])
    var places: Array = wall._placed.keys()
    places.sort()
    var by_place: Array = places.map(func(i): return wall._placed[i]["id"])
    var threaded: bool = wall.threads_drawn() == 1          # the lesson to the action it is about
    _check("the_wall_hangs_what_eli_says_goes_up_in_elis_order", order == ["book_lesson_7", "claim_2", "action_OPEN_APP"] and by_place.size() == 3
           and by_place.has("book_lesson_7") and wall.records_on_wall() == 3 and not pinned._things["claim_1"].pinned and threaded,
           "order %s places %s threads %d" % [order, by_place, wall.threads_drawn()])
    pinned.queue_free()
    wall.queue_free()

# ELI v3's own example of a world message (tests/fixtures, copied from ELI v3): the rooms built from it,
# headless, show what it holds.
func _example_feed_checks() -> void:
    var state = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/world_feed_v2_example.json"))
    if typeof(state) != TYPE_DICTIONARY:
        _check("the_rooms_show_elis_example_world_message", false, "the example did not load")
        return
    var eli := {"connected": true, "mind": "", "mode": "idle", "can": ["books", "evidence"], "state": state}
    var objects: Array = state["objects"]
    var by_room := func(room: String, kind: String) -> Array:
        return objects.filter(func(o): return o.get("room") == room and o.get("kind") == kind)
    # the Evidence Wall: the wall of sheets fills with every record there is, the rest blank; scoreboard and charts drawn
    var wall = EvidenceWall.new()
    root.add_child(wall)
    wall.build({}, Settings.new())
    wall.show_eli(eli)
    var on_wall = Things.new()
    root.add_child(on_wall)
    on_wall.pinner = wall
    on_wall.show_room("evidence_wall")
    on_wall.apply_world_state(state)
    await process_frame
    # every record ELI's example says goes up (its evidence "wall"), each of a kind the wall knows, in ELI's order
    var sent: Array = state["evidence"]["wall"]
    var records: int = sent.size()
    var hung: Array = wall._placed.keys()
    hung.sort()
    var as_sent: bool = hung.map(func(i): return wall._placed[i]["id"]) == sent.map(func(e): return e["ref"]) \
        and sent.map(func(e): return e["kind"]).has("claim") and sent.map(func(e): return e["kind"]).has("action")
    var said: Array = _texts_under(wall._sheets) + [wall._on_file.text]
    for claim in by_room.call("evidence_wall", "claim"):
        said.append_array(_texts_under(on_wall._things[claim["id"]]._body))
    var invented: Array = _invented(said, _allowed_words(state))
    var board := _texts(wall._score).filter(func(t): return t != "")
    var bars: MultiMeshInstance3D = wall._chart.find_child("RowBars", false, false)
    var lesson_on_desk := true
    for b in by_room.call("evidence_wall", "book"):
        lesson_on_desk = lesson_on_desk and on_wall._things[b["id"]].pinned and on_wall._things[b["id"]].position.y > wall._desk_top
    _check("the_evidence_wall_shows_elis_example_world_message", wall.sheet_count() == 91 and wall.records_on_wall() == records and as_sent
           and wall._on_file.text == "%d records on file" % records and invented.is_empty() and str(board[0]).begins_with("open app")
           and bars != null and bars.multimesh.instance_count > 2 and "replies to you" in " ".join(_texts_under(wall._chart))
           and lesson_on_desk and wall.threads_drawn() >= 3,
           "sheets %d records %d of %d says %s invented %s board %s bars %s desk %s threads %d" % [wall.sheet_count(), wall.records_on_wall(),
           records, wall._on_file.text, invented, board.slice(0, 1), bars.multimesh.instance_count if bars else -1, lesson_on_desk, wall.threads_drawn()])
    on_wall.queue_free()
    wall.queue_free()
    # the Memory Archive: every book shelved, the stories on their own shelves, by time
    var archive = Archive.new()
    root.add_child(archive)
    archive.build({}, Settings.new())
    archive.show_eli(eli)
    var shelved = Things.new()
    root.add_child(shelved)
    shelved.pinner = archive
    shelved.show_room("memory_archive")
    shelved.apply_world_state(state)
    await process_frame
    var books: Array = by_room.call("memory_archive", "book")
    var all_shelved: bool = not books.is_empty() and books.all(func(b): return shelved._things[b["id"]].pinned)
    var stories_apart := true
    var story_case: Bookcase = archive._story_cases[0]
    for b in books.filter(func(b): return b["book"]["of"] == "story"):
        var at: Vector3 = story_case.to_room.affine_inverse() * (shelved._things[b["id"]] as Node3D).position
        stories_apart = stories_apart and absf(at.y - float(story_case.tops[0])) < 0.001
    var memories: bool = by_room.call("memory_archive", "memory").all(func(m): return shelved._things[m["id"]].pinned and shelved._things[m["id"]] is EliBook)
    var bare: Label3D = (archive._record_cases[0] as Bookcase)._empty
    _check("the_archive_shelves_elis_example_books", all_shelved and stories_apart and memories and (bare == null or not bare.visible),
           "shelved %s stories %s memories %s bare %s" % [all_shelved, stories_apart, memories, bare.text if bare else ""])
    shelved.queue_free()
    archive.queue_free()
    # ELI's own room: its books on its bookcase, shelf by shelf in its order
    var own = OwnRoomClass.new()
    root.add_child(own)
    own.build({}, Settings.new())
    own.show_eli(eli)
    var kept = Things.new()
    root.add_child(kept)
    kept.pinner = own
    kept.show_room("own_room")
    kept.apply_world_state(state)
    await process_frame
    var mine: Array = by_room.call("own_room", "book")
    var ranked: Array = own.arrange("book", mine).map(func(b): return own.SHELF_ORDER.find(b["book"]["of"]))
    var in_order := true
    for i in range(1, ranked.size()):
        in_order = in_order and int(ranked[i]) >= int(ranked[i - 1])
    _check("elis_room_shelves_its_example_books", not mine.is_empty() and mine.all(func(b): return kept._things[b["id"]].pinned) and in_order,
           "books %d order %s" % [mine.size(), ranked])
    kept.queue_free()
    own.queue_free()

func _shaded_with(mesh: MeshInstance3D, shader_file: String) -> bool:
    var look := mesh.material_override as ShaderMaterial
    return look != null and look.shader != null and look.shader.resource_path.get_file() == shader_file

func _meshes(node: Node) -> Array:
    var out := []
    for child in node.get_children():
        if child is MeshInstance3D:
            out.append(child)
        out.append_array(_meshes(child))
    return out

# Every word ELI's world sent (any string anywhere in it), with the words a sheet adds of its own and
# the months a date is written with.
func _allowed_words(state) -> Dictionary:
    var out := {}
    for word in EvidenceSheet.CHROME + Array(Reading.MONTHS):
        out[str(word).to_lower()] = true
    _words_into(state, out)
    return out

func _words_into(value, out: Dictionary) -> void:
    match typeof(value):
        TYPE_STRING, TYPE_STRING_NAME:
            for token in _tokens(str(value)):
                out[token] = true
        TYPE_DICTIONARY:
            for key in value:
                _words_into(key, out)
                _words_into(value[key], out)
        TYPE_ARRAY:
            for item in value:
                _words_into(item, out)

func _tokens(text: String) -> Array:
    var out := []
    for raw in text.replace("_", " ").replace("·", " ").replace("→", " ").replace("\n", " ").split(" ", false):
        var word := raw.to_lower()
        for mark in [".", ",", ":", ";", "(", ")", "?", "!", "…", "\"", "'s", "%", "×", "↑", "↓", "=", "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]:
            word = word.replace(mark, "")
        if not word.is_empty() and not word.is_valid_float():
            out.append(word)
    return out

# The words in `texts` that are in none of `allowed`. A word cut short with "…" where a line ran out
# counts when an allowed word begins with it.
func _invented(texts: Array, allowed: Dictionary) -> Array:
    var out := []
    for text in texts:
        for raw in str(text).replace("\n", " ").split(" ", false):
            for token in _tokens(raw):
                if allowed.has(token):
                    continue
                if raw.ends_with("…") and allowed.keys().any(func(w): return str(w).begins_with(token)):
                    continue
                out.append(token)
    return out

# Whether a label's writing, measured in its own font, starts and ends inside a face `width` wide.
func _within(words: Label3D, width: float) -> bool:
    var widest := 0.0
    for line in words.text.split("\n"):
        widest = maxf(widest, Reading.measurer(words.font).call(line) * words.pixel_size)
    return words.position.x >= -width * 0.5 and words.position.x + widest <= width * 0.5 + 0.0001

func _labels(node: Node) -> Array:
    var out := []
    for child in node.get_children():
        if child is Label3D and (child as Label3D).visible:
            out.append(child)
        out.append_array(_labels(child))
    return out

# Every shader material under `node` (and the sky's) compiled: a shader that fails to compile
# reports no uniforms.
func _shaders_compile(node: Node, failed: Array) -> void:
    var materials := []
    if node is GeometryInstance3D and (node as GeometryInstance3D).material_override != null:
        materials.append((node as GeometryInstance3D).material_override)
    if node is GPUParticles3D:
        materials.append((node as GPUParticles3D).process_material)
    if node is WorldEnvironment and (node as WorldEnvironment).environment.sky != null:
        materials.append((node as WorldEnvironment).environment.sky.sky_material)
    for m in materials:
        while m is ShaderMaterial:
            var shader: Shader = (m as ShaderMaterial).shader
            if shader != null and shader.get_shader_uniform_list().is_empty():
                failed.append(shader.resource_path)
            m = (m as ShaderMaterial).next_pass
    for child in node.get_children():
        _shaders_compile(child, failed)

func _built(script) -> Node:
    var room = script.new()
    root.add_child(room)
    room.build({}, Settings.new())
    return room

func _flock_of(room: Node):
    for child in room.get_children():
        if child.has_method("positions"):
            return child
    return null

func _has_mesh(node: Node, kind: String) -> bool:
    if node is MeshInstance3D and (node as MeshInstance3D).mesh != null and (node as MeshInstance3D).mesh.is_class(kind):
        return true
    for child in node.get_children():
        if _has_mesh(child, kind):
            return true
    return false

# The ocean's gulls, the desert's dunes and night, the anomaly's black hole: what the rooms are
# made of, measured, not looked at.
func _room_checks() -> void:
    var failed := []
    # --- the ocean: gulls that flock, bank into their turns, beat and glide, over the sea
    var ocean = _built(Ocean)
    _shaders_compile(ocean, failed)
    var gulls = _flock_of(ocean)
    var is_bird := false
    var flies: bool = gulls != null
    var banks := 0
    var turns := 0
    var flapped := false
    var glided := false
    if gulls != null:
        var arrays: Array = gulls.multimesh.mesh.surface_get_arrays(0)
        var spans: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
        var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
        var widest := 0.0
        for uv in spans:
            widest = maxf(widest, absf(uv.x))
        var dark: bool = colours.size() > 0 and Array(colours).any(func(c): return c.get_luminance() < 0.1)
        is_bird = widest > 0.99 and dark and gulls.multimesh.use_custom_data and not _has_mesh(ocean, "PrismMesh")
        var band: Vector2 = gulls.kind["band"]
        var dt := 1.0 / 30.0
        var before: PackedVector3Array = gulls.velocities().duplicate()
        for frame in 900:
            gulls.step(dt)
            var now: PackedVector3Array = gulls.velocities()
            for i in now.size():
                var p: Vector3 = gulls.positions()[i]
                var speed := now[i].length()
                if frame > 150:
                    var height: float = p.y - gulls.floor_y
                    var out := Vector2(p.x - gulls.home.x, p.z - gulls.home.z).length()
                    flies = flies and height > band.x - 2.0 and height < band.y + 4.0 and out > gulls.keep_out - 3.0 \
                        and out < gulls.roam + 15.0 and speed >= gulls.kind["slowest"] - 0.01 and speed <= gulls.kind["fastest"] + 0.01
                    # a bird turning hard leans into the turn: its back tips towards the side it turns to
                    var forward := now[i].normalized()
                    var turning := (now[i] - before[i]) / dt
                    turning -= forward * turning.dot(forward)
                    turning.y = 0.0
                    if turning.length() > 2.0:
                        turns += 1
                        if gulls.pose(i).basis.y.dot(turning.normalized()) > 0.0:
                            banks += 1
                flapped = flapped or gulls._flap[i] > 0.99
                glided = glided or gulls._flap[i] < 0.01
            before = now.duplicate()
    _check("the_ocean_gulls_are_birds_that_flock_bank_and_keep_their_height",
           is_bird and flies and turns > 50 and banks > turns * 0.85 and flapped and glided,
           "bird %s flies %s banks %d of %d turns, flapped %s glided %s" % [is_bird, flies, banks, turns, flapped, glided])

    # --- the ocean's sea carries the swell it floats things on
    ocean._clock = 7.3
    ocean._animate(0.0)
    var afloat: bool = not ocean._floating.is_empty()
    for entry in ocean._floating:
        var node: Node3D = entry[0]
        afloat = afloat and absf(node.position.y - (ocean.sea_height(node.position.x, node.position.z) + float(entry[1]))) < 0.0001
    var sea: ShaderMaterial = ocean._sea
    var waves = sea.get_shader_parameter("waves")
    var moves: bool = waves != null and waves.size() == ocean.SWELL.size() and absf(sea.get_shader_parameter("clock") - 7.3) < 0.001 \
        and absf(ocean.sea_height(3.0, 4.0) - ocean.SEA_Y) > 0.0
    _check("the_ocean_floats_its_buoys_and_boat_on_the_swell_it_draws", afloat and moves, "afloat %s moves %s" % [afloat, moves])
    ocean.queue_free()

    # --- the mountain's birds are a flock of their own kind
    var mountain = _built(Mountain)
    _shaders_compile(mountain, failed)
    var raptors = _flock_of(mountain)
    var soars: bool = raptors != null and raptors.kind == raptors.KINDS["raptor"] and not _has_mesh(mountain, "PrismMesh")
    mountain.queue_free()

    # --- the lab under the sea: schools of fish, swimming over the seabed as it rises and falls
    var lab = _built(Underwater)
    _shaders_compile(lab, failed)
    var schools := []
    var spheres := false
    for child in lab.get_children():
        if child.has_method("positions"):
            schools.append(child)
        for grand in [child] + child.get_children():
            if grand is MultiMeshInstance3D and (grand as MultiMeshInstance3D).multimesh.mesh is SphereMesh:
                spheres = true
    var swims: bool = schools.size() >= 2 and not spheres and schools.all(func(f): return f.kind.get("swims", false))
    var over_bed := true
    for f in schools:
        var band: Vector2 = f.kind["band"]
        for frame in 600:
            f.step(1.0 / 30.0)
            if frame > 150:
                for p in f.positions():
                    var above: float = p.y - lab._land.y_at(p.x, p.z)
                    over_bed = over_bed and above > band.x * 0.5 and above < band.y + 3.0
    _check("the_underwater_fish_school_over_the_seabed", swims and over_bed,
           "schools %d spheres %s over the bed %s" % [schools.size(), spheres, over_bed])
    lab.queue_free()

    # --- the anomaly: light bent as general relativity bends it, the shadow where rays fall in
    var far := 4000.0
    var b := 25.0
    var angle := asin(sqrt(1.0 / (far * far * (1.0 / (b * b) + 2.0 / (far * far * far)))))
    var series := 4.0 / b + 15.0 * PI / (4.0 * b * b) + 128.0 / (3.0 * b * b * b)
    var bent := BlackHole.trace(far, angle)
    var edge := BlackHole.shadow_angle(40.0)
    var shadow: bool = BlackHole.trace(40.0, edge * 0.995) < 0.0 and BlackHole.trace(40.0, edge * 1.005) > 0.0 \
        and absf(BlackHole.impact(40.0, edge) - BlackHole.CRITICAL) < 1e-6
    var table: ImageTexture = BlackHole.table(40.0, 34.0)
    var image := table.get_image()
    var rows_ok: bool = image.get_format() == Image.FORMAT_RGH and image.get_width() == BlackHole.COLUMNS \
        and image.get_height() == BlackHole.ROWS and is_equal_approx(image.get_pixel(BlackHole.COLUMNS - 1, 0).r, BlackHole.HORIZON_U) \
        and image.get_pixel(BlackHole.COLUMNS - 1, BlackHole.ROWS - 1).r == 0.0 and BlackHole.table(40.0, 34.0) == table
    var anomaly = Anomaly.new()
    root.add_child(anomaly)
    anomaly.build({}, Settings.new())
    _shaders_compile(anomaly, failed)
    var lens: ShaderMaterial = anomaly._lens.material_override
    var sky: ShaderMaterial = null
    for child in anomaly.get_children():
        if child is WorldEnvironment:
            sky = (child as WorldEnvironment).environment.sky.sky_material
    var same_stars: bool = sky != null and lens.get_shader_parameter("stars") == sky.get_shader_parameter("stars") \
        and lens.get_shader_parameter("orient") == sky.get_shader_parameter("orient") \
        and lens.get_shader_parameter("star_energy") == sky.get_shader_parameter("energy") \
        and lens.get_shader_parameter("lens") == table and not _has_mesh(anomaly, "TorusMesh")
    _check("light_bends_round_the_black_hole_as_general_relativity_bends_it",
           absf(bent - series) / series < 0.01 and shadow and rows_ok and same_stars,
           "bent %.4f series %.4f shadow %s table %s same stars %s" % [bent, series, shadow, rows_ok, same_stars])
    anomaly.queue_free()

    # --- the desert: dunes with slip faces at the angle of repose, under a night sky with no moon
    var desert = _built(Desert)
    _shaders_compile(desert, failed)
    var land: LandKit = desert._land
    var wind := Vector2(land.dunes.x, land.dunes.y).normalized()
    var lee := 0.0
    var windward := 0.0
    var step_m := 0.5
    for line in 6:
        var start := Vector2(-wind.y, wind.x) * (40.0 + 30.0 * line) - wind * 250.0
        for k in 900:
            var a := start + wind * step_m * k
            var c := a + wind * step_m
            var slope := (land.y_at(c.x, c.y) - land.y_at(a.x, a.y)) / step_m
            if a.length() > land.flat + land.rise and c.length() < land.size * 0.5 - land.fade:
                lee = maxf(lee, -slope)
                windward = maxf(windward, slope)
    var dunes_ok: bool = absf(lee - MeshKit.REPOSE) < 0.2 * MeshKit.REPOSE and windward < lee * 0.6
    var night: ShaderMaterial = desert._sky
    var mesas := 0
    var sand := 0
    var moonlight: DirectionalLight3D = null
    for child in desert.get_children():
        if child is MeshInstance3D and Vector2(child.position.x, child.position.z).length() > land.size * 0.7:
            mesas += 1
        if child is GPUParticles3D and (child as GPUParticles3D).lifetime < 1.0:
            sand += 1
        if child is DirectionalLight3D and child.name == "Moonlight":
            moonlight = child
    var ground: ShaderMaterial = land.ground.material_override
    var night_ok: bool = night.get_shader_parameter("air") > 0.0 and night.get_shader_parameter("twilight") > 0.0 \
        and (night.get_shader_parameter("sun_dir") as Vector3).y < 0.0 \
        and ground.get_shader_parameter("mirage") == night.get_shader_parameter("twilight") \
        and ground.get_shader_parameter("mirage_sun") == night.get_shader_parameter("sun_dir") \
        and ground.get_shader_parameter("rayleigh") == night.get_shader_parameter("rayleigh")
    # the moon is in the sky where its age puts it from the sun, lit as its phase says, and the light
    # it casts comes from it, as strong and as coloured as that phase and its height make it
    var moon: Dictionary = desert.moon()
    var sun_way: Vector3 = (night.get_shader_parameter("sun_dir") as Vector3).normalized()
    var apart := rad_to_deg(sun_way.angle_to(moon["dir"]))
    var full := pow(10.0, -0.4 * (0.026 * 0.0))
    var half_lit_share := pow(10.0, -0.4 * (0.026 * 90.0 + 4e-9 * pow(90.0, 4.0)))
    var moon_ok: bool = moonlight != null and (moon["dir"] as Vector3).y > 0.0 \
        and absf(apart - 360.0 * desert.MOON_AGE / desert.SYNODIC_MONTH) < 0.01 \
        and absf(float(moon["lit"]) - (1.0 + cos(deg_to_rad(180.0 - apart))) * 0.5) < 0.001 \
        and moonlight.basis.z.dot(moon["dir"]) > 0.9999 and moonlight.shadow_enabled \
        and absf(moonlight.light_energy - float(moon["energy"])) < 0.0001 and moonlight.light_color.is_equal_approx(moon["colour"]) \
        and float(moon["share"]) < full and float(moon["share"]) > half_lit_share \
        and moonlight.light_color.b < moonlight.light_color.r \
        and (night.get_shader_parameter("moon_dir") as Vector3).is_equal_approx(moon["dir"]) \
        and (night.get_shader_parameter("moon") as Vector3).length() > 0.0
    var wind_ok: bool = ground.get_shader_parameter("ripples") > 0.0 and ground.get_shader_parameter("drift") > 0.0 \
        and ground.get_shader_parameter("haze") > 0.0 and sand >= 1
    _check("the_desert_is_wind_built_dunes_with_mesas_beyond_under_a_night_sky",
           dunes_ok and night_ok and wind_ok and mesas >= 6,
           "lee %.3f windward %.3f night %s wind %s mesas %d" % [lee, windward, night_ok, wind_ok, mesas])
    _check("the_desert_moon_is_in_the_sky_at_its_phase_and_casts_the_light_its_phase_and_height_give",
           moon_ok, "moon %s light %s apart %.2f" % [moon, moonlight != null, apart])
    # the dune field is made on a worker thread: the room is built without waiting for it, and the
    # ground comes in as the same land a few frames later
    var waited := land.pending()
    var frames := 0
    while land.pending() and frames < 600:
        await process_frame
        frames += 1
    var laid := false
    if land.ground.mesh != null:
        var made: PackedVector3Array = land.ground.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
        laid = made.size() == (land.cells + 1) * (land.cells + 1)
        for i in range(0, made.size(), 211):
            laid = laid and absf(land.y_at(made[i].x, made[i].z) - made[i].y) < 0.001
    _check("the_desert_ground_is_made_in_the_background_and_is_the_same_land", waited and laid,
           "waited %s laid %s after %d frames" % [waited, laid, frames])
    desert.queue_free()

    # --- the arctic hut is a log cabin, and nothing that was at the hut is gone
    var arctic = _built(Arctic)
    _shaders_compile(arctic, failed)
    var hut: Node3D = null
    for child in arctic.get_children():
        if child is Node3D and Vector2(child.position.x, child.position.z).is_equal_approx(Vector2(11.5, -17.0)):
            hut = child
    var cabin := false
    var panes := 0
    var props := 0
    var boxed := _has_mesh(arctic, "PrismMesh")
    if hut != null:
        for child in hut.get_children():
            if child is MeshInstance3D and (child as MeshInstance3D).mesh is ArrayMesh:
                var bounds: AABB = (child as MeshInstance3D).mesh.get_aabb()
                cabin = cabin or (bounds.size.x >= arctic.CABIN.x and bounds.size.z >= arctic.CABIN.z
                                  and bounds.size.y >= arctic.CABIN.y + arctic.RIDGE * 0.7)
            elif child is MeshInstance3D and (child as MeshInstance3D).mesh is BoxMesh:
                var size: Vector3 = ((child as MeshInstance3D).mesh as BoxMesh).size
                boxed = boxed or size.is_equal_approx(arctic.CABIN)
                if size.is_equal_approx(Vector3(0.9, 0.7, 0.05)):
                    panes += 1
            elif child is Node3D and not child is Light3D and not child is MeshInstance3D:
                props += 1
    # and it stands on the snow: its floor between the lowest and the highest ground under it,
    # neither floating over the snow nor sunk under it
    var under: Vector2 = arctic._land.ground_under(hut.position, 3.4) if hut != null else Vector2.ZERO
    var on_snow: bool = hut != null and hut.position.y > under.x and hut.position.y < under.y
    _check("the_arctic_hut_is_a_log_cabin_and_keeps_what_stood_at_it", cabin and not boxed and panes == 2 and props >= 8 and on_snow,
           "cabin %s boxed %s panes %d props %d on the snow %s" % [cabin, boxed, panes, props, on_snow])
    arctic.queue_free()

    _check("the_rebuilt_rooms_shaders_compile_and_the_mountain_has_its_birds", failed.is_empty() and soars,
           "failed %s soars %s" % [failed, soars])
