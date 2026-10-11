class_name PerformanceHud
extends CanvasLayer

var app: Node
var label: Label

func setup(p_app: Node) -> void:
    app = p_app
    label = Label.new()
    label.position = Vector2(20, 820)
    label.add_theme_font_size_override("font_size", 16)
    label.add_theme_color_override("font_color", Color("#bcefff"))
    add_child(label)

func _process(_delta: float) -> void:
    if not label or not app:
        return
    var opt: String = str(app.optimizer.capability_summary()) if app.optimizer else ""
    label.text = "FPS %d  |  %s  |  %s  |  XR %s  |  Desktop %s  |  %s" % [
        Engine.get_frames_per_second(),
        str(app.current_room_name()),
        str(app.current_environment_name()),
        "ON" if app.xr_active else "FLAT",
        str(app.desktop_status()),
        opt
    ]
    var eli: String = str(app.eli_status())
    if not eli.is_empty():
        label.text += "  |  " + eli
    var leaving: String = str(app.exit_notice())
    if not leaving.is_empty():
        label.text += "  |  " + leaving
