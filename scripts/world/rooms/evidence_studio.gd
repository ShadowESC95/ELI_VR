class_name EvidenceStudioRoom
extends RoomBase

# The Evidence Wall: a dim studio with one long wall of pinned sheets and
# photographs, strung together thread by thread. Lamps pick out the boards, a
# fan turns overhead, a projector flickers at the side.

var _slide: ShaderMaterial

func _build() -> void:
    var env := environment(Color(0.26, 0.22, 0.2), 1.1)
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.01, 0.009, 0.008)

    var boards := MaterialKitClass.surface("wood_floor", 2.6, Color(0.9, 0.8, 0.7), 0.55)
    var plaster := MaterialKitClass.surface("concrete", 3.0, Color(0.34, 0.3, 0.28), 1.0)
    hall(13.6, 5.2, boards, plaster, plaster)
    add(MeshKitClass.annulus(2.94, 3.03, 128), strip({"energy": 1.3, "wave": 0.12}), Vector3(0, 0.006, 0))

    _wall_of_sheets()
    _desk()
    _projector(plaster)
    _fan()
    if motes:
        drift(Vector3(0, 2.4, -3.0), Vector3(10, 2.4, 9), 240, Color(1.0, 0.9, 0.75), 0.028)
    lamp(Vector3(0, 4.2, 4.0), Color(1.0, 0.85, 0.7), 1.6, 16.0)
    lamp(Vector3(0, 4.2, -5.0), Color(1.0, 0.85, 0.7), 1.6, 16.0)
    probe(Vector3(27, 5.2, 27), Vector3(0, 2.6, 0), true)

func _wall_of_sheets() -> void:
    var cork := MaterialKitClass.surface("planks", 1.2, Color(0.75, 0.55, 0.36), 1.0, true)
    var rng := RandomNumberGenerator.new()
    rng.seed = 44
    var sheet := QuadMesh.new()
    sheet.size = Vector2(0.52, 0.68)
    var photo := QuadMesh.new()
    photo.size = Vector2(0.62, 0.5)
    var pins: Array[Vector3] = []
    var warm := Color(1.0, 0.84, 0.62)
    for b in 7:
        var a := deg_to_rad(-78.0 + 26.0 * b)
        var facing := Vector3(sin(a), 0.0, -cos(a))
        var board := Node3D.new()
        board.position = facing * 13.3 + Vector3(0, 2.6, 0)
        board.rotation.y = -a
        add_child(board)
        box(Vector3(5.6, 3.6, 0.12), cork, Vector3.ZERO, board)
        for i in 13:
            var is_photo := rng.randf() < 0.4
            var at := Vector3(rng.randf_range(-2.4, 2.4), rng.randf_range(-1.4, 1.4), 0.07 + 0.002 * i)
            var paper := add(photo if is_photo else sheet, MaterialKitClass.shader("res://assets/shaders/document.gdshader", {
                "seed": rng.randf() * 99.0, "picture": 1.0 if is_photo else 0.0,
            }), at, board)
            paper.rotation.z = rng.randf_range(-0.14, 0.14)
            pins.append(board.to_global(at + Vector3(0, 0.26, 0.02)) if is_inside_tree() else board.position + at.rotated(Vector3.UP, -a))
        if b % 2 == 0:
            var from := facing * 7.2 + Vector3(0, 5.0, 0)
            spot(from, board.position, warm, 9.0, 12.0, 38.0)
            glow(from, warm, 0.9, 1.2, 0.8)

    # thread from pin to pin, and a red head on every pin
    var thread := MaterialKitClass.light(Color(0.95, 0.12, 0.1), 1.6)
    for i in pins.size():
        if i % 3 == 0:
            glow(pins[i], Color(1.0, 0.2, 0.15), 0.12, 2.0, 1.0)
    for i in 34:
        var from := pins[rng.randi() % pins.size()]
        var to := pins[rng.randi() % pins.size()]
        if from.distance_to(to) < 0.6 or from.distance_to(to) > 9.0:
            continue
        var path := PackedVector3Array()
        for s in 7:
            var t := float(s) / 6.0
            # pulled a little clear of the wall, sagging in the middle
            path.append(from.lerp(to, t) * (1.0 - 0.012 * sin(t * PI)) + Vector3(0, -0.12 * sin(t * PI), 0))
        add(MeshKitClass.beam(path, Vector3.UP, 0.012, 0.012), thread).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _desk() -> void:
    var wood := MaterialKitClass.surface("wood_floor", 1.4, Color(0.6, 0.45, 0.36), 0.6, true)
    var paper := StandardMaterial3D.new()
    paper.albedo_color = Color(0.86, 0.82, 0.72)
    var desk := Node3D.new()
    desk.position = Vector3(-7.4, 0, 5.2)
    desk.rotation.y = deg_to_rad(50.0)
    add_child(desk)
    box(Vector3(2.6, 0.08, 1.3), wood, Vector3(0, 0.78, 0), desk)
    for x in [-1.1, 1.1]:
        box(Vector3(0.3, 0.76, 1.2), wood, Vector3(x, 0.38, 0), desk)
    var rng := RandomNumberGenerator.new()
    rng.seed = 3
    for i in 6:
        var stack := box(Vector3(0.32, rng.randf_range(0.03, 0.22), 0.44), paper, Vector3(rng.randf_range(-1.0, 1.0), 0.9, rng.randf_range(-0.4, 0.4)), desk)
        stack.rotation.y = rng.randf_range(-0.5, 0.5)
    var brass := MaterialKitClass.metal("brushed_metal", 0.4, Color(0.9, 0.7, 0.4), 0.6)
    rod(0.02, 0.6, brass, Vector3(0.9, 1.12, -0.4), desk)
    add(MeshKitClass.lathe(PackedVector2Array([Vector2(0.03, 0.14), Vector2(0.2, 0.0)]), 16), brass, Vector3(0.9, 1.36, -0.4), desk)
    var warm := Color(1.0, 0.8, 0.5)
    glow(Vector3(0.9, 1.38, -0.4), warm, 0.5, 1.6, 0.9, desk)
    spot(Vector3(0.9, 1.4, -0.4), Vector3(0.4, 0.8, 0.0), warm, 5.0, 4.0, 60.0, desk)

func _projector(wall: Material) -> void:
    var casing := MaterialKitClass.metal("brushed_metal", 0.5, Color(0.25, 0.25, 0.27), 0.8)
    var at := Vector3(6.4, 1.2, 4.0)
    rod(0.03, 1.2, casing, at - Vector3(0, 0.6, 0))
    box(Vector3(0.5, 0.3, 0.7), casing, at + Vector3(0, 0.15, 0)).rotation.y = deg_to_rad(-52.0)
    # the picture it throws on the side wall
    _slide = MaterialKitClass.shader("res://assets/shaders/document.gdshader", {"seed": 7.0, "picture": 1.0, "brightness": 1.3})
    var screen := QuadMesh.new()
    screen.size = Vector2(3.4, 2.4)
    var a := deg_to_rad(118.0)
    var picture := add(screen, _slide, Vector3(sin(a), 0.0, -cos(a)) * 13.4 + Vector3(0, 2.6, 0))
    picture.rotation.y = -a
    glow(at + Vector3(0.25, 0.15, 0.2), Color(1.0, 0.95, 0.85), 0.5, 2.0, 1.0)
    spot(at, picture.position, Color(1.0, 0.95, 0.85), 3.0, 14.0, 20.0)

func _fan() -> void:
    var dark := MaterialKitClass.surface("wood_floor", 1.0, Color(0.3, 0.22, 0.18), 0.7, true)
    var fan := Node3D.new()
    fan.position = Vector3(0, 4.7, 0)
    add_child(fan)
    rod(0.05, 0.5, dark, Vector3(0, 0.25, 0), fan)
    for i in 4:
        var blade := box(Vector3(1.6, 0.03, 0.3), dark, Vector3(cos(TAU * i / 4.0), 0, sin(TAU * i / 4.0)) * 0.95, fan)
        blade.rotation = Vector3(0.2, -TAU * float(i) / 4.0, 0.0)
    spin(fan, Vector3.UP, 1.1)

func _animate(_delta: float) -> void:
    # the slide changes every few seconds, and the lamp never quite holds steady
    _slide.set_shader_parameter("seed", floor(_clock / 5.0) * 3.7 + 7.0)
    _slide.set_shader_parameter("brightness", 1.2 + 0.12 * sin(_clock * 31.0) * sin(_clock * 7.0))
