class_name Reading
extends RefCounted

# How the writing in the rooms is made to be read, in one place for every room: big enough for
# where it is read from, in a font that suits it, with enough between ink and paper, wrapped to its
# column and cut into pages that fit. And where a person's eye is and how far their hand reaches,
# so a room puts what is read where it can be read and what is taken where a hand can take it.
#
# No label picks a size of its own. Text is sized by the angle its capitals fill at the eye from
# where it is read: held in the hand, at arm's length, or stood back from a board until the whole
# board is in view. The distances come from the person (their eye height, from the headset when
# there is one) and from the board's own width; the angles are the method's constants below.

## The angle a capital letter fills at the eye, in radians, to be read without effort in a headset:
## about one degree. A headset shows some 11 to 20 pixels to a degree, so a capital is then 11 to 20
## pixels tall; guidance for print read at a distance asks the same.
const ARC := 0.0175
## A capital letter's height as a share of its font's em (about 0.7 in the fonts used here).
const CAP := 0.7
## How wide a field of view a board is read across without turning the head (about 50 degrees):
## a reader stands back from a board until it fits in it.
const FIELD := 0.87
## Pixels of a glyph's em in the texture Label3D draws it from. Only how crisp it is: its size in
## the room is pixel_size times this.
const DRAWN := 48
## A standing adult's eye height (the median, about 1.6 m), for when no headset says where the eye is.
const STANDING_EYE := 1.6
## Eye height, shoulder height and arm's reach (shoulder to the middle of the closed hand) as shares
## of stature: adult body proportions from anthropometric tables.
const EYE_OF_STATURE := 0.936
const SHOULDER_OF_STATURE := 0.818
const REACH_OF_STATURE := 0.44
## How far from the eye a book is held to be read, as a share of arm's reach (elbows bent: about
## 40 to 45 cm for an adult).
const HELD_OF_REACH := 0.6
## Where a card on a board is read from, in arm's reaches: a step back from arm's length.
const BOARD_OF_REACH := 2.0
## Writing further than this many times its reading distance fills a third of the angle it is read
## at: it cannot be read there, so it is not drawn (a shelf of spines from across a hall).
const READ_FADE := 3.0
## Ink against its paper: WCAG's enhanced contrast, 7 to 1.
const CONTRAST := 7.0
## Glyph advance as a share of the em: a monospaced glyph, and the mean of a proportional face.
const MONO_ADVANCE := 0.6
const MEAN_ADVANCE := 0.5

const TYPED_FACES := ["DejaVu Sans Mono", "Liberation Mono", "Menlo", "Consolas", "Courier New", "monospace"]
const PRINTED_FACES := ["DejaVu Serif", "Liberation Serif", "Georgia", "Cambria", "Times New Roman", "serif"]
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

static var _typed: SystemFont
static var _printed: SystemFont

# --- the person --------------------------------------------------------------------------------

## The eye's height above the floor: the headset's (or the flat window's camera) when there is one,
## a standing adult's when there is none yet.
static func eye_height() -> float:
    var tree := Engine.get_main_loop() as SceneTree
    var camera: Camera3D = tree.root.get_camera_3d() if tree != null and tree.root != null else null
    if camera == null or not camera.is_inside_tree():
        return STANDING_EYE
    var y := camera.global_position.y
    return y if y > STANDING_EYE * 0.5 else STANDING_EYE      # not tracking yet: the head is not on the floor

static func stature(eye: float = eye_height()) -> float:
    return eye / EYE_OF_STATURE

static func shoulder(eye: float = eye_height()) -> float:
    return stature(eye) * SHOULDER_OF_STATURE

## How far a hand reaches from the shoulder.
static func reach(eye: float = eye_height()) -> float:
    return stature(eye) * REACH_OF_STATURE

## From the eye to a book held open to read.
static func in_hand(eye: float = eye_height()) -> float:
    return reach(eye) * HELD_OF_REACH

## From the eye to a shelf or a desk a hand can take from.
static func at_arm(eye: float = eye_height()) -> float:
    return reach(eye)

## Where a card pinned on a board is read: a step back from arm's length, as a reader stands at a
## board to read one card of many.
static func before_board(eye: float = eye_height()) -> float:
    return reach(eye) * BOARD_OF_REACH

## From the eye of a reader stood at a board to writing on it `height` metres off the floor.
static func at_height(height: float, eye: float = eye_height()) -> float:
    return Vector2(before_board(eye), height - eye).length()

## How far back a reader stands from a board `width` metres wide to see it whole.
static func stand_back(width: float) -> float:
    return width / (2.0 * tan(FIELD * 0.5))

## The highest and lowest a hand takes from without stretching or kneeling: the shoulder plus half a
## reach, and the knee (a quarter of stature).
static func top_shelf(eye: float = eye_height()) -> float:
    return shoulder(eye) + reach(eye) * 0.5

static func low_shelf(eye: float = eye_height()) -> float:
    return stature(eye) * 0.25

# --- the writing -------------------------------------------------------------------------------

## The em, in metres, of writing read from `distance` metres.
static func em(distance: float) -> float:
    return maxf(distance, 0.05) * tan(ARC) / CAP

## Label3D's pixel_size for writing read from `distance`.
static func pixel(distance: float) -> float:
    return em(distance) / float(DRAWN)

## How many monospaced characters a line `width` metres wide holds when read from `distance`.
static func columns(width: float, distance: float) -> int:
    return maxi(8, int(floor(width / (em(distance) * MONO_ADVANCE))))

## Type for screens and printed records, every glyph as wide as the next.
static func typed() -> Font:
    if _typed == null:
        _typed = SystemFont.new()
        _typed.font_names = PackedStringArray(TYPED_FACES)
    return _typed

## Type for books.
static func printed() -> Font:
    if _printed == null:
        _printed = SystemFont.new()
        _printed.font_names = PackedStringArray(PRINTED_FACES)
    return _printed

## A line of writing for the room, read from `distance`: `ink` on whatever it stands on, left-aligned
## from its position, wrapped to `width` metres when one is given. Unshaded, so the room's lamps
## never take its contrast away.
static func label(text: String, distance: float, ink: Color, width: float = 0.0, font: Font = null, scale: float = 1.0) -> Label3D:
    var words := Label3D.new()
    words.text = text
    words.font = font if font != null else printed()
    words.font_size = DRAWN
    words.pixel_size = pixel(distance) * scale
    words.modulate = ink
    words.outline_size = 0
    words.shaded = false
    words.double_sided = false
    words.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    words.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    words.render_priority = 1
    words.visibility_range_end = maxf(distance, 0.05) * READ_FADE
    if width > 0.0:
        words.width = width / words.pixel_size
        words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return words

## How tall a line of writing set in `font` and read from `distance` stands, in metres.
static func line_height(font: Font, distance: float, scale: float = 1.0) -> float:
    return font.get_height(DRAWN) * pixel(distance) * scale

## How wide a text is in `font`, in the pixels a label set in it measures its width in.
static func measurer(font: Font) -> Callable:
    return func(s: String) -> float: return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, DRAWN).x

## A text as every line it takes in a column `width` metres wide read from `distance`: all of it,
## however many lines that is (a sheet that takes a record whole asks how tall that makes it).
static func wrapped(text: String, distance: float, width: float, font: Font = null, scale: float = 1.0) -> Array:
    font = font if font != null else printed()
    var room := width / (pixel(distance) * scale)
    var measure := measurer(font)
    var lines := []
    for paragraph in text.split("\n", false):
        lines.append_array(wrap_lines(paragraph, room, measure))
    return lines

## A text as the lines it takes in a column `width` metres wide read from `distance`, no more than
## `rows` of them: the last cut short with "…" when there is more.
static func fit(text: String, distance: float, width: float, rows: int, font: Font = null, scale: float = 1.0) -> Array:
    font = font if font != null else printed()
    var lines := wrapped(text, distance, width, font, scale)
    if lines.size() <= rows:
        return lines
    var room := width / (pixel(distance) * scale)
    var measure := measurer(font)
    lines = lines.slice(0, maxi(rows, 1))
    var last: String = lines[-1]
    while not last.is_empty() and float(measure.call(last + "…")) > room:
        last = last.substr(0, last.length() - 1)
    lines[-1] = last.strip_edges() + "…"
    return lines

## A text's lines no wider than `width`: by characters, or measured by `measure` (a text -> width
## in the same units, such as pixels of a font). A word longer than a whole line is broken.
static func wrap_lines(text: String, width: float, measure: Callable = Callable()) -> Array:
    var size := func(s: String) -> float: return measure.call(s) if measure.is_valid() else float(s.length())
    var out := []
    var line := ""
    for word in text.split(" ", false):
        while size.call(word) > width and word.length() > 1:
            var cut := word.length() - 1
            while cut > 1 and size.call(word.substr(0, cut)) > width:
                cut -= 1
            if not line.is_empty():
                out.append(line)
                line = ""
            out.append(word.substr(0, cut))
            word = word.substr(cut)
        var longer := (line + " " + word).strip_edges()
        if size.call(longer) > width and not line.is_empty():
            out.append(line)
            line = word
        else:
            line = longer
    if not line.is_empty():
        out.append(line)
    return out

## Sections of writing ({"heading", "text"}; paragraphs split by new lines) cut into pages of `rows`
## lines no wider than `width` pixels of `font` at `font_size`. Each page is {"heading": the section
## it is in, "lines": [...]}; a section's heading opens it, and a paragraph never starts a page with
## the space between paragraphs.
static func paginate(sections: Array, font: Font, font_size: int, width: float, rows: int) -> Array:
    var measure := func(s: String) -> float: return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
    var pages := []
    var page := {"heading": "", "lines": []}
    rows = maxi(rows, 2)
    for section in sections:
        if typeof(section) != TYPE_DICTIONARY:
            continue
        var heading := " ".join(str(section.get("heading", "")).split(" ", false))
        var lines := []
        if not heading.is_empty():
            for chunk in wrap_lines(heading.to_upper(), width, measure):
                lines.append(chunk)
        var paragraphs := str(section.get("text", "")).split("\n", false)
        for p in paragraphs.size():
            var said := " ".join(paragraphs[p].split(" ", false))
            if said.is_empty():
                continue
            if not lines.is_empty():
                lines.append("")
            lines.append_array(wrap_lines(said, width, measure))
        if lines.is_empty():
            continue
        # a new section starts on a fresh line after a gap, or on a new page when it would leave its
        # heading alone at the foot of this one
        if not (page["lines"] as Array).is_empty():
            if (page["lines"] as Array).size() + 3 > rows:
                pages.append(page)
                page = {"heading": heading, "lines": []}
            else:
                page["lines"].append("")
        if (page["lines"] as Array).is_empty():
            page["heading"] = heading
        for line in lines:
            if (page["lines"] as Array).size() >= rows:
                pages.append(page)
                page = {"heading": heading, "lines": []}
                if line == "":
                    continue
            page["lines"].append(line)
    if not (page["lines"] as Array).is_empty():
        pages.append(page)
    return pages

# --- ink and paper -----------------------------------------------------------------------------

static func _luminance(c: Color) -> float:
    var lin := func(v: float) -> float: return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
    return 0.2126 * lin.call(c.r) + 0.7152 * lin.call(c.g) + 0.0722 * lin.call(c.b)

## The contrast ratio of two colours (WCAG): 1 for the same, 21 for black on white.
static func contrast(a: Color, b: Color) -> float:
    var la := _luminance(a)
    var lb := _luminance(b)
    return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)

## Ink for writing on `paper` in the hue of `hue`: darkened (or lightened, on dark paper) until it
## stands out from the paper by CONTRAST.
static func ink(paper: Color, hue: Color = Color(0.1, 0.08, 0.07)) -> Color:
    var dark := _luminance(paper) > 0.18
    var colour := hue
    for i in 40:
        if contrast(colour, paper) >= CONTRAST:
            return colour
        colour = colour.darkened(0.12) if dark else colour.lightened(0.12)
    return Color.BLACK if dark else Color.WHITE

# --- days --------------------------------------------------------------------------------------

## A day as it reads on a cover or a card: "2 Nov 2026"; "" for no time.
static func day(ts) -> String:
    if typeof(ts) != TYPE_FLOAT and typeof(ts) != TYPE_INT or float(ts) <= 0.0:
        return ""
    var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
    var t := Time.get_datetime_dict_from_unix_time(int(ts) + bias)
    return "%d %s %d" % [t.day, MONTHS[int(t.month) - 1], t.year]

## A month as it reads on a shelf: "Nov 2026".
static func month(ts) -> String:
    if typeof(ts) != TYPE_FLOAT and typeof(ts) != TYPE_INT or float(ts) <= 0.0:
        return ""
    var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
    var t := Time.get_datetime_dict_from_unix_time(int(ts) + bias)
    return "%s %d" % [MONTHS[int(t.month) - 1], t.year]

## The days a record covers: "2 Nov 2026", "2 – 9 Nov 2026", "28 Oct – 3 Nov 2026".
static func span(from, to) -> String:
    var a := day(from)
    var b := day(to)
    if b.is_empty() or a == b:
        return a
    if a.is_empty():
        return b
    var pa := a.split(" ")
    var pb := b.split(" ")
    if pa[2] == pb[2] and pa[1] == pb[1]:
        return "%s – %s" % [pa[0], b]
    if pa[2] == pb[2]:
        return "%s %s – %s" % [pa[0], pa[1], b]
    return "%s – %s" % [a, b]
