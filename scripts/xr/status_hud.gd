class_name XRStatusHUD
extends Node3D

const HudReadoutsClass = preload("res://scripts/ui/hud_readouts.gd")

var app: Node
var label: Label3D
var elapsed: float = 0.0

func setup(p_app: Node, camera: XRCamera3D) -> void:
    app = p_app
    label = Label3D.new()
    label.name = "XRStatusLabel"
    label.font_size = 18
    label.pixel_size = 0.00092
    label.outline_size = 6
    label.modulate = Color("#dff8ff")
    label.position = Vector3(0.62, 0.32, -1.12)
    label.no_depth_test = true
    label.visible = false
    camera.add_child(label)

# What it says is the readouts that are on and what must be seen whatever is on (HudReadouts); with
# nothing to say it shows nothing.
func _process(delta: float) -> void:
    if label == null or app == null or app.readouts == null:
        return
    # the label rides on the camera, outside this node: it goes with this node's own visibility
    if not visible:
        label.visible = false
        return

    elapsed += delta
    if elapsed < HudReadoutsClass.REFRESH_SECONDS:
        return
    elapsed = 0.0

    var lines: PackedStringArray = app.readouts.lines(app)
    label.visible = not lines.is_empty()
    if label.visible:
        label.text = "\n".join(lines)
