class_name DesertObservatoryRoom
extends RoomBase

# Desert Observatory: dunes under the Milky Way, far from any town. A dome
# stands open to the sky, a dish turns, and the only lamps are the dim red
# ones astronomers keep so their eyes stay dark.

const MOON := Vector3(-0.55, 0.30, 0.62)

var _streak: MeshInstance3D
var _next_streak := 4.0
var _streak_from := Vector3.ZERO
var _streak_to := Vector3.ZERO
var _streak_age := 9.0

func _build() -> void:
    var env := environment(Color(0.12, 0.15, 0.24), 0.6)
    # the galaxy stands straight up ahead, the whole point of being here
    star_sky(env, Vector3(0.05, 0.62, -0.78), 62.0, 2.1)
    sun(MOON, Color(0.70, 0.80, 1.0), 1.25)

    _dunes()
    _platform()
    _dome()
    _dish()
    _shooting_star()
    _camp()
    if motes:
        drift(Vector3(0, 1.6, 0), Vector3(14, 1.6, 14), 220, Color(0.9, 0.82, 0.7), 0.025, Vector3(1, 0.05, 0.3), 0.35, 0.5)
    probe()

func _dunes() -> void:
    var noise := FastNoiseLite.new()
    noise.seed = 31
    noise.frequency = 0.016
    noise.fractal_octaves = 3
    var sand := MaterialKitClass.surface("sand", 4.0, Color(0.62, 0.58, 0.56), 0.95)
    add(MeshKitClass.terrain(640.0, 190, noise, 26.0, 12.0, 26.0, 30.0, -0.16), sand)

    # the boulders, quiver trees and dry scrub of a desert's edge (scanned, assets/models)
    var rng := RandomNumberGenerator.new()
    rng.seed = 14
    var boulders := ["namaqualand_boulder_02", "namaqualand_boulder_03", "namaqualand_boulder_05", "namaqualand_boulder_06"]
    for i in 16:
        var angle := rng.randf() * TAU
        var distance := rng.randf_range(12.0, 44.0)
        prop(boulders[i % boulders.size()], Vector3(cos(angle) * distance, -0.16 + rng.randf_range(-0.15, 0.05), sin(angle) * distance),
             rng.randf() * 360.0, rng.randf_range(0.8, 1.7))
    for i in 7:
        var angle := rng.randf() * TAU
        var distance := rng.randf_range(13.0, 36.0)
        prop(["quiver_tree_01", "quiver_tree_02", "didelta_spinosa"][i % 3], Vector3(cos(angle) * distance, -0.16, sin(angle) * distance),
             rng.randf() * 360.0, rng.randf_range(0.9, 1.4))
    for i in 20:
        var angle := rng.randf() * TAU
        var distance := rng.randf_range(10.5, 40.0)
        prop("dry_branches_medium_01" if i % 2 else "shrub_04", Vector3(cos(angle) * distance, -0.16, sin(angle) * distance),
             rng.randf() * 360.0, rng.randf_range(1.0, 2.2))

func _platform() -> void:
    var slab := MaterialKitClass.surface("concrete", 3.0, Color(0.6, 0.55, 0.5), 0.9)
    deck(9.0, slab, slab)
    # red lamps low to the ground
    var red := Color(1.0, 0.16, 0.08)
    var post := CylinderMesh.new()
    post.top_radius = 0.03
    post.bottom_radius = 0.04
    post.height = 0.5
    for i in 10:
        var angle := TAU * float(i) / 10.0
        var at := Vector3(cos(angle), 0.0, sin(angle)) * 8.8
        add(post, slab, at + Vector3(0, 0.25, 0))
        glow(at + Vector3(0, 0.55, 0), red, 0.7, 1.4, 0.8)
        if i % 2 == 0:
            lamp(at + Vector3(0, 0.6, 0), red, 0.5, 4.5)

func _dome() -> void:
    # painted, not bare metal: a bare dome mirrors the whole sky
    var white := StandardMaterial3D.new()
    white.albedo_color = Color(0.86, 0.86, 0.84)
    white.roughness = 0.55
    var slab := MaterialKitClass.surface("concrete", 2.5, Color(0.62, 0.58, 0.54))
    var base := Node3D.new()
    base.position = Vector3(-12.0, 0.0, -19.0)
    add_child(base)
    add(MeshKitClass.lathe(PackedVector2Array([
        Vector2(0.0, 3.2), Vector2(4.6, 3.2), Vector2(4.6, 0.0), Vector2(0.0, 0.0),
    ]), 48), slab, Vector3.ZERO, base)
    # the dome, built as a turning shell with its slit left open
    var shell := Node3D.new()
    shell.position = Vector3(0, 3.2, 0)
    base.add_child(shell)
    var profile := PackedVector2Array()
    for s in 13:
        var a := float(s) / 12.0 * PI * 0.5
        profile.append(Vector2(sin(a) * 4.7 + 0.001, cos(a) * 4.7))
    profile.append(Vector2(4.7, 0.0))
    add(MeshKitClass.lathe(profile, 40), white, Vector3.ZERO, shell)
    var dark := StandardMaterial3D.new()
    dark.albedo_color = Color(0.01, 0.01, 0.015)
    var slit := BoxMesh.new()
    slit.size = Vector3(1.5, 4.9, 0.3)
    var opening := add(slit, dark, Vector3(0, 2.6, 3.3), shell)
    opening.rotation.x = deg_to_rad(-52.0)
    var steel := MaterialKitClass.metal("brushed_metal", 0.6, Color(0.6, 0.62, 0.68), 0.7)
    var tube := add(MeshKitClass.lathe(PackedVector2Array([
        Vector2(0.0, 2.4), Vector2(0.5, 2.4), Vector2(0.5, -1.5), Vector2(0.0, -1.5),
    ]), 24), steel, Vector3(0, 2.6, 2.4), shell)
    tube.rotation.x = deg_to_rad(38.0)
    glow(base.position + Vector3(0, 3.0, 4.9), Color(1.0, 0.16, 0.08), 2.6, 0.8, 0.2)
    shell.rotation.y = deg_to_rad(20.0)
    spin(shell, Vector3.UP, 0.02)

func _dish() -> void:
    var white := StandardMaterial3D.new()
    white.albedo_color = Color(0.84, 0.84, 0.82)
    white.roughness = 0.55
    white.cull_mode = BaseMaterial3D.CULL_DISABLED
    var steel := MaterialKitClass.metal("brushed_metal", 0.6, Color(0.5, 0.52, 0.58))
    var base := Node3D.new()
    base.position = Vector3(15.0, 0.4, -21.0)
    add_child(base)
    var mast := CylinderMesh.new()
    mast.top_radius = 0.3
    mast.bottom_radius = 0.5
    mast.height = 5.0
    add(mast, steel, Vector3(0, 2.5, 0), base)
    var head := Node3D.new()
    head.position = Vector3(0, 5.4, 0)
    base.add_child(head)
    var profile := PackedVector2Array()
    for s in 11:
        var r := float(s) / 10.0 * 3.6
        profile.append(Vector2(r + 0.001, r * r * 0.11))
    var bowl := add(MeshKitClass.lathe(profile, 40), white, Vector3.ZERO, head)
    bowl.rotation.x = deg_to_rad(48.0)
    var feed := CylinderMesh.new()
    feed.top_radius = 0.04
    feed.bottom_radius = 0.04
    feed.height = 2.6
    var arm := add(feed, steel, Vector3(0, 0.85, 1.0), head)
    arm.rotation.x = deg_to_rad(48.0)
    blink(glow(base.position + Vector3(0, 8.6, 0), Color(1.0, 0.2, 0.12), 0.9, 2.0, 0.9), 2.6)
    spin(head, Vector3.UP, 0.05)

# The astronomers' table at the edge of the platform, where the night's notes are kept under a red
# lamp; the generator by the dome; a stool by the dish (real things, assets/models).
func _camp() -> void:
    var a := deg_to_rad(150.0)
    var table := Node3D.new()
    table.position = Vector3(sin(a), 0.0, -cos(a)) * 6.3
    table.rotation.y = -a + PI * 0.5
    add_child(table)
    prop("wooden_picnic_table", Vector3.ZERO, 0.0, 1.0, table)
    prop("cassette_player", Vector3(0.35, 0.75, 0.5), 20.0, 1.0, table)
    prop("vintage_binocular", Vector3(-0.3, 0.75 + 0.05, -0.4), -35.0, 1.0, table)
    prop("Lantern_01", Vector3(0.0, 0.75, 0.0), 0.0, 1.0, table)
    var red := Color(1.0, 0.25, 0.12)
    glow(Vector3(0.0, 0.95, 0.0), red, 0.5, 1.2, 0.8, table)
    lamp(Vector3(0.0, 1.0, 0.0), red, 0.9, 4.0, table)
    prop("plastic_monobloc_chair_01", Vector3(1.5, 0.0, 1.9), 150.0, 1.0, table)
    prop("portable_generator", Vector3(-12.0, 0.0, -19.0) + Vector3(5.5, 0.0, 1.4), -20.0)
    prop("metal_stool_01", Vector3(15.0, 0.4, -21.0) + Vector3(-1.4, 0.0, 1.0), 0.0)

func _shooting_star() -> void:
    var quad := QuadMesh.new()
    quad.size = Vector2(1.0, 1.0)
    _streak = add(quad, MaterialKitClass.shader("res://assets/shaders/glow_sprite.gdshader", {
        "tint": Vector3(1.0, 0.97, 0.9), "energy": 3.0, "core": 1.0,
    }))
    _streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _streak.scale = Vector3.ONE * 9.0
    _streak.visible = false

func _animate(delta: float) -> void:
    # every so often one crosses the sky
    _streak_age += delta
    if _clock > _next_streak:
        var rng := RandomNumberGenerator.new()
        rng.randomize()
        var a := rng.randf_range(-1.2, 1.2)
        _streak_from = Vector3(sin(a), rng.randf_range(0.45, 0.8), -cos(a)).normalized() * 700.0
        _streak_to = _streak_from + Vector3(rng.randf_range(-260.0, 260.0), rng.randf_range(-200.0, -80.0), rng.randf_range(-60.0, 60.0))
        _streak_age = 0.0
        _next_streak = _clock + rng.randf_range(5.0, 12.0)
    var life := _streak_age / 0.7
    _streak.visible = life < 1.0
    if _streak.visible:
        _streak.position = _streak_from.lerp(_streak_to, life)
        _streak.scale = Vector3.ONE * 11.0 * sin(life * PI)
