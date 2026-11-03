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
    func get_value(key, fallback = null):
        return 2 if key == "desktop.layout_version" else (false if key == "desktop.enabled" else fallback)
    func set_value(_key, _value) -> void:
        pass
    func save_runtime() -> void:
        pass

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
    bay.show_eli({"connected": true, "state": {"awareness": {"cognitive_load": 0.9, "tool_activity": 0.2}}})
    var hard: float = bay._leds.get_shader_parameter("busy")
    bay.show_eli({"connected": true, "state": {"awareness": {"cognitive_load": 0.1, "tool_activity": 0.0}}})
    var easy: float = bay._leds.get_shader_parameter("busy")
    bay.show_eli({"connected": false})
    var away: float = bay._leds.get_shader_parameter("busy")
    _check("the_racks_work_as_hard_as_eli", is_equal_approx(hard, 0.9) and is_equal_approx(easy, 0.1) and away < easy,
           "%s %s %s" % [hard, easy, away])

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
    var desk := DesktopSurface.new()
    root.add_child(desk)
    desk.setup(DesktopSettings.new(), false, {})
    var helper := FakeHelper.new()
    desk.bridge = helper
    desk.global_position = Vector3(0, 2, -5)
    desk.point(desk.to_global(Vector3(0.0, 0.0, 0.0)), "left", true)
    desk.point(desk.to_global(Vector3(-2.1, 1.18, 0.0)), "", false, -1)
    desk.point(desk.to_global(Vector3(9.0, 0.0, 0.0)), "left", false)
    var sent: Array = helper.sent
    var desk_ok: bool = sent.size() == 4 and sent[0] == {"kind": "move", "x": 0.5, "y": 0.5} \
        and sent[1] == {"kind": "button", "button": "left", "down": true} and sent[2]["x"] == 0.0 and sent[2]["y"] == 0.0 \
        and sent[3] == {"kind": "scroll", "steps": -1}
    _check("pointing_at_the_desktop_moves_clicks_and_scrolls_it", desk_ok and desk.bridge_started == false, str(sent))
    _check("a_picture_eli_took_is_pinned_up_as_a_photograph", placed_at is Transform3D and wall.pin_spot("seen", 4) == null
           and pictured and link.asked == ["/v1/world/picture/31"], "placed %s, pictured %s, asked %s" % [placed_at is Transform3D, pictured, link.asked])
    _check("a_painting_is_painted_and_stands_on_an_easel_on_the_floor", styled == 5 and hung.eye_height() < 0.6
           and standing.eye_height() > 0.8 and standing._body.get_child_count() > hung._body.get_child_count(),
           "style %d, hung %s, standing %s" % [styled, hung.eye_height(), standing.eye_height()])
    quit()

func _labels(node: Node) -> Array:
    var out := []
    for child in node.get_children():
        if child is Label3D and (child as Label3D).visible:
            out.append(child)
        out.append_array(_labels(child))
    return out
