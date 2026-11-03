class_name MountainObservatoryRoom
extends RoomBase

# The Reflection Chamber: a stone terrace on a mountain plateau at dawn, with
# a ring of still water round it that holds the sky. The place around you is
# a photograph of a real one, laid on the ground so it stays put as you move.

const DAWN := Vector3(0.754, 0.242, -0.611)

func _build() -> void:
    var env := environment(Color(0.5, 0.45, 0.55), 1.0)
    photo_sky(env, "mountain_dawn", 46.0, -0.14, 1.05)
    env.ambient_light_energy = 1.1
    sun(DAWN, Color(1.0, 0.72, 0.52), 1.7)
    glow(DAWN.normalized() * 880.0, Color(1.0, 0.75, 0.5), 300.0, 1.1, 0.6)

    _terrace()
    _stones()
    _instrument()
    flock(Vector3(30, 34, -70), 46.0, 6, 0.1)
    if motes:
        drift(Vector3(0, 2.2, 0), Vector3(12, 2.2, 12), 200, Color(1.0, 0.85, 0.7), 0.03, DAWN, 0.25, 0.7)
    probe(Vector3(30, 14, 30))

func _terrace() -> void:
    var paving := MaterialKitClass.surface("concrete", 2.6, Color(0.95, 0.82, 0.74), 0.85)
    var wall := MaterialKitClass.surface("rock", 1.6, Color(0.9, 0.72, 0.6), 1.0, true)
    # the terrace, then a moat of still water, then an outer walk
    add(MeshKitClass.annulus(0.0, 6.3, 128), paving)
    add(MeshKitClass.annulus(7.7, 9.3, 128), paving)
    var still := StandardMaterial3D.new()
    still.albedo_color = Color(0.03, 0.035, 0.05)
    still.metallic = 1.0
    still.roughness = 0.02
    add(MeshKitClass.annulus(6.3, 7.7, 128), still, Vector3(0, -0.05, 0))
    add(MeshKitClass.lathe(PackedVector2Array([
        Vector2(9.3, 0.0), Vector2(9.7, 0.0), Vector2(9.8, -0.14), Vector2(0.0, -0.14),
    ]), 128), paving)
    add(MeshKitClass.annulus(2.94, 3.03, 128), strip({"energy": 1.5, "wave": 0.12}), Vector3(0, 0.006, 0))

    # slabs to cross the water by, in front of each way out
    var slab := BoxMesh.new()
    slab.size = Vector3(1.9, 0.08, 1.5)
    for bearing in [-34.0, 0.0, 34.0, 90.0, 180.0, 270.0]:
        var a := deg_to_rad(float(bearing))
        var crossing := add(slab, paving, Vector3(sin(a), 0.0, -cos(a)) * 7.0 + Vector3(0, -0.035, 0))
        crossing.rotation.y = -a

    # a low wall of fitted stone on the outer edge, open towards the sunrise
    var block := BoxMesh.new()
    block.size = Vector3(1.5, 0.55, 0.42)
    for i in 34:
        var angle := TAU * float(i) / 34.0
        if abs(angle_difference(angle, atan2(DAWN.z, DAWN.x))) < 0.7:
            continue
        var stone := add(block, wall, Vector3(cos(angle), 0.0, sin(angle)) * 9.15 + Vector3(0, 0.27, 0))
        stone.rotation.y = -angle + PI * 0.5
        stone.scale = Vector3(1.0, 0.8 + 0.4 * fmod(float(i) * 0.37, 1.0), 1.0)

# Real boulders, trees and shrubs of a dry mountain plateau (scanned, assets/models), scattered
# beyond the outer walk; nothing stands on the terrace itself.
const BOULDERS := ["namaqualand_boulder_02", "namaqualand_boulder_03", "namaqualand_boulder_05", "namaqualand_boulder_06", "boulder_01"]
const TREES := ["searsia_lucida", "quiver_tree_01", "quiver_tree_02", "didelta_spinosa"]

func _stones() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 12
    for i in 18:
        var angle := rng.randf() * TAU
        var distance := rng.randf_range(11.5, 34.0)
        prop(BOULDERS[i % BOULDERS.size()], Vector3(cos(angle) * distance, -0.14 + rng.randf_range(-0.1, 0.05), sin(angle) * distance),
             rng.randf() * 360.0, rng.randf_range(0.8, 1.6))
    for i in 9:
        var angle := rng.randf() * TAU
        var distance := rng.randf_range(13.0, 30.0)
        prop(TREES[i % TREES.size()], Vector3(cos(angle) * distance, -0.14, sin(angle) * distance), rng.randf() * 360.0,
             rng.randf_range(0.9, 1.4))
    for i in 24:
        var angle := rng.randf() * TAU
        var distance := rng.randf_range(10.2, 36.0)
        prop("shrub_04" if i % 3 else "dry_branches_medium_01", Vector3(cos(angle) * distance, -0.14, sin(angle) * distance),
             rng.randf() * 360.0, rng.randf_range(1.2, 2.6))
    for at in [Vector3(-10.5, -0.14, -5.0), Vector3(11.0, -0.14, 3.5)]:
        prop("namaqualand_stones_01", at, rng.randf() * 360.0, 1.6)
    prop("stone_fire_pit", Vector3(4.6, 0.0, 3.8), 0.0, 1.0)

func _instrument() -> void:
    var brass := MaterialKitClass.metal("brushed_metal", 0.4, Color(0.95, 0.74, 0.42), 0.6)
    var stand := Node3D.new()
    stand.position = Vector3(-4.6, 0, -3.4)
    add_child(stand)
    var leg := CylinderMesh.new()
    leg.top_radius = 0.02
    leg.bottom_radius = 0.03
    leg.height = 1.7
    for i in 3:
        var a := TAU * float(i) / 3.0
        var one := add(leg, brass, Vector3(cos(a) * 0.3, 0.78, sin(a) * 0.3), stand)
        one.rotation = Vector3(sin(a) * 0.36, 0.0, -cos(a) * 0.36)
    var tube := add(MeshKitClass.lathe(PackedVector2Array([
        Vector2(0.0, 0.75), Vector2(0.085, 0.75), Vector2(0.085, 0.6), Vector2(0.06, 0.55), Vector2(0.06, -0.55),
        Vector2(0.035, -0.6), Vector2(0.035, -0.75), Vector2(0.0, -0.75),
    ]), 20), brass, Vector3(0, 1.62, 0), stand)
    tube.rotation = Vector3(deg_to_rad(-62.0), deg_to_rad(-50.0), 0.0)
    # benches facing the light: a bench's front is its +z, and the sunrise is towards -z
    for bearing in [118.0, 242.0]:
        var a := deg_to_rad(float(bearing))
        prop("painted_wooden_bench", Vector3(sin(a), 0.0, -cos(a)) * 5.0, 180.0 - bearing + 180.0, 1.1)
