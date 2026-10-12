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

func _stones() -> void:
    var rock := MaterialKitClass.surface("rock", 2.2, Color(1.0, 0.74, 0.6), 1.0, true)
    var rng := RandomNumberGenerator.new()
    rng.seed = 12
    for i in 18:
        var angle := rng.randf() * TAU
        var distance := rng.randf_range(12.0, 34.0)
        var boulder := add(MeshKitClass.rock(100 + i, rng.randf_range(0.5, 2.6), 0.32, 10), rock,
            Vector3(cos(angle) * distance, rng.randf_range(-0.3, 0.4), sin(angle) * distance))
        boulder.rotation.y = rng.randf() * TAU
    # cairns: someone was here before
    for at in [Vector3(-10.5, 0, -5.0), Vector3(11.0, 0, 3.5), Vector3(-4.0, 0, 11.5)]:
        var size := 0.42
        var y := -0.1
        for level in 5:
            add(MeshKitClass.rock(200 + level + int(at.x), size, 0.2, 8), rock, at + Vector3(rng.randf_range(-0.05, 0.05), y + size * 0.6, rng.randf_range(-0.05, 0.05)))
            y += size * 1.15
            size *= 0.78

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
    # benches facing the light
    var seat := BoxMesh.new()
    seat.size = Vector3(2.0, 0.12, 0.55)
    var paving := MaterialKitClass.surface("concrete", 1.5, Color(0.9, 0.8, 0.72))
    for bearing in [118.0, 242.0]:
        var a := deg_to_rad(float(bearing))
        var at := Vector3(sin(a), 0.0, -cos(a)) * 5.0
        var bench := add(seat, paving, at + Vector3(0, 0.45, 0))
        bench.rotation.y = -a
        var foot := BoxMesh.new()
        foot.size = Vector3(0.25, 0.4, 0.5)
        for side in [-0.75, 0.75]:
            add(foot, paving, Vector3(side, -0.25, 0), bench)
