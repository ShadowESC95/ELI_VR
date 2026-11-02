class_name EvidenceStudioRoom
extends RoomBase

# The Evidence Wall: a dim studio with one long wall of pinned sheets and
# photographs, strung together thread by thread. Lamps pick out the boards, a
# fan turns overhead, a projector flickers at the side; behind, a desk under its
# lamp and a cabinet of files.

var _slide: ShaderMaterial

func _build() -> void:
    var env := environment(Color(0.26, 0.22, 0.2), 1.35)
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.01, 0.009, 0.008)

    var boards := MaterialKitClass.surface("wood_floor", 2.6, Color(0.9, 0.8, 0.7), 0.55)
    var plaster := MaterialKitClass.surface("concrete", 3.0, Color(0.34, 0.3, 0.28), 1.0)
    hall(13.6, 5.2, boards, plaster, plaster)
    add(MeshKitClass.annulus(2.94, 3.03, 128), strip({"energy": 1.3, "wave": 0.12}), Vector3(0, 0.006, 0))

    _wall_of_sheets()
    _desk()
    _projector()
    _fan()
    _files()
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
    var desk := Node3D.new()
    desk.position = Vector3(-7.4, 0, 5.2)
    desk.rotation.y = deg_to_rad(50.0)
    add_child(desk)
    prop("metal_office_desk", Vector3.ZERO, 0.0, 1.0, desk)
    var top := 0.79
    prop("office_notepads", Vector3(-0.3, top, 0.05), 8.0, 1.0, desk)
    prop("clipboard", Vector3(0.25, top, 0.15), -12.0, 1.0, desk)
    prop("magnifying_glass_01", Vector3(-0.05, top, 0.25), 30.0, 1.0, desk)
    prop("desk_lamp_arm_01", Vector3(0.75, top, -0.15), -140.0, 1.0, desk)
    prop("SchoolChair_01", Vector3(0.1, 0, 0.7), 180.0, 1.0, desk)
    var warm := Color(1.0, 0.8, 0.5)
    glow(Vector3(0.6, top + 0.45, 0.0), warm, 0.4, 1.6, 0.9, desk)
    spot(Vector3(0.6, top + 0.5, 0.0), Vector3(0.0, top, 0.1), warm, 5.0, 4.0, 60.0, desk)

func _projector() -> void:
    var at := Vector3(6.4, 0, 4.0)
    prop("tool_cart", at, -52.0 + 90.0)
    prop("filmstrip_projector_8mm", at + Vector3(0, 0.96, 0), -52.0 + 180.0)
    var lens := at + Vector3(0, 1.2, 0)
    # the picture it throws on the side wall
    _slide = MaterialKitClass.shader("res://assets/shaders/document.gdshader", {"seed": 7.0, "picture": 1.0, "brightness": 1.3})
    var screen := QuadMesh.new()
    screen.size = Vector2(3.4, 2.4)
    var a := deg_to_rad(118.0)
    var picture := add(screen, _slide, Vector3(sin(a), 0.0, -cos(a)) * 13.4 + Vector3(0, 2.6, 0))
    picture.rotation.y = -a
    glow(lens, Color(1.0, 0.95, 0.85), 0.4, 2.0, 1.0)
    spot(lens, picture.position, Color(1.0, 0.95, 0.85), 3.0, 14.0, 20.0)

func _fan() -> void:
    var fan := prop("ceiling_fan", Vector3(0, 4.66, 0))
    if fan != null:
        spin(fan, Vector3.UP, 1.1)

# A cabinet of files against the back wall, its own lamp over it, and lamps on the
# walls either side so the back of the studio is a place too.
func _files() -> void:
    prop("vintage_cabinet_01", Vector3(0, 0, 12.6), 180.0)
    var warm := Color(1.0, 0.82, 0.6)
    spot(Vector3(0, 4.4, 9.0), Vector3(0, 1.2, 12.6), warm, 6.0, 9.0, 40.0)
    glow(Vector3(0, 4.4, 9.0), warm, 0.6, 1.2, 0.8)
    for degrees in [140.0, 220.0]:
        var a := deg_to_rad(degrees)
        var on_wall := Vector3(sin(a), 0.0, -cos(a)) * 13.45
        prop("industrial_wall_lamp", on_wall + Vector3(0, 2.3, 0), rad_to_deg(atan2(-on_wall.x, -on_wall.z)))
        var bulb := on_wall * 0.97 + Vector3(0, 2.25, 0)
        lamp(bulb, warm, 2.6, 11.0)
        glow(bulb, warm, 0.35, 1.4, 0.9)
    # the boxes of what has been gathered, on racks either side of the cabinet
    for degrees in [158.0, 202.0]:
        var a := deg_to_rad(degrees)
        var at := Vector3(sin(a), 0.0, -cos(a)) * 12.9
        var facing := rad_to_deg(atan2(-at.x, -at.z))
        prop("worn_metal_rack", at, facing)
        var beside := at.rotated(Vector3.UP, deg_to_rad(-6.0 if degrees < 180.0 else 6.0)) * 0.93
        prop("plastic_crate_01", beside, facing + 14.0)
        prop("plastic_crate_02", beside + Vector3(0, 0.41, 0), facing - 9.0)

func _animate(_delta: float) -> void:
    # the slide changes every few seconds, and the lamp never quite holds steady
    _slide.set_shader_parameter("seed", floor(_clock / 5.0) * 3.7 + 7.0)
    _slide.set_shader_parameter("brightness", 1.2 + 0.12 * sin(_clock * 31.0) * sin(_clock * 7.0))
