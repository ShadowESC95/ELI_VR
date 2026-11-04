class_name DigitalMatrixRoom
extends RoomBase

# The Simulation Lab: a world that is only being computed. A grid of light to
# the horizon, hills drawn as lines, towers of data running down their sides,
# a sun that is a picture of a sun.

func _build() -> void:
    var other := secondary.lerp(Color(1.0, 0.25, 0.75), 0.6)
    var env := environment(Color(0.03, 0.05, 0.09).lerp(accent, 0.25), 0.8)
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.004, 0.006, 0.014)
    env.fog_enabled = true
    env.fog_light_color = accent * 0.05
    env.fog_density = 0.0009

    _ground(other)
    _towers()
    _sky_things(other)
    _platform()
    _house_table()
    if motes:
        # bits falling out of the sky
        drift(Vector3(0, 9.0, 0), Vector3(26, 9, 26), 500, accent.lightened(0.3), 0.06, Vector3(0, -1, 0), 3.2, 1.0)

func _ground(other: Color) -> void:
    add(MeshKitClass.annulus(0.0, 900.0, 96), MaterialKitClass.shader("res://assets/shaders/grid_floor.gdshader", {"tint": rgb(accent)}), Vector3(0, -0.02, 0))
    var noise := FastNoiseLite.new()
    noise.seed = 4
    noise.frequency = 0.006
    noise.fractal_octaves = 3
    add(MeshKitClass.terrain(1500.0, 110, noise, 95.0, 150.0, 190.0, 80.0, -0.05), MaterialKitClass.shader("res://assets/shaders/wire_land.gdshader", {
        "tint": rgb(accent), "peak": rgb(other), "cell": 13.6, "top": 110.0, "energy": 2.2,
    }))

# Towers of data, each with a shape of its own: a base, narrower blocks set off above it, a mast;
# and the data on its way between them.
func _towers() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 9
    var tops: Array[Vector3] = []
    for i in 30:
        var angle := rng.randf() * TAU
        var distance := rng.randf_range(15.0, 120.0)
        var height := rng.randf_range(6.0, 12.0) + distance * rng.randf_range(0.1, 0.4)
        var width := rng.randf_range(1.6, 4.5)
        var tower := Node3D.new()
        tower.position = Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
        tower.rotation.y = rng.randf() * TAU
        add_child(tower)
        var tiers := 1 + (i % 3)
        var y := 0.0
        var w := width
        for tier in tiers:
            var h := height / float(tiers) * (1.0 if tier == 0 else rng.randf_range(0.6, 1.0))
            var block := BoxMesh.new()
            block.size = Vector3(w, h, w)
            var off := Vector3(rng.randf_range(-0.2, 0.2) * w, 0.0, rng.randf_range(-0.2, 0.2) * w) * float(tier)
            var face := add(block, MaterialKitClass.shader("res://assets/shaders/code_rain.gdshader", {
                "tint": rgb(accent), "seed": float(i) * 5.3 + float(tier), "cells": Vector2(w * 2.2, h * 2.0),
            }), off + Vector3(0, y + h * 0.5, 0), tower)
            face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            y += h
            w *= rng.randf_range(0.55, 0.8)
        var mast := rod(0.05, height * 0.25, MaterialKitClass.light(accent, 1.2), Vector3(0, y + height * 0.125, 0), tower)
        mast.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        var top := tower.position + Vector3(0, y + height * 0.25, 0)
        tops.append(top)
        if i % 3 == 0:
            blink(glow(top + Vector3(0, 0.5, 0), accent, 2.4, 1.6, 0.8), rng.randf_range(1.4, 3.0), rng.randf() * 3.0)
    _streams(tops, rng)

# Data on its way between the towers: from each to its nearest, an arc of light carrying its pulses
# at its own pace.
func _streams(tops: Array[Vector3], rng: RandomNumberGenerator) -> void:
    var joined := {}
    for i in tops.size():
        var nearest := -1
        var best := INF
        for j in tops.size():
            var apart := tops[i].distance_to(tops[j])
            if j != i and apart > 8.0 and apart < best:
                best = apart
                nearest = j
        if nearest < 0 or joined.has([mini(i, nearest), maxi(i, nearest)]):
            continue
        joined[[mini(i, nearest), maxi(i, nearest)]] = true
        var path := PackedVector3Array()
        var rise := clampf(best * 0.25, 2.0, 18.0)
        for s in 13:
            var t := float(s) / 12.0
            path.append(tops[i].lerp(tops[nearest], t) + Vector3(0, sin(t * PI) * rise, 0))
        var arc := add(MeshKitClass.beam(path, Vector3.UP, 0.07, 0.07),
                       strip({"energy": 1.8, "wave": 0.9, "speed": rng.randf_range(0.3, 0.9), "phase": rng.randf() * TAU}))
        arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _sky_things(other: Color) -> void:
    var disc := QuadMesh.new()
    disc.size = Vector2(520, 520)
    var sun_picture := add(disc, MaterialKitClass.shader("res://assets/shaders/synth_sun.gdshader", {
        "top": rgb(accent.lightened(0.5)), "bottom": rgb(other),
    }), Vector3(0, 250, -900))
    sun_picture.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    # shapes that are only edges, hanging and turning
    var rng := RandomNumberGenerator.new()
    rng.seed = 2
    for i in 7:
        var angle := TAU * float(i) / 7.0 + 0.4
        var at := Vector3(cos(angle) * rng.randf_range(14.0, 30.0), rng.randf_range(4.0, 13.0), sin(angle) * rng.randf_range(14.0, 30.0))
        var shape: Mesh
        var cells := Vector2(8, 4)
        if i % 3 == 0:
            var ball := SphereMesh.new()
            ball.radius = 1.6
            ball.height = 3.2
            ball.radial_segments = 8
            ball.rings = 4
            shape = ball
        elif i % 3 == 1:
            var box := BoxMesh.new()
            box.size = Vector3.ONE * 2.4
            shape = box
            cells = Vector2(3, 2)
        else:
            var hoop := TorusMesh.new()
            hoop.inner_radius = 1.0
            hoop.outer_radius = 1.9
            hoop.rings = 10
            hoop.ring_segments = 6
            shape = hoop
            cells = Vector2(10, 6)
        var solid := add(shape, MaterialKitClass.shader("res://assets/shaders/wire_solid.gdshader", {
            "tint": rgb(accent if i % 2 == 0 else other), "cells": cells,
        }), at)
        solid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        spin(solid, Vector3(rng.randf(), 1.0, rng.randf()), rng.randf_range(0.15, 0.4))
    lamp(Vector3(0, 6, 0), accent, 1.6, 24.0)

# ELI's house as a hologram on a table: each room a tile of light, the ways between them threads,
# the room ELI is in burning brightest and this room marked. What ELI's world says, nothing made up.
const HOUSE := "res://config/rooms/rooms.json"
const HERE := "simulation_lab"
var _tiles := {}                 # room id -> [tile, its material, its label]
var _eli_room := ""

func _house_table() -> void:
    var a := deg_to_rad(150.0)
    var at := Vector3(sin(a), 0.0, -cos(a)) * 5.6
    var dark := StandardMaterial3D.new()
    dark.albedo_color = Color(0.02, 0.025, 0.035)
    dark.metallic = 0.5
    dark.roughness = 0.4
    add(MeshKitClass.lathe(PackedVector2Array([
        Vector2(0.0, 0.95), Vector2(0.75, 0.95), Vector2(0.8, 0.9), Vector2(0.55, 0.1), Vector2(0.65, 0.0), Vector2(0.0, 0.0),
    ]), 48), dark, at)
    add(MeshKitClass.annulus(0.0, 0.72, 48), MaterialKitClass.light(accent, 0.5), at + Vector3(0, 0.955, 0))
    var house = JSON.parse_string(FileAccess.get_file_as_string(HOUSE)) if FileAccess.file_exists(HOUSE) else null
    if typeof(house) != TYPE_DICTIONARY:
        return
    var ids: Array = house.keys()
    var spots := {}
    for i in ids.size():
        var angle := TAU * float(i) / float(ids.size())
        spots[ids[i]] = at + Vector3(cos(angle) * 0.5, 1.22, sin(angle) * 0.5)
    for id in ids:
        for other in (house[id] as Dictionary).get("portals", []):
            if spots.has(other) and str(id) < str(other):
                var thread := add(MeshKitClass.beam(PackedVector3Array([spots[id], spots[other]]), Vector3.UP, 0.006, 0.006),
                                  MaterialKitClass.light(accent, 0.7))
                thread.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    for id in ids:
        var tile := BoxMesh.new()
        tile.size = Vector3(0.11, 0.03, 0.11)
        var material := MaterialKitClass.light(secondary if str(id) == HERE else accent, 0.9)
        var node := add(tile, material, spots[id])
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        var label := Label3D.new()
        label.text = str((house[id] as Dictionary).get("name", id))
        label.font_size = 20
        label.pixel_size = 0.0022
        label.modulate = accent.lightened(0.5)
        label.outline_size = 4
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        label.position = spots[id] + Vector3(0, 0.1, 0)
        add_child(label)
        _tiles[str(id)] = [node, material, label]
    lamp(at + Vector3(0, 1.7, 0), accent, 0.6, 3.5)

func show_eli(eli: Dictionary) -> void:
    var state: Dictionary = eli.get("state", {})
    var avatar: Dictionary = state.get("avatar", {})
    _eli_room = str(avatar.get("room", "")) if bool(eli.get("connected", false)) else ""
    for id in _tiles:
        var material: StandardMaterial3D = _tiles[id][1]
        material.emission_energy_multiplier = 3.0 if id == _eli_room else 0.9

func _animate(_delta: float) -> void:
    if _tiles.has(_eli_room):
        (_tiles[_eli_room][0] as MeshInstance3D).scale = Vector3.ONE * (1.4 + 0.3 * sin(_clock * 3.0))

func _platform() -> void:
    var black := StandardMaterial3D.new()
    black.albedo_color = Color(0.015, 0.02, 0.03)
    black.metallic = 0.6
    black.roughness = 0.3
    deck(9.0, black, black)
    for i in 12:
        var angle := TAU * float(i) / 12.0
        var tick := BoxMesh.new()
        tick.size = Vector3(0.03, 0.008, 2.6)
        var line := add(tick, MaterialKitClass.light(accent, 1.3), Vector3(cos(angle), 0.0, sin(angle)) * 6.6 + Vector3(0, 0.004, 0))
        line.rotation.y = PI * 0.5 - angle
    # columns of light at the edge, rising out of the grid
    var column := CylinderMesh.new()
    column.top_radius = 0.05
    column.bottom_radius = 0.05
    column.height = 30.0
    for i in 6:
        var angle := TAU * float(i) / 6.0 + PI / 6.0
        var at := Vector3(cos(angle), 0.0, sin(angle)) * 9.6
        add(column, strip({"energy": 1.5, "wave": 0.05, "speed": 0.5, "phase": float(i)}), at + Vector3(0, 15.0, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    probe()
