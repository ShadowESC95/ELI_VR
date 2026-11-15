class_name MemoryCathedralRoom
extends RoomBase

# The Memory Archive: a round hall of marble open to the stars, its walls shelved floor to roof
# with books, some of them lit from within and brightening and fading. Ahead, on the shelves a hand
# reaches, stand ELI's own books (EliBook, on the shared Bookcase): its conversations, sessions,
# logs and stretches of time, oldest to the left and newest to the right along the shelf at eye
# height and on along the one below, a brass plate where each month begins; to the right, the
# stories ELI wrote from its records. Between those shelves its latest memories stand face out, what
# each remembers written on its cover. Any of them can be taken down, opened and read. Reading
# corners with lamps, a librarian's desk, catalogue cabinets and a clock keep the floor.

const BAYS := 12
const BAY_RADIUS := 14.6
const SHELF_GAP := 0.45             # between boards above the ones a hand reaches, as a library's are
const SHELF_FRONT := 0.32           # how far a board reaches into the room from the bay's face
const SHELF_DEPTH := 0.46
const MEMORY_BAYS := [8, 9, 7, 10]  # straight ahead first, then either side
const MEMORY_SLOTS := 5
const RECORD_BAYS := [7, 8, 9, 10]  # ELI's books, left to right as you face them
const STORY_BAYS := [11]            # the stories ELI wrote, on the right
const LEAN := 0.12                  # a book stood face out leans back this far, in radians

# each bay as wide as its part of the ring, so they meet with no gap between them
var bay_width := 2.0 * BAY_RADIUS * sin(PI / float(BAYS))
# the shelves a hand takes books from, for this reader (Bookcase.reachable_tops): spine-out rows of
# ELI's books, and the one below eye level where memories stand face out
var _reach_tops: Array = []
var _record_cases: Array = []       # Bookcases, in reading order: each bay's halves along a row, row by row
var _story_cases: Array = []
var _book_slots: Array = []         # where the arranged books stand, by their place in the order

func _build() -> void:
    _reach_tops = Bookcase.reachable_tops(EliBook.measure({}).y)
    var env := environment(Color(0.20, 0.22, 0.30).lerp(accent, 0.15), 0.8)
    star_sky(env, Vector3(0.0, 0.92, -0.38), 30.0, 1.6)     # the galaxy stands over the roof

    var white := MaterialKitClass.surface("marble_white", 3.0, Color(0.92, 0.92, 0.95), 0.35)
    var black := MaterialKitClass.surface("marble_black", 2.4, Color(0.75, 0.75, 0.8), 0.25)
    add(MeshKitClass.annulus(0.0, 3.0, 96), black)
    add(MeshKitClass.annulus(3.0, 9.4, 128), white)
    add(MeshKitClass.annulus(9.4, 15.0, 128), black)
    add(MeshKitClass.annulus(2.94, 3.03, 128), strip({"energy": 1.5, "wave": 0.12}), Vector3(0, 0.006, 0))
    add(MeshKitClass.annulus(9.36, 9.44, 160), strip({"energy": 1.2, "wave": 0.08, "phase": 1.6}), Vector3(0, 0.006, 0))

    _shelves()
    _columns_and_roof(white)
    _orrery()
    for degrees in [30.0, 150.0, 90.0]:
        _reading_corner(deg_to_rad(degrees), degrees == 90.0)
    _along_the_walls(white)
    _notice_board()
    _sconces()
    if motes:
        # memories that have come loose
        drift(Vector3(0, 7.0, 0), Vector3(12, 7, 12), 90, accent.lightened(0.3), 0.16, Vector3(0.05, 1, 0.03), 0.22, 1.0)
        drift(Vector3(0, 3.0, 0), Vector3(10, 3, 10), 160, Color(1.0, 0.95, 0.85), 0.025)
    lamp(Vector3(0, 7.5, 0), Color(1.0, 0.95, 0.88), 2.2, 22.0)
    lamp(Vector3(0, 2.6, -11.0), accent, 0.9, 10.0)
    lamp(Vector3(9.5, 2.6, 5.5), accent, 0.9, 10.0)
    lamp(Vector3(-9.5, 2.6, 5.5), accent, 0.9, 10.0)
    probe(Vector3(30, 20, 30), Vector3(0, 4.0, 0))

# The `i`th bay of shelving, as a place in the room: x across the bay, y up, z towards the middle.
func _bay(i: int) -> Transform3D:
    var angle := TAU * (float(i) + 0.5) / float(BAYS)
    return Transform3D(Basis(Vector3.UP, -angle - PI * 0.5), Vector3(cos(angle), 0.0, sin(angle)) * BAY_RADIUS)

func _shelves() -> void:
    var wood := MaterialKitClass.surface("planks", 1.6, Color(0.42, 0.3, 0.22), 0.9)
    var dark := MaterialKitClass.surface("planks", 1.6, Color(0.2, 0.15, 0.12), 1.0)
    var brass := MaterialKitClass.metal("brushed_metal", 0.4, Color(1.0, 0.8, 0.45), 0.45)
    var rng := RandomNumberGenerator.new()
    rng.seed = 1977
    for i in BAYS:
        var bay := Node3D.new()
        bay.transform = _bay(i)
        bay.name = "Bay_%d" % i
        add_child(bay)
        _bays[i] = bay
        box(Vector3(bay_width, 15.0, 0.12), dark, Vector3(0, 7.5, -0.14), bay)
        for x in [-bay_width * 0.5 + 0.06, 0.0, bay_width * 0.5 - 0.06]:
            box(Vector3(0.12 if x != 0.0 else 0.08, 15.0, 0.5), wood, Vector3(x, 7.5, 0.09), bay)
        box(Vector3(bay_width + 0.3, 0.45, 0.62), wood, Vector3(0, 15.0, 0.12), bay)     # the cornice
        for y in _boards():
            box(Vector3(bay_width - 0.1, 0.05, SHELF_DEPTH), wood, Vector3(0, y, SHELF_FRONT - SHELF_DEPTH * 0.5), bay)
        _books(bay, rng, i)
        if i % 2 == 0 and not i in MEMORY_BAYS and not i in STORY_BAYS:
            _ladder(bay, wood, brass, rng.randf_range(-2.0, 2.0))
    _cases()

# The bays' shelves for ELI's books, as Bookcases: each bay in two halves either side of its middle
# upright, the eye-level row across every bay first and then the row below; the stories' bay the same.
func _cases() -> void:
    _record_cases.clear()
    _story_cases.clear()
    var rows := _record_rows()
    var half := bay_width * 0.5 - 0.14
    for list in [[RECORD_BAYS, _record_cases], [STORY_BAYS, _story_cases]]:
        for top in rows:
            for b in list[0]:
                for side in [-1.0, 1.0]:
                    var case := Bookcase.new()
                    case.name = "Books_%d_%d_%s" % [b, int(top * 100.0), "l" if side < 0.0 else "r"]
                    var centre := Vector3(side * (half * 0.5 + 0.05), 0.0, SHELF_FRONT - SHELF_DEPTH * 0.5)
                    case.setup(half - 0.06, SHELF_DEPTH, [top + 0.025], _bay(b) * Transform3D(Basis.IDENTITY, centre))
                    case.position = centre
                    (_bays[b] as Node3D).add_child(case)
                    (list[1] as Array).append(case)

# The rows of ELI's books: the reachable shelves but the one memories stand on.
func _record_rows() -> Array:
    return _reach_tops.filter(func(t): return t != memory_board())

## The board ELI's memories stand on, face out: the reachable one below eye level.
func memory_board() -> float:
    return _reach_tops[1] if _reach_tops.size() > 1 else _reach_tops[0]

var _bays := {}                     # bay number -> its node

# The heights of a bay's boards, floor to roof: big books at the bottom, the shelves a hand reaches
# (for this reader: Bookcase.reachable_tops), and a library's spacing from there up.
func _boards() -> Array:
    var heights := [0.1]
    var reached := _reach_tops.duplicate()
    reached.sort()
    heights.append_array(reached)
    var y: float = reached[-1] + (reached[-1] - reached[-2] if reached.size() > 1 else SHELF_GAP)
    while y < 14.6:
        heights.append(y)
        y += SHELF_GAP
    return heights

# Every shelf of a bay filled with books, as one batch: leathers of every age, a few lit. Less
# detail means fewer, broader books, not empty shelves. The rows that keep ELI's own books, and the
# places its memories stand, are left for them.
func _books(bay: Node3D, rng: RandomNumberGenerator, index: int) -> void:
    var keeps_memories: bool = index in MEMORY_BAYS
    var keeps_books: bool = index in RECORD_BAYS or index in STORY_BAYS
    const LEATHERS := [Color(0.36, 0.08, 0.06), Color(0.24, 0.12, 0.07), Color(0.42, 0.27, 0.15), Color(0.1, 0.19, 0.13),
                       Color(0.08, 0.11, 0.22), Color(0.06, 0.05, 0.05), Color(0.62, 0.52, 0.38), Color(0.3, 0.05, 0.12)]
    var boards := _boards()
    # the bay's batch is worked out once and kept for the next time the hall is built (MeshKit):
    # thousands of books a bay, each placed by the dice. The dice are left as the working-out left
    # them, so what is thrown after (the ladders) falls as it did the first time.
    var key := ["bay of books", index, detail, boards, _record_rows(), memory_board(), bay_width]
    var had = MeshKitClass.held(key)
    if had != null:
        rng.state = had[1]
        _stand_books(bay, had[0])
        return
    var placed: Array = []          # [transform, colour, lit]
    var broad := 1.0 / clampf(detail, 0.5, 1.0)
    for k in boards.size():
        var y: float = boards[k]
        var room_above: float = (boards[k + 1] - y - 0.05) if k + 1 < boards.size() else 0.45
        for half in [-1.0, 1.0]:
            var x := (0.06 if half > 0.0 else -bay_width * 0.5 + 0.14)
            var end := (bay_width * 0.5 - 0.14 if half > 0.0 else -0.06)
            if keeps_books and y in _record_rows():
                break                                   # ELI's books stand here
            while x < end:
                var width := rng.randf_range(0.025, 0.075) * broad
                if x + width > end:
                    break
                if rng.randf() < 0.025:
                    x += rng.randf_range(0.1, 0.35)     # a gap where books are out
                    continue
                if keeps_memories and y == memory_board() and _memory_slot_near(x, width):
                    x += width                          # room kept for a memory stood face out
                    continue
                var tall := minf(rng.randf_range(0.22, 0.42) * (1.2 if k == 0 else 1.0), room_above - 0.02)
                var deep := rng.randf_range(0.16, 0.26)
                var lean := 0.0 if rng.randf() > 0.04 else rng.randf_range(-0.22, 0.22)
                var at := Vector3(x + width * 0.5, y + 0.025 + tall * 0.5, SHELF_FRONT - 0.02 - deep * 0.5)
                var xf := Transform3D(Basis(Vector3.BACK, lean).scaled(Vector3(width, tall, deep)), at)
                var leather: Color = LEATHERS[rng.randi() % LEATHERS.size()]
                placed.append([xf, leather.lightened(rng.randf_range(0.0, 0.25)).darkened(rng.randf_range(0.0, 0.3)),
                               1.0 if rng.randf() < 0.025 else 0.0])
                x += width + rng.randf_range(0.0, 0.006)
    var batch := MultiMesh.new()
    batch.transform_format = MultiMesh.TRANSFORM_3D
    batch.use_colors = true
    batch.use_custom_data = true
    batch.mesh = BoxMesh.new()
    batch.instance_count = placed.size()
    for n in placed.size():
        batch.set_instance_transform(n, placed[n][0])
        batch.set_instance_color(n, placed[n][1])
        batch.set_instance_custom_data(n, Color(placed[n][2], rng.randf() * TAU, 0.0, 0.0))
    MeshKitClass.hold(key, [batch, rng.state])
    _stand_books(bay, batch)

# A bay's batch of books, stood in it.
func _stand_books(bay: Node3D, batch: MultiMesh) -> void:
    var books := MultiMeshInstance3D.new()
    books.multimesh = batch
    books.material_override = MaterialKitClass.shader("res://assets/shaders/book_spines.gdshader",
                                                      {"tint": rgb(accent), "energy": 0.55, "pace": 0.35})
    books.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    bay.add_child(books)

# A library ladder on a brass rail, standing at `along` across the bay.
func _ladder(bay: Node3D, wood: Material, brass: Material, along: float) -> void:
    const TOP := 5.05
    rod(0.025, bay_width - 0.3, brass, Vector3(0, TOP, SHELF_FRONT + 0.1), bay).rotation.z = PI * 0.5
    var ladder := Node3D.new()
    ladder.position = Vector3(along, 0.0, SHELF_FRONT + 0.1)
    bay.add_child(ladder)
    var foot := 1.15                       # how far its feet stand out from the shelves
    var tilt := atan2(foot, TOP)
    var length := sqrt(TOP * TOP + foot * foot)
    for side in [-0.24, 0.24]:
        var rail := box(Vector3(0.045, length, 0.07), wood, Vector3(side, TOP * 0.5, foot * 0.5), ladder)
        rail.rotation.x = -tilt
    var rungs := int(TOP / 0.3)
    for r in range(1, rungs):
        var up := float(r) / float(rungs)
        rod(0.018, 0.48, wood, Vector3(0, TOP * up, foot * (1.0 - up)), ladder).rotation.z = PI * 0.5

# Two chairs drawn up to a low table, a lamp and books on it, at `angle` round the floor. The one
# behind the middle is the librarian's desk.
func _reading_corner(angle: float, desk: bool) -> void:
    var out := Vector3(cos(angle), 0.0, sin(angle))
    var centre := out * (11.2 if desk else 7.2)
    var facing := rad_to_deg(atan2(-out.x, -out.z))          # front towards the middle of the room
    var along := Vector3(-out.z, 0.0, out.x)
    var top := 1.09 if desk else 0.55
    if desk:
        prop("vintage_wooden_drawer_01", centre, facing)
        prop("WoodenChair_01", centre - out * 0.95, facing + 180.0)
        prop("book_encyclopedia_set_01", centre + along * 0.45 + Vector3(0, top, 0), facing)
        prop("binder_notebook", centre - along * 0.2 - out * 0.15 + Vector3(0, top, 0), facing + 12.0)
    else:
        prop("WoodenTable_01", centre, facing)
        prop("ArmChair_01", centre + out * 1.05, facing + 180.0)
        prop("Rockingchair_01", centre - out * 1.05, facing)
        prop("book_encyclopedia_set_01", centre - along * 0.5 + Vector3(0, top, 0), facing + 180.0)
        prop("binder_notebook", centre + along * 0.05 + Vector3(0, top, 0), facing - 20.0)
    var lamp_at := centre + along * (-0.55 if desk else 0.6) + Vector3(0, top, 0)
    prop("vintage_oil_lamp", lamp_at, facing)
    lamp(lamp_at + Vector3(0, 0.42, 0), Color(1.0, 0.72, 0.42), 1.6, 5.5)
    glow(lamp_at + Vector3(0, 0.42, 0), Color(1.0, 0.75, 0.45), 0.5, 0.7, 0.6)

# A warm lamp on the outer face of each column, so the shelves are lit where you walk to them.
func _sconces() -> void:
    var brass := MaterialKitClass.metal("brushed_metal", 0.4, Color(1.0, 0.8, 0.45), 0.45)
    for i in BAYS:
        var angle := TAU * float(i) / float(BAYS)
        var out := Vector3(cos(angle), 0.0, sin(angle))
        var at := out * 13.35 + Vector3(0, 3.1, 0)
        rod(0.035, 0.3, brass, at - out * 0.12 + Vector3(0, -0.12, 0)).rotation = Vector3(0, -angle, PI * 0.5)
        glow(at, Color(1.0, 0.76, 0.48), 0.42, 0.9, 0.7)
        lamp(at + out * 0.15, Color(1.0, 0.74, 0.46), 1.1, 6.5)

# Against the shelves, between the columns: catalogue cabinets, a cabinet, the clock and a bust.
func _along_the_walls(marble: Material) -> void:
    var along_wall := {45.0: "drawer_cabinet", 135.0: "drawer_cabinet", 75.0: "GothicCabinet_01",
                       165.0: "vintage_grandfather_clock_01", 105.0: "wooden_bookshelf_worn"}
    var depth := {"drawer_cabinet": 0.49, "GothicCabinet_01": 1.13, "vintage_grandfather_clock_01": 0.43,
                  "wooden_bookshelf_worn": 0.58}
    for degrees in along_wall:
        var model: String = along_wall[degrees]
        var a := deg_to_rad(degrees)
        var out := Vector3(cos(a), 0.0, sin(a))
        prop(model, out * (BAY_RADIUS - SHELF_FRONT - float(depth[model]) * 0.5 - 0.08), rad_to_deg(atan2(-out.x, -out.z)))
    var to_bust := Vector3(cos(deg_to_rad(15.0)), 0.0, sin(deg_to_rad(15.0)))
    var plinth := to_bust * (BAY_RADIUS - SHELF_FRONT - 0.4)
    box(Vector3(0.5, 1.1, 0.5), marble, plinth + Vector3(0, 0.55, 0))
    prop("marble_bust_01", plinth + Vector3(0, 1.1, 0), rad_to_deg(atan2(-to_bust.x, -to_bust.z)))
    spot(plinth + Vector3(0, 3.2, 0) - to_bust * 1.2, plinth + Vector3(0, 1.35, 0), Color(1.0, 0.9, 0.78), 2.0, 5.0, 26.0)

# Across a bay, where its `slot`th memory stands.
func _memory_x(slot: int) -> float:
    return (float(slot) - float(MEMORY_SLOTS - 1) * 0.5) * (bay_width - 0.6) / float(MEMORY_SLOTS)

# Whether a book at `x` this wide would stand where a memory does.
func _memory_slot_near(x: float, width: float) -> bool:
    for slot in MEMORY_SLOTS:
        if absf(x + width * 0.5 - _memory_x(slot)) < 0.22 + width * 0.5:
            return true
    return false

# By the librarian's desk, a notice board for the thoughts of this hall: the memories ELI brought to
# mind for its replies and what became of them, the ones it kept, promoted or let go, each a sheet
# the user can take down and ask about.
const NOTICE_AT := Vector3(-2.6, 0.0, 10.4)
const NOTICE_PLACES := [Vector3(-0.38, 0.95, 0.05), Vector3(0.38, 0.95, 0.05), Vector3(-0.38, 0.1, 0.05), Vector3(0.38, 0.1, 0.05),
                        Vector3(-0.38, -0.75, 0.05), Vector3(0.38, -0.75, 0.05)]

func _notice_at() -> Transform3D:
    return Transform3D(Basis(Vector3.UP, atan2(-NOTICE_AT.x, -NOTICE_AT.z)), NOTICE_AT + Vector3(0, 1.55, 0))

func _notice_board() -> void:
    var wood := MaterialKitClass.surface("planks", 1.6, Color(0.42, 0.3, 0.22), 0.9)
    var cork := MaterialKitClass.surface("planks", 1.2, Color(0.7, 0.52, 0.34), 1.0, true)
    var board := Node3D.new()
    board.transform = _notice_at()
    add_child(board)
    box(Vector3(1.6, 2.5, 0.06), cork, Vector3.ZERO, board)
    box(Vector3(1.7, 0.08, 0.1), wood, Vector3(0, 1.29, 0), board)
    box(Vector3(1.7, 0.08, 0.1), wood, Vector3(0, -1.29, 0), board)
    for x in [-0.72, 0.72]:
        rod(0.03, 2.9, wood, Vector3(x, -0.1, 0.0), board)
    var heading := Label3D.new()
    heading.text = "WHAT ELI RECALLED"
    heading.font_size = 40
    heading.pixel_size = 0.0028
    heading.modulate = Color(1.0, 0.88, 0.7)
    heading.outline_size = 6
    heading.position = Vector3(0, 1.4, 0.04)
    board.add_child(heading)
    lamp(board.transform * Vector3(0, 0.6, 1.0), Color(1.0, 0.8, 0.55), 0.7, 4.0)

# Where the `index`th of ELI's memories stands: face out on the eye-level shelf of the bays
# ahead, the nearest first; its thoughts of recall go on the notice board.
func pin_spot(kind: String, index: int) -> Variant:
    if kind == "thought":
        return _notice_at() * Transform3D(Basis.IDENTITY, NOTICE_PLACES[index]) if index >= 0 and index < NOTICE_PLACES.size() else null
    if kind == "book":
        return _book_slots[index] if index >= 0 and index < _book_slots.size() else null
    if kind != "memory" or index < 0 or index >= MEMORY_BAYS.size() * MEMORY_SLOTS:
        return null
    var place := Vector3(_memory_x(index % MEMORY_SLOTS), memory_board() + 0.025, SHELF_FRONT - 0.12)
    return _bay(MEMORY_BAYS[index / MEMORY_SLOTS]) * Transform3D(Basis(Vector3.RIGHT, -LEAN), place)

## ELI's books in the order the shelves keep them: the records by the time they are of, oldest
## first, and the stories ELI wrote after them on their own shelves, by when they were written.
## Where each stands is worked out here, for pin_spot to give.
func arrange(kind: String, records: Array) -> Array:
    if kind != "book":
        return records
    # the same books (told by what they say, as one number) on the same shelves stand as they stood:
    # putting hundreds in order is not done again for every message from ELI's world
    var said := records.hash()
    if said == _arranged_said:
        return _arranged
    # each record with the time it is of, worked out once, then put in order by it
    var told := []
    var stories := []
    for record in records:
        (stories if _is_story(record) else told).append([EliBook.when_of(record), record])
    var by_time := func(a, b): return a[0] < b[0]
    told.sort_custom(by_time)
    stories.sort_custom(by_time)
    told = told.map(func(pair): return pair[1])
    stories = stories.map(func(pair): return pair[1])
    _book_slots = Bookcase.shelve(_record_cases, told, _shelf_of) + Bookcase.shelve(_story_cases, stories, _shelf_of)
    _arranged_said = said
    _arranged = told + stories
    return _arranged

var _arranged_said := 0             # the books last put in order, as one number, and the order they were given
var _arranged: Array = []

static func _is_story(record: Dictionary) -> bool:
    return str(EliBook.book_of(record).get("of", "")) == "story"

# The group a book is shelved under: the shelf ELI v3 named for it, or the month it is of.
static func _shelf_of(record: Dictionary) -> String:
    var named := str(EliBook.book_of(record).get("shelf", "")).strip_edges()
    if not named.is_empty():
        return named
    # the month, kept by the day (here, as Reading.month reads the clock) it falls in: a shelf
    # holds many books of one day
    if _months.is_empty():
        _zone = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
    var day := floori((EliBook.when_of(record) + _zone) / 86400.0)
    if not _months.has(day):
        _months[day] = Reading.month(EliBook.when_of(record))
    return _months[day]

static var _months := {}            # local day (since 1970) -> the month a book of that day is shelved under
static var _zone := 0               # seconds this place's clock is ahead of UTC

## The shelves say what is on them: ELI's books where it keeps them, or why there are none.
func show_eli(eli: Dictionary) -> void:
    var words := ""
    if not bool(eli.get("connected", false)):
        words = EliReadout.idle_reason(eli)
    elif eli.has("can") and not "books" in eli.get("can", []):
        words = "this ELI does not keep books yet"
    var told := 0
    var stories := 0
    for record in (eli.get("state", {}) as Dictionary).get("objects", []):
        if typeof(record) == TYPE_DICTIONARY and str(record.get("kind", "")) == "book" and str(record.get("room", "")) == "memory_archive":
            if _is_story(record):
                stories += 1
            else:
                told += 1
    for pair in [[_record_cases, told], [_story_cases, stories]]:
        var cases: Array = pair[0]
        if cases.is_empty():
            continue
        if pair[1] == 0:
            Bookcase.shelve(cases, [], _shelf_of)       # none left: their plates go with them
        (cases[0] as Bookcase).show_empty(words if not words.is_empty() else ("nothing on record yet" if pair[1] == 0 else ""))

func _columns_and_roof(marble: Material) -> void:
    var column := MeshKitClass.lathe(PackedVector2Array([
        Vector2(0.0, 15.0), Vector2(0.62, 15.0), Vector2(0.62, 14.6), Vector2(0.42, 14.2), Vector2(0.4, 1.0),
        Vector2(0.52, 0.6), Vector2(0.66, 0.5), Vector2(0.66, 0.0), Vector2(0.0, 0.0),
    ]), 20)
    for i in 12:
        var angle := TAU * float(i) / 12.0
        add(column, marble, Vector3(cos(angle), 0.0, sin(angle)) * 12.6)
        # a rib from each column up to the open ring at the top
        var side := Vector3(-sin(angle), 0.0, cos(angle))
        add(MeshKitClass.beam(MeshKitClass.arc(12.6, 15.0, 3.6, 24.0, angle, 22), side, 0.4, 0.55), marble)
        add(MeshKitClass.beam(MeshKitClass.arc(12.35, 15.0, 3.6, 23.7, angle, 22), side, 0.06, 0.04),
            strip({"energy": 1.4, "wave": 0.2, "speed": 0.07, "phase": float(i) * 0.6}))
    add(MeshKitClass.lathe(PackedVector2Array([
        Vector2(3.2, 24.4), Vector2(4.0, 24.4), Vector2(4.0, 23.8), Vector2(3.2, 23.8), Vector2(3.2, 24.4),
    ]), 64), marble)
    add(MeshKitClass.lathe(PackedVector2Array([
        Vector2(12.2, 15.6), Vector2(13.1, 15.6), Vector2(13.1, 15.0), Vector2(12.2, 15.0), Vector2(12.2, 15.6),
    ]), 96), marble)
    # light falling in through the open top
    var beam := QuadMesh.new()
    beam.size = Vector2(6.5, 24.0)
    for i in 3:
        var shaft := add(beam, MaterialKitClass.shader("res://assets/shaders/light_shaft.gdshader", {
            "seed": float(i) * 2.9, "energy": 0.1, "tint": Vector3(0.8, 0.9, 1.0),
        }), Vector3(0, 12.0, 0))
        shaft.rotation.y = TAU * float(i) / 3.0
        shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _orrery() -> void:
    # rings turning inside each other, high over the middle of the floor
    var gold := MaterialKitClass.metal("brushed_metal", 0.4, Color(1.0, 0.8, 0.45), 0.5)
    var centre := Vector3(0, 9.5, 0)
    for i in 4:
        var hoop := TorusMesh.new()
        hoop.inner_radius = 1.5 + 0.75 * i
        hoop.outer_radius = hoop.inner_radius + 0.07
        hoop.rings = 96
        hoop.ring_segments = 8
        var ring := add(hoop, gold, centre)
        ring.rotation = Vector3(0.6 * i, 0.0, 0.9 * i + 0.3)
        spin(ring, Vector3(0.3 + 0.2 * i, 1.0, 0.1 * i), 0.22 - 0.04 * i)
        var bead := glow(Vector3(hoop.inner_radius + 0.03, 0, 0), accent, 0.9, 1.6, 0.9, ring)
        bead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var heart := SphereMesh.new()
    heart.radius = 0.55
    heart.height = 1.1
    add(heart, MaterialKitClass.light(accent.lightened(0.5), 2.2), centre)
    glow(centre, accent, 5.0, 0.6, 0.3)
