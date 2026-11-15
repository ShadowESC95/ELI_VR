class_name EvidenceStudioRoom
extends RoomBase

# The Evidence Wall: a dim studio with one long wall of pinned sheets, strung together thread by
# thread, every sheet one of ELI's records and every word on it the record's own.
#
# Ahead, seven boards of sheets (portrait and landscape, as a wall of evidence is), each sheet a
# record: what ELI believes and has learned about you (with how sure it is and since when; these
# can be taken down and asked about), what it was told two ways and the question that settles it,
# how often each of its actions worked, a lesson it learned, a record its beliefs rest on, a thought
# it had, a memory it recalled, how often its own figures proved right. ELI says which records go up
# and in what order, what matters most first (ELI v3's evidence "wall"); the nearest sheets ahead
# are filled first. A record is pinned up once, however many times it arrives, and whole: it goes
# to the nearest free place whose sheet takes all of it at the size it is read at there, the sheet
# as tall (and, when it must be, as wide) as its writing makes it within its share of the board.
# A sheet with no record is blank pinned paper, and the wall says once how many records are on file. Red thread runs only between sheets that are
# about the same thing: beliefs about the same thing and their question, beliefs and the records
# they rest on, an action and the lesson learned from it.
#
# To the right, the scoreboard of what ELI's actions did (how often each worked, week by week, why
# it failed and what worked instead), a board charting how often ELI's figures proved right, and the
# projector throwing the questions ELI is waiting on you to settle. To the left, what ELI found for
# you with its sources, the pictures it saw, and the board of its thoughts here. Behind, the desk
# with the case files of what ELI learned (take one up and read it), a table of sealed exhibits
# (the records ELI's beliefs rest on, each tagged with what it supports), and a cabinet of files
# between racks of boxes.
#
# Writing is sized for where it is read from (Reading): a sheet for a reader stood at the wall,
# higher sheets larger; the scoreboard and charts for one stood back to see them whole.

const HALL := 13.6                  # the studio's wall
const WALL := 13.3                  # where boards hang on it
# The long wall: seven boards round the front of the studio, each this big, its middle this high.
const WALL_BOARDS := 7
const WALL_FIRST := -78.0           # the first board's bearing, degrees round from straight ahead
const WALL_STEP := 26.0
const WALL_BOARD := Vector2(5.6, 3.6)
const WALL_MIDDLE := 2.6
const BOARD_ORDER := [3, 2, 4, 1, 5, 0, 6]      # nearest straight ahead first
# The owner's wall: thirteen sheets to a board that size, four in ten of them landscape like a
# photograph's print, each turned a little on its pin. The number follows a board's area.
const SHEETS_PER_M2 := 13.0 / (5.6 * 3.6)
const PORTRAIT := Vector2(0.52, 0.68)
const LANDSCAPE := Vector2(0.62, 0.5)
const LANDSCAPE_SHARE := 0.4
const TILT := 0.14                  # radians a sheet may hang off true
# The other boards round the wall: bearing and the arc of wall each is given, in degrees; a board is
# as wide as its arc, less the gap to the next.
const SCORE_AT := [104.0, 22.0]
const CHART_AT := [126.0, 18.0]
const QUESTION_AT := [146.0, 16.0]
const FOUND_AT := [-104.0, 22.0]
const SEEN_AT := [-124.0, 14.0]
const THOUGHT_AT := [-142.0, 18.0]
const BOARD_GAP := 0.08             # of a board's arc left bare either side of it
# What ELI v3 hangs here at most (eli/world/shown.py: KEPT, NOTES_PER_ROOM), each on its own board.
const FOUND_PLACES := 6
const SEEN_PLACES := 4
const THOUGHT_PLACES := 6
const TAG_MEASURE := 28             # characters to a line of an exhibit's tag

var _score: InfoScreen
var _questions: InfoScreen
var _chart: Node3D
var _chart_key := ""
var _threads: MeshInstance3D
var _threads_key := ""
var _threads_drawn := 0
var _exhibits: Node3D
var _exhibits_key := ""
var _empty: Dictionary = {}         # board -> the card saying why it is bare
var _desk: Node3D
var _desk_top := 0.0
var _table: Node3D
var _table_top := 0.0
var _conflicts: Array = []          # the questions ELI waits on: [what it is about, the question, the record]
var _slots: Array = []              # the wall's sheets: {"xf", "size", "distance"}, nearest straight ahead first
var _papers: MultiMeshInstance3D    # every sheet's paper, and its pin, drawn at once
var _pins: MultiMeshInstance3D
var _sheets: Node3D                 # the writing on the sheets the room writes
var _written := {}                  # slot -> what it was last written with
var _planned_key := ""              # what the wall was last laid out for
var _placed := {}                   # slot -> the entry pinned there now
var _claim_slot := {}               # a belief's id -> its sheet's place
var _on_file: Label3D
var _filled := 0                    # how many sheets carry a record
var _claim_place: Array = []        # the arranged beliefs' places on the wall (-1 for one with none)
var _book_slots: Array = []

func _build() -> void:
    var env := environment(Color(0.26, 0.22, 0.2), 1.35)
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.01, 0.009, 0.008)

    var boards := MaterialKitClass.surface("wood_floor", 2.6, Color(0.9, 0.8, 0.7), 0.55)
    var plaster := MaterialKitClass.surface("concrete", 3.0, Color(0.34, 0.3, 0.28), 1.0)
    hall(HALL, 5.2, boards, plaster, plaster)
    add(MeshKitClass.annulus(2.94, 3.03, 128), strip({"energy": 1.3, "wave": 0.12}), Vector3(0, 0.006, 0))

    _wall_of_sheets()
    _scoreboard()
    _charts()
    _cork_board(FOUND_AT, "WHAT ELI FOUND", FOUND_PLACES)
    _cork_board(SEEN_AT, "WHAT ELI SAW", SEEN_PLACES)
    _cork_board(THOUGHT_AT, "WHAT ELI THOUGHT", THOUGHT_PLACES)
    _projector()
    _desk_of_cases()
    _exhibit_table()
    _fan()
    _files()
    if motes:
        drift(Vector3(0, 2.4, -3.0), Vector3(10, 2.4, 9), 240, Color(1.0, 0.9, 0.75), 0.028)
    lamp(Vector3(0, 4.2, 4.0), Color(1.0, 0.85, 0.7), 1.6, 16.0)
    lamp(Vector3(0, 4.2, -5.0), Color(1.0, 0.85, 0.7), 1.6, 16.0)
    probe(Vector3(27, 5.2, 27), Vector3(0, 2.6, 0), true)

# --- where things hang ---------------------------------------------------------------------------

## A board on the wall at `bearing` degrees, its middle at height `y`, as a place in the room
## (x across it, y up, z out into the room).
func _board_at(bearing: float, y: float = Reading.eye_height()) -> Transform3D:
    var a := deg_to_rad(bearing)
    return Transform3D(Basis(Vector3.UP, -a), Vector3(sin(a), 0.0, -cos(a)) * WALL + Vector3(0, y, 0))

## How wide a board given `arc` degrees of the wall is.
static func board_width(arc: float) -> float:
    return 2.0 * WALL * sin(deg_to_rad(arc) * 0.5) * (1.0 - 2.0 * BOARD_GAP)

func _cork() -> Material:
    return MaterialKitClass.surface("planks", 1.2, Color(0.75, 0.55, 0.36), 1.0, true)

# A heading over a board, read from the middle of the room (as far away as the wall is), no wider
# than the board.
func _heading(board: Node3D, words: String, top: float, width: float) -> Label3D:
    var distance := WALL
    var wide: float = Reading.measurer(Reading.typed()).call(words if not words.is_empty() else "x".repeat(24)) * Reading.pixel(distance)
    var heading := Reading.label(words, distance, Color(0.95, 0.88, 0.75), 0.0, Reading.typed(), minf(1.0, width * 0.9 / maxf(wide, 0.001)))
    heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    heading.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
    heading.outline_size = 6
    heading.position = Vector3(0, top + 0.08, 0.05)
    board.add_child(heading)
    return heading

# What a board says while it has nothing on it, from why: ELI away, this ELI not sending it yet, or
# nothing on record.
func _bare(board: Node3D, size: Vector2) -> void:
    var distance := Reading.before_board()
    var words := Reading.label("", distance, Reading.ink(Color(0.92, 0.88, 0.78)), size.x * 0.7, Reading.typed())
    words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    words.position = Vector3(-size.x * 0.35, 0, 0.07)
    var card := MeshInstance3D.new()
    var quad := QuadMesh.new()
    quad.size = Vector2(size.x * 0.75, Reading.em(distance) * 3.0)
    card.mesh = quad
    card.material_override = MaterialKit.light(Color(0.92, 0.88, 0.78), 0.5)
    card.position = Vector3(size.x * 0.35, 0, -0.003)
    words.add_child(card)
    words.visible = false
    words.name = "Bare"
    board.add_child(words)
    _empty[board] = words

func _say_bare(board: Node3D, why: String) -> void:
    var words: Label3D = _empty.get(board)
    if words == null:
        return
    words.text = why
    words.visible = not why.is_empty()

# --- the wall of sheets --------------------------------------------------------------------------

func _wall_of_sheets() -> void:
    var cork := _cork()
    var rng := RandomNumberGenerator.new()
    rng.seed = 44
    var warm := Color(1.0, 0.84, 0.62)
    var eye := Reading.eye_height()
    var tones := []
    _slots.clear()
    for b in WALL_BOARDS:
        var bearing := WALL_FIRST + WALL_STEP * float(b)
        var at := _board_at(bearing, WALL_MIDDLE)
        var board := Node3D.new()
        board.transform = at
        board.name = "Wall_%d" % b
        add_child(board)
        box(Vector3(WALL_BOARD.x, WALL_BOARD.y, 0.12), cork, Vector3.ZERO, board)
        if b == BOARD_ORDER[0]:
            _on_file = _heading(board, "", WALL_BOARD.y * 0.5, WALL_BOARD.x)
            _on_file.name = "OnFile"
        # its sheets in rows across it, each a little off its place and off true, as pinned by hand
        var count := int(round(WALL_BOARD.x * WALL_BOARD.y * SHEETS_PER_M2))
        var rows := maxi(1, int(round(sqrt(float(count) * WALL_BOARD.y / WALL_BOARD.x))))
        var pitch_y := WALL_BOARD.y / float(rows)
        var in_rows := _row_counts(count, rows)
        for r in rows:
            var in_row: int = in_rows[r]
            var pitch_x := WALL_BOARD.x / float(in_row)
            for c in in_row:
                var size := LANDSCAPE if rng.randf() < LANDSCAPE_SHARE else PORTRAIT
                var jitter := Vector2(rng.randf_range(-0.5, 0.5) * (pitch_x - size.x), rng.randf_range(-0.5, 0.5) * (pitch_y - size.y) * 0.6)
                var place := Vector3((float(c) - float(in_row - 1) * 0.5) * pitch_x + jitter.x,
                                     (float(rows - 1) * 0.5 - float(r)) * pitch_y + jitter.y, 0.07 + 0.002 * float(_slots.size() % 13))
                var tilt := rng.randf_range(-TILT, TILT)
                var xf := at * Transform3D(Basis(Vector3.BACK, tilt), place)
                # its share of the board: its row and column's, less how far off its place it was pinned
                _slots.append({"xf": xf, "size": size, "now": size, "distance": Reading.at_height(xf.origin.y, eye), "board": b, "x": absf(place.x),
                               "cell": Vector2(pitch_x - 2.0 * absf(jitter.x), pitch_y - 2.0 * absf(jitter.y)), "tilt": tilt})
                tones.append(rng.randf_range(0.9, 1.0))
        if b % 2 == 0:
            var from := at.origin * Vector3(7.2 / WALL, 0.0, 7.2 / WALL) + Vector3(0, 5.0, 0)
            spot(from, at.origin, warm, 9.0, 12.0, 38.0)
            glow(from, warm, 0.9, 1.2, 0.8)
    # nearest straight ahead first, then those nearest eye height, then nearest the board's middle
    var keyed := []
    for i in _slots.size():
        keyed.append([BOARD_ORDER.find(_slots[i]["board"]), absf((_slots[i]["xf"] as Transform3D).origin.y - eye), _slots[i]["x"], i])
    keyed.sort_custom(func(a, b): return a < b)
    var ordered := []
    var toned := []
    for k in keyed:
        ordered.append(_slots[k[3]])
        toned.append(tones[k[3]])
    _slots = ordered
    _papers = _batch(QuadMesh.new(), MaterialKit.light(Color.WHITE, 1.0))
    _papers.name = "Sheets"
    _pins = _batch(SphereMesh.new(), MaterialKit.light(Color.WHITE, 1.0))
    _pins.name = "Pins"
    for i in _slots.size():
        _slots[i]["tone"] = toned[i]
    _sheets = Node3D.new()
    _sheets.name = "Writing"
    add_child(_sheets)
    _threads = MeshInstance3D.new()
    _threads.name = "Threads"
    _threads.material_override = MaterialKitClass.light(Color(0.85, 0.1, 0.08), 1.4)
    _threads.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_threads)
    _paper_up({})

# `count` sheets over `rows` rows, as even as they go, the rows nearest the middle taking any over.
static func _row_counts(count: int, rows: int) -> Array:
    var out := []
    for r in rows:
        out.append(count / rows)
    var by_middle := range(rows)
    by_middle.sort_custom(func(a, b): return absf(float(a) - float(rows - 1) * 0.5) < absf(float(b) - float(rows - 1) * 0.5))
    for i in count % rows:
        out[by_middle[i]] += 1
    return out

# One batch of a mesh across every place on the wall, coloured place by place.
func _batch(mesh: Mesh, look: StandardMaterial3D) -> MultiMeshInstance3D:
    look.vertex_color_use_as_albedo = true
    var batch := MultiMesh.new()
    batch.transform_format = MultiMesh.TRANSFORM_3D
    batch.use_colors = true
    batch.mesh = mesh
    batch.instance_count = _slots.size()
    var node := MultiMeshInstance3D.new()
    node.multimesh = batch
    node.material_override = look
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)
    return node

## Where a sheet's pin is, in the room.
func _pin_of(slot: Dictionary) -> Vector3:
    var e := Reading.em(float(slot["distance"]))
    return (slot["xf"] as Transform3D) * Vector3(0, (slot["now"] as Vector2).y * 0.5 - e * 0.35, e * 0.4)

# The paper of every sheet, tinted a little in the colour of the record on it, red-headed pins for the
# sheets with a record; none drawn where one of ELI's beliefs hangs its own sheet. `held` is place ->
# its record's colour, or null for a belief's own.
func _paper_up(held: Dictionary) -> void:
    var paper := EvidenceSheet.PAPER
    for i in _slots.size():
        var slot: Dictionary = _slots[i]
        var xf: Transform3D = slot["xf"]
        var size: Vector2 = slot["now"]
        var gone := held.has(i) and held[i] == null
        _papers.multimesh.set_instance_transform(i, xf * Transform3D(Basis.IDENTITY.scaled(Vector3(size.x, size.y, 1.0) * (0.0001 if gone else 1.0)), Vector3.ZERO))
        var tone: Color = (paper * float(slot["tone"])).lerp(held[i], 0.12) if held.has(i) and held[i] != null else paper * float(slot["tone"])
        tone.a = 1.0
        _papers.multimesh.set_instance_color(i, tone)
        var head := Reading.em(float(slot["distance"])) * 0.9
        _pins.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (0.0001 if gone else head)), _pin_of(slot)))
        _pins.multimesh.set_instance_color(i, Color(0.85, 0.08, 0.06) if held.has(i) else Color(0.55, 0.5, 0.42))

## How many sheets the wall has, and how many carry a record now.
func sheet_count() -> int:
    return _slots.size()

func records_on_wall() -> int:
    return _filled

## What a belief is about, in words: ELI v3's relation, or the words of its name before the colon.
static func about(record: Dictionary) -> String:
    var claim = record.get("claim", {})
    if typeof(claim) == TYPE_DICTIONARY and not str(claim.get("relation", "")).is_empty():
        return str(claim["relation"]).replace("_", " ").to_lower().strip_edges()
    return str(record.get("name", "")).get_slice(":", 0).to_lower().strip_edges()

static func _disputed(record: Dictionary) -> bool:
    var claim = record.get("claim", {})
    if typeof(claim) == TYPE_DICTIONARY and (bool(claim.get("contested", false)) or str(claim.get("status", "")) == "disputed"):
        return true
    return _contested_colour(record)

# ELI v3 colours a contested belief amber (eli/world/shown.py), the one sign it gives without "claim".
static func _contested_colour(record: Dictionary) -> bool:
    var form = record.get("form", {})
    return typeof(form) == TYPE_DICTIONARY and str(form.get("colour", "")).to_lower() == "#f5b942"

static func _chance(record: Dictionary) -> float:
    var claim = record.get("claim", {})
    if typeof(claim) == TYPE_DICTIONARY and claim.get("chance") != null:
        return float(claim["chance"])
    return float(record.get("importance", 0.5)) if record.get("importance") != null else 0.5

## The beliefs in the order of their places on the wall (as the wall was last laid out, _lay), those
## with no place there last.
func arrange(kind: String, records: Array) -> Array:
    if kind == "book":
        return _lay_cases(records)
    if kind != "claim":
        return records
    if not records.is_empty() and not records.any(func(r): return _claim_slot.has(str(r.get("id", "")))):
        _lay(_once(_by_kind({}, records)))              # asked before the wall was shown ELI: the beliefs alone
    var ordered := records.duplicate()
    var place := func(r) -> int: return int(_claim_slot.get(str(r.get("id", "")), _slots.size()))
    ordered.sort_custom(func(a, b): return place.call(a) < place.call(b))
    _claim_place.clear()
    for record in ordered:
        _claim_place.append(int(_claim_slot.get(str(record.get("id", "")), -1)))
    return ordered

# The beliefs as an ELI that sends no order has them kept: those in dispute first, then by what they
# are about, the surest first within each; each group with the sheet asking which is right after it.
func _beliefs_and_questions(records: Array) -> Array:
    var groups := {}
    var disputed := {}
    for record in records:
        var topic := about(record)
        if not groups.has(topic):
            groups[topic] = []
        groups[topic].append(record)
        disputed[topic] = bool(disputed.get(topic, false)) or _disputed(record)
    var asked := {}
    for conflict in _conflicts:
        asked[conflict[0]] = conflict
    var topics := groups.keys()
    topics.sort_custom(_topic_before.bind(disputed, asked))
    var out := []
    for topic in topics:
        var group: Array = groups[topic]
        group.sort_custom(func(a, b): return _chance(a) > _chance(b))
        for record in group:
            out.append(_belief_entry(record))
        if asked.has(topic):
            out.append(_question_entry(asked[topic]))
    # questions about what ELI holds no belief for still go up
    for conflict in _conflicts:
        if not groups.has(conflict[0]):
            out.append(_question_entry(conflict))
    return out

func _belief_entry(record: Dictionary) -> Dictionary:
    # the other wordings ELI folded into this belief (its claim's "also") are not sheets of their own
    var claim = record.get("claim", {})
    var also = claim.get("also", []) if typeof(claim) == TYPE_DICTIONARY else []
    var folded := []
    for other in (also if typeof(also) == TYPE_ARRAY else []):
        if typeof(other) == TYPE_DICTIONARY and not str(other.get("id", "")).is_empty():
            folded.append(str(other["id"]))
    return {"id": str(record.get("id", "")), "belief": record, "keys": ["topic:" + about(record)] + _sources(record), "also": folded}

func _question_entry(conflict: Array) -> Dictionary:
    return {"id": str((conflict[2] as Dictionary).get("id", "")), "view": EvidenceSheet.of_conflict(conflict[2]), "keys": ["topic:" + conflict[0]]}

# Beliefs in dispute (or asked about) before the rest, then by what they are about.
static func _topic_before(a, b, disputed: Dictionary, asked: Dictionary) -> bool:
    var da := bool(disputed[a]) or asked.has(a)
    var db := bool(disputed[b]) or asked.has(b)
    return da and not db if da != db else str(a) < str(b)

# The places on the boards for what ELI found, saw and thought: as many as ELI v3 hangs, as far apart
# as a sheet or a photograph needs.
const SHEET_PITCH := Vector2(1.1, 1.05)
const PHOTO_PITCH := Vector2(1.1, 0.95)

func pin_spot(kind: String, index: int) -> Variant:
    match kind:
        "found":
            return _place_on(FOUND_AT, index, FOUND_PLACES, SHEET_PITCH)
        "seen":
            return _place_on(SEEN_AT, index, SEEN_PLACES, PHOTO_PITCH)
        "thought":
            return _place_on(THOUGHT_AT, index, THOUGHT_PLACES, SHEET_PITCH)
        "book":
            return _book_slots[index] if index >= 0 and index < _book_slots.size() else null
        "claim":
            var place := _belief_place(index)
            return _slots[place]["xf"] if place >= 0 else null       # a belief the wall has no sheet for has no place
    return null

## How big a belief's place on the wall is: the sheet it hangs as.
func pin_size(kind: String, index: int) -> Vector2:
    var place := _belief_place(index) if kind == "claim" else -1
    return _slots[place]["now"] if place >= 0 else Vector2.ZERO

func _belief_place(index: int) -> int:
    # before any belief was arranged, the beliefs' places are the wall's sheets in order
    var place: int = index if _claim_place.is_empty() else (_claim_place[index] if index >= 0 and index < _claim_place.size() else -1)
    return place if place >= 0 and place < _slots.size() else -1

# The `index`th of `count` places on a board, as many to a row as its width holds, `pitch` apart.
func _place_on(board: Array, index: int, count: int, pitch: Vector2) -> Variant:
    if index < 0 or index >= count:
        return null
    var cols := _columns_on(board, count, pitch)
    var rows := int(ceil(float(count) / float(cols)))
    var place := Vector3((float(index % cols) - float(cols - 1) * 0.5) * pitch.x,
                         (float(rows - 1) * 0.5 - float(index / cols)) * pitch.y, 0.09)
    return _board_at(board[0]) * Transform3D(Basis.IDENTITY, place)

static func _columns_on(board: Array, count: int, pitch: Vector2) -> int:
    return clampi(int(floor(board_width(board[1]) / pitch.x)), 1, count)

func _cork_board(board: Array, heading_text: String, count: int) -> void:
    var width := board_width(board[1])
    var pitch := PHOTO_PITCH if board == SEEN_AT else SHEET_PITCH
    var height := ceilf(float(count) / float(_columns_on(board, count, pitch))) * pitch.y + 0.4
    var node := Node3D.new()
    node.transform = _board_at(board[0])
    add_child(node)
    box(Vector3(width, height, 0.08), _cork(), Vector3.ZERO, node)
    _heading(node, heading_text, height * 0.5, width)
    spot(node.transform * Vector3(0, 2.2, 2.2), node.transform.origin, Color(1.0, 0.85, 0.65), 3.5, 6.0, 38.0)

## What goes up on the wall, in order, from ELI's world: as ELI says (its evidence "wall": one entry
## for one fact, what matters most first), or for an ELI that sends no order, kind by kind (_by_kind).
## Each {"id", "view", "keys"}, or {"id", "belief", "keys"} for one of ELI's beliefs, which hangs its
## own sheet; "also" the ids of the records ELI folded into it.
func _evidence(state: Dictionary, claims: Array) -> Array:
    var evidence: Dictionary = state.get("evidence", {}) if typeof(state.get("evidence")) == TYPE_DICTIONARY else {}
    if typeof(evidence.get("wall")) == TYPE_ARRAY:
        return _once(_as_sent(state, evidence["wall"], claims))
    return _once(_by_kind(state, claims))

# The wall as ELI ordered it: each entry's record found in the message by its id. An entry whose
# record did not come (a book the message had no room for) is not pinned up.
func _as_sent(state: Dictionary, wall: Array, claims: Array) -> Array:
    var evidence: Dictionary = state["evidence"]
    var objects := {}
    for record in state.get("objects", []):
        if typeof(record) == TYPE_DICTIONARY:
            objects[str(record.get("id", ""))] = record
    var rows := {}
    var actions = evidence.get("actions", {})
    for row in (actions.get("rows", []) if typeof(actions) == TYPE_DICTIONARY else []):
        if typeof(row) == TYPE_DICTIONARY:
            rows[str(row.get("id", "action_" + str(row.get("action", ""))))] = row
    for row in (evidence.get("accuracy", []) if typeof(evidence.get("accuracy")) == TYPE_ARRAY else []):
        if typeof(row) == TYPE_DICTIONARY:
            rows[str(row.get("id", "accuracy_" + str(row.get("kind", ""))))] = row
    var thoughts := {}
    for thought in (state.get("thoughts", []) if typeof(state.get("thoughts")) == TYPE_ARRAY else []):
        if typeof(thought) == TYPE_DICTIONARY:
            thoughts["thought_%d" % int(thought.get("id", 0))] = thought
    var conflicts := {}
    for conflict in _conflicts:
        conflicts[str((conflict[2] as Dictionary).get("id", ""))] = conflict
    var believed := []                      # the beliefs in ELI's order, for the exhibits' numbers
    for sent in wall:
        if typeof(sent) == TYPE_DICTIONARY and str(sent.get("kind", "")) == "claim" and objects.has(str(sent.get("ref", ""))):
            believed.append(objects[str(sent["ref"])])
    var exhibits := {}
    for exhibit in _exhibits_of(believed if not believed.is_empty() else claims):
        exhibits[str(exhibit["source"].get("id", ""))] = exhibit
    var out := []
    for sent in wall:
        if typeof(sent) != TYPE_DICTIONARY:
            continue
        var ref := str(sent.get("ref", ""))
        var entry := {}
        match str(sent.get("kind", "")):
            "claim":
                if objects.has(ref) and str(objects[ref].get("room", "")) == "evidence_wall":
                    entry = _belief_entry(objects[ref])
            "conflict":
                if conflicts.has(ref):
                    entry = _question_entry(conflicts[ref])
            "action":
                if rows.has(ref):
                    entry = _action_entry(rows[ref])
            "lesson":
                if objects.has(ref):
                    entry = _lesson_entry(objects[ref])
            "accuracy":
                if rows.has(ref):
                    entry = {"view": EvidenceSheet.of_accuracy(rows[ref]), "keys": []}
            "source":
                if exhibits.has(ref):
                    entry = _exhibit_entry(exhibits[ref])
            "thought":
                if thoughts.has(ref):
                    entry = {"view": EvidenceSheet.of_thought(thoughts[ref]), "keys": _about_keys(thoughts[ref])}
        if entry.is_empty():
            continue
        entry["id"] = ref
        entry["also"] = entry.get("also", []) + (sent.get("also", []) if typeof(sent.get("also")) == TYPE_ARRAY else [])
        out.append(entry)
    return out

func _action_entry(row: Dictionary) -> Dictionary:
    return {"id": "action_" + str(row.get("action", "")), "view": EvidenceSheet.of_action(row), "keys": ["action:" + str(row.get("action", ""))]}

func _lesson_entry(record: Dictionary) -> Dictionary:
    var applies := str(EliBook.book_of(record).get("applies_to", ""))
    return {"id": str(record.get("id", "")), "view": EvidenceSheet.of_lesson(record), "keys": ["action:" + applies] if not applies.is_empty() else []}

func _exhibit_entry(exhibit: Dictionary) -> Dictionary:
    return {"id": str(exhibit["source"].get("id", "")), "view": EvidenceSheet.of_source(exhibit["number"], exhibit["source"], exhibit["supports"]),
            "keys": ["source " + str(exhibit["source"].get("id", ""))]}

# The wall for an ELI that sends no order of its own: its beliefs with the questions about them, then
# how often its actions worked, the lessons it learned, the records its beliefs rest on, its thoughts
# from the other rooms, the memories it recalled, and how often its figures proved right.
func _by_kind(state: Dictionary, claims: Array) -> Array:
    var out := _beliefs_and_questions(claims)
    var evidence: Dictionary = state.get("evidence", {}) if typeof(state.get("evidence")) == TYPE_DICTIONARY else {}
    var actions = evidence.get("actions", {})
    for row in (actions.get("rows", []) if typeof(actions) == TYPE_DICTIONARY else []):
        if typeof(row) == TYPE_DICTIONARY:
            out.append(_action_entry(row))
    for record in state.get("objects", []):
        if typeof(record) == TYPE_DICTIONARY and str(record.get("kind", "")) == "book" and str(EliBook.book_of(record).get("of", "")) == "lesson":
            out.append(_lesson_entry(record))
    var believed := out.filter(func(e): return e.has("belief")).map(func(e): return e["belief"])
    for exhibit in _exhibits_of(believed):
        out.append(_exhibit_entry(exhibit))
    var thoughts = state.get("thoughts", [])
    var recalled := []
    for thought in (thoughts if typeof(thoughts) == TYPE_ARRAY else []):
        if typeof(thought) != TYPE_DICTIONARY or str(thought.get("room", "")) == "evidence_wall":
            continue                                    # this room's own hang on its board
        var entry := {"id": "thought_%d" % int(thought.get("id", 0)), "view": EvidenceSheet.of_thought(thought), "keys": _about_keys(thought)}
        if str(thought.get("kind", "")) == "recall":
            recalled.append(entry)
        else:
            out.append(entry)
    out.append_array(recalled)
    for row in (evidence.get("accuracy", []) if typeof(evidence.get("accuracy")) == TYPE_ARRAY else []):
        if typeof(row) == TYPE_DICTIONARY and int(row.get("n", 0)) > 0 and row.get("right") != null:
            out.append({"id": "accuracy_" + str(row.get("kind", "")), "view": EvidenceSheet.of_accuracy(row), "keys": []})
    return out

## What a sheet would say first, as a reader takes it in: its kind and its heading, without case,
## spacing or marks. Two records that read the same are one sheet.
static func reads_as(entry: Dictionary) -> String:
    var view: Dictionary = entry["view"] if entry.has("view") else EvidenceSheet.of_claim(entry["belief"])
    var said := ""
    for c in (str(view.get("kind", "")) + " " + str(view.get("heading", ""))).to_lower():
        if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") or c.unicode_at(0) > 127:
            said += c
    return said

## Each record once: the first of those with the same id, of those that read the same, and none
## that ELI already folded into another on the wall ("also").
static func _once(entries: Array) -> Array:
    var folded := {}
    for entry in entries:
        for id in entry.get("also", []):
            folded[str(id)] = true
    var seen := {}
    var out := []
    for entry in entries:
        var id := str(entry.get("id", ""))
        var said := reads_as(entry)
        if (not id.is_empty() and (seen.has("id " + id) or folded.has(id))) or seen.has("said " + said):
            continue
        seen["id " + id] = true
        seen["said " + said] = true
        out.append(entry)
    return out

# Each record's place on the wall, in order: the nearest free sheet that takes the whole of it at the
# size it is read at there (EvidenceSheet.size_for: as tall and as wide as its writing needs, within
# its share of the board); a record no free sheet takes whole goes to the nearest, at the most room
# that has. Worked out again only when what goes up changes.
func _lay(entries: Array) -> void:
    var key := JSON.stringify(entries.map(func(e): return [e.get("id", ""), e.get("view", e.get("belief"))]))
    if key == _planned_key:
        return
    _planned_key = key
    _placed.clear()
    _claim_slot.clear()
    for slot in _slots:
        slot["now"] = slot["size"]
    var free := range(_slots.size())
    for entry in entries:
        if free.is_empty():
            break
        var view: Dictionary = entry["view"] if entry.has("view") else EvidenceSheet.of_claim(entry["belief"])
        var chosen := -1
        var size := Vector2.ZERO
        for i in free:
            var slot: Dictionary = _slots[i]
            var takes := EvidenceSheet.size_for(view, slot["size"], slot["cell"], float(slot["tilt"]), float(slot["distance"]))
            if EvidenceSheet.fits(view, takes, float(slot["distance"])):
                chosen = i
                size = takes
                break
        if chosen < 0:
            chosen = free[0]
            var slot: Dictionary = _slots[chosen]
            size = EvidenceSheet.size_for(view, slot["size"], slot["cell"], float(slot["tilt"]), float(slot["distance"]))
        free.erase(chosen)
        _slots[chosen]["now"] = size
        _placed[chosen] = entry
        if entry.has("belief"):
            _claim_slot[str(entry.get("id", ""))] = chosen

# What a thought is about (ELI v3's "subject"), for the thread: the same thing, or an action by its name.
static func _about_keys(thought: Dictionary) -> Array:
    var subject := str(thought.get("subject", "")).strip_edges()
    if subject.is_empty():
        return []
    return ["subject:" + subject.to_lower(), "action:" + subject.to_upper().replace(" ", "_"), "topic:" + subject.replace("_", " ").to_lower()]

# The wall written with what goes up on it (as _lay placed it): each sheet written again only when its
# record or its size changed, the thread run between sheets about the same thing, and how many
# records are on file.
func _write_wall(evidence: Array, why: String) -> void:
    _lay(evidence)
    _filled = _placed.size()
    var held := {}
    for i in _slots.size():
        var entry: Dictionary = _placed.get(i, {})
        var view = entry.get("view")
        if entry.has("belief"):
            held[i] = null
        elif view != null:
            held[i] = view["colour"]
        var key := JSON.stringify([view, _slots[i]["now"]]) if view != null else ""
        if str(_written.get(i, "")) == key:
            continue
        _written[i] = key
        var old: Node = _sheets.get_node_or_null("Sheet_%d" % i)
        if old != null:
            _sheets.remove_child(old)
            old.queue_free()
        if view == null:
            continue                                    # blank pinned paper, or one of ELI's beliefs
        var sheet := Node3D.new()
        sheet.name = "Sheet_%d" % i
        sheet.transform = _slots[i]["xf"]
        _sheets.add_child(sheet)
        EvidenceSheet.draw(sheet, _slots[i]["now"], float(_slots[i]["distance"]), view, false)
    _paper_up(held)
    if not why.is_empty():
        _on_file.text = why
    else:
        _on_file.text = "nothing on record yet" if _filled == 0 else ("%d record%s on file" % [_filled, "" if _filled == 1 else "s"])
    # the thread: between sheets about the same thing, in the order they hang
    var pins_of := {}
    var hung := _placed.keys()
    hung.sort()
    for i in hung:
        for key_of in (_placed[i] as Dictionary).get("keys", []):
            if not pins_of.has(key_of):
                pins_of[key_of] = []
            pins_of[key_of].append(_pin_of(_slots[i]))
    var key := JSON.stringify(pins_of)
    if key == _threads_key:
        return
    _threads_key = key
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    _threads_drawn = 0
    for key_of in pins_of:
        var pins: Array = pins_of[key_of]
        for i in range(1, pins.size()):
            _threads_drawn += 1
            st.append_from(_thread(pins[i - 1], pins[i]), 0, Transform3D.IDENTITY)
    _threads.mesh = st.commit() if _threads_drawn > 0 else null

## How many threads run between the sheets now.
func threads_drawn() -> int:
    return _threads_drawn

# A thread from pin to pin, pulled a little clear of the wall and sagging between.
func _thread(from: Vector3, to: Vector3) -> ArrayMesh:
    var path := PackedVector3Array()
    var out := Vector3(from.x + to.x, 0.0, from.z + to.z).normalized() * -0.03
    for s in 9:
        var t := float(s) / 8.0
        path.append(from.lerp(to, t) + out * sin(t * PI) + Vector3(0, -0.12 * sin(t * PI) * minf(1.0, from.distance_to(to)), 0))
    var side := (to - from).cross(Vector3(from.x + to.x, 0.0, from.z + to.z).normalized())
    return MeshKitClass.beam(path, side if side.length() > 0.001 else Vector3.UP, 0.01, 0.01)

static func _sources(record: Dictionary) -> Array:
    var claim = record.get("claim", {})
    var out := []
    if typeof(claim) == TYPE_DICTIONARY and typeof(claim.get("sources")) == TYPE_ARRAY:
        for source in claim["sources"]:
            if typeof(source) == TYPE_DICTIONARY and not str(source.get("id", "")).is_empty():
                out.append("source " + str(source["id"]))
    return out

# --- what ELI's actions did: the scoreboard ------------------------------------------------------

func _scoreboard() -> void:
    var width := board_width(SCORE_AT[1])
    var size := Vector2(width, width * 0.56)
    _score = InfoScreen.make(size, "What ELI's actions did", Color(0.93, 0.92, 0.86), InfoScreen.columns_for(width))
    _score.transform = _board_at(SCORE_AT[0], Reading.eye_height() + size.y * 0.2)
    add_child(_score)
    _frame(_score, size)
    _score.show_idle("ELI is not connected")

## The scoreboard's lines: every action ELI ran lately, the ones that failed most first (ELI v3's
## order), each with how often it worked, its weeks as a row of bars and how far that moved, then
## why it failed and what worked instead.
static func score_lines(evidence: Dictionary, columns: int) -> Array:
    var actions = evidence.get("actions", {})
    var rows = actions.get("rows", []) if typeof(actions) == TYPE_DICTIONARY else []
    var lines := []
    if typeof(rows) != TYPE_ARRAY:
        return lines
    var name_w := 4
    for row in rows:
        if typeof(row) == TYPE_DICTIONARY:
            name_w = maxi(name_w, str(row.get("name", "")).length())
    name_w = mini(name_w, columns / 3)
    for row in rows:
        if typeof(row) != TYPE_DICTIONARY:
            continue
        var n := int(row.get("n", 0))
        var ok := int(row.get("ok", 0))
        var rate := float(ok) / float(n) if n > 0 else 0.0
        var colour := EliReadout.GOOD if ok * 2 > n else EliReadout.TROUBLE
        var name := str(row.get("name", str(row.get("action", "")).replace("_", " ").to_lower()))
        var weeks := _weeks(row.get("weeks", []))
        var line := "%s %3d%% %d of %d" % [name.substr(0, name_w).rpad(name_w), int(round(rate * 100.0)), ok, n]
        if not weeks[0].is_empty():
            line += "  " + weeks[0] + ("  " + weeks[1] if not weeks[1].is_empty() else "")
        lines.append([line, colour])
        var why := []
        for cause in row.get("causes", []):
            if typeof(cause) == TYPE_DICTIONARY and not str(cause.get("words", "")).is_empty():
                why.append(str(cause["words"]) + (" (%d)" % int(cause.get("n", 0)) if int(cause.get("n", 0)) > 1 else ""))
        var detail := ""
        if not why.is_empty():
            detail = "failed: " + ", ".join(why.slice(0, 2))
        var instead = row.get("instead", [])
        if typeof(instead) == TYPE_ARRAY and not instead.is_empty() and typeof(instead[0]) == TYPE_DICTIONARY:
            var other: Dictionary = instead[0]
            detail += ("; " if not detail.is_empty() else "") + "%s worked instead %d×" % [str(other.get("name", "")), int(other.get("n", 0))]
        for chunk in EliReadout._wrap(detail, columns - 2):
            lines.append(["  " + chunk, EliReadout.PALE])
    return lines

## A run of weeks as bars, one a week, as tall as the share that worked (a dot for a week with no
## runs), and how far the share moved from the first week with runs to the last.
static func _weeks(weeks) -> Array:
    const BARS := "▁▂▃▄▅▆▇█"
    if typeof(weeks) != TYPE_ARRAY or weeks.is_empty():
        return ["", ""]
    var drawn := ""
    var rates := []
    for week in weeks:
        var n := int((week as Dictionary).get("n", 0)) if typeof(week) == TYPE_DICTIONARY else 0
        if n <= 0:
            drawn += "·"
            continue
        var rate := float((week as Dictionary).get("ok", 0)) / float(n)
        rates.append(rate)
        drawn += BARS[clampi(int(floor(rate * float(BARS.length()))), 0, BARS.length() - 1)]
    var moved := ""
    if rates.size() >= 2:
        var a := int(round(float(rates[0]) * 100.0))
        var b := int(round(float(rates[-1]) * 100.0))
        moved = "%s %d%%→%d%%" % ["↑" if b > a else ("↓" if b < a else "="), a, b]
    return [drawn, moved]

# --- how often ELI's figures proved right: the charts --------------------------------------------

func _charts() -> void:
    var width := board_width(CHART_AT[1])
    var size := Vector2(width, width * 0.7)
    _chart = Node3D.new()
    _chart.name = "Charts"
    _chart.transform = _board_at(CHART_AT[0], Reading.eye_height() + size.y * 0.15)
    add_child(_chart)
    var white := Color(0.93, 0.93, 0.9)
    var face := MeshInstance3D.new()
    var quad := QuadMesh.new()
    quad.size = size
    face.mesh = quad
    face.material_override = MaterialKitClass.light(white, 0.8)
    _chart.add_child(face)
    _frame(_chart, size)
    _heading(_chart, "HOW OFTEN ELI WAS RIGHT", size.y * 0.5, size.x)
    _bare(_chart, size)
    _chart.set_meta("size", size)

## The charts: a row for each kind of figure ELI gives (ELI v3's words for it), a bar as long as the
## share that proved right with that share and how many were settled, how far its figures were off,
## and its weeks as columns. Drawn again only when the figures change.
func _draw_charts(accuracy: Array) -> void:
    var key := JSON.stringify(accuracy)
    if key == _chart_key:
        return
    _chart_key = key
    for child in _chart.get_children():
        if child.name.begins_with("Row"):
            child.queue_free()
    var size: Vector2 = _chart.get_meta("size")
    var distance := Reading.stand_back(size.x)
    var e := Reading.em(distance)
    var font := Reading.typed()
    var line := Reading.line_height(font, distance)
    var ink := Reading.ink(Color(0.93, 0.93, 0.9))
    var rows := accuracy.filter(func(r): return typeof(r) == TYPE_DICTIONARY and int(r.get("n", 0)) > 0 and r.get("right") != null)
    var pitch := line * 2.6
    rows = rows.slice(0, maxi(1, int(floor((size.y - 2.0 * e) / pitch))))
    var bars := MultiMesh.new()
    bars.transform_format = MultiMesh.TRANSFORM_3D
    bars.use_colors = true
    bars.mesh = BoxMesh.new()
    var placed := []                        # [transform, colour]
    var label_w := size.x * 0.34
    var bar_w := size.x * 0.36
    var week_w := size.x - label_w - bar_w - 3.0 * e
    var y := size.y * 0.5 - e
    for r in rows.size():
        var row: Dictionary = rows[r]
        var node := Node3D.new()
        node.name = "Row%d" % r
        _chart.add_child(node)
        var said := Reading.fit(str(row.get("words", row.get("kind", ""))), distance, label_w, 2, font)
        var named := Reading.label("\n".join(said), distance, ink, 0.0, font)
        named.position = Vector3(-size.x * 0.5 + e, y, 0.003)
        node.add_child(named)
        var right := clampf(float(row["right"]) if row.get("right") != null else 0.0, 0.0, 1.0)
        var bar_x := -size.x * 0.5 + e + label_w + e * 0.5
        var bar_h := line * 0.8
        placed.append([Transform3D(Basis.IDENTITY.scaled(Vector3(bar_w, bar_h, 0.004)), Vector3(bar_x + bar_w * 0.5, y - bar_h * 0.6, 0.002)), ink.lerp(Color(0.93, 0.93, 0.9), 0.8)])
        placed.append([Transform3D(Basis.IDENTITY.scaled(Vector3(maxf(0.001, bar_w * right), bar_h, 0.006)), Vector3(bar_x + bar_w * right * 0.5, y - bar_h * 0.6, 0.003)),
                       EliReadout.GOOD.darkened(0.45) if right >= 0.5 else EliReadout.TROUBLE.darkened(0.35)])
        var figures := "%d%% of %d" % [int(round(right * 100.0)), int(row.get("n", 0))]
        if row.get("ece") != null:
            figures += " · off by %.2f" % float(row["ece"])
        var shown := Reading.label(Reading.fit(figures, distance, bar_w + week_w, 1, font, 0.8)[0], distance, ink, 0.0, font, 0.8)
        shown.position = Vector3(bar_x, y - bar_h * 1.3, 0.003)
        node.add_child(shown)
        # its weeks, oldest first, each a column as tall as its share right
        var weeks: Array = row.get("weeks", []) if typeof(row.get("weeks")) == TYPE_ARRAY else []
        if not weeks.is_empty():
            var col := week_w / float(weeks.size())
            for w in weeks.size():
                var week = weeks[w]
                if typeof(week) != TYPE_DICTIONARY or int(week.get("n", 0)) <= 0 or week.get("right") == null:
                    continue
                var share := clampf(float(week.get("right", 0.0)), 0.0, 1.0)
                var tall := maxf(0.002, pitch * 0.7 * share)
                placed.append([Transform3D(Basis.IDENTITY.scaled(Vector3(col * 0.7, tall, 0.006)),
                               Vector3(bar_x + bar_w + e + col * (float(w) + 0.5), y - pitch * 0.75 + tall * 0.5, 0.003)), ink.lerp(Color.WHITE, 0.3)])
        y -= pitch
    bars.instance_count = placed.size()
    for i in placed.size():
        bars.set_instance_transform(i, placed[i][0])
        bars.set_instance_color(i, placed[i][1])
    var drawn := MultiMeshInstance3D.new()
    drawn.name = "RowBars"
    drawn.multimesh = bars
    var flat := StandardMaterial3D.new()
    flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    flat.vertex_color_use_as_albedo = true
    drawn.material_override = flat
    _chart.add_child(drawn)

# A dark frame round a screen or a board.
func _frame(node: Node3D, size: Vector2) -> void:
    var wood := MaterialKitClass.surface("planks", 1.6, Color(0.24, 0.17, 0.12), 0.9)
    var rim := 0.06
    for bar in [[Vector3(size.x + rim * 2.0, rim, 0.06), Vector3(0, size.y * 0.5 + rim * 0.5, -0.02)],
                [Vector3(size.x + rim * 2.0, rim, 0.06), Vector3(0, -size.y * 0.5 - rim * 0.5, -0.02)],
                [Vector3(rim, size.y, 0.06), Vector3(-size.x * 0.5 - rim * 0.5, 0, -0.02)],
                [Vector3(rim, size.y, 0.06), Vector3(size.x * 0.5 + rim * 0.5, 0, -0.02)]]:
        box(bar[0], wood, bar[1], node)

# --- the questions, on the projector -------------------------------------------------------------

func _projector() -> void:
    var a := deg_to_rad(QUESTION_AT[0])
    var width := board_width(QUESTION_AT[1])
    var size := Vector2(width, width * 0.7)
    _questions = InfoScreen.make(size, "Open questions", Color(1.0, 0.93, 0.8), InfoScreen.columns_for(width))
    _questions.transform = _board_at(QUESTION_AT[0], Reading.eye_height() + size.y * 0.25)
    add_child(_questions)
    _questions.show_idle("ELI is not connected")
    # the cart a little way out from the screen, the projector on it throwing the picture back
    var out := Vector3(sin(a), 0.0, -cos(a))
    var at := out * (WALL - Reading.stand_back(width))
    prop("tool_cart", at, rad_to_deg(atan2(out.x, out.z)) + 90.0)
    prop("filmstrip_projector_8mm", at + Vector3(0, 0.96, 0), rad_to_deg(atan2(out.x, out.z)))
    var lens := at + Vector3(0, 1.2, 0)
    glow(lens, Color(1.0, 0.95, 0.85), 0.4, 2.0, 1.0)
    spot(lens, _questions.position, Color(1.0, 0.95, 0.85), 3.0, 14.0, 20.0)

# --- what ELI learned: the case files on the desk ------------------------------------------------

func _desk_of_cases() -> void:
    _desk = Node3D.new()
    _desk.name = "Desk"
    _desk.position = Vector3(-7.4, 0, 5.2)
    _desk.rotation.y = deg_to_rad(50.0)
    add_child(_desk)
    var desk := prop("metal_office_desk", Vector3.ZERO, 0.0, 1.0, _desk)
    _desk_top = EliModels.bounds(desk).end.y if desk != null else 0.0
    var top := _desk_top
    prop("magnifying_glass_01", Vector3(0.55, top, 0.25), 30.0, 1.0, _desk)
    prop("desk_lamp_arm_01", Vector3(0.75, top, -0.25), -140.0, 1.0, _desk)
    prop("SchoolChair_01", Vector3(0.1, 0, 0.7), 180.0, 1.0, _desk)
    var warm := Color(1.0, 0.8, 0.5)
    glow(Vector3(0.6, top + 0.45, 0.0), warm, 0.4, 1.6, 0.9, _desk)
    spot(Vector3(0.6, top + 0.5, 0.0), Vector3(-0.2, top, 0.1), warm, 5.0, 4.0, 60.0, _desk)
    _bare(_desk, Vector2(1.2, 0.4))
    (_empty[_desk] as Label3D).position = Vector3(-0.42, top + 0.32, 0.1)

## The case files of what ELI learned (ELI v3's books of kind "lesson"), the newest on top of the
## pile on the desk, each turned a little from the one under it so its tab shows.
func _lay_cases(records: Array) -> Array:
    var ordered := records.filter(func(r): return str(EliBook.book_of(r).get("of", "")) == "lesson")
    ordered.sort_custom(func(a, b): return EliBook.when_of(a) < EliBook.when_of(b))
    _book_slots.clear()
    var height := _desk_top
    for i in ordered.size():
        var size := EliBook.measure(ordered[i])
        var turn := deg_to_rad(-14.0 + 28.0 * fmod(float(i) * 0.618, 1.0))
        var at := Vector3(-0.35 + 0.12 * fmod(float(i) * 0.37, 1.0), height + size.z * 0.5, 0.12 + size.y * 0.5)
        # lying on its back, its foot towards the chair, its tab away
        _book_slots.append(_desk.transform * Transform3D(Basis(Vector3.UP, turn) * Basis(Vector3.RIGHT, -PI * 0.5), at))
        height += size.z
    return ordered + records.filter(func(r): return not r in ordered)

# --- what ELI's beliefs rest on: the sealed exhibits ---------------------------------------------

func _exhibit_table() -> void:
    _table = Node3D.new()
    _table.name = "Exhibits"
    var a := deg_to_rad(150.0)
    var at := Vector3(sin(a), 0.0, -cos(a)) * (WALL - 3.5)
    _table.position = at
    _table.rotation.y = atan2(-at.x, -at.z)
    add_child(_table)
    var table := prop("WoodenTable_01", Vector3.ZERO, 0.0, 1.0, _table)
    _table_top = EliModels.bounds(table).end.y if table != null else 0.0
    _exhibits = Node3D.new()
    _exhibits.name = "Bags"
    _table.add_child(_exhibits)
    var warm := Color(1.0, 0.86, 0.66)
    spot(Vector3(0, _table_top + 2.2, 0.6), Vector3(0, _table_top, 0), warm, 5.0, 4.0, 55.0, _table)
    _bare(_table, Vector2(1.4, 0.4))
    (_empty[_table] as Label3D).position = Vector3(-0.49, _table_top + 0.3, 0.0)

## Every record ELI's beliefs here rest on (ELI v3's claim "sources"), once each, numbered in the
## order the wall's beliefs cite them: {"number", "source", "supports": the beliefs' names}.
static func _exhibits_of(claims: Array) -> Array:
    var seen := {}
    var exhibits := []
    for record in claims:
        var claim = record.get("claim", {})
        if typeof(claim) != TYPE_DICTIONARY or typeof(claim.get("sources")) != TYPE_ARRAY:
            continue
        for source in claim["sources"]:
            if typeof(source) != TYPE_DICTIONARY:
                continue
            var id := str(source.get("id", source.get("text", "")))
            if id.is_empty():
                continue
            if not seen.has(id):
                seen[id] = exhibits.size()
                exhibits.append({"number": exhibits.size() + 1, "source": source, "supports": []})
            exhibits[seen[id]]["supports"].append(str(record.get("name", "")))
    return exhibits

## The exhibits on the table, each sealed in a bag with a tag saying what it is, when, where it came
## from and what it supports. As many as the table holds, the rest counted.
func _lay_exhibits(claims: Array) -> void:
    var exhibits := _exhibits_of(claims)
    var key := JSON.stringify(exhibits)
    if key == _exhibits_key:
        return
    _exhibits_key = key
    for child in _exhibits.get_children():
        child.queue_free()
    var distance := Reading.at_arm()
    var e := Reading.em(distance)
    var tag := Vector2((TAG_MEASURE * Reading.MONO_ADVANCE + 2.0) * e, Reading.line_height(Reading.typed(), distance) * 8.0 + e * 1.5)
    var bag := tag + Vector2(e * 2.0, e * 4.0)
    var across := maxi(1, int(floor(1.7 / (bag.x + e))))
    var deep := maxi(1, int(floor(0.6 / (bag.y + e))))
    var fits := across * deep
    var shown := exhibits.slice(0, fits if exhibits.size() <= fits else fits - 1)
    for i in shown.size():
        var place := Vector3((float(i % across) - float(across - 1) * 0.5) * (bag.x + e), _table_top + 0.004,
                             (float(i / across) - float(deep - 1) * 0.5) * (bag.y + e))
        _exhibit(i + 1, shown[i], place, bag, tag, distance)
    if exhibits.size() > shown.size():
        var more := Reading.label("+%d" % (exhibits.size() - shown.size()), distance, Reading.ink(Color(0.6, 0.45, 0.3)), 0.0, Reading.typed(), 1.4)
        more.rotation.x = -PI * 0.5
        more.position = Vector3((float(across - 1) * 0.5) * (bag.x + e) - bag.x * 0.3, _table_top + 0.006, (float(deep - 1) * 0.5) * (bag.y + e))
        _exhibits.add_child(more)

func _exhibit(number: int, exhibit: Dictionary, at: Vector3, bag: Vector2, tag: Vector2, distance: float) -> void:
    var node := Node3D.new()
    node.position = at
    node.rotation.x = -PI * 0.5                 # lying on the table, read from its near side
    _exhibits.add_child(node)
    var plastic := MeshInstance3D.new()
    var quad := QuadMesh.new()
    quad.size = bag
    plastic.mesh = quad
    plastic.material_override = MaterialKitClass.glass(Color(0.85, 0.9, 0.95), 0.25)
    plastic.position.z = 0.004
    node.add_child(plastic)
    var e := Reading.em(distance)
    var seal := MeshInstance3D.new()
    var band := QuadMesh.new()
    band.size = Vector2(bag.x, e * 1.2)
    seal.mesh = band
    seal.material_override = MaterialKitClass.light(Color(0.78, 0.08, 0.06), 0.9)
    seal.position = Vector3(0, bag.y * 0.5 - e * 0.6, 0.005)
    node.add_child(seal)
    var card := MeshInstance3D.new()
    var face := QuadMesh.new()
    face.size = tag
    card.mesh = face
    var paper := Color(0.96, 0.94, 0.86)
    card.material_override = MaterialKitClass.light(paper, 0.8)
    card.position = Vector3(0, -e, 0.002)
    node.add_child(card)
    var source: Dictionary = exhibit["source"]
    var font := Reading.typed()
    var width := tag.x - e * 1.2
    var lines := ["EXHIBIT %d" % number]
    lines.append_array(Reading.fit(str(source.get("text", "")), distance, width, 3, font))
    var when := " · ".join([Reading.day(source.get("when")), str(source.get("origin", ""))].filter(func(t): return not str(t).is_empty()))
    if not when.is_empty():
        lines.append_array(Reading.fit(when, distance, width, 1, font))
    lines.append_array(Reading.fit("supports: " + "; ".join(exhibit["supports"]), distance, width, 3, font))
    var words := Reading.label("\n".join(lines), distance, Reading.ink(paper), 0.0, font)
    words.position = Vector3(-tag.x * 0.5 + e * 0.6, tag.y * 0.5 - e * 1.4, 0.003)
    node.add_child(words)

# --- the rest of the studio ----------------------------------------------------------------------

func _fan() -> void:
    var fan := prop("ceiling_fan", Vector3(0, 4.66, 0))
    if fan != null:
        spin(fan, Vector3.UP, 1.1)

# A cabinet of files against the back wall, its own lamp over it, and lamps on the walls either
# side so the back of the studio is a place too.
func _files() -> void:
    prop("vintage_cabinet_01", Vector3(0, 0, WALL - 0.7), 180.0)
    var warm := Color(1.0, 0.82, 0.6)
    spot(Vector3(0, 4.4, 9.0), Vector3(0, 1.2, WALL - 0.7), warm, 6.0, 9.0, 40.0)
    glow(Vector3(0, 4.4, 9.0), warm, 0.6, 1.2, 0.8)
    for degrees in [157.0, 203.0]:
        var a := deg_to_rad(degrees)
        var on_wall := Vector3(sin(a), 0.0, -cos(a)) * (HALL - 0.15)
        prop("industrial_wall_lamp", on_wall + Vector3(0, 2.3, 0), rad_to_deg(atan2(-on_wall.x, -on_wall.z)))
        var bulb := on_wall * 0.97 + Vector3(0, 2.25, 0)
        lamp(bulb, warm, 2.6, 11.0)
        glow(bulb, warm, 0.35, 1.4, 0.9)
    # the boxes of what has been gathered, on racks either side of the cabinet
    for degrees in [168.0, 192.0]:
        var a := deg_to_rad(degrees)
        var at := Vector3(sin(a), 0.0, -cos(a)) * (WALL - 0.4)
        var facing := rad_to_deg(atan2(-at.x, -at.z))
        prop("worn_metal_rack", at, facing)
        var beside := at.rotated(Vector3.UP, deg_to_rad(-6.0 if degrees < 180.0 else 6.0)) * 0.93
        prop("plastic_crate_01", beside, facing + 14.0)
        prop("plastic_crate_02", beside + Vector3(0, 0.41, 0), facing - 9.0)

# --- what the room shows of ELI ------------------------------------------------------------------

func show_eli(eli: Dictionary) -> void:
    if _questions == null:
        return
    var connected := bool(eli.get("connected", false))
    var state: Dictionary = eli.get("state", {}) if typeof(eli.get("state")) == TYPE_DICTIONARY else {}
    var can: Array = eli.get("can", []) if typeof(eli.get("can")) == TYPE_ARRAY else []
    var claims := []
    _conflicts.clear()
    var lessons := 0
    for record in state.get("objects", []):
        if typeof(record) != TYPE_DICTIONARY:
            continue
        match str(record.get("kind", "")):
            "conflict":
                # what it is about: ELI v3's relation, or the words of its name
                var topic := str(record.get("relation", "")).replace("_", " ").to_lower().strip_edges()
                if topic.is_empty():
                    topic = str(record.get("name", "")).trim_suffix("?").to_lower().strip_edges()
                _conflicts.append([topic, str(record.get("meaning", "")), record])
            "claim":
                if str(record.get("room", "")) == "evidence_wall":
                    claims.append(record)
            "book":
                if str(record.get("room", "")) == "evidence_wall" and str(EliBook.book_of(record).get("of", "")) == "lesson":
                    lessons += 1
    var away := "" if connected else EliReadout.idle_reason(eli)
    var unsent := func(capability: String) -> String:
        return away if not away.is_empty() else ("this ELI does not send that yet" if eli.has("can") and not capability in can else "")
    # the wall of sheets and its threads
    _write_wall(_evidence(state, claims) if connected else [], away)
    var ordered := arrange("claim", claims).filter(func(c): return _claim_slot.has(str(c.get("id", ""))))
    # the scoreboard and the charts
    var evidence: Dictionary = state.get("evidence", {}) if typeof(state.get("evidence")) == TYPE_DICTIONARY else {}
    var why: String = unsent.call("evidence")
    if not why.is_empty():
        _score.show_idle(why)
    else:
        var scored := score_lines(evidence, _score.columns)
        if scored.is_empty():
            _score.show_idle("nothing on record yet")
        else:
            _score.show_lines(scored.slice(0, _score.rows()))
    var accuracy: Array = evidence.get("accuracy", []) if typeof(evidence.get("accuracy")) == TYPE_ARRAY else []
    _draw_charts(accuracy if why.is_empty() else [])
    _say_bare(_chart, why if not why.is_empty() else ("nothing on record yet" if accuracy.filter(func(r): return typeof(r) == TYPE_DICTIONARY and int(r.get("n", 0)) > 0 and r.get("right") != null).is_empty() else ""))
    # the case files and the exhibits
    var books_why: String = unsent.call("books")
    _say_bare(_desk, books_why if not books_why.is_empty() else ("nothing on record yet" if lessons == 0 else ""))
    _lay_exhibits(ordered if connected else [])
    var sourced := ordered.any(func(c): return not _sources(c).is_empty())
    _say_bare(_table, away if not away.is_empty() else ("nothing on record yet" if not sourced else ""))
    # the projector: the questions, then the thoughts that belong in this room
    if not connected:
        _questions.show_idle(EliReadout.idle_reason(eli))
        return
    var lines := []
    for conflict in _conflicts:
        for chunk in EliReadout._wrap(str(conflict[1]), _questions.columns):
            lines.append(chunk)
        lines.append("")
    var thought := EliReadout.thought_lines(eli, Color(1.0, 0.93, 0.8), [], "evidence_wall", _questions.columns - 6)
    if not thought.is_empty():
        if not lines.is_empty():
            lines.append("")
        lines.append(["WHAT ELI THOUGHT", Color(1.0, 0.93, 0.8).darkened(0.2)])
        lines.append_array(thought)
    if lines.is_empty():
        _questions.show_idle("nothing in dispute")
    else:
        _questions.show_lines(lines.slice(0, _questions.rows()))
