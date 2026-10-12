class_name FabricationLabRoom
extends RoomBase

# The Upgrade Bay: a clean white lab where the next part is made. A printer
# builds a piece up layer by layer, crates go by on a belt, an arm sorts
# them, and the plan for the thing turns slowly in the air.

var _print: MeshInstance3D
var _head: Node3D
var _crates: Array = []
var _arm: Array = []

func _build() -> void:
    var env := environment(Color(0.42, 0.45, 0.5).lerp(accent, 0.08), 1.0)
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.02, 0.022, 0.026)

    var tiles := MaterialKitClass.surface("lab_tiles", 1.8, Color(0.86, 0.88, 0.9), 0.5)
    var white := StandardMaterial3D.new()
    white.albedo_color = Color(0.84, 0.86, 0.88)
    white.roughness = 0.5
    hall(14.0, 6.4, tiles, white, white)
    add(MeshKitClass.annulus(2.94, 3.03, 128), strip({"energy": 1.5, "wave": 0.12}), Vector3(0, 0.006, 0))
    # light coves where wall meets floor and roof, in the theme's colour
    add(MeshKitClass.lathe(PackedVector2Array([Vector2(13.96, 0.12), Vector2(13.96, 0.22)]), 96), strip({"energy": 1.6, "wave": 0.04}))
    add(MeshKitClass.lathe(PackedVector2Array([Vector2(13.96, 6.1), Vector2(13.96, 6.22)]), 96), strip({"energy": 1.6, "wave": 0.04, "phase": 2.0}))
    # light panels in the roof
    var panel := MeshKitClass.annulus(0.0, 1.1, 32)
    for i in 6:
        var angle := TAU * float(i) / 6.0 + PI / 6.0
        var at := Vector3(cos(angle) * 7.0, 6.38, sin(angle) * 7.0)
        add(panel, MaterialKitClass.light(Color(0.95, 0.98, 1.0), 1.15), at).rotation.x = PI
        lamp(at - Vector3(0, 0.6, 0), Color(0.95, 0.98, 1.0), 1.6, 12.0)

    _printer()
    _belt_and_arm()
    _plan_table()
    _glass_screens()
    probe(Vector3(28, 6.4, 28), Vector3(0, 3.2, 0), true)

func _printer() -> void:
    var steel := MaterialKitClass.metal("brushed_metal", 0.6, Color(0.82, 0.84, 0.88), 0.6)
    var at := Vector3(6.6, 0, -6.6)
    add(MeshKitClass.lathe(PackedVector2Array([
        Vector2(0.0, 0.5), Vector2(1.9, 0.5), Vector2(2.0, 0.4), Vector2(2.0, 0.0), Vector2(0.0, 0.0),
    ]), 48), steel, at)
    for i in 4:
        var a := TAU * float(i) / 4.0 + PI / 4.0
        rod(0.06, 3.6, steel, at + Vector3(cos(a) * 1.8, 2.3, sin(a) * 1.8))
    var hoop := TorusMesh.new()
    hoop.inner_radius = 1.74
    hoop.outer_radius = 1.86
    hoop.rings = 64
    hoop.ring_segments = 8
    add(hoop, steel, at + Vector3(0, 4.1, 0))

    # the piece being printed: it grows, is finished, and the next one starts
    _print = add(MeshKitClass.lathe(PackedVector2Array([
        Vector2(0.0, 2.6), Vector2(0.35, 2.6), Vector2(0.75, 2.0), Vector2(0.5, 1.3), Vector2(0.95, 0.6), Vector2(0.7, 0.0), Vector2(0.0, 0.0),
    ]), 40), MaterialKitClass.shader("res://assets/shaders/wire_solid.gdshader", {
        "tint": rgb(accent), "cells": Vector2(20.0, 26.0), "energy": 1.3,
    }), at + Vector3(0, 0.52, 0))
    _print.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _head = Node3D.new()
    _head.position = at
    add_child(_head)
    box(Vector3(0.3, 0.22, 0.3), steel, Vector3.ZERO, _head)
    glow(Vector3(0, -0.16, 0), accent.lightened(0.5), 0.6, 3.0, 1.0, _head)
    lamp(Vector3(0, -0.2, 0), accent, 1.0, 5.0, _head)

func _belt_and_arm() -> void:
    var steel := MaterialKitClass.metal("brushed_metal", 0.6, Color(0.6, 0.62, 0.66), 0.7)
    var rubber := StandardMaterial3D.new()
    rubber.albedo_color = Color(0.06, 0.06, 0.07)
    rubber.roughness = 0.85
    var line := Node3D.new()
    line.position = Vector3(-9.0, 0, 0.5)
    line.rotation.y = deg_to_rad(-8.0)
    add_child(line)
    box(Vector3(1.3, 0.1, 12.0), rubber, Vector3(0, 0.9, 0), line)
    box(Vector3(1.5, 0.82, 11.8), steel, Vector3(0, 0.43, 0), line)
    var crate := MeshKitClass.lathe(PackedVector2Array([
        Vector2(0.0, 0.5), Vector2(0.36, 0.5), Vector2(0.4, 0.46), Vector2(0.4, 0.0), Vector2(0.0, 0.0),
    ]), 4)
    var shell := StandardMaterial3D.new()
    shell.albedo_color = Color(0.9, 0.91, 0.93)
    shell.roughness = 0.35
    for i in 6:
        var one := add(crate, shell, Vector3(0, 0.95, 0), line)
        one.rotation.y = PI / 4.0
        add(MeshKitClass.lathe(PackedVector2Array([Vector2(0.405, 0.2), Vector2(0.405, 0.27)]), 4), strip({"energy": 1.6}), Vector3.ZERO, one)
        _crates.append(one)

    # an arm at the end of the belt, reaching over each one as it comes
    var paint := StandardMaterial3D.new()
    paint.albedo_color = Color(0.9, 0.91, 0.93)
    paint.roughness = 0.35
    var base := Node3D.new()
    base.position = Vector3(-7.0, 0, -5.6)
    add_child(base)
    rod(0.45, 0.5, steel, Vector3(0, 0.25, 0), base)
    var shoulder := Node3D.new()
    shoulder.position = Vector3(0, 0.55, 0)
    base.add_child(shoulder)
    box(Vector3(0.26, 1.8, 0.26), paint, Vector3(0, 0.9, 0), shoulder)
    var elbow := Node3D.new()
    elbow.position = Vector3(0, 1.8, 0)
    shoulder.add_child(elbow)
    box(Vector3(0.2, 1.5, 0.2), paint, Vector3(0, 0.75, 0), elbow)
    glow(Vector3(0, 1.55, 0), accent, 0.5, 1.6, 0.9, elbow)
    _arm = [base, shoulder, elbow]

func _plan_table() -> void:
    var steel := MaterialKitClass.metal("brushed_metal", 0.6, Color(0.82, 0.84, 0.88), 0.6)
    var at := Vector3(7.4, 0, 5.4)
    add(MeshKitClass.lathe(PackedVector2Array([
        Vector2(0.0, 0.95), Vector2(1.5, 0.95), Vector2(1.5, 0.85), Vector2(0.25, 0.75), Vector2(0.25, 0.08), Vector2(0.8, 0.0), Vector2(0.0, 0.0),
    ]), 40), steel, at)
    add(MeshKitClass.annulus(1.2, 1.3, 64), strip({"energy": 1.8}), at + Vector3(0, 0.956, 0))
    var hoop := TorusMesh.new()
    hoop.inner_radius = 0.42
    hoop.outer_radius = 0.9
    hoop.rings = 14
    hoop.ring_segments = 8
    var plan := add(hoop, MaterialKitClass.shader("res://assets/shaders/wire_solid.gdshader", {
        "tint": rgb(accent), "cells": Vector2(14.0, 8.0),
    }), at + Vector3(0, 2.2, 0))
    plan.rotation.x = 0.5
    plan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    spin(plan, Vector3(0.2, 1.0, 0.1), 0.4)
    glow(at + Vector3(0, 2.2, 0), accent, 2.6, 0.5, 0.2)

func _glass_screens() -> void:
    var pane := MaterialKitClass.glass(Color(0.7, 0.9, 1.0), 0.12)
    var steel := MaterialKitClass.metal("brushed_metal", 0.6, Color(0.82, 0.84, 0.88), 0.6)
    for bearing in [78.0, 150.0, 210.0, 282.0]:
        var a := deg_to_rad(float(bearing))
        var screen := box(Vector3(3.6, 2.6, 0.04), pane, Vector3(sin(a), 0.0, -cos(a)) * 11.2 + Vector3(0, 1.5, 0))
        screen.rotation.y = -a
        screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        box(Vector3(3.7, 0.2, 0.12), steel, Vector3(0, -1.4, 0), screen)

func _animate(_delta: float) -> void:
    # one print takes twelve seconds; then a pause, and it begins again
    var cycle := fmod(_clock, 15.0)
    var done := clampf(cycle / 12.0, 0.02, 1.0)
    _print.scale = Vector3(1.0, done, 1.0)
    var turn := _clock * 2.6
    var busy := cycle < 12.0
    _head.position = Vector3(6.6, 0, -6.6) + Vector3(cos(turn) * 0.7, 0.74 + done * 2.6, sin(turn) * 0.7) if busy \
        else Vector3(6.6, 3.8, -6.6)
    # crates travel the belt and come round again
    for i in _crates.size():
        (_crates[i] as Node3D).position.z = fposmod(_clock * 0.45 + float(i) * 2.0, 12.0) - 6.0
    # the arm dips each time one arrives
    var dip := pow(0.5 + 0.5 * sin(_clock * 0.45 * PI), 3.0)
    (_arm[0] as Node3D).rotation.y = deg_to_rad(110.0) + sin(_clock * 0.3) * 0.3
    (_arm[1] as Node3D).rotation.x = 0.5 + dip * 0.5
    (_arm[2] as Node3D).rotation.x = 1.3 - dip * 0.3
