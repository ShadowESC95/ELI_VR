class_name EvidenceSheet
extends RefCounted

# A sheet pinned on the Evidence Wall, written with one of ELI's records: a belief or a fact it
# learned, a disputed one, how often an action worked, a lesson, a record a belief rests on, a
# thought, a memory it recalled, how often its figures proved right. Every sheet reads the same way:
# its kind on a strip in the kind's colour, a heading, the figure or the chance (with a bar filled to
# it), its date, and what else the record says, each at the size it is read at from where the sheet
# hangs. The words are the record's; the sheet adds only the few words of its own in CHROME.
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
    return {"kind": "LESSON", "colour": _colour(record.get("form", {}), EliReadout.GOOD),
            "heading": str(book.get("title", record.get("name", ""))), "figure": str(book.get("about", "")), "fill": -1.0,
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

# --- drawn ---------------------------------------------------------------------------------------

## Write `view` on a sheet `size` metres across, facing +z from `parent`'s origin, for writing read
## from `distance`; `paper` false leaves the paper to the wall (it draws every sheet's paper at once).
static func draw(parent: Node3D, size: Vector2, distance: float, view: Dictionary, paper: bool = true) -> void:
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
    band.size = Vector3(size.x, e * 0.7, 0.004)
    strip.mesh = band
    strip.material_override = MaterialKit.light(colour, 0.9)
    strip.position = Vector3(0, size.y * 0.5 - e * 0.35, 0.002)
    strip.name = "Strip"
    parent.add_child(strip)
    var ink := Reading.ink(PAPER)
    var soft := Reading.ink(PAPER, ink.lerp(PAPER, 0.25))
    var left := -size.x * 0.5 + e * 0.8
    var width := size.x - e * 1.6
    var line := Reading.line_height(font, distance)
    var y := size.y * 0.5 - e * 1.0
    var rows := int(floor((size.y - e * 1.8) / line))
    # the kind, then the heading, the figure (with its bar) and the date, then what else it says
    y = _text(parent, [str(view.get("kind", ""))], distance, Vector2(left, y), Reading.ink(PAPER, colour.darkened(0.5)), 0.8, "Kind")
    rows -= 1
    var heading := Reading.fit(str(view.get("heading", "")), distance, width, clampi(rows - 3, 1, 3), font, 1.1)
    y = _text(parent, heading, distance, Vector2(left, y), ink, 1.1, "Heading")
    rows -= int(ceil(heading.size() * 1.1))
    var fill := float(view.get("fill", -1.0))
    if fill >= 0.0 and rows > 0:
        var bar_w := width * 0.45
        var bar_h := e * 0.5
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
        y -= bar_h * 1.6
    for part in [["Figure", str(view.get("figure", "")), 1], ["Date", str(view.get("date", "")), 2]]:
        if rows > 0 and not str(part[1]).is_empty():
            var shown := Reading.fit(part[1], distance, width, mini(int(part[2]), rows), font)
            y = _text(parent, shown, distance, Vector2(left, y), ink, 1.0, part[0])
            rows -= shown.size()
    var details := "\n".join(view.get("details", []))
    if rows > 0 and not details.strip_edges().is_empty():
        _text(parent, Reading.fit(details, distance, width, rows, font), distance, Vector2(left, y - e * 0.2), soft, 1.0, "Details")
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
