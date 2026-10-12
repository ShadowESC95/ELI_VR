class_name DebugBunkerRoom
extends RoomBase

# The Debug Basement: a concrete bunker under everything, where faults are
# run to ground. Racks of machines blink in rows, logs scroll on old
# terminals, a fan turns in the roof, and one strip light is on its way out.

var _tube: MeshInstance3D
var _tube_light: OmniLight3D

func _build() -> void:
    var env := environment(Color(0.16, 0.19, 0.19), 1.0)
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.005, 0.006, 0.008)
    env.fog_enabled = true
    env.fog_light_color = Color(0.05, 0.07, 0.06)
    env.fog_density = 0.012

    var concrete := MaterialKitClass.surface("concrete", 3.0, Color(0.62, 0.62, 0.6), 0.9)
    var wall := MaterialKitClass.surface("concrete", 2.4, Color(0.5, 0.5, 0.48), 1.0)
    hall(15.0, 5.2, concrete, wall, wall)
    add(MeshKitClass.annulus(2.94, 3.03, 128), strip({"energy": 1.4, "wave": 0.12}), Vector3(0, 0.006, 0))

    _racks()
    _terminals()
    _roof(wall)
    if motes:
        drift(Vector3(0, 2.4, 0), Vector3(12, 2.4, 12), 200, Color(0.8, 0.9, 0.8), 0.025)
    probe(Vector3(30, 5.2, 30), Vector3(0, 2.6, 0), true)

func _racks() -> void:
    var steel := MaterialKitClass.metal("hull_panels", 1.2, Color(0.18, 0.19, 0.2), 0.8)
    var green := Color(0.25, 1.0, 0.45)
    var face := QuadMesh.new()
    face.size = Vector2(1.5, 3.3)
    # rows of racks either side and behind, leaving the way ahead clear
    for bearing in [58.0, 78.0, 98.0, 118.0, 138.0, 160.0, 200.0, 222.0, 242.0, 262.0, 282.0, 302.0]:
        var a := deg_to_rad(float(bearing))
        for row in 2:
            var rack := Node3D.new()
            rack.position = Vector3(sin(a), 0.0, -cos(a)) * (10.2 + 2.6 * row)
            rack.rotation.y = -a
            add_child(rack)
            box(Vector3(1.7, 3.6, 1.0), steel, Vector3(0, 1.8, 0), rack)
            add(face, MaterialKitClass.shader("res://assets/shaders/cell_wall.gdshader", {
                "tint": rgb(green), "cells": Vector2(16.0, 44.0), "lit": 0.42, "alarm": 0.07, "pace": 2.4,
                "seed": float(bearing) + row * 7.0, "energy": 1.5, "roundness": 1.0,
            }), Vector3(0, 1.8, 0.51), rack)
    lamp(Vector3(9.5, 2.4, 3.0), green, 0.5, 9.0)
    lamp(Vector3(-9.5, 2.4, 3.0), green, 0.5, 9.0)
    lamp(Vector3(0, 2.4, 10.0), green, 0.5, 9.0)

func _terminals() -> void:
    var casing := MaterialKitClass.metal("brushed_metal", 0.5, Color(0.3, 0.3, 0.28), 0.9)
    var amber := Color(1.0, 0.7, 0.2)
    var screen := QuadMesh.new()
    screen.size = Vector2(0.92, 0.66)
    for bearing in [-52.0, -38.0, 38.0, 52.0]:
        var a := deg_to_rad(float(bearing))
        var desk := Node3D.new()
        desk.position = Vector3(sin(a), 0.0, -cos(a)) * 8.6
        desk.rotation.y = -a
        add_child(desk)
        box(Vector3(1.5, 0.06, 0.8), casing, Vector3(0, 0.78, 0), desk)
        for leg in [-0.68, 0.68]:
            box(Vector3(0.06, 0.78, 0.7), casing, Vector3(leg, 0.39, 0), desk)
        box(Vector3(1.0, 0.82, 0.7), casing, Vector3(0, 1.22, -0.05), desk)
        add(screen, MaterialKitClass.shader("res://assets/shaders/code_rain.gdshader", {
            "tint": rgb(amber if int(bearing) % 3 == 0 else Color(0.3, 1.0, 0.5)), "seed": float(bearing),
            "cells": Vector2(26.0, 18.0), "energy": 1.4, "base": Vector3(0.01, 0.015, 0.01),
        }), Vector3(0, 1.24, 0.31), desk)
    lamp(Vector3(-6.0, 1.6, -6.0), amber, 0.5, 5.0)
    lamp(Vector3(6.0, 1.6, -6.0), Color(0.3, 1.0, 0.5), 0.5, 5.0)

func _roof(concrete: Material) -> void:
    var steel := MaterialKitClass.metal("brushed_metal", 0.6, Color(0.35, 0.36, 0.38), 0.8)
    # pillars, and beams running across
    for i in 8:
        var angle := TAU * float(i) / 8.0 + PI / 8.0
        box(Vector3(0.9, 5.2, 0.9), concrete, Vector3(cos(angle) * 6.9, 2.6, sin(angle) * 6.9))
    for i in 4:
        var beam := box(Vector3(30.0, 0.5, 0.6), concrete, Vector3(0, 4.95, 0))
        beam.rotation.y = PI * float(i) / 4.0
    # cable trays, slung under the roof
    for radius in [5.0, 11.4]:
        var tray := TorusMesh.new()
        tray.inner_radius = radius - 0.16
        tray.outer_radius = radius + 0.16
        tray.rings = 96
        tray.ring_segments = 4
        add(tray, steel, Vector3(0, 4.45, 0))

    # the fan, with light coming down through it
    var fan := Node3D.new()
    fan.position = Vector3(0, 4.9, 0)
    add_child(fan)
    for i in 5:
        var blade := box(Vector3(1.9, 0.03, 0.42), steel, Vector3(cos(TAU * i / 5.0), 0, sin(TAU * i / 5.0)) * 1.05, fan)
        blade.rotation = Vector3(0.25, -TAU * float(i) / 5.0, 0.0)
    spin(fan, Vector3.UP, 1.6)
    var down := spot(Vector3(0, 5.15, 0), Vector3.ZERO, Color(0.85, 0.95, 0.9), 5.0, 9.0, 46.0)
    down.shadow_enabled = shadows

    # red warning strips round the wall, breathing
    add(MeshKitClass.lathe(PackedVector2Array([Vector2(14.96, 3.9), Vector2(14.96, 4.0)]), 96), MaterialKitClass.shader(
        "res://assets/shaders/light_strip.gdshader", {"tint": Vector3(1.0, 0.12, 0.08), "energy": 1.8, "wave": 0.0, "speed": 0.22}))
    add(MeshKitClass.lathe(PackedVector2Array([Vector2(14.96, 0.3), Vector2(14.96, 0.36)]), 96), strip({"energy": 1.2, "wave": 0.05}))

    # a strip light that cannot make up its mind
    _tube = box(Vector3(2.2, 0.07, 0.14), MaterialKitClass.light(Color(0.9, 1.0, 0.95), 3.0), Vector3(-4.6, 4.6, -6.4))
    _tube_light = lamp(Vector3(-4.6, 4.3, -6.4), Color(0.85, 1.0, 0.92), 1.6, 9.0)
    box(Vector3(2.2, 0.07, 0.14), MaterialKitClass.light(Color(0.9, 1.0, 0.95), 3.0), Vector3(4.6, 4.6, -6.4))
    lamp(Vector3(4.6, 4.3, -6.4), Color(0.85, 1.0, 0.92), 1.6, 9.0)

func _animate(_delta: float) -> void:
    var on := sin(_clock * 23.0) * sin(_clock * 7.3) > -0.55 or fmod(_clock, 6.0) > 1.2
    _tube.visible = on
    _tube_light.visible = on
