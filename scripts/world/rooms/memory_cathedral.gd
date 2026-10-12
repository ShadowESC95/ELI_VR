class_name MemoryCathedralRoom
extends RoomBase

# The Memory Archive: a round hall of marble open to the stars, its walls
# shelved floor to roof with small lights, one for each thing remembered.
# They brighten and fade; a few drift loose and rise.

func _build() -> void:
    var env := environment(Color(0.20, 0.22, 0.30).lerp(accent, 0.15), 0.8)
    star_sky(env, Vector3(0.0, 0.92, -0.38), 30.0, 1.6)     # the galaxy stands over the roof

    var white := MaterialKitClass.surface("marble_white", 3.0, Color(0.92, 0.92, 0.95), 0.35)
    var black := MaterialKitClass.surface("marble_black", 2.4, Color(0.75, 0.75, 0.8), 0.25)
    add(MeshKitClass.annulus(0.0, 3.0, 96), black)
    add(MeshKitClass.annulus(3.0, 9.4, 128), white)
    add(MeshKitClass.annulus(9.4, 15.0, 128), black)
    add(MeshKitClass.annulus(2.94, 3.03, 128), strip({"energy": 1.5, "wave": 0.12}), Vector3(0, 0.006, 0))
    add(MeshKitClass.annulus(9.36, 9.44, 160), strip({"energy": 1.2, "wave": 0.08, "phase": 1.6}), Vector3(0, 0.006, 0))

    _shelves(black)
    _columns_and_roof(white)
    _orrery()
    if motes:
        # memories that have come loose
        drift(Vector3(0, 7.0, 0), Vector3(12, 7, 12), 90, accent.lightened(0.3), 0.16, Vector3(0.05, 1, 0.03), 0.22, 1.0)
        drift(Vector3(0, 3.0, 0), Vector3(10, 3, 10), 160, Color(1.0, 0.95, 0.85), 0.025)
    lamp(Vector3(0, 7.5, 0), Color(1.0, 0.95, 0.88), 2.2, 22.0)
    lamp(Vector3(0, 2.6, -11.0), accent, 0.9, 10.0)
    lamp(Vector3(9.5, 2.6, 5.5), accent, 0.9, 10.0)
    lamp(Vector3(-9.5, 2.6, 5.5), accent, 0.9, 10.0)
    probe(Vector3(30, 20, 30), Vector3(0, 4.0, 0))

func _shelves(stone: Material) -> void:
    # twelve bays of shelving round the wall, each a field of small lights
    for i in 12:
        var angle := TAU * (float(i) + 0.5) / 12.0
        var out := Vector3(cos(angle), 0.0, sin(angle))
        var bay := Node3D.new()
        bay.position = out * 14.6
        bay.rotation.y = -angle - PI * 0.5
        add_child(bay)
        box(Vector3(6.6, 15.0, 0.5), stone, Vector3(0, 7.5, -0.3), bay)
        var face := QuadMesh.new()
        face.size = Vector2(6.0, 13.6)
        add(face, MaterialKitClass.shader("res://assets/shaders/cell_wall.gdshader", {
            "tint": rgb(accent), "cells": Vector2(30.0, 68.0), "lit": 0.5, "pace": 0.35,
            "seed": float(i) * 4.1, "energy": 1.5, "base": Vector3(0.02, 0.02, 0.03),
        }), Vector3(0, 7.4, 0.0), bay)
        # shelf edges, so it reads as shelving and not a screen
        for level in 9:
            box(Vector3(6.2, 0.06, 0.2), stone, Vector3(0, 1.2 + 1.5 * level, 0.08), bay)

func _columns_and_roof(marble: Material) -> void:
    var column := MeshKitClass.lathe(PackedVector2Array([
        Vector2(0.0, 15.0), Vector2(0.62, 15.0), Vector2(0.62, 14.6), Vector2(0.42, 14.2), Vector2(0.4, 1.0),
        Vector2(0.52, 0.6), Vector2(0.66, 0.5), Vector2(0.66, 0.0), Vector2(0.0, 0.0),
    ]), 20)
    for i in 12:
        var angle := TAU * float(i) / 12.0
        add(column, marble, Vector3(cos(angle), 0.0, sin(angle)) * 12.6)
        # a rib from each column up to the open ring at the top
        var side := Vector3(-sin(angle), 0.0, cos(angle))
        add(MeshKitClass.beam(MeshKitClass.arc(12.6, 15.0, 3.6, 24.0, angle, 22), side, 0.4, 0.55), marble)
        add(MeshKitClass.beam(MeshKitClass.arc(12.35, 15.0, 3.6, 23.7, angle, 22), side, 0.06, 0.04),
            strip({"energy": 1.4, "wave": 0.2, "speed": 0.07, "phase": float(i) * 0.6}))
    add(MeshKitClass.lathe(PackedVector2Array([
        Vector2(3.2, 24.4), Vector2(4.0, 24.4), Vector2(4.0, 23.8), Vector2(3.2, 23.8), Vector2(3.2, 24.4),
    ]), 64), marble)
    add(MeshKitClass.lathe(PackedVector2Array([
        Vector2(12.2, 15.6), Vector2(13.1, 15.6), Vector2(13.1, 15.0), Vector2(12.2, 15.0), Vector2(12.2, 15.6),
    ]), 96), marble)
    # light falling in through the open top
    var beam := QuadMesh.new()
    beam.size = Vector2(6.5, 24.0)
    for i in 3:
        var shaft := add(beam, MaterialKitClass.shader("res://assets/shaders/light_shaft.gdshader", {
            "seed": float(i) * 2.9, "energy": 0.1, "tint": Vector3(0.8, 0.9, 1.0),
        }), Vector3(0, 12.0, 0))
        shaft.rotation.y = TAU * float(i) / 3.0
        shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _orrery() -> void:
    # rings turning inside each other, high over the middle of the floor
    var gold := MaterialKitClass.metal("brushed_metal", 0.4, Color(1.0, 0.8, 0.45), 0.5)
    var centre := Vector3(0, 9.5, 0)
    for i in 4:
        var hoop := TorusMesh.new()
        hoop.inner_radius = 1.5 + 0.75 * i
        hoop.outer_radius = hoop.inner_radius + 0.07
        hoop.rings = 96
        hoop.ring_segments = 8
        var ring := add(hoop, gold, centre)
        ring.rotation = Vector3(0.6 * i, 0.0, 0.9 * i + 0.3)
        spin(ring, Vector3(0.3 + 0.2 * i, 1.0, 0.1 * i), 0.22 - 0.04 * i)
        var bead := glow(Vector3(hoop.inner_radius + 0.03, 0, 0), accent, 0.9, 1.6, 0.9, ring)
        bead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var heart := SphereMesh.new()
    heart.radius = 0.55
    heart.height = 1.1
    add(heart, MaterialKitClass.light(accent.lightened(0.5), 2.2), centre)
    glow(centre, accent, 5.0, 0.6, 0.3)
