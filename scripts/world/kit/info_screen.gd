class_name InfoScreen
extends Node3D

# A screen that shows something true: a title and lines of text, each line its own colour, on a
# dark face. What it shows comes from ELI's world (its log, its status, what is on its mind); with
# nothing to show it says so, and never fills itself with made-up text.

const FONTS := ["DejaVu Sans Mono", "Liberation Mono", "Menlo", "Consolas", "Courier New", "monospace"]
const FONT_SIZE := 32
const ADVANCE := 0.6           # a monospaced glyph is about this wide for its height

var size := Vector2(1.4, 0.7)
var columns := 44
var tint := Color("#63ddff")
var _title: Label3D
var _lines: Array[Label3D] = []
var _font: SystemFont
var _pixel := 0.001

static func make(screen_size: Vector2, title: String, colour: Color, cols: int = 44) -> InfoScreen:
    var screen := InfoScreen.new()
    screen.size = screen_size
    screen.tint = colour
    screen.columns = cols
    screen._build(title)
    return screen

func _build(title: String) -> void:
    _font = SystemFont.new()
    _font.font_names = PackedStringArray(FONTS)
    var face := MeshInstance3D.new()
    var quad := QuadMesh.new()
    quad.size = size
    face.mesh = quad
    var dark := StandardMaterial3D.new()
    dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    dark.albedo_color = Color(0.015, 0.022, 0.03)
    face.material_override = dark
    face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(face)
    # a glyph wide enough that a line of `columns` fills the face, with a margin either side
    _pixel = size.x * 0.92 / (columns * ADVANCE * FONT_SIZE)
    var row := FONT_SIZE * _pixel * 1.28
    var top := size.y * 0.5 - row * 0.9
    _title = _label(tint.lightened(0.25), Vector3(0, top, 0.003))
    _title.text = title.to_upper()
    var rows := int(floor((size.y * 0.92 - row * 1.6) / row))
    for i in rows:
        _lines.append(_label(tint, Vector3(0, top - row * (1.5 + i), 0.003)))

func _label(colour: Color, at: Vector3) -> Label3D:
    var label := Label3D.new()
    label.font = _font
    label.font_size = FONT_SIZE
    label.pixel_size = _pixel
    label.modulate = colour
    label.outline_size = 0
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    label.width = size.x * 0.92 / _pixel
    label.autowrap_mode = TextServer.AUTOWRAP_OFF
    label.shaded = false
    label.double_sided = false
    label.render_priority = 1
    label.position = at
    add_child(label)
    return label

## How many lines fit.
func rows() -> int:
    return _lines.size()

## Show these lines, top to bottom: each a String, or [String, Color]. Lines beyond what fits are
## not shown; a line too long for the face is cut with "…".
func show_lines(lines: Array) -> void:
    for i in _lines.size():
        var text := ""
        var colour := tint
        if i < lines.size():
            var line = lines[i]
            if typeof(line) == TYPE_ARRAY:
                text = str(line[0])
                colour = line[1] if line.size() > 1 else tint
            else:
                text = str(line)
        if text.length() > columns:
            text = text.substr(0, columns - 1) + "…"
        _lines[i].text = text
        _lines[i].modulate = colour

## Nothing true to show: say why, dimly.
func show_idle(why: String) -> void:
    show_lines([[why, tint.darkened(0.45)]])

## A bar of `width` characters, filled to `value` (0..1).
static func bar(value: float, width: int = 10) -> String:
    var filled := int(round(clampf(value, 0.0, 1.0) * width))
    return "█".repeat(filled) + "░".repeat(width - filled)
