class_name Bookcase
extends Node3D

# Shelves for ELI's books (EliBook), the same wherever books are kept: the bays of the Memory
# Archive, the bookcase in ELI's own room. The room says which books go here and in what order
# (RoomBase.arrange); the shelves stand them up spine out, left to right and shelf by shelf, each
# as thick as its pages make it, with a gap and a brass plate where a new group begins (a month, a
# kind of book; the plate's words are the books' own). With no books, a card on the shelf says so.
#
# Its space: x across the front, y up from the floor, z out of the front. The shelves are the ones a
# hand takes from without stretching or kneeling, eye level first (Reading), unless the room gives
# its own (the Archive's bays have theirs).

## Between two books on a shelf, as a share of a spine.
const SPACING := 0.08
## How far a book stands back from a shelf's front edge, as a share of its width.
const SET_BACK := 0.06

var width := 1.0
var depth := 0.3
var tops: Array = []                    # heights of the shelves that hold books, in reading order
var to_room := Transform3D.IDENTITY     # from the case's space to the room's
var _plates: Node3D
var _empty: Label3D
var _key := ""

func setup(case_width: float, case_depth: float, shelf_tops: Array, room_transform: Transform3D) -> void:
    width = case_width
    depth = case_depth
    tops = shelf_tops
    to_room = room_transform
    _plates = Node3D.new()
    _plates.name = "Plates"
    add_child(_plates)

## The shelves a hand takes books from, for books `book_height` tall: from the one at eye level down
## to the lowest a hand reaches without kneeling, then up to the highest it reaches without
## stretching. Heights of the shelves' tops, in the order they are read.
static func reachable_tops(book_height: float, eye: float = Reading.eye_height()) -> Array:
    var pitch := book_height * 1.25
    var at_eye := eye - book_height * 0.5            # spines at eye height
    var out := []
    var y := at_eye
    while y >= Reading.low_shelf(eye):
        out.append(y)
        y -= pitch
    y = at_eye + pitch
    while y + book_height <= Reading.top_shelf(eye) + book_height * 0.5:
        out.append(y)
        y += pitch
    return out

## A bookcase of its own to stand on the floor: sides, top, back and the shelves themselves.
func build_case(wood: Material, book_height: float) -> void:
    var highest := 0.0
    var lowest := INF
    for top in tops:
        highest = maxf(highest, float(top))
        lowest = minf(lowest, float(top))
    var height := highest + book_height * 1.25
    var board := depth * 0.08
    for x in [-width * 0.5 - board * 0.5, width * 0.5 + board * 0.5]:
        _box(Vector3(board, height, depth), Vector3(x, height * 0.5, 0), wood)
    _box(Vector3(width + board * 2.0, board, depth), Vector3(0, height + board * 0.5, 0), wood)
    _box(Vector3(width, height, board * 0.5), Vector3(0, height * 0.5, -depth * 0.5 + board * 0.25), wood)
    _box(Vector3(width, lowest - board * 0.5, depth), Vector3(0, (lowest - board * 0.5) * 0.5, 0), wood)
    for top in tops:
        _box(Vector3(width, board, depth), Vector3(0, float(top) - board * 0.5, 0), wood)

func _box(extent: Vector3, at: Vector3, look: Material) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = extent
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.material_override = look
    node.position = at
    add_child(node)
    return node

## Stand `books` (records, in order) across `cases` in turn, shelf by shelf: each book's place in the
## room, or null when the shelves are full. `group_of` gives a book's group (a new group starts after
## a gap, under a plate with the group's words; "" for none).
static func shelve(cases: Array, books: Array, group_of: Callable, eye: float = Reading.eye_height()) -> Array:
    var out := []
    var key := JSON.stringify(books.map(func(b): return [b.get("id"), group_of.call(b), EliBook.measure(b, eye)]))
    var c := 0
    var shelf := 0
    var cursor := 0.0
    var last_group = null
    var plates := []                     # [case, shelf top, x, words]
    for book in books:
        var size := EliBook.measure(book, eye)
        var group := str(group_of.call(book))
        var placed := false
        while c < cases.size() and not placed:
            var case: Bookcase = cases[c]
            if shelf >= case.tops.size():
                c += 1
                shelf = 0
                cursor = 0.0
                continue
            var gap := size.z * SPACING
            var start := cursor + (size.z if last_group != null and group != last_group and cursor > 0.0 else 0.0)
            if start + size.z > case.width or size.x > case.depth * 1.6:
                shelf += 1
                cursor = 0.0
                continue
            var top: float = case.tops[shelf]
            var foot := Vector3(-case.width * 0.5 + start + size.z * 0.5, top, case.depth * 0.5 - size.x * (0.5 + SET_BACK))
            out.append(case.to_room * Transform3D(Basis(Vector3.UP, PI * 0.5), foot))
            if group != last_group and not group.is_empty():
                plates.append([case, top, -case.width * 0.5 + start, group])
            last_group = group
            cursor = start + size.z + gap
            placed = true
        if not placed:
            out.append(null)
    # the plates, drawn again only when what is on the shelves changes
    for case in cases:
        if (case as Bookcase)._key != key:
            (case as Bookcase)._clear_plates()
    for plate in plates:
        if (plate[0] as Bookcase)._key != key:
            (plate[0] as Bookcase)._plate(float(plate[1]), float(plate[2]), str(plate[3]))
    for case in cases:
        (case as Bookcase)._key = key
    return out

## What the shelves say while no books stand on them, where they would stand ("" says nothing):
## why there are none, as the room reads it from ELI's world.
func show_empty(words: String) -> void:
    if words.is_empty():
        if _empty != null:
            _empty.visible = false
        return
    if _empty == null:
        var distance := Reading.at_arm()
        _empty = Reading.label("", distance, Reading.ink(Color(0.92, 0.88, 0.78)), width * 0.8, Reading.typed())
        _empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _empty.name = "Empty"
        var card := MeshInstance3D.new()
        var quad := QuadMesh.new()
        quad.size = Vector2(width * 0.86, Reading.em(distance) * 4.0)
        card.mesh = quad
        card.material_override = MaterialKit.light(Color(0.92, 0.88, 0.78), 0.55)
        card.position = Vector3(0, -Reading.em(distance) * 1.6, -0.002)
        _empty.add_child(card)
        add_child(_empty)
    var top: float = tops[0] if not tops.is_empty() else Reading.eye_height()
    _empty.text = words
    _empty.position = Vector3(-width * 0.4, top + Reading.em(Reading.at_arm()) * 3.0, depth * 0.5)
    _empty.visible = true

func _clear_plates() -> void:
    for child in _plates.get_children():
        child.queue_free()

# A brass plate on a shelf's front edge, under the first book of a group, with the group's words.
func _plate(top: float, x: float, words: String) -> void:
    var distance := Reading.at_arm()
    var e := Reading.em(distance) * 0.8
    var brass := Color(0.78, 0.6, 0.3)
    var shown := Reading.fit(words, distance, width * 0.45, 1, Reading.typed(), 0.8)
    var text_w: float = Reading.measurer(Reading.typed()).call(shown[0]) * Reading.pixel(distance) * 0.8
    var plate := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(text_w + e * 1.2, e * 1.5, 0.004)
    plate.mesh = box
    var metal := StandardMaterial3D.new()
    metal.albedo_color = brass
    metal.metallic = 0.8
    metal.roughness = 0.35
    metal.emission_enabled = true           # the writing on it reads in a dim hall
    metal.emission = brass
    metal.emission_energy_multiplier = 0.25
    plate.material_override = metal
    plate.position = Vector3(x + box.size.x * 0.5, top - e * 0.9, depth * 0.5 + 0.004)
    _plates.add_child(plate)
    var engraved := Reading.label(shown[0], distance, Reading.ink(brass), 0.0, Reading.typed(), 0.8)
    engraved.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    engraved.position = Vector3(x + e * 0.6, top - e * 0.9, depth * 0.5 + 0.0065)
    _plates.add_child(engraved)
