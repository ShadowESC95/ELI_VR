extends SceneTree

# A long run without a headset: every environment built and taken down over and over, ELI's things
# put in and taken out of each, with the real models, for as long as asked. Nothing may be left
# behind: the counts of nodes and objects after a full round must come back to what they were after
# the second, and no room may keep taking longer to build than it did at first: more than twice its
# own first builds and more than the slowest room's first build over them, two rounds running (one
# slow build on a shared machine is a hiccup, not a slowdown). Prints one line a round and
# "SOAK PASS" or "SOAK FAIL: why" at the end.
#
#     godot --headless --path . --xr-mode off --script tools/soak.gd -- --seconds=120

const AppConfigClass = preload("res://scripts/core/app_config.gd")
const RegistryClass = preload("res://scripts/core/registry.gd")
const RoomFactoryClass = preload("res://scripts/world/room_factory.gd")
const EliThingsClass = preload("res://scripts/eli/eli_things.gd")

func _initialize() -> void:
    _run.call_deferred()

## Frames until `done` says so, or `seconds` of real time have passed.
func _until(done: Callable, seconds: float) -> void:
    var give_up := Time.get_ticks_msec() + int(seconds * 1000.0)
    while not done.call() and Time.get_ticks_msec() < give_up:
        await process_frame

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
    var first_builds := {}          # environment -> its slowest build in the first two rounds
    var slow_before := {}           # environment -> true when its last build was slow
    var slowest_any := 0            # the slowest first build of any environment: the budget a build may run over by
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
            # a thing leaves over a moment of real time, which a slow machine's frames may not cover
            await _until(func() -> bool: return things.get_child_count() == 0, 5.0)
            if round_no <= 2:
                first_builds[env_id] = maxi(int(first_builds.get(env_id, 0)), took)
                slowest_any = maxi(slowest_any, took)
            else:
                var usual: int = first_builds[env_id]
                var slow := took > 2 * usual and took > usual + slowest_any
                if slow and bool(slow_before.get(env_id, false)):
                    failed = "%s took %d ms in round %d and was slow the round before; %d ms at first" % [env_id, took, round_no, usual]
                slow_before[env_id] = slow
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
