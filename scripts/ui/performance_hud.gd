class_name PerformanceHud
extends CanvasLayer

const HudReadoutsClass = preload("res://scripts/ui/hud_readouts.gd")

## From the window's edges, as the settings dock stands from its corner.
const MARGIN_PX := 20

var app: Node
var label: Label
var elapsed: float = 0.0

func setup(p_app: Node) -> void:
    app = p_app
    label = Label.new()
    # kept to the bottom left of the window whatever its size, growing upwards
    label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, MARGIN_PX)
    label.grow_vertical = Control.GROW_DIRECTION_BEGIN
    label.add_theme_font_size_override("font_size", 16)
    label.add_theme_color_override("font_color", Color("#bcefff"))
    add_child(label)

# What it says is the readouts that are on and what must be seen whatever is on (HudReadouts).
func _process(delta: float) -> void:
    if not label or not app or app.readouts == null:
        return
    elapsed += delta
    if elapsed < HudReadoutsClass.REFRESH_SECONDS:
        return
    elapsed = 0.0
    label.text = "  |  ".join(app.readouts.lines(app))
