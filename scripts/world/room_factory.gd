class_name RoomFactory
extends RefCounted

# Every place is a script of its own in rooms/.
const REBUILT := {
    "eli_room": preload("res://scripts/world/rooms/own_room.gd"),
    "core_station": preload("res://scripts/world/rooms/orbital_core.gd"),
    "deep_space": preload("res://scripts/world/rooms/deep_space.gd"),
    "anomaly_void": preload("res://scripts/world/rooms/anomaly_void.gd"),
    "arctic_aurora": preload("res://scripts/world/rooms/arctic_aurora.gd"),
    "digital_matrix": preload("res://scripts/world/rooms/digital_matrix.gd"),
    "desert_observatory": preload("res://scripts/world/rooms/desert_observatory.gd"),
    "mountain_observatory": preload("res://scripts/world/rooms/mountain_observatory.gd"),
    "forest_sanctuary": preload("res://scripts/world/rooms/forest_sanctuary.gd"),
    "ocean_platform": preload("res://scripts/world/rooms/ocean_platform.gd"),
    "underwater_lab": preload("res://scripts/world/rooms/underwater_lab.gd"),
    "memory_cathedral": preload("res://scripts/world/rooms/memory_cathedral.gd"),
    "workshop_bay": preload("res://scripts/world/rooms/workshop_bay.gd"),
    "debug_bunker": preload("res://scripts/world/rooms/debug_bunker.gd"),
    "fabrication_lab": preload("res://scripts/world/rooms/fabrication_lab.gd"),
    "evidence_studio": preload("res://scripts/world/rooms/evidence_studio.gd"),
}
const FALLBACK := "core_station"

## Every room starts on what it can work out ahead of being built (RoomBase.warm), in the background.
static func warm() -> void:
    for script in REBUILT.values():
        script.warm()

static func rest() -> void:
    for script in REBUILT.values():
        script.rest()

## Builds the place under parent, in place of whatever stood there. An id no place answers to (a
## saved override from another version, a mistyped --eli-environment) is the Orbital Core.
func build(
    parent: Node3D,
    environment_id: String,
    p_theme: Dictionary,
    config,
    eli_mood: Dictionary = {}
) -> void:
    for child in parent.get_children():
        child.queue_free()
    var built := environment_id if REBUILT.has(environment_id) else FALLBACK
    var room = REBUILT[built].new()
    room.name = built
    parent.add_child(room)
    # ELI's own room is built the way ELI made it the first time, not plain and then again
    if not eli_mood.is_empty() and room.has_method("take_mood"):
        room.take_mood(eli_mood)
    room.build(p_theme, config)
