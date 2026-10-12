class_name WorkshopBayRoom
extends RoomBase

# The Workshop: a repair bay on the station, its big door open to space with
# Earth going by outside. An arm welds, the crane runs up and down its rails,
# a half-built rover sits on the lift.

const SUN_DIR := Vector3(-0.80, 0.32, -0.30)

var _crane: Node3D
var _arm_joints: Array = []
var _weld_glow: MeshInstance3D
var _weld_light: OmniLight3D

func _build() -> void:
    var env := environment(Color(0.34, 0.35, 0.38), 1.1)
    star_sky(env, Vector3(0.5, 0.4, -0.75), 10.0, 1.4)
    var sunlight := sun(SUN_DIR, Color(1.0, 0.96, 0.9), 2.2)
    sunlight.directional_shadow_max_distance = 60.0

    _earth_outside()
    _shell()
    _benches()
    _welding_arm()
    _crane_and_load()
    _rover_on_lift()
    if motes:
        drift(Vector3(0, 3.5, -6.0), Vector3(12, 3.5, 14), 260, Color(1.0, 0.95, 0.85), 0.03)
    probe(Vector3(30, 9, 34), Vector3(0, 4.5, -5.0), true)

func _earth_outside() -> void:
    var ball := SphereMesh.new()
    ball.radius = 420.0
    ball.height = 840.0
    ball.radial_segments = 128
    ball.rings = 64
    var earth := add(ball, MaterialKitClass.shader("res://assets/shaders/planet_earth.gdshader", {
        "day_tex": load("res://assets/space/earth_day.jpg"),
        "night_tex": load("res://assets/space/earth_night.jpg"),
        "cloud_tex": load("res://assets/space/earth_clouds.jpg"),
        "sun_dir": SUN_DIR.normalized(),
    }), Vector3(30.0, -250.0, -640.0))
    earth.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(110.0), deg_to_rad(23.4))
    earth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    spin(earth, Vector3.UP, 0.004)

func _shell() -> void:
    var floor_slab := MaterialKitClass.surface("concrete", 3.0, Color(0.6, 0.6, 0.6), 0.75, true)
    var plate := MaterialKitClass.surface("hull_panels", 2.4, Color(0.44, 0.46, 0.5), 0.9, true)
    var steel := MaterialKitClass.surface("brushed_metal", 1.0, Color(0.5, 0.52, 0.56), 0.8, true)
    box(Vector3(30.0, 0.4, 36.0), floor_slab, Vector3(0, -0.2, -5.0))
    box(Vector3(0.5, 9.0, 36.0), plate, Vector3(-15.0, 4.5, -5.0))
    box(Vector3(0.5, 9.0, 36.0), plate, Vector3(15.0, 4.5, -5.0))
    box(Vector3(30.0, 9.0, 0.5), plate, Vector3(0, 4.5, 13.0))
    box(Vector3(30.0, 0.5, 36.0), plate, Vector3(0, 9.0, -5.0))
    # the door: wall either side and over, open in the middle
    box(Vector3(6.0, 9.0, 0.5), plate, Vector3(-12.0, 4.5, -23.0))
    box(Vector3(6.0, 9.0, 0.5), plate, Vector3(12.0, 4.5, -23.0))
    box(Vector3(18.0, 2.0, 0.5), plate, Vector3(0, 8.0, -23.0))
    add(MeshKitClass.annulus(2.94, 3.03, 128), strip({"energy": 1.5, "wave": 0.12}), Vector3(0, 0.006, 0))

    # warning stripes at the door sill, roof trusses, lamps hung from them
    var yellow := MaterialKitClass.light(Color(1.0, 0.75, 0.1), 0.9)
    for i in 12:
        var stripe := box(Vector3(0.5, 0.01, 1.3), yellow, Vector3(-8.25 + 1.5 * i, 0.006, -21.6))
        stripe.rotation.y = deg_to_rad(35.0)
    for z in [-17.0, -9.0, -1.0, 7.0]:
        box(Vector3(30.0, 0.5, 0.35), steel, Vector3(0, 8.4, z))
    var warm := Color(1.0, 0.86, 0.66)
    for at in [Vector3(-7, 7.9, -13), Vector3(7, 7.9, -13), Vector3(-7, 7.9, -3), Vector3(7, 7.9, -3), Vector3(-7, 7.9, 7), Vector3(7, 7.9, 7)]:
        rod(0.02, 0.9, steel, at + Vector3(0, 0.45, 0))
        glow(at, warm, 1.4, 1.2, 0.8)
        spot(at, at * Vector3(1, 0, 1), warm, 12.0, 16.0, 62.0)
    # the bay's own working light, high up
    for at in [Vector3(-6, 6.5, -14), Vector3(6, 6.5, -14), Vector3(-6, 6.5, 2), Vector3(6, 6.5, 2)]:
        lamp(at, warm, 2.4, 18.0)

    # an amber beacon by the door, going round
    var beacon := Node3D.new()
    beacon.position = Vector3(-8.6, 6.4, -22.5)
    add_child(beacon)
    glow(Vector3.ZERO, Color(1.0, 0.6, 0.1), 1.2, 1.6, 0.9, beacon)
    spot(Vector3.ZERO, Vector3(0, -0.6, 1.0), Color(1.0, 0.6, 0.1), 5.0, 22.0, 26.0, beacon)
    spin(beacon, Vector3.UP, 2.4)

func _benches() -> void:
    var top := MaterialKitClass.surface("brushed_metal", 0.6, Color(0.7, 0.72, 0.76), 0.6, true)
    var frame := MaterialKitClass.surface("hull_panels", 1.0, Color(0.25, 0.27, 0.3), 0.9, true)
    var wood := MaterialKitClass.surface("planks", 1.4, Color(0.8, 0.66, 0.5), 0.9, true)
    var rng := RandomNumberGenerator.new()
    rng.seed = 13
    for z in [-14.0, -7.0, 0.0, 7.0]:
        for side in [-1.0, 1.0]:
            var bench := Node3D.new()
            bench.position = Vector3(13.6 * side, 0, z)
            add_child(bench)
            box(Vector3(1.6, 0.08, 4.4), top, Vector3(0, 0.95, 0), bench)
            box(Vector3(1.5, 0.9, 4.2), frame, Vector3(0, 0.45, 0), bench)
            # the board behind it, and what hangs there
            box(Vector3(0.08, 2.2, 4.4), wood, Vector3(0.9 * side, 2.3, 0), bench)
            for t in 9:
                var tool := box(Vector3(0.05, rng.randf_range(0.25, 0.8), rng.randf_range(0.06, 0.22)), top,
                    Vector3(0.82 * side, rng.randf_range(1.6, 3.0), -1.9 + 0.48 * t), bench)
                tool.rotation.x = rng.randf_range(-0.3, 0.3)
            # things left out on the bench
            for t in 4:
                box(Vector3(rng.randf_range(0.2, 0.5), rng.randf_range(0.1, 0.3), rng.randf_range(0.2, 0.5)), frame if t % 2 == 0 else wood,
                    Vector3(rng.randf_range(-0.4, 0.4), 1.1, -1.6 + 1.05 * t), bench)

func _welding_arm() -> void:
    var paint := StandardMaterial3D.new()
    paint.albedo_color = Color(0.95, 0.5, 0.08)
    paint.roughness = 0.45
    paint.metallic = 0.3
    var steel := MaterialKitClass.surface("brushed_metal", 0.5, Color(0.4, 0.42, 0.46), 0.7, true)
    var base := Node3D.new()
    base.position = Vector3(7.5, 0, -10.0)
    add_child(base)
    rod(0.55, 0.5, steel, Vector3(0, 0.25, 0), base)
    var shoulder := Node3D.new()
    shoulder.position = Vector3(0, 0.6, 0)
    base.add_child(shoulder)
    box(Vector3(0.36, 2.4, 0.36), paint, Vector3(0, 1.2, 0), shoulder)
    var elbow := Node3D.new()
    elbow.position = Vector3(0, 2.4, 0)
    shoulder.add_child(elbow)
    box(Vector3(0.28, 2.0, 0.28), paint, Vector3(0, 1.0, 0), elbow)
    var wrist := Node3D.new()
    wrist.position = Vector3(0, 2.0, 0)
    elbow.add_child(wrist)
    rod(0.06, 0.7, steel, Vector3(0, 0.35, 0), wrist)
    _arm_joints = [base, shoulder, elbow, wrist]
    _weld_glow = glow(Vector3(0, 0.75, 0), Color(0.75, 0.88, 1.0), 1.1, 3.0, 1.0, wrist)
    _weld_light = lamp(Vector3(0, 0.75, 0), Color(0.7, 0.85, 1.0), 2.0, 9.0, wrist)
    # the piece being worked on
    box(Vector3(2.2, 0.9, 1.4), steel, Vector3(7.5, 0.45, -12.6))
    if motes:
        drift(Vector3(7.5, 1.3, -12.4), Vector3(0.3, 0.3, 0.3), 60, Color(1.0, 0.75, 0.3), 0.03, Vector3(0.2, 1, 0.3), 1.6, 1.6).lifetime = 1.2

func _crane_and_load() -> void:
    var steel := MaterialKitClass.surface("brushed_metal", 1.0, Color(0.85, 0.7, 0.2), 0.7, true)
    for x in [-13.4, 13.4]:
        box(Vector3(0.4, 0.5, 34.0), steel, Vector3(x, 7.2, -5.0))
    _crane = Node3D.new()
    _crane.position = Vector3(0, 7.2, -5.0)
    add_child(_crane)
    box(Vector3(27.0, 0.7, 0.9), steel, Vector3.ZERO, _crane)
    box(Vector3(1.2, 0.8, 1.2), steel, Vector3(-3.0, -0.6, 0), _crane)
    var dark := MaterialKitClass.surface("hull_panels", 1.0, Color(0.2, 0.2, 0.22), 0.9, true)
    rod(0.03, 3.0, dark, Vector3(-3.0, -2.5, 0), _crane)
    var crate := MaterialKitClass.surface("planks", 1.0, Color(0.8, 0.62, 0.42), 0.9, true)
    box(Vector3(1.6, 1.3, 1.6), crate, Vector3(-3.0, -4.6, 0), _crane)
    blink(glow(Vector3(-3.0, -0.1, 0.7), Color(1.0, 0.6, 0.1), 0.7, 1.6, 0.9, _crane), 1.0)

func _rover_on_lift() -> void:
    var body := MaterialKitClass.surface("hull_panels", 1.2, Color(0.7, 0.72, 0.76), 0.6, true)
    var dark := StandardMaterial3D.new()
    dark.albedo_color = Color(0.05, 0.05, 0.06)
    dark.roughness = 0.9
    var lift := MaterialKitClass.surface("brushed_metal", 1.0, Color(0.2, 0.35, 0.6), 0.7, true)
    var rig := Node3D.new()
    rig.position = Vector3(-6.5, 0, -9.5)
    rig.rotation.y = deg_to_rad(24.0)
    add_child(rig)
    box(Vector3(3.4, 0.2, 5.2), lift, Vector3(0, 1.0, 0), rig)
    for x in [-1.3, 1.3]:
        var strut := box(Vector3(0.12, 1.5, 0.12), lift, Vector3(x, 0.5, 0), rig)
        strut.rotation.x = deg_to_rad(40.0)
        var other := box(Vector3(0.12, 1.5, 0.12), lift, Vector3(x, 0.5, 0), rig)
        other.rotation.x = deg_to_rad(-40.0)
    box(Vector3(2.2, 0.7, 3.8), body, Vector3(0, 1.95, 0), rig)
    box(Vector3(1.7, 0.6, 1.6), body, Vector3(0, 2.6, -0.6), rig)
    for x in [-1.25, 1.25]:
        for z in [-1.4, 0.0, 1.4]:
            var wheel := rod(0.42, 0.3, dark, Vector3(x, 1.55, z), rig)
            wheel.rotation.z = PI * 0.5
    # a panel off, and its insides showing
    var open := box(Vector3(1.0, 0.04, 1.2), body, Vector3(1.5, 2.75, 0.9), rig)
    open.rotation.z = deg_to_rad(-55.0)
    box(Vector3(0.9, 0.3, 1.0), MaterialKitClass.shader("res://assets/shaders/cell_wall.gdshader", {
        "tint": rgb(accent), "cells": Vector2(10.0, 8.0), "lit": 0.5, "pace": 1.5, "roundness": 1.0,
    }), Vector3(0.6, 2.36, 0.9), rig)
    lamp(Vector3(1.4, 2.6, 0.9), accent, 0.7, 4.0, rig)

func _animate(_delta: float) -> void:
    # the crane goes the length of the bay and back
    _crane.position.z = -5.0 + sin(_clock * 0.12) * 11.0
    # the arm reaches in, works, and draws back
    var reach := sin(_clock * 0.5)
    (_arm_joints[0] as Node3D).rotation.y = PI + sin(_clock * 0.23) * 0.25
    (_arm_joints[1] as Node3D).rotation.x = 0.55 + reach * 0.12
    (_arm_joints[2] as Node3D).rotation.x = 1.25 - reach * 0.2
    (_arm_joints[3] as Node3D).rotation.x = 0.6
    var working := reach > 0.2
    var spark := working and sin(_clock * 61.0) * sin(_clock * 17.0) > -0.3
    _weld_glow.visible = spark
    _weld_light.visible = spark
