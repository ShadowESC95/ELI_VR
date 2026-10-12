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

func _towers() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 9
    for i in 30:
        var angle := rng.randf() * TAU
        var distance := rng.randf_range(15.0, 120.0)
        var height := rng.randf_range(6.0, 12.0) + distance * rng.randf_range(0.1, 0.4)
        var width := rng.randf_range(1.6, 4.5)
        var box := BoxMesh.new()
        box.size = Vector3(width, height, width)
        var tower := add(box, MaterialKitClass.shader("res://assets/shaders/code_rain.gdshader", {
            "tint": rgb(accent), "seed": float(i) * 5.3, "cells": Vector2(width * 2.2, height * 2.0),
        }), Vector3(cos(angle) * distance, height * 0.5, sin(angle) * distance))
        tower.rotation.y = rng.randf() * TAU
        tower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        if i % 3 == 0:
            blink(glow(tower.position + Vector3(0, height * 0.5 + 0.6, 0), accent, 2.4, 1.6, 0.8), rng.randf_range(1.4, 3.0), rng.randf() * 3.0)

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
