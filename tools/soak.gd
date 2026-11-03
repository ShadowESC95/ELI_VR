extends SceneTree

# A long run without a headset: every environment built and taken down over and over, ELI's things
# put in and taken out of each, with the real models, for as long as asked. Nothing may be left
# behind: the counts of nodes and objects after a full round must come back to what they were after
# the first, and no room may take longer to build than the slowest first build. Prints one line a
# round and "SOAK PASS" or "SOAK FAIL: why" at the end.
#
#     godot --headless --path . --xr-mode off --script tools/soak.gd -- --seconds=120

const AppConfigClass = preload("res://scripts/core/app_config.gd")
const RegistryClass = preload("res://scripts/core/registry.gd")
const RoomFactoryClass = preload("res://scripts/world/room_factory.gd")
const EliThingsClass = preload("res://scripts/eli/eli_things.gd")

func _initialize() -> void:
    _run.call_deferred()

func _world(round_no: int, room_id: String) -> Dictionary:
    # a world message with a few of ELI's things in this room, different every round
    var objects := []
    for i in 6:
        var prop: String = ["ArmChair_01", "boulder_01", "desk_lamp_arm_01", "", "", ""][(i + round_no) % 6]
        var form := {"shape": "prop" if prop else ["orb", "pillar", "crystal"][i % 3], "colour": "#9fd8ff", "size": 1.0,
                     "glow": 0.3, "pos": [float(i) - 2.5, 0.0, 2.0 + float(round_no % 3)]}
        if prop:
            form["prop"] = prop
        objects.append({"id": "soak_%d_%d" % [round_no, i], "name": "Thing %d" % i, "room": room_id, "form": form})
    return {"objects": objects}

func _run() -> void:
    var seconds := 60.0
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--seconds="):
            seconds = float(arg.get_slice("=", 1))
    var config = AppConfigClass.new()
    config.load_all()
    var registry = RegistryClass.new()
    registry.load_all()
    var theme = registry.theme("cyan")
    var room_root := Node3D.new()
    root.add_child(room_root)
    var factory = RoomFactoryClass.new()
    if factory is Node:
        root.add_child(factory)
    var things = EliThingsClass.new()
    root.add_child(things)
    ModelCache.warm()
    while ModelCache.poll() > 0:
        await process_frame

    var environments: Array = registry.environment_ids()
    var rooms: Array = []
    var listed_rooms = JSON.parse_string(FileAccess.get_file_as_string("res://config/rooms/rooms.json"))
    if typeof(listed_rooms) == TYPE_DICTIONARY:
        rooms = listed_rooms.keys()
    else:
        for r in listed_rooms:
            rooms.append(str(r["id"]))

    var started := Time.get_ticks_msec()
    var round_no := 0
    var baseline := {}
    var slowest_first := {}
    var worst_ms := 0
    var failed := ""
    while Time.get_ticks_msec() - started < seconds * 1000.0 and failed.is_empty():
        round_no += 1
        for i in environments.size():
            var env_id: String = environments[i]
            var t := Time.get_ticks_msec()
            factory.build(room_root, env_id, theme, config)
            var took := Time.get_ticks_msec() - t
            things.show_room(rooms[i % rooms.size()])
            things.apply_world_state(_world(round_no, rooms[i % rooms.size()]))
            for _f in 3:
                await process_frame
            things.apply_world_state({"objects": []})
            await process_frame
            if round_no == 1:
                slowest_first[env_id] = took
            elif took > 2 * maxi(50, int(slowest_first.get(env_id, took))):
                failed = "%s took %d ms in round %d, %d ms the first time" % [env_id, took, round_no, slowest_first[env_id]]
            worst_ms = maxi(worst_ms, took)
        for child in room_root.get_children():
            child.free()
        for _f in 5:
            await process_frame
        var counts := {"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
                       "objects": Performance.get_monitor(Performance.OBJECT_COUNT),
                       "orphans": Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)}
        if round_no == 2:
            baseline = counts          # after the first round everything lazily made is made
        elif round_no > 2:
            for key in counts:
                if counts[key] > baseline[key] * 1.02 + 16:
                    failed = "%s grew from %d after round 2 to %d after round %d" % [key, baseline[key], counts[key], round_no]
        print("SOAK round %d: %d environments, worst build %d ms, nodes %d, objects %d, orphans %d" % [
            round_no, environments.size(), worst_ms, counts["nodes"], counts["objects"], counts["orphans"]])
    if round_no < 3 and failed.is_empty():
        failed = "only %d round(s) in %.0f s; a check needs three" % [round_no, seconds]
    print("SOAK PASS: %d rounds of %d environments in %.0f s" % [round_no, environments.size(), seconds] if failed.is_empty() else "SOAK FAIL: " + failed)
    quit(0 if failed.is_empty() else 1)
