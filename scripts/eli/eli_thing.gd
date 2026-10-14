class_name EliThing
extends Manipulable3D

# One thing ELI has put in a room. It can be grabbed and moved like any other
# object; letting go tells ELI where it now stands.
#
# A thing is either a shape by name (pillar, tree, lamp) or anything at all,
# made part by part: boxes, balls, cones, rings, a profile turned on a lathe,
# an outline pulled up into a solid, a tube along a path, a line of text, each
# with its own place, turn, size, colour, metal, glow, clearness and motion.

signal let_go(thing)

const GROW_SECONDS := 0.9

var thing_id := ""
var shape := "orb"
var colour := Color("#9fd8ff")
var size := 1.0
var glow := 0.25
var meaning := ""
var made_by := ""
var kind := ""                  # "built" for what it made; "memory", "goal" for its records
var lamp: OmniLight3D

var _body: Node3D
var _name_tag: Label3D
var _material: StandardMaterial3D
var _target := Vector3.ZERO
var _held := false
var _grown := 0.0
var _leaving := false
var _clock := 0.0
var _parts: Array = []
var _parts_key := ""
var _moving: Array = []        # [node, spin radians a second, bob metres, pulse, material, rest height]
var _made_height := 1.0

func build(data: Dictionary) -> void:
    thing_id = str(data.get("id", ""))
    name = "Thing_%s" % thing_id.validate_node_name()
    setup(0.6, str(data.get("name", "")))
    _body = Node3D.new()
    add_child(_body)
    _name_tag = Label3D.new()
    _name_tag.font_size = 44
    _name_tag.pixel_size = 0.0024
    _name_tag.outline_size = 10
    _name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(_name_tag)
    _body.scale = Vector3.ONE * 0.001
    refresh(data, true)

# Bring it in line with what ELI's world now says of it.
func refresh(data: Dictionary, first: bool = false) -> void:
    var form: Dictionary = data.get("form", {})
    var look := [str(form.get("shape", "orb")), str(form.get("colour", "#9fd8ff")),
                 float(form.get("size", 1.0)), float(form.get("glow", 0.25))]
    label = str(data.get("name", label))
    meaning = str(data.get("meaning", ""))
    made_by = str(data.get("made_by", ""))
    kind = str(data.get("kind", ""))
    var pos: Array = form.get("pos", [0.0, 0.0, 0.0])
    _target = EliSenses.from_protocol(pos)
    if first:
        position = _target
    var parts_key := JSON.stringify(form.get("parts", []))
    if first or parts_key != _parts_key or look != [shape, "#" + colour.to_html(false), size, glow]:
        shape = look[0]
        colour = Color(look[1])
        size = look[2]
        glow = look[3]
        _parts = form.get("parts", [])
        _parts_key = parts_key
        _shape()
    _name_tag.text = label
    _name_tag.modulate = colour.lightened(0.55)
    _name_tag.position = Vector3(0, eye_height() * 2.0 + 0.28, 0)

func leave() -> void:
    _leaving = true

func eye_height() -> float:
    if not _parts.is_empty():
        return _made_height * 0.5
    return {"orb": 0.9, "pillar": 1.1, "lamp": 1.0, "beacon": 1.6, "tree": 1.2, "arch": 1.1,
            "ring": 0.9, "board": 0.9, "crystal": 0.7}.get(shape, 0.35) * size

func begin_grab() -> void:
    super.begin_grab()
    _held = true

func end_grab() -> void:
    super.end_grab()
    _held = false
    position.y = maxf(position.y, 0.0)
    _target = position
    if kind != "memory" and kind != "goal":     # a record can be picked up; moving one changes nothing in ELI
        let_go.emit(self)

func _process(delta: float) -> void:
    _clock += delta
    if _leaving:
        _grown = maxf(0.0, _grown - delta / 0.5)
        if _grown <= 0.0:
            queue_free()
            return
    elif _grown < 1.0:
        _grown = minf(1.0, _grown + delta / GROW_SECONDS)
    # out of the ground, with a little overshoot
    var eased := 1.0 - pow(1.0 - _grown, 3.0)
    _body.scale = Vector3.ONE * maxf(0.001, eased * (1.0 + 0.12 * sin(_grown * PI)))
    if not _held:
        position = position.lerp(_target, clampf(delta * 4.0, 0.0, 1.0))
    if shape == "orb":
        _body.position.y = 0.06 * sin(_clock * 1.1 + float(get_index()))
    elif shape == "ring" or shape == "crystal":
        _body.rotate_y(delta * 0.35)
    for m in _moving:
        var node: Node3D = m[0]
        if not is_instance_valid(node):
            continue
        if m[1] != 0.0:
            node.rotate_y(delta * m[1])
        if m[2] > 0.0:
            node.position.y = m[5] + m[2] * sin(_clock * 1.3 + m[5])
        if m[3] > 0.0 and m[4] != null:
            m[4].emission_energy_multiplier = m[6] * (1.0 + m[3] * sin(_clock * 2.2 + m[5])) * eased
    if _material and _parts.is_empty():
        var breath := 1.0 + 0.18 * sin(_clock * 1.7 + float(get_index()) * 0.9)
        # its own colour first: only a thing meant to glow gives off much light
        _material.emission_energy_multiplier = (0.03 + 0.8 * glow * glow) * breath * eased
    if lamp:
        lamp.light_energy = (0.4 + 1.6 * glow) * eased

# --- shapes ---------------------------------------------------------------------

func _shape() -> void:
    for child in _body.get_children():
        child.queue_free()
    lamp = null
    _moving.clear()
    if not _parts.is_empty():
        _material = null
        _made_height = 0.2
        for part in _parts:
            if typeof(part) == TYPE_DICTIONARY:
                _part(part)
        return
    _material = StandardMaterial3D.new()
    _material.albedo_color = colour
    _material.roughness = 0.42
    _material.metallic = 0.15
    _material.emission_enabled = true
    _material.emission = colour
    var s := size
    match shape:
        "pillar":
            _cyl(0.17 * s, 0.2 * s, 2.2 * s, Vector3(0, 1.1 * s, 0))
            _box(Vector3(0.52, 0.12, 0.52) * s, Vector3(0, 0.06 * s, 0))
            _box(Vector3(0.46, 0.1, 0.46) * s, Vector3(0, 2.2 * s, 0))
        "block":
            _box(Vector3.ONE * 0.8 * s, Vector3(0, 0.4 * s, 0))
        "slab":
            _box(Vector3(1.7, 0.12, 1.7) * s, Vector3(0, 0.06 * s, 0))
        "arch":
            _box(Vector3(0.24, 2.0, 0.24) * s, Vector3(-0.7 * s, 1.0 * s, 0))
            _box(Vector3(0.24, 2.0, 0.24) * s, Vector3(0.7 * s, 1.0 * s, 0))
            _box(Vector3(1.9, 0.26, 0.3) * s, Vector3(0, 2.1 * s, 0))
        "ring":
            var torus := TorusMesh.new()
            torus.inner_radius = 0.62 * s
            torus.outer_radius = 0.74 * s
            var ring := _mesh(torus, Vector3(0, 0.95 * s, 0))
            ring.rotation.x = PI * 0.5
        "crystal":
            _cone(0.34 * s, 0.9 * s, Vector3(0, 0.95 * s, 0), 6)
            var under := _cone(0.34 * s, 0.5 * s, Vector3(0, 0.25 * s, 0), 6)
            under.rotation.x = PI
        "tree":
            _cyl(0.07 * s, 0.11 * s, 0.9 * s, Vector3(0, 0.45 * s, 0), Color(0.36, 0.25, 0.18))
            for i in 3:
                _cone((0.62 - 0.14 * i) * s, 0.75 * s, Vector3(0, (0.95 + 0.42 * i) * s, 0), 9)
        "lamp":
            _cyl(0.035 * s, 0.05 * s, 1.5 * s, Vector3(0, 0.75 * s, 0), Color(0.2, 0.2, 0.22))
            _ball(0.17 * s, Vector3(0, 1.6 * s, 0))
            _light(Vector3(0, 1.6 * s, 0), 5.0 * s)
        "board":
            _cyl(0.03 * s, 0.03 * s, 0.9 * s, Vector3(0, 0.45 * s, 0), Color(0.2, 0.2, 0.22))
            _box(Vector3(1.3, 0.8, 0.05) * s, Vector3(0, 1.2 * s, 0))
        "cone":
            _cone(0.42 * s, 1.0 * s, Vector3(0, 0.5 * s, 0), 24)
        "stair":
            for i in 4:
                _box(Vector3(0.9, 0.2 * (i + 1), 0.3) * s, Vector3(0, 0.1 * (i + 1) * s, (0.45 - 0.3 * i) * s))
        "table":
            _box(Vector3(1.3, 0.08, 0.8) * s, Vector3(0, 0.76 * s, 0))
            for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
                _box(Vector3(0.07, 0.74, 0.07) * s, Vector3(0.58 * corner.x * s, 0.37 * s, 0.33 * corner.y * s))
        "seat":
            _box(Vector3(0.5, 0.08, 0.5) * s, Vector3(0, 0.45 * s, 0))
            _box(Vector3(0.5, 0.6, 0.07) * s, Vector3(0, 0.78 * s, -0.22 * s))
            _box(Vector3(0.42, 0.42, 0.42) * s, Vector3(0, 0.21 * s, 0))
        "pool":
            var rim := TorusMesh.new()
            rim.inner_radius = 0.92 * s
            rim.outer_radius = 1.02 * s
            _mesh(rim, Vector3(0, 0.05, 0))
            var water := _cyl(0.94 * s, 0.94 * s, 0.03, Vector3(0, 0.04, 0))
            var still := StandardMaterial3D.new()
            still.albedo_color = colour.darkened(0.75)
            still.metallic = 1.0
            still.roughness = 0.04
            water.material_override = still
        "beacon":
            _cyl(0.05 * s, 0.22 * s, 3.2 * s, Vector3(0, 1.6 * s, 0))
            _ball(0.14 * s, Vector3(0, 3.3 * s, 0))
            _light(Vector3(0, 3.3 * s, 0), 7.0 * s)
        _:
            _ball(0.34 * s, Vector3(0, 0.9 * s, 0))
            if glow >= 0.5:
                _light(Vector3(0, 0.9 * s, 0), 4.0 * s)

func _mesh(mesh: Mesh, at: Vector3, tint = null) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.position = at
    if tint == null:
        node.material_override = _material
    else:
        var plain := StandardMaterial3D.new()
        plain.albedo_color = tint
        plain.roughness = 0.7
        node.material_override = plain
    _body.add_child(node)
    return node

func _box(extent: Vector3, at: Vector3) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = extent
    return _mesh(mesh, at)

func _cyl(top: float, bottom: float, height: float, at: Vector3, tint = null) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = top
    mesh.bottom_radius = bottom
    mesh.height = height
    mesh.radial_segments = 24
    return _mesh(mesh, at, tint)

func _cone(radius: float, height: float, at: Vector3, sides: int) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.0
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = sides
    return _mesh(mesh, at)

func _ball(radius: float, at: Vector3) -> MeshInstance3D:
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    return _mesh(mesh, at)

func _light(at: Vector3, reach: float) -> void:
    lamp = OmniLight3D.new()
    lamp.position = at
    lamp.light_color = colour
    lamp.omni_range = reach
    lamp.shadow_enabled = false
    _body.add_child(lamp)

# --- made part by part -------------------------------------------------------------

func _part(part: Dictionary) -> void:
    var kind := str(part.get("kind", "box"))
    var pos: Array = part.get("pos", [0.0, 0.0, 0.0])
    var rot: Array = part.get("rot", [0.0, 0.0, 0.0])
    var extent: Array = part.get("size", [1.0, 1.0, 1.0])
    var at := Vector3(float(pos[0]), float(pos[1]), -float(pos[2]))
    var scale_by := Vector3(float(extent[0]), float(extent[1]), float(extent[2]))
    var tint := Color(str(part.get("colour", "#9fd8ff")))
    var shine := clampf(float(part.get("glow", 0.0)), 0.0, 1.0)
    _made_height = maxf(_made_height, at.y + scale_by.y)

    if kind == "text":
        var words := Label3D.new()
        words.text = str(part.get("text", ""))
        words.font_size = 64
        words.pixel_size = 0.004 * scale_by.y
        words.outline_size = 12
        words.modulate = tint
        words.position = at
        words.rotation_degrees = Vector3(float(rot[0]), float(rot[1]), float(rot[2]))
        words.double_sided = true
        _body.add_child(words)
        return

    var look := StandardMaterial3D.new()
    look.albedo_color = tint
    look.metallic = clampf(float(part.get("metal", 0.1)), 0.0, 1.0)
    look.roughness = clampf(float(part.get("rough", 0.5)), 0.03, 1.0)
    look.emission_enabled = true
    look.emission = tint
    look.emission_energy_multiplier = 0.03 + 1.4 * shine * shine
    var clear := clampf(float(part.get("clear", 0.0)), 0.0, 1.0)
    if clear > 0.01:
        look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        look.albedo_color.a = 1.0 - 0.85 * clear

    var node: Node3D
    match kind:
        "tube":
            node = _tube(part.get("path", []), float(part.get("radius", 0.05)), look)
        "lathe":
            look.cull_mode = BaseMaterial3D.CULL_DISABLED
            node = _solid(_lathe(part.get("profile", [])), look)
        "extrude":
            look.cull_mode = BaseMaterial3D.CULL_DISABLED
            node = _solid(_extrude(part.get("outline", [])), look)
        _:
            node = _solid(_primitive(kind), look)
    if node == null:
        return
    node.position = at
    node.rotation_degrees = Vector3(float(rot[0]), float(rot[1]), float(rot[2]))
    node.scale = scale_by
    _body.add_child(node)

    var spin := deg_to_rad(float(part.get("spin", 0.0)))
    var bob := float(part.get("bob", 0.0))
    var pulse := float(part.get("pulse", 0.0))
    if spin != 0.0 or bob > 0.0 or pulse > 0.0:
        _moving.append([node, spin, bob, pulse, look, at.y, look.emission_energy_multiplier])
    if shine >= 0.7 and lamp == null:
        lamp = OmniLight3D.new()
        lamp.position = at + Vector3(0, scale_by.y * 0.5, 0)
        lamp.light_color = tint
        lamp.omni_range = 5.0
        lamp.shadow_enabled = false
        _body.add_child(lamp)
        glow = shine

func _solid(mesh: Mesh, look: Material) -> MeshInstance3D:
    if mesh == null:
        return null
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.material_override = look
    return node

# One unit across, standing on its foot, so that size is its width, height and depth.
func _primitive(kind: String) -> Mesh:
    match kind:
        "ball":
            var ball := SphereMesh.new()
            ball.radius = 0.5
            ball.height = 1.0
            return _raised(ball, 0.5)
        "cylinder", "cone":
            var round := CylinderMesh.new()
            round.top_radius = 0.0 if kind == "cone" else 0.5
            round.bottom_radius = 0.5
            round.height = 1.0
            round.radial_segments = 32
            return _raised(round, 0.5)
        "torus":
            var ring := TorusMesh.new()
            ring.inner_radius = 0.36
            ring.outer_radius = 0.5
            return _raised(ring, 0.07)
        "capsule":
            var pill := CapsuleMesh.new()
            pill.radius = 0.25
            pill.height = 1.0
            return _raised(pill, 0.5)
        "prism":
            return _raised(PrismMesh.new(), 0.5)
    return _raised(BoxMesh.new(), 0.5)

# A mesh moved up so that it stands on y = 0 and not through it.
func _raised(mesh: Mesh, by: float) -> Mesh:
    var st := SurfaceTool.new()
    st.append_from(mesh, 0, Transform3D(Basis.IDENTITY, Vector3(0, by, 0)))
    return st.commit()

# A profile of [radius, height] points turned round the upright axis.
func _lathe(profile: Array) -> Mesh:
    if profile.size() < 2:
        return null
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var around := 28
    for i in profile.size() - 1:
        var a: Array = profile[i]
        var b: Array = profile[i + 1]
        for s in around:
            var t0 := TAU * float(s) / around
            var t1 := TAU * float(s + 1) / around
            var p00 := Vector3(cos(t0) * float(a[0]), float(a[1]), sin(t0) * float(a[0]))
            var p01 := Vector3(cos(t1) * float(a[0]), float(a[1]), sin(t1) * float(a[0]))
            var p10 := Vector3(cos(t0) * float(b[0]), float(b[1]), sin(t0) * float(b[0]))
            var p11 := Vector3(cos(t1) * float(b[0]), float(b[1]), sin(t1) * float(b[0]))
            for v in [p00, p10, p01, p01, p10, p11]:
                st.add_vertex(v)
    st.generate_normals()
    return st.commit()

# An outline of [right, forward] points pulled up one unit into a solid.
func _extrude(outline: Array) -> Mesh:
    if outline.size() < 3:
        return null
    var flat := PackedVector2Array()
    for point in outline:
        flat.append(Vector2(float(point[0]), -float(point[1])))
    var faces := Geometry2D.triangulate_polygon(flat)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for level in [0.0, 1.0]:
        for index in faces:
            st.add_vertex(Vector3(flat[index].x, level, flat[index].y))
    for i in flat.size():
        var a := flat[i]
        var b := flat[(i + 1) % flat.size()]
        for v in [Vector3(a.x, 0, a.y), Vector3(a.x, 1, a.y), Vector3(b.x, 0, b.y),
                  Vector3(b.x, 0, b.y), Vector3(a.x, 1, a.y), Vector3(b.x, 1, b.y)]:
            st.add_vertex(v)
    st.generate_normals()
    return st.commit()

# A tube along a path of [right, up, forward] points.
func _tube(path: Array, radius: float, look: Material) -> Node3D:
    if path.size() < 2:
        return null
    var whole := Node3D.new()
    for i in path.size() - 1:
        var a := Vector3(float(path[i][0]), float(path[i][1]), -float(path[i][2]))
        var b := Vector3(float(path[i + 1][0]), float(path[i + 1][1]), -float(path[i + 1][2]))
        var along := b - a
        if along.length() < 0.001:
            continue
        var piece := CylinderMesh.new()
        piece.top_radius = radius
        piece.bottom_radius = radius
        piece.height = along.length()
        piece.radial_segments = 12
        var node := MeshInstance3D.new()
        node.mesh = piece
        node.material_override = look
        node.position = (a + b) * 0.5
        # a cylinder stands along Y: turn Y onto the direction of this piece
        node.basis = Basis(Quaternion(Vector3.UP, along.normalized()))
        whole.add_child(node)
        var joint := MeshInstance3D.new()
        var bead := SphereMesh.new()
        bead.radius = radius
        bead.height = radius * 2.0
        joint.mesh = bead
        joint.material_override = look
        joint.position = b
        whole.add_child(joint)
        _made_height = maxf(_made_height, maxf(a.y, b.y))
    return whole

