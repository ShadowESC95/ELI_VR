class_name EliBook
extends EliThing

# A book of ELI's records: a conversation, a session, a log, a stretch of time, a story ELI wrote
# from its records, one of its own (what it likes and does not, what it believes and thinks, how it
# looks back, what it hopes for, its diary), or a case file of what it learned. A memory of ELI's is
# a book of one page.
#
# On a shelf it stands with its title down its spine, or face out with its cover saying what it is
# and when; how it stands is the room's (the place it is pinned to faces the room one way or the
# other). The grip takes it off the shelf and opens it in the hand, turned to the eye; the trigger,
# a flick of the stick, or the other hand drawn across a page turns the page; let go, it goes back
# to its place. The page in view is what ELI is told the user is reading.
#
# Every word is ELI's record as ELI v3 sends it (a feed object of kind "book": its "book" carries
# of, title, spine, about, from, to, length, shelf, by, drawn_from and sections [{heading, when, text}];
# the shapes are ELI v3's tests/fixtures/world_feed_v2_contract.json, kept in tests/fixtures here);
# the book only lays it out and cuts it into pages that fit. A book too long for the world message
# comes without its sections, saying its length: it is read whole from ELI v3 (GET
# /v1/world/book/<id>, capability "books") when it is first opened. Its size comes from the reader: the
# page holds a narrow book's line at the size writing held in the hand is read.

## Records drawn as books.
const KINDS := ["book", "memory"]
## Characters to a line on a page: the narrowest comfortable measure typographers set.
const MEASURE := 30
## Margins round the writing on a page, in ems.
const MARGIN := 1.5
## A page's height over its width: the ISO page.
const PAGE_RATIO := 1.414
## A cover board's thickness as a share of the page width (about 3 mm on a 20 cm page).
const BOARD_OF_PAGE := 0.015
## A leaf of book paper, in metres: what a book's length adds to its spine.
const LEAF := 0.0001
## The share of a spine's width its title fills.
const SPINE_FILL := 0.7
## How far the open pages lean towards the reader from flat, in radians.
const OPEN_LEAN := 0.14
## How long a page takes to turn, in seconds.
const TURN_SECONDS := 0.35
## How far a stick is pushed to flick a page, and let back to flick the next.
const FLICK := 0.7
const FLICK_BACK := 0.3
## Lines a held page reports to ELI, each no longer than a held sheet's line (eli/world/embodiment.py).
const REPORT_LINES := 8
const REPORT_WIDTH := 160

const BOOK_PATH := "/v1/world/book/"

static var link: Node           # the EliLink, set when the app makes it: a book read whole comes through it

const LEATHER := Color(0.16, 0.1, 0.07)
const PAPER := Color(0.95, 0.92, 0.84)
const MANILA := Color(0.86, 0.74, 0.5)
const GILT := Color(0.95, 0.8, 0.45)

var book := {}                  # the record's "book", as ELI v3 sent it
var spread := 0                 # the open pages in view: 0 is the title page and the first page
var opened := false
var _pages: Array = []          # [{"heading", "lines"}], cut to fit
var _size := Vector3.ONE        # width, height, thickness of the closed book
var _page := Vector2.ONE
var _open: Node3D
var _closed: Node3D
var _text: Array[Label3D] = []  # left head, left body, left foot, right head, right body, right foot
var _leaf: Node3D
var _turning := 0.0             # seconds left of a page turning, signed by its way
var _pressed := false
var _flicked := false
var _swipes := {}               # a hand drawn across a page: manipulator -> the side it came onto
var _content_key := ""
var _when = null                # when the record is of, for a book with no span of its own
var _placed := false            # stood in its place once: from then on it is carried back there

## A record is a book here: a memory, or a book ELI v3 sent.
static func is_book(data: Dictionary) -> bool:
    return str(data.get("kind", "")) in KINDS

## A record's "book" ({} when it has none).
static func book_of(record: Dictionary) -> Dictionary:
    return record.get("book", {}) if typeof(record.get("book")) == TYPE_DICTIONARY else {}

## When a record's book is of: where its span begins (or ends), else when the record was made; 0 for never said.
static func when_of(record: Dictionary) -> float:
    var of := book_of(record)
    for key in ["from", "to"]:
        if typeof(of.get(key)) in [TYPE_FLOAT, TYPE_INT]:
            return float(of[key])
    return float(record.get("when")) if typeof(record.get("when")) in [TYPE_FLOAT, TYPE_INT] else 0.0

## A page's size for this reader: a narrow book's line at the size writing held in the hand is read.
static func page_size(eye: float = Reading.eye_height()) -> Vector2:
    var e := Reading.em(Reading.in_hand(eye))
    var width := (MEASURE * Reading.MEAN_ADVANCE + 2.0 * MARGIN) * e
    return Vector2(width, width * PAGE_RATIO)

## What a record's book holds, as sections of writing: the book's own, or a memory's words.
static func sections_of(data: Dictionary) -> Array:
    var given = (data.get("book", {}) as Dictionary).get("sections", []) if typeof(data.get("book")) == TYPE_DICTIONARY else []
    if typeof(given) == TYPE_ARRAY and not given.is_empty():
        return given.filter(func(s): return typeof(s) == TYPE_DICTIONARY)
    var said := str(data.get("meaning", "")).strip_edges()
    if typeof(data.get("lines")) == TYPE_ARRAY and not (data["lines"] as Array).is_empty():
        said = "\n".join(data["lines"])
    return [{"heading": "", "text": said}] if not said.is_empty() else []

## How big the closed book is, for a shelf to make room for it: a cover a little larger than its
## pages, and a spine as thick as its pages make it, never too thin to carry its title.
static func measure(data: Dictionary, eye: float = Reading.eye_height()) -> Vector3:
    var page := page_size(eye)
    var board := page.x * BOARD_OF_PAGE
    var chars := 0
    for section in sections_of(data):
        chars += str(section.get("text", "")).length() + str(section.get("heading", "")).length()
    if chars == 0:
        chars = int(book_of(data).get("length", 0))        # sent without its sections: as long as it says
    var per_page := float(MEASURE) * _rows_for(page, eye)
    var leaves := ceilf(float(chars) / maxf(per_page, 1.0) * 0.5) + 1.0
    var spine := Reading.em(Reading.at_arm(eye)) / SPINE_FILL
    return Vector3(page.x + board * 2.0, page.y + board * 2.0, maxf(spine, board * 2.0 + leaves * LEAF))

static func _rows_for(page: Vector2, eye: float) -> int:
    var distance := Reading.in_hand(eye)
    var e := Reading.em(distance)
    var line := Reading.line_height(Reading.printed(), distance)
    return maxi(2, int(floor((page.y - 2.0 * MARGIN * e - 2.0 * line) / line)))

# --- drawn ---------------------------------------------------------------------------------------

func refresh(data: Dictionary, first: bool = false) -> void:
    book = data.get("book", {}) if typeof(data.get("book")) == TYPE_DICTIONARY else {}
    var key := JSON.stringify([data.get("name", ""), data.get("meaning", ""), data.get("lines", []), book, data.get("when")])
    var changed := key != _content_key
    _content_key = key
    if changed:
        _fetched = []               # a book read whole before is read again once it has changed
    _when = data.get("when")
    super.refresh(data, first)
    if changed and not first and _text_key != _content_key:
        _shape()                    # the same book says something new (an unpinned one is not reshaped above)

func _words_key() -> String:
    return _content_key

## Stand at the place the room keeps for it. The book is drawn the same whichever way the place
## faces: face out or spine out is the room's.
func pin_to(spot: Transform3D, _size: Vector2 = Vector2.ZERO) -> void:
    pinned = true
    _pin = spot
    if not _held:
        _target = spot.origin
        basis = spot.basis
        if not _placed:
            position = spot.origin      # already on its shelf when you come in, not flown there
    _placed = true

## Let go of the place it had: it stands where ELI's world says.
func unpin() -> void:
    if not pinned:
        return
    pinned = false
    _pin = Transform3D.IDENTITY
    basis = Basis.IDENTITY

func title() -> String:
    var named := str(book.get("title", "")).strip_edges()
    return named if not named.is_empty() else label

func spine_title() -> String:
    var named := str(book.get("spine", "")).strip_edges()
    return named if not named.is_empty() else title()

func when_span() -> String:
    if book.has("from") or book.has("to"):
        return Reading.span(book.get("from"), book.get("to"))
    return Reading.day(_when)

func is_folder() -> bool:
    return str(book.get("of", "")) == "lesson"

func _shape() -> void:
    for child in _body.get_children():
        child.queue_free()
    lamp = null
    _moving.clear()
    _material = null
    _name_tag.visible = false
    _text.clear()
    _text_key = _words_key()
    var eye := Reading.eye_height()
    _page = page_size(eye)
    _size = measure({"book": book, "meaning": meaning, "lines": lines}, eye)
    reshape(Vector3(_size.x, _size.y, _size.z), Vector3(0, _size.y * 0.5, 0))
    _closed = _closed_book()
    _body.add_child(_closed)
    _closed.visible = not opened
    # the pages are cut and the open book drawn only when it is opened: a shelf of books costs its
    # covers and spines, not every page of every book
    _open = null
    _leaf = null
    _pages = []
    _paged = false
    if opened:
        _ensure_open()
        _open.visible = true
        spread = clampi(spread, 0, maxi(0, spreads() - 1))
        _show_spread()

var _paged := false
var _fetched: Array = []        # the sections of a book read whole from ELI v3
var _fetching := false
var _unread := false            # ELI v3 did not give it: asked again at the next opening, not before

func _ensure_pages() -> void:
    if not _paged:
        _paged = true
        _paginate()
        if _pages.is_empty() and unsent():
            _read_whole()

## Whether the book came without its sections and has to be read whole from ELI v3.
func unsent() -> bool:
    var given = book.get("sections")
    return (typeof(given) != TYPE_ARRAY or given.is_empty()) and _fetched.is_empty() and int(book.get("length", 0)) > 0

# Read the book whole from ELI v3, through the link the app made (its token and all), and lay it out
# when it comes. Until then the pages are blank; a failure leaves them blank and is tried again at
# the next opening.
func _read_whole() -> void:
    if _fetching or link == null or not is_instance_valid(link) or not link.can("books"):
        return
    _fetching = true
    var asked := _content_key
    var got = await link.fetch(BOOK_PATH + thing_id.uri_encode(), "books")
    if not is_instance_valid(self):
        return
    _fetching = false
    var answer = JSON.parse_string((got.payload as PackedByteArray).get_string_from_utf8()) if got.ok and got.payload is PackedByteArray else null
    if typeof(answer) != TYPE_DICTIONARY or typeof(answer.get("sections")) != TYPE_ARRAY or asked != _content_key:
        _unread = true              # not read: the next opening asks again
        if got.ok:
            push_warning("ELI VR: the book %s came back without its sections" % thing_id)
        return
    _fetched = (answer["sections"] as Array).filter(func(x): return typeof(x) == TYPE_DICTIONARY)
    _paginate()
    spread = clampi(spread, 0, maxi(0, spreads() - 1))
    if opened:
        _show_spread()

func _ensure_open() -> void:
    if _open == null:
        _ensure_pages()
        _open = _open_book()
        _open.visible = false
        _body.add_child(_open)

# Materials shared by every book of the same colour, so a shelf of them draws as few as it can.
static var _materials := {}

func _material_of(colour_of: Color, rough: float = 0.6, glow_by: float = 0.0) -> StandardMaterial3D:
    var key := "%s|%.2f|%.2f" % [colour_of.to_html(), rough, glow_by]
    if _materials.has(key):
        return _materials[key]
    var m := StandardMaterial3D.new()
    _materials[key] = m
    m.albedo_color = colour_of
    m.roughness = rough
    if glow_by > 0.0:
        m.emission_enabled = true
        m.emission = colour_of
        m.emission_energy_multiplier = glow_by
    return m

func _block(parent: Node3D, extent: Vector3, at: Vector3, look: Material) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = extent
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.position = at
    node.material_override = look
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(node)
    return node

## The cover's colour: leather in the record's colour, or a manila folder for a case file.
func cover_colour() -> Color:
    return MANILA if is_folder() else LEATHER.lerp(colour, 0.22)

# The closed book, standing on its foot: the cover faces +z, the spine is on its -x side.
func _closed_book() -> Node3D:
    var shut := Node3D.new()
    var w := _size.x
    var h := _size.y
    var t := _size.z
    var board := _page.x * BOARD_OF_PAGE
    var cover := _material_of(cover_colour(), 0.55 if not is_folder() else 0.9)
    var paper := _material_of(PAPER, 0.95, 0.12)
    _block(shut, Vector3(w, h, board), Vector3(0, h * 0.5, t * 0.5 - board * 0.5), cover)
    _block(shut, Vector3(w, h, board), Vector3(0, h * 0.5, -t * 0.5 + board * 0.5), cover)
    _block(shut, Vector3(board, h, t), Vector3(-w * 0.5 + board * 0.5, h * 0.5, 0), cover)
    _block(shut, Vector3(w - board * 1.5, h - board * 2.0, t - board * 2.0), Vector3(board * 0.25, h * 0.5, 0), paper)
    var at_arm := Reading.at_arm()
    var ink := Reading.ink(cover_colour(), GILT if not is_folder() else Color(0.12, 0.09, 0.06))
    # the cover: its title, what it is (for a memory, what ELI remembers), and when, each cut to the
    # cover it has
    var face_w := w - board * 4.0
    var printed := Reading.printed()
    var y := h - board * 3.0
    var foot := board * 3.0 + Reading.line_height(printed, at_arm, 0.85)
    y = _cover_lines(shut, Reading.fit(title(), at_arm, face_w, 3, printed, 1.25), 1.25, ink, Vector2(-face_w * 0.5, y), t)
    var about := str(book.get("about", "")).strip_edges()
    if about.is_empty() and kind == "memory":
        about = meaning
    var rows := int(floor((y - board - foot) / Reading.line_height(printed, at_arm, 0.85)))
    if not about.is_empty() and rows > 0:
        y = _cover_lines(shut, Reading.fit(about, at_arm, face_w, rows, printed, 0.85), 0.85, Reading.ink(cover_colour(), ink.lerp(cover_colour(), 0.15)),
                         Vector2(-face_w * 0.5, y - board), t)
    if not when_span().is_empty():
        _cover_lines(shut, [when_span()], 0.85, Reading.ink(cover_colour(), ink.lerp(cover_colour(), 0.15)), Vector2(-face_w * 0.5, foot), t)
    # the spine: its title read top to bottom, and its year at the foot
    var spine := Reading.label(_fit_spine(spine_title(), h * 0.8, t * SPINE_FILL), at_arm, ink, 0.0, Reading.printed(),
                               _spine_scale(t))
    spine.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    spine.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    spine.basis = Basis(Vector3.UP, -PI * 0.5) * Basis(Vector3.BACK, -PI * 0.5)
    spine.position = Vector3(-w * 0.5 - 0.0015, h * 0.55, 0)
    shut.add_child(spine)
    if is_folder():
        var tab := _block(shut, Vector3(w * 0.4, board * 8.0, board), Vector3(w * 0.22, h + board * 4.0, t * 0.5 - board * 0.5), cover)
        var named := Reading.label(spine_title(), at_arm, ink, w * 0.38, Reading.typed(), 0.7)
        named.position = Vector3(w * 0.04, h + board * 7.0, t * 0.5 + 0.0015)
        shut.add_child(named)
        tab.name = "Tab"
    return shut

# Lines of a cover's writing from `at` (their top left) down; where the next begin.
func _cover_lines(parent: Node3D, shown: Array, scale: float, ink: Color, at: Vector2, thickness: float) -> float:
    var at_arm := Reading.at_arm()
    var words := Reading.label("\n".join(shown), at_arm, ink, 0.0, Reading.printed(), scale)
    words.position = Vector3(at.x, at.y, thickness * 0.5 + 0.0015)
    words.name = "Cover%d" % parent.get_child_count()         # each its own name: a shared one is not kept
    parent.add_child(words)
    return at.y - Reading.line_height(Reading.printed(), at_arm, scale) * shown.size()

# The spine's title, scaled to its width and cut to its length.
func _spine_scale(thickness: float) -> float:
    var e := Reading.em(Reading.at_arm())
    return minf(1.0, thickness * SPINE_FILL / e)

func _fit_spine(text: String, length: float, across: float) -> String:
    var pixel := Reading.pixel(Reading.at_arm()) * minf(1.0, across / Reading.em(Reading.at_arm()))
    var font := Reading.printed()
    var room := length / pixel
    if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Reading.DRAWN).x <= room:
        return text
    var cut := text.length()
    while cut > 1 and font.get_string_size(text.substr(0, cut) + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, Reading.DRAWN).x > room:
        cut -= 1
    return text.substr(0, cut).strip_edges() + "…"

# The open book, its spine at the middle and its pages leaning a little towards the reader.
func _open_book() -> Node3D:
    var wide := Node3D.new()
    var paper := _material_of(PAPER, 0.95, 0.18)
    var cover := _material_of(cover_colour(), 0.6)
    var board := _page.x * BOARD_OF_PAGE
    var ink := Reading.ink(PAPER)
    var held := Reading.in_hand()
    var e := Reading.em(held)
    for side in [-1.0, 1.0]:
        var hinge := Node3D.new()
        hinge.rotation.y = side * OPEN_LEAN
        wide.add_child(hinge)
        _block(hinge, Vector3(_page.x + board, _page.y + board * 2.0, board), Vector3(side * (_page.x + board) * 0.5, 0, -board), cover)
        var sheet := _block(hinge, Vector3(_page.x, _page.y, board * 0.5), Vector3(side * _page.x * 0.5, 0, 0), paper)
        sheet.name = "Page"
        var left: float = side * _page.x * 0.5 - _page.x * 0.5 + MARGIN * e
        var top := _page.y * 0.5 - MARGIN * e
        var face := board * 0.25 + 0.001
        var head := Reading.label("", held, Reading.ink(PAPER, ink.lerp(PAPER, 0.35)), _page.x - 2.0 * MARGIN * e, Reading.printed(), 0.8)
        head.autowrap_mode = TextServer.AUTOWRAP_OFF
        head.position = Vector3(left, top, face)
        hinge.add_child(head)
        var words := Reading.label("", held, ink, 0.0, Reading.printed())
        words.position = Vector3(left, top - Reading.line_height(Reading.printed(), held) * 1.4, face)
        hinge.add_child(words)
        var foot := Reading.label("", held, Reading.ink(PAPER, ink.lerp(PAPER, 0.35)), 0.0, Reading.printed(), 0.8)
        foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        foot.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
        foot.position = Vector3(side * _page.x * 0.5, -_page.y * 0.5 + MARGIN * e * 0.6, face)
        hinge.add_child(foot)
        _text.append_array([head, words, foot])
    # the leaf that turns, hinged at the spine
    _leaf = Node3D.new()
    _leaf.visible = false
    wide.add_child(_leaf)
    var leaf := _block(_leaf, Vector3(_page.x, _page.y, board * 0.3), Vector3(_page.x * 0.5, 0, board * 0.4), paper)
    leaf.name = "Leaf"
    _block(wide, Vector3(board * 2.0, _page.y + board * 2.0, board * 2.0), Vector3(0, 0, -board * 1.5), cover)
    return wide

# --- the pages -----------------------------------------------------------------------------------

func _paginate() -> void:
    var held := Reading.in_hand()
    var e := Reading.em(held)
    var font := Reading.printed()
    var width := (_page.x - 2.0 * MARGIN * e) / Reading.pixel(held)
    var written := sections_of({"book": book, "meaning": meaning, "lines": lines}) if _fetched.is_empty() else _fetched
    _pages = Reading.paginate(written, font, Reading.DRAWN, width, _rows_for(_page, Reading.eye_height()))

## How many pages the book has, and how many openings (the title page faces the first page).
func page_count() -> int:
    _ensure_pages()
    return _pages.size()

func spreads() -> int:
    _ensure_pages()
    return int(ceil(float(_pages.size() + 1) / 2.0))

## The title page: the book's title, what it is, when, and for a story who wrote it and from what.
func _title_page() -> Dictionary:
    var out := [title().to_upper(), ""]
    for said in [str(book.get("about", "")), when_span(), str(book.get("by", ""))]:
        if not said.strip_edges().is_empty():
            out.append(said)
    var drawn = book.get("drawn_from", [])
    if typeof(drawn) == TYPE_ARRAY and not drawn.is_empty():
        out.append("")
        for source in drawn:
            out.append(str(source))
    var held := Reading.in_hand()
    var width := (_page.x - 2.0 * MARGIN * Reading.em(held)) / Reading.pixel(held)
    var wrapped := []
    for line in out:
        if line == "":
            wrapped.append("")
        else:
            wrapped.append_array(Reading.wrap_lines(line, width, Reading.measurer(Reading.printed())))
    return {"heading": "", "lines": wrapped.slice(0, _rows_for(_page, Reading.eye_height()))}

## The two pages of an opening, left then right: {} for the inside of a cover.
func spread_pages(at: int) -> Array:
    _ensure_pages()
    var left = _title_page() if at == 0 else (_pages[at * 2 - 1] if at * 2 - 1 < _pages.size() else {})
    var right = _pages[at * 2] if at * 2 < _pages.size() else {}
    return [left, right]

func _show_spread() -> void:
    if _text.size() < 6:
        return
    var pair := spread_pages(spread)
    for side in 2:
        var page: Dictionary = pair[side]
        var number := spread * 2 + side           # the title page is not numbered
        _text[side * 3].text = str(page.get("heading", "")).to_upper() if spread > 0 or side == 1 else ""
        _text[side * 3 + 1].text = "\n".join(page.get("lines", []))
        _text[side * 3 + 2].text = ("%d / %d" % [number, _pages.size()]) if not page.is_empty() and number > 0 else ""

## Turn to the next opening (`by` 1) or the one before (-1). Nothing past the last or before the first.
func turn_page(by: int) -> bool:
    var to := clampi(spread + by, 0, maxi(0, spreads() - 1))
    if to == spread:
        return false
    spread = to
    _turning = TURN_SECONDS * signf(float(by))
    if _leaf != null:
        _leaf.visible = true
        _leaf.rotation.y = 0.0 if by > 0 else -PI
    _show_spread()
    return true

func open_book() -> void:
    opened = true
    if _unread:
        _unread = false
        _paged = false              # a book ELI v3 did not give last time is asked for again
    if _closed != null:
        _ensure_open()
        _closed.visible = false
        _open.visible = true
    _show_spread()

func close_book() -> void:
    opened = false
    _turning = 0.0
    if _closed != null:
        _closed.visible = true
    if _open != null:
        _open.visible = false
        _leaf.visible = false

# --- in the hand ---------------------------------------------------------------------------------

func begin_grab() -> void:
    super.begin_grab()
    open_book()

## The grip is closed on it: the world manipulator calls this each frame with where the hand is,
## which way it points, and the stick. The book sits open in the hand, turned to the eye; a flick of
## the stick turns a page either way.
func hold(origin: Vector3, direction: Vector3, stick: Vector2, _delta: float) -> void:
    if not opened:
        open_book()
    _held = true
    var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
    var eye := camera.global_position if camera != null else origin - direction.normalized() * Reading.in_hand()
    var toward := (eye - origin)
    if toward.length() < 0.01:
        toward = -direction
    var up := Vector3.UP if absf(toward.normalized().y) < 0.98 else Vector3.FORWARD
    global_transform = Transform3D(Basis.looking_at(-toward.normalized(), up), origin + up * _page.y * 0.25)
    _target = global_position
    if not _flicked and absf(stick.x) > FLICK:
        _flicked = true
        turn_page(1 if stick.x > 0.0 else -1)
    elif _flicked and absf(stick.x) < FLICK_BACK:
        _flicked = false
    _other_hands()

## The trigger of the hand holding it, each frame: a press turns the page.
func press(down: bool) -> void:
    if down and not _pressed:
        turn_page(1)
    _pressed = down

# The other hand drawn across a page: from the right page towards the spine turns on, from the left
# page back. A hand counts while it is on the page, give or take the reach of a closed hand.
func _other_hands() -> void:
    if not is_inside_tree():
        return
    for hand in get_tree().get_nodes_in_group("world_manipulators"):
        var controller = hand.get("controller")
        if hand.get("grabbed") == self or controller == null or not controller.get_has_tracking_data():
            _swipes.erase(hand)
            continue
        swipe(hand, global_transform.affine_inverse() * (controller as Node3D).global_position)

## A hand at `local` (in the open book's own space) moving over its pages.
func swipe(hand: Object, local: Vector3) -> void:
    var on := absf(local.z) < HAND_REACH and absf(local.y) < _page.y * 0.5 and absf(local.x) < _page.x
    if not on:
        _swipes.erase(hand)
        return
    if not _swipes.has(hand):
        _swipes[hand] = 1 if local.x > _page.x * 0.25 else (-1 if local.x < -_page.x * 0.25 else 0)
        return
    var came: int = _swipes[hand]
    if came == 1 and local.x < -_page.x * 0.1:
        turn_page(1)
        _swipes[hand] = -1
    elif came == -1 and local.x > _page.x * 0.1:
        turn_page(-1)
        _swipes[hand] = 1

func end_grab() -> void:
    close_book()
    _pressed = false
    _flicked = false
    _swipes.clear()
    super.end_grab()

## The record as ELI is told of it while the user holds it: the book, and the page they are reading.
func record() -> Dictionary:
    var out := {"id": thing_id, "kind": kind, "name": title(), "lines": []}
    var said := []
    if opened:
        # the lines in view joined back into their paragraphs, then cut to what ELI is told of a line
        for page in spread_pages(spread):
            var paragraph := []
            for line in (page as Dictionary).get("lines", []) + [""]:
                if str(line).is_empty():
                    if not paragraph.is_empty():
                        said.append_array(Reading.wrap_lines(" ".join(paragraph), REPORT_WIDTH))
                    paragraph = []
                else:
                    paragraph.append(str(line))
    else:
        said = [str(book.get("about", meaning))]
    out["lines"] = said.filter(func(l): return not str(l).is_empty()).slice(0, REPORT_LINES)
    return out

func eye_height() -> float:
    return _size.y * 0.5

func _process(delta: float) -> void:
    if _turning != 0.0:
        var way := signf(_turning)
        _turning = way * maxf(0.0, absf(_turning) - delta)
        if _leaf != null:
            var done := 1.0 - absf(_turning) / TURN_SECONDS
            _leaf.rotation.y = -PI * (done if way > 0.0 else 1.0 - done)     # lifting towards the reader
            if _turning == 0.0:
                _leaf.visible = false
    # at rest in its place and grown in: nothing to move, so nothing is written to it frame by frame
    if not _held and not _leaving and _grown >= 1.0 and _flash_left <= 0.0 and position.is_equal_approx(_target) \
            and (not pinned or basis.is_equal_approx(_pin.basis)):
        return
    if not _held and pinned:
        basis = basis.slerp(_pin.basis, clampf(delta * 6.0, 0.0, 1.0)).orthonormalized()
    super._process(delta)
