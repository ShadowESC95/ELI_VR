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
var pinned := false            # the room has a place for this kind of record, and it stands there
# Records that, pinned, are written out where they stand: a belief, a memory, what ELI found for
# you, what it wrote, and what it is playing.
const WRITTEN := ["claim", "memory", "found", "written", "playing", "seen"]
const TYPED := ["DejaVu Sans Mono", "Liberation Mono", "Menlo", "Consolas", "Courier New", "monospace"]
var lines: Array = []               # what a written record says, line by line, when ELI sends it so
var prop := ""                      # a real thing the body has (assets/models/<prop>), when that is what it is
var picture := ""                   # the path ELI v3 serves a picture this record shows at
var art := {}                       # a painting's style and colours
const ART_STYLES := ["rings", "stripes", "waves", "cells", "blooms", "horizon", "rays", "drift"]
var _text_key := ""
var _pin := Transform3D.IDENTITY
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
    var real := str(form.get("prop", ""))
    var painted: Dictionary = form.get("art", {}) if typeof(form.get("art")) == TYPE_DICTIONARY else {}
    label = str(data.get("name", label))
    meaning = str(data.get("meaning", ""))
    made_by = str(data.get("made_by", ""))
    kind = str(data.get("kind", ""))
    lines = data.get("lines", []) if typeof(data.get("lines")) == TYPE_ARRAY else []
    picture = str(data.get("picture", ""))
    var pos: Array = form.get("pos", [0.0, 0.0, 0.0])
    _target = _pin.origin if pinned else EliSenses.from_protocol(pos)
    if first:
        position = _target
    var parts_key := JSON.stringify(form.get("parts", []))
    if first or parts_key != _parts_key or look != [shape, "#" + colour.to_html(false), size, glow] \
            or real != prop or painted != art:
        prop = real
        art = painted
        shape = look[0]
        colour = Color(look[1])
        size = look[2]
        glow = look[3]
        _parts = form.get("parts", [])
        _parts_key = parts_key
        _shape()
    elif pinned and kind in WRITTEN and _words_key() != _text_key:
        _shape()                    # the same record says something new: another song on the radio
    # which way its front faces: ELI's degrees round from straight ahead (0 ahead, 90 to the right);
    # a model's front is its +z, and straight ahead is -z
    _body.rotation.y = deg_to_rad(180.0 - float(form.get("turn"))) if form.get("turn") != null and not pinned else 0.0
    _name_tag.text = label
    _name_tag.modulate = colour.lightened(0.55)
    _name_tag.position = Vector3(0, eye_height() * 2.0 + 0.28, 0)

func leave() -> void:
    _leaving = true

## Stand at a place the room keeps for records of this kind (a belief pinned to the Evidence Wall).
func pin_to(spot: Transform3D) -> void:
    var moved := not pinned or not spot.is_equal_approx(_pin)
    pinned = true
    _pin = spot
    _target = spot.origin
    basis = spot.basis
    if moved and kind in WRITTEN:
        _shape()

# A belief pinned up: a sheet of paper with what ELI believes written on it, and a red pin.
func _sheet() -> void:
    _name_tag.visible = false
    _material = null
    var paper := StandardMaterial3D.new()
    paper.albedo_color = Color(0.93, 0.9, 0.82).lerp(colour, 0.25)
    paper.roughness = 0.95
    var sheet := MeshInstance3D.new()
    var quad := QuadMesh.new()
    quad.size = Vector2(0.62, 0.8)
    sheet.mesh = quad
    sheet.material_override = paper
    _body.add_child(sheet)
    _write(Color(0.08, 0.07, 0.07), 0.56, Vector3(0, 0.34, 0.002), 0.0016, 0.0013)
    var pin := MeshInstance3D.new()
    var head := SphereMesh.new()
    head.radius = 0.022
    head.height = 0.044
    pin.mesh = head
    var red := StandardMaterial3D.new()
    red.albedo_color = Color(0.85, 0.08, 0.06)
    red.emission_enabled = true
    red.emission = Color(0.6, 0.04, 0.03)
    pin.material_override = red
    pin.position = Vector3(0, 0.37, 0.02)
    _body.add_child(pin)

# What a written record says: its name, and below it what it means, in a column `width` metres wide
# whose top middle is `top`. Left-aligned text in a Label3D starts at the label's position, so the
# labels stand at the column's left edge (at the middle, the writing ran off the page).
func _write(ink: Color, width: float, top: Vector3, title_pixel: float, words_pixel: float, typed: bool = false) -> void:
    top.x -= width * 0.5
    var title := Label3D.new()
    title.text = label
    title.font_size = 34
    title.pixel_size = title_pixel
    title.modulate = ink
    title.outline_size = 0
    title.shaded = false
    title.width = width / title_pixel
    title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    title.position = top
    title.render_priority = 1
    _body.add_child(title)
    _text_key = _words_key()
    var words := Label3D.new()
    words.text = "\n".join(lines) if not lines.is_empty() else meaning
    words.font_size = 26
    words.pixel_size = words_pixel
    words.modulate = ink.lightened(0.15)
    words.outline_size = 0
    words.shaded = false
    words.width = width / words_pixel
    words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    words.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    words.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    # below the name, however many lines it wraps to, measured in the font it is drawn in
    var font: Font = title.font if title.font != null else ThemeDB.fallback_font
    var name_height := font.get_multiline_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, width / title_pixel,
                                                       title.font_size).y * title_pixel
    words.position = top - Vector3(0, maxf(0.16 * title_pixel / 0.0016, name_height + 0.012), 0)
    words.render_priority = 1
    if typed:
        var mono := SystemFont.new()
        mono.font_names = PackedStringArray(TYPED)
        words.font = mono
    _body.add_child(words)

# A memory kept in the Memory Archive: a book stood face out on the shelf, leaning back a little,
# what ELI remembers written on a plate on its cover and its page edges lit in the memory's colour.
func _cover() -> void:
    _name_tag.visible = false
    _material = null
    var leather := StandardMaterial3D.new()
    leather.albedo_color = Color(0.2, 0.12, 0.08).lerp(colour, 0.12)
    leather.roughness = 0.6
    var pages := StandardMaterial3D.new()
    pages.albedo_color = Color(0.92, 0.88, 0.78)
    pages.emission_enabled = true
    pages.emission = colour * clampf(glow, 0.0, 1.0)
    pages.emission_energy_multiplier = 1.2
    var paper := StandardMaterial3D.new()
    paper.albedo_color = Color(0.93, 0.9, 0.82)
    paper.roughness = 0.95
    var book := Node3D.new()
    book.rotation.x = -0.12
    _body.add_child(book)
    for part in [[Vector3(0.36, 0.46, 0.012), Vector3(0, 0.23, 0.024), leather],     # the front board
                 [Vector3(0.36, 0.46, 0.012), Vector3(0, 0.23, -0.024), leather],    # the back board
                 [Vector3(0.012, 0.46, 0.06), Vector3(-0.174, 0.23, 0.0), leather],  # the spine
                 [Vector3(0.34, 0.44, 0.036), Vector3(0.008, 0.23, 0.0), pages]]:    # the pages between
        var block := MeshInstance3D.new()
        var mesh := BoxMesh.new()
        mesh.size = part[0]
        block.mesh = mesh
        block.position = part[1]
        block.material_override = part[2]
        block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        book.add_child(block)
    var plate := MeshInstance3D.new()
    var quad := QuadMesh.new()
    quad.size = Vector2(0.3, 0.39)
    plate.mesh = quad
    plate.material_override = paper
    plate.position = Vector3(0.006, 0.23, 0.031)
    book.add_child(plate)
    var held := _body
    _body = book                    # the writing goes on the book, leaning with it
    _write(Color(0.1, 0.07, 0.05), 0.27, Vector3(0.006, 0.405, 0.032), 0.0011, 0.0009)
    _body = held

func _words_key() -> String:
    return "%s|%s|%s|%s" % [label, meaning, "\n".join(lines), picture]

# A picture ELI took or looked at for you, as a photograph pinned up: the picture itself once it
# has come from ELI v3 (dark until then), and under it what ELI saw in it.
func _photo() -> void:
    _name_tag.visible = false
    _material = null
    var border := StandardMaterial3D.new()
    border.albedo_color = Color(0.95, 0.94, 0.9)
    border.roughness = 0.9
    var mount := MeshInstance3D.new()
    var card := QuadMesh.new()
    card.size = Vector2(0.92, 0.8)
    mount.mesh = card
    mount.material_override = border
    _body.add_child(mount)
    var print_face := StandardMaterial3D.new()
    print_face.albedo_color = Color(0.08, 0.09, 0.1)
    print_face.roughness = 0.6
    var photo := MeshInstance3D.new()
    var face := QuadMesh.new()
    face.size = Vector2(0.84, 0.5)
    photo.mesh = face
    photo.material_override = print_face
    photo.position = Vector3(0, 0.1, 0.002)
    _body.add_child(photo)
    var caption := Label3D.new()
    caption.text = label + ("\n" + str(lines[0]) if not lines.is_empty() else "")
    caption.font_size = 26
    caption.pixel_size = 0.0011
    caption.modulate = Color(0.1, 0.09, 0.08)
    caption.outline_size = 0
    caption.shaded = false
    caption.width = 0.84 / 0.0011
    caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    caption.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    caption.position = Vector3(-0.42, -0.17, 0.003)
    caption.render_priority = 1
    _body.add_child(caption)
    if not picture.is_empty():
        EliPictures.want(picture, func(texture: Texture2D):
            if is_instance_valid(photo):
                print_face.albedo_texture = texture
                print_face.albedo_color = Color.WHITE
                var wide := float(texture.get_width()) / maxf(1.0, float(texture.get_height()))
                face.size = Vector2(minf(0.84, 0.5 * wide), minf(0.5, 0.84 / maxf(wide, 0.01))))

# A sheet pinned or clipped up: what ELI found for you, printed (`typed`), or what it wrote, with
# the sheets under it showing at the edges.
func _paper(tint: Color, held_by: String, typed: bool) -> void:
    _name_tag.visible = false
    _material = null
    var paper := StandardMaterial3D.new()
    paper.albedo_color = tint
    paper.roughness = 0.95
    var quad := QuadMesh.new()
    quad.size = Vector2(0.62, 0.8)
    var under := [] if held_by == "pin" else [Vector3(0.018, -0.014, -0.004), Vector3(-0.012, -0.026, -0.008)]
    for offset in under + [Vector3.ZERO]:
        var sheet := MeshInstance3D.new()
        sheet.mesh = quad
        sheet.material_override = paper
        sheet.position = offset
        sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        _body.add_child(sheet)
    _write(Color(0.08, 0.07, 0.07), 0.56, Vector3(0, 0.34, 0.002), 0.0014, 0.0011, typed)
    var hold := MeshInstance3D.new()
    var dark := StandardMaterial3D.new()
    if held_by == "pin":
        var head := SphereMesh.new()
        head.radius = 0.022
        head.height = 0.044
        hold.mesh = head
        dark.albedo_color = Color(0.1, 0.35, 0.8)
    else:
        var clip := BoxMesh.new()                   # a binder clip along the top edge
        clip.size = Vector3(0.12, 0.05, 0.02)
        hold.mesh = clip
        dark.albedo_color = Color(0.05, 0.05, 0.06)
        dark.metallic = 0.8
        dark.roughness = 0.35
    hold.material_override = dark
    hold.position = Vector3(0, 0.38, 0.015)
    _body.add_child(hold)

# What ELI is playing, on the radio the room keeps: the radio, a card in front naming the track,
# and a light that pulses while it plays.
func _radio() -> void:
    _name_tag.visible = false
    _material = null
    var radio := ModelCache.scene("boombox")
    if radio != null:
        _body.add_child(radio.instantiate())
    var paused := "paused" in lines
    var card := Label3D.new()
    var said := lines.filter(func(l): return l != "paused")
    card.text = "%s\n%s" % [label, "  ·  ".join(said)] if not said.is_empty() else label
    if paused:
        card.text += "\n(paused)"
    card.font_size = 40
    card.pixel_size = 0.0016
    card.outline_size = 8
    card.modulate = Color(1.0, 0.93, 0.8) if not paused else Color(0.75, 0.72, 0.68)
    card.width = 0.9 / 0.0016
    card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    card.position = Vector3(0, 0.66, 0.0)
    card.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
    _body.add_child(card)
    var light := StandardMaterial3D.new()
    light.albedo_color = Color(1.0, 0.7, 0.4)
    light.emission_enabled = true
    light.emission = Color(1.0, 0.62, 0.3)
    light.emission_energy_multiplier = 0.0 if paused else 1.4
    var dot := MeshInstance3D.new()
    var bead := SphereMesh.new()
    bead.radius = 0.012
    bead.height = 0.024
    dot.mesh = bead
    dot.material_override = light
    dot.position = Vector3(0.3, 0.42, 0.11)
    _body.add_child(dot)
    if not paused:
        _moving.append([dot, 0.0, 0.0, 0.6, light, dot.position.y, 1.4])

# A real thing the body has, at its real size times `size`. A model the body does not have is a
# plain orb, so nothing ELI placed goes missing.
func _real() -> void:
    var scene := EliProps.model(prop)
    if scene == null:
        shape = "orb"
        _shape()
        return
    _material = null
    var model := scene.instantiate() as Node3D
    model.scale = Vector3.ONE * size
    _body.add_child(model)
    _made_height = 1.0
    for entry in EliProps.catalogue():
        if entry["id"] == prop:
            _made_height = float(entry["size"][1]) * size
    _name_tag.visible = false           # a chair is a chair: its name shows when you point at it

# A painting of ELI's own, framed: its foot is the frame's lower edge, its front faces where ELI
# turned it. Set on the floor, it stands on an easel. With no art given, a style and colours of
# its own from its id and its colour.
func _painting() -> void:
    _material = null
    var wide := 1.0 * size
    var tall := 0.75 * size
    var lift := 0.0
    if _target.y < 0.3:
        lift = 0.8
        var wood := StandardMaterial3D.new()
        wood.albedo_color = Color(0.45, 0.32, 0.2)
        wood.roughness = 0.7
        for leg in [[Vector3(-0.35, 0.0, 0.12), -0.12], [Vector3(0.35, 0.0, 0.12), 0.12], [Vector3(0.0, 0.0, -0.45), 0.0]]:
            var rod := MeshInstance3D.new()
            var stick := CylinderMesh.new()
            stick.top_radius = 0.018
            stick.bottom_radius = 0.022
            stick.height = 1.75
            rod.mesh = stick
            rod.material_override = wood
            rod.position = leg[0] + Vector3(0, 0.85, 0) + (Vector3(0, 0, 0.22) if leg[0].z < 0 else Vector3.ZERO)
            rod.rotation = Vector3(0.27 if leg[0].z < 0 else -0.1, 0.0, leg[1])
            _body.add_child(rod)
        var ledge := MeshInstance3D.new()
        var shelf := BoxMesh.new()
        shelf.size = Vector3(wide + 0.1, 0.04, 0.08)
        ledge.mesh = shelf
        ledge.material_override = wood
        ledge.position = Vector3(0, lift - 0.02, 0.04)
        _body.add_child(ledge)
    var style := str(art.get("style", ""))
    var tints: Array = art.get("colours", [])
    if not style in ART_STYLES:
        style = ART_STYLES[absi(thing_id.hash()) % ART_STYLES.size()]
    if tints.size() < 2:
        tints = [colour.darkened(0.6).to_html(false), colour.to_html(false), colour.lightened(0.5).to_html(false)]
    var palette := PackedVector3Array()
    for i in 4:
        var c := Color(str(tints[mini(i, tints.size() - 1)]))
        palette.append(Vector3(c.r, c.g, c.b))
    var canvas := MeshInstance3D.new()
    var quad := QuadMesh.new()
    quad.size = Vector2(wide, tall)
    canvas.mesh = quad
    canvas.material_override = MaterialKit.shader("res://assets/shaders/painting.gdshader", {
        "style": ART_STYLES.find(style), "colours": palette, "count": mini(tints.size(), 4),
        "seed": float(absi(thing_id.hash()) % 997) * 0.1,
    })
    canvas.position = Vector3(0, lift + tall * 0.5 + 0.05 * size, 0.012)
    _body.add_child(canvas)
    var frame := StandardMaterial3D.new()
    frame.albedo_color = Color(0.32, 0.22, 0.12) if glow < 0.5 else Color(0.78, 0.6, 0.28)
    frame.metallic = 0.0 if glow < 0.5 else 0.7
    frame.roughness = 0.55
    var rim := 0.05 * size
    for side in [[Vector3(wide + rim * 2.0, rim, 0.04), Vector3(0, rim * 0.5, 0)],
                 [Vector3(wide + rim * 2.0, rim, 0.04), Vector3(0, tall + rim * 1.5, 0)],
                 [Vector3(rim, tall + rim * 2.0, 0.04), Vector3(-(wide + rim) * 0.5, tall * 0.5 + rim, 0)],
                 [Vector3(rim, tall + rim * 2.0, 0.04), Vector3((wide + rim) * 0.5, tall * 0.5 + rim, 0)]]:
        var bar := MeshInstance3D.new()
        var box := BoxMesh.new()
        box.size = side[0]
        bar.mesh = box
        bar.material_override = frame
        bar.position = side[1] + Vector3(0, lift, 0)
        _body.add_child(bar)
    _made_height = lift + tall + rim * 2.0

func eye_height() -> float:
    if shape == "prop" or shape == "painting":
        return _made_height * 0.5
    if not _parts.is_empty():
        return _made_height * 0.5
    if pinned and kind in WRITTEN:
        return 0.0
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
    if pinned and kind in WRITTEN:
        pass                        # written out where it stands, it holds still
    elif shape == "orb":
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
    _name_tag.visible = true
    if kind == "claim" and pinned:
        _sheet()
        return
    if kind == "memory" and pinned:
        _cover()
        return
    if kind == "found" and pinned:
        _paper(Color(0.96, 0.95, 0.91), "pin", true)
        return
    if kind == "written" and pinned:
        _paper(Color(0.95, 0.94, 0.9), "clip", false)
        return
    if kind == "playing" and pinned:
        _radio()
        return
    if kind == "seen" and pinned:
        _photo()
        return
    if shape == "prop" and not prop.is_empty():
        _real()
        return
    if shape == "painting":
        _painting()
        return
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

