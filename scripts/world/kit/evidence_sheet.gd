class_name EvidenceSheet
extends RefCounted

# A sheet pinned on the Evidence Wall, written with one of ELI's records: a belief or a fact it
# learned, a disputed one, how often an action worked, a lesson, a record a belief rests on, a
# thought, a memory it recalled, how often its figures proved right. Every sheet reads the same way:
# its kind on a strip in the kind's colour, a heading, the figure or the chance (with a bar filled to
# it), its date, and what else the record says, each at the size it is read at from where the sheet
# hangs. The words are the record's; the sheet adds only the few words of its own in CHROME.
#
# A sheet takes its record whole: no line is cut short. laid() says how tall a sheet a record needs
# at the size it is read at, size_for() gives the sheet that takes it within the room its place on
# the board has, and draw() writes every line of it.
#
# view(): {"kind": the strip's word, "colour": the kind's colour, "heading", "figure", "fill" (0..1, or
# -1 for no bar), "date", "details": [lines], "stamp": a word stamped across it ("" for none),
# "keys": what it is related to, for the threads between sheets}.

## Every word a sheet writes that is not the record's own.
const CHROME := ["belief", "disputed", "contested", "action", "lesson", "exhibit", "accuracy", "chance", "since", "learned",
                 "rests", "on", "record", "records", "worked", "of", "failed", "instead", "proved", "right", "off", "by",
                 "supports", "file", "nothing", "yet", "eli", "is", "not", "connected", "because"]

# The wall's paper, as the owner's wall had it: a warm off-white, drawn unshaded so the room's lamps
# never take the writing's contrast away.
const PAPER := Color(0.774, 0.738, 0.648)

## A belief (ELI v3's claim object): its fact, its chance, since when and what it rests on.
static func of_claim(record: Dictionary) -> Dictionary:
    var claim: Dictionary = record.get("claim", {}) if typeof(record.get("claim")) == TYPE_DICTIONARY else {}
    var fact := str(record.get("name", ""))
    if not str(claim.get("value", "")).is_empty():
        fact = "%s: %s" % [str(claim.get("relation", "")).replace("_", " "), str(claim.get("value"))]
    var chance := float(claim["chance"]) if claim.get("chance") != null else (float(record.get("importance")) if record.get("importance") != null else -1.0)
    var disputed := bool(claim.get("contested", false)) or str(claim.get("status", "")) == "disputed"
    var details := []
    var date := ""
    if claim.has("since") or claim.has("learned"):
        date = " · ".join([_dated("since", claim.get("since")), _dated("learned", claim.get("learned"))].filter(func(t): return not t.is_empty()))
        if not str(claim.get("basis", "")).is_empty():
            details.append(str(claim["basis"]))
        var sources = claim.get("sources", [])
        if typeof(sources) == TYPE_ARRAY and not sources.is_empty():
            details.append("rests on %d record%s" % [sources.size(), "" if sources.size() == 1 else "s"])
    elif not str(record.get("meaning", "")).is_empty():
        details.append(str(record["meaning"]))
    var form = record.get("form", {})
    return {"kind": "DISPUTED" if disputed else "BELIEF", "colour": _colour(form, Color("#d9e4f2")), "heading": fact,
            "figure": "chance %d%%" % int(round(chance * 100.0)) if chance >= 0.0 else "", "fill": chance,
            "date": date, "details": details, "stamp": ("DISPUTED" if str(claim.get("status", "")) == "disputed" else "CONTESTED") if disputed else ""}

## Something ELI was told two ways (ELI v3's conflict object), with the question that settles it.
static func of_conflict(record: Dictionary) -> Dictionary:
    return {"kind": "DISPUTED", "colour": _colour(record.get("form", {}), Color("#ff6a4d")), "heading": str(record.get("name", "")),
            "figure": "", "fill": -1.0, "date": "", "details": [str(record.get("meaning", ""))], "stamp": ""}

## How often one of ELI's actions worked (ELI v3's evidence.actions row), week by week.
static func of_action(row: Dictionary) -> Dictionary:
    var n := int(row.get("n", 0))
    var ok := int(row.get("ok", 0))
    var rate := float(ok) / float(n) if n > 0 else 0.0
    var details := []
    var weeks := EvidenceStudioRoom._weeks(row.get("weeks", []))
    if not str(weeks[0]).is_empty():
        details.append(str(weeks[0]) + ("  " + str(weeks[1]) if not str(weeks[1]).is_empty() else ""))
    var why := []
    for cause in row.get("causes", []):
        if typeof(cause) == TYPE_DICTIONARY and not str(cause.get("words", "")).is_empty():
            why.append(str(cause["words"]))
    if not why.is_empty():
        details.append("failed: " + ", ".join(why.slice(0, 2)))
    var instead = row.get("instead", [])
    if typeof(instead) == TYPE_ARRAY and not instead.is_empty() and typeof(instead[0]) == TYPE_DICTIONARY:
        details.append("%s worked instead %d×" % [str(instead[0].get("name", "")), int(instead[0].get("n", 0))])
    return {"kind": "ACTION", "colour": EliReadout.GOOD if ok * 2 > n else EliReadout.TROUBLE,
            "heading": str(row.get("name", str(row.get("action", "")).replace("_", " ").to_lower())),
            "figure": "%d of %d worked · %d%%" % [ok, n, int(round(rate * 100.0))], "fill": rate,
            "date": Reading.day(row.get("last")), "details": details, "stamp": ""}

## A lesson ELI learned (ELI v3's book of kind "lesson").
static func of_lesson(record: Dictionary) -> Dictionary:
    var book := EliBook.book_of(record)
    var details := []
    for section in book.get("sections", []):
        if typeof(section) == TYPE_DICTIONARY and not str(section.get("text", "")).is_empty():
            details.append(str(section["text"]))
    # what the lesson says to do, whole (ELI v3's "change"); a cover's title is cut to its cover
    var heading := str(book.get("title", record.get("name", "")))
    if not str(book.get("change", "")).is_empty():
        heading = ": ".join([str(book.get("spine", "")), str(book["change"])].filter(func(t): return not t.is_empty()))
    return {"kind": "LESSON", "colour": _colour(record.get("form", {}), EliReadout.GOOD),
            "heading": heading, "figure": str(book.get("about", "")), "fill": -1.0,
            "date": Reading.span(book.get("from"), book.get("to")), "details": details, "stamp": ""}

## A record ELI's beliefs rest on (a claim's source), numbered as the exhibits are, with what it supports.
static func of_source(number: int, source: Dictionary, supports: Array) -> Dictionary:
    return {"kind": "EXHIBIT %d" % number, "colour": Color("#e8e2d4"), "heading": str(source.get("text", "")),
            "figure": str(source.get("origin", "")), "fill": -1.0, "date": Reading.day(source.get("when")),
            "details": ["supports: " + "; ".join(supports)], "stamp": ""}

## A thought ELI had (ELI v3's feed "thoughts"), a memory it recalled among them: what, how sure, what it
## decided and why, what became of it.
static func of_thought(thought: Dictionary) -> Dictionary:
    var kind := str(thought.get("kind", ""))
    var figure := ""
    if thought.get("chance") != null:
        figure = "chance %d%%" % int(round(float(thought["chance"]) * 100.0))
    if not str(thought.get("outcome", "")).is_empty():
        figure += (" · " if not figure.is_empty() else "") + "proved " + str(thought["outcome"])
    var details := []
    if not str(thought.get("decision", "")).is_empty():
        details.append(str(thought["decision"]) + (": " + str(thought["reason"]) if not str(thought.get("reason", "")).is_empty() else ""))
    var why = thought.get("why", [])
    if typeof(why) == TYPE_ARRAY and not why.is_empty():
        details.append("because " + "; ".join(why.slice(0, 3)))
    return {"kind": kind.to_upper(), "colour": EliReadout._colour_of(kind, EliReadout.PALE), "heading": str(thought.get("what", "")),
            "figure": figure, "fill": float(thought["chance"]) if thought.get("chance") != null else -1.0,
            "date": Reading.day(thought.get("when")), "details": details, "stamp": ""}

## How often one kind of ELI's figures proved right (ELI v3's evidence.accuracy row).
static func of_accuracy(row: Dictionary) -> Dictionary:
    var right := clampf(float(row["right"]) if row.get("right") != null else 0.0, 0.0, 1.0)
    var weeks: Array = row.get("weeks", []) if typeof(row.get("weeks")) == TYPE_ARRAY else []
    var last = weeks[-1].get("from") if not weeks.is_empty() and typeof(weeks[-1]) == TYPE_DICTIONARY else null
    return {"kind": "ACCURACY", "colour": EliReadout.REFLECT, "heading": str(row.get("words", row.get("kind", ""))),
            "figure": "%d%% of %d proved right" % [int(round(right * 100.0)), int(row.get("n", 0))], "fill": right,
            "date": Reading.day(last), "details": ["off by %.2f" % float(row["ece"])] if row.get("ece") != null else [], "stamp": ""}

static func _dated(word: String, ts) -> String:
    var day := Reading.day(ts)
    return "" if day.is_empty() else word + " " + day

static func _colour(form, fallback: Color) -> Color:
    if typeof(form) == TYPE_DICTIONARY and not str(form.get("colour", "")).is_empty():
        return Color(str(form["colour"]))
    return fallback

# --- laid out and drawn ----------------------------------------------------------------------------

# A sheet's own measures, in ems of its writing: the strip's height, the margin at each side, the
# writing's top under the strip and the foot left clear, the bar's height and the room it takes.
const STRIP := 0.7
const SIDE := 0.8
const TOP := 1.0
const FOOT := 0.8
const BAR := 0.5
const BAR_ROOM := 0.8
const GAP := 0.2
const KIND_SCALE := 0.8
const HEADING_SCALE := 1.1

## A record's view laid out on a sheet `width` metres across for writing read from `distance`: every
## line of it, none cut, and how tall a sheet that needs. {"heading", "figure", "date", "details":
## lines, "needs": metres}.
static func laid(view: Dictionary, width: float, distance: float) -> Dictionary:
    var e := Reading.em(distance)
    var font := Reading.typed()
    var column := maxf(width - e * SIDE * 2.0, e)
    var line := Reading.line_height(font, distance)
    var heading := Reading.wrapped(str(view.get("heading", "")), distance, column, font, HEADING_SCALE)
    var figure := Reading.wrapped(str(view.get("figure", "")), distance, column, font)
    var date := Reading.wrapped(str(view.get("date", "")), distance, column, font)
    var details := []
    for detail in view.get("details", []):
        details.append_array(Reading.wrapped(str(detail), distance, column, font))
    var needs := e * TOP + line * KIND_SCALE + line * HEADING_SCALE * heading.size() + line * (figure.size() + date.size()) + e * FOOT
    if float(view.get("fill", -1.0)) >= 0.0:
        needs += e * BAR_ROOM
    if not details.is_empty():
        needs += e * GAP + line * details.size()
    return {"heading": heading, "figure": figure, "date": date, "details": details, "needs": needs}

## Whether a sheet `size` takes the whole of `view` at the size it is read at from `distance`.
static func fits(view: Dictionary, size: Vector2, distance: float) -> bool:
    return float(laid(view, size.x, distance)["needs"]) <= size.y + 0.0005

## The sheet that takes `view` whole where it hangs: `base` (the sheet its place was pinned with) when
## that holds it, else wide enough for its longest word, as tall as its writing makes it, and then
## wider a letter at a time, for as far
## as its place on the board has room (`cell`, the board's share for this sheet, which the sheet turned
## `tilt` radians on its pin must stay inside). When no sheet there takes it whole, the largest that
## the place has room for (fits() then says it does not).
static func size_for(view: Dictionary, base: Vector2, cell: Vector2, tilt: float, distance: float) -> Vector2:
    var e := Reading.em(distance)
    var c := cos(absf(tilt))
    var s := sin(absf(tilt))
    var best := base
    # wide enough that no word of it is broken across lines, when its place has that room
    var width := maxf(base.x, _widest_word(view, distance) + e * SIDE * 2.0)
    if (cell.y - width * s) / c < base.y or (s > 0.0001 and (cell.x - width * c) / s < base.y):
        width = base.x
    while true:
        # the tallest a sheet this wide may be and still lie, turned, inside its place
        var most := (cell.y - width * s) / c
        if s > 0.0001:
            most = minf(most, (cell.x - width * c) / s)
        if most < base.y:
            break
        var needs := float(laid(view, width, distance)["needs"])
        if needs <= most:
            return Vector2(width, maxf(base.y, needs))
        best = Vector2(width, most)
        width += e * Reading.MONO_ADVANCE
    return best

# The widest single word of a view as it is written, in metres.
static func _widest_word(view: Dictionary, distance: float) -> float:
    var measure := Reading.measurer(Reading.typed())
    var widest := 0.0
    var texts := [[str(view.get("heading", "")), HEADING_SCALE], [str(view.get("figure", "")), 1.0], [str(view.get("date", "")), 1.0]]
    for detail in view.get("details", []):
        texts.append([str(detail), 1.0])
    for text in texts:
        for word in str(text[0]).replace("\n", " ").split(" ", false):
            widest = maxf(widest, float(measure.call(word)) * Reading.pixel(distance) * float(text[1]))
    return widest

## Write `view` on a sheet `size` metres across, facing +z from `parent`'s origin, for writing read
## from `distance`; `paper` false leaves the paper to the wall (it draws every sheet's paper at once).
## Every line of the record is written. A sheet too small for it (no place on the board had room for
## the whole of it) leaves out what else the record says from the end, a whole entry at a time, and
## then writes smaller until the heading, the figure and the date are all there: never part of a line.
static func draw(parent: Node3D, size: Vector2, distance: float, view: Dictionary, paper: bool = true) -> void:
    view = view.duplicate()
    var said := laid(view, size.x, distance)
    while float(said["needs"]) > size.y + 0.0005 and not (view.get("details", []) as Array).is_empty():
        view["details"] = (view["details"] as Array).slice(0, -1)
        said = laid(view, size.x, distance)
    var low := 0.0
    if float(said["needs"]) > size.y + 0.0005:
        var high := 1.0
        for i in 12:
            var mid := (low + high) * 0.5
            if float(laid(view, size.x, distance * mid)["needs"]) <= size.y:
                low = mid
            else:
                high = mid
        distance *= maxf(low, 0.05)
        said = laid(view, size.x, distance)
    var e := Reading.em(distance)
    var font := Reading.typed()
    if paper:
        var sheet := MeshInstance3D.new()
        var quad := QuadMesh.new()
        quad.size = size
        sheet.mesh = quad
        sheet.material_override = MaterialKit.light(PAPER, 1.0)
        sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        parent.add_child(sheet)
    var colour: Color = view.get("colour", Color.WHITE)
    var strip := MeshInstance3D.new()
    var band := BoxMesh.new()
    band.size = Vector3(size.x, e * STRIP, 0.004)
    strip.mesh = band
    strip.material_override = MaterialKit.light(colour, 0.9)
    strip.position = Vector3(0, size.y * 0.5 - e * STRIP * 0.5, 0.002)
    strip.name = "Strip"
    parent.add_child(strip)
    var ink := Reading.ink(PAPER)
    var soft := Reading.ink(PAPER, ink.lerp(PAPER, 0.25))
    var left := -size.x * 0.5 + e * SIDE
    var width := size.x - e * SIDE * 2.0
    var y := size.y * 0.5 - e * TOP
    # the kind, then the heading, the figure (with its bar) and the date, then what else it says
    y = _text(parent, [str(view.get("kind", ""))], distance, Vector2(left, y), Reading.ink(PAPER, colour.darkened(0.5)), KIND_SCALE, "Kind")
    y = _text(parent, said["heading"], distance, Vector2(left, y), ink, HEADING_SCALE, "Heading")
    var fill := float(view.get("fill", -1.0))
    if fill >= 0.0:
        var bar_w := width * 0.45
        var bar_h := e * BAR
        for part in [["Track", bar_w, ink.lerp(PAPER, 0.75)], ["Sureness", maxf(0.001, bar_w * clampf(fill, 0.0, 1.0)), ink]]:
            var bar := MeshInstance3D.new()
            var box := BoxMesh.new()
            box.size = Vector3(part[1], bar_h, 0.003)
            bar.mesh = box
            bar.material_override = MaterialKit.light(part[2], 1.0)
            bar.position = Vector3(left + float(part[1]) * 0.5, y - bar_h * 0.9, 0.003)
            bar.visibility_range_end = distance * Reading.READ_FADE
            bar.name = part[0]
            parent.add_child(bar)
        y -= e * BAR_ROOM
    y = _text(parent, said["figure"], distance, Vector2(left, y), ink, 1.0, "Figure")
    y = _text(parent, said["date"], distance, Vector2(left, y), ink, 1.0, "Date")
    _text(parent, said["details"], distance, Vector2(left, y - e * GAP), soft, 1.0, "Details")
    if not str(view.get("stamp", "")).is_empty():
        var stamp := Reading.label(str(view["stamp"]), distance, Color(0.72, 0.05, 0.04), 0.0, font, 1.2)
        stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        stamp.position = Vector3(size.x * 0.12, -size.y * 0.3, 0.004)
        stamp.rotation.z = 0.22
        stamp.name = "Stamp"
        parent.add_child(stamp)

static func _text(parent: Node3D, lines: Array, distance: float, at: Vector2, ink: Color, scale: float, named: String) -> float:
    if lines.is_empty() or (lines.size() == 1 and str(lines[0]).is_empty()):
        return at.y
    var words := Reading.label("\n".join(lines), distance, ink, 0.0, Reading.typed(), scale)
    words.position = Vector3(at.x, at.y, 0.004)
    words.name = named
    parent.add_child(words)
    return at.y - Reading.line_height(Reading.typed(), distance, scale) * lines.size()
